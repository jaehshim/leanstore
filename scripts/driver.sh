#!/bin/bash

mkdir results

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

