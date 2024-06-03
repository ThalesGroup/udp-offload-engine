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
entity test_uoe_registers_itf is
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

    ----------------------
    -- IRQ
    ---------------------
    -- IRQ sources
    IRQ_GEN_DONE                                : in  std_logic;                                       -- End of frames generation
    IRQ_GEN_MON_TIMEOUT_READY                   : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_GEN_MON_TIMEOUT_VALID                   : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_GEN_MON_VALID_ERROR                     : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_GEN_MON_DATA_ERROR                      : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_GEN_MON_LAST_ERROR                      : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_GEN_MON_USER_ERROR                      : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_GEN_MON_KEEP_ERROR                      : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_CHK_DONE                                : in  std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_DATA                            : in  std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_SIZE                            : in  std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_LAST                            : in  std_logic;                                       -- last error detection
    IRQ_CHK_MON_TIMEOUT_READY                   : in  std_logic;                                       -- Timeout reach waiting ready signal
    IRQ_CHK_MON_TIMEOUT_VALID                   : in  std_logic;                                       -- Timeout reach waiting valid signal
    IRQ_CHK_MON_VALID_ERROR                     : in  std_logic;                                       -- TVALID value changed during a transfer without handshake
    IRQ_CHK_MON_DATA_ERROR                      : in  std_logic;                                       -- TDATA value changed during a transfer without handshake
    IRQ_CHK_MON_LAST_ERROR                      : in  std_logic;                                       -- TLAST value changed during a transfer without handshake
    IRQ_CHK_MON_USER_ERROR                      : in  std_logic;                                       -- TUSER value changed during a transfer without handshake
    IRQ_CHK_MON_KEEP_ERROR                      : in  std_logic;                                       -- TKEEP value changed during a transfer without handshake
    IRQ_RATE_METER_TX_DONE                      : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_TX_OVERFLOW                  : in  std_logic;                                       -- Counter reach the maximum size of the counter
    IRQ_RATE_METER_RX_DONE                      : in  std_logic;                                       -- End of measurement
    IRQ_RATE_METER_RX_OVERFLOW                  : in  std_logic;                                       -- Counter reach the maximum size of the counter

    -- output
    -- IRQ output
    REG_INTERRUPT                               : out std_logic

  );
end test_uoe_registers_itf;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of test_uoe_registers_itf is


  -- Irq Status register
  signal reg_interrupt_status                        : std_logic_vector(22 downto 0);

  -- IRQ Enable register
  signal reg_interrupt_enable                        : std_logic_vector(22 downto 0);

  -- IRQ clear register
  signal reg_interrupt_clear                         : std_logic_vector(22 downto 0);
  signal reg_interrupt_clear_write                   : std_logic;

  -- IRQ set register
  signal reg_interrupt_set                           : std_logic_vector(22 downto 0);
  signal reg_interrupt_set_write                     : std_logic;



