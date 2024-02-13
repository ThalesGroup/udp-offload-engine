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

#====================================================================== Useful functions and variables=============================================

REQUEST_1 = 0x6162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
REQUEST_2 = 0x08004d56000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869

ECHO_1 = 0x00005556000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
ECHO_2 = 0x08005556000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869

SEED = 1234567890



def gen_icmpframes_tosend(frame):
    """Generates correct format from icmp frame, from hexedecimal data"""

    data = frame.to_bytes(40,'big')
    return AxiStreamFrame(tdata = data)
    
    
    
def genRandom_icmpframes(gen_random):
    """generating pseudo random frames for icmp module to receive"""
    
    # generating random data of random size
    #payload_size = gen_random.randint(8,64)
    payload_size = 32
    cocotb.log.info(f"Generating payload of size {payload_size}")
    #data = gen_random.randbytes(payload_size)
    data = REQUEST_1.to_bytes(32,'big')
    data_hex = return_frame_hexa_format(data)
    cocotb.log.info(f"payload : {data_hex}")
    
    header = 0x0800000000010005
    data_checksum = header.to_bytes(8,'big') + data
    
    code = 0x0800
    checksum = calculate_checksum(data_checksum)
    identifier = 0x0001
    sequence_number = 0x0005
   
    
    data = code.to_bytes(2,'big') + checksum.to_bytes(2,'big') + identifier.to_bytes(2,'big') + sequence_number.to_bytes(2,'big') + data
    tkeep = [1] * len(data)
    
    data_hex = return_frame_hexa_format(data)
    cocotb.log.info(f"frame : {data_hex}")
    return AxiStreamFrame(tdata = data,tkeep = tkeep)

    
    
def return_frame_hexa_format(frame):
    hex_format = "0x"
    for i in range(len(frame)):
        temp = frame[i]
        temp = format(temp,'02x')
        hex_format +=  str(temp)
    return hex_format



def calculate_checksum(frame):
    # Dividing sent message in packets of bits.
    sum = 0
    for i in range(0,len(frame)-1,2):
        temp = frame[i]*256 + frame[i+1]
        if (i!=2):
            cocotb.log.info(f"Byte : {temp}")
            sum = sum + temp
               
    sum = bin(sum) [2:]   
    cocotb.log.info(f"Result of sum : {sum}")
    
    # Adding the overflow bits
    if(len(sum) > 16):
        x = len(sum)-16
        sum = bin(int(sum[0:x], 2)+int(sum[x:], 2))[2:]
    if(len(sum) < 16):
        sum = '0'*(16-len(sum))+sum
   
    # Calculating the complement of sum
    Checksum = ''
    for i in sum:
        if(i == '1'):
            Checksum += '0'
        else:
            Checksum += '1'
            
    Checksum = int(Checksum,2)
    cocotb.log.info(f"Checksum in hex : {hex(Checksum)}")
    return Checksum

#====================================================================== Coroutines handler ============================================

# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(5, units='ns')
    dut.rst.value = 1
    await Timer(15, units='ns')
    dut.rst.value = 0



async def handleslave_send_frame(dut):
    """coroutine to gen and send icmp frame to module"""
    
# Init source
    logging.getLogger("cocotb.uoe_icmp_module.Request").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "Request"), dut.clk, dut.rst, reset_active_level=True)
    
    
    # Init random generator
    gen_random = Random()
    gen_random.seed(SEED)
    
    cocotb.log.info("generating random frame")
    frame = genRandom_icmpframes(gen_random)
    
    # Init signals
    dut.Request_tkeep = 0
    dut.Request_tdata = 0
    
    #wait for reset
    await FallingEdge(dut.rst)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Data send,first correct framme then wrong frame
    #await slave.send(gen_icmpframes_tosend(REQUEST_1))
    
    await slave.send(frame)
    
    #wait for end of receptionEQUEST_1))

    await FallingEdge(dut.Echo_TLAST)

    await slave.send(gen_icmpframes_tosend(REQUEST_2))

    cocotb.log.info("End of handlerSlave_rx")
    
    
    

async def handlermaster_receive_reply(dut):
    """coroutine used to check generated frame"""

      # Error variable
    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_icmp_module.Echo").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "Echo"), dut.clk, dut.rst, reset_active_level=True)

    # Init signal
    
    dut.Echo_tready = 1
    
    
    await FallingEdge(dut.rst)
    
    #receive data : echo frame correct
    data = await master.recv()  
    
    data_hexa = return_frame_hexa_format(data.tdata)
    if (data.tdata ==  ECHO_1.to_bytes(40,"big") ):
        cocotb.log.info("Correct frame ! Request 1 has passed")
        cocotb.log.info(f"{ECHO_1:#0{82}x} : was expected ")
        cocotb.log.info(f"{data_hexa} : was received")
    else :
        cocotb.log.error("Incorrect frame ! Request 1 has failed")
        cocotb.log.error(f"{ECHO_1:#0{82}x} : was expected ")
        cocotb.log.error(f"{data_hexa} : was received")
        simulation_err += 1
    

    data = await master.recv()  
    
    data_hexa = return_frame_hexa_format(data.tdata)
    if (data ==  ECHO_2.to_bytes(40,"big") ):
        cocotb.log.info("Correct frame ! Request 2 has passed")
        cocotb.log.info(f"{ECHO_2:#0{82}x}': was expected ")
        cocotb.log.info(f"{data_hexa} : was received")
    else :
        
        cocotb.log.error("Incorrect frame ! Request 2 has failed")
        cocotb.log.error(f"{ECHO_2:#0{82}x} : was expected ")
        cocotb.log.error(f"{data_hexa} : was received")
        simulation_err += 1



    
    await RisingEdge(dut.clk)
    cocotb.log.info("End of handlermaster_reply")



#====================================================================== MAIN handler ============================================

@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""
    
    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The ICMP module responds to a ping echo request with the ICMP protocol.                                               *\n"
    description += "* ICMP makes it possible to receive a ping request (ICMP type 8), and respond with an Echo (ICMP type 0), aswell as sending its own requests.                *\n"
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
    
    cocotb.log.info("After RESET, start of coroutines")
    
        
    #start other coroutines
    icmp_request = cocotb.start_soon(handleslave_send_frame(dut))
    icmp_reply = cocotb.start_soon(handlermaster_receive_reply(dut))
    
    
    # Wait for Reset
    await FallingEdge(dut.rst)
    await RisingEdge(dut.clk)
    
    
    #execute coroutines
    await icmp_request
    await icmp_reply
    
    cocotb.log.info("After coroutines, end of handler MAIN")
      
        
    await Timer(500, units='ns')
    
    
    
    
    if simulation_err >= 1:
        print_rsl = "\n\n\n***************************************************************************************\n"
        print_rsl += "**                                 There is(are) " + str(simulation_err) + " error(s) !                             **\n"
        print_rsl += "***************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n***************************************************************************************\n"
        print_rsl += "**                                      Simulation OK !                              **\n"
        print_rsl += "***************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
    

