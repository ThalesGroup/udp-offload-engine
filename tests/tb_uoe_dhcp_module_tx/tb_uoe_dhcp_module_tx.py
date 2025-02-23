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
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame)

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

class DhcpState(IntEnum):
    IDLE           = 0
    DISCOVER       = 1
    OFFER          = 2
    REQUEST        = 3
    ACK            = 4
    BOUND          = 5

# Global Parameters
NB_FRAMES          = 20
PAYLOAD_MIN_SIZE   = 240
PAYLOAD_MAX_SIZE   = 264
FRAME_SIZE_MAX     = PAYLOAD_MAX_SIZE
SEED               = 1658406584
DEBUG              = 1

# Variable declarations
LOCAL_IP_ADDR      = 0xC0_A8_0A_04        # local IP addr requested in DISCOVER
LOCAL_MAC_ADDR     = 0x01_23_45_67_89_AB  # Hardware addr
SRC_MAC_ADDR       = 0x11_22_33_44_55_66  # Hardware addr
DEST_MAC_ADDR      = 0xff_ff_ff_ff_ff_ff  # Broadcast
DHCP_SERVER_IP     = 0xC0_A8_01_01        # 192.168.1.1 (example server IP)
DHCP_CLIENT_IP     = 0xC0_A8_01_0A        # 192.168.1.10 (example client IP)
DHCP_ROUTER_IP     = 0xC0_A8_01_0B        # 192.168.1.11 (example Router IP )
DHCP_SERVER_PORT   = 0x00_43              # port dest 67
DHCP_CLIENT_PORT   = 0x00_44              # port src  68
DHCP_FLAGS         = 0x8000               # Broadcast flags

DISCOVER_MSG       = 0x35_01_01           # Tag, length and value for dhcp discover option
REQUEST_MSG        = 0x35_01_03           # Tag, length and value for dhcp request option
DECLINE_MSG        = 0x35_01_04           # Tag, length and value for dhcp decline option
RELEASE_MSG        = 0x35_01_07           # Tag, length and value for dhcp release option
INFORM_MSG         = 0x35_01_08           # Tag, length and value for dhcp inform option
PARAMETER_REQ_MSG  = 0x37_02_01_03        # Tag, length and value for dhcp requested parametters list option

REQUESTED_IP_MSG   = 0x32_04              # Tag  and length for dhcp server option     
DHCP_SERVER_IP_MSG = 0x36_04              # Tag  and length for dhcp server option
DHCP_NETMASK_MSG   = 0x01_04              # Tag  and length for dhcp subnetmask option
DHCP_ROUTER_MSG    = 0x03_04              # Tag  and length for dhcp router option

DHCP_END           = 0xFF                 # Tag  for dhcp end option
DHCP_PAD           = 0x00                 # Tag  for dhcp pad option

TYPE_MSG_LIST      = [DISCOVER_MSG, REQUEST_MSG, DECLINE_MSG, RELEASE_MSG, INFORM_MSG]

# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1

# coroutine to handle Initdone, xid and dhcp_state
async def handlerInitdone(dut):
    """Init done, XID and dhcp_state management"""
    dut.DHCP_STATE.value = DhcpState.IDLE
    dut.dhcp_send_discover.value = 0
    dut.dhcp_send_request.value = 0
    dut.dhcp_network_config.offer_ip.value = 0x0000
    dut.dhcp_network_config.subnet_mask.value = 0x0000
    dut.dhcp_network_config.server_ip.value = 0xFFFFFFFF
    dut.dhcp_network_config.router_ip.value = 0x0000
    dut.dhcp_xid.value = 0x0000
    dut.dhcp_use_ip.value = 0
    dut.dhcp_user_ip_addr.value = 0x0000
    dut.dhcp_user_mac_addr.value = 0x000000
    dut.init_done.value = 0
    await Timer(200, units='ns')
    dut.dhcp_use_ip.value = 1
    dut.dhcp_user_ip_addr.value = LOCAL_IP_ADDR
    dut.dhcp_user_mac_addr.value = LOCAL_MAC_ADDR
    dut.init_done.value = 1

def gen_dhcp_option(dut, message_type):
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
        options += DHCP_PAD.to_bytes(2, 'big')           # padding
        options += DHCP_SERVER_IP_MSG.to_bytes(2, 'big') # server ip option
        options += DHCP_SERVER_IP.to_bytes(4, 'big')     
        options += DHCP_PAD.to_bytes(1, 'big')           # padding

    options     += PARAMETER_REQ_MSG.to_bytes(4, 'big')  # parameter request list option
    options     += DHCP_END.to_bytes(1, 'big')           # End option
    return options