begin

  ------------------------------------------------------------------------
  -- registers instanciation
  ------------------------------------------------------------------------
  inst_test_uoe_registers : test_uoe_registers
    port map(
      ----------------------
      -- AXI4-Lite bus
      ----------------------
      S_AXI_ACLK                 => S_AXI_ACLK,
      S_AXI_ARESET               => S_AXI_ARESET,
      S_AXI_AWADDR               => S_AXI_AWADDR,
      S_AXI_AWVALID              => S_AXI_AWVALID,
      S_AXI_AWREADY              => S_AXI_AWREADY,
      S_AXI_WDATA                => S_AXI_WDATA,
      S_AXI_WVALID               => S_AXI_WVALID,
      S_AXI_WSTRB                => S_AXI_WSTRB,
      S_AXI_WREADY               => S_AXI_WREADY,
      S_AXI_BRESP                => S_AXI_BRESP,
      S_AXI_BVALID               => S_AXI_BVALID,
      S_AXI_BREADY               => S_AXI_BREADY,
      S_AXI_ARADDR               => S_AXI_ARADDR,
      S_AXI_ARVALID              => S_AXI_ARVALID,
      S_AXI_ARREADY              => S_AXI_ARREADY,
      S_AXI_RDATA                => S_AXI_RDATA,
      S_AXI_RRESP                => S_AXI_RRESP,
      S_AXI_RVALID               => S_AXI_RVALID,
      S_AXI_RREADY               => S_AXI_RREADY,
      ----------------------
      -- Input data for registers
      ----------------------

      GEN_TEST_DURATION_LSB                       => GEN_TEST_DURATION_LSB,
      GEN_TEST_DURATION_MSB                       => GEN_TEST_DURATION_MSB,
      CHK_TEST_DURATION_LSB                       => CHK_TEST_DURATION_LSB,
      CHK_TEST_DURATION_MSB                       => CHK_TEST_DURATION_MSB,
      TX_RM_CNT_BYTES_LSB                         => TX_RM_CNT_BYTES_LSB,
      TX_RM_CNT_BYTES_MSB                         => TX_RM_CNT_BYTES_MSB,
      TX_RM_CNT_CYCLES_LSB                        => TX_RM_CNT_CYCLES_LSB,
      TX_RM_CNT_CYCLES_MSB                        => TX_RM_CNT_CYCLES_MSB,
      RX_RM_CNT_BYTES_LSB                         => RX_RM_CNT_BYTES_LSB,
      RX_RM_CNT_BYTES_MSB                         => RX_RM_CNT_BYTES_MSB,
      RX_RM_CNT_CYCLES_LSB                        => RX_RM_CNT_CYCLES_LSB,
      RX_RM_CNT_CYCLES_MSB                        => RX_RM_CNT_CYCLES_MSB,
      TX_RM_INIT_COUNTER_IN                       => TX_RM_INIT_COUNTER_IN,
      RX_RM_INIT_COUNTER_IN                       => RX_RM_INIT_COUNTER_IN,
      IRQ_GEN_DONE_CLEAR_IN                       => reg_interrupt_clear(0),
      IRQ_GEN_MON_TIMEOUT_READY_CLEAR_IN          => reg_interrupt_clear(1),
      IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_IN          => reg_interrupt_clear(2),
      IRQ_GEN_MON_VALID_ERROR_CLEAR_IN            => reg_interrupt_clear(3),
      IRQ_GEN_MON_DATA_ERROR_CLEAR_IN             => reg_interrupt_clear(4),
      IRQ_GEN_MON_LAST_ERROR_CLEAR_IN             => reg_interrupt_clear(5),
      IRQ_GEN_MON_USER_ERROR_CLEAR_IN             => reg_interrupt_clear(6),
      IRQ_GEN_MON_KEEP_ERROR_CLEAR_IN             => reg_interrupt_clear(7),
      IRQ_CHK_DONE_CLEAR_IN                       => reg_interrupt_clear(8),
      IRQ_CHK_ERR_DATA_CLEAR_IN                   => reg_interrupt_clear(9),
      IRQ_CHK_ERR_SIZE_CLEAR_IN                   => reg_interrupt_clear(10),
      IRQ_CHK_ERR_LAST_CLEAR_IN                   => reg_interrupt_clear(11),
      IRQ_CHK_MON_TIMEOUT_READY_CLEAR_IN          => reg_interrupt_clear(12),
      IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_IN          => reg_interrupt_clear(13),
      IRQ_CHK_MON_VALID_ERROR_CLEAR_IN            => reg_interrupt_clear(14),
      IRQ_CHK_MON_DATA_ERROR_CLEAR_IN             => reg_interrupt_clear(15),
      IRQ_CHK_MON_LAST_ERROR_CLEAR_IN             => reg_interrupt_clear(16),
      IRQ_CHK_MON_USER_ERROR_CLEAR_IN             => reg_interrupt_clear(17),
      IRQ_CHK_MON_KEEP_ERROR_CLEAR_IN             => reg_interrupt_clear(18),
      IRQ_RATE_METER_TX_DONE_CLEAR_IN             => reg_interrupt_clear(19),
      IRQ_RATE_METER_TX_OVERFLOW_CLEAR_IN         => reg_interrupt_clear(20),
      IRQ_RATE_METER_RX_DONE_CLEAR_IN             => reg_interrupt_clear(21),
      IRQ_RATE_METER_RX_OVERFLOW_CLEAR_IN         => reg_interrupt_clear(22),
      IRQ_GEN_DONE_SET_IN                         => reg_interrupt_set(0),
      IRQ_GEN_MON_TIMEOUT_READY_SET_IN            => reg_interrupt_set(1),
      IRQ_GEN_MON_TIMEOUT_VALID_SET_IN            => reg_interrupt_set(2),
      IRQ_GEN_MON_VALID_ERROR_SET_IN              => reg_interrupt_set(3),
      IRQ_GEN_MON_DATA_ERROR_SET_IN               => reg_interrupt_set(4),
      IRQ_GEN_MON_LAST_ERROR_SET_IN               => reg_interrupt_set(5),
      IRQ_GEN_MON_USER_ERROR_SET_IN               => reg_interrupt_set(6),
      IRQ_GEN_MON_KEEP_ERROR_SET_IN               => reg_interrupt_set(7),
      IRQ_CHK_DONE_SET_IN                         => reg_interrupt_set(8),
      IRQ_CHK_ERR_DATA_SET_IN                     => reg_interrupt_set(9),
      IRQ_CHK_ERR_SIZE_SET_IN                     => reg_interrupt_set(10),
      IRQ_CHK_ERR_LAST_SET_IN                     => reg_interrupt_set(11),
      IRQ_CHK_MON_TIMEOUT_READY_SET_IN            => reg_interrupt_set(12),
      IRQ_CHK_MON_TIMEOUT_VALID_SET_IN            => reg_interrupt_set(13),
      IRQ_CHK_MON_VALID_ERROR_SET_IN              => reg_interrupt_set(14),
      IRQ_CHK_MON_DATA_ERROR_SET_IN               => reg_interrupt_set(15),
      IRQ_CHK_MON_LAST_ERROR_SET_IN               => reg_interrupt_set(16),
      IRQ_CHK_MON_USER_ERROR_SET_IN               => reg_interrupt_set(17),
      IRQ_CHK_MON_KEEP_ERROR_SET_IN               => reg_interrupt_set(18),
      IRQ_RATE_METER_TX_DONE_SET_IN               => reg_interrupt_set(19),
      IRQ_RATE_METER_TX_OVERFLOW_SET_IN           => reg_interrupt_set(20),
      IRQ_RATE_METER_RX_DONE_SET_IN               => reg_interrupt_set(21),
      IRQ_RATE_METER_RX_OVERFLOW_SET_IN           => reg_interrupt_set(22),
      IRQ_GEN_DONE_STATUS                         => reg_interrupt_status(0),
      IRQ_GEN_MON_TIMEOUT_READY_STATUS            => reg_interrupt_status(1),
      IRQ_GEN_MON_TIMEOUT_VALID_STATUS            => reg_interrupt_status(2),
      IRQ_GEN_MON_VALID_ERROR_STATUS              => reg_interrupt_status(3),
      IRQ_GEN_MON_DATA_ERROR_STATUS               => reg_interrupt_status(4),
      IRQ_GEN_MON_LAST_ERROR_STATUS               => reg_interrupt_status(5),
      IRQ_GEN_MON_USER_ERROR_STATUS               => reg_interrupt_status(6),
      IRQ_GEN_MON_KEEP_ERROR_STATUS               => reg_interrupt_status(7),
      IRQ_CHK_DONE_STATUS                         => reg_interrupt_status(8),
      IRQ_CHK_ERR_DATA_STATUS                     => reg_interrupt_status(9),
      IRQ_CHK_ERR_SIZE_STATUS                     => reg_interrupt_status(10),
      IRQ_CHK_ERR_LAST_STATUS                     => reg_interrupt_status(11),
      IRQ_CHK_MON_TIMEOUT_READY_STATUS            => reg_interrupt_status(12),
      IRQ_CHK_MON_TIMEOUT_VALID_STATUS            => reg_interrupt_status(13),
      IRQ_CHK_MON_VALID_ERROR_STATUS              => reg_interrupt_status(14),
      IRQ_CHK_MON_DATA_ERROR_STATUS               => reg_interrupt_status(15),
      IRQ_CHK_MON_LAST_ERROR_STATUS               => reg_interrupt_status(16),
      IRQ_CHK_MON_USER_ERROR_STATUS               => reg_interrupt_status(17),
      IRQ_CHK_MON_KEEP_ERROR_STATUS               => reg_interrupt_status(18),
      IRQ_RATE_METER_TX_DONE_STATUS               => reg_interrupt_status(19),
      IRQ_RATE_METER_TX_OVERFLOW_STATUS           => reg_interrupt_status(20),
      IRQ_RATE_METER_RX_DONE_STATUS               => reg_interrupt_status(21),
      IRQ_RATE_METER_RX_OVERFLOW_STATUS           => reg_interrupt_status(22),

      ----------------------
      -- Registers output data
      ----------------------

      LOOPBACK_MAC_EN                             => LOOPBACK_MAC_EN,
      LOOPBACK_UDP_EN                             => LOOPBACK_UDP_EN,
      GEN_ENABLE                                  => GEN_ENABLE,
      GEN_FRAME_SIZE_TYPE                         => GEN_FRAME_SIZE_TYPE,
      CHK_ENABLE                                  => CHK_ENABLE,
      CHK_FRAME_SIZE_TYPE                         => CHK_FRAME_SIZE_TYPE,
      GEN_NB_FRAMES                               => GEN_NB_FRAMES,
      GEN_FRAME_SIZE_STATIC                       => GEN_FRAME_SIZE_STATIC,
      GEN_RATE_NB_TRANSFERS                       => GEN_RATE_NB_TRANSFERS,
      GEN_RATE_WINDOW_SIZE                        => GEN_RATE_WINDOW_SIZE,
      GEN_MON_TIMEOUT_VALUE                       => GEN_MON_TIMEOUT_VALUE,
      CHK_NB_FRAMES                               => CHK_NB_FRAMES,
      CHK_FRAME_SIZE_STATIC                       => CHK_FRAME_SIZE_STATIC,
      CHK_MON_TIMEOUT_VALUE                       => CHK_MON_TIMEOUT_VALUE,
      LB_GEN_DEST_PORT                            => LB_GEN_DEST_PORT,
      LB_GEN_SRC_PORT                             => LB_GEN_SRC_PORT,
      LB_GEN_DEST_IP_ADDR                         => LB_GEN_DEST_IP_ADDR,
      CHK_LISTENING_PORT                          => CHK_LISTENING_PORT,
      TX_RM_BYTES_EXPT_LSB                        => TX_RM_BYTES_EXPT_LSB,
      TX_RM_BYTES_EXPT_MSB                        => TX_RM_BYTES_EXPT_MSB,
      RX_RM_BYTES_EXPT_LSB                        => RX_RM_BYTES_EXPT_LSB,
      RX_RM_BYTES_EXPT_MSB                        => RX_RM_BYTES_EXPT_MSB,
      TX_RM_INIT_COUNTER_OUT                      => TX_RM_INIT_COUNTER_OUT,
      RX_RM_INIT_COUNTER_OUT                      => RX_RM_INIT_COUNTER_OUT,
      REG_TX_RATE_METER_CTRL_WRITE                => REG_TX_RATE_METER_CTRL_WRITE,
      REG_RX_RATE_METER_CTRL_WRITE                => REG_RX_RATE_METER_CTRL_WRITE,
      IRQ_GEN_DONE_ENABLE                         => reg_interrupt_enable(0),
      IRQ_GEN_MON_TIMEOUT_READY_ENABLE            => reg_interrupt_enable(1),
      IRQ_GEN_MON_TIMEOUT_VALID_ENABLE            => reg_interrupt_enable(2),
      IRQ_GEN_MON_VALID_ERROR_ENABLE              => reg_interrupt_enable(3),
      IRQ_GEN_MON_DATA_ERROR_ENABLE               => reg_interrupt_enable(4),
      IRQ_GEN_MON_LAST_ERROR_ENABLE               => reg_interrupt_enable(5),
      IRQ_GEN_MON_USER_ERROR_ENABLE               => reg_interrupt_enable(6),
      IRQ_GEN_MON_KEEP_ERROR_ENABLE               => reg_interrupt_enable(7),
      IRQ_CHK_DONE_ENABLE                         => reg_interrupt_enable(8),
      IRQ_CHK_ERR_DATA_ENABLE                     => reg_interrupt_enable(9),
      IRQ_CHK_ERR_SIZE_ENABLE                     => reg_interrupt_enable(10),
      IRQ_CHK_ERR_LAST_ENABLE                     => reg_interrupt_enable(11),
      IRQ_CHK_MON_TIMEOUT_READY_ENABLE            => reg_interrupt_enable(12),
      IRQ_CHK_MON_TIMEOUT_VALID_ENABLE            => reg_interrupt_enable(13),
      IRQ_CHK_MON_VALID_ERROR_ENABLE              => reg_interrupt_enable(14),
      IRQ_CHK_MON_DATA_ERROR_ENABLE               => reg_interrupt_enable(15),
      IRQ_CHK_MON_LAST_ERROR_ENABLE               => reg_interrupt_enable(16),
      IRQ_CHK_MON_USER_ERROR_ENABLE               => reg_interrupt_enable(17),
      IRQ_CHK_MON_KEEP_ERROR_ENABLE               => reg_interrupt_enable(18),
      IRQ_RATE_METER_TX_DONE_ENABLE               => reg_interrupt_enable(19),
      IRQ_RATE_METER_TX_OVERFLOW_ENABLE           => reg_interrupt_enable(20),
      IRQ_RATE_METER_RX_DONE_ENABLE               => reg_interrupt_enable(21),
      IRQ_RATE_METER_RX_OVERFLOW_ENABLE           => reg_interrupt_enable(22),
      IRQ_GEN_DONE_CLEAR_OUT                      => reg_interrupt_clear(0),
      IRQ_GEN_MON_TIMEOUT_READY_CLEAR_OUT         => reg_interrupt_clear(1),
      IRQ_GEN_MON_TIMEOUT_VALID_CLEAR_OUT         => reg_interrupt_clear(2),
      IRQ_GEN_MON_VALID_ERROR_CLEAR_OUT           => reg_interrupt_clear(3),
      IRQ_GEN_MON_DATA_ERROR_CLEAR_OUT            => reg_interrupt_clear(4),
      IRQ_GEN_MON_LAST_ERROR_CLEAR_OUT            => reg_interrupt_clear(5),
      IRQ_GEN_MON_USER_ERROR_CLEAR_OUT            => reg_interrupt_clear(6),
      IRQ_GEN_MON_KEEP_ERROR_CLEAR_OUT            => reg_interrupt_clear(7),
      IRQ_CHK_DONE_CLEAR_OUT                      => reg_interrupt_clear(8),
      IRQ_CHK_ERR_DATA_CLEAR_OUT                  => reg_interrupt_clear(9),
      IRQ_CHK_ERR_SIZE_CLEAR_OUT                  => reg_interrupt_clear(10),
      IRQ_CHK_ERR_LAST_CLEAR_OUT                  => reg_interrupt_clear(11),
      IRQ_CHK_MON_TIMEOUT_READY_CLEAR_OUT         => reg_interrupt_clear(12),
      IRQ_CHK_MON_TIMEOUT_VALID_CLEAR_OUT         => reg_interrupt_clear(13),
      IRQ_CHK_MON_VALID_ERROR_CLEAR_OUT           => reg_interrupt_clear(14),
      IRQ_CHK_MON_DATA_ERROR_CLEAR_OUT            => reg_interrupt_clear(15),
      IRQ_CHK_MON_LAST_ERROR_CLEAR_OUT            => reg_interrupt_clear(16),
      IRQ_CHK_MON_USER_ERROR_CLEAR_OUT            => reg_interrupt_clear(17),
      IRQ_CHK_MON_KEEP_ERROR_CLEAR_OUT            => reg_interrupt_clear(18),
      IRQ_RATE_METER_TX_DONE_CLEAR_OUT            => reg_interrupt_clear(19),
      IRQ_RATE_METER_TX_OVERFLOW_CLEAR_OUT        => reg_interrupt_clear(20),
      IRQ_RATE_METER_RX_DONE_CLEAR_OUT            => reg_interrupt_clear(21),
      IRQ_RATE_METER_RX_OVERFLOW_CLEAR_OUT        => reg_interrupt_clear(22),
      IRQ_GEN_DONE_SET_OUT                        => reg_interrupt_set(0),
      IRQ_GEN_MON_TIMEOUT_READY_SET_OUT           => reg_interrupt_set(1),
      IRQ_GEN_MON_TIMEOUT_VALID_SET_OUT           => reg_interrupt_set(2),
      IRQ_GEN_MON_VALID_ERROR_SET_OUT             => reg_interrupt_set(3),
      IRQ_GEN_MON_DATA_ERROR_SET_OUT              => reg_interrupt_set(4),
      IRQ_GEN_MON_LAST_ERROR_SET_OUT              => reg_interrupt_set(5),
      IRQ_GEN_MON_USER_ERROR_SET_OUT              => reg_interrupt_set(6),
      IRQ_GEN_MON_KEEP_ERROR_SET_OUT              => reg_interrupt_set(7),
      IRQ_CHK_DONE_SET_OUT                        => reg_interrupt_set(8),
      IRQ_CHK_ERR_DATA_SET_OUT                    => reg_interrupt_set(9),
      IRQ_CHK_ERR_SIZE_SET_OUT                    => reg_interrupt_set(10),
      IRQ_CHK_ERR_LAST_SET_OUT                    => reg_interrupt_set(11),
      IRQ_CHK_MON_TIMEOUT_READY_SET_OUT           => reg_interrupt_set(12),
      IRQ_CHK_MON_TIMEOUT_VALID_SET_OUT           => reg_interrupt_set(13),
      IRQ_CHK_MON_VALID_ERROR_SET_OUT             => reg_interrupt_set(14),
      IRQ_CHK_MON_DATA_ERROR_SET_OUT              => reg_interrupt_set(15),
      IRQ_CHK_MON_LAST_ERROR_SET_OUT              => reg_interrupt_set(16),
      IRQ_CHK_MON_USER_ERROR_SET_OUT              => reg_interrupt_set(17),
      IRQ_CHK_MON_KEEP_ERROR_SET_OUT              => reg_interrupt_set(18),
      IRQ_RATE_METER_TX_DONE_SET_OUT              => reg_interrupt_set(19),
      IRQ_RATE_METER_TX_OVERFLOW_SET_OUT          => reg_interrupt_set(20),
      IRQ_RATE_METER_RX_DONE_SET_OUT              => reg_interrupt_set(21),
      IRQ_RATE_METER_RX_OVERFLOW_SET_OUT          => reg_interrupt_set(22),
      REG_INTERRUPT_CLEAR_WRITE                   => reg_interrupt_clear_write,
      REG_INTERRUPT_SET_WRITE                     => reg_interrupt_set_write



    );



  -------------------------------------------------------------
  -- interrupt instanciation
  -------------------------------------------------------------
  inst_reg_interrupt_interruptions : interruptions
    generic map(
      G_STATUS_WIDTH    => 23,
      G_ACTIVE_RST      => '1',
      G_ASYNC_RST       => false
    )
    port map(
      CLK               => S_AXI_ACLK,
      RST               => S_AXI_ARESET,
      
      IRQ_SOURCES(0)    => IRQ_GEN_DONE,
      IRQ_SOURCES(1)    => IRQ_GEN_MON_TIMEOUT_READY,
      IRQ_SOURCES(2)    => IRQ_GEN_MON_TIMEOUT_VALID,
      IRQ_SOURCES(3)    => IRQ_GEN_MON_VALID_ERROR,
      IRQ_SOURCES(4)    => IRQ_GEN_MON_DATA_ERROR,
      IRQ_SOURCES(5)    => IRQ_GEN_MON_LAST_ERROR,
      IRQ_SOURCES(6)    => IRQ_GEN_MON_USER_ERROR,
      IRQ_SOURCES(7)    => IRQ_GEN_MON_KEEP_ERROR,
      IRQ_SOURCES(8)    => IRQ_CHK_DONE,
      IRQ_SOURCES(9)    => IRQ_CHK_ERR_DATA,
      IRQ_SOURCES(10)   => IRQ_CHK_ERR_SIZE,
      IRQ_SOURCES(11)   => IRQ_CHK_ERR_LAST,
      IRQ_SOURCES(12)   => IRQ_CHK_MON_TIMEOUT_READY,
      IRQ_SOURCES(13)   => IRQ_CHK_MON_TIMEOUT_VALID,
      IRQ_SOURCES(14)   => IRQ_CHK_MON_VALID_ERROR,
      IRQ_SOURCES(15)   => IRQ_CHK_MON_DATA_ERROR,
      IRQ_SOURCES(16)   => IRQ_CHK_MON_LAST_ERROR,
      IRQ_SOURCES(17)   => IRQ_CHK_MON_USER_ERROR,
      IRQ_SOURCES(18)   => IRQ_CHK_MON_KEEP_ERROR,
      IRQ_SOURCES(19)   => IRQ_RATE_METER_TX_DONE,
      IRQ_SOURCES(20)   => IRQ_RATE_METER_TX_OVERFLOW,
      IRQ_SOURCES(21)   => IRQ_RATE_METER_RX_DONE,
      IRQ_SOURCES(22)   => IRQ_RATE_METER_RX_OVERFLOW,
 
      IRQ_STATUS_RO     => reg_interrupt_status,
      IRQ_ENABLE_RW     => reg_interrupt_enable,
      IRQ_CLEAR_WO      => reg_interrupt_clear,
      IRQ_CLEAR_WRITE   => reg_interrupt_clear_write,
      IRQ_SET_WO        => reg_interrupt_set,
      IRQ_SET_WRITE     => reg_interrupt_set_write,
      IRQ               => REG_INTERRUPT
    );



end rtl;
