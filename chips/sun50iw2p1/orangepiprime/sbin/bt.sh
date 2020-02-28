#!/bin/bash

rfkill unblock all
echo "0" > /sys/class/rfkill/rfkill0/state
echo "1" > /sys/class/rfkill/rfkill0/state
sleep 2
echo "" > /dev/ttyS1
sleep 2

rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 1>/tmp/rtl8723bs.firmware 2>&1
