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
from math import *
import logging

# IPV4 Library
from lib import Ipv4Frame
from lib import UdpFrame

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
ETHERTYPE_IPV4 = 0x0800
FRAME_SIZE_1 = 12  # 1 fragment / Small paquet
FRAME_SIZE_2 = 1480  # 1 fragment/ Max size
FRAME_SIZE_3 = 1481  # 2 fragments / 1480 + 1
FRAME_SIZE_4 = 2480  # 2 fragments / 1480 + 1000
FRAME_SIZE_5 = 4000  # 3 fragments / 1480 + 1480 + 1040
FRAME_SIZE_LIST = [FRAME_SIZE_1, FRAME_SIZE_2, FRAME_SIZE_3, FRAME_SIZE_4, FRAME_SIZE_5]
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


# coroutine to handle Initdone
async def handlerInitdone(dut):
    """Init done management"""
    dut.init_done.value = 0
    await Timer(400, units='ns')
    dut.init_done.value = 1


# coroutine to handle Slave interface
async def handlerSlave(dut):
    """coroutine use to generate Frame IPV4 on Slave interface"""

    # Init source
    logging.getLogger("cocotb.uoe_ipv4_module_tx.s").setLevel("WARNING")
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

        # slave_nb_bytes = FRAME_SIZE_LIST[s_ctrl_random.randint(0, 4)]
        slave_ip = ETH_IP_ADDR_LIST[s_ctrl_random.randint(0, 3)]

        # slave_nb_bytes = 8 * 5

        # if _ == 10:
        #     slave_nb_bytes = 8 * 5

        slave_nb_bytes = s_ctrl_random.randint(FRAME_SIZE_1, FRAME_SIZE_2)

        cocotb.log.info(f"Frame : {_} / Size : {slave_nb_bytes}")

        slave_packet_bytes = s_data_random.randbytes(slave_nb_bytes)

        tdata = slave_packet_bytes
        tkeep = [1] * len(tdata)
        tid = PROTOCOL_UDP
        tuser = int.from_bytes(slave_nb_bytes.to_bytes(2, 'big') + slave_ip.to_bytes(4, 'big'), 'big')

        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=tid, tdest=None, tuser=tuser)

        await slave.send(frame)

    cocotb.log.info("End of handlerSlave")


# coroutine to handle Master interface
async def handlerMaster(dut):
    """coroutine used to check generated frame"""

    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_ipv4_module_tx.m").setLevel("WARNING")
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
        master_ip = ETH_IP_ADDR_LIST[m_ctrl_random.randint(0, 3)]

        master_frame_nb_btes = m_ctrl_random.randint(FRAME_SIZE_1, FRAME_SIZE_2)

        master_frag_offset = 0

        for i in range(1, 2):  # ceil(master_frame_nb_btes / PAYLOAD_SIZE_BYTES) + 1):
            if master_frame_nb_btes > PAYLOAD_SIZE_BYTES:
                master_pkt_nb_bytes = PAYLOAD_SIZE_BYTES
                master_frame_nb_btes = master_frame_nb_btes - PAYLOAD_SIZE_BYTES
                master_frag_more = 1
            else:
                master_pkt_nb_bytes = master_frame_nb_btes
                master_frag_more = 0

            master_packet_bytes = m_data_random.randbytes(master_pkt_nb_bytes)

            udp_part_ctrl = UdpFrame.from_bytes(master_packet_bytes)

            tdata_ctrl = Ipv4Frame(frame_id=_,
                                   sub_protocol=PROTOCOL_UDP,
                                   ip_src=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                                   ip_dest=master_ip.to_bytes(4, 'big'),
                                   payload=udp_part_ctrl,
                                   ttl=TTL,
                                   frag_flags=master_frag_more,
                                   frag_offset=master_frag_offset)
            tuser_ctrl = master_ip
            tid_ctrl = ETHERTYPE_IPV4
            data_rslt = await master.recv()
            tdata_rslt = Ipv4Frame.from_bytes(data_rslt.tdata)
            udp_part = tdata_rslt.payload
            if tdata_rslt == tdata_ctrl and data_rslt.tuser == tuser_ctrl and data_rslt.tid == tid_ctrl:
                if DEBUG == 1:
                    cocotb.log.info(f"IPV4 frame {_} is valid")
            else:
                cocotb.log.error(f'''IPV4 frame {_} is faillure
    Frame_id : {tdata_rslt.frame_id} / Frame_id_ctrl : {tdata_ctrl.frame_id}
    Sub_protocol : {hex(tdata_rslt.sub_protocol)} / Sub_protocol_ctrl : {hex(tdata_ctrl.sub_protocol)}
    IP_src : {tdata_rslt.ip_src.hex()} / IP_src_ctrl : {tdata_ctrl.ip_src.hex()}
    IP_dest : {tdata_rslt.ip_dest.hex()} / IP_dest_ctrl : {tdata_ctrl.ip_dest.hex()}
    TTL : {hex(tdata_rslt.ttl)} / TTL_ctrl : {hex(tdata_ctrl.ttl)}
    Frag_flags : {hex(tdata_rslt.frag_flags)} / Frag_flags_ctrl : {hex(tdata_ctrl.frag_flags)}
    Frag_offset : {hex(tdata_rslt.frag_offset)} / Frag_offset : {hex(tdata_ctrl.frag_offset)}
    Port_src : {hex(udp_part.src_port)} / Port_src_ctrl : {hex(udp_part_ctrl.src_port)}
    Port_dest : {hex(udp_part.dst_port)} / Port_dest_ctrl : {hex(udp_part_ctrl.dst_port)}
    Data_rslt : {udp_part.payload.hex()} / Data_ctrl : {udp_part_ctrl.payload.hex()}
    Tuser : {hex(data_rslt.tuser)} / Tuser_ctrl : {hex(tuser_ctrl)}
    Tid : {hex(data_rslt.tid)} / Tid : {hex(tid_ctrl)}''')

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
    h_init_done = cocotb.start_soon(handlerInitdone(dut))
    h_slave = cocotb.start_soon(handlerSlave(dut))
    h_master = cocotb.start_soon(handlerMaster(dut))

    # Init Signals
    dut.TTL.value = TTL
    dut.LOCAL_IP_ADDR.value = LOCAL_IP_ADDR

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Await RX process
    await h_slave
    await h_master

    await Timer(1, units='us')

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
