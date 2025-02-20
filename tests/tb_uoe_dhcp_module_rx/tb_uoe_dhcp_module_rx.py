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
from cocotb.triggers import RisingEdge, FallingEdge
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
SRC_MAC_ADDR         = 0x11_22_33_44_55_66  # Hardware addrr
DEST_MAC_ADDR        = 0xff_ff_ff_ff_ff_ff  # Broadcast
DHCP_SERVER_IP       = 0xC0_A8_01_01        # 192.168.1.1 (example server IP)
DHCP_CLIENT_IP       = 0xC0_A8_01_0A        # 192.168.1.10 (example client IP)
DHCP_GATEAWAY_IP     = 0xC0_A8_01_0B        # 192.168.1.11 (GIADDR )
DHCP_SERVER_PORT     = 0x00_43              # port src 67
DHCP_CLIENT_PORT     = 0x00_44              # port dest 68
DHCP_XID             = 0x35_65_52_47
DHCP_FLAGS           = 0x8000               # Broadcast flags

OFFER_MSG            = 0x35_01_02           # Tag, length and value for dhcp offer option
ACK_MSG              = 0x35_01_05           # Tag, length and value for dhcp ack option
NACK_MSG             = 0x35_01_06           # Tag, length and value for dhcp nack option
BROADCAST_MSG        = 0x1C_04_FF_FF_FF_FF  # Tag, length and value for dhcp broadcast option
RENEWEL_MSG          = 0x3A_04_00_00_0E_10  # Tag, length and value for dhcp renewing  option
REBINDING_MSG        = 0x3B_04_00_00_1C_20  # Tag, length and value for dhcp rebinfing option

DHCP_END             = 0xFF                 # Tag  for dhcp end option
DHCP_PAD             = 0x00                 # Tag  for dhcp pad option

DHCP_SERVER_IP_MSG   = 0x36_04              # Tag  and length for dhcp server option
DHCP_NETMASK_MSG     = 0x01_04              # Tag  and length for dhcp subnetmask option
DHCP_ROUTER_MSG      = 0x03_04              # Tag  and length for dhcp router option
DHCP_LEASE_TIME_MSG  = 0x33_04              # Tag  and length for dhcp lease time option

OFFER                = 0x02
ACK                  = 0x05
NACK                 = 0x06
Rem_SIZE             = [6, 12, 18]
MSG_LIST             = [OFFER, ACK, NACK]
TYPE_MSG_LIST        = [OFFER_MSG, ACK_MSG, NACK_MSG]
OPTIONNAL_MSG        = [BROADCAST_MSG, RENEWEL_MSG, REBINDING_MSG]


def int_to_ip(ip_int):
    return '.'.join(map(str, ip_int.to_bytes(4, 'big')))

