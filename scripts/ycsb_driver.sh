#!/bin/bash

mkdir ycsb_results

./ycsb_eval.sh wiredtiger 0 nvme0n1
sleep 60
./ycsb_eval.sh wiredtiger 1 nvme0n1
sleep 60
./ycsb_eval.sh wiredtiger 2 nvme0n1
sleep 60
./ycsb_eval.sh wiredtiger 3 nvme0n1
sleep 60
./ycsb_eval.sh wiredtiger 4 nvme0n1
sleep 60
./ycsb_eval.sh wiredtiger 5 nvme0n1
sleep 60

./ycsb_eval.sh rocksdb 0 nvme0n1
sleep 60
./ycsb_eval.sh rocksdb 1 nvme0n1
sleep 60
./ycsb_eval.sh rocksdb 2 nvme0n1
sleep 60
./ycsb_eval.sh rocksdb 3 nvme0n1
sleep 60
./ycsb_eval.sh rocksdb 4 nvme0n1
sleep 60
./ycsb_eval.sh rocksdb 5 nvme0n1
sleep 60

mv ycsb_results delta_ycsb_results


source ~/pushover.sh
push_to_mobile "LeanStore benchmark" "YCSB done! $HOSTNAME @ $(date)"
