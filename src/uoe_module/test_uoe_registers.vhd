-- Copyright (c) 2022-2024 THALES. All Rights Reserved
--
-- Licensed under the SolderPad Hardware License v 2.1 (the "License");
-- you may not use this file except in compliance with the License, or,
-- at your option. You may obtain a copy of the License at
--
-- https://solderpad.org/licenses/SHL-2.1/
--
-- Unless required by applicable law or agreed to in writing, any
-- work distributed under the License is distributed on an "AS IS"
-- BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
-- either express or implied. See the License for the specific
-- language governing permissions and limitations under the
-- License.
--
-- File subject to timestamp TSP22X5365 Thales, in the name of Thales SIX GTS France, made on 10/06/2022.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library common;
use work.package_uoe_registers.all;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity test_uoe_registers is
  port(
    ----------------------
    -- AXI4-Lite bus
    ----------------------
    S_AXI_ACLK                                  : in  std_logic;                                       -- Global clock signal
    S_AXI_ARESET                                : in  std_logic;                                       -- Global reset signal synchronous to clock S_AXI_ACLK
    S_AXI_AWADDR                                : in  std_logic_vector(7 downto 0);                    -- Write address (issued by master, accepted by Slave)
    S_AXI_AWVALID                               : in  std_logic_vector(0 downto 0);                    -- Write address valid: this signal indicates that the master is signalling valid write address and control information.
    S_AXI_AWREADY                               : out std_logic_vector(0 downto 0);                    -- Write address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_WDATA                                 : in  std_logic_vector(31 downto 0);                   -- Write data (issued by master, accepted by slave)
    S_AXI_WVALID                                : in  std_logic_vector(0 downto 0);                    -- Write valid: this signal indicates that valid write data and strobes are available.
    S_AXI_WSTRB                                 : in  std_logic_vector(3 downto 0);                    -- Write strobes: WSTRB[n:0] signals when HIGH, specify the byte lanes of the data bus that contain valid information
    S_AXI_WREADY                                : out std_logic_vector(0 downto 0);                    -- Write ready: this signal indicates that the slave can accept the write data.
    S_AXI_BRESP                                 : out std_logic_vector(1 downto 0);                    -- Write response: this signal indicates the status of the write transaction.
    S_AXI_BVALID                                : out std_logic_vector(0 downto 0);                    -- Write response valid: this signal indicates that the channel is signalling a valid write response.
    S_AXI_BREADY                                : in  std_logic_vector(0 downto 0);                    -- Response ready: this signal indicates that the master can accept a write response.
    S_AXI_ARADDR                                : in  std_logic_vector(7 downto 0);                    -- Read address (issued by master, accepted by Slave)
    S_AXI_ARVALID                               : in  std_logic_vector(0 downto 0);                    -- Read address valid: this signal indicates that the channel is signalling valid read address and control information.
    S_AXI_ARREADY                               : out std_logic_vector(0 downto 0);                    -- Read address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_RDATA                                 : out std_logic_vector(31 downto 0);                   -- Read data (issued by slave)
    S_AXI_RRESP                                 : out std_logic_vector(1 downto 0);                    -- Read response: this signal indicates the status of the read transfer.
    S_AXI_RVALID                                : out std_logic_vector(0 downto 0);                    -- Read valid: this signal indicates that the channel is signalling the required read data.
    S_AXI_RREADY                                : in  std_logic_vector(0 downto 0);                    -- Read ready: this signal indicates that the master can accept the read data and response information.

    ----------------------
    -- Input data for registers
    ----------------------
    -- RO Registers
    GEN_TEST_DURATION_LSB                       : in  std_logic_vector(31 downto 0);                   -- Duration time to generate all data (LSB)
    GEN_TEST_DURATION_MSB                       : in  std_logic_vector(31 downto 0);                   -- Duration time to generate all data (MSB)
    CHK_TEST_DURATION_LSB                       : in  std_logic_vector(31 downto 0);                   -- Duration time to received all data (LSB)
    CHK_TEST_DURATION_MSB                       : in  std_logic_vector(31 downto 0);                   -- Duration time to received all data (MSB)
    TX_RM_CNT_BYTES_LSB                         : in  std_logic_vector(31 downto 0);                   -- Value of the bytes counter registered when trigger is asserted (LSB)
    TX_RM_CNT_BYTES_MSB                         : in  std_logic_vector(31 downto 0);                   -- Value of the bytes counter registered when trigger is asserted (MSB)
    TX_RM_CNT_CYCLES_LSB                        : in  std_logic_vector(31 downto 0);                   -- Value of the clock counter registered when trigger is asserted (LSB)
    TX_RM_CNT_CYCLES_MSB                        : in  std_logic_vector(31 downto 0);                   -- Value of the clock counter registered when trigger is asserted (MSB)
    RX_RM_CNT_BYTES_LSB                         : in  std_logic_vector(31 downto 0);                   -- Value of the bytes counter registered when trigger is asserted (LSB)
    RX_RM_CNT_BYTES_MSB                         : in  std_logic_vector(31 downto 0);                   -- Value of the bytes counter registered when trigger is asserted (MSB)
    RX_RM_CNT_CYCLES_LSB                        : in  std_logic_vector(31 downto 0);                   -- Value of the clock counter registered when trigger is asserted (LSB)
    RX_RM_CNT_CYCLES_MSB                        : in  std_logic_vector(31 downto 0);                   -- Value of the clock counter registered when trigger is asserted (MSB)
    -- WO Registers
    TX_RM_INIT_COUNTER_IN                       : in  std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    RX_RM_INIT_COUNTER_IN                       : in  std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    -- Irq WO Registers
    IRQ_GEN_DONE_CLEAR_IN                       : in  std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_CLEAR_IN          : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_IN          : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_CLEAR_IN            : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_CLEAR_IN             : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_CLEAR_IN             : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_CLEAR_IN             : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_CLEAR_IN             : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_CLEAR_IN                       : in  std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_CLEAR_IN                   : in  std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_CLEAR_IN                   : in  std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_CLEAR_IN                   : in  std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_CLEAR_IN          : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_IN          : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_CLEAR_IN            : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_CLEAR_IN             : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_CLEAR_IN             : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_CLEAR_IN             : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_CLEAR_IN             : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_CLEAR_IN             : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_CLEAR_IN         : in  std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_CLEAR_IN             : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_CLEAR_IN         : in  std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_GEN_DONE_SET_IN                         : in  std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_SET_IN            : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_SET_IN            : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_SET_IN              : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_SET_IN               : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_SET_IN               : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_SET_IN               : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_SET_IN               : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_SET_IN                         : in  std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_SET_IN                     : in  std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_SET_IN                     : in  std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_SET_IN                     : in  std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_SET_IN            : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_SET_IN            : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_SET_IN              : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_SET_IN               : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_SET_IN               : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_SET_IN               : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_SET_IN               : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_SET_IN               : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_SET_IN           : in  std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_SET_IN               : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_SET_IN           : in  std_logic;                                       -- Counter reach the maximum size of the counter
    -- Irq RO Registers
    IRQ_GEN_DONE_STATUS                         : in  std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_STATUS            : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_STATUS            : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_STATUS              : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_STATUS               : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_STATUS               : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_STATUS               : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_STATUS               : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_STATUS                         : in  std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_STATUS                     : in  std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_STATUS                     : in  std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_STATUS                     : in  std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_STATUS            : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_STATUS            : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_STATUS              : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_STATUS               : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_STATUS               : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_STATUS               : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_STATUS               : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_STATUS               : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_STATUS           : in  std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_STATUS               : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_STATUS           : in  std_logic;                                       -- Counter reach the maximum size of the counter

    ----------------------
    -- Registers output data
    ----------------------
    -- RW Registers
    LOOPBACK_MAC_EN                             : out std_logic;                                       -- Enable Loopback on MAC interface
    LOOPBACK_UDP_EN                             : out std_logic;                                       -- Enable Loopback on UDP interface
    GEN_ENABLE                                  : out std_logic;                                       -- Generator Enable
    GEN_FRAME_SIZE_TYPE                         : out std_logic;                                       -- Generator Frame size type ('0' : Static, '1' : Dynamic Pseudo Random)
    CHK_ENABLE                                  : out std_logic;                                       -- Checker Enable
    CHK_FRAME_SIZE_TYPE                         : out std_logic;                                       -- Checker Frame size type ('0' : Static, '1' : Dynamic Pseudo Random)
    GEN_NB_FRAMES                               : out std_logic_vector(15 downto 0);                   -- Number of frames to generate (if 0, frames are generated endlessly)
    GEN_FRAME_SIZE_STATIC                       : out std_logic_vector(15 downto 0);                   -- Frame size used in static mode
    GEN_RATE_NB_TRANSFERS                       : out std_logic_vector(7 downto 0);                    -- Number of transfers allow during a time window
    GEN_RATE_WINDOW_SIZE                        : out std_logic_vector(7 downto 0);                    -- Size of the time window (Period)
    GEN_MON_TIMEOUT_VALUE                       : out std_logic_vector(15 downto 0);                   -- Timeout value used for the axis monitoring
    CHK_NB_FRAMES                               : out std_logic_vector(15 downto 0);                   -- Number of frames to generate (if 0, frames are generated endlessly)
    CHK_FRAME_SIZE_STATIC                       : out std_logic_vector(15 downto 0);                   -- Frame size used in static mode
    CHK_MON_TIMEOUT_VALUE                       : out std_logic_vector(15 downto 0);                   -- Timeout value used for the axis monitoring
    LB_GEN_DEST_PORT                            : out std_logic_vector(15 downto 0);                   -- Destination port use for generated frames and loopback
    LB_GEN_SRC_PORT                             : out std_logic_vector(15 downto 0);                   -- Source port use for generated frames and loopback
    LB_GEN_DEST_IP_ADDR                         : out std_logic_vector(31 downto 0);                   -- Destination IP Address use for generated frames and loopback
    CHK_LISTENING_PORT                          : out std_logic_vector(15 downto 0);                   -- Listening port of integrated checker
    TX_RM_BYTES_EXPT_LSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (LSB)
    TX_RM_BYTES_EXPT_MSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (MSB)
    RX_RM_BYTES_EXPT_LSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (LSB)
    RX_RM_BYTES_EXPT_MSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (MSB)
    -- WO Registers
    TX_RM_INIT_COUNTER_OUT                      : out std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    RX_RM_INIT_COUNTER_OUT                      : out std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    -- WO Pulses Registers
    REG_TX_RATE_METER_CTRL_WRITE                : out std_logic;
    REG_RX_RATE_METER_CTRL_WRITE                : out std_logic;
    -- Irq RW Registers
    IRQ_GEN_DONE_ENABLE                         : out std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_ENABLE            : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_ENABLE            : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_ENABLE              : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_ENABLE               : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_ENABLE               : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_ENABLE               : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_ENABLE               : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_ENABLE                         : out std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_ENABLE                     : out std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_ENABLE                     : out std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_ENABLE                     : out std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_ENABLE            : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_ENABLE            : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_ENABLE              : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_ENABLE               : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_ENABLE               : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_ENABLE               : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_ENABLE               : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_ENABLE               : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_ENABLE           : out std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_ENABLE               : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_ENABLE           : out std_logic;                                       -- Counter reach the maximum size of the counter
    -- Irq WO Registers
    IRQ_GEN_DONE_CLEAR_OUT                      : out std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_CLEAR_OUT         : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_OUT         : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_CLEAR_OUT           : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_CLEAR_OUT            : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_CLEAR_OUT            : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_CLEAR_OUT            : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_CLEAR_OUT            : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_CLEAR_OUT                      : out std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_CLEAR_OUT                  : out std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_CLEAR_OUT                  : out std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_CLEAR_OUT                  : out std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_CLEAR_OUT         : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_OUT         : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_CLEAR_OUT           : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_CLEAR_OUT            : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_CLEAR_OUT            : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_CLEAR_OUT            : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_CLEAR_OUT            : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_CLEAR_OUT            : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_CLEAR_OUT        : out std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_CLEAR_OUT            : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_CLEAR_OUT        : out std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_GEN_DONE_SET_OUT                        : out std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY_SET_OUT           : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID_SET_OUT           : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR_SET_OUT             : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR_SET_OUT              : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR_SET_OUT              : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR_SET_OUT              : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR_SET_OUT              : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE_SET_OUT                        : out std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA_SET_OUT                    : out std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE_SET_OUT                    : out std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST_SET_OUT                    : out std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY_SET_OUT           : out std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID_SET_OUT           : out std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR_SET_OUT             : out std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR_SET_OUT              : out std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR_SET_OUT              : out std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR_SET_OUT              : out std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR_SET_OUT              : out std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE_SET_OUT              : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW_SET_OUT          : out std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE_SET_OUT              : out std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW_SET_OUT          : out std_logic;                                       -- Counter reach the maximum size of the counter
    -- Irq WO Pulses Registers
    REG_INTERRUPT_CLEAR_WRITE                   : out std_logic;
    REG_INTERRUPT_SET_WRITE                     : out std_logic

  );
