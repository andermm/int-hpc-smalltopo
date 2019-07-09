#!/bin/bash
mpirun -np 2 -machinefile nodes is.S.x >> is.S.log  &
sudo ./send.py h5 "OK" 600 &
sleep 5
ssh h6 iperf -c h2 -u -t 30 &
sleep 55
kisend=$(pidof python ./send.py)
sudo kill -9 $kisend
