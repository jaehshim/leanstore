#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage $0 [DB name] [Read ratio] {Scan Length} {Insert flag}"
	exit -1
fi

#TARGET="rocksdb"
#TARGET="wiredtiger"
TARGET=$1

if [ "$TARGET" = "rocksdb" ]
then
	LIBRARY_PATH="/home/$USER/testbed/rocksdb"
	BENCH_PATH="./rocksdb_ycsb"
elif [ "$TARGET" = "wiredtiger" ]
then
	LIBRARY_PATH="/home/$USER/testbed/wiredtiger/build"
	BENCH_PATH="./wiredtiger_ycsb"
elif [ "$TARGET" = "leanstore" ]
then
	BENCH_PATH="./ycsb"
else
	exit
fi

MNT="/mnt/nvme"
DEV="nvme0n1"

TUPLES=33554432
#TUPLES=8372255
#TUPLES=16744510
TIME=60

RATIO=$2
WRITE_TYPE=$3 # 1: update, 2: insert, 3: RMW
SCAN=$4

if [ -z "$3" ]
then
	WRITE_TYPE=3
fi
if [ -z "$4" ]
then
	SCAN=0
fi

echo $TARGET $RATIO $WRITE_TYPE $SCAN

function do_init() {
	echo "drop cache & sync & sleep"
	sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches '
	sudo sync
	sleep 5

	echo "umount" $MNT
	sudo rm -rf /mnt/nvme/*
	sudo umount $MNT > /dev/null 2>&1

	echo "format" $DEV
	sudo nvme format /dev/$DEV -t 3600000

	echo "mount" $DEV $MNT
	sudo mkfs.ext4 -F /dev/$DEV || exit
	sudo mount /dev/$DEV $MNT || exit
	sudo chown $USER:$USER $MNT || exit
}

do_init
sleep 10

sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=$TIME --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=$RATIO --ycsb_scan=$SCAN --ycsb_write_type=$WRITE_TYPE | tee results/$TARGET"_"$RATIO"_"$SCAN"_"$WRITE_TYPE


## FOR BENCHMARK ON DIRTY DB ##
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=120 --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO"_"$SCAN
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=120 --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO"_"$SCAN
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=120 --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO"_"$SCAN
#
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=60 --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=$RATIO --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO"_"$SCAN
#
