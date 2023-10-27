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
from cocotb.binary import BinaryValue
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame)
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiLiteRam

# Others
import os
import random
from random import randbytes
from random import Random
import logging

from lib.pkg_tb_uoe_core import *

# Global Parameters
DEBUG = 1
NB_FRAME_UDP_TX = 100
NB_FRAME_UDP_RX = 100
NB_FRAMES_RAW = 100

MIN_SIZE_RAW = 20
MAX_SIZE_RAW = 30

# UDP_SEED_1 = 1658406584
UDP_SEED_1 = 1658406587
# UDP_SEED_2 = 2027250568
UDP_SEED_2 = 2027250569

RAW_SEED_1 = 928374615
RAW_SEED_2 = 1327347126

LOCAL_IP_ADDR = 0xC0_A8_01_01
LOCAL_MAC_ADDR = 0x01_23_45_67_89_AB

LOCAL_MAC_ADDR_LSB = (LOCAL_MAC_ADDR & BinaryValue('1' * 32))
LOCAL_MAC_ADDR_LSB = LOCAL_MAC_ADDR_LSB.to_bytes(4, 'little')
LOCAL_MAC_ADDR_MSB = (LOCAL_MAC_ADDR & (BinaryValue('1' * 16) << 32)) >> 32
LOCAL_MAC_ADDR_MSB = LOCAL_MAC_ADDR_MSB.to_bytes(4, 'little')

PAYLOAD_SIZE_MIN = 5
PAYLOAD_SIZE_MAX = 20


# *************************************************************************************************************************************
#                                                               RST
# *************************************************************************************************************************************


# coroutine to handle Reset
async def handlerReset_RX(dut):
    dut.rst_rx.value = 1
    await Timer(30, units='ns')
    dut.rst_rx.value = 0


# coroutine to handle Reset
async def handlerReset_TX(dut):
    dut.rst_tx.value = 1
    await Timer(30, units='ns')
    dut.rst_tx.value = 0


# coroutine to handle Reset
async def handlerReset_UOE(dut):
    dut.rst_uoe.value = 1
    await Timer(30, units='ns')
    dut.rst_uoe.value = 0


# coroutine to activate PHY_LAYER_RDY
async def handlerPhy_Layer_Rdy(dut):

    dut.PHY_LAYER_RDY = 0
    await Timer(400, units='ns')
    dut.PHY_LAYER_RDY = 1


# *************************************************************************************************************************************
#                                                               ARP
# *************************************************************************************************************************************


# coroutine to handle Slave_Axi interface
async def handlerSlave_AXI(dut):

    # Init source and random generator
    logging.getLogger("cocotb.wrapped_uoe_core.s_axi").setLevel("WARNING")
    slave = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk_uoe, dut.rst_uoe, reset_active_level=True)

    # Init signals
    dut.s_axi_awaddr = BinaryValue('Z' * 8)
    dut.s_axi_awvalid = BinaryValue('Z')
    dut.s_axi_wdata = BinaryValue('Z' * 32)
    dut.s_axi_wvalid = BinaryValue('Z')
    dut.s_axi_wstrb = BinaryValue('Z' * 4)
    dut.s_axi_araddr = 0x00000000

    # Wait Reset
    await FallingEdge(dut.rst_uoe)

    # Read Version Register
    await slave.read(MAIN_REG_VERSION, 4)

    # Config Address
    ADDRESS = MAIN_REG_LOCAL_MAC_ADDR_LSB
    DATA = LOCAL_MAC_ADDR_LSB
    await slave.write(ADDRESS, DATA)

    ADDRESS = MAIN_REG_LOCAL_MAC_ADDR_MSB
    DATA = LOCAL_MAC_ADDR_MSB
    await slave.write(ADDRESS, DATA)

    ADDRESS = MAIN_REG_LOCAL_IP_ADDR
    DATA = LOCAL_IP_ADDR.to_bytes(4, 'little')
    await slave.write(ADDRESS, DATA)

    ADDRESS = MAIN_REG_ARP_CONFIGURATION
    DATA = ARP_CONFIGURATION
    await slave.write(ADDRESS, DATA)

    # Enable Interrupt for init done
    ADDRESS = MAIN_REG_INTERRUPT_ENABLE
    DATA = int(1).to_bytes(4, 'little')
    await slave.write(ADDRESS, DATA)

    ADDRESS = MAIN_REG_CONFIG_DONE
    DATA = int(1).to_bytes(4, 'little')
    await slave.write(ADDRESS, DATA)

    # Check end of initialisation
    await RisingEdge(dut.INTERRUPT)

    # Clear interrupt
    ADDRESS = MAIN_REG_INTERRUPT_CLEAR
    DATA = int(1).to_bytes(4, 'little')
    await slave.write(ADDRESS, DATA)


