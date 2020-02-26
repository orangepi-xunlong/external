#!/bin/bash

amixer cset -c 0 numid=27,iface=MIXER,name='Left Output Mixer DACR Switch' on
amixer cset -c 0 numid=28,iface=MIXER,name='Left Output Mixer DACL Switch' on
amixer cset -c 0 numid=18,iface=MIXER,name='LADC input Mixer MIC1 boost Switch' on
