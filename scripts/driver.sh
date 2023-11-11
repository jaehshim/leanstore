#!/bin/bash

mkdir results

## ./do_eval.sh [DB name] [read ratio] {scan length} {insert flag}

./do_eval.sh wiredtiger 100
sleep 10
./do_eval.sh wiredtiger 50
sleep 10
./do_eval.sh wiredtiger 0
sleep 10

./do_eval.sh rocksdb 100
sleep 10
./do_eval.sh rocksdb 50
sleep 10
./do_eval.sh rocksdb 0
sleep 10

./do_eval.sh wiredtiger 100 0 1
sleep 10
./do_eval.sh wiredtiger 50 0 1
sleep 10
./do_eval.sh wiredtiger 0 0 1
sleep 10

./do_eval.sh rocksdb 100 0 1
sleep 10
./do_eval.sh rocksdb 50 0 1
sleep 10
./do_eval.sh rocksdb 0 0 1
sleep 10

source ~/pushover.sh
push_to_mobile "LeanStore benchmark" "driver $dir done! $HOSTNAME @ $(date)"
