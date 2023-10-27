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
import os
from random import Random

# Global Parameters
NB_FRAMES = 5


# coroutine to handle Reset
async def handlerReset(dut):
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1


# Generator to generate transfer
def genRandomTransfer(random_gen):
    while True:
        size = random_gen.randint(1, 20)
        tdata = random_gen.randbytes(size)
        # tkeep = [random_gen.randint(0,1) for _ in range(size)]
        tkeep = [random_gen.getrandbits(int(int(os.getenv('G_TDATA_WIDTH')) / 8))]
        print(tkeep)
        tuser = [random_gen.getrandbits(int(os.getenv('G_TUSER_WIDTH'))) for _ in range(size)]
        tid = random_gen.getrandbits(int(os.getenv('G_TID_WIDTH')))
        tdest = random_gen.getrandbits(int(os.getenv('G_TDEST_WIDTH')))
        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=tid, tdest=tdest, tuser=tuser)
        print("===========================================================================")
        print(frame)
        yield frame


# coroutine to handle Slave interface
async def handlerSlave(dut):

    # Init source and random generator
    slave = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s"), dut.clk, dut.rst, reset_active_level=False)
    s_random = Random()
    s_random.seed(5)
    s_trans = genRandomTransfer(s_random)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    for _ in range(NB_FRAMES):
        frame = next(s_trans)
        await slave.send(frame)


# coroutine to handle Master interface
async def handlerMaster(dut):

    # Init sink and random generator
    master = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m"), dut.clk, dut.rst, reset_active_level=False)
    m_random = Random()
    m_random.seed(5)

    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    for _ in range(NB_FRAMES):
        data = await master.recv()
        print(data)


# Main coroutine
@cocotb.test()
async def register_test(dut):
    # Clk declaration
    clk100M = Clock(dut.clk, 10, units='ns')

    # Start coroutines
    cocotb.log.info("Start coroutines")
    cocotb.start_soon(clk100M.start())
    cocotb.start_soon(handlerReset(dut))

    h_slave = cocotb.start_soon(handlerSlave(dut))
    h_master = cocotb.start_soon(handlerMaster(dut))

    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    await h_slave
    await h_master
    await Timer(50, units='ns')

    # Generate a random list of value
    # randomlist = random.sample(range(0x00000000, 0x11111111), 64)
    # tuser=[1]

    # cocotb.start_soon(s.write(randomlist,1,tuser=tuser, tkeep=1 ) ) #start writing coroutine ,t_keep and t_data needed if port exist on component

    # await RisingEdge(dut.m_tlast) #await the last value on the m_tdata output
    # await RisingEdge(dut.clk)
    #
    # verif of all value transfered, here verification don't take t_user , t_data and t_keep into account . Also timing isn't concidered
    # for k in range( len(randomlist)):
    # assert randomlist[k]==A[k] , f"erreur :{randomlist[k]}=!{A[k] } "
