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
entity main_uoe_registers_itf is
  port(
    ----------------------
    -- AXI4-Lite bus
    ----------------------
    S_AXI_ACLK                                        : in  std_logic;                                             -- Global clock signal
    S_AXI_ARESET                                      : in  std_logic;                                             -- Global reset signal synchronous to clock S_AXI_ACLK
    S_AXI_AWADDR                                      : in  std_logic_vector(7 downto 0);                          -- Write address (issued by master, accepted by Slave)
    S_AXI_AWVALID                                     : in  std_logic_vector(0 downto 0);                          -- Write address valid: this signal indicates that the master is signalling valid write address and control information.
    S_AXI_AWREADY                                     : out std_logic_vector(0 downto 0);                          -- Write address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_WDATA                                       : in  std_logic_vector(31 downto 0);                         -- Write data (issued by master, accepted by slave)
    S_AXI_WVALID                                      : in  std_logic_vector(0 downto 0);                          -- Write valid: this signal indicates that valid write data and strobes are available.
    S_AXI_WSTRB                                       : in  std_logic_vector(3 downto 0);                          -- Write strobes: WSTRB[n:0] signals when HIGH, specify the byte lanes of the data bus that contain valid information
    S_AXI_WREADY                                      : out std_logic_vector(0 downto 0);                          -- Write ready: this signal indicates that the slave can accept the write data.
    S_AXI_BRESP                                       : out std_logic_vector(1 downto 0);                          -- Write response: this signal indicates the status of the write transaction.
    S_AXI_BVALID                                      : out std_logic_vector(0 downto 0);                          -- Write response valid: this signal indicates that the channel is signalling a valid write response.
    S_AXI_BREADY                                      : in  std_logic_vector(0 downto 0);                          -- Response ready: this signal indicates that the master can accept a write response.
    S_AXI_ARADDR                                      : in  std_logic_vector(7 downto 0);                          -- Read address (issued by master, accepted by Slave)
    S_AXI_ARVALID                                     : in  std_logic_vector(0 downto 0);                          -- Read address valid: this signal indicates that the channel is signalling valid read address and control information.
    S_AXI_ARREADY                                     : out std_logic_vector(0 downto 0);                          -- Read address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_RDATA                                       : out std_logic_vector(31 downto 0);                         -- Read data (issued by slave)
    S_AXI_RRESP                                       : out std_logic_vector(1 downto 0);                          -- Read response: this signal indicates the status of the read transfer.
    S_AXI_RVALID                                      : out std_logic_vector(0 downto 0);                          -- Read valid: this signal indicates that the channel is signalling the required read data.
    S_AXI_RREADY                                      : in  std_logic_vector(0 downto 0);                          -- Read ready: this signal indicates that the master can accept the read data and response information.

    ----------------------
    -- Input data for registers
    ----------------------
    -- RO Registers
    VERSION                                           : in  std_logic_vector(7 downto 0);                          -- Version number
    REVISION                                          : in  std_logic_vector(7 downto 0);                          -- Revision number
    DEBUG                                             : in  std_logic_vector(15 downto 0);                         -- Debug number
    -- RZ Registers
    CRC_FILTER_COUNTER                                : in  std_logic_vector(31 downto 0);                         -- Number of frames filtered because of bad CRC
    MAC_FILTER_COUNTER                                : in  std_logic_vector(31 downto 0);                         -- Number of frames filtered following MAC configuration
    EXT_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on externe interface
    RAW_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on raw interface
    UDP_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on udp interface
    -- WO Registers
    ARP_SW_REQ_DEST_IP_ADDR_IN                        : in  std_logic_vector(31 downto 0);                         -- Destination IP Address use to generate software request ARP

    ----------------------
    -- Registers output data
    ----------------------
    -- RW Registers
    LOCAL_MAC_ADDR_LSB                                : out std_logic_vector(31 downto 0);                         -- Local MAC Address LSB
    LOCAL_MAC_ADDR_MSB                                : out std_logic_vector(15 downto 0);                         -- Local MAC Address MSB
    LOCAL_IP_ADDR                                     : out std_logic_vector(31 downto 0);                         -- Local IP Address
    RAW_DEST_MAC_ADDR_LSB                             : out std_logic_vector(31 downto 0);                         -- Destination MAC Address use for RAW Ethernet (LSB)
    RAW_DEST_MAC_ADDR_MSB                             : out std_logic_vector(15 downto 0);                         -- Destination MAC Address use for RAW Ethernet (MSB)
    TTL                                               : out std_logic_vector(7 downto 0);                          -- Time To Leave value insert in IPV4 Header
    BROADCAST_FILTER_ENABLE                           : out std_logic;                                             -- Broadcast frames filtering enabling
    IPV4_MULTICAST_FILTER_ENABLE                      : out std_logic;                                             -- IPv4 multicast frames filtering enabling
    UNICAST_FILTER_ENABLE                             : out std_logic;                                             -- Unicast frames filtering enabling (neither IPv4 multicast nor broadcast)
    MULTICAST_IP_ADDR_1                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 1 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_1_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 1 enabling
    MULTICAST_IP_ADDR_2                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 2 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_2_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 2 enabling
    MULTICAST_IP_ADDR_3                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 3 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_3_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 3 enabling
    MULTICAST_IP_ADDR_4                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 4 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_4_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 4 enabling
    ARP_TIMEOUT_MS                                    : out std_logic_vector(11 downto 0);                         -- Timeout for ARP request (milliseconds)
    ARP_TRYINGS                                       : out std_logic_vector(3 downto 0);                          -- Number of ARP requests tryings
    ARP_GRATUITOUS_REQ                                : out std_logic;                                             -- Request sending "Gratuitous ARP"
    ARP_RX_TARGET_IP_FILTER                           : out std_logic_vector(1 downto 0);                          -- Set ARP Rx Frame filter (0 : unicast, 1 : unicast + broadcast, 2 : all, 3 : none)
    ARP_RX_TEST_LOCAL_IP_CONFLICT                     : out std_logic;                                             -- Enable test "Local IP ADDR conflict"
    ARP_TABLE_CLEAR                                   : out std_logic;                                             -- Clear ARP Table (Should be drive like a pulse : '0' => '1' => '0')
    CONFIG_DONE                                       : out std_logic;                                             -- Flag Configuration Done
    -- WO Registers
    ARP_SW_REQ_DEST_IP_ADDR_OUT                       : out std_logic_vector(31 downto 0);                         -- Destination IP Address use to generate software request ARP
    -- WO Pulses Registers
    REG_ARP_SW_REQ_WRITE                              : out std_logic;
    -- RZ Pulses Registers
    REG_MONITORING_CRC_FILTER_READ                    : out std_logic;
    REG_MONITORING_MAC_FILTER_READ                    : out std_logic;
    REG_MONITORING_EXT_DROP_READ                      : out std_logic;
    REG_MONITORING_RAW_DROP_READ                      : out std_logic;
    REG_MONITORING_UDP_DROP_READ                      : out std_logic;

    ----------------------
    -- IRQ
    ---------------------
    -- IRQ sources
    IRQ_INIT_DONE                                     : in  std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE                          : in  std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT                               : in  std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT                              : in  std_logic;                                             -- Field description
    IRQ_ARP_ERROR                                     : in  std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW                          : in  std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW                  : in  std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW                   : in  std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR                     : in  std_logic;                                             -- Field description

    -- output
    -- IRQ output
    REG_INTERRUPT                                     : out std_logic

  );
