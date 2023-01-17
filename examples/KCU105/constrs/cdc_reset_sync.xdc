# ******************************************************************************************
# * This program is the Confidential and Proprietary product of THALES.                    *
# * Any unauthorized use, reproduction or transfer of this program is strictly prohibited. *
# * Copyright (c) 2014-2020 THALES SGF. All Rights Reserved.                               *
# ******************************************************************************************

#**************************************************************
# Set False path for asynchronous clear and preset
#**************************************************************
set_false_path -to [get_pins {GEN_RANGE[*].inst_cdc_bit_sync_neg/data_int_reg[*]/CLR GEN_RANGE[*].inst_cdc_bit_sync_pos/data_int_reg[*]/PRE}]
