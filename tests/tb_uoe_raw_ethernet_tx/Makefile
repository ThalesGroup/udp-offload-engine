# Copyright (c) 2022-2023 THALES. All Rights Reserved

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Color message
RED=\033[0;31mc
BLUE=\033[0;36m
RESET=\033[0;0m

# Environnement
PWD=$(shell pwd)

ifneq ("$(wildcard $(PWD)/workspace)","")
else
	CMD := $(shell mkdir workspace)
endif

ifneq ("$(wildcard $(PWD)/modelsim.ini")","")
else
	CMD := $(shell cp $(PWD)/../lib/modelsim.ini $(PWD)/modelsim.ini)
endif

# Config Cocotb
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps
COCOTB_REDUCED_LOG_FMT = 0
COCOTB_LOG_LEVEL = DEBUG
COCOTB_RESULTS_FILE = workspace/results.xml

# Simulation Tool
SIM=questa
WAVES=1

# Append VHDL files
TOPLEVEL_LANG ?= vhdl

-include $(PWD)/../../src/uoe_module/uoe_module.mk
-include $(PWD)/../../src/common/common.mk

#VHDL version
VCOM_ARGS += -2008

SIM_BUILD = workspace/sim_build

VCD_FILE_DIR = workspace/ghdl_sim.vcd

# Top Level
TOPLEVEL = uoe_raw_ethernet_tx
# Testbench Python
MODULE = tb_uoe_raw_ethernet_tx

# Module Parameters
export G_ACTIVE_RST := 0
export G_ASYNC_RST := true
export G_TDATA_WIDTH := 64

ifeq ($(SIM), questa)
	GUI = 1
    SIM_ARGS += $(foreach v,$(filter G_%,$(.VARIABLES)),-g $(v)=$($(v)))
    SIM_ARGS += -wlf workspace/simulation_waveforms_rtl.wlf
    SIM_ARGS += -l $(PWD)/workspace/log_sim

    ifeq ($(WAVES), 1)
		ifneq ("$(wildcard $(PWD)/workspace/wave.do)","")
			SIM_ARGS += -do workspace/wave.do
		endif
	endif
else ifeq ($(SIM), ghdl)
	SIM_ARGS += --vcd=$(VCD_FILE_DIR)
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

start:
	@(echo -e "${BLUE}INFO:")
	@(echo -e "Simulation is executing")
	@(echo -e "...\n${RESET}")
	@($(MAKE)) > workspace/log_make 2> workspace/log_error || true
	@(if [ -s workspace/log_error ]; then \
		cat workspace/log_make; \
		echo -e "${RED}"; \
		cat workspace/log_error; \
		echo -e "${RESET}"; \
	fi)
	@(if [ "$(SIM)" = "questa" ]; then \
		if [ $(GUI) = 0 ]; then \
			cat workspace/log_sim; \
		fi; \
	fi)

	@(if [ "$(SIM)" = "ghdl" ]; then \
		egrep -v "make\[" workspace/log_make > workspace/log_sim; \
		cat workspace/log_sim; \
		if [ "$(WAVE)" = "1" ]; then \
			gtkwave $(VCD_FILE_DIR) wave.gtkw;\
		elif [ $(GUI) = 1 ]; then \
			gtkwave $(VCD_FILE_DIR); \
		fi; \
		echo -e "\n"; \
	fi)

	-@($(MAKE) clean >> workspace/log_make 2> workspace/log_error || true)
	@(if [ -s workspace/log_error ]; then \
		echo -e "${RED}"; \
		cat workspace/log_error; \
		echo -e "${RESET}"; \
	fi)

	@(rm -rf __pycache__ >> workspace/log_make 2> /dev/null || true)
	@(rm -rf workspace/log_error >> workspace/log_make 2> /dev/null || true)
	@(rm -f modelsim.ini >> workspace/log_make 2> /dev/null || true)
	@(mv -f *.vstf workspace >> workspace/log_make 2> /dev/null || true)

	@(echo -e "${BLUE}INFO:")
	@(echo -e 'Logs of "make start" are in workspace/log_make file')
	@(echo -e "Logs of simulation are in workspace/log_sim file\n${RESET}")
