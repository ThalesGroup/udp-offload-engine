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
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import logging

# DHCP state define in t_dhcp_state
from enum import IntEnum

class DhcpState(IntEnum):
    IDLE          = 0
    DISCOVER      = 1
    OFFER         = 2
    REQUEST       = 3
    ACK           = 4
    BOUND         = 5

# Global Parameters
NB_FRAMES         = 20
PAYLOAD_MIN_SIZE  = 240
PAYLOAD_MAX_SIZE  = 264
SEED              = 1658406584
DEBUG             = 1



# Coroutine to handle Reset
async def handlerReset(dut):
    """Reset management"""
    dut.rst.value = 0
    await Timer(30, units='ns')
    dut.rst.value = 1

# Helper function to check state and log errors
async def check_state(dut, expected_state, state_name):
    """Checks the state of DHCP controller"""
    await RisingEdge(dut.clk)
    global simulation_err
    if dut.DHCP_STATE.value != expected_state:
        simulation_err += 1
        cocotb.log.error(f"Error: Expected {state_name} state, got {DhcpState(int(dut.DHCP_STATE.value)).name}")
    else:
        cocotb.log.info(f"State check passed : Expected DHCP_STATE to be : {state_name}")

# Function to initialize DUT inputs
def init_dut_signals(dut):
    """Initialize DUT inputs"""
    dut.init_done.value = 0
    dut.dhcp_start.value = 0
    dut.dhcp_message_sent.value = 0
    dut.dhcp_offer_sel.value = 0
    dut.dhcp_ack.value = 0
    dut.dhcp_nack.value = 0

# Helper function to check signal state
def check_signal(signal, expected_value, message):
    """Check signal value and log error if needed"""
    global simulation_err
    if signal.value != expected_value:
        simulation_err += 1
        cocotb.log.error(f"Error on {signal.name}: {message}")
    else:
        cocotb.log.info(f"check signal passed: {message} ")

# coroutine to handle Initdone, XID and dhcp_state
async def handlerInitdone(dut):
    """Test the DHCP Controller state machine"""
    init_dut_signals(dut)

    # Check initial state (IDLE)
    await check_state(dut, DhcpState.IDLE, "IDLE")

    # Transition sequence
    transitions = [
        (dut.init_done, 1, 20, None, DhcpState.IDLE, "IDLE", dut.DHCP_SEND_DISCOVER, 0),
        (dut.init_done, 1, 10, None, DhcpState.IDLE, "IDLE", dut.DHCP_SEND_REQUEST,  0),
        (dut.init_done, 1, 30, None, DhcpState.IDLE, "IDLE", dut.DHCP_XID, 0),
        (dut.init_done, 1, 10, None, DhcpState.IDLE, "IDLE", dut.DHCP_STATUS, 0),
        (dut.dhcp_start, 1, 100, None, DhcpState.DISCOVER, "DISCOVER", dut.DHCP_SEND_DISCOVER, 1),
        (dut.dhcp_message_sent, 1, 0, dut.dhcp_message_sent, DhcpState.OFFER, "OFFER", dut.DHCP_STATUS, 1),
        (dut.dhcp_offer_sel, 1, 0, dut.dhcp_offer_sel, DhcpState.REQUEST, "REQUEST", dut.DHCP_SEND_REQUEST, 1),
        (dut.dhcp_message_sent, 1, 0, dut.dhcp_message_sent, DhcpState.ACK, "ACK", dut.DHCP_STATUS, 1),
        (dut.dhcp_nack, 1, 0, dut.dhcp_nack, DhcpState.DISCOVER, "DISCOVER", dut.DHCP_SEND_DISCOVER, 1),
        (dut.dhcp_message_sent, 1, 0, dut.dhcp_message_sent, DhcpState.OFFER, "OFFER", None, None),
        (dut.dhcp_offer_sel, 1, 0, dut.dhcp_offer_sel, DhcpState.REQUEST, "REQUEST", dut.DHCP_SEND_REQUEST, 1),
        (dut.dhcp_message_sent, 1, 0, dut.dhcp_message_sent, DhcpState.ACK, "ACK", None, None),
        (dut.dhcp_ack, 1, 0, dut.dhcp_ack, DhcpState.BOUND, "BOUND", dut.DHCP_STATUS, 3)

    ]

    for sig, val, delay, reset_sig, state, state_name, check_sig, check_val in transitions:
        if delay:
            await Timer(delay, units='ns')
        await RisingEdge(dut.clk)
        sig.value = val
        await RisingEdge(dut.clk)
        if reset_sig:
            reset_sig.value = 0
        await check_state(dut, state, state_name)
        if check_sig:
            check_signal(check_sig, check_val, f"Expected {check_sig._name} to be  {check_val} ")

    cocotb.log.info("End of handlerInitdone")

@cocotb.test()
async def handlermain(dut):
    """Main function for starting coroutines"""

    description = "\n\n**********************************************************************************************************************************************************\n"
    description += "*                                                                    Description                                                                         *\n"
    description += "**********************************************************************************************************************************************************\n"
    description += "* The role of the DHCP module layer is to manage the DHCP protocol.                                                                                       *\n"
    description += "* The role of the DHCP controller is to manage the receiver and the transmitter by controlling the DHCP state.                                        *\n"
    description += "**********************************************************************************************************************************************************\n"

    cocotb.log.info(f"{description}")
    cocotb.log.info("Start coroutines")

    # Error variable
    global simulation_err
    simulation_err = 0

    # Init clock
    clk100M = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk100M.start())

    # Start reset management
    cocotb.start_soon(handlerReset(dut))

    # Start Initdone coroutine
    h_init_done = cocotb.start_soon(handlerInitdone(dut))
    
    # Wait Reset
    await RisingEdge(dut.rst)
    await RisingEdge(dut.clk)

    # Wait for Initdone coroutine to finish
    await h_init_done

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

