#!/bin/bash

apt-get -y install dialog expect bc cpufrequtils figlet toilet

rm -rf /etc/update-motd.d/* 
cp overlay/* / -rf

ln -s opi-config /usr/bin/opi-config
