#!/bin/bash

MAC=$(echo -n 1c:1b; dd bs=1 count=4 if=/dev/random 2>/dev/null | hexdump -v -e '/1 ":%02X"')

rfkill unblock all
echo "0" > /sys/class/rfkill/rfkill0/state
echo "1" > /sys/class/rfkill/rfkill0/state
echo "" > /dev/ttyS1

hciattach /dev/ttyS1 bcm43xx 115200 flow bdaddr ${MAC} 1>/tmp/ap6256.firmware 2>&1
