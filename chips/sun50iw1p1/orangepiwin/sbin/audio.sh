#!/bin/bash

# playback
amixer cset -c 0 numid=112,iface=MIXER,name='Headphone Switch' on
amixer cset -c 0 numid=16,iface=MIXER,name='headphone volume' 60
amixer cset -c 0 numid=86,iface=MIXER,name='DACL Mixer AIF1DA0L Switch' on
amixer cset -c 0 numid=82,iface=MIXER,name='DACR Mixer AIF1DA0R Switch' on 

# recording
amixer cset -c 0 numid=97,iface=MIXER,name='AIF1 AD0L Mixer ADCL Switch' on
amixer cset -c 0 numid=93,iface=MIXER,name='AIF1 AD0R Mixer ADCR Switch' on
amixer cset -c 0 numid=40,iface=MIXER,name='LADC input Mixer MIC1 boost Switch' on
amixer cset -c 0 numid=33,iface=MIXER,name='RADC input Mixer MIC1 boost Switch' on
amixer cset -c 0 numid=18,iface=MIXER,name='MIC1 boost AMP gain control' 7
