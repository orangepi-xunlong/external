# -*- coding: utf-8 -*-
# Copyright (c) 2018 Richard Hull
# See LICENSE.md for details.

import functools
from copy import deepcopy
from OPi.constants import BOARD, BCM, SUNXI, CUSTOM

class _sunXi(object):

    def __getitem__(self, value):

        offset = ord(value[1]) - 65
        pin = int(value[2:])

        assert value[0] == "P"
        assert 0 <= offset <= 25
        assert 0 <= pin <= 31

        return (offset * 32) + pin


_pin_map = {
    # Physical pin to actual GPIO pin
    BOARD : {
        3:   64,    # PD26/TWI0-SDA/TS3-D0/UART3-CTS/JTAG-DI
        5:   65,    # PD25/TWI0-SCK/TS3-DVLD/UART3-RTS/JTAG-DO
        7:  150,    # PD22/PWM0/TS3-CLK/UART2-CTS
        8:  145,    # PL2/S-UART-TX
        10: 144,    # PL3/S-UART-RX
        11:  33,    # PD24/TWI2-SDA/TS3-SYNC/UART3-RX/JTAG-CK
        12:  50,    # PD18/LCD0-CLK/TS2-ERR/DMIC-DATA3
        13:  35,    # PD23/TWI2-SCK/TS3-ERR/UART3-TX/JTAG-MS
        15:  92,    # PL10/S-OWC/S-PWM1
        16:  54,    # PD15/LCD0-D21/TS1-DVLD/DMIC-DATA0/CSI-D9
        18:  55,    # PD16/LCD0-D22/TS1-D0/DMIC-DATA1
        19:  40,    # PH5/SPI1-MOSI/SPDIF-MCLK/TWI1-SCK/SIM1-RST
        21:  39,    # PH6/SPI1-MISO/SPDIF-IN/TWI1-SDA/SIM1-DET
        22:  56,    # PD21/LCD0-VSYNC/TS2-D0/UART2-RTS
        23:  41,    # PH4/SPI1-CLK/PCM0-MCLK/H-PCM0-MCLK/SIM1-DATA
        24:  42,    # PH3/SPI1-CS/PCM0-DIN/H-PCM0-DIN/SIM1-CLK
        26: 149,     # PL8/S-PWM0
        27:  64,   # PA19 (PCM0_CLK/TWI1_SDA/PA_EINT19)
        28:  65,   # PA18 (PCM0_SYNC/TWI1_SCK/PA_EINT18)
        29:  -1,    # PA7 (SIM_CLK/PA_EINT7)
        31:  -1,    # PA8 (SIM_DATA/PA_EINT8)
        32:  -1,  # PG8 (UART1_RTS/PG_EINT8)
        33:  -1,    # PA9 (SIM_RST/PA_EINT9)
        35:  -1,   # PA10 (SIM_DET/PA_EINT10)
        36:  -1,  # PG9 (UART1_CTS/PG_EINT9)
        37:  -1,   # PA20 (PCM0_DOUT/SIM_VPPEN/PA_EINT20)
        38:  -1,  # PG6 (UART1_TX/PG_EINT6)
        40:  -1  # PG7 (UART1_RX/PG_EINT7)
    },
    # BCM pin to actual GPIO pin
    BCM: {
        2: 12,
        3: 11,
        4: 6,
        7: 10,
        8: 13,
        9: 16,
        10: 15,
        11: 14,
        14: 198,
        15: 199,
        17: 1,
        18: 7,
        22: 3,
        23: 19,
        24: 18,
        25: 2,
        27: 0
    },

    SUNXI: _sunXi(),

    # User defined, initialized as empty
    CUSTOM: {}
}


def set_custom_pin_mappings(mappings):
    _pin_map[CUSTOM] = deepcopy(mappings)


def get_gpio_pin(mode, channel):
    assert mode in [BOARD, BCM, SUNXI, CUSTOM]
    return _pin_map[mode][channel]


bcm = functools.partial(get_gpio_pin, BCM)
board = functools.partial(get_gpio_pin, BOARD)
sunxi = functools.partial(get_gpio_pin, SUNXI)
custom = functools.partial(get_gpio_pin, CUSTOM)
