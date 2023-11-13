#include <gflags/gflags.h>

#include "../shared/WiredTigerAdapter.hpp"
#include "../shared/Schema.hpp"
#include "Units.hpp"
#include "leanstore/Config.hpp"
#include "leanstore/LeanStore.hpp"
#include "leanstore/profiling/counters/WorkerCounters.hpp"
#include "leanstore/utils/FVector.hpp"
#include "leanstore/utils/Files.hpp"
#include "leanstore/utils/Parallelize.hpp"
#include "leanstore/utils/RandomGenerator.hpp"
#include "leanstore/utils/ScrambledZipfGenerator.hpp"
// -------------------------------------------------------------------------------------
#include <chrono>
#include <iostream>
#include <string>
#include <thread>
#include <vector>
// -------------------------------------------------------------------------------------
using namespace std;
// -------------------------------------------------------------------------------------
DEFINE_uint32(ycsb_read_ratio, 100, "");
DEFINE_uint64(ycsb_tuple_count, 0, "");
DEFINE_uint32(ycsb_payload_size, 100, "tuple size in bytes");
DEFINE_uint32(ycsb_warmup_rounds, 0, "");
DEFINE_bool(ycsb_single_statement_tx, true, "");
DEFINE_bool(ycsb_count_unique_lookup_keys, true, "");
DEFINE_uint32(ycsb_scan, 0, "");
DEFINE_uint32(ycsb_write_type, 3, "");
// -------------------------------------------------------------------------------------
DEFINE_bool(print_header, true, "");
// -------------------------------------------------------------------------------------
thread_local WT_SESSION* WiredTigerDB::session = nullptr;
thread_local WT_CURSOR* WiredTigerDB::cursor[20] = {nullptr};
// -------------------------------------------------------------------------------------
using YCSBKey = u64;
using YCSBPayload = BytesPayload<256>;
using YCSBTable = Relation<YCSBKey, YCSBPayload>;
// -------------------------------------------------------------------------------------
double calculateMTPS(chrono::high_resolution_clock::time_point begin, chrono::high_resolution_clock::time_point end, u64 factor)
{
   double tps = ((factor * 1.0 / (chrono::duration_cast<chrono::microseconds>(end - begin).count() / 1000000.0)));
   return (tps / 1000000.0);
}
// -------------------------------------------------------------------------------------
int main(int argc, char** argv)
{
   gflags::SetUsageMessage("WiredTiger TPC-C");
   gflags::ParseCommandLineFlags(&argc, &argv, true);
   cout << "WiredTiger YCSB" << endl;
   // -------------------------------------------------------------------------------------
   chrono::high_resolution_clock::time_point begin, end;
   // -------------------------------------------------------------------------------------
   WiredTigerDB wiredtiger_db;
   wiredtiger_db.prepareThread();
   WiredTigerAdapter<YCSBTable> table(wiredtiger_db);
   // -------------------------------------------------------------------------------------
   cout << "Tuple size is (" << sizeof(YCSBKey) << ", " << sizeof(YCSBPayload) << ")" << endl;
   cout << "Read Ratio is " << FLAGS_ycsb_read_ratio << endl;
   cout << "Write type (1: update, 2: insert, 3: rmw) is " << FLAGS_ycsb_write_type << endl;
   cout << "Scan length is " << FLAGS_ycsb_scan << endl;
   // -------------------------------------------------------------------------------------
   const u64 ycsb_tuple_count = (FLAGS_ycsb_tuple_count)
                                    ? FLAGS_ycsb_tuple_count
                                    : FLAGS_target_gib * 1024 * 1024 * 1024 * 1.0 / 2.0 / (sizeof(YCSBKey) + sizeof(YCSBPayload));
   if(!FLAGS_recover) {
      cout << "Inserting " << ycsb_tuple_count << " values" << endl;
      begin = chrono::high_resolution_clock::now();
      // leanstore::utils::Parallelize::range(FLAGS_worker_threads, ycsb_tuple_count, [&](u64 t_i, u64 begin, u64 end) {
      //    wiredtiger_db.prepareThread();
      //    for (u64 i = begin; i < end; i++) {
      //       YCSBPayload payload;
      //       leanstore::utils::RandomGenerator::getRandString(reinterpret_cast<u8*>(&payload), sizeof(YCSBPayload));
      //       YCSBKey& key = i;
      //       table.insert({key}, {payload});
      //    }
      // });
      leanstore::utils::Parallelize::parallelRange(ycsb_tuple_count, [&](u64 begin, u64 end) {
       wiredtiger_db.prepareThread();
       for (u64 i = begin; i < end; i++) {
         YCSBPayload payload;
         leanstore::utils::RandomGenerator::getRandString(reinterpret_cast<u8*>(&payload), sizeof(YCSBPayload));
         YCSBKey& key = i;
         table.insert({key}, {payload});
       }
     });
            end = chrono::high_resolution_clock::now();
      cout << "time elapsed = " << (chrono::duration_cast<chrono::microseconds>(end - begin).count() / 1000000.0) << endl;
      cout << calculateMTPS(begin, end, ycsb_tuple_count) << " M tps" << endl;
   }
   // -------------------------------------------------------------------------------------
   std::vector<thread> threads;
   auto zipf_random = std::make_unique<leanstore::utils::ScrambledZipfGenerator>(0, ycsb_tuple_count, FLAGS_zipf_factor);
   cout << setprecision(4);
   // -------------------------------------------------------------------------------------
   cout << "~Transactions" << endl;
   atomic<bool> keep_running = true;
   atomic<u64> running_threads_counter = 0;
   std::atomic<u64> thread_committed[FLAGS_worker_threads];
   std::atomic<u64> thread_read_committed[FLAGS_worker_threads];
   std::atomic<u64> thread_write_committed[FLAGS_worker_threads];
   std::atomic<u64> thread_aborted[FLAGS_worker_threads];
   for (u64 t_i = 0; t_i < FLAGS_worker_threads; t_i++) {
      thread_committed[t_i] = 0;
      thread_read_committed[t_i] = 0;
      thread_write_committed[t_i] = 0;
      thread_aborted[t_i] = 0;
      int operation_type = 0;
      // -------------------------------------------------------------------------------------
      threads.emplace_back([&, t_i] {
         running_threads_counter++;
         wiredtiger_db.prepareThread();
         while (keep_running) {
            jumpmuTry()
            {
               YCSBKey key;
               if (FLAGS_zipf_factor == 0) {
                  key = leanstore::utils::RandomGenerator::getRandU64(0, ycsb_tuple_count);
               } else {
                  key = zipf_random->rand();
               }
               assert(key < ycsb_tuple_count);
               YCSBPayload result;
               wiredtiger_db.startTX();
               if (FLAGS_ycsb_read_ratio == 100 || leanstore::utils::RandomGenerator::getRandU64(0, 100) < FLAGS_ycsb_read_ratio) {
                  if (FLAGS_ycsb_scan == 0) {
                     table.lookup1({key}, [&](const YCSBTable&) {});  // result = record.my_payload;
                  } else {
                     u64 scan_counter = 0;
                     table.scan(
                        {key},
                        [&](const YCSBTable::Key& found_key, const YCSBTable& found_value) {
                           scan_counter++;
                           if (scan_counter >= FLAGS_ycsb_scan) {
                              return false;
                           }
                           return true;
                        },
                        [&]() {});
                  }

                  operation_type = 1; // read operation
               } else {
                  leanstore::utils::RandomGenerator::getRandString(reinterpret_cast<u8*>(&result), sizeof(YCSBPayload));
                  if (FLAGS_ycsb_write_type == 1) { // Update
                     table.insert({key}, {result});
                  } else if (FLAGS_ycsb_write_type == 2) { // Insert
                     YCSBKey random_key = leanstore::utils::RandomGenerator::getRandU64(0, 100000000000);
                     u64 random_prefix = leanstore::utils::RandomGenerator::getRandU64(1, 16);
                     table.insert1({random_key}, {result}, random_prefix);
                  } else { // Read-Modify-Write
                     UpdateDescriptorGenerator1(tabular_update_descriptor, YCSBTable, my_payload);
                     table.update1(
                        {key}, [&](YCSBTable& rec) { rec.my_payload = result; }, tabular_update_descriptor);
                  }
                  
                  operation_type = 2; // write operation
               }
               wiredtiger_db.commitTX();
               thread_committed[t_i]++;
               if (operation_type == 1) {
                  thread_read_committed[t_i]++;
               } else {
                  thread_write_committed[t_i]++;
               }
            }
            jumpmuCatch() { thread_aborted[t_i]++; }
         }
         running_threads_counter--;
      });
   }
   // -------------------------------------------------------------------------------------
   threads.emplace_back([&]() {
      running_threads_counter++;
      if (FLAGS_print_header) {
         cout << "t,tag,oltp_committed,oltp_aborted" << endl;
      }
      u64 time = 0;
      u64 count_commited = 0;
      u64 count_read_commited = 0;
      u64 count_write_commited = 0;
      u64 count_aborted = 0;
      while (keep_running) {
         u64 total_committed = 0, total_aborted = 0, total_read_committed = 0, total_write_committed = 0;
         for (u64 t_i = 0; t_i < FLAGS_worker_threads; t_i++) {
            total_committed += thread_committed[t_i].exchange(0);
            total_read_committed += thread_read_committed[t_i].exchange(0);
            total_write_committed += thread_write_committed[t_i].exchange(0);
            total_aborted += thread_aborted[t_i].exchange(0);
         }
         count_commited += total_committed;
         count_read_commited += total_read_committed;
         count_write_commited += total_write_committed;
         count_aborted += total_aborted;
         cout << time++ << "," << FLAGS_tag << "," << total_committed << "," << total_aborted << endl;
         sleep(1);
      }
      running_threads_counter--;
      printf("total time: %ld, oltp per second: %.2lf\n", time, (double)count_commited/time);
      printf("total operations: %ld \n", count_commited);
      printf("total read operations: %ld \n", count_read_commited);
      printf("total write operations: %ld \n", count_write_commited);
   });
   // Shutdown threads
   sleep(FLAGS_run_for_seconds);
   keep_running = false;
   while (running_threads_counter) {
   }
   for (auto& thread : threads) {
      thread.join();
   }
   return 0;
}
