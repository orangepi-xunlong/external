#!/bin/bash

amixer cset -c 1 numid=27,iface=MIXER,name='Left Input Mixer MIC1 Switch' on
amixer cset -c 1 numid=46,iface=MIXER,name='Left I2S Mixer ADCL Switch' on
