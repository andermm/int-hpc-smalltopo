#!/bin/bash

#NPB-MPI
mpirun -np 2 -machinefile nodes is.S.x >> is.S.log  &

#Send/receive
sudo ./receive.py >> receive1.log
sudo ./send.py h5 "OK" 600 &

#Iperf
sleep 5
ssh h2 iperf -s -u &
ssh h6 iperf -c h2 -u -t 50 &
sleep 55

#Kill send 
kisend=$(pidof python ./send.py)
sudo kill -9 $kisend