end test_uoe_registers;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of test_uoe_registers is


  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------
  -- Set new value on register according to strobe, old data and mask
  function set_reg_val (signal   old_reg   : in std_logic_vector(31 downto 0);
                        signal   wr_strobe : in std_logic_vector(31 downto 0);
                        signal   wr_data   : in std_logic_vector(31 downto 0);
                        constant reg_mask  : in std_logic_vector(31 downto 0)) return std_logic_vector is
    variable new_reg: std_logic_vector(31 downto 0) := old_reg;
  begin

    -- Loop on all bits of register
    for i in 31 downto 0 loop
      if (wr_strobe(i) = '1') and (reg_mask(i) = '1') then
        new_reg(i) := wr_data(i);
      end if;
    end loop;

    return new_reg;
  end function set_reg_val;


  --------------------------------------------
  -- CONSTANTS
  --------------------------------------------
  -- Define the size of each register by masking all unused bits
  constant C_REG_GEN_CHK_CONTROL                 : std_logic_vector(31 downto 0):="00000000000000000000000000111111";
  constant C_REG_GEN_FRAME                       : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_GEN_RATE                        : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_GEN_MONITOR                     : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_CHK_FRAME                       : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_CHK_MONITOR                     : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_LB_GEN_UDP_PORT                 : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_LB_GEN_DEST_IP_ADDR             : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_CHK_UDP_PORT                    : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_TX_RM_BYTES_EXPT_LSB            : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_TX_RM_BYTES_EXPT_MSB            : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_RX_FM_BYTES_EXPT_LSB            : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_RX_RM_BYTES_EXPT_MSB            : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_INTERRUPT_ENABLE                : std_logic_vector(31 downto 0):="00000000011111111111111111111111";
  constant C_REG_TX_RATE_METER_CTRL              : std_logic_vector(31 downto 0):="00000000000000000000000000000001";
  constant C_REG_RX_RATE_METER_CTRL              : std_logic_vector(31 downto 0):="00000000000000000000000000000001";
  constant C_REG_INTERRUPT_CLEAR                 : std_logic_vector(31 downto 0):="00000000011111111111111111111111";
  constant C_REG_INTERRUPT_SET                   : std_logic_vector(31 downto 0):="00000000011111111111111111111111";



  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  -- AXI4-Lite signals
  signal axi_wr_init                 : std_logic;
  signal axi_rd_init                 : std_logic;
  signal axi_awvalid                 : std_logic;
  signal axi_wvalid                  : std_logic;

  signal s_axi_bvalid_i              : std_logic_vector(0 downto 0);
  signal s_axi_awready_i             : std_logic_vector(0 downto 0);
  signal s_axi_wready_i              : std_logic_vector(0 downto 0);

  signal s_axi_rvalid_i              : std_logic_vector(0 downto 0);
  signal s_axi_arready_i             : std_logic_vector(0 downto 0);

  -- Internal write transactions
  signal wr_req                      : std_logic;
  signal wr_req_r                    : std_logic;
  signal wr_addr                     : std_logic_vector(7 downto 0);
  signal wr_data                     : std_logic_vector(31 downto 0);
  signal wr_strobe                   : std_logic_vector(31 downto 0);
  signal bad_wr_addr                 : std_logic;

  -- Internal read transactions
  signal rd_req                      : std_logic;
  signal rd_req_r                    : std_logic;
  signal rd_addr                     : std_logic_vector(7 downto 0);
  signal rd_data                     : std_logic_vector(31 downto 0);
  signal bad_rd_addr                 : std_logic;

  -- Write registers
  signal reg_gen_chk_control_int                : std_logic_vector(31 downto 0);
  signal reg_gen_frame_int                      : std_logic_vector(31 downto 0);
  signal reg_gen_rate_int                       : std_logic_vector(31 downto 0);
  signal reg_gen_monitor_int                    : std_logic_vector(31 downto 0);
  signal reg_chk_frame_int                      : std_logic_vector(31 downto 0);
  signal reg_chk_monitor_int                    : std_logic_vector(31 downto 0);
  signal reg_lb_gen_udp_port_int                : std_logic_vector(31 downto 0);
  signal reg_lb_gen_dest_ip_addr_int            : std_logic_vector(31 downto 0);
  signal reg_chk_udp_port_int                   : std_logic_vector(31 downto 0);
  signal reg_tx_rm_bytes_expt_lsb_int           : std_logic_vector(31 downto 0);
  signal reg_tx_rm_bytes_expt_msb_int           : std_logic_vector(31 downto 0);
  signal reg_rx_fm_bytes_expt_lsb_int           : std_logic_vector(31 downto 0);
  signal reg_rx_rm_bytes_expt_msb_int           : std_logic_vector(31 downto 0);
  signal reg_interrupt_enable_int               : std_logic_vector(31 downto 0);
  signal reg_tx_rate_meter_ctrl_int             : std_logic_vector(31 downto 0);
  signal reg_rx_rate_meter_ctrl_int             : std_logic_vector(31 downto 0);
  signal reg_interrupt_clear_int                : std_logic_vector(31 downto 0);
  signal reg_interrupt_set_int                  : std_logic_vector(31 downto 0);



