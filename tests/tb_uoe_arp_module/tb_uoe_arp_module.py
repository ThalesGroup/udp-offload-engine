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

# ARP Library
from lib import ArpFrame
from lib import EthFrame

# Global Parameters
NB_FRAME_S_RX = 2
NB_FRAME_IP_MAC_ADDR = 1
ARP_TRYINGS = 3
ARP_TRYINGS_2 = 3
DEBUG = 1

# Variable declaration
LOCAL_IP_ADDR = 0xC0_A8_01_01  # 192.168.1.01
LOCAL_MAC_ADDR = 0x01_23_45_67_89_AB

ETHERTYPE_ARP = 0x0806
ETH_IP_ADDR_1 = 0xC0_A8_01_0A  # 192.168.1.10
ETH_IP_ADDR_2 = 0xC0_A8_01_0F  # 192.168.1.15
ETH_IP_ADDR_3 = 0xC0_A8_01_14  # 192.168.1.20
ETH_MAC_ADDR_1 = 0x11_12_13_14_15_16
ETH_MAC_ADDR_2 = 0x21_22_23_24_25_26
ETH_MAC_ADDR_3 = 0x31_32_33_34_35_36
BROADCAST_MAC_ADDR = 0xFF_FF_FF_FF_FF_FF
ZERO_MAC_ADDR = 0x00_00_00_00_00_00
ARP_OPCODE_REQUEST = 0x0001
ARP_OPCODE_REPLY = 0x0002
STATUS_VALID = 0
STATUS_INVALID = 1


def genArpTrame_to_axis(opcode, mac_src, ip_src, mac_dest, ip_dest):
    """function to generate ARP frame to be sent to arp_module"""
    # Building axis frame with ethernet_arp protocole
    arp_part = ArpFrame(opcode=opcode,
                        sender_hw_addr=mac_src.to_bytes(6, 'big'),
                        sender_protocol_addr=ip_src.to_bytes(4, 'big'),
                        target_hw_addr=mac_dest.to_bytes(6, 'big'),
                        target_protocol_addr=ip_dest.to_bytes(4, 'big'))

    tdata = EthFrame(dst_mac_addr=mac_dest.to_bytes(6, 'big'),
                     src_mac_addr=mac_src.to_bytes(6, 'big'),
                     ethertype=ETHERTYPE_ARP,
                     payload=arp_part)
    tdata = EthFrame.__bytes__(tdata)
    tkeep = [1] * len(tdata)  # Generate tkeep
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
    return frame


def arp_check(data, opcode_ctrl, ip_dest_ctrl, mac_dest_ctrl, indice):
    """function to check if arp frame recepted is valid"""

    # Error variable
    global simulation_err

    # Validity test
    if mac_dest_ctrl == BROADCAST_MAC_ADDR:
        mac_dest_ctrl = ZERO_MAC_ADDR
    data = EthFrame.from_bytes(data)
    data_arp = data.payload
    data_ctrl = ArpFrame(opcode=opcode_ctrl,
                         sender_hw_addr=int(0).to_bytes(6, 'big'),
                         sender_protocol_addr=int(0).to_bytes(4, 'big'),
                         target_hw_addr=mac_dest_ctrl.to_bytes(6, 'big'),
                         target_protocol_addr=ip_dest_ctrl.to_bytes(4, 'big'))

    if data_arp.target_hw_addr == data_ctrl.target_hw_addr and data_arp.target_protocol_addr == data_ctrl.target_protocol_addr:
        if DEBUG == 1:
            if data_arp.opcode == ARP_OPCODE_REQUEST:
                cocotb.log.info("ARP request is OK")
            else:
                cocotb.log.info("ARP reply is OK")
    else:
        if data_arp.opcode == ARP_OPCODE_REQUEST:
            cocotb.log.error(f"ARP request {indice} faillure")
        else:
            cocotb.log.error(f"ARP reply {indice} faillure")
        cocotb.log.error(f"OPCODE : {hex(data_arp.opcode)} / OPCODE_CTRL : {hex(opcode_ctrl)}")
        cocotb.log.error(f"IP_DEST : {data_arp.target_protocol_addr.hex()} / IP_DEST_CTRL : {data_ctrl.target_protocol_addr.hex()}")
        cocotb.log.error(f"MAC_DEST : {data_arp.target_hw_addr.hex()} / MAC_DEST_CTRL : {data_ctrl.target_hw_addr.hex()}")
        simulation_err += 1


# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1


# coroutine to handle Slave interface
async def handlerSlave_rx(dut):
    """coroutine use to generate Frame ARP on Slave interface"""

    # Init source
    logging.getLogger("cocotb.uoe_arp_module.s_rx").setLevel("WARNING")
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
    await RisingEdge(dut.ARP_INIT_DONE)

    # Data send
    await slave.send(genArpTrame_to_axis(opcode=ARP_OPCODE_REQUEST,
                                         mac_src=ETH_MAC_ADDR_2,
                                         ip_src=ETH_IP_ADDR_2,
                                         mac_dest=BROADCAST_MAC_ADDR,
                                         ip_dest=LOCAL_IP_ADDR))

    await slave.send(genArpTrame_to_axis(opcode=ARP_OPCODE_REPLY,
                                         mac_src=ETH_MAC_ADDR_2,
                                         ip_src=ETH_IP_ADDR_2,
                                         mac_dest=ETH_MAC_ADDR_3,
                                         ip_dest=ETH_IP_ADDR_3))

    cocotb.log.info("End of handlerSlave_rx")


# coroutine to handle Slave interface
async def handlerSlave_ip_addr(dut):
    """coroutine used to generate request from arp_table"""

    # Init source
    logging.getLogger("cocotb.uoe_arp_module.s_ip_addr").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_ip_addr"), dut.clk, dut.rst, reset_active_level=False)

    # Init signals
    dut.s_ip_addr_tdata = 0
    dut.s_ip_addr_tvalid = 0

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.ARP_INIT_DONE)

    # Test 1 : MAC_SHAPING Request => ARP_TX / ARP_RX => MAC_SHAPING Return
    # use ETH_IP_ADDR_1 for this test
    tdata = ETH_IP_ADDR_1.to_bytes(4, 'little')  # Generate tdata with ethernet ip address 1
    tkeep = [1] * len(tdata)  # Generate tkeep
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
    await slave.send(frame)

    cocotb.log.info("End of handlerSlave_ip_addr")


# coroutine to handle Master interface
async def handlerMaster_tx(dut):
    """coroutine used to check generated frame"""

    # Init source
    logging.getLogger("cocotb.uoe_arp_module.m_tx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_tx"), dut.clk, dut.rst, reset_active_level=False)

    # Init signal
    dut.m_tx_tready = 0

    await RisingEdge(dut.init_done)

    # Loop to check all Gratuitous ARP
    for _ in range(ARP_TRYINGS):
        data = await master.recv()
        arp_check(data=data.tdata,
                  opcode_ctrl=ARP_OPCODE_REQUEST,
                  ip_dest_ctrl=LOCAL_IP_ADDR,
                  mac_dest_ctrl=0,
                  indice=_)

    # Normal Operati
    # *******************************************************************************
    # Test 1 : MAC_SHAPING Request => ARP_TX / ARP_RX => MAC_SHAPING Return
    # use ETH_IP_ADDR_1 for this test
    data = await master.recv()
    arp_check(data=data.tdata,
              opcode_ctrl=ARP_OPCODE_REQUEST,
              ip_dest_ctrl=ETH_IP_ADDR_1,
              mac_dest_ctrl=BROADCAST_MAC_ADDR,
              indice=ARP_TRYINGS + 1)

    # Test 2 : ARP_RX Request => ARP TX Reply and MAC_SHAPING Return
    # use ETH_IP_ADDR_2 for this test
    data = await master.recv()
    arp_check(data=data.tdata,
              opcode_ctrl=ARP_OPCODE_REPLY,
              ip_dest_ctrl=ETH_IP_ADDR_2,
              mac_dest_ctrl=ETH_MAC_ADDR_2,
              indice=ARP_TRYINGS + 2)

    # Test 1 : MAC_SHAPING Request => ARP_TX / ARP_RX => MAC_SHAPING Return
    # use ETH_IP_ADDR_1 for this test (Repeat)
    for _ in range(ARP_TRYINGS_2 - 1):
        data = await master.recv()
        arp_check(data=data.tdata,
                  opcode_ctrl=ARP_OPCODE_REQUEST,
                  ip_dest_ctrl=ETH_IP_ADDR_1,
                  mac_dest_ctrl=BROADCAST_MAC_ADDR,
                  indice=ARP_TRYINGS + ARP_TRYINGS_2)

    cocotb.log.info("End of handlerMaster_tx")