# coroutine init to handle Slave_ARP_TABLE
async def handlerSlave_ARP_TABLE(dut):

    # Init source
    dut.s_axi_arp_table_awaddr = 0
    dut.s_axi_arp_table_awvalid = 0
    dut.s_axi_arp_table_wdata = 0
    dut.s_axi_arp_table_wvalid = 0
    dut.s_axi_arp_table_bready = 1
    dut.s_axi_arp_table_araddr = 0
    dut.s_axi_arp_table_arvalid = 0
    dut.s_axi_arp_table_rready = 1


# *************************************************************************************************************************************
#                                                               UDP
# *************************************************************************************************************************************


# coroutine to handle Slave_UDP_TX interface
async def handlerSlave_udp_tx(dut):

    dut.s_udp_tx_tdata = 0
    dut.s_udp_tx_tvalid = 0
    dut.s_udp_tx_tlast = 0
    dut.s_udp_tx_tkeep = 0

    logging.getLogger("cocotb.wrapped_uoe_core.s_udp_tx").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_udp_tx"), dut.clk_uoe, dut.rst_uoe, reset_active_level=True)

    udp_tx_ctrl_rand_gen = Random()
    udp_tx_ctrl_rand_gen.seed(UDP_SEED_1)
    udp_tx_data_rand_gen = Random()
    udp_tx_data_rand_gen.seed(UDP_SEED_1 + 1)

    await FallingEdge(dut.rst_uoe)
    await RisingEdge(dut.clk_uoe)

    await RisingEdge(dut.interrupt)

    await Timer(10, units='us')

    for i in range(NB_FRAME_UDP_TX):

        udp_tx_port_dest = ETH_PORT_LIST[udp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_tx_port_src = ETH_PORT_LIST[udp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_tx_nb_bytes = udp_tx_ctrl_rand_gen.randint(ETH_SIZE_MIN, ETH_SIZE_MAX)
        udp_tx_ipx = udp_tx_ctrl_rand_gen.randint(0, len(ETH_IP_LIST) - 1)
        udp_tx_ip = ETH_IP_LIST[udp_tx_ipx]

        if i >= 40 and i < 60:
            udp_tx_nb_bytes = ETH_SIZE_RATE

        if DEBUG == 1:
            cocotb.log.info(f"(TX) Send UDP Frame : {i}")

        frame = generateFrame_UDP_TX(random_gen=udp_tx_data_rand_gen,
                                     size=udp_tx_nb_bytes,
                                     dest=udp_tx_port_dest,
                                     src=udp_tx_port_src,
                                     ip=udp_tx_ip)
        await slave.send(frame)

    cocotb.log.info("handlerSlave_udp_tx end")


async def handlerMaster_udp_rx(dut):

    global simulation_err

    logging.getLogger("cocotb.wrapped_uoe_core.m_udp_rx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_udp_rx"), dut.clk_uoe, dut.rst_uoe, reset_active_level=True)

    udp_rx_ctrl_rand_gen = Random()
    udp_rx_ctrl_rand_gen.seed(UDP_SEED_2)
    udp_rx_data_rand_gen = Random()
    udp_rx_data_rand_gen.seed(UDP_SEED_2 + 1)

    await FallingEdge(dut.rst_uoe)
    await RisingEdge(dut.clk_uoe)

    for i in range(NB_FRAME_UDP_RX):

        data = await master.recv()

        udp_rx_port_dest = ETH_PORT_LIST[udp_rx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_rx_port_src = ETH_PORT_LIST[udp_rx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_rx_nb_bytes = udp_rx_ctrl_rand_gen.randint(ETH_SIZE_MIN, ETH_SIZE_MAX)
        udp_rx_idx = udp_rx_ctrl_rand_gen.randint(0, len(ETH_IP_LIST) - 1)
        udp_rx_ip = ETH_IP_LIST[udp_rx_idx]

        if i >= 40 and i < 60:
            udp_rx_nb_bytes = ETH_SIZE_RATE

        data_test = generateFrame_UDP_TX(random_gen=udp_rx_data_rand_gen,
                                         size=udp_rx_nb_bytes,
                                         dest=udp_rx_port_dest,
                                         src=udp_rx_port_src,
                                         ip=udp_rx_ip)

        if data_test == data:
            if DEBUG == 1:
                cocotb.log.info(f"(RX) UDP [{i}] is OK")
        else:
            cocotb.log.error(f"(RX) UDP [{i}] faillure / size {len(data.tdata)}:{len(data_test.tdata)}(test)")
            cocotb.log.error(f"    Data : {data.tdata.hex()}")
            cocotb.log.error(f"    User : {hex(data.tuser)}")
            cocotb.log.error(f"    Data_test : {data_test.tdata.hex()}")
            cocotb.log.error(f"    User_test : {hex(data_test.tuser)}")
            simulation_err += 1

    cocotb.log.info("handlerMaster_udp_rx end")


# *************************************************************************************************************************************
#                                                               RAW
# *************************************************************************************************************************************


# coroutine to handle Slave interface
async def handlerSlave_raw_tx(dut):
    """Sending data frames generated by genRandomTransfer to AXI-Stream bus"""

    global h_slave_udp_rx

    # Init source
    logging.getLogger("cocotb.wrapped_uoe_core.s_raw_tx").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_raw_tx"), dut.clk_uoe, dut.rst_uoe, reset_active_level=True)

    # Init random generator
    raw_tx_random = Random()
    raw_tx_random.seed(RAW_SEED_2)

    s_trans = generateFrame_RAW_TX(random_gen=raw_tx_random,
                                   min_size=MIN_SIZE_RAW,
                                   max_size=MAX_SIZE_RAW)

    await RisingEdge(dut.rst_uoe)
    await RisingEdge(dut.clk_uoe)

    await h_slave_udp_rx
    await Timer(2, units='us')

    # Data send
    for i in range(NB_FRAMES_RAW):
        frame = next(s_trans)
        await slave.send(frame)
        dut.s_raw_tx_tvalid.value = 0

        if DEBUG == 1:
            cocotb.log.info(f"(TX) Send RAW Frame : {i}")

    cocotb.log.info("handlerSlave_raw_tx end")


# coroutine to handle Master interface
async def handlerMaster_raw_rx(dut):
    """Read data from AXI-Stream bus"""

    # Error variable
    global simulation_err

    # Init source
    logging.getLogger("cocotb.wrapped_uoe_core.m_raw_rx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_raw_rx"), dut.clk_uoe, dut.rst_uoe, reset_active_level=True)

    # Init random generator
    m_raw_rx_data = Random()
    m_raw_rx_data.seed(RAW_SEED_1)

    await FallingEdge(dut.rst_uoe)
    await RisingEdge(dut.clk_uoe)

    # Data reception
    for _ in range(NB_FRAMES_RAW):
        data = await master.recv()
        data = data.tdata

        # Value for test
        m_size = m_raw_rx_data.randint(MIN_SIZE_RAW, MAX_SIZE_RAW)

        data_ctrl = m_raw_rx_data.randbytes(m_size)
        # Validity test
        if data_ctrl == data:
            if DEBUG == 1:
                cocotb.log.info(f"(RX) RAW [{_}] is OK")
        else:
            cocotb.log.error(f"(RX) RAW [{_}] faillure / size {len(data)}:{len(data_ctrl)}(test)")
            cocotb.log.error(f"Data : {data.hex()} / Data_ctrl : {data_ctrl.hex()}")
            simulation_err += 1

    cocotb.log.info("handlerMaster_raw_rx end")


# *************************************************************************************************************************************
#                                                               EXT
# *************************************************************************************************************************************


async def handlerSlave_ext_tx(dut):

    logging.getLogger("cocotb.wrapped_uoe_core.s_ext_tx").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_ext_tx"), dut.clk_rx, dut.rst_tx, reset_active_level=True)


async def handlerMaster_ext_rx(dut):

    logging.getLogger("cocotb.wrapped_uoe_core.m_ext_rx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_ext_rx"), dut.clk_rx, dut.rst_rx, reset_active_level=True)

    dut.m_ext_rx_tready.value = 1


# *************************************************************************************************************************************
#                                                               MAC
# *************************************************************************************************************************************


# coroutine to handle Slave_MAC_RX interface
async def handlerSlave_mac_rx(dut):

    # Init source
    dut.s_mac_rx_tdata = 0
    dut.s_mac_rx_tvalid = 0
    dut.s_mac_rx_tlast = 0
    dut.s_mac_rx_tkeep = 0
    dut.s_mac_rx_tuser = 0

    arp_cnt = 0
    udp_rx_frame_id = 0

    # Global variable
    global arp_tx_reply_en
    global arp_tx_reply_idx

    logging.getLogger("cocotb.wrapped_uoe_core.s_mac_rx").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_mac_rx"), dut.clk_rx, dut.rst_rx, reset_active_level=True)

    udp_rx_ctrl_rand_gen = Random()
    udp_rx_ctrl_rand_gen.seed(UDP_SEED_2)
    udp_rx_data_rand_gen = Random()
    udp_rx_data_rand_gen.seed(UDP_SEED_2 + 1)
    raw_rx_ctrl = Random()
    raw_rx_ctrl.seed(RAW_SEED_1)
    raw_rx_data = Random()
    raw_rx_data.seed(RAW_SEED_1)
    eth_rx_ctrl = Random()
    eth_rx_ctrl.seed(RAW_SEED_1)
    eth_rx_data = Random()
    eth_rx_data.seed(RAW_SEED_1)

    await FallingEdge(dut.rst_rx)
    await RisingEdge(dut.clk_rx)

    while arp_cnt != len(ETH_IP_LIST):
        if arp_tx_reply_en == 1:
            if DEBUG == 1:
                cocotb.log.info(f"(RX) ARP REPLY")
            s_mac_addr_dest = ETH_MAC_LIST[arp_tx_reply_idx]
            s_ip_addr_dest = ETH_IP_LIST[arp_tx_reply_idx]

            frame = generateFrame_ARP_v2(opcode=ARP_OPCODE_REPLY,
                                         mac_src=s_mac_addr_dest,
                                         mac_dest=LOCAL_MAC_ADDR,
                                         ip_src=s_ip_addr_dest,
                                         ip_dest=LOCAL_IP_ADDR,
                                         padding_en=True)
            await slave.send(frame)
            arp_cnt = arp_cnt + 1
        await RisingEdge(dut.clk_rx)

    # Write ARP Request
    frame = generateFrame_ARP_v2(opcode=ARP_OPCODE_REQUEST,
                                 mac_src=ETH_MAC_ADDR_5,
                                 mac_dest=BROADCAST_MAC_ADDR,
                                 ip_src=ETH_IP_ADDR_5,
                                 ip_dest=LOCAL_IP_ADDR,
                                 padding_en=True)
    await slave.send(frame)

    if DEBUG == 1:
        cocotb.log.info(f"(RX) ARP REQUEST")

    for i in range(NB_FRAME_UDP_RX):

        udp_rx_port_dest = ETH_PORT_LIST[udp_rx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_rx_port_src = ETH_PORT_LIST[udp_rx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
        udp_rx_nb_bytes = udp_rx_ctrl_rand_gen.randint(ETH_SIZE_MIN, ETH_SIZE_MAX)
        udp_rx_idx = udp_rx_ctrl_rand_gen.randint(0, len(ETH_IP_LIST) - 1)

        if udp_rx_frame_id >= 40 and udp_rx_frame_id < 60:
            udp_rx_nb_bytes = ETH_SIZE_RATE

        frame = generateFrame_IPV4(random_gen=udp_rx_data_rand_gen,
                                   mac_src=ETH_MAC_LIST[udp_rx_idx],
                                   ip_src=ETH_IP_LIST[udp_rx_idx],
                                   mac_dest=LOCAL_MAC_ADDR,
                                   ip_dest=LOCAL_IP_ADDR,
                                   protocole=PROTOCOL_UDP,
                                   frame_id=udp_rx_frame_id,
                                   port_src=udp_rx_port_src,
                                   port_dest=udp_rx_port_dest,
                                   nb_bytes=udp_rx_nb_bytes)
        await slave.send(frame)

        if DEBUG == 1:
            cocotb.log.info(f"(RX) UDP {i}")

        udp_rx_frame_id += 1

    global h_master_mac_tx

    await h_master_mac_tx
    await Timer(2, units='us')

    for i in range(NB_FRAMES_RAW):

        raw_rx_mac_dest = ETH_MAC_LIST[raw_rx_ctrl.randint(0, 3)]

        frame = generateFrame_RAW_RX(random_gen=raw_rx_data,
                                     min_size=MIN_SIZE_RAW,
                                     max_size=MAX_SIZE_RAW,
                                     dest=raw_rx_mac_dest,
                                     src=LOCAL_MAC_ADDR)

        await slave.send(frame)

        if DEBUG == 1:
            cocotb.log.info(f"(RX) RAW {i}")

    cocotb.log.info("handlerSlave_mac_rx end")


# coroutine to handle Master_MAC_TX interface
async def handlerMaster_mac_tx(dut):

    dut.m_mac_tx_tready = 0
    dut.m_mac_tx_tlast = 0
    dut.m_mac_tx_tkeep = BinaryValue('Z' * 8)
    dut.m_mac_tx_tdata = BinaryValue('Z' * 64)

    arp_tx_ctrl_rand_gen = Random()
    arp_tx_ctrl_rand_gen.seed(UDP_SEED_1)
    udp_tx_ctrl_rand_gen = Random()
    udp_tx_ctrl_rand_gen.seed(UDP_SEED_1)
    udp_tx_data_rand_gen = Random()
    udp_tx_data_rand_gen.seed(UDP_SEED_1 + 1)
    raw_tx_random = Random()
    raw_tx_random.seed(RAW_SEED_2)

    global simulation_err

    global arp_tx_reply_idx
    global arp_tx_reply_en

    arp_tx_reply_en = 0
    arp_tx_reply_idx = 0
    arp_tx_addr_know = BinaryValue('0' * 4)
    udp_tx_frame_id = 0

    await FallingEdge(dut.rst_tx)
    await RisingEdge(dut.clk_tx)

    logging.getLogger("cocotb.wrapped_uoe_core.m_mac_tx").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_mac_tx"), dut.clk_tx, dut.rst_tx, reset_active_level=True)

    arp_part_ctrl = ArpFrame(opcode=ARP_OPCODE_REQUEST,
                             sender_hw_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                             sender_protocol_addr=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                             target_hw_addr=ZERO_MAC_ADDR.to_bytes(6, 'big'),
                             target_protocol_addr=LOCAL_IP_ADDR.to_bytes(4, 'big'))

    data_test = EthFrame(dst_mac_addr=BROADCAST_MAC_ADDR.to_bytes(6, 'big'),
                         src_mac_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                         ethertype=ETHERTYPE_ARP,
                         payload=arp_part_ctrl)

    for _ in range(ARP_TRYINGS):
        data = await master.recv()

        data_rslt = EthFrame.from_bytes(data.tdata)
        arp_part = data_rslt.payload

        dut.m_mac_tx_tready = 0
        if data_test == data_rslt:
            if DEBUG == 1:
                cocotb.log.info(f"(TX) ARP TRYING [{_}] is OK")
        else:
            cocotb.log.error(f"(TX) ARP TRYING [{_}] faillure")
            cocotb.log.error(f"    mac_src     : {data_rslt.dst_mac_addr.hex()} & mac_src_ctrl : {data_test.dst_mac_addr.hex()}")
            cocotb.log.error(f"    mac_dest    : {data_rslt.src_mac_addr.hex()} & mac_dest_ctrl : {data_test.src_mac_addr.hex()}")
            cocotb.log.error(f"    ethertype   : {hex(data_rslt.ethertype)} & ethertype_ctrl : {hex(data_test.ethertype)}")
            cocotb.log.error(f"    mac_src_arp : {arp_part.sender_hw_addr.hex()} & mac_src_arp_ctrl : {arp_part_ctrl.sender_hw_addr}")
            cocotb.log.error(f"    mac_dst_arp : {arp_part.target_hw_addr.hex()} & mac_dst_arp_ctrl : {arp_part_ctrl.target_hw_addr.hex()}")
            cocotb.log.error(f"    ip_src_arp  : {arp_part.sender_protocol_addr.hex()} & ip_src_arp_ctrl : {arp_part_ctrl.sender_protocol_addr.hex()}")
            cocotb.log.error(f"    ip_dst_arp  : {arp_part.target_protocol_addr.hex()} & ip_dst_arp_ctrl : {arp_part_ctrl.target_protocol_addr.hex()}")
            cocotb.log.error(f"    opcode_arp  : {hex(arp_part.opcode)} & opcode_arp_ctrl : {hex(arp_part_ctrl.opcode)}")
            simulation_err += 1

    index_udp_trans = 0
    index_raw_trans = 0

    while index_udp_trans != NB_FRAME_UDP_TX or index_raw_trans != NB_FRAMES_RAW:
        data = await master.recv()
        dut.m_mac_tx_tready = 0
        data_rslt = EthFrame.from_bytes(data.tdata)
        m_ethertype = data_rslt.ethertype

        if m_ethertype <= ETHERTYPE_RAW_MAX:
            index_raw_trans += 1
            if DEBUG == 1:
                cocotb.log.info(f"(TX) ETHERTYPE : {hex(m_ethertype)} (RAW)")

            raw_tx_size = raw_tx_random.randint(MIN_SIZE_RAW, MAX_SIZE_RAW)

            data_ctrl = EthFrame(dst_mac_addr=BROADCAST_MAC_ADDR.to_bytes(6, 'big'),
                                 src_mac_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                 ethertype=ETHERTYPE_RAW,
                                 payload=raw_tx_random.randbytes(raw_tx_size),)

            if data_rslt == data_ctrl:
                if DEBUG == 1:
                    cocotb.log.info("(TX) RAW is Ok")
            else:
                cocotb.log.error(f"(TX)RAW_RX [{_}] faillure / size {len(data_rslt.payload)}:{len(data_ctrl.payload)}(test)")
                cocotb.log.error(f"    Dst_mac_addr : {data_rslt.dst_mac_addr.hex()} / Dst_mac_addr_ctrl : {data_ctrl.dst_mac_addr.hex()}")
                cocotb.log.error(f"    Src_mac_addr : {data_rslt.src_mac_addr.hex()} / Src_mac_addr_ctrl : {data_ctrl.src_mac_addr.hex()}")
                cocotb.log.error(f"    Ethertype    : {hex(data_rslt.ethertype)} / Ethertype_ctrl : {hex(data_ctrl.ethertype)}")
                cocotb.log.error(f"    Data         : {data_rslt.payload.hex()} / Data_ctrl : {data_ctrl.payload.hex()}")
                simulation_err += 1

        elif m_ethertype == ETHERTYPE_IPV4:
            index_udp_trans += 1
            ipv4_part = data_rslt.payload
            udp_part = ipv4_part.payload
            if DEBUG == 1:
                cocotb.log.info(f"(TX) ETHERTYPE : {hex(m_ethertype)} (IPV4)")
            udp_tx_port_dest = ETH_PORT_LIST[udp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
            udp_tx_port_src = ETH_PORT_LIST[udp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
            udp_tx_nb_bytes = udp_tx_ctrl_rand_gen.randint(ETH_SIZE_MIN, ETH_SIZE_MAX)
            udp_tx_idx = udp_tx_ctrl_rand_gen.randint(0, len(ETH_IP_LIST) - 1)

            if udp_tx_frame_id >= 40 and udp_tx_frame_id < 60:
                udp_tx_nb_bytes = ETH_SIZE_RATE

            if udp_tx_nb_bytes == 0:
                eth_nb_bytes = udp_tx_data_rand_gen.randint(1, ETH_PAYLOAD_MAX_SIZE)
            else:
                eth_nb_bytes = udp_tx_nb_bytes

            udp_part_ctrl = UdpFrame(src_port=udp_tx_port_src,
                                     dst_port=udp_tx_port_dest,
                                     payload=udp_tx_data_rand_gen.randbytes(eth_nb_bytes))

            ipv4_part_ctrl = Ipv4Frame(frame_id=udp_tx_frame_id,
                                       sub_protocol=PROTOCOL_UDP,
                                       ip_src=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                                       ip_dest=ETH_IP_LIST[udp_tx_idx].to_bytes(4, 'big'),
                                       payload=udp_part)

            data_test = EthFrame(dst_mac_addr=ETH_MAC_LIST[udp_tx_idx].to_bytes(6, 'big'),
                                 src_mac_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                 ethertype=ETHERTYPE_IPV4,
                                 payload=ipv4_part)

            if data_test == data_rslt:
                if DEBUG == 1:
                    cocotb.log.info(f"(TX) IPV4_UDP is OK")
            else:
                cocotb.log.error(f"(TX) IPV4_UDP faillure")
                cocotb.log.error(f"    mac_src      : {data_rslt.dst_mac_addr.hex()} & mac_src_ctrl : {data_test.dst_mac_addr.hex()}")
                cocotb.log.error(f"    mac_dest     : {data_rslt.src_mac_addr.hex()} & mac_dest_ctrl : {data_test.src_mac_addr.hex()}")
                cocotb.log.error(f"    ethertype    : {hex(data_rslt.ethertype)} & ethertype_ctrl : {hex(data_test.ethertype)}")
                cocotb.log.error(f"    frame_id     : {hex(ipv4_part.frame_id)} & frame_id_ctrl : {hex(ipv4_part_ctrl.frame_id)}")
                cocotb.log.error(f"    protocole    : {hex(ipv4_part.sub_protocol)} & protocole_ctrl : {hex(ipv4_part_ctrl.sub_protocol)}")
                cocotb.log.error(f"    ip_src_ipv4  : {ipv4_part.ip_src.hex()} & ip_src_ipv4 : {ipv4_part_ctrl.ip_src.hex()}")
                cocotb.log.error(f"    ip_dest_ipv4 : {ipv4_part.ip_dest.hex()} & ip_dest_ipv4 : {ipv4_part_ctrl.ip_dest.hex()}")
                cocotb.log.error(f"    port_src     : {hex(udp_part.src_port)} & port_src_ctrl : {hex(udp_part_ctrl.src_port)}")
                cocotb.log.error(f"    port_dest    : {hex(udp_part.dst_port)} & port_dest_ctrl : {hex(udp_part_ctrl.dst_port)}")
                cocotb.log.error(f"    data         : {udp_part.payload.hex()} & data_ctrl : {udp_part_ctrl.payload.hex()}")
                simulation_err += 1

            udp_tx_frame_id += 1

        elif m_ethertype == ETHERTYPE_ARP:
            if DEBUG == 1:
                cocotb.log.info(f"(TX) ETHERTYPE : {hex(m_ethertype)} (ARP)")
            arp_part_ctrl = data_rslt.payload
            arp_opcode = arp_part.opcode

            if arp_opcode == ARP_OPCODE_REQUEST:
                if DEBUG == 1:
                    cocotb.log.info(f"  ARP_OCCODE : {hex(arp_opcode)} (REQUEST)")
                if arp_tx_addr_know != BinaryValue('1' * len(ETHERTYPE_LIST)):
                    while True:
                        udp_tx_port_dest = ETH_PORT_LIST[arp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
                        udp_tx_port_src = ETH_PORT_LIST[arp_tx_ctrl_rand_gen.randint(0, len(ETH_PORT_LIST) - 1)]
                        udp_tx_nb_bytes = arp_tx_ctrl_rand_gen.randint(ETH_SIZE_MIN, ETH_SIZE_MAX)
                        arp_tx_idx = arp_tx_ctrl_rand_gen.randint(0, len(ETH_IP_LIST) - 1)
                        arp_tx_ip = ETH_IP_LIST[arp_tx_idx]
                        mask = (1 << arp_tx_idx)
                        if arp_tx_addr_know & mask == 0:
                            break

                    # Memorize ARP Request reception
                    arp_tx_addr_know = arp_tx_addr_know | mask

                    arp_part_ctrl_request = ArpFrame(opcode=ARP_OPCODE_REQUEST,
                                                     sender_hw_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                                     sender_protocol_addr=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                                                     target_hw_addr=0x00_00_00_00_00_00.to_bytes(6, 'big'),
                                                     target_protocol_addr=arp_tx_ip.to_bytes(4, 'big'))

                    data_test_arp_request = EthFrame(dst_mac_addr=BROADCAST_MAC_ADDR.to_bytes(6, 'big'),
                                                     src_mac_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                                     ethertype=ETHERTYPE_ARP,
                                                     payload=arp_part_ctrl)

                    if data_test_arp_request == data_rslt:
                        if DEBUG == 1:
                            cocotb.log.info(f"  ARP REQUEST is OK")
                    else:
                        cocotb.log.error(f"  ARP REQUEST faillure")
                        cocotb.log.error(f"    mac_src     : {data_rslt.dst_mac_addr.hex()} & mac_src_ctrl     : {data_test_arp_request.dst_mac_addr.hex()}")
                        cocotb.log.error(f"    mac_dest    : {data_rslt.src_mac_addr.hex()} & mac_dest_ctrl    : {data_test_arp_request.src_mac_addr.hex()}")
                        cocotb.log.error(f"    ethertype   : {hex(data_rslt.ethertype)} & ethertype_ctrl   : {hex(data_test_arp_request.ethertype)}")
                        cocotb.log.error(f"    mac_src_arp : {arp_part.sender_hw_addr.hex()} & mac_src_arp_ctrl : {arp_part_ctrl_request.sender_hw_addr.hex()}")
                        cocotb.log.error(f"    mac_dst_arp : {arp_part.target_hw_addr.hex()} & mac_dst_arp_ctrl : {arp_part_ctrl_request.target_hw_addr.hex()}")
                        cocotb.log.error(f"    ip_src_arp  : {arp_part.sender_protocol_addr.hex()} & ip_src_arp_ctrl  : {arp_part_ctrl_request.sender_protocol_addr.hex()}")
                        cocotb.log.error(f"    ip_dst_arp  : {arp_part.target_protocol_addr.hex()} & ip_dst_arp_ctrl  : {arp_part_ctrl_request.target_protocol_addr.hex()}")
                        cocotb.log.error(f"    opcode_arp  : {hex(arp_part.opcode)} & opcode_arp_ctrl  : {hex(arp_part_ctrl_request.opcode)}")
                        simulation_err += 1

                    arp_tx_reply_en = 1
                    arp_tx_reply_idx = arp_tx_idx
                    await RisingEdge(dut.clk_tx)
                    arp_tx_reply_en = 0

                else:
                    cocotb.log.error(f"  ARP address isn't know : {bin(arp_tx_addr_know)}")
                    cocotb.log.error(f"    mac_src     : {data_rslt.dst_mac_addr.hex()}")
                    cocotb.log.error(f"    mac_dest    : {data_rslt.src_mac_addr.hex()}")
                    cocotb.log.error(f"    ethertype   : {hex(data_rslt.ethertype)}")
                    cocotb.log.error(f"    mac_src_arp : {arp_part.sender_hw_addr.hex()}")
                    cocotb.log.error(f"    mac_dst_arp : {arp_part.target_hw_addr.hex()}")
                    cocotb.log.error(f"    ip_src_arp  : {arp_part.sender_protocol_addr.hex()}")
                    cocotb.log.error(f"    ip_dst_arp  : {arp_part.target_protocol_addr.hex()}")
                    cocotb.log.error(f"    opcode_arp  : {hex(arp_part.opcode)}")

            if arp_opcode == ARP_OPCODE_REPLY:
                if DEBUG == 1:
                    cocotb.log.info(f"  ARP_OCCODE : {arp_opcode} (REPLY)")

                arp_part_ctrl_reply = ArpFrame(opcode=ARP_OPCODE_REPLY,
                                               sender_hw_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                               sender_protocol_addr=LOCAL_IP_ADDR.to_bytes(4, 'big'),
                                               target_hw_addr=ETH_MAC_ADDR_5.to_bytes(6, 'big'),
                                               target_protocol_addr=ETH_IP_ADDR_5.to_bytes(4, 'big'))

                data_test_arp_reply = EthFrame(dst_mac_addr=ETH_MAC_ADDR_5.to_bytes(6, 'big'),
                                               src_mac_addr=LOCAL_MAC_ADDR.to_bytes(6, 'big'),
                                               ethertype=ETHERTYPE_ARP,
                                               payload=arp_part_ctrl)

                if data_test == data_rslt:
                    if DEBUG == 1:
                        cocotb.log.info(f"  ARP (REPLY) is OK")
                else:
                    cocotb.log.error(f"  ARP REPLY faillure")
                    cocotb.log.error(f"    mac_src     : {data_rslt.dst_mac_addr.hex()} & mac_src_ctrl     : {data_test_arp_reply.dst_mac_addr.hex()}")
                    cocotb.log.error(f"    mac_dest    : {data_rslt.src_mac_addr.hex()} & mac_dest_ctrl    : {data_test_arp_reply.src_mac_addr.hex()}")
                    cocotb.log.error(f"    ethertype   : {hex(data_rslt.ethertype)} & ethertype_ctrl   : {hex(data_test_arp_reply.ethertype)}")
                    cocotb.log.error(f"    mac_src_arp : {arp_part.sender_hw_addr.hex()} & mac_src_arp_ctrl : {arp_part_ctrl_reply.sender_hw_addr.hex()}")
                    cocotb.log.error(f"    mac_dst_arp : {arp_part.target_hw_addr.hex()} & mac_dst_arp_ctrl : {arp_part_ctrl_reply.target_hw_addr.hex()}")
                    cocotb.log.error(f"    ip_src_arp  : {arp_part.sender_protocol_addr.hex()} & ip_src_arp_ctrl  : {arp_part_ctrl_reply.sender_protocol_addr.hex()}")
                    cocotb.log.error(f"    ip_dst_arp  : {arp_part.target_protocol_addr.hex()} & ip_dst_arp_ctrl  : {arp_part_ctrl_reply.target_protocol_addr.hex()}")
                    cocotb.log.error(f"    opcode_arp  : {hex(arp_part.opcode)} & opcode_arp_ctrl  : {hex(arp_part_ctrl_reply.opcode)}")
                    simulation_err += 1

    cocotb.log.info("handlerMaster_mac_tx end")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of this module is to send and receive data over an Ethernet link using UDP and IPV4 protocols.                                                *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    # Error variable
    global simulation_err
    simulation_err = 0

    # start coroutines of reset management
    cocotb.start_soon(handlerReset_TX(dut))
    cocotb.start_soon(handlerReset_RX(dut))
    cocotb.start_soon(handlerReset_UOE(dut))

    # Start process
    global h_slave_udp_rx
    global h_master_mac_tx

    h_slave_axi = cocotb.start_soon(handlerSlave_AXI(dut))
    h_master_mac_tx = cocotb.start_soon(handlerMaster_mac_tx(dut))
    h_slave_mac_rx = cocotb.start_soon(handlerSlave_mac_rx(dut))
    h_phy_layer_rdy = cocotb.start_soon(handlerPhy_Layer_Rdy(dut))
    h_slave_ext = cocotb.start_soon(handlerSlave_ext_tx(dut))
    h_master_ext = cocotb.start_soon(handlerMaster_ext_rx(dut))
    h_slave_raw = cocotb.start_soon(handlerSlave_raw_tx(dut))
    h_master_raw = cocotb.start_soon(handlerMaster_raw_rx(dut))
    h_slave_arp_table = cocotb.start_soon(handlerSlave_ARP_TABLE(dut))
    h_slave_udp_tx = cocotb.start_soon(handlerSlave_udp_tx(dut))
    h_slave_udp_rx = cocotb.start_soon(handlerMaster_udp_rx(dut))

    # Wait Reset
    await FallingEdge(dut.rst_rx)
    await RisingEdge(dut.clk_rx)

    await h_master_raw
    await Timer(5, units='us')

    if simulation_err >= 1:
        print_rsl = "\n\n\n**************************************************************************************\n"
        print_rsl += "**                                There are " + str(simulation_err) + " errors !                             **\n"
        print_rsl += "**************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n**************************************************************************************\n"
        print_rsl += "**                                      Simulation OK !                             **\n"
        print_rsl += "**************************************************************************************"
        cocotb.log.info(f"{print_rsl}")
