#!/bin/bash

#NPB-MPI
#mpirun -np 2 -machinefile nodes is.W.x >> is.W.1500.log  &

#Send/receive
sudo ./send.py h5 "OK" 60000 &

#Iperf
sleep 20
#ssh h6 iperf3 -c h2 -u -t 20 -b 1500M  &
#sleep 40

#Kill send 
kisend=$(pidof python ./send.py)
sudo kill -9 $kisend