# coroutine to handle Master interface
async def handlerMaster_ip_mac_addr(dut):
    """coroutine used to check received data transmit to arp_table"""

    # Error variable
    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_arp_module.m_ip_mac_addr").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_ip_mac_addr"), dut.clk, dut.rst, reset_active_level=False)

    # Init signal
    dut.m_ip_mac_addr_tready = 0

    await RisingEdge(dut.init_done)

    for _ in range(2):
        data = await master.recv()
        mac_addr = int.from_bytes(data.tdata[4:10], 'big').to_bytes(6, 'little')
        ip_addr = int.from_bytes(data.tdata[0:4], 'big').to_bytes(4, 'little')
        if _ == 0:
            if mac_addr == ETH_MAC_ADDR_2.to_bytes(6, 'big') and ip_addr == ETH_IP_ADDR_2.to_bytes(4, 'big') and data.tuser == STATUS_VALID:
                if DEBUG == 1:
                    cocotb.log.info("M_IP_MAC_ADDR is OK")
            else:
                cocotb.log.error(f"M_IP_MAC_ADDR faillure")
                cocotb.log.error(f"MAC_ADDR : {mac_addr.hex()} / MAC_ADDR_CTRL : {ETH_MAC_ADDR_2.to_bytes(6, 'big').hex()}")
                cocotb.log.error(f"IP_ADDR : {ip_addr.hex()} / IP_ADDR_CTRL : {ETH_IP_ADDR_2.to_bytes(4, 'big').hex()}")
                cocotb.log.error(f"STATUS : {data.tuser}")
                simulation_err += 1
        else:
            if mac_addr == ZERO_MAC_ADDR.to_bytes(6, 'big') and ip_addr == ETH_IP_ADDR_1.to_bytes(4, 'big') and data.tuser == STATUS_INVALID:
                if DEBUG == 1:
                    cocotb.log.info("M_IP_MAC_ADDR is OK")
            else:
                cocotb.log.error(f"M_IP_MAC_ADDR faillure")
                cocotb.log.error(f"MAC_ADDR : {mac_addr.hex()} / MAC_ADDR_CTRL : {ZERO_MAC_ADDR.to_bytes(6, 'big').hex()}")
                cocotb.log.error(f"IP_ADDR : {ip_addr.hex()} / IP_ADDR_CTRL : {ETH_IP_ADDR_1.to_bytes(4, 'big').hex()}")
                cocotb.log.error(f"STATUS : {data.tuser}")
                simulation_err += 1

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

    # Start RX process
    h_slave_rx = cocotb.start_soon(handlerSlave_rx(dut))
    h_slave_ip_addr = cocotb.start_soon(handlerSlave_ip_addr(dut))
    h_master_tx = cocotb.start_soon(handlerMaster_tx(dut))
    h_master_ip_mac_addr = cocotb.start_soon(handlerMaster_ip_mac_addr(dut))

    # Update signals to initializate ARP_MODULE
    dut.init_done = 0
    dut.ARP_TRYINGS = ARP_TRYINGS
    dut.ARP_RX_TEST_LOCAL_IP_CONFLICT = 0
    dut.ARP_GRATUITOUS_REQ = 0
    dut.ARP_RX_TARGET_IP_FILTER = 0x00
    dut.ARP_TIMEOUT_MS = 2
    dut.local_ip_addr = LOCAL_IP_ADDR
    dut.local_mac_addr = LOCAL_MAC_ADDR

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    for _ in range(5):
        await RisingEdge(dut.clk)

    # Stimulis
    dut.init_done = 1

    await RisingEdge(dut.ARP_INIT_DONE)

    # Await RX process
    await h_slave_rx
    await h_slave_ip_addr
    await h_master_tx
    await h_master_ip_mac_addr

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
