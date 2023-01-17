-- Copyright (c) 2022-2022 THALES. All Rights Reserved
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
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
    LOOPBACK_MAC_EN_IN                          : in  std_logic;                                       -- Enable Loopback on MAC interface
    LOOPBACK_UDP_EN_IN                          : in  std_logic;                                       -- Enable Loopback on UDP interface
    GEN_START_IN                                : in  std_logic;                                       -- Start the Axis Frame Checker
    GEN_STOP_IN                                 : in  std_logic;                                       -- Start the Axis Frame Checker
    CHK_START_IN                                : in  std_logic;                                       -- Start the Axis Frame Checker
    CHK_STOP_IN                                 : in  std_logic;                                       -- Stop the Axis Frame Checker
    TX_RM_INIT_COUNTER_IN                       : in  std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    RX_RM_INIT_COUNTER_IN                       : in  std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)

    ----------------------
    -- Registers output data
    ----------------------
    -- RW Registers 
    GEN_FRAME_SIZE_TYPE                         : out std_logic;                                       -- Frame size type : '0' => static, '1' => dynamic
    GEN_FRAME_SIZE_STATIC                       : out std_logic_vector(15 downto 0);                   -- Frame size used in static mode
    GEN_RATE_LIMITATION                         : out std_logic_vector(7 downto 0);                    -- Rate limitation / Example : 50% = (2^7)-1
    GEN_NB_BYTES_LSB                            : out std_logic_vector(31 downto 0);                   -- Number of bytes to generate (LSB)
    GEN_NB_BYTES_MSB                            : out std_logic_vector(31 downto 0);                   -- Number of bytes to generate (MSB)
    CHK_FRAME_SIZE_TYPE                         : out std_logic;                                       -- Frame size type : '0' => static, '1' => dynamic
    CHK_FRAME_SIZE_STATIC                       : out std_logic_vector(15 downto 0);                   -- Frame size used in static mode
    CHK_RATE_LIMITATION                         : out std_logic_vector(7 downto 0);                    -- Rate limitation / Example : 50% = (2^7)-1
    CHK_NB_BYTES_LSB                            : out std_logic_vector(31 downto 0);                   -- Number of bytes to check (LSB)
    CHK_NB_BYTES_MSB                            : out std_logic_vector(31 downto 0);                   -- Number of bytes to check (MSB)
    LB_GEN_DEST_PORT                            : out std_logic_vector(15 downto 0);                   -- Destination port use for generated frames and loopback
    LB_GEN_SRC_PORT                             : out std_logic_vector(15 downto 0);                   -- Source port use for generated frames and loopback
    LB_GEN_DEST_IP_ADDR                         : out std_logic_vector(31 downto 0);                   -- Destination IP Address use for generated frames and loopback
    CHK_LISTENING_PORT                          : out std_logic_vector(15 downto 0);                   -- Listening port of integrated checker
    TX_RM_BYTES_EXPT_LSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (LSB)
    TX_RM_BYTES_EXPT_MSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (MSB)
    RX_RM_BYTES_EXPT_LSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (LSB)
    RX_RM_BYTES_EXPT_MSB                        : out std_logic_vector(31 downto 0);                   -- Number of bytes expected during the measurment (MSB)
    -- WO Registers 
    LOOPBACK_MAC_EN_OUT                         : out std_logic;                                       -- Enable Loopback on MAC interface
    LOOPBACK_UDP_EN_OUT                         : out std_logic;                                       -- Enable Loopback on UDP interface
    GEN_START_OUT                               : out std_logic;                                       -- Start the Axis Frame Checker
    GEN_STOP_OUT                                : out std_logic;                                       -- Start the Axis Frame Checker
    CHK_START_OUT                               : out std_logic;                                       -- Start the Axis Frame Checker
    CHK_STOP_OUT                                : out std_logic;                                       -- Stop the Axis Frame Checker
    TX_RM_INIT_COUNTER_OUT                      : out std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    RX_RM_INIT_COUNTER_OUT                      : out std_logic;                                       -- Initialization of Rate meter counter (take into account when trigger is asserted)
    -- WO Pulses Registers 
    REG_GEN_CHK_CONTROL_WRITE                   : out std_logic;
    REG_TX_RATE_METER_CTRL_WRITE                : out std_logic;
    REG_RX_RATE_METER_CTRL_WRITE                : out std_logic;

    ----------------------
    -- IRQ
    ---------------------
    -- IRQ sources
    IRQ_GEN_DONE                                : in  std_logic;                                       -- End of frames generation
    IRQ_GEN_ERR_TIMEOUT                         : in  std_logic;                                       -- Timeout reach during generation of frames
    IRQ_CHK_DONE                                : in  std_logic;                                       -- End of frames verification
    IRQ_CHK_ERR_FRAME_SIZE                      : in  std_logic;                                       -- Frame size error detection
    IRQ_CHK_ERR_DATA                            : in  std_logic;                                       -- Data error detection
    IRQ_CHK_ERR_TIMEOUT                         : in  std_logic;                                       -- Timeout reach during checking of frames
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
  signal reg_interrupt_status                        : std_logic_vector(9 downto 0); 

  -- IRQ Enable register
  signal reg_interrupt_enable                        : std_logic_vector(9 downto 0); 

  -- IRQ clear register
  signal reg_interrupt_clear                         : std_logic_vector(9 downto 0); 
  signal reg_interrupt_clear_write                   : std_logic; 

  -- IRQ set register
  signal reg_interrupt_set                           : std_logic_vector(9 downto 0); 
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
      LOOPBACK_MAC_EN_IN                          => LOOPBACK_MAC_EN_IN, 
      LOOPBACK_UDP_EN_IN                          => LOOPBACK_UDP_EN_IN, 
      GEN_START_IN                                => GEN_START_IN, 
      GEN_STOP_IN                                 => GEN_STOP_IN, 
      CHK_START_IN                                => CHK_START_IN, 
      CHK_STOP_IN                                 => CHK_STOP_IN, 
      TX_RM_INIT_COUNTER_IN                       => TX_RM_INIT_COUNTER_IN, 
      RX_RM_INIT_COUNTER_IN                       => RX_RM_INIT_COUNTER_IN, 
      IRQ_GEN_DONE_CLEAR_in                       => reg_interrupt_clear(0), 
      IRQ_GEN_ERR_TIMEOUT_CLEAR_in                => reg_interrupt_clear(1), 
      IRQ_CHK_DONE_CLEAR_in                       => reg_interrupt_clear(2), 
      IRQ_CHK_ERR_FRAME_SIZE_CLEAR_in             => reg_interrupt_clear(3), 
      IRQ_CHK_ERR_DATA_CLEAR_in                   => reg_interrupt_clear(4), 
      IRQ_CHK_ERR_TIMEOUT_CLEAR_in                => reg_interrupt_clear(5), 
      IRQ_RATE_METER_TX_DONE_CLEAR_in             => reg_interrupt_clear(6), 
      IRQ_RATE_METER_TX_OVERFLOW_CLEAR_in         => reg_interrupt_clear(7), 
      IRQ_RATE_METER_RX_DONE_CLEAR_in             => reg_interrupt_clear(8), 
      IRQ_RATE_METER_RX_OVERFLOW_CLEAR_in         => reg_interrupt_clear(9), 
      IRQ_GEN_DONE_SET_in                         => reg_interrupt_set(0), 
      IRQ_GEN_ERR_TIMEOUT_SET_in                  => reg_interrupt_set(1), 
      IRQ_CHK_DONE_SET_in                         => reg_interrupt_set(2), 
      IRQ_CHK_ERR_FRAME_SIZE_SET_in               => reg_interrupt_set(3), 
      IRQ_CHK_ERR_DATA_SET_in                     => reg_interrupt_set(4), 
      IRQ_CHK_ERR_TIMEOUT_SET_in                  => reg_interrupt_set(5), 
      IRQ_RATE_METER_TX_DONE_SET_in               => reg_interrupt_set(6), 
      IRQ_RATE_METER_TX_OVERFLOW_SET_in           => reg_interrupt_set(7), 
      IRQ_RATE_METER_RX_DONE_SET_in               => reg_interrupt_set(8), 
      IRQ_RATE_METER_RX_OVERFLOW_SET_in           => reg_interrupt_set(9), 
      IRQ_GEN_DONE_STATUS                         => reg_interrupt_status(0), 
      IRQ_GEN_ERR_TIMEOUT_STATUS                  => reg_interrupt_status(1), 
      IRQ_CHK_DONE_STATUS                         => reg_interrupt_status(2), 
      IRQ_CHK_ERR_FRAME_SIZE_STATUS               => reg_interrupt_status(3), 
      IRQ_CHK_ERR_DATA_STATUS                     => reg_interrupt_status(4), 
      IRQ_CHK_ERR_TIMEOUT_STATUS                  => reg_interrupt_status(5), 
      IRQ_RATE_METER_TX_DONE_STATUS               => reg_interrupt_status(6), 
      IRQ_RATE_METER_TX_OVERFLOW_STATUS           => reg_interrupt_status(7), 
      IRQ_RATE_METER_RX_DONE_STATUS               => reg_interrupt_status(8), 
      IRQ_RATE_METER_RX_OVERFLOW_STATUS           => reg_interrupt_status(9), 

      ----------------------
      -- Registers output data
      ----------------------

      GEN_FRAME_SIZE_TYPE                         => GEN_FRAME_SIZE_TYPE, 
      GEN_FRAME_SIZE_STATIC                       => GEN_FRAME_SIZE_STATIC, 
      GEN_RATE_LIMITATION                         => GEN_RATE_LIMITATION, 
      GEN_NB_BYTES_LSB                            => GEN_NB_BYTES_LSB, 
      GEN_NB_BYTES_MSB                            => GEN_NB_BYTES_MSB, 
      CHK_FRAME_SIZE_TYPE                         => CHK_FRAME_SIZE_TYPE, 
      CHK_FRAME_SIZE_STATIC                       => CHK_FRAME_SIZE_STATIC, 
      CHK_RATE_LIMITATION                         => CHK_RATE_LIMITATION, 
      CHK_NB_BYTES_LSB                            => CHK_NB_BYTES_LSB, 
      CHK_NB_BYTES_MSB                            => CHK_NB_BYTES_MSB, 
      LB_GEN_DEST_PORT                            => LB_GEN_DEST_PORT, 
      LB_GEN_SRC_PORT                             => LB_GEN_SRC_PORT, 
      LB_GEN_DEST_IP_ADDR                         => LB_GEN_DEST_IP_ADDR, 
      CHK_LISTENING_PORT                          => CHK_LISTENING_PORT, 
      TX_RM_BYTES_EXPT_LSB                        => TX_RM_BYTES_EXPT_LSB, 
      TX_RM_BYTES_EXPT_MSB                        => TX_RM_BYTES_EXPT_MSB, 
      RX_RM_BYTES_EXPT_LSB                        => RX_RM_BYTES_EXPT_LSB, 
      RX_RM_BYTES_EXPT_MSB                        => RX_RM_BYTES_EXPT_MSB, 
      LOOPBACK_MAC_EN_OUT                         => LOOPBACK_MAC_EN_OUT, 
      LOOPBACK_UDP_EN_OUT                         => LOOPBACK_UDP_EN_OUT, 
      GEN_START_OUT                               => GEN_START_OUT, 
      GEN_STOP_OUT                                => GEN_STOP_OUT, 
      CHK_START_OUT                               => CHK_START_OUT, 
      CHK_STOP_OUT                                => CHK_STOP_OUT, 
      TX_RM_INIT_COUNTER_OUT                      => TX_RM_INIT_COUNTER_OUT, 
      RX_RM_INIT_COUNTER_OUT                      => RX_RM_INIT_COUNTER_OUT, 
      REG_GEN_CHK_CONTROL_WRITE                   => REG_GEN_CHK_CONTROL_WRITE, 
      REG_TX_RATE_METER_CTRL_WRITE                => REG_TX_RATE_METER_CTRL_WRITE, 
      REG_RX_RATE_METER_CTRL_WRITE                => REG_RX_RATE_METER_CTRL_WRITE, 
      IRQ_GEN_DONE_ENABLE                         => reg_interrupt_enable(0), 
      IRQ_GEN_ERR_TIMEOUT_ENABLE                  => reg_interrupt_enable(1), 
      IRQ_CHK_DONE_ENABLE                         => reg_interrupt_enable(2), 
      IRQ_CHK_ERR_FRAME_SIZE_ENABLE               => reg_interrupt_enable(3), 
      IRQ_CHK_ERR_DATA_ENABLE                     => reg_interrupt_enable(4), 
      IRQ_CHK_ERR_TIMEOUT_ENABLE                  => reg_interrupt_enable(5), 
      IRQ_RATE_METER_TX_DONE_ENABLE               => reg_interrupt_enable(6), 
      IRQ_RATE_METER_TX_OVERFLOW_ENABLE           => reg_interrupt_enable(7), 
      IRQ_RATE_METER_RX_DONE_ENABLE               => reg_interrupt_enable(8), 
      IRQ_RATE_METER_RX_OVERFLOW_ENABLE           => reg_interrupt_enable(9), 
      IRQ_GEN_DONE_CLEAR_OUT                      => reg_interrupt_clear(0), 
      IRQ_GEN_ERR_TIMEOUT_CLEAR_OUT               => reg_interrupt_clear(1), 
      IRQ_CHK_DONE_CLEAR_OUT                      => reg_interrupt_clear(2), 
      IRQ_CHK_ERR_FRAME_SIZE_CLEAR_OUT            => reg_interrupt_clear(3), 
      IRQ_CHK_ERR_DATA_CLEAR_OUT                  => reg_interrupt_clear(4), 
      IRQ_CHK_ERR_TIMEOUT_CLEAR_OUT               => reg_interrupt_clear(5), 
      IRQ_RATE_METER_TX_DONE_CLEAR_OUT            => reg_interrupt_clear(6), 
      IRQ_RATE_METER_TX_OVERFLOW_CLEAR_OUT        => reg_interrupt_clear(7), 
      IRQ_RATE_METER_RX_DONE_CLEAR_OUT            => reg_interrupt_clear(8), 
      IRQ_RATE_METER_RX_OVERFLOW_CLEAR_OUT        => reg_interrupt_clear(9), 
      IRQ_GEN_DONE_SET_OUT                        => reg_interrupt_set(0), 
      IRQ_GEN_ERR_TIMEOUT_SET_OUT                 => reg_interrupt_set(1), 
      IRQ_CHK_DONE_SET_OUT                        => reg_interrupt_set(2), 
      IRQ_CHK_ERR_FRAME_SIZE_SET_OUT              => reg_interrupt_set(3), 
      IRQ_CHK_ERR_DATA_SET_OUT                    => reg_interrupt_set(4), 
      IRQ_CHK_ERR_TIMEOUT_SET_OUT                 => reg_interrupt_set(5), 
      IRQ_RATE_METER_TX_DONE_SET_OUT              => reg_interrupt_set(6), 
      IRQ_RATE_METER_TX_OVERFLOW_SET_OUT          => reg_interrupt_set(7), 
      IRQ_RATE_METER_RX_DONE_SET_OUT              => reg_interrupt_set(8), 
      IRQ_RATE_METER_RX_OVERFLOW_SET_OUT          => reg_interrupt_set(9), 
      REG_INTERRUPT_CLEAR_WRITE                   => reg_interrupt_clear_WRITE, 
      REG_INTERRUPT_SET_WRITE                     => reg_interrupt_set_WRITE 



    );



  -------------------------------------------------------------
  -- interrupt instanciation
  -------------------------------------------------------------
  inst_reg_interrupt_interruptions : interruptions
    generic map(
      G_STATUS_WIDTH    => 10,
      G_ACTIVE_RST      => '1',
      G_ASYNC_RST       => false
    )
    port map(
      CLK               => S_AXI_ACLK,
      RST               => S_AXI_ARESET,
      
      IRQ_SOURCES(0)    => IRQ_GEN_DONE, 
      IRQ_SOURCES(1)    => IRQ_GEN_ERR_TIMEOUT, 
      IRQ_SOURCES(2)    => IRQ_CHK_DONE, 
      IRQ_SOURCES(3)    => IRQ_CHK_ERR_FRAME_SIZE, 
      IRQ_SOURCES(4)    => IRQ_CHK_ERR_DATA, 
      IRQ_SOURCES(5)    => IRQ_CHK_ERR_TIMEOUT, 
      IRQ_SOURCES(6)    => IRQ_RATE_METER_TX_DONE, 
      IRQ_SOURCES(7)    => IRQ_RATE_METER_TX_OVERFLOW, 
      IRQ_SOURCES(8)    => IRQ_RATE_METER_RX_DONE, 
      IRQ_SOURCES(9)    => IRQ_RATE_METER_RX_OVERFLOW, 
 
      IRQ_STATUS_RO     => reg_interrupt_status,
      IRQ_ENABLE_RW     => reg_interrupt_enable,
      IRQ_CLEAR_WO      => reg_interrupt_clear,
      IRQ_CLEAR_WRITE   => reg_interrupt_clear_write,
      IRQ_SET_WO        => reg_interrupt_set,
      IRQ_SET_WRITE     => reg_interrupt_set_write,
      IRQ               => REG_INTERRUPT
    );



end rtl;
