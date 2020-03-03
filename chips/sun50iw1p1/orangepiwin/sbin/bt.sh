#!/bin/bash

MAC=$(echo -n 1c:1b; dd bs=1 count=4 if=/dev/random 2>/dev/null | hexdump -v -e '/1 ":%02X"')

rfkill unblock all
sleep 2
echo "0" > /sys/class/rfkill/rfkill0/state
sleep 2
echo "1" > /sys/class/rfkill/rfkill0/state
sleep 2
echo " " > /dev/ttyS1
sleep 2

brcm_patchram_plus --patchram /lib/firmware/ap6212/bcm43438a1.hcd --enable_hci --no2bytes --bd_addr ${MAC} /dev/ttyS1