async def handlerMaster(dut):
    """Read data from AXI-Stream bus"""
    # Error variable
    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_dhcp_module_tx.m").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m"), dut.clk, dut.rst, reset_active_level=False)
    dut.log.info(f"Starting  a DHCP configuration process.\n")
    
    # Init random generator
    m_random_ctrl = Random()
    m_random_ctrl.seed(SEED)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)
    DHCP_XID_test = 3521010

    # Data reception
    for _ in range(NB_FRAMES):
        # Generate DHCP frame

        dut.dhcp_send_discover.value = 0
        dut.dhcp_send_request.value = 0      
        msg_type = TYPE_MSG_LIST[_ % 2]
      
        if msg_type == DISCOVER_MSG:  
            DHCP_XID_test                           +=3 
            dut.dhcp_xid.value                      = DHCP_XID_test
            dut.dhcp_state.value                    = DhcpState.DISCOVER
            dut.dhcp_network_config.offer_ip.value  = 0x0000    
            dut.dhcp_send_discover.value            = 1
            dut.dhcp_send_request.value             = 0
          
        elif msg_type == REQUEST_MSG:  
            dut.dhcp_send_discover.value            = 0
            dut.dhcp_network_config.offer_ip.value  = DHCP_CLIENT_IP
            dut.dhcp_network_config.server_ip.value = DHCP_SERVER_IP
            dut.dhcp_state.value                    = DhcpState.REQUEST
            dut.dhcp_send_request.value             = 1    
      
        data = await master.recv()
        data_ctrl = DhcpFrame(
            op=0x01,                      # BOOTPREQUEST
            htype=0x01,                   # Ethernet
            hlen=0x06,                    # MAC address length
            hops=0x00,
            xid=DHCP_XID_test,            # Transaction identifier
            secs=0x00,
            flags=DHCP_FLAGS,             # Broadcast flag
            ciaddr=0x0000,
            yiaddr=0x0000,
            siaddr=0x0000,
            giaddr=0x0000,
            chaddr=LOCAL_MAC_ADDR,
            options=gen_dhcp_option(dut, msg_type)
        )
        data_ctrl = DhcpFrame.__bytes__(data_ctrl)
        
        if data.tdata == data_ctrl:
            dut.log.info(f"A {'DISCOVER' if msg_type == DISCOVER_MSG else 'REQUEST'} message is successfully sent.")
            if DEBUG == 1:    
                dut.log.info(f"Check passed : DHCP_TX frame [{_}] met the expected frame")
        else:
            dut.log.error(f"DHCP_TX [{_}] : failure (somthing went wrong check frame [{_}]  below )")
            dut.log.error(f"DHCP_TX [{_}] : data_ctrl : {data_ctrl.hex()} / data : {data.tdata.hex()} (test)\n")
            simulation_err += 1
        if msg_type == DISCOVER_MSG :
            dut.dhcp_state.value = DhcpState.OFFER
            dut.log.info(f"waiting an OFFER from the server \n")
            await Timer(200, units='ns')    # to simulate offer state 
        elif msg_type == REQUEST_MSG:
            dut.dhcp_state.value = DhcpState.ACK
            dut.log.info(f"waiting an ACK from the server \n")
            await Timer(200, units='ns')    # to simulate ack state
            dut.dhcp_use_ip.value = m_random_ctrl.randint(0,1)
    cocotb.log.info("End of handlerMaster")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the DHCP module tx is to manage the DHCP protocol.                                                                                         *\n"
    description += "* It constructs DHCP packets and send it to the udp layer.                                                                                               *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    # Error variable+
    global simulation_err
    simulation_err = 0

    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    # start clock
    cocotb.start_soon(clk100M.start())

    # start coroutine of reset management
    cocotb.start_soon(handlerReset(dut))

    # start coroutines
    h_init_done = cocotb.start_soon(handlerInitdone(dut))
    h_master    = cocotb.start_soon(handlerMaster(dut))
    
    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # wait that coroutines are finished
    await h_master

    await Timer(100, units='ns')

    if simulation_err >= 1:
        print_rsl = "\n\n\n******************************************************************************************\n"
        print_rsl += "**                                   There are " + str(simulation_err) + " errors !                              **\n"
        print_rsl += "******************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n******************************************************************************************\n"
        print_rsl += "**                                        Simulation OK !                               **\n"
        print_rsl += "******************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
