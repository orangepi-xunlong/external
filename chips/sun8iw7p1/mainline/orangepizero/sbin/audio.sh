#!/bin/bash

amixer cset numid=17,iface=MIXER,name='Line In Capture Switch' on
amixer cset numid=4,iface=MIXER,name='Line Out Playback Switch' on
amixer cset numid=1,iface=MIXER,name='DAC Playback Volume' 63
amixer cset numid=3,iface=MIXER,name='Line Out Playback Volume' 31
amixer cset numid=18,iface=MIXER,name='Mic1 Capture Switch' on
