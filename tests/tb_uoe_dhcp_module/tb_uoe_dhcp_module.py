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
#from cocotb.regression import TimeoutError
from cocotb.triggers import RisingEdge, FallingEdge, with_timeout
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame)
from cocotb.result import TestFailure
# Others
import random
from random import randbytes
from random import Random
import logging

# DHCP library
from lib import DhcpFrame 
# UDP library
from lib import UdpFrame
from enum import IntEnum
# DHCP state define in t_dhcp_state
class DhcpState(IntEnum):
    IDLE             = 0
    DISCOVER         = 1
    OFFER            = 2
    REQUEST          = 3
    ACK              = 4
    BOUND            = 5

class Dhcp_Rx_State(IntEnum): 
    IDLE             = 0
    DHCP_RX_HEADER   = 1
    SKIP             = 2
    DHCP_RX_OPTIONS  = 3

class MessageType(IntEnum):
    OFFER            = 0x02
    ACK              = 0x05
    NACK             = 0x06
# Global Parameters
NB_FRAMES            = 20
DHCP_HEADER_SIZE     = 240
PAYLOAD_MIN_SIZE     = 240
PAYLOAD_MAX_SIZE     = 270
FRAME_SIZE_MAX       = PAYLOAD_MAX_SIZE
SEED                 = 1658406584
DEBUG                = 1
SERVER_AND_END_SIZE  = 7

# Variable declarations
LOCAL_IP_ADDR        = 0xC0_A8_0A_04        # local IP addr requested in DISCOVER
LOCAL_MAC_ADDR       = 0x01_23_45_67_89_AB  # Hardware addr
SRC_MAC_ADDR         = 0x11_22_33_44_55_66  # Hardware addr
DEST_MAC_ADDR        = 0xff_ff_ff_ff_ff_ff  # Broadcast
DHCP_SERVER_IP       = 0xC0_A8_01_01        # 192.168.1.1 (example server IP)
DHCP_CLIENT_IP       = 0xC0_A8_01_0A        # 192.168.1.10 (example client IP)
DHCP_GATEAWAY_IP     = 0xC0_A8_01_0B        # 192.168.1.11 (GIADDR )
DHCP_ROUTER_IP       = 0xC0_A8_01_0B        # 192.168.1.11 (router ip )
DHCP_SERVER_PORT     = 0x00_43              # port src 67
DHCP_CLIENT_PORT     = 0x00_44              # port dest 68
DHCP_FLAGS           = 0x8000               # Broadcast flags

DISCOVER_MSG         = 0x35_01_01           # Tag, length and value for dhcp discover option
OFFER_MSG            = 0x35_01_02           # Tag, length and value for dhcp offer option
REQUEST_MSG          = 0x35_01_03           # Tag, length and value for dhcp request option
DECLINE_MSG          = 0x35_01_04           # Tag, length and value for dhcp decline option
ACK_MSG              = 0x35_01_05           # Tag, length and value for dhcp ack option
NACK_MSG             = 0x35_01_06           # Tag, length and value for dhcp nack option
RELEASE_MSG          = 0x35_01_07           # Tag, length and value for dhcp release option
INFORM_MSG           = 0x35_01_08           # Tag, length and value for dhcp inform option
PARAMETER_REQ_MSG    = 0x37_02_01_03        # Tag, length and value for dhcp requested parametters list option
BROADCAST_MSG        = 0x1C_04_FF_FF_FF_FF  # Tag, length and value for dhcp broadcast option
RENEWEL_MSG          = 0x3A_04_00_00_0E_10  # Tag, length and value for dhcp renewing  option
REBINDING_MSG        = 0x3B_04_00_00_1C_20  # Tag, length and value for dhcp rebinfing option

DHCP_END             = 0xFF                 # Tag  for dhcp end option
DHCP_PAD             = 0x00                 # Tag  for dhcp pad option

REQUESTED_IP_MSG     = 0x32_04              # Tag  and length for dhcp server option     
DHCP_SERVER_IP_MSG   = 0x36_04              # Tag  and length for dhcp server option
DHCP_NETMASK_MSG     = 0x01_04              # Tag  and length for dhcp subnetmask option
DHCP_ROUTER_MSG      = 0x03_04              # Tag  and length for dhcp router option
DHCP_LEASE_TIME_MSG  = 0x33_04              # Tag  and length for dhcp lease time option

