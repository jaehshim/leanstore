#!/bin/bash

mkdir results

## ./do_eval.sh [DB name] [Read ratio] {Scan Length} {Insert flag}

# ./do_eval.sh wiredtiger 100
# sleep 60
./do_eval.sh wiredtiger 50 3
sleep 60
./do_eval.sh wiredtiger 0 3
sleep 60

# ./do_eval.sh rocksdb 100
# sleep 60
./do_eval.sh rocksdb 50 3
sleep 60
./do_eval.sh rocksdb 0 3
sleep 60

./do_eval.sh wiredtiger 50 2
sleep 60
./do_eval.sh wiredtiger 0 2
sleep 60

./do_eval.sh rocksdb 50 2
sleep 60
./do_eval.sh rocksdb 0 2
sleep 60

./do_eval.sh wiredtiger 50 1
sleep 60
./do_eval.sh wiredtiger 0 1
sleep 60

./do_eval.sh rocksdb 50 1
sleep 60
./do_eval.sh rocksdb 0 1
sleep 60

source ~/pushover.sh
push_to_mobile "LeanStore benchmark" "driver $dir done! $HOSTNAME @ $(date)"
