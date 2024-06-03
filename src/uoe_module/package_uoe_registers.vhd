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


package package_uoe_registers is

  component interruptions is
    generic (
      G_STATUS_WIDTH  : natural   := 1;                   -- Number of IRQs
      G_ACTIVE_RST    : std_logic := '1';               -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST     : boolean   := false              -- Type of reset used (synchronous or asynchronous resets)
    );
    port (
      CLK             : in  std_logic;
      RST             : in  std_logic;
      IRQ_SOURCES     : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt sources vector
      IRQ_STATUS_RO   : out std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt status vector
      IRQ_ENABLE_RW   : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt enable vector
      IRQ_CLEAR_WO    : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Clear interrupt status vector
      IRQ_CLEAR_WRITE : in  std_logic;                                    -- Clear interrupt status
      IRQ_SET_WO      : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Set interrupt status vector
      IRQ_SET_WRITE   : in  std_logic;                                    -- Set interrupt status
      IRQ             : out std_logic
    );
  end component interruptions;


  -- Main

  component main_uoe_registers is
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
      -- Irq WO Registers
      IRQ_INIT_DONE_CLEAR_IN                            : in  std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_IN                 : in  std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_CLEAR_IN                      : in  std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_CLEAR_IN                     : in  std_logic;                                             -- Field description
      IRQ_ARP_ERROR_CLEAR_IN                            : in  std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_IN                 : in  std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_IN         : in  std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_IN          : in  std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_IN            : in  std_logic;                                             -- Field description
      IRQ_INIT_DONE_SET_IN                              : in  std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_SET_IN                   : in  std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_SET_IN                        : in  std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_SET_IN                       : in  std_logic;                                             -- Field description
      IRQ_ARP_ERROR_SET_IN                              : in  std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_SET_IN                   : in  std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_IN           : in  std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_IN            : in  std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_IN              : in  std_logic;                                             -- Field description
      -- Irq RO Registers
      IRQ_INIT_DONE_STATUS                              : in  std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_STATUS                   : in  std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_STATUS                        : in  std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_STATUS                       : in  std_logic;                                             -- Field description
      IRQ_ARP_ERROR_STATUS                              : in  std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_STATUS                   : in  std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_STATUS           : in  std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_STATUS            : in  std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_STATUS              : in  std_logic;                                             -- Field description

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
      -- Irq RW Registers
      IRQ_INIT_DONE_ENABLE                              : out std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_ENABLE                   : out std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_ENABLE                        : out std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_ENABLE                       : out std_logic;                                             -- Field description
      IRQ_ARP_ERROR_ENABLE                              : out std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_ENABLE                   : out std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_ENABLE           : out std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_ENABLE            : out std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_ENABLE              : out std_logic;                                             -- Field description
      -- Irq WO Registers
      IRQ_INIT_DONE_CLEAR_OUT                           : out std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_OUT                : out std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_CLEAR_OUT                     : out std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_CLEAR_OUT                    : out std_logic;                                             -- Field description
      IRQ_ARP_ERROR_CLEAR_OUT                           : out std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_OUT                : out std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_OUT        : out std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_OUT         : out std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_OUT           : out std_logic;                                             -- Field description
      IRQ_INIT_DONE_SET_OUT                             : out std_logic;                                             -- Field description
      IRQ_ARP_TABLE_CLEAR_DONE_SET_OUT                  : out std_logic;                                             -- Field description
      IRQ_ARP_IP_CONFLICT_SET_OUT                       : out std_logic;                                             -- Field description
      IRQ_ARP_MAC_CONFLICT_SET_OUT                      : out std_logic;                                             -- Field description
      IRQ_ARP_ERROR_SET_OUT                             : out std_logic;                                             -- Field description
      IRQ_ARP_RX_FIFO_OVERFLOW_SET_OUT                  : out std_logic;                                             -- Field description
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_OUT          : out std_logic;                                             -- Field description
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_OUT           : out std_logic;                                             -- Field description
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_OUT             : out std_logic;                                             -- Field description
      -- Irq WO Pulses Registers
      REG_INTERRUPT_CLEAR_WRITE                         : out std_logic;
      REG_INTERRUPT_SET_WRITE                           : out std_logic

    );
  end component main_uoe_registers;

  -- Itf Main

  component main_uoe_registers_itf is
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
  end component main_uoe_registers_itf;

  -- Test

  component test_uoe_registers is
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
  end component test_uoe_registers;

  -- Itf Test

  component test_uoe_registers_itf is
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
  end component test_uoe_registers_itf;



  constant C_MAIN_REG_VERSION                                                                  : std_logic_vector(7 downto 0):="00000000";
  constant C_MAIN_REG_INTERRUPT_STATUS                                                         : std_logic_vector(7 downto 0):="01010100";
  constant C_MAIN_REG_ARP_SW_REQ                                                               : std_logic_vector(7 downto 0):="00110100";
  constant C_MAIN_REG_INTERRUPT_CLEAR                                                          : std_logic_vector(7 downto 0):="01011100";
  constant C_MAIN_REG_INTERRUPT_SET                                                            : std_logic_vector(7 downto 0):="01100000";
  constant C_MAIN_REG_LOCAL_MAC_ADDR_LSB                                                       : std_logic_vector(7 downto 0):="00000100";
  constant C_MAIN_REG_LOCAL_MAC_ADDR_MSB                                                       : std_logic_vector(7 downto 0):="00001000";
  constant C_MAIN_REG_LOCAL_IP_ADDR                                                            : std_logic_vector(7 downto 0):="00001100";
  constant C_MAIN_REG_RAW_DEST_MAC_ADDR_LSB                                                    : std_logic_vector(7 downto 0):="00010000";
  constant C_MAIN_REG_RAW_DEST_MAC_ADDR_MSB                                                    : std_logic_vector(7 downto 0):="00010100";
  constant C_MAIN_REG_IPV4_TIME_TO_LEAVE                                                       : std_logic_vector(7 downto 0):="00011000";
  constant C_MAIN_REG_FILTERING_CONTROL                                                        : std_logic_vector(7 downto 0):="00011100";
  constant C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_1                                                 : std_logic_vector(7 downto 0):="00100000";
  constant C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_2                                                 : std_logic_vector(7 downto 0):="00100100";
  constant C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_3                                                 : std_logic_vector(7 downto 0):="00101000";
  constant C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_4                                                 : std_logic_vector(7 downto 0):="00101100";
  constant C_MAIN_REG_ARP_CONFIGURATION                                                        : std_logic_vector(7 downto 0):="00110000";
  constant C_MAIN_REG_CONFIG_DONE                                                              : std_logic_vector(7 downto 0):="00111000";
  constant C_MAIN_REG_INTERRUPT_ENABLE                                                         : std_logic_vector(7 downto 0):="01011000";
  constant C_MAIN_REG_MONITORING_CRC_FILTER                                                    : std_logic_vector(7 downto 0):="01000000";
  constant C_MAIN_REG_MONITORING_MAC_FILTER                                                    : std_logic_vector(7 downto 0):="01000100";
  constant C_MAIN_REG_MONITORING_EXT_DROP                                                      : std_logic_vector(7 downto 0):="01001000";
  constant C_MAIN_REG_MONITORING_RAW_DROP                                                      : std_logic_vector(7 downto 0):="01001100";
  constant C_MAIN_REG_MONITORING_UDP_DROP                                                      : std_logic_vector(7 downto 0):="01010000";
  constant C_TEST_REG_GEN_TEST_DURATION_LSB                                        : std_logic_vector(7 downto 0):="00010000";
  constant C_TEST_REG_GEN_TEST_DURATION_MSB                                        : std_logic_vector(7 downto 0):="00010100";
  constant C_TEST_REG_CHK_TEST_DURATION_LSB                                        : std_logic_vector(7 downto 0):="00100000";
  constant C_TEST_REG_CHK_TEST_DURATION_MSB                                        : std_logic_vector(7 downto 0):="00100100";
  constant C_TEST_REG_TX_RM_CNT_BYTES_LSB                                          : std_logic_vector(7 downto 0):="01010000";
  constant C_TEST_REG_TX_RM_CNT_BYTES_MSB                                          : std_logic_vector(7 downto 0):="01010100";
  constant C_TEST_REG_TX_RM_CNT_CYCLES_LSB                                         : std_logic_vector(7 downto 0):="01011000";
  constant C_TEST_REG_TX_RM_CNT_CYCLES_MSB                                         : std_logic_vector(7 downto 0):="01011100";
  constant C_TEST_REG_RX_RM_CNT_BYTES_LSB                                          : std_logic_vector(7 downto 0):="01101100";
  constant C_TEST_REG_RX_RM_CNT_BYTES_MSB                                          : std_logic_vector(7 downto 0):="01110000";
  constant C_TEST_REG_RX_RM_CNT_CYCLES_LSB                                         : std_logic_vector(7 downto 0):="01110100";
  constant C_TEST_REG_RX_RM_CNT_CYCLES_MSB                                         : std_logic_vector(7 downto 0):="01111000";
  constant C_TEST_REG_INTERRUPT_STATUS                                             : std_logic_vector(7 downto 0):="00110100";
  constant C_TEST_REG_TX_RATE_METER_CTRL                                           : std_logic_vector(7 downto 0):="01000100";
  constant C_TEST_REG_RX_RATE_METER_CTRL                                           : std_logic_vector(7 downto 0):="01100000";
  constant C_TEST_REG_INTERRUPT_CLEAR                                              : std_logic_vector(7 downto 0):="00111100";
  constant C_TEST_REG_INTERRUPT_SET                                                : std_logic_vector(7 downto 0):="01000000";
  constant C_TEST_REG_GEN_CHK_CONTROL                                              : std_logic_vector(7 downto 0):="00000000";
  constant C_TEST_REG_GEN_FRAME                                                    : std_logic_vector(7 downto 0):="00000100";
  constant C_TEST_REG_GEN_RATE                                                     : std_logic_vector(7 downto 0):="00001000";
  constant C_TEST_REG_GEN_MONITOR                                                  : std_logic_vector(7 downto 0):="00001100";
  constant C_TEST_REG_CHK_FRAME                                                    : std_logic_vector(7 downto 0):="00011000";
  constant C_TEST_REG_CHK_MONITOR                                                  : std_logic_vector(7 downto 0):="00011100";
  constant C_TEST_REG_LB_GEN_UDP_PORT                                              : std_logic_vector(7 downto 0):="00101000";
  constant C_TEST_REG_LB_GEN_DEST_IP_ADDR                                          : std_logic_vector(7 downto 0):="00101100";
  constant C_TEST_REG_CHK_UDP_PORT                                                 : std_logic_vector(7 downto 0):="00110000";
  constant C_TEST_REG_TX_RM_BYTES_EXPT_LSB                                         : std_logic_vector(7 downto 0):="01001000";
  constant C_TEST_REG_TX_RM_BYTES_EXPT_MSB                                         : std_logic_vector(7 downto 0):="01001100";
  constant C_TEST_REG_RX_FM_BYTES_EXPT_LSB                                         : std_logic_vector(7 downto 0):="01100100";
  constant C_TEST_REG_RX_RM_BYTES_EXPT_MSB                                         : std_logic_vector(7 downto 0):="01101000";
  constant C_TEST_REG_INTERRUPT_ENABLE                                             : std_logic_vector(7 downto 0):="00111000";


end package_uoe_registers;


-------------------------------------------
-- Package Body
-------------------------------------------
package body package_uoe_registers is

end package_uoe_registers;
