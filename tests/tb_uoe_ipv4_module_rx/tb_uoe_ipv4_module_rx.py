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


# ==============================================================================================
#     / \
#    /   \
#   /  |  \      NOT WORKING CAUSES FRAGMENTATION
#  /   |   \
# /    .    \
# ==============================================================================================


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
from math import *
import logging

# IPV4 Library
from lib import Ipv4Frame

# Global Parameters
NB_FRAME = 50
SEED = 1658406584
DEBUG = 1

# Variable declaration
LOCAL_IP_ADDR = 0xC0_A8_01_01  # 192.168.1.01
LOCAL_MAC_ADDR = 0x01_23_45_67_89_AB
PROTOCOL_UDP = 0x11
ETHERTYPE_ARP = 0x0806
ETH_IP_ADDR_1 = 0xC0_A8_01_0A  # 192.168.1.10
ETH_IP_ADDR_2 = 0xC0_A8_01_0F  # 192.168.1.15
ETH_IP_ADDR_3 = 0xC0_A8_01_14  # 192.168.1.20
ETH_IP_ADDR_4 = 0xC0_A8_01_19  # 192.168.1.25
ETH_IP_ADDR_LIST = [ETH_IP_ADDR_1, ETH_IP_ADDR_2, ETH_IP_ADDR_3, ETH_IP_ADDR_4]
FRAME_SIZE_1 = 12  # 1 fragment / Small paquet
FRAME_SIZE_2 = 1480  # 1 fragment/ Max size
# FRAME_SIZE_3 = 1481  # 2 fragments / 1480 + 1
# FRAME_SIZE_4 = 2480  # 2 fragments / 1480 + 1000
# FRAME_SIZE_5 = 4000  # 3 fragments / 1480 + 1480 + 1040
# FRAME_SIZE_LIST = [FRAME_SIZE_1, FRAME_SIZE_2, FRAME_SIZE_3, FRAME_SIZE_4, FRAME_SIZE_5]
TTL = 0x55
IPV4_MAX_PACKET_SIZE = 1500
IPV4_MIN_HEADER_SIZE = 20
IPV4_MAX_PAYLOAD_SIZE = IPV4_MAX_PACKET_SIZE - IPV4_MIN_HEADER_SIZE  # 1480
PAYLOAD_SIZE_BYTES = 1480
FRAGMENT_OFFSET_INC = int(PAYLOAD_SIZE_BYTES / 8)


# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1


# coroutine to handle Slave interface
async def handlerSlave(dut):
    """coroutine use to generate Frame IPV4 on Slave interface"""

    # Init source
    logging.getLogger("cocotb.uoe_ipv4_module_rx.s").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    s_ctrl_random = Random()
    s_ctrl_random.seed(SEED)
    s_data_random = Random()
    s_data_random.seed(SEED)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Data send
    for _ in range(NB_FRAME):

        # slave_frame_nb_btes = FRAME_SIZE_LIST[s_ctrl_random.randint(0, 4)]
        slave_frame_nb_btes = s_ctrl_random.randint(FRAME_SIZE_1, FRAME_SIZE_2)
        slave_ip = ETH_IP_ADDR_LIST[s_ctrl_random.randint(0, 3)]

        cocotb.log.info(f"Frame : {_} / Size : {slave_frame_nb_btes}")

        slave_frag_offset = 0

        # s_trans = genRandomTransfer_Ipv4(s_data_random, s_ctrl_random, slave_frag_offset, _)

        for i in range(1, ceil(slave_frame_nb_btes / PAYLOAD_SIZE_BYTES) + 1):
            # Calcul size of payload
            if slave_frame_nb_btes > PAYLOAD_SIZE_BYTES:
                slave_pkt_nb_bytes = PAYLOAD_SIZE_BYTES
                slave_frame_nb_btes = slave_frame_nb_btes - PAYLOAD_SIZE_BYTES
                slave_frag_more = 1
            else:
                slave_pkt_nb_bytes = slave_frame_nb_btes
                slave_frag_more = 0

            cocotb.log.info(f"  packet : {i} / size packet : {slave_pkt_nb_bytes}")

            slave_packet_bytes = s_data_random.randbytes(slave_pkt_nb_bytes)

            # Building axis frame with ethernet ipv4 protocole
            tdata = Ipv4Frame(frame_id=i - 1,
                              sub_protocol=PROTOCOL_UDP,
                              ip_src=slave_ip.to_bytes(4, 'big'),
                              ip_dest=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                              payload=slave_packet_bytes,
                              ttl=TTL,
                              frag_flags=slave_frag_more,
                              frag_offset=slave_frag_offset)
            tdata = Ipv4Frame.__bytes__(tdata)
            if len(tdata) < 50:
                tdata += int(0x00).to_bytes(50 - len(tdata), 'big')
                cocotb.log.info(f"DATA_PADDING : {tdata.hex()}")
            tkeep = [1] * len(tdata)
            cocotb.log.info(f"      len(tdata) : {len(tdata)}")
            frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
            await slave.send(frame)

        slave_frag_offset += FRAGMENT_OFFSET_INC

    cocotb.log.info("End of handlerSlave")


