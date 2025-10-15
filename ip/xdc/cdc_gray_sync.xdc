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

#**************************************************************
# Set max delay (to limit skew on bus)
#**************************************************************

#This constraint file has been tested on vivado 2019.1

# Define source clock
set src_clk          [get_clocks -quiet -of [get_ports CLK_SRC]]
set src_clk_period   [get_property -quiet -min PERIOD $src_clk]

# Set max delay on cross clock domain path for gray vector resynchronization
set_max_delay -from [get_pins {data_src_r_reg[*]/C}] -to [get_pins {data_dst_arr_reg[0][*]/D}] -datapath_only $src_clk_period
set_bus_skew  -from [get_pins {data_src_r_reg[*]/C}] -to [get_pins {data_dst_arr_reg[0][*]/D}] $src_clk_period
