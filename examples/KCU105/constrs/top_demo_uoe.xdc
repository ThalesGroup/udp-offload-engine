# Copyright (c) 2022-2024 THALES. All Rights Reserved
#
# Licensed under the SolderPad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option. You may obtain a copy of the License at
#
# https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any
# work distributed under the License is distributed on an "AS IS"
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific
# language governing permissions and limitations under the
# License.
#
# File subject to timestamp TSP22X5365 Thales, in the name of Thales SIX GTS France, made on 10/06/2022.
#

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

# UART
# Bank  95 VCCO -          - IO_L3P_T0L_N4_AD15P_A26_65
set_property PACKAGE_PIN G25      [get_ports "UART_RX"] 
set_property IOSTANDARD  LVCMOS18 [get_ports "UART_RX"]
# Bank  95 VCCO -          - IO_L2P_T0L_N2_FOE_B_65
set_property PACKAGE_PIN K26      [get_ports "UART_TX"] 
set_property IOSTANDARD  LVCMOS18 [get_ports "UART_TX"]
# Inversion RX/TX sur carte d'évaluation 
