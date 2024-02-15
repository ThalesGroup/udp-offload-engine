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
from cocotbext.axi.axis import AxiStreamPause

# Others
import random
from random import randbytes
from random import Random
import logging
import itertools

#====================================================================== Useful functions and variables=============================================

REQUEST_1 = 0x08004d56000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
#REQUEST_2 = 0x08004d56000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
ECHO_1 = 0x00005556000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869
#ECHO_2 = 0x08005556000100056162636465666768696a6b6c6d6e6f7071727374757677616263646566676869

TYPE_ECHO = 0x0800
TYPE_REPLY = 0x0000
CHECKSUM_NULL = 0x0000
IDENTIFIER = 0x0001
SEQUENCE_NUMBER = 0x0005

header_echo = TYPE_ECHO.to_bytes(2,'big') + CHECKSUM_NULL.to_bytes(2,'big') + IDENTIFIER.to_bytes(2,'big') + SEQUENCE_NUMBER.to_bytes(2,'big')
header_reply = TYPE_REPLY.to_bytes(2,'big') + CHECKSUM_NULL.to_bytes(2,'big') + IDENTIFIER.to_bytes(2,'big') + SEQUENCE_NUMBER.to_bytes(2,'big')

PAYLOAD_SIZE_MIN = 1
PAYLOAD_SIZE_MAX = 64
PAYLOAD_SIZE = 32

NB_RANDOM_BITS = 10
NB_FRAMES = 5
frames = []

SEED = 1234567890


def gen_icmpframes(frame):
    """Generates correct format from icmp frame, from hexedecimal data"""

    data = frame.to_bytes(40,'big')
    return AxiStreamFrame(tdata = data)
    
    
       
    
def genRandom_icmpframes(gen_random,header):
    """generating pseudo random frames for icmp module to receive"""
    
    # generating random data of random size
    #payload_size = gen_random.randint(PAYLOAD_SIZE_MIN,PAYLOAD_SIZE_MAX)

    #cocotb.log.info(f"Generating payload of size {PAYLOAD_SIZE}")
    data = gen_random.randbytes(PAYLOAD_SIZE)
    #data = REQUEST_1.to_bytes(32,'big')
    #cocotb.log.info(f"payload : {return_frame_hexa_format(data)}")
    
    data_check = header + data
    #cocotb.log.info(f"frame before check: {return_frame_hexa_format(data_check)}")    
    checksum = calculate_checksum(data_check)
    checksum = checksum.to_bytes(2,'big')
    #cocotb.log.info(f"checksum sent : {return_frame_hexa_format(checksum)}")

    header = TYPE_ECHO.to_bytes(2,'big') + checksum + IDENTIFIER.to_bytes(2,'big') + SEQUENCE_NUMBER.to_bytes(2,'big')    
    data = header + data
    #checksum = calculate_checksum(data)
    tkeep = [1] * len(data)
    
    #cocotb.log.info(f"frame sent : {return_frame_hexa_format(data)}")
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
    for i in range(len(frame)):
        temp = frame[i]
        if (i%2 == 0):
            temp = temp * 256
        
        #cocotb.log.info(f"Byte : {hex(temp)}")
        sum = sum + temp
        #cocotb.log.info(f"sum : {hex(sum)}")
               
    sum = bin(sum)   
    sum = sum[2:] 
    # Adding the overflow bits
    if(len(sum) > 16):
        x = len(sum)-16
        sum = bin(int(sum[0:x], 2)+int(sum[x:], 2))[2:]
    if(len(sum) < 16):
        sum = '0'*(16-len(sum))+sum
    #cocotb.log.info(f"Result of sum : {sum}")
    
    # Calculating the complement of sum
    Checksum = ''
    for i in sum:
        if(i == '1'):
            Checksum += '0'
        else:
            Checksum += '1'
            
    Checksum = int(Checksum,2)
    #cocotb.log.info(f"Checksum in hex : {hex(Checksum)}")
    return Checksum





