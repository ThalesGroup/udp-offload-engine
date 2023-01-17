# ******************************************************************************************
# * This program is the Confidential and Proprietary product of THALES.                    *
# * Any unauthorized use, reproduction or transfer of this program is strictly prohibited. *
# * Copyright (c) 2014-2020 THALES SGF. All Rights Reserved.                               *
# ******************************************************************************************

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