end main_uoe_registers_itf;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of main_uoe_registers_itf is


  -- Irq Status register
  signal reg_interrupt_status                              : std_logic_vector(8 downto 0);

  -- IRQ Enable register
  signal reg_interrupt_enable                              : std_logic_vector(8 downto 0);

  -- IRQ clear register
  signal reg_interrupt_clear                               : std_logic_vector(8 downto 0);
  signal reg_interrupt_clear_write                         : std_logic;

  -- IRQ set register
  signal reg_interrupt_set                                 : std_logic_vector(8 downto 0);
  signal reg_interrupt_set_write                           : std_logic;



begin

  ------------------------------------------------------------------------
  -- registers instanciation
  ------------------------------------------------------------------------
  inst_main_uoe_registers : main_uoe_registers
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

      VERSION                                           => VERSION,
      REVISION                                          => REVISION,
      DEBUG                                             => DEBUG,
      CRC_FILTER_COUNTER                                => CRC_FILTER_COUNTER,
      MAC_FILTER_COUNTER                                => MAC_FILTER_COUNTER,
      EXT_DROP_COUNTER                                  => EXT_DROP_COUNTER,
      RAW_DROP_COUNTER                                  => RAW_DROP_COUNTER,
      UDP_DROP_COUNTER                                  => UDP_DROP_COUNTER,
      ARP_SW_REQ_DEST_IP_ADDR_IN                        => ARP_SW_REQ_DEST_IP_ADDR_IN,
      IRQ_INIT_DONE_CLEAR_IN                            => reg_interrupt_clear(0),
      IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_IN                 => reg_interrupt_clear(1),
      IRQ_ARP_IP_CONFLICT_CLEAR_IN                      => reg_interrupt_clear(2),
      IRQ_ARP_MAC_CONFLICT_CLEAR_IN                     => reg_interrupt_clear(3),
      IRQ_ARP_ERROR_CLEAR_IN                            => reg_interrupt_clear(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_IN                 => reg_interrupt_clear(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_IN         => reg_interrupt_clear(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_IN          => reg_interrupt_clear(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_IN            => reg_interrupt_clear(8),
      IRQ_INIT_DONE_SET_IN                              => reg_interrupt_set(0),
      IRQ_ARP_TABLE_CLEAR_DONE_SET_IN                   => reg_interrupt_set(1),
      IRQ_ARP_IP_CONFLICT_SET_IN                        => reg_interrupt_set(2),
      IRQ_ARP_MAC_CONFLICT_SET_IN                       => reg_interrupt_set(3),
      IRQ_ARP_ERROR_SET_IN                              => reg_interrupt_set(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_SET_IN                   => reg_interrupt_set(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_IN           => reg_interrupt_set(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_IN            => reg_interrupt_set(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_IN              => reg_interrupt_set(8),
      IRQ_INIT_DONE_STATUS                              => reg_interrupt_status(0),
      IRQ_ARP_TABLE_CLEAR_DONE_STATUS                   => reg_interrupt_status(1),
      IRQ_ARP_IP_CONFLICT_STATUS                        => reg_interrupt_status(2),
      IRQ_ARP_MAC_CONFLICT_STATUS                       => reg_interrupt_status(3),
      IRQ_ARP_ERROR_STATUS                              => reg_interrupt_status(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_STATUS                   => reg_interrupt_status(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_STATUS           => reg_interrupt_status(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_STATUS            => reg_interrupt_status(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_STATUS              => reg_interrupt_status(8),

      ----------------------
      -- Registers output data
      ----------------------

      LOCAL_MAC_ADDR_LSB                                => LOCAL_MAC_ADDR_LSB,
      LOCAL_MAC_ADDR_MSB                                => LOCAL_MAC_ADDR_MSB,
      LOCAL_IP_ADDR                                     => LOCAL_IP_ADDR,
      RAW_DEST_MAC_ADDR_LSB                             => RAW_DEST_MAC_ADDR_LSB,
      RAW_DEST_MAC_ADDR_MSB                             => RAW_DEST_MAC_ADDR_MSB,
      TTL                                               => TTL,
      BROADCAST_FILTER_ENABLE                           => BROADCAST_FILTER_ENABLE,
      IPV4_MULTICAST_FILTER_ENABLE                      => IPV4_MULTICAST_FILTER_ENABLE,
      UNICAST_FILTER_ENABLE                             => UNICAST_FILTER_ENABLE,
      MULTICAST_IP_ADDR_1                               => MULTICAST_IP_ADDR_1,
      MULTICAST_IP_ADDR_1_ENABLE                        => MULTICAST_IP_ADDR_1_ENABLE,
      MULTICAST_IP_ADDR_2                               => MULTICAST_IP_ADDR_2,
      MULTICAST_IP_ADDR_2_ENABLE                        => MULTICAST_IP_ADDR_2_ENABLE,
      MULTICAST_IP_ADDR_3                               => MULTICAST_IP_ADDR_3,
      MULTICAST_IP_ADDR_3_ENABLE                        => MULTICAST_IP_ADDR_3_ENABLE,
      MULTICAST_IP_ADDR_4                               => MULTICAST_IP_ADDR_4,
      MULTICAST_IP_ADDR_4_ENABLE                        => MULTICAST_IP_ADDR_4_ENABLE,
      ARP_TIMEOUT_MS                                    => ARP_TIMEOUT_MS,
      ARP_TRYINGS                                       => ARP_TRYINGS,
      ARP_GRATUITOUS_REQ                                => ARP_GRATUITOUS_REQ,
      ARP_RX_TARGET_IP_FILTER                           => ARP_RX_TARGET_IP_FILTER,
      ARP_RX_TEST_LOCAL_IP_CONFLICT                     => ARP_RX_TEST_LOCAL_IP_CONFLICT,
      ARP_TABLE_CLEAR                                   => ARP_TABLE_CLEAR,
      CONFIG_DONE                                       => CONFIG_DONE,
      ARP_SW_REQ_DEST_IP_ADDR_OUT                       => ARP_SW_REQ_DEST_IP_ADDR_OUT,
      REG_MONITORING_CRC_FILTER_READ                    => REG_MONITORING_CRC_FILTER_READ,
      REG_MONITORING_MAC_FILTER_READ                    => REG_MONITORING_MAC_FILTER_READ,
      REG_MONITORING_EXT_DROP_READ                      => REG_MONITORING_EXT_DROP_READ,
      REG_MONITORING_RAW_DROP_READ                      => REG_MONITORING_RAW_DROP_READ,
      REG_MONITORING_UDP_DROP_READ                      => REG_MONITORING_UDP_DROP_READ,
      REG_ARP_SW_REQ_WRITE                              => REG_ARP_SW_REQ_WRITE,
      IRQ_INIT_DONE_ENABLE                              => reg_interrupt_enable(0),
      IRQ_ARP_TABLE_CLEAR_DONE_ENABLE                   => reg_interrupt_enable(1),
      IRQ_ARP_IP_CONFLICT_ENABLE                        => reg_interrupt_enable(2),
      IRQ_ARP_MAC_CONFLICT_ENABLE                       => reg_interrupt_enable(3),
      IRQ_ARP_ERROR_ENABLE                              => reg_interrupt_enable(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_ENABLE                   => reg_interrupt_enable(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_ENABLE           => reg_interrupt_enable(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_ENABLE            => reg_interrupt_enable(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_ENABLE              => reg_interrupt_enable(8),
      IRQ_INIT_DONE_CLEAR_OUT                           => reg_interrupt_clear(0),
      IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_OUT                => reg_interrupt_clear(1),
      IRQ_ARP_IP_CONFLICT_CLEAR_OUT                     => reg_interrupt_clear(2),
      IRQ_ARP_MAC_CONFLICT_CLEAR_OUT                    => reg_interrupt_clear(3),
      IRQ_ARP_ERROR_CLEAR_OUT                           => reg_interrupt_clear(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_OUT                => reg_interrupt_clear(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_OUT        => reg_interrupt_clear(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_OUT         => reg_interrupt_clear(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_OUT           => reg_interrupt_clear(8),
      IRQ_INIT_DONE_SET_OUT                             => reg_interrupt_set(0),
      IRQ_ARP_TABLE_CLEAR_DONE_SET_OUT                  => reg_interrupt_set(1),
      IRQ_ARP_IP_CONFLICT_SET_OUT                       => reg_interrupt_set(2),
      IRQ_ARP_MAC_CONFLICT_SET_OUT                      => reg_interrupt_set(3),
      IRQ_ARP_ERROR_SET_OUT                             => reg_interrupt_set(4),
      IRQ_ARP_RX_FIFO_OVERFLOW_SET_OUT                  => reg_interrupt_set(5),
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_OUT          => reg_interrupt_set(6),
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_OUT           => reg_interrupt_set(7),
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_OUT             => reg_interrupt_set(8),
      REG_INTERRUPT_CLEAR_WRITE                         => reg_interrupt_clear_write,
      REG_INTERRUPT_SET_WRITE                           => reg_interrupt_set_write



    );



  -------------------------------------------------------------
  -- interrupt instanciation
  -------------------------------------------------------------
  inst_reg_interrupt_interruptions : interruptions
    generic map(
      G_STATUS_WIDTH    => 9,
      G_ACTIVE_RST      => '1',
      G_ASYNC_RST       => false
    )
    port map(
      CLK               => S_AXI_ACLK,
      RST               => S_AXI_ARESET,
      
      IRQ_SOURCES(0)    => IRQ_INIT_DONE,
      IRQ_SOURCES(1)    => IRQ_ARP_TABLE_CLEAR_DONE,
      IRQ_SOURCES(2)    => IRQ_ARP_IP_CONFLICT,
      IRQ_SOURCES(3)    => IRQ_ARP_MAC_CONFLICT,
      IRQ_SOURCES(4)    => IRQ_ARP_ERROR,
      IRQ_SOURCES(5)    => IRQ_ARP_RX_FIFO_OVERFLOW,
      IRQ_SOURCES(6)    => IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW,
      IRQ_SOURCES(7)    => IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW,
      IRQ_SOURCES(8)    => IRQ_IPV4_RX_FRAG_OFFSET_ERROR,
 
      IRQ_STATUS_RO     => reg_interrupt_status,
      IRQ_ENABLE_RW     => reg_interrupt_enable,
      IRQ_CLEAR_WO      => reg_interrupt_clear,
      IRQ_CLEAR_WRITE   => reg_interrupt_clear_write,
      IRQ_SET_WO        => reg_interrupt_set,
      IRQ_SET_WRITE     => reg_interrupt_set_write,
      IRQ               => REG_INTERRUPT
    );



end rtl;