def check_icmp_frame(frame_to_check, frame_sent):
   """function to check if given frame is correct"""
   
   # Error variable
   global simulation_err

   cocotb.log.info(f"frame sent : {return_frame_hexa_format(frame_sent)}")
   

   payload_sent = frame_sent[8:]
   theoric_checksum = calculate_checksum(header_reply + payload_sent)
   cocotb.log.info(f"checksum theoric : {hex(theoric_checksum)}")
   
   cocotb.log.info(f"frame received : {return_frame_hexa_format(frame_to_check)}")
   
   if((TYPE_REPLY.to_bytes(2,'big') == frame_to_check[0:2]) and (theoric_checksum.to_bytes(2,'big') == frame_to_check[2:4]) and (IDENTIFIER.to_bytes(1,'big') == frame_to_check[5].to_bytes(1,'big')) and (SEQUENCE_NUMBER.to_bytes(2,'big') == frame_to_check[6:8]) and (payload_sent == frame_to_check[8:])):

       cocotb.log.info("Correct frame ! Request has passed")

   else :
       cocotb.log.error("Incorrect frame ! Request 2 has failed")
       #cocotb.log.error(f"{ECHO_1:#0{82}x} : was expected ")
       simulation_err += 1
    
 

#def set_axis_throughput(axis_pause: AxiStreamPause, throughput: Real):
#    """ Manage the AXI Stream throughput : TREADY or TVALID"""
#    if (throughput < 0.0) or (throughput > 1.0):
#        raise ValueError("Throughput must be between 0.0 and 1.0")
#    axis_pause.set_pause_generator(gen_rand_bool(false_probability=throughput)) 
   
    
    
def gen_pause_cycle(gen_seed):
    """Generate a pause cycle for a stream source"""
    
    """
    loop = [] 
    for i in range(NB_RANDOM_BITS):
        loop.append(gen_seed.randint(0,1))
    
    """
    
    loop = [1,1,0,0,0,0,0,0,0,0,0,1,1,1,0,1,1,1,0,1,0,1,0,0]
    
    return itertools.cycle(loop)
    
    
    


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
    
   
    cocotb.log.info(f"generating {NB_FRAMES} random frames")
    for i in range(NB_FRAMES):
        frames.append(genRandom_icmpframes(gen_random,header_echo))
  
    
    # Init signals
    dut.Request_tkeep = 0
    dut.Request_tdata = 0
    
    #wait for reset
    await FallingEdge(dut.rst)
    await RisingEdge(dut.clk)
    
  
    #await slave.send(gen_icmpframes(REQUEST_1))
    #await FallingEdge(dut.Echo_TLAST)
    
   
    
    slave.set_pause_generator(gen_pause_cycle(gen_random)) 
    
    
    for i in range(NB_FRAMES):
       
        await slave.send(frames[i])
    
        #wait for end of reception REQUEST_1))

        await FallingEdge(dut.Echo_TLAST)

 

    cocotb.log.info("End of handlerSlave_rx")
    
    
    

async def handlermaster_receive_reply(dut):
    """coroutine used to check generated frame"""
   
    # Init source
    logging.getLogger("cocotb.uoe_icmp_module.Echo").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "Echo"), dut.clk, dut.rst, reset_active_level=True)

    # Init signal
    
    dut.Echo_tready = 1
    
    
    await FallingEdge(dut.rst)
    
    
    #data = await master.recv()  
    #check_icmp_frame(data.tdata,gen_icmpframes(REQUEST_1).tdata)
    
    #receive data : echo frame correct
    cocotb.log.info(f"receiving {NB_FRAMES} random frames")
    
    for i in range(NB_FRAMES):
        data = await master.recv() 
        check_icmp_frame(data.tdata,frames[i].tdata)


    
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
      
        
    await Timer(300, units='ns')
    
    
    
    
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
    