def genDhcpFrame(random_gen):
    """Generation of DHCP frame with pseudo-random but valid options for a DHCP client"""
    # message_type variable
    global message_type   
    while True:
        secs = random_gen.randint(0, 0xFFFF)              #  seconds 
        # Generate valid options
        options = b''
        options +=DHCP_PAD.to_bytes(1, 'big')             #  pad message
       
        if message_type == OFFER:
          options += OFFER_MSG.to_bytes(3, 'big')         #  message OFFER to receive
        
        elif message_type == ACK:
          options += ACK_MSG.to_bytes(3, 'big')           #  message ACK to receive
        
        elif message_type == NACK:
          options += NACK_MSG.to_bytes(3, 'big')          #  message NACK to receive

        if message_type != NACK:            
            # Randomize subnet mask
            #random_netmask = random_gen.randint(0xFF, 0xFFFFFFFF)

            # Randomize subnet mask
            prefix_length  = random_gen.randint(0, 32)
            random_netmask = (0xFFFFFFFF << (32 - prefix_length)) & 0xFFFFFFFF

            options += DHCP_NETMASK_MSG.to_bytes(2, 'big') + random_netmask.to_bytes(4, 'big')
            options += DHCP_ROUTER_MSG.to_bytes(2, 'big') + DHCP_GATEAWAY_IP.to_bytes(4, 'big')
            lease_time = random_gen.randint(300, 86400)
            options += DHCP_LEASE_TIME_MSG.to_bytes(2, 'big') + lease_time.to_bytes(4, 'big')
            size     = DHCP_HEADER_SIZE + len(options)  + SERVER_AND_END_SIZE + Rem_SIZE[random_gen.randint(0,2)]
         
            # Fill remaining bytes with random valid dhcp option
            remaining_size = size - 247 - len(options)
            while( remaining_size > 0):
              options += OPTIONNAL_MSG[int((remaining_size/6)) - 1].to_bytes(6, 'big')
              remaining_size -= 6
        else :
            size = DHCP_HEADER_SIZE + len(options) + SERVER_AND_END_SIZE       
           
        options += DHCP_SERVER_IP_MSG.to_bytes(2, 'big') + DHCP_SERVER_IP.to_bytes(4, 'big')  # Server Identifier
        options += DHCP_END.to_bytes(1, 'big')                                                # End option

        # Create DHCP frame
        tdata = DhcpFrame(
            op=0x02,                                        # BootsReply
            htype=0x01,                                     # Ethernet
            hlen=0x06,                                      # MAC address length
            hops=0x00,
            xid=DHCP_XID,
            secs=secs,
            flags=DHCP_FLAGS,                               # Broadcast flag
            ciaddr=0x0000,
            yiaddr=DHCP_CLIENT_IP if message_type != 0x06 else 0x00000000,
            siaddr=0x0000,
            giaddr=0X0000,
            chaddr=SRC_MAC_ADDR,
            options=options
        )
        tdata = DhcpFrame.__bytes__(tdata)
        tkeep = [1] * len(tdata)
        pay = size.to_bytes(2, 'big') + DHCP_SERVER_IP.to_bytes(4, 'big')
        port_dest = DHCP_CLIENT_PORT
        port_src = DHCP_SERVER_PORT
        tuser = int.from_bytes(port_dest.to_bytes(2, 'big') + port_src.to_bytes(2, 'big') + pay, 'big')
        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=tuser)
        yield frame


# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1

# coroutine to handle Initdone, XID and dhcp_state
async def handlerInitdone(dut):
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)
    """Init done, XID and dhcp_state management"""
    dut.dhcp_state.value = DhcpState.DISCOVER
    dut.DHCP_XID.value = DHCP_XID
    dut.init_done.value = 0
    await Timer(200, units='ns')
    dut.init_done.value = 1
    dut.dhcp_state.value = DhcpState.OFFER

# coroutine to handle Slave interface
async def handlerSlave(dut):
    """Sending data frames generated by genRandomTransfer to AXI-Stream bus"""

    # message_type variable
    global message_type, skip_mode, simulation_err
    dhcp_state = [DhcpState.OFFER, DhcpState.ACK]    
    
    # Init source
    logging.getLogger("cocotb.uoe_dhcp_module_rx.s").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    s_random = Random()
    s_random.seed(SEED) 
    s_trans = genDhcpFrame(s_random)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)
    dut.log.info("DHCP process is at {:<3} : DISCOVER stage".format(""))
    # Data send
    for _ in range(NB_FRAMES):
        

        if _ % 2 == 0:
            message_type = OFFER                                    # OFFER
            
        else:
            message_type = MSG_LIST[s_random.randint(1, 2)]         # ACK or NACK

        frame = next(s_trans)
        await slave.send(frame)

        await RisingEdge(dut.mid.tlast)
        await RisingEdge(dut.clk)                                         

        if message_type == OFFER  :
            dut.dhcp_state.value = DhcpState.REQUEST
            await Timer(200, units='ns')                            # to simulate REQUEST state

        elif message_type == ACK :
            dut.dhcp_state.value = DhcpState.BOUND
            await Timer(200, units='ns')                            # to simulate bound state
           
        elif message_type == NACK :
            dut.dhcp_state.value = DhcpState.DISCOVER
            
            await Timer(200, units='ns')                            # to simulate DISCOVER state
        dut.dhcp_state.value = dhcp_state[(_ % 2) - 1]
        if skip_mode == True:
          dut.log.error("tdata  : {:<10}\n".format(frame.tdata.hex()))
          simulation_err += 1
          skip_mode = False
          break
    cocotb.log.info("End of handlerSlave")