OFFER                = 0x02             
ACK                  = 0x05
NACK                 = 0x06
Rem_SIZE             = [6, 12, 18]
TYPE_MSG_LIST        = [DISCOVER_MSG, OFFER_MSG, REQUEST_MSG, DECLINE_MSG, ACK_MSG, NACK_MSG, RELEASE_MSG, INFORM_MSG]
OPTIONNAL_MSG        = [BROADCAST_MSG, RENEWEL_MSG, REBINDING_MSG]

def int_to_ip(ip_int):
    return '.'.join(map(str, ip_int.to_bytes(4, 'big')))

def gen_dhcp_option_tx(dut, message_type):
    """Generate a DHCP Discover or Request frame."""
    # Init random generator
    gen_random = Random()
    gen_random.seed(SEED)    

    options     = b''
    options     += message_type.to_bytes(3, 'big')       # message type option
    options     += DHCP_PAD.to_bytes(1, 'big')           # pad option
    if message_type == DISCOVER_MSG:         

        if dut.dhcp_use_ip.value == 1:       
            options += REQUESTED_IP_MSG.to_bytes(2, 'big')   # requested ip option
            options += LOCAL_IP_ADDR.to_bytes(4, 'big')
        
        else:
            options += DHCP_PAD.to_bytes(6, 'big')           # padding 
        options += DHCP_PAD.to_bytes(9, 'big')           # padding

    elif message_type == REQUEST_MSG:
        options += REQUESTED_IP_MSG.to_bytes(2, 'big')  
        options += DHCP_CLIENT_IP.to_bytes(4, 'big')     # requested ip option
        options += DHCP_PAD.to_bytes(2, 'big')           # pad option 
        options += DHCP_SERVER_IP_MSG.to_bytes(2, 'big') # server ip option
        options += DHCP_SERVER_IP.to_bytes(4, 'big')
        options += DHCP_PAD.to_bytes(1, 'big')           # pad option
    
    options     += PARAMETER_REQ_MSG.to_bytes(4, 'big')  # parameter request list option
    options     += DHCP_END.to_bytes(1, 'big')           # End option
   
    return options

def gen_dhcp_options_rx(message_type):
    # Init random generator
    rand_gen = Random()
    rand_gen.seed(SEED)

    secs = rand_gen.randint(0, 0xFFFF)                  #  seconds 
    # Generate valid options
    options = b''
    options +=DHCP_PAD.to_bytes(1, 'big')               #  pad message
       
    if message_type == OFFER:
        options += OFFER_MSG.to_bytes(3, 'big')         #  message OFFER to receive
        
    elif message_type == ACK:
        options += ACK_MSG.to_bytes(3, 'big')           #  message ACK to receive
        
    elif message_type == NACK:
        options += NACK_MSG.to_bytes(3, 'big')          #  message NACK to receive

    if message_type != NACK:            
      
        # Randomize subnet mask
        prefix_length  = rand_gen.randint(0, 32)
        random_netmask = (0xFFFFFFFF << (32 - prefix_length)) & 0xFFFFFFFF
        options       += DHCP_NETMASK_MSG.to_bytes(2, 'big') + random_netmask.to_bytes(4, 'big')
        options       += DHCP_ROUTER_MSG.to_bytes(2, 'big') + DHCP_ROUTER_IP.to_bytes(4, 'big')
        lease_time     = rand_gen.randint(300, 86400)
        options       += DHCP_LEASE_TIME_MSG.to_bytes(2, 'big') + lease_time.to_bytes(4, 'big')
        size           = DHCP_HEADER_SIZE + len(options)  + SERVER_AND_END_SIZE + Rem_SIZE[rand_gen.randint(0,2)]
         
        # Fill remaining bytes with random valid dhcp option
        remaining_size = size - DHCP_HEADER_SIZE - SERVER_AND_END_SIZE - len(options)
        while( remaining_size > 0):
            options += OPTIONNAL_MSG[int((remaining_size/6)) - 1].to_bytes(6, 'big')
            remaining_size -= 6
    else :
        size = DHCP_HEADER_SIZE + len(options) + SERVER_AND_END_SIZE       
           
    options += DHCP_SERVER_IP_MSG.to_bytes(2, 'big') + DHCP_SERVER_IP.to_bytes(4, 'big')  # Server Identifier
    options += DHCP_END.to_bytes(1, 'big')                                                # End option

    return options, size, secs

