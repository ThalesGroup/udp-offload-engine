# ******************************************************************************************
# * This program is the Confidential and Proprietary product of THALES.                    *
# * Any unauthorized use, reproduction or transfer of this program is strictly prohibited. *
# * Copyright (c) 2014-2017 THALES GLOBAL SERVICES. All Rights Reserved.                   *
# ******************************************************************************************

#clock creation section

# 125 MHz global ref - defined in clock wiz
# create_clock -period 8.000 [get_ports CLK_125_P]
#  156.25 MHz SFP ref
create_clock -period 6.400 [get_ports SFP_REFCLK_P]

# Pinout

# Bank  66 VCCO - VADJ_1V8_FPGA_10A - IO_L12P_T1U_N10_GC_66
set_property IOSTANDARD LVDS [get_ports CLK_125_P]
set_property PACKAGE_PIN G10 [get_ports CLK_125_P]
set_property PACKAGE_PIN F10 [get_ports CLK_125_N]
set_property IOSTANDARD LVDS [get_ports CLK_125_N]

# SFP GT in bank 226 sourced by Si570 clock in Bank 227
set_property PACKAGE_PIN P6 [get_ports SFP_REFCLK_P]
set_property PACKAGE_PIN P5 [get_ports SFP_REFCLK_N]

#SFP 1
set_property PACKAGE_PIN U4 [get_ports SFP_TX_P[0]]
set_property PACKAGE_PIN U3 [get_ports SFP_TX_N[0]]
set_property PACKAGE_PIN T2 [get_ports SFP_RX_P[0]]
set_property PACKAGE_PIN T1 [get_ports SFP_RX_N[0]]

set_property PACKAGE_PIN K21     [get_ports SFP_LOS[0]]
set_property IOSTANDARD LVCMOS18 [get_ports SFP_LOS[0]]


# SFP 2
set_property PACKAGE_PIN W4 [get_ports SFP_TX_P[1]]
set_property PACKAGE_PIN W3 [get_ports SFP_TX_N[1]]
set_property PACKAGE_PIN V2 [get_ports SFP_RX_P[1]]
set_property PACKAGE_PIN V1 [get_ports SFP_RX_N[1]]

set_property PACKAGE_PIN AM9     [get_ports SFP_LOS[1]]
set_property IOSTANDARD LVCMOS18 [get_ports SFP_LOS[1]]

# GPIO Button for reset
set_property PACKAGE_PIN AE10    [get_ports CPU_RESET]
set_property IOSTANDARD LVCMOS18 [get_ports CPU_RESET]

# GPIO LEDS
set_property PACKAGE_PIN AP8     [get_ports GPIO_LED[0]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[0]]
set_property PACKAGE_PIN H23     [get_ports GPIO_LED[1]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[1]]
set_property PACKAGE_PIN P20     [get_ports GPIO_LED[2]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[2]]
set_property PACKAGE_PIN P21     [get_ports GPIO_LED[3]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[3]]
set_property PACKAGE_PIN N22     [get_ports GPIO_LED[4]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[4]]
set_property PACKAGE_PIN M22     [get_ports GPIO_LED[5]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[5]]
set_property PACKAGE_PIN R23     [get_ports GPIO_LED[6]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[6]]
set_property PACKAGE_PIN P23     [get_ports GPIO_LED[7]]
set_property IOSTANDARD LVCMOS18 [get_ports GPIO_LED[7]]

# GPIO SW
set_property PACKAGE_PIN AN16    [get_ports GPIO_DIP_SW[0]]
set_property IOSTANDARD LVCMOS12 [get_ports GPIO_DIP_SW[0]]
set_property PACKAGE_PIN AN19    [get_ports GPIO_DIP_SW[1]]
set_property IOSTANDARD LVCMOS12 [get_ports GPIO_DIP_SW[1]]
set_property PACKAGE_PIN AP18    [get_ports GPIO_DIP_SW[2]]
set_property IOSTANDARD LVCMOS12 [get_ports GPIO_DIP_SW[2]]
set_property PACKAGE_PIN AN14    [get_ports GPIO_DIP_SW[3]]
set_property IOSTANDARD LVCMOS12 [get_ports GPIO_DIP_SW[3]]
