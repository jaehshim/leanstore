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

YCSB=("A" "B" "C" "D" "E" "F")
YCSB_READ_RATIO=("50" "95" "100" "95" "95" "50")
YCSB_SCAN_LENGTH=("0" "0" "0" "0" "50" "0")
YCSB_WRITE_TYPE=("1" "1" "1" "2" "2" "3")

MNT="/mnt/nvme"
DEV=$3

TUPLES=252645136
#TUPLES=33554432
#TUPLES=8372255
#TUPLES=16744510
TIME=600

WL=$2
RATIO=${YCSB_READ_RATIO[$WL]}
WRITE_TYPE=${YCSB_WRITE_TYPE[$WL]} # 1: update, 2: insert, 3: RMW
SCAN=${YCSB_SCAN_LENGTH[$WL]}

echo $TARGET ${YCSB[$WL]} $RATIO $WRITE_TYPE $SCAN 
echo results/$TARGET"_"${YCSB[$WL]}

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
sleep 120

sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=$TIME --ycsb_tuple_count=$TUPLES --ycsb_read_ratio=$RATIO --ycsb_scan=$SCAN --ycsb_write_type=$WRITE_TYPE | tee ycsb_results/$TARGET"_"${YCSB[$WL]}


## FOR BENCHMARK ON DIRTY DB ##
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=60 --ycsb_tuple_count=8372255 --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=60 --ycsb_tuple_count=8372255 --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=60 --ycsb_tuple_count=8372255 --ycsb_read_ratio=0 --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO
#
#sudo LD_LIBRARY_PATH=$LIBRARY_PATH $BENCH_PATH --recover --ssd_path=$MNT --dram_gib=4 --worker_threads=8 --run_for_seconds=60 --ycsb_tuple_count=8372255 --ycsb_read_ratio=$RATIO --ycsb_scan=$SCAN | tee results/$TARGET"_"$RATIO
#
#