def gen_dhcp_frame(xid, message_type):
    """Generate a complete DHCP frame."""
   
    # Init random generator
    gen_randrom = Random()
    gen_randrom.seed(SEED)

    options, size, secs = gen_dhcp_options_rx(message_type)
    pay = size.to_bytes(2, 'big') + DHCP_SERVER_IP.to_bytes(4, 'big')
    port_dest = DHCP_CLIENT_PORT
    port_src = DHCP_SERVER_PORT
    
    tdata = DhcpFrame(
        op=0x02,                        # Boot Reply
        htype=0x01,                     # Ethernet
        hlen=0x06,                      # MAC address length
        hops=0x00,
        xid=xid,                        # xid
        secs=secs,                      # seconds
        flags=DHCP_FLAGS,               # flags 
        ciaddr=0x0000,
        yiaddr=DHCP_CLIENT_IP if message_type != NACK else 0x00000000, # offered IP addr
        siaddr=0x0000,
        giaddr=0x0000,
        chaddr=LOCAL_MAC_ADDR,
        options=options
    )

    tdata = DhcpFrame.__bytes__(tdata)
    tkeep = [1] * len(tdata)
    tuser = int.from_bytes(port_dest.to_bytes(2, 'big') + port_src.to_bytes(2, 'big') + pay, 'big')
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=tuser)
    return frame

async def handler_reset(dut):
    """Reset management"""
    dut.rst.value     = 0
    await Timer(30, units='ns')
    dut.rst.value     = 1

async def handler_initdone(dut):
    """Init done and dhcp_sdhcp_start management"""
    dut.init_done.value = 0
    dut.dhcp_start.value = 0
    dut.dhcp_use_ip.value = 0
    dut.dhcp_user_ip_addr.value = 0x0000
    dut.dhcp_user_mac_addr.value = 0x000000
    await Timer(150, units='ns')
    dut.dhcp_use_ip.value = 1
    dut.dhcp_user_ip_addr.value = LOCAL_IP_ADDR
    dut.dhcp_user_mac_addr.value = LOCAL_MAC_ADDR
    dut.init_done.value = 1
    await Timer(200, units='ns')
    dut.dhcp_start.value = 1
    

async def handler_master(dut):
    """Read data from AXI-Stream bus"""

    # Error variable
    MSG_LIST     = [DISCOVER_MSG, REQUEST_MSG, DECLINE_MSG, RELEASE_MSG, INFORM_MSG]
    global simulation_err, xid 
    
    # Init source
    logging.getLogger("cocotb.uoe_dhcp_module.m").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    m_random_ctrl = Random()
    m_random_ctrl.seed(SEED)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    for _ in range(NB_FRAMES):
        
        msg_type = MSG_LIST[_ % 2]

        try:
            
            data = await with_timeout(master.recv(), 1500, 'ns')
        except cocotb.result.SimTimeoutError:
             
            if dut.dhcp_state == DhcpState.BOUND:
                break
            else:
                dut.log.warning("Timeout occurred while waiting for master to receive data")
                continue

        data_ctrl = DhcpFrame(
            op=0x01,                        # BOOTPREQUEST
            htype=0x01,                     # Ethernet
            hlen=0x06,                      # MAC address length
            hops=0x00,
            xid=xid,                        # transaction identifier
            secs=0x00,
            flags=DHCP_FLAGS,               # Broadcast flag
            ciaddr=0x0000,
            yiaddr=0x0000,
            siaddr=0x0000,
            giaddr=0x0000,
            chaddr=LOCAL_MAC_ADDR,
            options=gen_dhcp_option_tx(dut, msg_type)
        )
        
        data_ctrl = DhcpFrame.__bytes__(data_ctrl)
        data = data.tdata
        if  data == data_ctrl:
            
            
                dut.log.info("DHCP_TX [{:02d}] {:<7} : A {} message is successfully sent.".format(_, "",  ("DISCOVER" if msg_type == DISCOVER_MSG else "REQUEST")))
                dut.log.info("Check passed {:<7} : Frame [{}] met the one expected\n".format("", _))
        else:
            dut.log.error(f"DHCP_TX [{_}] failure (somthing went wrong check frame [{_}] below )")
            dut.log.info(f"data frame : [{data.hex()}] \n Data_ctrl : [{data_ctrl.hex()}]\n")
            simulation_err += 1

    cocotb.log.info("End of handlerMaster")

async def monitor_rx_state(dut, stop_signal):
    global skip_mode
    """Coroutine that monitors rx_state as long as stop_signal is not True"""
    while not(stop_signal):
        await RisingEdge(dut.clk)  # Wait for one clock cycle
        if dut.inst_uoe_dhcp_module_rx.rx_state.value == Dhcp_Rx_State.SKIP:
            skip_mode = True
            break


