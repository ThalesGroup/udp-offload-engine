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
from cocotb.triggers import RisingEdge,FallingEdge
from cocotbext.axi import (AxiBus,AxiMaster,AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame)

# Others
import random
from random import randbytes
from random import Random
import logging

#====================================================================== Coroutines handler ============================================



# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(10, units='ns')
    dut.rst.value = 1
    await Timer(20, units='ns')
    dut.rst.value = 0




async def handleslave_send_frame(dut):
    """coroutine to gen and send icmp frame to module"""
    
# Init source
    logging.getLogger("cocotb.uoe_icmp_module.Request").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "Request"), dut.clk, dut.rst, reset_active_level=True)
    
    
    # Init random generator
    gen_random = Random()
    gen_random.seed(30)
    
    # Init signals
    dut.Request_tkeep = 0
    dut.Request_tdata = 0
    
    #wait for reset
    await FallingEdge(dut.rst)
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    
    # Data send, from hex to bytes
    data = 0x08004d56000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
    data = data.to_bytes(40,'big')
    frame = AxiStreamFrame(tdata = data)
    await slave.send(frame)


    cocotb.log.info("End of handlerSlave_rx")
    
    
    

async def handlermaster_receive_reply(dut):
    """coroutine used to check generated frame"""

    # Init source
    logging.getLogger("cocotb.uoe_icmp_module.Echo").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "Echo"), dut.clk, dut.rst, reset_active_level=True)

    # Init signal
    
    #dut.Echo_tready = 0
    
    
    await FallingEdge(dut.rst)
    
    #receive data : must be set with a prior condition good enough to ensure init data is not received
    data = await master.recv()  
        
    await RisingEdge(dut.init_done)



#====================================================================== MAIN handler ============================================

@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""
    
    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the ICMP module is to do things other modules can't :).                                               *\n"
    description += "* ICMP makes it possible to receive a ping request (ICMP type 0), and respond with an Echo (ICMP type 8), aswell as sending its own requests.                *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Starting coroutines")
    
    # Error variable
    global simulation_err
    simulation_err = 0

    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    # start clock
    cocotb.start_soon(clk100M.start())
    # start coroutine of reset management
    cocotb.start_soon(handlerReset(dut))
     
        
    #start other coroutines
    icmp_request = cocotb.start_soon(handleslave_send_frame(dut))
    #icmp_reply = cocotb.start_soon(handlermaster_receive_reply(dut))
    

    dut.Echo_tready = 1
          
    # Wait for Reset
    await FallingEdge(dut.rst)
    await RisingEdge(dut.clk)
    
    
    #execute coroutines
    await icmp_request
    #await icmp_reply
    
    cocotb.log.info("after RESET, write")
      
        
    await Timer(500, units='ns')
    