begin


  --------------------------------------------
  --    AXI WRITE PROCESS
  --------------------------------------------
  -- Process: P_AXI_WR
  -- Description:
  -- Management of write channels
  -- AXI4-Lite slave will be ready to accept new write transactions
  -- only when previous transaction response has been accepted
  --------------------------------------------
  P_AXI_WR : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_awready_i <= "0";
        s_axi_wready_i  <= "0";

        axi_awvalid     <= '0';
        axi_wvalid      <= '0';

        axi_wr_init     <= '1';

        wr_req          <= '0';
        wr_addr         <= (others => '0');
        wr_data         <= (others => '0');
        wr_strobe       <= (others => '1');

      else
        -- Default
        wr_req <= '0';

        -- AXI4-Lite slave will be ready to accept new write transactions
        -- only when previous transaction response has been accepted
        if (s_axi_bvalid_i = "1") and (S_AXI_BREADY = "1") then
          s_axi_awready_i <= "1";
          s_axi_wready_i  <= "1";

        -- AXI4 write channels are ready after reset
        elsif axi_wr_init = '1' then
          s_axi_awready_i <= "1";
          s_axi_wready_i  <= "1";
          axi_wr_init     <= '0';

        end if;

        --
        -- Manage internal write requests
        --

        -- Write address request
        if (S_AXI_AWVALID = "1") and (s_axi_awready_i = "1") then
          axi_awvalid     <= '1';
          wr_addr         <= S_AXI_AWADDR;
          s_axi_awready_i <= "0";
        end if;

        -- Write data request
        if (S_AXI_WVALID = "1") and (s_axi_wready_i = "1") then
          axi_wvalid     <= '1';
          wr_data        <= S_AXI_WDATA;
          s_axi_wready_i <= "0";

          -- Convert strobe to data size
          for i in S_AXI_WSTRB'high downto 0 loop
            if (S_AXI_WSTRB(i) = '1') then
              wr_strobe(i*8 +7 downto i*8) <= (others => '1');
            else
              wr_strobe(i*8 +7 downto i*8) <= (others => '0');
            end if;
          end loop;

        end if;

        -- Write request complete
        if (axi_awvalid = '1') and (axi_wvalid = '1') then
          wr_req      <= '1';
          axi_awvalid <= '0';
          axi_wvalid  <= '0';
        end if;

      end if;
    end if;
  end process P_AXI_WR;

  -- Output assignment
  S_AXI_AWREADY <= s_axi_awready_i;
  S_AXI_WREADY  <= s_axi_wready_i;


  --------------------------------------------
  --    AXI WRITE RESPONSE PROCESS
  --------------------------------------------
  -- Process: P_AXI_WR_RESP
  -- Description:
  -- Implement write response logic generation
  -- The write response and response valid signals are asserted by the slave
  -- when wr_req_r is asserted.
  -- This marks the acceptance of address and indicates the status of
  -- write transaction.
  --------------------------------------------
  P_AXI_WR_RESP : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_bvalid_i <= "0";
        S_AXI_BRESP    <= "00";

        wr_req_r       <= '0';

      else
        -- Register
        wr_req_r <= wr_req;

        -- Set response when write command has been processed
        if wr_req_r = '1' then
          s_axi_bvalid_i <= "1";
          S_AXI_BRESP    <= bad_wr_addr & "0"; -- OKAY or SLVERR response
        elsif S_AXI_BREADY = "1" then -- check if bready is asserted while bvalid is high)
          s_axi_bvalid_i <= "0";
        end if;
      end if;
    end if;
  end process P_AXI_WR_RESP;

  -- Output assignment
  S_AXI_BVALID <= s_axi_bvalid_i;


  --------------------------------------------
  -- Process: P_REG_WRITE
  -- Description: Manage input data to write to
  -- registers
  --------------------------------------------
  P_REG_WRITE : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        bad_wr_addr               <= '0';

        reg_gen_chk_control_int(0)                      <= '0';
        reg_gen_chk_control_int(1)                      <= '0';
        reg_gen_chk_control_int(2)                      <= '0';
        reg_gen_chk_control_int(3)                      <= '0';
        reg_gen_chk_control_int(4)                      <= '0';
        reg_gen_chk_control_int(5)                      <= '0';
        reg_gen_frame_int(15 downto 0)                  <= "0000000000000000";
        reg_gen_frame_int(31 downto 16)                 <= "0000010000000000";
        reg_gen_rate_int(7 downto 0)                    <= "00000001";
        reg_gen_rate_int(15 downto 8)                   <= "00000001";
        reg_gen_monitor_int(15 downto 0)                <= "0000000000000000";
        reg_chk_frame_int(15 downto 0)                  <= "0000000000000000";
        reg_chk_frame_int(31 downto 16)                 <= "0000010000000000";
        reg_chk_monitor_int(15 downto 0)                <= "0000000000000000";
        reg_lb_gen_udp_port_int(15 downto 0)            <= "1101011011011000";
        reg_lb_gen_udp_port_int(31 downto 16)           <= "1101011011011010";
        reg_lb_gen_dest_ip_addr_int(31 downto 0)        <= "00000000000000000000000000000000";
        reg_chk_udp_port_int(15 downto 0)               <= "1101011011011010";
        reg_tx_rm_bytes_expt_lsb_int(31 downto 0)       <= "00000000000000000000000000000000";
        reg_tx_rm_bytes_expt_msb_int(31 downto 0)       <= "00000000000000000000000000000000";
        reg_rx_fm_bytes_expt_lsb_int(31 downto 0)       <= "00000000000000000000000000000000";
        reg_rx_rm_bytes_expt_msb_int(31 downto 0)       <= "00000000000000000000000000000000";
        reg_interrupt_enable_int(0)                     <= '0';
        reg_interrupt_enable_int(1)                     <= '0';
        reg_interrupt_enable_int(2)                     <= '0';
        reg_interrupt_enable_int(3)                     <= '0';
        reg_interrupt_enable_int(4)                     <= '0';
        reg_interrupt_enable_int(5)                     <= '0';
        reg_interrupt_enable_int(6)                     <= '0';
        reg_interrupt_enable_int(7)                     <= '0';
        reg_interrupt_enable_int(8)                     <= '0';
        reg_interrupt_enable_int(9)                     <= '0';
        reg_interrupt_enable_int(10)                    <= '0';
        reg_interrupt_enable_int(11)                    <= '0';
        reg_interrupt_enable_int(12)                    <= '0';
        reg_interrupt_enable_int(13)                    <= '0';
        reg_interrupt_enable_int(14)                    <= '0';
        reg_interrupt_enable_int(15)                    <= '0';
        reg_interrupt_enable_int(16)                    <= '0';
        reg_interrupt_enable_int(17)                    <= '0';
        reg_interrupt_enable_int(18)                    <= '0';
        reg_interrupt_enable_int(19)                    <= '0';
        reg_interrupt_enable_int(20)                    <= '0';
        reg_interrupt_enable_int(21)                    <= '0';
        reg_interrupt_enable_int(22)                    <= '0';
        reg_tx_rate_meter_ctrl_int                      <= (others => '0');
        reg_rx_rate_meter_ctrl_int                      <= (others => '0');
        reg_interrupt_clear_int                         <= (others => '0');
        reg_interrupt_set_int                           <= (others => '0');
        REG_TX_RATE_METER_CTRL_WRITE                    <= '0';
        REG_RX_RATE_METER_CTRL_WRITE                    <= '0';
        REG_INTERRUPT_CLEAR_WRITE                       <= '0';
        REG_INTERRUPT_SET_WRITE                         <= '0';


      else

        -- Default
        bad_wr_addr <= '0';

        REG_TX_RATE_METER_CTRL_WRITE            <= '0';
        REG_RX_RATE_METER_CTRL_WRITE            <= '0';
        REG_INTERRUPT_CLEAR_WRITE               <= '0';
        REG_INTERRUPT_SET_WRITE                 <= '0';


        if (wr_req = '1') then
          -- Decode register address to write
          case wr_addr is

            when C_TEST_REG_GEN_CHK_CONTROL => 
              reg_gen_chk_control_int                 <= set_reg_val(reg_gen_chk_control_int, wr_strobe, wr_data, C_REG_GEN_CHK_CONTROL);
            when C_TEST_REG_GEN_FRAME => 
              reg_gen_frame_int                       <= set_reg_val(reg_gen_frame_int, wr_strobe, wr_data, C_REG_GEN_FRAME);
            when C_TEST_REG_GEN_RATE => 
              reg_gen_rate_int                        <= set_reg_val(reg_gen_rate_int, wr_strobe, wr_data, C_REG_GEN_RATE);
            when C_TEST_REG_GEN_MONITOR => 
              reg_gen_monitor_int                     <= set_reg_val(reg_gen_monitor_int, wr_strobe, wr_data, C_REG_GEN_MONITOR);
            when C_TEST_REG_CHK_FRAME => 
              reg_chk_frame_int                       <= set_reg_val(reg_chk_frame_int, wr_strobe, wr_data, C_REG_CHK_FRAME);
            when C_TEST_REG_CHK_MONITOR => 
              reg_chk_monitor_int                     <= set_reg_val(reg_chk_monitor_int, wr_strobe, wr_data, C_REG_CHK_MONITOR);
            when C_TEST_REG_LB_GEN_UDP_PORT => 
              reg_lb_gen_udp_port_int                 <= set_reg_val(reg_lb_gen_udp_port_int, wr_strobe, wr_data, C_REG_LB_GEN_UDP_PORT);
            when C_TEST_REG_LB_GEN_DEST_IP_ADDR => 
              reg_lb_gen_dest_ip_addr_int             <= set_reg_val(reg_lb_gen_dest_ip_addr_int, wr_strobe, wr_data, C_REG_LB_GEN_DEST_IP_ADDR);
            when C_TEST_REG_CHK_UDP_PORT => 
              reg_chk_udp_port_int                    <= set_reg_val(reg_chk_udp_port_int, wr_strobe, wr_data, C_REG_CHK_UDP_PORT);
            when C_TEST_REG_TX_RM_BYTES_EXPT_LSB => 
              reg_tx_rm_bytes_expt_lsb_int            <= set_reg_val(reg_tx_rm_bytes_expt_lsb_int, wr_strobe, wr_data, C_REG_TX_RM_BYTES_EXPT_LSB);
            when C_TEST_REG_TX_RM_BYTES_EXPT_MSB => 
              reg_tx_rm_bytes_expt_msb_int            <= set_reg_val(reg_tx_rm_bytes_expt_msb_int, wr_strobe, wr_data, C_REG_TX_RM_BYTES_EXPT_MSB);
            when C_TEST_REG_RX_FM_BYTES_EXPT_LSB => 
              reg_rx_fm_bytes_expt_lsb_int            <= set_reg_val(reg_rx_fm_bytes_expt_lsb_int, wr_strobe, wr_data, C_REG_RX_FM_BYTES_EXPT_LSB);
            when C_TEST_REG_RX_RM_BYTES_EXPT_MSB => 
              reg_rx_rm_bytes_expt_msb_int            <= set_reg_val(reg_rx_rm_bytes_expt_msb_int, wr_strobe, wr_data, C_REG_RX_RM_BYTES_EXPT_MSB);
            when C_TEST_REG_INTERRUPT_ENABLE => 
              reg_interrupt_enable_int                <= set_reg_val(reg_interrupt_enable_int, wr_strobe, wr_data, C_REG_INTERRUPT_ENABLE);
            when C_TEST_REG_TX_RATE_METER_CTRL => 
              reg_tx_rate_meter_ctrl_int              <= set_reg_val(reg_tx_rate_meter_ctrl_int, wr_strobe, wr_data, C_REG_TX_RATE_METER_CTRL);
              REG_TX_RATE_METER_CTRL_WRITE            <= '1';
            when C_TEST_REG_RX_RATE_METER_CTRL => 
              reg_rx_rate_meter_ctrl_int              <= set_reg_val(reg_rx_rate_meter_ctrl_int, wr_strobe, wr_data, C_REG_RX_RATE_METER_CTRL);
              REG_RX_RATE_METER_CTRL_WRITE            <= '1';
            when C_TEST_REG_INTERRUPT_CLEAR => 
              reg_interrupt_clear_int                 <= set_reg_val(reg_interrupt_clear_int, wr_strobe, wr_data, C_REG_INTERRUPT_CLEAR);
              REG_INTERRUPT_CLEAR_WRITE               <= '1';
            when C_TEST_REG_INTERRUPT_SET => 
              reg_interrupt_set_int                   <= set_reg_val(reg_interrupt_set_int, wr_strobe, wr_data, C_REG_INTERRUPT_SET);
              REG_INTERRUPT_SET_WRITE                 <= '1';

            when others =>
              bad_wr_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_WRITE;

  -- Output assignments
  LOOPBACK_MAC_EN                         <= reg_gen_chk_control_int(0);
  LOOPBACK_UDP_EN                         <= reg_gen_chk_control_int(1);
  GEN_ENABLE                              <= reg_gen_chk_control_int(2);
  GEN_FRAME_SIZE_TYPE                     <= reg_gen_chk_control_int(3);
  CHK_ENABLE                              <= reg_gen_chk_control_int(4);
  CHK_FRAME_SIZE_TYPE                     <= reg_gen_chk_control_int(5);
  GEN_NB_FRAMES                           <= reg_gen_frame_int(15 downto 0);
  GEN_FRAME_SIZE_STATIC                   <= reg_gen_frame_int(31 downto 16);
  GEN_RATE_NB_TRANSFERS                   <= reg_gen_rate_int(7 downto 0);
  GEN_RATE_WINDOW_SIZE                    <= reg_gen_rate_int(15 downto 8);
  GEN_MON_TIMEOUT_VALUE                   <= reg_gen_monitor_int(15 downto 0);
  CHK_NB_FRAMES                           <= reg_chk_frame_int(15 downto 0);
  CHK_FRAME_SIZE_STATIC                   <= reg_chk_frame_int(31 downto 16);
  CHK_MON_TIMEOUT_VALUE                   <= reg_chk_monitor_int(15 downto 0);
  LB_GEN_DEST_PORT                        <= reg_lb_gen_udp_port_int(15 downto 0);
  LB_GEN_SRC_PORT                         <= reg_lb_gen_udp_port_int(31 downto 16);
  LB_GEN_DEST_IP_ADDR                     <= reg_lb_gen_dest_ip_addr_int(31 downto 0);
  CHK_LISTENING_PORT                      <= reg_chk_udp_port_int(15 downto 0);
  TX_RM_BYTES_EXPT_LSB                    <= reg_tx_rm_bytes_expt_lsb_int(31 downto 0);
  TX_RM_BYTES_EXPT_MSB                    <= reg_tx_rm_bytes_expt_msb_int(31 downto 0);
  RX_RM_BYTES_EXPT_LSB                    <= reg_rx_fm_bytes_expt_lsb_int(31 downto 0);
  RX_RM_BYTES_EXPT_MSB                    <= reg_rx_rm_bytes_expt_msb_int(31 downto 0);
  IRQ_GEN_DONE_ENABLE                     <= reg_interrupt_enable_int(0);
  IRQ_GEN_MON_TIMEOUT_READY_ENABLE        <= reg_interrupt_enable_int(1);
  IRQ_GEN_MON_TIMEOUT_VALID_ENABLE        <= reg_interrupt_enable_int(2);
  IRQ_GEN_MON_VALID_ERROR_ENABLE          <= reg_interrupt_enable_int(3);
  IRQ_GEN_MON_DATA_ERROR_ENABLE           <= reg_interrupt_enable_int(4);
  IRQ_GEN_MON_LAST_ERROR_ENABLE           <= reg_interrupt_enable_int(5);
  IRQ_GEN_MON_USER_ERROR_ENABLE           <= reg_interrupt_enable_int(6);
  IRQ_GEN_MON_KEEP_ERROR_ENABLE           <= reg_interrupt_enable_int(7);
  IRQ_CHK_DONE_ENABLE                     <= reg_interrupt_enable_int(8);
  IRQ_CHK_ERR_DATA_ENABLE                 <= reg_interrupt_enable_int(9);
  IRQ_CHK_ERR_SIZE_ENABLE                 <= reg_interrupt_enable_int(10);
  IRQ_CHK_ERR_LAST_ENABLE                 <= reg_interrupt_enable_int(11);
  IRQ_CHK_MON_TIMEOUT_READY_ENABLE        <= reg_interrupt_enable_int(12);
  IRQ_CHK_MON_TIMEOUT_VALID_ENABLE        <= reg_interrupt_enable_int(13);
  IRQ_CHK_MON_VALID_ERROR_ENABLE          <= reg_interrupt_enable_int(14);
  IRQ_CHK_MON_DATA_ERROR_ENABLE           <= reg_interrupt_enable_int(15);
  IRQ_CHK_MON_LAST_ERROR_ENABLE           <= reg_interrupt_enable_int(16);
  IRQ_CHK_MON_USER_ERROR_ENABLE           <= reg_interrupt_enable_int(17);
  IRQ_CHK_MON_KEEP_ERROR_ENABLE           <= reg_interrupt_enable_int(18);
  IRQ_RATE_METER_TX_DONE_ENABLE           <= reg_interrupt_enable_int(19);
  IRQ_RATE_METER_TX_OVERFLOW_ENABLE       <= reg_interrupt_enable_int(20);
  IRQ_RATE_METER_RX_DONE_ENABLE           <= reg_interrupt_enable_int(21);
  IRQ_RATE_METER_RX_OVERFLOW_ENABLE       <= reg_interrupt_enable_int(22);
  TX_RM_INIT_COUNTER_OUT                  <= reg_tx_rate_meter_ctrl_int(0);
  RX_RM_INIT_COUNTER_OUT                  <= reg_rx_rate_meter_ctrl_int(0);
  IRQ_GEN_DONE_CLEAR_OUT                  <= reg_interrupt_clear_int(0);
  IRQ_GEN_MON_TIMEOUT_READY_CLEAR_OUT     <= reg_interrupt_clear_int(1);
  IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_OUT     <= reg_interrupt_clear_int(2);
  IRQ_GEN_MON_VALID_ERROR_CLEAR_OUT       <= reg_interrupt_clear_int(3);
  IRQ_GEN_MON_DATA_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(4);
  IRQ_GEN_MON_LAST_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(5);
  IRQ_GEN_MON_USER_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(6);
  IRQ_GEN_MON_KEEP_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(7);
  IRQ_CHK_DONE_CLEAR_OUT                  <= reg_interrupt_clear_int(8);
  IRQ_CHK_ERR_DATA_CLEAR_OUT              <= reg_interrupt_clear_int(9);
  IRQ_CHK_ERR_SIZE_CLEAR_OUT              <= reg_interrupt_clear_int(10);
  IRQ_CHK_ERR_LAST_CLEAR_OUT              <= reg_interrupt_clear_int(11);
  IRQ_CHK_MON_TIMEOUT_READY_CLEAR_OUT     <= reg_interrupt_clear_int(12);
  IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_OUT     <= reg_interrupt_clear_int(13);
  IRQ_CHK_MON_VALID_ERROR_CLEAR_OUT       <= reg_interrupt_clear_int(14);
  IRQ_CHK_MON_DATA_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(15);
  IRQ_CHK_MON_LAST_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(16);
  IRQ_CHK_MON_USER_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(17);
  IRQ_CHK_MON_KEEP_ERROR_CLEAR_OUT        <= reg_interrupt_clear_int(18);
  IRQ_RATE_METER_TX_DONE_CLEAR_OUT        <= reg_interrupt_clear_int(19);
  IRQ_RATE_METER_TX_OVERFLOW_CLEAR_OUT    <= reg_interrupt_clear_int(20);
  IRQ_RATE_METER_RX_DONE_CLEAR_OUT        <= reg_interrupt_clear_int(21);
  IRQ_RATE_METER_RX_OVERFLOW_CLEAR_OUT    <= reg_interrupt_clear_int(22);
  IRQ_GEN_DONE_SET_OUT                    <= reg_interrupt_set_int(0);
  IRQ_GEN_MON_TIMEOUT_READY_SET_OUT       <= reg_interrupt_set_int(1);
  IRQ_GEN_MON_TIMEOUT_VALID_SET_OUT       <= reg_interrupt_set_int(2);
  IRQ_GEN_MON_VALID_ERROR_SET_OUT         <= reg_interrupt_set_int(3);
  IRQ_GEN_MON_DATA_ERROR_SET_OUT          <= reg_interrupt_set_int(4);
  IRQ_GEN_MON_LAST_ERROR_SET_OUT          <= reg_interrupt_set_int(5);
  IRQ_GEN_MON_USER_ERROR_SET_OUT          <= reg_interrupt_set_int(6);
  IRQ_GEN_MON_KEEP_ERROR_SET_OUT          <= reg_interrupt_set_int(7);
  IRQ_CHK_DONE_SET_OUT                    <= reg_interrupt_set_int(8);
  IRQ_CHK_ERR_DATA_SET_OUT                <= reg_interrupt_set_int(9);
  IRQ_CHK_ERR_SIZE_SET_OUT                <= reg_interrupt_set_int(10);
  IRQ_CHK_ERR_LAST_SET_OUT                <= reg_interrupt_set_int(11);
  IRQ_CHK_MON_TIMEOUT_READY_SET_OUT       <= reg_interrupt_set_int(12);
  IRQ_CHK_MON_TIMEOUT_VALID_SET_OUT       <= reg_interrupt_set_int(13);
  IRQ_CHK_MON_VALID_ERROR_SET_OUT         <= reg_interrupt_set_int(14);
  IRQ_CHK_MON_DATA_ERROR_SET_OUT          <= reg_interrupt_set_int(15);
  IRQ_CHK_MON_LAST_ERROR_SET_OUT          <= reg_interrupt_set_int(16);
  IRQ_CHK_MON_USER_ERROR_SET_OUT          <= reg_interrupt_set_int(17);
  IRQ_CHK_MON_KEEP_ERROR_SET_OUT          <= reg_interrupt_set_int(18);
  IRQ_RATE_METER_TX_DONE_SET_OUT          <= reg_interrupt_set_int(19);
  IRQ_RATE_METER_TX_OVERFLOW_SET_OUT      <= reg_interrupt_set_int(20);
  IRQ_RATE_METER_RX_DONE_SET_OUT          <= reg_interrupt_set_int(21);
  IRQ_RATE_METER_RX_OVERFLOW_SET_OUT      <= reg_interrupt_set_int(22);



  --------------------------------------------
  --    AXI READ PROCESS
  --------------------------------------------
  -- Process: P_AXI_RD
  -- Description:
  -- Management of read channels
  -- AXI4-Lite slave will be ready to accept new read transactions
  -- only when previous transaction response has been accepted
  --------------------------------------------
  P_AXI_RD : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_arready_i <= "0";

        axi_rd_init     <= '1';

        rd_req          <= '0';
        rd_addr         <= (others => '0');

      else
        -- Default
        rd_req <= '0';

        -- AXI4-Lite slave will be ready to accept new read transactions
        -- only when previous transaction response has been accepted
        if (s_axi_rvalid_i = "1") and (S_AXI_RREADY = "1") then
          s_axi_arready_i <= "1";

        -- AXI4 write channels are ready after reset
        elsif axi_rd_init = '1' then
          s_axi_arready_i <= "1";
          axi_rd_init     <= '0';

        end if;

        -- Manage internal read requests
        if (S_AXI_ARVALID = "1") and (s_axi_arready_i = "1") then
          rd_addr         <= S_AXI_ARADDR;
          s_axi_arready_i <= "0";
          rd_req          <= '1';
        end if;

      end if;
    end if;
  end process P_AXI_RD;

  -- Output assignment
  S_AXI_ARREADY <= s_axi_arready_i;


  --------------------------------------------
  -- AXI READ RESPONSE PROCESS
  --------------------------------------------
  -- Process: P_AXI_RD_RESP
  -- Description:
  -- Implement axi_arvalid generation
  -- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  -- S_AXI_ARVALID and axi_arready are asserted. The slave registers
  -- data are available on the axi_rdata bus at this instance. The
  -- assertion of axi_rvalid marks the validity of read data on the
  -- bus and axi_rresp indicates the status of read transaction.axi_rvalid
  -- is de-asserted on reset (active low). axi_rresp and axi_rdata are
  -- cleared to zero on reset (active low).
  --------------------------------------------
  P_AXI_RD_RESP : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_rvalid_i <= "0";
        S_AXI_RRESP    <= "00";
        S_AXI_RDATA    <= (others => '0');

        rd_req_r       <= '0';

      else
        -- Register
        rd_req_r <= rd_req;

        -- Set response when read command has been processed
        if rd_req_r = '1' then
          -- Valid read data is available at the read data bus
          s_axi_rvalid_i <= "1";
          S_AXI_RRESP    <= bad_rd_addr & "0";   -- OKAY or SLVERR response
          S_AXI_RDATA    <= rd_data;
        elsif S_AXI_RREADY = "1" then
          -- Read data is accepted by the master
          s_axi_rvalid_i <= "0";
        end if;
      end if;
    end if;
  end process P_AXI_RD_RESP;

  -- Output assignment
  S_AXI_RVALID <= s_axi_rvalid_i;


  --------------------------------------------
  -- Process: P_REG_READ
  -- Description: Manage output data read from
  -- registers
  --------------------------------------------
  P_REG_READ : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        bad_rd_addr <= '0';
        rd_data     <= (others => '0');



      else
        -- Default
        bad_rd_addr <= '0';
        rd_data     <= (others => '0');



        if (rd_req = '1') then
          -- Decode register address to read
          case rd_addr is

            when C_TEST_REG_GEN_TEST_DURATION_LSB => 
              rd_data(31 downto 0)                    <= GEN_TEST_DURATION_LSB;
            when C_TEST_REG_GEN_TEST_DURATION_MSB => 
              rd_data(31 downto 0)                    <= GEN_TEST_DURATION_MSB;
            when C_TEST_REG_CHK_TEST_DURATION_LSB => 
              rd_data(31 downto 0)                    <= CHK_TEST_DURATION_LSB;
            when C_TEST_REG_CHK_TEST_DURATION_MSB => 
              rd_data(31 downto 0)                    <= CHK_TEST_DURATION_MSB;
            when C_TEST_REG_TX_RM_CNT_BYTES_LSB => 
              rd_data(31 downto 0)                    <= TX_RM_CNT_BYTES_LSB;
            when C_TEST_REG_TX_RM_CNT_BYTES_MSB => 
              rd_data(31 downto 0)                    <= TX_RM_CNT_BYTES_MSB;
            when C_TEST_REG_TX_RM_CNT_CYCLES_LSB => 
              rd_data(31 downto 0)                    <= TX_RM_CNT_CYCLES_LSB;
            when C_TEST_REG_TX_RM_CNT_CYCLES_MSB => 
              rd_data(31 downto 0)                    <= TX_RM_CNT_CYCLES_MSB;
            when C_TEST_REG_RX_RM_CNT_BYTES_LSB => 
              rd_data(31 downto 0)                    <= RX_RM_CNT_BYTES_LSB;
            when C_TEST_REG_RX_RM_CNT_BYTES_MSB => 
              rd_data(31 downto 0)                    <= RX_RM_CNT_BYTES_MSB;
            when C_TEST_REG_RX_RM_CNT_CYCLES_LSB => 
              rd_data(31 downto 0)                    <= RX_RM_CNT_CYCLES_LSB;
            when C_TEST_REG_RX_RM_CNT_CYCLES_MSB => 
              rd_data(31 downto 0)                    <= RX_RM_CNT_CYCLES_MSB;
            when C_TEST_REG_INTERRUPT_STATUS => 
              rd_data(0)                              <= IRQ_GEN_DONE_STATUS;
              rd_data(1)                              <= IRQ_GEN_MON_TIMEOUT_READY_STATUS;
              rd_data(2)                              <= IRQ_GEN_MON_TIMEOUT_VALID_STATUS;
              rd_data(3)                              <= IRQ_GEN_MON_VALID_ERROR_STATUS;
              rd_data(4)                              <= IRQ_GEN_MON_DATA_ERROR_STATUS;
              rd_data(5)                              <= IRQ_GEN_MON_LAST_ERROR_STATUS;
              rd_data(6)                              <= IRQ_GEN_MON_USER_ERROR_STATUS;
              rd_data(7)                              <= IRQ_GEN_MON_KEEP_ERROR_STATUS;
              rd_data(8)                              <= IRQ_CHK_DONE_STATUS;
              rd_data(9)                              <= IRQ_CHK_ERR_DATA_STATUS;
              rd_data(10)                             <= IRQ_CHK_ERR_SIZE_STATUS;
              rd_data(11)                             <= IRQ_CHK_ERR_LAST_STATUS;
              rd_data(12)                             <= IRQ_CHK_MON_TIMEOUT_READY_STATUS;
              rd_data(13)                             <= IRQ_CHK_MON_TIMEOUT_VALID_STATUS;
              rd_data(14)                             <= IRQ_CHK_MON_VALID_ERROR_STATUS;
              rd_data(15)                             <= IRQ_CHK_MON_DATA_ERROR_STATUS;
              rd_data(16)                             <= IRQ_CHK_MON_LAST_ERROR_STATUS;
              rd_data(17)                             <= IRQ_CHK_MON_USER_ERROR_STATUS;
              rd_data(18)                             <= IRQ_CHK_MON_KEEP_ERROR_STATUS;
              rd_data(19)                             <= IRQ_RATE_METER_TX_DONE_STATUS;
              rd_data(20)                             <= IRQ_RATE_METER_TX_OVERFLOW_STATUS;
              rd_data(21)                             <= IRQ_RATE_METER_RX_DONE_STATUS;
              rd_data(22)                             <= IRQ_RATE_METER_RX_OVERFLOW_STATUS;
            when C_TEST_REG_GEN_CHK_CONTROL => 
              rd_data(0)                              <= reg_gen_chk_control_int(0);
              rd_data(1)                              <= reg_gen_chk_control_int(1);
              rd_data(2)                              <= reg_gen_chk_control_int(2);
              rd_data(3)                              <= reg_gen_chk_control_int(3);
              rd_data(4)                              <= reg_gen_chk_control_int(4);
              rd_data(5)                              <= reg_gen_chk_control_int(5);
            when C_TEST_REG_GEN_FRAME => 
              rd_data(15 downto 0)                    <= reg_gen_frame_int(15 downto 0);
              rd_data(31 downto 16)                   <= reg_gen_frame_int(31 downto 16);
            when C_TEST_REG_GEN_RATE => 
              rd_data(7 downto 0)                     <= reg_gen_rate_int(7 downto 0);
              rd_data(15 downto 8)                    <= reg_gen_rate_int(15 downto 8);
            when C_TEST_REG_GEN_MONITOR => 
              rd_data(15 downto 0)                    <= reg_gen_monitor_int(15 downto 0);
            when C_TEST_REG_CHK_FRAME => 
              rd_data(15 downto 0)                    <= reg_chk_frame_int(15 downto 0);
              rd_data(31 downto 16)                   <= reg_chk_frame_int(31 downto 16);
            when C_TEST_REG_CHK_MONITOR => 
              rd_data(15 downto 0)                    <= reg_chk_monitor_int(15 downto 0);
            when C_TEST_REG_LB_GEN_UDP_PORT => 
              rd_data(15 downto 0)                    <= reg_lb_gen_udp_port_int(15 downto 0);
              rd_data(31 downto 16)                   <= reg_lb_gen_udp_port_int(31 downto 16);
            when C_TEST_REG_LB_GEN_DEST_IP_ADDR => 
              rd_data(31 downto 0)                    <= reg_lb_gen_dest_ip_addr_int(31 downto 0);
            when C_TEST_REG_CHK_UDP_PORT => 
              rd_data(15 downto 0)                    <= reg_chk_udp_port_int(15 downto 0);
            when C_TEST_REG_TX_RM_BYTES_EXPT_LSB => 
              rd_data(31 downto 0)                    <= reg_tx_rm_bytes_expt_lsb_int(31 downto 0);
            when C_TEST_REG_TX_RM_BYTES_EXPT_MSB => 
              rd_data(31 downto 0)                    <= reg_tx_rm_bytes_expt_msb_int(31 downto 0);
            when C_TEST_REG_RX_FM_BYTES_EXPT_LSB => 
              rd_data(31 downto 0)                    <= reg_rx_fm_bytes_expt_lsb_int(31 downto 0);
            when C_TEST_REG_RX_RM_BYTES_EXPT_MSB => 
              rd_data(31 downto 0)                    <= reg_rx_rm_bytes_expt_msb_int(31 downto 0);
            when C_TEST_REG_INTERRUPT_ENABLE => 
              rd_data(0)                              <= reg_interrupt_enable_int(0);
              rd_data(1)                              <= reg_interrupt_enable_int(1);
              rd_data(2)                              <= reg_interrupt_enable_int(2);
              rd_data(3)                              <= reg_interrupt_enable_int(3);
              rd_data(4)                              <= reg_interrupt_enable_int(4);
              rd_data(5)                              <= reg_interrupt_enable_int(5);
              rd_data(6)                              <= reg_interrupt_enable_int(6);
              rd_data(7)                              <= reg_interrupt_enable_int(7);
              rd_data(8)                              <= reg_interrupt_enable_int(8);
              rd_data(9)                              <= reg_interrupt_enable_int(9);
              rd_data(10)                             <= reg_interrupt_enable_int(10);
              rd_data(11)                             <= reg_interrupt_enable_int(11);
              rd_data(12)                             <= reg_interrupt_enable_int(12);
              rd_data(13)                             <= reg_interrupt_enable_int(13);
              rd_data(14)                             <= reg_interrupt_enable_int(14);
              rd_data(15)                             <= reg_interrupt_enable_int(15);
              rd_data(16)                             <= reg_interrupt_enable_int(16);
              rd_data(17)                             <= reg_interrupt_enable_int(17);
              rd_data(18)                             <= reg_interrupt_enable_int(18);
              rd_data(19)                             <= reg_interrupt_enable_int(19);
              rd_data(20)                             <= reg_interrupt_enable_int(20);
              rd_data(21)                             <= reg_interrupt_enable_int(21);
              rd_data(22)                             <= reg_interrupt_enable_int(22);
            when C_TEST_REG_TX_RATE_METER_CTRL => 
              rd_data(0)                              <= TX_RM_INIT_COUNTER_IN;
            when C_TEST_REG_RX_RATE_METER_CTRL => 
              rd_data(0)                              <= RX_RM_INIT_COUNTER_IN;
            when C_TEST_REG_INTERRUPT_CLEAR => 
              rd_data(0)                              <= IRQ_GEN_DONE_CLEAR_IN;
              rd_data(1)                              <= IRQ_GEN_MON_TIMEOUT_READY_CLEAR_IN;
              rd_data(2)                              <= IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_IN;
              rd_data(3)                              <= IRQ_GEN_MON_VALID_ERROR_CLEAR_IN;
              rd_data(4)                              <= IRQ_GEN_MON_DATA_ERROR_CLEAR_IN;
              rd_data(5)                              <= IRQ_GEN_MON_LAST_ERROR_CLEAR_IN;
              rd_data(6)                              <= IRQ_GEN_MON_USER_ERROR_CLEAR_IN;
              rd_data(7)                              <= IRQ_GEN_MON_KEEP_ERROR_CLEAR_IN;
              rd_data(8)                              <= IRQ_CHK_DONE_CLEAR_IN;
              rd_data(9)                              <= IRQ_CHK_ERR_DATA_CLEAR_IN;
              rd_data(10)                             <= IRQ_CHK_ERR_SIZE_CLEAR_IN;
              rd_data(11)                             <= IRQ_CHK_ERR_LAST_CLEAR_IN;
              rd_data(12)                             <= IRQ_CHK_MON_TIMEOUT_READY_CLEAR_IN;
              rd_data(13)                             <= IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_IN;
              rd_data(14)                             <= IRQ_CHK_MON_VALID_ERROR_CLEAR_IN;
              rd_data(15)                             <= IRQ_CHK_MON_DATA_ERROR_CLEAR_IN;
              rd_data(16)                             <= IRQ_CHK_MON_LAST_ERROR_CLEAR_IN;
              rd_data(17)                             <= IRQ_CHK_MON_USER_ERROR_CLEAR_IN;
              rd_data(18)                             <= IRQ_CHK_MON_KEEP_ERROR_CLEAR_IN;
              rd_data(19)                             <= IRQ_RATE_METER_TX_DONE_CLEAR_IN;
              rd_data(20)                             <= IRQ_RATE_METER_TX_OVERFLOW_CLEAR_IN;
              rd_data(21)                             <= IRQ_RATE_METER_RX_DONE_CLEAR_IN;
              rd_data(22)                             <= IRQ_RATE_METER_RX_OVERFLOW_CLEAR_IN;
            when C_TEST_REG_INTERRUPT_SET => 
              rd_data(0)                              <= IRQ_GEN_DONE_SET_IN;
              rd_data(1)                              <= IRQ_GEN_MON_TIMEOUT_READY_SET_IN;
              rd_data(2)                              <= IRQ_GEN_MON_TIMEOUT_VALID_SET_IN;
              rd_data(3)                              <= IRQ_GEN_MON_VALID_ERROR_SET_IN;
              rd_data(4)                              <= IRQ_GEN_MON_DATA_ERROR_SET_IN;
              rd_data(5)                              <= IRQ_GEN_MON_LAST_ERROR_SET_IN;
              rd_data(6)                              <= IRQ_GEN_MON_USER_ERROR_SET_IN;
              rd_data(7)                              <= IRQ_GEN_MON_KEEP_ERROR_SET_IN;
              rd_data(8)                              <= IRQ_CHK_DONE_SET_IN;
              rd_data(9)                              <= IRQ_CHK_ERR_DATA_SET_IN;
              rd_data(10)                             <= IRQ_CHK_ERR_SIZE_SET_IN;
              rd_data(11)                             <= IRQ_CHK_ERR_LAST_SET_IN;
              rd_data(12)                             <= IRQ_CHK_MON_TIMEOUT_READY_SET_IN;
              rd_data(13)                             <= IRQ_CHK_MON_TIMEOUT_VALID_SET_IN;
              rd_data(14)                             <= IRQ_CHK_MON_VALID_ERROR_SET_IN;
              rd_data(15)                             <= IRQ_CHK_MON_DATA_ERROR_SET_IN;
              rd_data(16)                             <= IRQ_CHK_MON_LAST_ERROR_SET_IN;
              rd_data(17)                             <= IRQ_CHK_MON_USER_ERROR_SET_IN;
              rd_data(18)                             <= IRQ_CHK_MON_KEEP_ERROR_SET_IN;
              rd_data(19)                             <= IRQ_RATE_METER_TX_DONE_SET_IN;
              rd_data(20)                             <= IRQ_RATE_METER_TX_OVERFLOW_SET_IN;
              rd_data(21)                             <= IRQ_RATE_METER_RX_DONE_SET_IN;
              rd_data(22)                             <= IRQ_RATE_METER_RX_OVERFLOW_SET_IN;

            when others =>
              bad_rd_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_READ;


end rtl;
