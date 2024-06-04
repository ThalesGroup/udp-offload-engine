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
# Set False Path
#**************************************************************
# Double Flip-flop synchronization
set_false_path -to [get_pins {data_int_reg[0]/D}]