async def monitor_rx_state(dut, stop_signal):
    global skip_mode
    """Coroutine that monitors rx_state as long as stop_signal is not True"""
    while not(stop_signal):
        await RisingEdge(dut.clk)  # Wait for one clock cycle
        if dut.rx_state.value == Dhcp_Rx_State.SKIP:
            skip_mode = True
            break


async def handlerOutput(dut):
    """Read and validate an internal signal directly"""

    # Error variable
    global simulation_err, skip_mode

    # Init random generator
    o_random_ctrl = Random()
    o_random_ctrl.seed(SEED)

    skip_mode = False
    await RisingEdge(dut.rst)  # Wait for reset to complete
    await RisingEdge(dut.clk)  # Synchronize to the clock

    for _ in range(NB_FRAMES):
        
        if _ % 2 == 0 :
            o_type_msg = OFFER
        else:
            o_type_msg = MSG_LIST[o_random_ctrl.randint(1, 2)]

        o_secs = o_random_ctrl.randint(0, 0xFFFF)  # seconds 
        if o_type_msg != NACK:            
            length_option = 29
            prefix_length = o_random_ctrl.randint(0, 32)
            o_netmask     = (0xFFFFFFFF << (32 - prefix_length)) & 0xFFFFFFFF
            o_lease_time  = o_random_ctrl.randint(300, 86400)
            o_size        = DHCP_HEADER_SIZE +  length_option + Rem_SIZE[o_random_ctrl.randint(0,2)]

        else :
            length_option = 11
            o_size = DHCP_HEADER_SIZE + length_option

        o_yiaddr    = (DHCP_CLIENT_IP if o_type_msg != NACK else 0x00000000)
        o_siaddr    = (DHCP_SERVER_IP if o_type_msg != NACK else 0xFFFFFFFF)
        o_xid       = DHCP_XID
        o_router    = DHCP_GATEAWAY_IP


        # Stop signal to end monitoring
        stop_signal =  False
        # Start monitoring rx_state
        cocotb.start_soon(monitor_rx_state(dut, stop_signal))
        
        await FallingEdge(dut.mid.tlast)
        await RisingEdge(dut.clk) # synchronization
        await RisingEdge(dut.clk)
        
        # Read internal and output signals
        frame_size  = dut.frame_size.value
        xid         = dut.DHCP_XID.value
        yiaddr      = dut.dhcp_network_config.offer_ip.value
        subnet_mask = dut.dhcp_subnetmask.value if o_type_msg != ACK else dut.dhcp_network_config.subnet_mask.value
        siaddr      = dut.dhcp_network_config.server_ip.value
        router      = dut.dhcp_router.value if o_type_msg != ACK else dut.dhcp_network_config.router_ip.value
        giaddr      = dut.dhcp_giaddr.value
        type_msg    = dut.dhcp_type_msg.value
        lease_time  = dut.dhcp_lease_time.value

        if skip_mode == True:
          dut.log.warning(f"DHCP_RX [{_}] ! This message is not destinated to the DHCP client or there is an error : dhcp_rx is in skip mode")
          dut.log.error(f"DHCP_RX [{_}] failure (somthing went wrong check frame [{_}] )")
          dut.log.error("s_xid      : {:<10}  / o_xid     :  {:<10}".format(hex(o_xid),  hex(dut.dhcp_xid.value)))
          dut.log.error("s_yiaddr   : {:<10}  / o_yiaddr  :  {:<10}\n".format(hex(o_yiaddr), hex(int(dut.dhcp_network_config.OFFER_IP.value))))
          simulation_err += 1
          
          break
        # Stop signal to end monitoring
        stop_signal =  False            
        
        # Validity test
        if (yiaddr      == o_yiaddr     and
            frame_size  == o_size       and
            xid         == o_xid        and
            siaddr      == o_siaddr     and
            giaddr      == 0x0000       and
            router      == o_router     and
            type_msg    == o_type_msg   and
            lease_time  == o_lease_time and 
            subnet_mask == o_netmask):
                
            if DEBUG == 1:
                if  o_type_msg == OFFER:
                    dut.log.info("DHCP_RX [{:02d}] {:<9} {}".format(_, "",": Server responds with an OFFER"))
                    dut.log.info("DHCP process is at {:<3} : REQUEST stage".format(""))
                elif o_type_msg == ACK:
                    dut.log.info("DHCP_RX [{:02d}] {:<9} {}\n".format(_, "",": Server responds with an ACK"))
                    dut.log.info("DHCP process {:<9} : {}\n".format("","The configuration is successfull :  Going to bound state after receveing an ACK"))
                    dut.log.info(f"IP Configuration  parameters are : ")

                    offer_ip    = dut.dhcp_network_config.OFFER_IP.value.integer
                    subnet_mask = dut.dhcp_network_config.SUBNET_MASK.value.integer
                    router_ip   = dut.dhcp_network_config.ROUTER_IP.value.integer
                    server_ip   = dut.dhcp_network_config.SERVER_IP.value.integer

                    dut.log.info("OFFERED IP  {:<10} :  {:<13} / {:<10}".format("", int_to_ip(offer_ip),  (hex(offer_ip))))
                    dut.log.info("ROUTER  IP  {:<10} :  {:<13} / {:<10}".format("", int_to_ip(router_ip), hex(router_ip)))
                    dut.log.info("SERVER  IP  {:<10} :  {:<13} / {:<10}".format("", int_to_ip(server_ip), hex(server_ip)))
                    dut.log.info("SUBNET MASK {:<10} :  {:<13} / {:<10}\n".format("", int_to_ip(subnet_mask), bin(subnet_mask).count('1')))
                    dut.log.info("DHCP process {:<9} : {}".format("", "Restarting the configuration from Discover"))
                else:
                    dut.log.info("DHCP_RX [{:02d}] {:<9} {}\n".format(_, "",": server responds with a NACK"))
                    dut.log.info("DHCP process {:<9} : {}\n".format("","Server DENIED configuration - DHCP_RX receieved a NACK message"))
                    dut.log.info("DHCP process {:<9} : {}".format("", "Restarting the configuration from Discover"))
                        
        else:
            dut.log.error("failure (something went wrong, check frame number [{}]) (test)".format(_))
            dut.log.error("DHCP_RX [{}] size : {:<10} / o_size       : {:<10}".format(_, hex(frame_size), hex(o_size)))
            dut.log.error("xid               : {:<10} / o_xid        : {:<10}".format(hex(xid), hex(o_xid)))
            dut.log.error("yiaddr            : {:<10} / o_yiaddr     : {:<10}".format(hex(yiaddr), hex(o_yiaddr)))
            dut.log.error("siaddr            : {:<10} / o_siaddr     : {:<10}".format(hex(siaddr), hex(o_siaddr)))
            dut.log.error("router            : {:<10} / o_router     : {:<10}".format(hex(router), hex(o_router)))
            dut.log.error("type_msg          : {:<10} / o_type_msg   : {:<10}".format(hex(type_msg), hex(o_type_msg)))
            dut.log.error("lease_time        : {:<10} / o_lease_time : {:<10}".format(hex(lease_time), hex(o_lease_time)))
            dut.log.error("netmask           : {:<10} / o_netmask    : {:<10}\n".format(hex(subnet_mask), hex(o_netmask)))
            simulation_err += 1
                
    cocotb.log.info("End of handlerOutput")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the DHCP module layer is to manage the DHCP protocol.                                                                                     *\n"
    description += "* It decodes incoming DHCP packets and verifies their content for correct processing.                                                                   *\n"
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

    # start coroutines
    h_init_done = cocotb.start_soon(handlerInitdone(dut))
    h_slave = cocotb.start_soon(handlerSlave(dut))
    h_Output = cocotb.start_soon(handlerOutput(dut))

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # wait that coroutines are finished
    await h_slave
    await h_Output

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