# coroutine to handle Master interface
async def handlerMaster(dut):
    """coroutine used to check generated frame"""

    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_ipv4_module_rx.m").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    m_ctrl_random = Random()
    m_ctrl_random.seed(SEED)
    m_data_random = Random()
    m_data_random.seed(SEED)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Loop to check all Gratuitous ARP
    for _ in range(NB_FRAME):

        # master_frame_nb_btes = FRAME_SIZE_LIST[m_ctrl_random.randint(0, 4)]
        master_frame_nb_btes = m_ctrl_random.randint(FRAME_SIZE_1, FRAME_SIZE_2)
        master_ip = ETH_IP_ADDR_LIST[m_ctrl_random.randint(0, 3)]

        for i in range(1, ceil(master_frame_nb_btes / PAYLOAD_SIZE_BYTES) + 1):
            # Calcul size of payload
            if master_frame_nb_btes > PAYLOAD_SIZE_BYTES:
                master_pkt_nb_bytes = PAYLOAD_SIZE_BYTES
                master_frame_nb_btes = master_frame_nb_btes - PAYLOAD_SIZE_BYTES
                master_frag_more = 1
            else:
                master_pkt_nb_bytes = master_frame_nb_btes
                master_frag_more = 0

            if i == 1:
                master_packet_bytes = m_data_random.randbytes(master_pkt_nb_bytes)
            else:
                master_packet_bytes += m_data_random.randbytes(master_pkt_nb_bytes)

        data = await master.recv()
        if data.tdata == master_packet_bytes:
            if DEBUG == 1:
                cocotb.log.info("IPV4 is valid")
        else:
            cocotb.log.error(f"IPV4 frame : {_}")
            cocotb.log.error(f"     size data : {len(data.tdata)} / size data_ctrl : {len(master_packet_bytes)}")
            simulation_err += 1

    cocotb.log.info("End of handlerMaster")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the ipv4 sub-module is to :                                                                                                                *\n"
    description += "* Manage the IPv4 protocol and its fragmentation features                                                                                                *\n"
    description += "* Partial ICMP protocol management (ping and ping response)                                                                                              *\n"
    description += "* Supports data padding during transmission (if enabled)                                                                                                 *\n"
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
    h_slave = cocotb.start_soon(handlerSlave(dut))
    h_master = cocotb.start_soon(handlerMaster(dut))

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Await RX process
    await h_slave
    await h_master

    await Timer(5, units='us')

    if simulation_err >= 1:
        print_rsl = "\n\n\n*******************************************************************************************\n"
        print_rsl += "**                                   There are " + str(simulation_err) + " errors !                               **\n"
        print_rsl += "*******************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n*******************************************************************************************\n"
        print_rsl += "**                                        Simulation OK !                                **\n"
        print_rsl += "*******************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
