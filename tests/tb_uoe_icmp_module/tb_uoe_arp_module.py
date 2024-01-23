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

# Import Cocotb
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame)

# Others
import random
from random import randbytes
from random import Random
import logging



# Global Parameters
DEBUG = 1

# Variable declaration

BROADCAST_MAC_ADDR = 0xFF_FF_FF_FF_FF_FF
ZERO_MAC_ADDR = 0x00_00_00_00_00_00
STATUS_VALID = 0
STATUS_INVALID = 1




# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 1
    await Timer(30, units='ns')
    dut.rst.value = 0


# coroutine to handle Slave interface
async def handlerSlave_rx(dut):
    """coroutine use to generate Frame on Slave interface for icmp"""

    # Init source
    logging.getLogger("cocotb.uoe_icmp_module.s_rx").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_rx"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    s_random = Random()
    s_random.seed(5)
    # s_trans = genRandomTransfer_rx(s_random, 1)

    # Init signals
    dut.s_rx_tkeep = 0
    dut.s_rx_tdata = 0

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)
    #await RisingEdge(dut.ICMP_INIT_DONE)

    # Data send
    

    cocotb.log.info("End of handlerSlave_rx")


# coroutine to handle Slave interface
async def handlerSlave_tx(dut):
    """coroutine used to """

    


# coroutine to handle Master interface
async def handlerMaster_tx(dut):
    """coroutine used to """

    # Init source
    logging.getLogger("cocotb.uoe_icmp_module.m_tx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_tx"), dut.clk, dut.rst, reset_active_level=False)

    # Init signal
    dut.m_tx_tready = 0

    await RisingEdge(dut.init_done)

   
    # Normal Operati
    # *******************************************************************************
    # Test 1 :

    # Test 2 : 

    # Test 1 : 

    cocotb.log.info("End of handlerMaster_tx")


# coroutine to handle Master interface
async def handlerMaster_ip_mac_addr(dut):
    """coroutine used to """

    

    cocotb.log.info("End of handlerMaster_ip_mac_addr")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the ARP sub-module is to manage the transmission and reception of ARP frames on the network.                                               *\n"
    description += "* ARP makes it possible to associate a network layer address (IP address) of a remote host with its physical layer address (MAC Address).                *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    # Error variable
    global simulation_err
    simulation_err = 0

    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    # start clock
    cocotb.start_soon(clk100M.start())
    # start coroutine of reset management
    cocotb.start_soon(handlerReset(dut))

    # Start process
    

    # Update signals 
   

    # Wait Reset

    # Stimulis
    dut.init_done = 1

    await RisingEdge(dut.ICMP_INIT_DONE)

    # Await process


    await Timer(5, units='us')

    if simulation_err >= 1:
        print_rsl = "\n\n\n***************************************************************************************\n"
        print_rsl += "**                                 There are " + str(simulation_err) + " errors !                             **\n"
        print_rsl += "***************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n***************************************************************************************\n"
        print_rsl += "**                                      Simulation OK !                              **\n"
        print_rsl += "***************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