async def handler_slave(dut):
    """Sending data frames generated by gen_dhcp_frame to AXI-Stream bus"""

    #global variables
    global simulation_err, xid, skip_mode
    MSG_LIST             = [OFFER, ACK, NACK]

    # Init source
    logging.getLogger("cocotb.uoe_dhcp_module.s").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s"), dut.clk, dut.rst, reset_active_level=False)
    
    skip_mode = False
    # Stop monitoring after sending
    
    # Init random generator
    s_random = Random()
    s_random.seed(SEED)
    
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    for _ in range(NB_FRAMES):
            stop_signal = True  
            await RisingEdge(dut.dhcp_message_sent)  
            await Timer(30, units='ns')
            dut.log.info("DHCP_RX [{:02d}] {:<7} {} ".format(_, "", ": Rising Edge on dhcp_message_sent; waiting DHCP server to respond "))

            if (_ % 2) == 0:
                message_type = OFFER

            else:
                message_type = MSG_LIST[s_random.randint(1, 2)]                       # ACK or NACK

            dut.log.info("DHCP process is at {:<1} : {} stage".format("", DhcpState(int(dut.dhcp_state.value)).name ))
            frame = gen_dhcp_frame(xid, message_type)
            
            # Stop signal to end monitoring
            stop_signal =  False
            # Start monitoring rx_state
            cocotb.start_soon(monitor_rx_state(dut, stop_signal))

            # Send the frame
            await slave.send(frame)

            s_dhcp_frame = DhcpFrame.from_bytes((frame.tdata))
            s_xid     = s_dhcp_frame.xid
            s_yiaddr  = s_dhcp_frame.yiaddr
            s_options = s_dhcp_frame.options     
            
            # Value for test
            await FallingEdge(dut.S_TLAST)
            await RisingEdge(dut.clk)

            o_options  = b''
            o_options += DHCP_PAD.to_bytes(1, 'big')                                                                                                # pad message
            o_options += 0x35_01.to_bytes(2, 'big') + (int(dut.inst_uoe_dhcp_module_rx.dhcp_type_msg.value)).to_bytes(1, 'big')                     # type message 
          
            if message_type != NACK:
                o_options += DHCP_NETMASK_MSG.to_bytes(2, 'big')    + (int(dut.inst_uoe_dhcp_module_rx.dhcp_subnetmask.value)).to_bytes(4, 'big')   # dhcp_subnetmask
                o_options += DHCP_ROUTER_MSG.to_bytes(2, 'big')     + (int(dut.inst_uoe_dhcp_module_rx.dhcp_router.value)).to_bytes(4, 'big')       # router
                o_options += DHCP_LEASE_TIME_MSG.to_bytes(2, 'big') + (int(dut.inst_uoe_dhcp_module_rx.dhcp_lease_time.value)).to_bytes(4, 'big')   # dhcp_lease_time

                size       = len(s_options) - len(o_options) - SERVER_AND_END_SIZE 
                if size == 6 :
                    o_options += OPTIONNAL_MSG[0].to_bytes(6, 'big')
                elif size == 12 :
                    o_options += OPTIONNAL_MSG[0].to_bytes(6, 'big')
                    o_options += OPTIONNAL_MSG[1].to_bytes(6, 'big')
                elif size == 18 :
                    o_options += OPTIONNAL_MSG[0].to_bytes(6, 'big')
                    o_options += OPTIONNAL_MSG[1].to_bytes(6, 'big')
                    o_options += OPTIONNAL_MSG[2].to_bytes(6, 'big')                    

            o_options += DHCP_SERVER_IP_MSG.to_bytes(2, 'big') + (int(dut.inst_uoe_dhcp_module_rx.dhcp_siaddr.value)).to_bytes(4, 'big')            #  dhcp_server_ip
            o_options += DHCP_END.to_bytes(1, 'big')   

            if skip_mode == True:
                dut.log.warning(f"DHCP_RX [{_}] ! This message is not destinated to the DHCP client or there is an error : dhcp_rx is in skip mode")
                dut.log.error(f"DHCP_RX [{_}] failure (somthing went wrong check frame [{_}] below )")
                dut.log.error("s_options  : {:<10}  / o_options :  {:<10}".format(s_options.hex(),  o_options.hex()))
                dut.log.error("s_xid      : {:<10}  / o_xid     :  {:<10}".format(hex(xid),  hex(dut.dhcp_xid.value)))
                dut.log.error("s_yiaddr   : {:<10}  / o_yiaddr  :  {:<10}\n".format(hex(s_yiaddr), hex(int(dut.dhcp_network_config.OFFER_IP.value))))
                skip_mode = False
                break
            # Stop signal to end monitoring
            stop_signal =  False
           
            # Validity test
            if (o_options == s_options and 
                dut.dhcp_network_config.OFFER_IP.value == s_yiaddr  and
                s_xid     == dut.dhcp_xid.value

            ):
                if DEBUG == 1:
                    if message_type == NACK :
                        dut.log.info("DHCP_RX [{:02d}] {:<7} {}\n".format(_, "",": server DENIED configuration - DHCP_RX receieved a NACK message"))
                        dut.log.info("DHCP process {:<7} : {}\n".format("", "Restarting the configuration from Discover"))
                        xid = xid +4
                    elif message_type == ACK :
                        dut.log.info("DHCP process {:<7} : {}\n".format("","The configuration is successfull :  Going to bound state after receveing an ACK"))
                        dut.log.info(f"End of simulation\n")
                        await RisingEdge(dut.clk)
                        dut.log.info(f"IP Configuration  parameters are : ")

                        offer_ip    = dut.dhcp_network_config.OFFER_IP.value.integer
                        subnet_mask = dut.dhcp_network_config.SUBNET_MASK.value.integer
                        router_ip   = dut.dhcp_network_config.ROUTER_IP.value.integer
                        server_ip   = dut.dhcp_network_config.SERVER_IP.value.integer

                        dut.log.info("OFFERED IP   :  {:<13} / {:<10}".format(int_to_ip(offer_ip),  (hex(offer_ip))))
                        dut.log.info("ROUTER  IP   :  {:<13} / {:<10}".format(int_to_ip(router_ip), hex(router_ip)))
                        dut.log.info("SERVER  IP   :  {:<13} / {:<10}".format(int_to_ip(server_ip), hex(server_ip)))
                        dut.log.info("SUBNET MASK  :  {:<13} / {:<10}\n".format(int_to_ip(subnet_mask), bin(subnet_mask).count('1')))
                        break 
                    else :
                        dut.log.info("DHCP_RX [{:02d}] {:<7} {}\n".format(_, "",": server responds with an OFFER"))
                        dut.log.info("DHCP process {:<7} : {}\n".format("","configuration is in progress"))
                            
            else:
                dut.log.error(f"DHCP_RX [{_}] failure (somthing went wrong check frame [{_}] below )")
                dut.log.error("s_options  : {:<10}  / o_options :  {:<10}".format(s_options.hex(),  o_options.hex()))
                dut.log.error("s_xid      : {:<10}  / o_xid     :  {:<10}".format(hex(xid),  hex(dut.dhcp_xid.value)))
                dut.log.error("s_yiaddr   : {:<10}  / o_yiaddr  :  {:<10}\n".format(hex(s_yiaddr), hex(int(dut.dhcp_network_config.OFFER_IP.value))))
                if message_type == NACK :
                    xid = xid +4

                simulation_err += 1

    cocotb.log.info("End of handlerSlave")
    
@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                          *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the DHCP module is to manage the DHCP protocol.                                                                                             *\n"
    description += "* It constructs DHCP packets and send it to the udp layer.                                                                                                *\n"
    description += "* It decodes incoming DHCP packets and verifies their content for correct processing.                                                                     *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    # Error variable
    global simulation_err, xid
    simulation_err = 0
    xid = 3
    
    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk100M.start())
    
    # Start reset management
    cocotb.start_soon(handler_reset(dut))

    # Start Initdone coroutine
    cocotb.start_soon(handler_initdone(dut))

    # start coroutines
    h_master = cocotb.start_soon(handler_master(dut))    
    h_slave = cocotb.start_soon(handler_slave(dut))


    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # wait that coroutines are finished
    await h_master
    await h_slave
    
    await Timer(100, units='ns')
   
    # Print simulation results
    if simulation_err >= 1:
        print_rsl = "\n\n\n******************************************************************************************\n"
        print_rsl += f"**                                   There are {simulation_err} errors!                              **\n"
        print_rsl += "******************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
        raise TestFailure("Simulation failed due to errors")
    else:
        print_rsl = "\n\n\n******************************************************************************************\n"
        print_rsl += "**                                        Simulation OK!                               **\n"
        print_rsl += "******************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
