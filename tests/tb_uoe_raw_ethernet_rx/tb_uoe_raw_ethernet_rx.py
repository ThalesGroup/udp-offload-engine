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

# Ethernet library
from lib import EthFrame

# Global Parameters
NB_FRAMES = 20
MIN_SIZE = 5
MAX_SIZE = 20
SEED = 758962
DEBUG = 1


# Variable declarations
SRC_MAC_ADDR = 0x11_22_33_44_55_66
DEST_MAC_ADDR = 0xaa_bb_cc_dd_ee_ff
ETHERTYPE = 0xABCD


def genRandomTransfer(random_gen):
    """Generation of RAW frame with pseudo-random way"""
    while True:
        size = random_gen.randint(MIN_SIZE, MAX_SIZE)  # Generate random size
        # Building axis frame with ethernet protocole
        tdata = EthFrame(dst_mac_addr=DEST_MAC_ADDR.to_bytes(6, 'big'),
                         src_mac_addr=SRC_MAC_ADDR.to_bytes(6, 'big'),
                         ethertype=ETHERTYPE,
                         payload=random_gen.randbytes(size))
        tdata = tdata.__bytes__()
        tkeep = [1] * len(tdata)  # Generate tkeep
        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
        yield frame


# coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1


# coroutine to handle Slave interface
async def handlerSlave(dut):
    """Sending data frames generated by genRandomTransfer to AXI-Stream bus"""

    # Init source
    logging.getLogger("cocotb.uoe_raw_ethernet_rx.s").setLevel("WARNING")
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    s_random = Random()
    s_random.seed(SEED)
    s_trans = genRandomTransfer(s_random)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Data send
    for _ in range(NB_FRAMES):
        frame = next(s_trans)
        await slave.send(frame)

    cocotb.log.info("End of handlerSlave")


# coroutine to handle Master interface
async def handlerMaster(dut):
    """Read data from AXI-Stream bus"""

    # Error variable
    global simulation_err

    # Init source
    logging.getLogger("cocotb.uoe_raw_ethernet_rx.m").setLevel("WARNING")
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m"), dut.clk, dut.rst, reset_active_level=False)

    # Init random generator
    m_random_ctrl = Random()
    m_random_ctrl.seed(SEED)

    # Data reception
    for _ in range(NB_FRAMES):
        data = await master.recv()
        data_rslt = EthFrame(dst_mac_addr=DEST_MAC_ADDR.to_bytes(6, 'big'),
                             src_mac_addr=SRC_MAC_ADDR.to_bytes(6, 'big'),
                             ethertype=data.tid,
                             payload=data.tdata)

        # Value for test
        m_size = m_random_ctrl.randint(MIN_SIZE, MAX_SIZE)
        m_payload = m_random_ctrl.randbytes(m_size)

        data_ctrl = EthFrame(dst_mac_addr=DEST_MAC_ADDR.to_bytes(6, 'big'),
                             src_mac_addr=SRC_MAC_ADDR.to_bytes(6, 'big'),
                             ethertype=ETHERTYPE,
                             payload=m_payload)

        # Validity test
        if data_ctrl == data_rslt:
            if DEBUG == 1:
                cocotb.log.info(f"RAW_RX [{_}] is OK")
        else:
            cocotb.log.error(f"RAW_RX [{_}] faillure / size {len(data_rslt.payload)}:{len(data_ctrl.payload)}(test)")
            cocotb.log.error(f"Dst_mac_addr : {data_rslt.dst_mac_addr.hex()} / Dst_mac_addr_ctrl : {data_ctrl.dst_mac_addr.hex()}")
            cocotb.log.error(f"Src_mac_addr : {data_rslt.src_mac_addr.hex()} / Src_mac_addr_ctrl : {data_ctrl.src_mac_addr.hex()}")
            cocotb.log.error(f"Ethertype : {hex(data_rslt.ethertype)} / Ethertype_ctrl : {hex(data_ctrl.ethertype)}")
            cocotb.log.error(f"Data : {data_rslt.payload.hex()} / Data_ctrl : {data_ctrl.payload.hex()}")
            simulation_err += 1

    cocotb.log.info("End of handlerMaster")


@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "*  On the receiving side, the RAW Ethernet sub-module manages the removal of the Ethernet header (MAC).                                                  *\n"
    description += "*  The aim is to send random bytes with an Ethernet header and check whether the header has been removed correctly.                                      *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    global simulation_err
    simulation_err = 0

    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    # start clock
    cocotb.start_soon(clk100M.start())
    # start coroutine of reset management
    cocotb.start_soon(handlerReset(dut))

    # start coroutines
    h_slave = cocotb.start_soon(handlerSlave(dut))
    h_master = cocotb.start_soon(handlerMaster(dut))

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # wait that coroutines are finished
    await h_slave
    await h_master

    await Timer(100, units='ns')

    if simulation_err >= 1:
        print_rsl = "\n\n\n********************************************************************************************\n"
        print_rsl += "**                                    There are " + str(simulation_err) + " errors !                               **\n"
        print_rsl += "********************************************************************************************"
        cocotb.log.error(f"{print_rsl}")
    else:
        print_rsl = "\n\n\n********************************************************************************************\n"
        print_rsl += "**                                         Simulation OK !                                **\n"
        print_rsl += "********************************************************************************************"
        cocotb.log.info(f"{print_rsl}")