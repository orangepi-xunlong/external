#!/bin/bash

amixer cset -c 1 numid=27,iface=MIXER,name='Left Input Mixer MIC1 Switch' on
amixer cset -c 1 numid=46,iface=MIXER,name='Left I2S Mixer ADCL Switch' on

amixer cset -c 1 numid=26,iface=MIXER,name='Right Output Mixer DACL Switch' on
amixer cset -c 1 numid=18,iface=MIXER,name='Left Output Mixer DACL Switch' on
amixer cset -c 1 numid=41,iface=MIXER,name='Left DAC Mixer I2SDACL Switch' on
amixer cset -c 1 numid=10,iface=MIXER,name='LINEOUT Volume' 31
