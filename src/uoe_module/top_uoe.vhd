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
use ieee.math_real.all;

--------------------------------------
-- TOP UOE
--------------------------------------
--
-- This module is the top entity of the IP
-- It instanciate the uoe_core (functionnal part of the design) and some integrated tests tools
--
--------------------------------------

library common;
use common.axi4lite_utils_pkg.axi4lite_switch;

use work.uoe_module_pkg.all;

entity top_uoe is
  generic(
    G_ACTIVE_RST          : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST           : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_ENABLE_ARP_MODULE   : boolean   := true; -- Enable or disable ARP Module
    G_ENABLE_ARP_TABLE    : boolean   := true; -- Disable ARP Table IP/MAC Addr.
    G_ENABLE_TESTENV      : boolean   := true; -- Enable UDP/MAC/PCS&PMA loopbacks according to reg. select
    G_ENABLE_PKT_DROP_EXT : boolean   := true; -- Enable Packet DROP on EXT RX interface
    G_ENABLE_PKT_DROP_RAW : boolean   := true; -- Enable Packet DROP on RAW RX interface
    G_ENABLE_PKT_DROP_UDP : boolean   := true; -- Enable Packet DROP on UDP RX interface
    G_MAC_TDATA_WIDTH     : integer   := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_UOE_TDATA_WIDTH     : integer   := 64; -- Number of bits used along AXI datapath of UOE
    G_ROUTER_FIFO_DEPTH   : integer   := 1536; -- Depth of router Fifos (in bytes)
    G_UOE_FREQ_KHZ        : integer   := 156250 -- System Frequency use to reference timeout
  );
  port(
    -- Clock domain of MAC in rx
    CLK_RX          : in  std_logic;
    RST_RX          : in  std_logic;
    -- Clock domain of MAC in tx
    CLK_TX          : in  std_logic;
    RST_TX          : in  std_logic;
    -- Internal clock domain
    CLK_UOE         : in  std_logic;
    RST_UOE         : in  std_logic;
    -- Status Physical Layer
    PHY_LAYER_RDY   : in  std_logic;
    -- UOE Interrupt Output
    INTERRUPT       : out std_logic_vector(1 downto 0); -- bit 0 => Main interrupt, bit 1 => Test interrupt
    -- Interface MAC with Physical interface
    S_MAC_RX_TDATA  : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
    S_MAC_RX_TVALID : in  std_logic;
    S_MAC_RX_TLAST  : in  std_logic;
    S_MAC_RX_TKEEP  : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
    S_MAC_RX_TUSER  : in  std_logic;
    M_MAC_TX_TDATA  : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
    M_MAC_TX_TVALID : out std_logic;
    M_MAC_TX_TLAST  : out std_logic;
    M_MAC_TX_TKEEP  : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
    M_MAC_TX_TUSER  : out std_logic;
    M_MAC_TX_TREADY : in  std_logic;
    -- Interface EXT
    S_EXT_TX_TDATA  : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    S_EXT_TX_TVALID : in  std_logic;
    S_EXT_TX_TLAST  : in  std_logic;
    S_EXT_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_EXT_TX_TREADY : out std_logic;
    M_EXT_RX_TDATA  : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    M_EXT_RX_TVALID : out std_logic;
    M_EXT_RX_TLAST  : out std_logic;
    M_EXT_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_EXT_RX_TREADY : in  std_logic;
    -- Interface RAW
    S_RAW_TX_TDATA  : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_RAW_TX_TVALID : in  std_logic;
    S_RAW_TX_TLAST  : in  std_logic;
    S_RAW_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_RAW_TX_TUSER  : in  std_logic_vector(15 downto 0); -- Frame Size
    S_RAW_TX_TREADY : out std_logic;
    M_RAW_RX_TDATA  : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_RAW_RX_TVALID : out std_logic;
    M_RAW_RX_TLAST  : out std_logic;
    M_RAW_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_RAW_RX_TUSER  : out std_logic_vector(15 downto 0); -- Frame Size
    M_RAW_RX_TREADY : in  std_logic;
    -- Interface UDP
    S_UDP_TX_TDATA  : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_UDP_TX_TVALID : in  std_logic;
    S_UDP_TX_TLAST  : in  std_logic;
    S_UDP_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_UDP_TX_TUSER  : in  std_logic_vector(79 downto 0);
    S_UDP_TX_TREADY : out std_logic;
    M_UDP_RX_TDATA  : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_UDP_RX_TVALID : out std_logic;
    M_UDP_RX_TLAST  : out std_logic;
    M_UDP_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_UDP_RX_TUSER  : out std_logic_vector(79 downto 0);
    M_UDP_RX_TREADY : in  std_logic;
    -- AXI4-Lite interface to registers
    S_AXI_AWADDR    : in  std_logic_vector(13 downto 0);
    S_AXI_AWVALID   : in  std_logic;
    S_AXI_AWREADY   : out std_logic;
    S_AXI_WDATA     : in  std_logic_vector(31 downto 0);
    S_AXI_WVALID    : in  std_logic;
    S_AXI_WSTRB     : in  std_logic_vector(3 downto 0);
    S_AXI_WREADY    : out std_logic;
    S_AXI_BRESP     : out std_logic_vector(1 downto 0);
    S_AXI_BVALID    : out std_logic;
    S_AXI_BREADY    : in  std_logic;
    S_AXI_ARADDR    : in  std_logic_vector(13 downto 0);
    S_AXI_ARVALID   : in  std_logic;
    S_AXI_ARREADY   : out std_logic;
    S_AXI_RDATA     : out std_logic_vector(31 downto 0);
    S_AXI_RRESP     : out std_logic_vector(1 downto 0);
    S_AXI_RVALID    : out std_logic;
    S_AXI_RREADY    : in  std_logic
  );
end top_uoe;

architecture rtl of top_uoe is

  component uoe_core is
    generic(
      G_ACTIVE_RST          : std_logic := '0';
      G_ASYNC_RST           : boolean   := false;
      G_MAC_TDATA_WIDTH     : integer   := 64;
      G_UOE_TDATA_WIDTH     : integer   := 64;
      G_ROUTER_FIFO_DEPTH   : integer   := 1536;
      G_ENABLE_ARP_MODULE   : boolean   := true;
      G_ENABLE_ARP_TABLE    : boolean   := true;
      G_ENABLE_PKT_DROP_EXT : boolean   := true;
      G_ENABLE_PKT_DROP_RAW : boolean   := true;
      G_ENABLE_PKT_DROP_UDP : boolean   := true;
      G_UOE_FREQ_KHZ        : integer   := 156250
    );
    port(
      CLK_RX                  : in  std_logic;
      RST_RX                  : in  std_logic;
      CLK_TX                  : in  std_logic;
      RST_TX                  : in  std_logic;
      CLK_UOE                 : in  std_logic;
      RST_UOE                 : in  std_logic;
      PHY_LAYER_RDY           : in  std_logic;
      INTERRUPT               : out std_logic;
      S_MAC_RX_TDATA          : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      S_MAC_RX_TVALID         : in  std_logic;
      S_MAC_RX_TLAST          : in  std_logic;
      S_MAC_RX_TKEEP          : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      S_MAC_RX_TUSER          : in  std_logic;
      M_MAC_TX_TDATA          : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      M_MAC_TX_TVALID         : out std_logic;
      M_MAC_TX_TLAST          : out std_logic;
      M_MAC_TX_TKEEP          : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      M_MAC_TX_TUSER          : out std_logic;
      M_MAC_TX_TREADY         : in  std_logic;
      S_EXT_TX_TDATA          : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_TVALID         : in  std_logic;
      S_EXT_TX_TLAST          : in  std_logic;
      S_EXT_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_TREADY         : out std_logic;
      M_EXT_RX_TDATA          : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_TVALID         : out std_logic;
      M_EXT_RX_TLAST          : out std_logic;
      M_EXT_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_TREADY         : in  std_logic;
      S_RAW_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_RAW_TX_TVALID         : in  std_logic;
      S_RAW_TX_TLAST          : in  std_logic;
      S_RAW_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_RAW_TX_TUSER          : in  std_logic_vector(15 downto 0);
      S_RAW_TX_TREADY         : out std_logic;
      M_RAW_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_RAW_RX_TVALID         : out std_logic;
      M_RAW_RX_TLAST          : out std_logic;
      M_RAW_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_RAW_RX_TUSER          : out std_logic_vector(15 downto 0);
      M_RAW_RX_TREADY         : in  std_logic;
      S_UDP_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_UDP_TX_TVALID         : in  std_logic;
      S_UDP_TX_TLAST          : in  std_logic;
      S_UDP_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_UDP_TX_TUSER          : in  std_logic_vector(79 downto 0);
      S_UDP_TX_TREADY         : out std_logic;
      M_UDP_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_UDP_RX_TVALID         : out std_logic;
      M_UDP_RX_TLAST          : out std_logic;
      M_UDP_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_UDP_RX_TUSER          : out std_logic_vector(79 downto 0);
      M_UDP_RX_TREADY         : in  std_logic;
      S_AXI_AWADDR            : in  std_logic_vector(7 downto 0);
      S_AXI_AWVALID           : in  std_logic;
      S_AXI_AWREADY           : out std_logic;
      S_AXI_WDATA             : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID            : in  std_logic;
      S_AXI_WSTRB             : in  std_logic_vector(3 downto 0);
      S_AXI_WREADY            : out std_logic;
      S_AXI_BRESP             : out std_logic_vector(1 downto 0);
      S_AXI_BVALID            : out std_logic;
      S_AXI_BREADY            : in  std_logic;
      S_AXI_ARADDR            : in  std_logic_vector(7 downto 0);
      S_AXI_ARVALID           : in  std_logic;
      S_AXI_ARREADY           : out std_logic;
      S_AXI_RDATA             : out std_logic_vector(31 downto 0);
      S_AXI_RRESP             : out std_logic_vector(1 downto 0);
      S_AXI_RVALID            : out std_logic;
      S_AXI_RREADY            : in  std_logic;
      S_AXI_ARP_TABLE_AWADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_AWVALID : in  std_logic;
      S_AXI_ARP_TABLE_AWREADY : out std_logic;
      S_AXI_ARP_TABLE_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_WVALID  : in  std_logic;
      S_AXI_ARP_TABLE_WREADY  : out std_logic;
      S_AXI_ARP_TABLE_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_BVALID  : out std_logic;
      S_AXI_ARP_TABLE_BREADY  : in  std_logic;
      S_AXI_ARP_TABLE_ARADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_ARVALID : in  std_logic;
      S_AXI_ARP_TABLE_ARREADY : out std_logic;
      S_AXI_ARP_TABLE_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_RVALID  : out std_logic;
      S_AXI_ARP_TABLE_RREADY  : in  std_logic
    );
  end component uoe_core;

  ---------------------------------------------
  -- Constants declaration
  ---------------------------------------------

  constant C_AXI_ADDR_WIDTH : integer := 14;
  constant C_AXI_DATA_WIDTH : integer := 32;
  constant C_AXI_STRB_WIDTH : integer := C_AXI_DATA_WIDTH / 8;

  constant C_UOE_TKEEP_WIDTH : integer := (G_UOE_TDATA_WIDTH / 8);

  constant C_NB_MASTER     : integer := 3;
  constant C_IDX_MAIN_REGS : integer := 0;
  constant C_IDX_ARP_TABLE : integer := 1;
  constant C_IDX_TEST_REGS : integer := 2;

  ---------------------------------------------
  -- Signals declaration
  ---------------------------------------------

  -- AXI4lite Switch output
  signal axi_sw_awaddr  : std_logic_vector((C_NB_MASTER * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_sw_awvalid : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_awready : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_wdata   : std_logic_vector((C_NB_MASTER * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_sw_wstrb   : std_logic_vector((C_NB_MASTER * C_AXI_STRB_WIDTH) - 1 downto 0);
  signal axi_sw_wvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_wready  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_bresp   : std_logic_vector((C_NB_MASTER * 2) - 1 downto 0);
  signal axi_sw_bvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_bready  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_araddr  : std_logic_vector((C_NB_MASTER * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_sw_arvalid : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_arready : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_rdata   : std_logic_vector((C_NB_MASTER * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_sw_rvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_sw_rresp   : std_logic_vector((C_NB_MASTER * 2) - 1 downto 0);
  signal axi_sw_rready  : std_logic_vector(C_NB_MASTER - 1 downto 0);

  -- Internal signals of MAC interface
  signal axis_mac_rx_tdata  : std_logic_vector(G_MAC_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_rx_tvalid : std_logic;
  signal axis_mac_rx_tlast  : std_logic;
  signal axis_mac_rx_tkeep  : std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_mac_rx_tuser  : std_logic;

  signal axis_mac_tx_tdata  : std_logic_vector(G_MAC_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_tx_tvalid : std_logic;
  signal axis_mac_tx_tlast  : std_logic;
  signal axis_mac_tx_tkeep  : std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_mac_tx_tuser  : std_logic;
  signal axis_mac_tx_tready : std_logic;

  -- Internal signals of UDP interface
  signal axis_udp_tx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_udp_tx_tvalid : std_logic;
  signal axis_udp_tx_tlast  : std_logic;
  signal axis_udp_tx_tuser  : std_logic_vector(79 downto 0);
  signal axis_udp_tx_tkeep  : std_logic_vector(C_UOE_TKEEP_WIDTH - 1 downto 0);
  signal axis_udp_tx_tready : std_logic;

  signal axis_udp_rx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_udp_rx_tvalid : std_logic;
  signal axis_udp_rx_tlast  : std_logic;
  signal axis_udp_rx_tuser  : std_logic_vector(79 downto 0);
  signal axis_udp_rx_tkeep  : std_logic_vector(C_UOE_TKEEP_WIDTH - 1 downto 0);
  signal axis_udp_rx_tready : std_logic;

begin

  -- UOE Core
  inst_uoe_core : uoe_core
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_MAC_TDATA_WIDTH     => G_MAC_TDATA_WIDTH,
      G_UOE_TDATA_WIDTH     => G_UOE_TDATA_WIDTH,
      G_ROUTER_FIFO_DEPTH   => G_ROUTER_FIFO_DEPTH,
      G_ENABLE_ARP_MODULE   => G_ENABLE_ARP_MODULE,
      G_ENABLE_ARP_TABLE    => G_ENABLE_ARP_TABLE,
      G_ENABLE_PKT_DROP_EXT => G_ENABLE_PKT_DROP_EXT,
      G_ENABLE_PKT_DROP_RAW => G_ENABLE_PKT_DROP_RAW,
      G_ENABLE_PKT_DROP_UDP => G_ENABLE_PKT_DROP_UDP,
      G_UOE_FREQ_KHZ        => G_UOE_FREQ_KHZ
    )
    port map(
      CLK_RX                  => CLK_RX,
      RST_RX                  => RST_RX,
      CLK_TX                  => CLK_TX,
      RST_TX                  => RST_TX,
      CLK_UOE                 => CLK_UOE,
      RST_UOE                 => RST_UOE,
      PHY_LAYER_RDY           => PHY_LAYER_RDY,
      INTERRUPT               => INTERRUPT(0),
      S_MAC_RX_TDATA          => axis_mac_rx_tdata,
      S_MAC_RX_TVALID         => axis_mac_rx_tvalid,
      S_MAC_RX_TLAST          => axis_mac_rx_tlast,
      S_MAC_RX_TKEEP          => axis_mac_rx_tkeep,
      S_MAC_RX_TUSER          => axis_mac_rx_tuser,
      M_MAC_TX_TDATA          => axis_mac_tx_tdata,
      M_MAC_TX_TVALID         => axis_mac_tx_tvalid,
      M_MAC_TX_TLAST          => axis_mac_tx_tlast,
      M_MAC_TX_TKEEP          => axis_mac_tx_tkeep,
      M_MAC_TX_TUSER          => axis_mac_tx_tuser,
      M_MAC_TX_TREADY         => axis_mac_tx_tready,
      S_EXT_TX_TDATA          => S_EXT_TX_TDATA,
      S_EXT_TX_TVALID         => S_EXT_TX_TVALID,
      S_EXT_TX_TLAST          => S_EXT_TX_TLAST,
      S_EXT_TX_TKEEP          => S_EXT_TX_TKEEP,
      S_EXT_TX_TREADY         => S_EXT_TX_TREADY,
      M_EXT_RX_TDATA          => M_EXT_RX_TDATA,
      M_EXT_RX_TVALID         => M_EXT_RX_TVALID,
      M_EXT_RX_TLAST          => M_EXT_RX_TLAST,
      M_EXT_RX_TKEEP          => M_EXT_RX_TKEEP,
      M_EXT_RX_TREADY         => M_EXT_RX_TREADY,
      S_RAW_TX_TDATA          => S_RAW_TX_TDATA,
      S_RAW_TX_TVALID         => S_RAW_TX_TVALID,
      S_RAW_TX_TLAST          => S_RAW_TX_TLAST,
      S_RAW_TX_TKEEP          => S_RAW_TX_TKEEP,
      S_RAW_TX_TUSER          => S_RAW_TX_TUSER,
      S_RAW_TX_TREADY         => S_RAW_TX_TREADY,
      M_RAW_RX_TDATA          => M_RAW_RX_TDATA,
      M_RAW_RX_TVALID         => M_RAW_RX_TVALID,
      M_RAW_RX_TLAST          => M_RAW_RX_TLAST,
      M_RAW_RX_TKEEP          => M_RAW_RX_TKEEP,
      M_RAW_RX_TUSER          => M_RAW_RX_TUSER,
      M_RAW_RX_TREADY         => M_RAW_RX_TREADY,
      S_UDP_TX_TDATA          => axis_udp_tx_tdata,
      S_UDP_TX_TVALID         => axis_udp_tx_tvalid,
      S_UDP_TX_TLAST          => axis_udp_tx_tlast,
      S_UDP_TX_TKEEP          => axis_udp_tx_tkeep,
      S_UDP_TX_TUSER          => axis_udp_tx_tuser,
      S_UDP_TX_TREADY         => axis_udp_tx_tready,
      M_UDP_RX_TDATA          => axis_udp_rx_tdata,
      M_UDP_RX_TVALID         => axis_udp_rx_tvalid,
      M_UDP_RX_TLAST          => axis_udp_rx_tlast,
      M_UDP_RX_TKEEP          => axis_udp_rx_tkeep,
      M_UDP_RX_TUSER          => axis_udp_rx_tuser,
      M_UDP_RX_TREADY         => axis_udp_rx_tready,
      S_AXI_AWADDR            => axi_sw_awaddr((C_IDX_MAIN_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_MAIN_REGS * C_AXI_ADDR_WIDTH)),
      S_AXI_AWVALID           => axi_sw_awvalid(C_IDX_MAIN_REGS),
      S_AXI_AWREADY           => axi_sw_awready(C_IDX_MAIN_REGS),
      S_AXI_WDATA             => axi_sw_wdata((C_IDX_MAIN_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MAIN_REGS * C_AXI_DATA_WIDTH)),
      S_AXI_WVALID            => axi_sw_wvalid(C_IDX_MAIN_REGS),
      S_AXI_WSTRB             => axi_sw_wstrb((C_IDX_MAIN_REGS * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_MAIN_REGS * C_AXI_STRB_WIDTH)),
      S_AXI_WREADY            => axi_sw_wready(C_IDX_MAIN_REGS),
      S_AXI_BRESP             => axi_sw_bresp((C_IDX_MAIN_REGS * 2) + 1 downto (C_IDX_MAIN_REGS * 2)),
      S_AXI_BVALID            => axi_sw_bvalid(C_IDX_MAIN_REGS),
      S_AXI_BREADY            => axi_sw_bready(C_IDX_MAIN_REGS),
      S_AXI_ARADDR            => axi_sw_araddr((C_IDX_MAIN_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_MAIN_REGS * C_AXI_ADDR_WIDTH)),
      S_AXI_ARVALID           => axi_sw_arvalid(C_IDX_MAIN_REGS),
      S_AXI_ARREADY           => axi_sw_arready(C_IDX_MAIN_REGS),
      S_AXI_RDATA             => axi_sw_rdata((C_IDX_MAIN_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MAIN_REGS * C_AXI_DATA_WIDTH)),
      S_AXI_RRESP             => axi_sw_rresp((C_IDX_MAIN_REGS * 2) + 1 downto (C_IDX_MAIN_REGS * 2)),
      S_AXI_RVALID            => axi_sw_rvalid(C_IDX_MAIN_REGS),
      S_AXI_RREADY            => axi_sw_rready(C_IDX_MAIN_REGS),
      S_AXI_ARP_TABLE_AWADDR  => axi_sw_awaddr((C_IDX_ARP_TABLE * C_AXI_ADDR_WIDTH) + 11 downto (C_IDX_ARP_TABLE * C_AXI_ADDR_WIDTH)),
      S_AXI_ARP_TABLE_AWVALID => axi_sw_awvalid(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_AWREADY => axi_sw_awready(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_WDATA   => axi_sw_wdata((C_IDX_ARP_TABLE * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_ARP_TABLE * C_AXI_DATA_WIDTH)),
      S_AXI_ARP_TABLE_WVALID  => axi_sw_wvalid(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_WREADY  => axi_sw_wready(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_BRESP   => axi_sw_bresp((C_IDX_ARP_TABLE * 2) + 1 downto (C_IDX_ARP_TABLE * 2)),
      S_AXI_ARP_TABLE_BVALID  => axi_sw_bvalid(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_BREADY  => axi_sw_bready(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_ARADDR  => axi_sw_araddr((C_IDX_ARP_TABLE * C_AXI_ADDR_WIDTH) + 11 downto (C_IDX_ARP_TABLE * C_AXI_ADDR_WIDTH)),
      S_AXI_ARP_TABLE_ARVALID => axi_sw_arvalid(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_ARREADY => axi_sw_arready(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_RDATA   => axi_sw_rdata((C_IDX_ARP_TABLE * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_ARP_TABLE * C_AXI_DATA_WIDTH)),
      S_AXI_ARP_TABLE_RRESP   => axi_sw_rresp((C_IDX_ARP_TABLE * 2) + 1 downto (C_IDX_ARP_TABLE * 2)),
      S_AXI_ARP_TABLE_RVALID  => axi_sw_rvalid(C_IDX_ARP_TABLE),
      S_AXI_ARP_TABLE_RREADY  => axi_sw_rready(C_IDX_ARP_TABLE)
    );

  -- AXI4Lite Switch
  inst_axi4lite_switch : axi4lite_switch
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_DATA_WIDTH  => C_AXI_DATA_WIDTH,
      G_ADDR_WIDTH  => C_AXI_ADDR_WIDTH,
      G_NB_SLAVE    => 1,
      G_NB_MASTER   => C_NB_MASTER,
      G_BASE_ADDR   => (("00" & x"000"), ("01" & x"000"), ("10" & x"000")),
      G_ADDR_RANGE  => (8, 8, 12),
      G_ROUND_ROBIN => false
    )
    port map(
      CLK          => CLK_UOE,
      RST          => RST_UOE,
      S_AWADDR     => S_AXI_AWADDR,
      S_AWPROT     => (others => '0'),
      S_AWVALID(0) => S_AXI_AWVALID,
      S_AWREADY(0) => S_AXI_AWREADY,
      S_WDATA      => S_AXI_WDATA,
      S_WSTRB      => S_AXI_WSTRB,
      S_WVALID(0)  => S_AXI_WVALID,
      S_WREADY(0)  => S_AXI_WREADY,
      S_BRESP      => S_AXI_BRESP,
      S_BVALID(0)  => S_AXI_BVALID,
      S_BREADY(0)  => S_AXI_BREADY,
      S_ARADDR     => S_AXI_ARADDR,
      S_ARPROT     => (others => '0'),
      S_ARVALID(0) => S_AXI_ARVALID,
      S_ARREADY(0) => S_AXI_ARREADY,
      S_RDATA      => S_AXI_RDATA,
      S_RVALID(0)  => S_AXI_RVALID,
      S_RRESP      => S_AXI_RRESP,
      S_RREADY(0)  => S_AXI_RREADY,
      M_AWADDR     => axi_sw_awaddr,
      M_AWPROT     => open,
      M_AWVALID    => axi_sw_awvalid,
      M_AWREADY    => axi_sw_awready,
      M_WDATA      => axi_sw_wdata,
      M_WSTRB      => axi_sw_wstrb,
      M_WVALID     => axi_sw_wvalid,
      M_WREADY     => axi_sw_wready,
      M_BRESP      => axi_sw_bresp,
      M_BVALID     => axi_sw_bvalid,
      M_BREADY     => axi_sw_bready,
      M_ARADDR     => axi_sw_araddr,
      M_ARPROT     => open,
      M_ARVALID    => axi_sw_arvalid,
      M_ARREADY    => axi_sw_arready,
      M_RDATA      => axi_sw_rdata,
      M_RVALID     => axi_sw_rvalid,
      M_RRESP      => axi_sw_rresp,
      M_RREADY     => axi_sw_rready,
      ERR_RDDEC    => open,
      ERR_WRDEC    => open
    );

  GEN_TEST_ENV : if G_ENABLE_TESTENV generate

    ----------------------------------
    -- Components declaration
    ----------------------------------

    component axis_rate_meter is
      generic(
        G_ACTIVE_RST  : std_logic := '0';
        G_ASYNC_RST   : boolean   := false;
        G_TKEEP_WIDTH : positive  := 1;
        G_CNT_WIDTH   : positive  := 32
      );
      port(
        CLK                : in  std_logic;
        RST                : in  std_logic;
        AXIS_TKEEP         : in  std_logic_vector(G_TKEEP_WIDTH - 1 downto 0);
        AXIS_TVALID        : in  std_logic;
        AXIS_TREADY        : in  std_logic;
        TRIG_TVALID        : in  std_logic;
        TRIG_TDATA_INIT    : in  std_logic;
        TRIG_TDATA_BYTES   : in  std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
        CNT_TDATA_BYTES    : out std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
        CNT_TDATA_CYCLES   : out std_logic_vector(G_CNT_WIDTH - 1 downto 0);
        CNT_TUSER_OVERFLOW : out std_logic;
        CNT_TVALID         : out std_logic
      );
    end component axis_rate_meter;

    component uoe_integrated_tests_mac is
      generic(
        G_ACTIVE_RST      : std_logic := '0';
        G_ASYNC_RST       : boolean   := false;
        G_TDATA_WIDTH     : positive  := 64;
        G_FIFO_ADDR_WIDTH : positive  := 4
      );
      port(
        CLK_RX           : in  std_logic;
        RST_RX           : in  std_logic;
        CLK_TX           : in  std_logic;
        RST_TX           : in  std_logic;
        LOOPBACK_EN      : in  std_logic;
        S_PHY_RX_TDATA   : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        S_PHY_RX_TVALID  : in  std_logic;
        S_PHY_RX_TLAST   : in  std_logic;
        S_PHY_RX_TKEEP   : in  std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        S_PHY_RX_TUSER   : in  std_logic;
        M_CORE_RX_TDATA  : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        M_CORE_RX_TVALID : out std_logic;
        M_CORE_RX_TLAST  : out std_logic;
        M_CORE_RX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        M_CORE_RX_TUSER  : out std_logic;
        S_CORE_TX_TDATA  : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        S_CORE_TX_TVALID : in  std_logic;
        S_CORE_TX_TLAST  : in  std_logic;
        S_CORE_TX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        S_CORE_TX_TUSER  : in  std_logic;
        S_CORE_TX_TREADY : out std_logic;
        M_PHY_TX_TDATA   : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        M_PHY_TX_TVALID  : out std_logic;
        M_PHY_TX_TLAST   : out std_logic;
        M_PHY_TX_TKEEP   : out std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        M_PHY_TX_TUSER   : out std_logic;
        M_PHY_TX_TREADY  : in  std_logic
      );
    end component uoe_integrated_tests_mac;

    component uoe_integrated_tests_udp is
      generic(
        G_ACTIVE_RST      : std_logic := '0';
        G_ASYNC_RST       : boolean   := false;
        G_TDATA_WIDTH     : integer   := 64;
        G_FIFO_ADDR_WIDTH : positive  := 8
      );
      port(
        CLK                   : in  std_logic;
        RST                   : in  std_logic;
        S_CORE_RX_TDATA       : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        S_CORE_RX_TVALID      : in  std_logic;
        S_CORE_RX_TLAST       : in  std_logic;
        S_CORE_RX_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        S_CORE_RX_TUSER       : in  std_logic_vector(79 downto 0);
        S_CORE_RX_TREADY      : out std_logic;
        M_EXT_RX_TDATA        : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        M_EXT_RX_TVALID       : out std_logic;
        M_EXT_RX_TLAST        : out std_logic;
        M_EXT_RX_TKEEP        : out std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        M_EXT_RX_TUSER        : out std_logic_vector(79 downto 0);
        M_EXT_RX_TREADY       : in  std_logic;
        S_EXT_TX_TDATA        : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        S_EXT_TX_TVALID       : in  std_logic;
        S_EXT_TX_TLAST        : in  std_logic;
        S_EXT_TX_TKEEP        : in  std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        S_EXT_TX_TUSER        : in  std_logic_vector(79 downto 0);
        S_EXT_TX_TREADY       : out std_logic;
        M_CORE_TX_TDATA       : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        M_CORE_TX_TVALID      : out std_logic;
        M_CORE_TX_TLAST       : out std_logic;
        M_CORE_TX_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
        M_CORE_TX_TUSER       : out std_logic_vector(79 downto 0);
        M_CORE_TX_TREADY      : in  std_logic;
        LOOPBACK_EN           : in  std_logic;
        GEN_START_P           : in  std_logic;
        GEN_STOP_P            : in  std_logic;
        CHK_START_P           : in  std_logic;
        CHK_STOP_P            : in  std_logic;
        GEN_FRAME_SIZE_TYPE   : in  std_logic;
        GEN_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
        GEN_RATE_LIMITATION   : in  std_logic_vector(7 downto 0);
        GEN_NB_BYTES          : in  std_logic_vector(63 downto 0);
        CHK_FRAME_SIZE_TYPE   : in  std_logic;
        CHK_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
        CHK_RATE_LIMITATION   : in  std_logic_vector(7 downto 0);
        CHK_NB_BYTES          : in  std_logic_vector(63 downto 0);
        LB_GEN_DEST_PORT      : in  std_logic_vector(15 downto 0);
        LB_GEN_SRC_PORT       : in  std_logic_vector(15 downto 0);
        LB_GEN_DEST_IP_ADDR   : in  std_logic_vector(31 downto 0);
        CHK_LISTENING_PORT    : in  std_logic_vector(15 downto 0);
        GEN_TEST_DURATION     : out std_logic_vector(63 downto 0);
        GEN_DONE              : out std_logic;
        GEN_ERR_TIMEOUT       : out std_logic;
        CHK_TEST_DURATION     : out std_logic_vector(63 downto 0);
        CHK_DONE              : out std_logic;
        CHK_ERR_DATA          : out std_logic;
        CHK_ERR_TIMEOUT       : out std_logic
      );
    end component uoe_integrated_tests_udp;

    component test_uoe_registers_itf is
      port(
        S_AXI_ACLK                   : in  std_logic;
        S_AXI_ARESET                 : in  std_logic;
        S_AXI_AWADDR                 : in  std_logic_vector(7 downto 0);
        S_AXI_AWVALID                : in  std_logic_vector(0 downto 0);
        S_AXI_AWREADY                : out std_logic_vector(0 downto 0);
        S_AXI_WDATA                  : in  std_logic_vector(31 downto 0);
        S_AXI_WVALID                 : in  std_logic_vector(0 downto 0);
        S_AXI_WSTRB                  : in  std_logic_vector(3 downto 0);
        S_AXI_WREADY                 : out std_logic_vector(0 downto 0);
        S_AXI_BRESP                  : out std_logic_vector(1 downto 0);
        S_AXI_BVALID                 : out std_logic_vector(0 downto 0);
        S_AXI_BREADY                 : in  std_logic_vector(0 downto 0);
        S_AXI_ARADDR                 : in  std_logic_vector(7 downto 0);
        S_AXI_ARVALID                : in  std_logic_vector(0 downto 0);
        S_AXI_ARREADY                : out std_logic_vector(0 downto 0);
        S_AXI_RDATA                  : out std_logic_vector(31 downto 0);
        S_AXI_RRESP                  : out std_logic_vector(1 downto 0);
        S_AXI_RVALID                 : out std_logic_vector(0 downto 0);
        S_AXI_RREADY                 : in  std_logic_vector(0 downto 0);
        GEN_TEST_DURATION_LSB        : in  std_logic_vector(31 downto 0);
        GEN_TEST_DURATION_MSB        : in  std_logic_vector(31 downto 0);
        CHK_TEST_DURATION_LSB        : in  std_logic_vector(31 downto 0);
        CHK_TEST_DURATION_MSB        : in  std_logic_vector(31 downto 0);
        TX_RM_CNT_BYTES_LSB          : in  std_logic_vector(31 downto 0);
        TX_RM_CNT_BYTES_MSB          : in  std_logic_vector(31 downto 0);
        TX_RM_CNT_CYCLES_LSB         : in  std_logic_vector(31 downto 0);
        TX_RM_CNT_CYCLES_MSB         : in  std_logic_vector(31 downto 0);
        RX_RM_CNT_BYTES_LSB          : in  std_logic_vector(31 downto 0);
        RX_RM_CNT_BYTES_MSB          : in  std_logic_vector(31 downto 0);
        RX_RM_CNT_CYCLES_LSB         : in  std_logic_vector(31 downto 0);
        RX_RM_CNT_CYCLES_MSB         : in  std_logic_vector(31 downto 0);
        LOOPBACK_MAC_EN_IN           : in  std_logic;
        LOOPBACK_UDP_EN_IN           : in  std_logic;
        GEN_START_IN                 : in  std_logic;
        GEN_STOP_IN                  : in  std_logic;
        CHK_START_IN                 : in  std_logic;
        CHK_STOP_IN                  : in  std_logic;
        TX_RM_INIT_COUNTER_IN        : in  std_logic;
        RX_RM_INIT_COUNTER_IN        : in  std_logic;
        GEN_FRAME_SIZE_TYPE          : out std_logic;
        GEN_FRAME_SIZE_STATIC        : out std_logic_vector(15 downto 0);
        GEN_RATE_LIMITATION          : out std_logic_vector(7 downto 0);
        GEN_NB_BYTES_LSB             : out std_logic_vector(31 downto 0);
        GEN_NB_BYTES_MSB             : out std_logic_vector(31 downto 0);
        CHK_FRAME_SIZE_TYPE          : out std_logic;
        CHK_FRAME_SIZE_STATIC        : out std_logic_vector(15 downto 0);
        CHK_RATE_LIMITATION          : out std_logic_vector(7 downto 0);
        CHK_NB_BYTES_LSB             : out std_logic_vector(31 downto 0);
        CHK_NB_BYTES_MSB             : out std_logic_vector(31 downto 0);
        LB_GEN_DEST_PORT             : out std_logic_vector(15 downto 0);
        LB_GEN_SRC_PORT              : out std_logic_vector(15 downto 0);
        LB_GEN_DEST_IP_ADDR          : out std_logic_vector(31 downto 0);
        CHK_LISTENING_PORT           : out std_logic_vector(15 downto 0);
        TX_RM_BYTES_EXPT_LSB         : out std_logic_vector(31 downto 0);
        TX_RM_BYTES_EXPT_MSB         : out std_logic_vector(31 downto 0);
        RX_RM_BYTES_EXPT_LSB         : out std_logic_vector(31 downto 0);
        RX_RM_BYTES_EXPT_MSB         : out std_logic_vector(31 downto 0);
        LOOPBACK_MAC_EN_OUT          : out std_logic;
        LOOPBACK_UDP_EN_OUT          : out std_logic;
        GEN_START_OUT                : out std_logic;
        GEN_STOP_OUT                 : out std_logic;
        CHK_START_OUT                : out std_logic;
        CHK_STOP_OUT                 : out std_logic;
        TX_RM_INIT_COUNTER_OUT       : out std_logic;
        RX_RM_INIT_COUNTER_OUT       : out std_logic;
        REG_GEN_CHK_CONTROL_WRITE    : out std_logic;
        REG_TX_RATE_METER_CTRL_WRITE : out std_logic;
        REG_RX_RATE_METER_CTRL_WRITE : out std_logic;
        IRQ_GEN_DONE                 : in  std_logic;
        IRQ_GEN_ERR_TIMEOUT          : in  std_logic;
        IRQ_CHK_DONE                 : in  std_logic;
        IRQ_CHK_ERR_FRAME_SIZE       : in  std_logic;
        IRQ_CHK_ERR_DATA             : in  std_logic;
        IRQ_CHK_ERR_TIMEOUT          : in  std_logic;
        IRQ_RATE_METER_TX_DONE       : in  std_logic;
        IRQ_RATE_METER_TX_OVERFLOW   : in  std_logic;
        IRQ_RATE_METER_RX_DONE       : in  std_logic;
        IRQ_RATE_METER_RX_OVERFLOW   : in  std_logic;
        
        REG_INTERRUPT                : out std_logic
      );
    end component test_uoe_registers_itf;

    ----------------------------------
    -- Signals declaration
    ----------------------------------

    constant C_RM_CNT_WIDTH : integer := 64;

    ----------------------------------
    -- Signals declaration
    ----------------------------------

    -- Registers
    signal reg_loopback_mac_en : std_logic;
    signal reg_loopback_udp_en : std_logic;

    signal reg_gen_chk_control_p : std_logic;
    signal reg_gen_start         : std_logic;
    signal reg_gen_stop          : std_logic;
    signal reg_chk_start         : std_logic;
    signal reg_chk_stop          : std_logic;

    signal reg_gen_start_p : std_logic;
    signal reg_gen_stop_p  : std_logic;
    signal reg_chk_start_p : std_logic;
    signal reg_chk_stop_p  : std_logic;

    --signal reg_gen_enable             : std_logic;
    --signal reg_chk_enable             : std_logic;

    --signal reg_gen_nb_frame           : std_logic_vector(31 downto 0);  -- Number of frame to generate. 0 => Infinite mode
    signal reg_gen_frame_size_type   : std_logic; -- '0' => static size, '1' => dynamic size
    signal reg_gen_frame_size_static : std_logic_vector(15 downto 0); -- Frame size in static mode
    --signal reg_gen_timeout_value      : std_logic_vector(31 downto 0);    -- Timeout value
    signal reg_gen_rate_limitation   : std_logic_vector(7 downto 0); -- Rate limitation => 0 to 2^8-1 --> 50% = 2^7-1
    signal reg_gen_nb_bytes          : std_logic_vector(63 downto 0); -- Will be removed

    signal st_gen_test_duration : std_logic_vector(63 downto 0);
    --signal st_gen_test_nb_bytes       : std_logic_vector(63 downto 0);
    signal st_gen_done          : std_logic;
    signal st_gen_err_timeout   : std_logic;

    --signal reg_chk_nb_frame           : std_logic_vector(31 downto 0);  -- Number of frame to generate. 0 => Infinite mode
    signal reg_chk_frame_size_type   : std_logic; -- '0' => static size, '1' => dynamic size
    signal reg_chk_frame_size_static : std_logic_vector(15 downto 0); -- Frame size in static mode
    --signal reg_chk_timeout_value      : std_logic_vector(31 downto 0);    -- Timeout value
    signal reg_chk_rate_limitation   : std_logic_vector(7 downto 0); -- Rate limitation => 0 to 2^8-1 --> 50% = 2^7-1
    signal reg_chk_nb_bytes          : std_logic_vector(63 downto 0); -- Will be removed

    signal st_chk_test_duration : std_logic_vector(63 downto 0);
    --signal st_chk_test_nb_bytes       : std_logic_vector(63 downto 0);
    signal st_chk_done          : std_logic;
    --signal st_chk_err_frame_size      : std_logic;
    signal st_chk_err_data      : std_logic;
    signal st_chk_err_timeout   : std_logic;

    signal reg_lb_gen_dest_port    : std_logic_vector(15 downto 0);
    signal reg_lb_gen_src_port     : std_logic_vector(15 downto 0);
    signal reg_lb_gen_dest_ip_addr : std_logic_vector(31 downto 0);
    signal reg_chk_listening_port  : std_logic_vector(15 downto 0);

    -- Flow meter
    signal reg_tx_rate_meter_trigger_p      : std_logic;
    signal reg_tx_rate_meter_init_counter   : std_logic;
    signal reg_tx_rate_meter_bytes_expected : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal st_tx_rate_meter_cnt_cycles_i    : std_logic_vector((C_RM_CNT_WIDTH - integer(ceil(log2(real(C_UOE_TKEEP_WIDTH))))) -1 downto 0);
    signal st_tx_rate_meter_cnt_cycles      : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal st_tx_rate_meter_cnt_bytes       : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal irq_tx_rate_meter_overflow       : std_logic;
    signal irq_tx_rate_meter_done           : std_logic;

    signal reg_rx_rate_meter_trigger_p      : std_logic;
    signal reg_rx_rate_meter_init_counter   : std_logic;
    signal reg_rx_rate_meter_bytes_expected : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal st_rx_rate_meter_cnt_cycles_i      : std_logic_vector((C_RM_CNT_WIDTH - integer(ceil(log2(real(C_UOE_TKEEP_WIDTH))))) -1 downto 0);
    signal st_rx_rate_meter_cnt_cycles      : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal st_rx_rate_meter_cnt_bytes       : std_logic_vector(C_RM_CNT_WIDTH-1 downto 0);
    signal irq_rx_rate_meter_overflow       : std_logic;
    signal irq_rx_rate_meter_done           : std_logic;

  begin

    -- Integrated test on MAC interface
    inst_uoe_integrated_tests_mac : uoe_integrated_tests_mac
      generic map(
        G_ACTIVE_RST      => G_ACTIVE_RST,
        G_ASYNC_RST       => G_ASYNC_RST,
        G_TDATA_WIDTH     => G_MAC_TDATA_WIDTH,
        G_FIFO_ADDR_WIDTH => 4
      )
      port map(
        CLK_RX           => CLK_RX,
        RST_RX           => RST_RX,
        CLK_TX           => CLK_TX,
        RST_TX           => RST_TX,
        LOOPBACK_EN      => reg_loopback_mac_en,
        S_PHY_RX_TDATA   => S_MAC_RX_TDATA,
        S_PHY_RX_TVALID  => S_MAC_RX_TVALID,
        S_PHY_RX_TLAST   => S_MAC_RX_TLAST,
        S_PHY_RX_TKEEP   => S_MAC_RX_TKEEP,
        S_PHY_RX_TUSER   => S_MAC_RX_TUSER,
        M_CORE_RX_TDATA  => axis_mac_rx_tdata,
        M_CORE_RX_TVALID => axis_mac_rx_tvalid,
        M_CORE_RX_TLAST  => axis_mac_rx_tlast,
        M_CORE_RX_TKEEP  => axis_mac_rx_tkeep,
        M_CORE_RX_TUSER  => axis_mac_rx_tuser,
        S_CORE_TX_TDATA  => axis_mac_tx_tdata,
        S_CORE_TX_TVALID => axis_mac_tx_tvalid,
        S_CORE_TX_TLAST  => axis_mac_tx_tlast,
        S_CORE_TX_TKEEP  => axis_mac_tx_tkeep,
        S_CORE_TX_TUSER  => axis_mac_tx_tuser,
        S_CORE_TX_TREADY => axis_mac_tx_tready,
        M_PHY_TX_TDATA   => M_MAC_TX_TDATA,
        M_PHY_TX_TVALID  => M_MAC_TX_TVALID,
        M_PHY_TX_TLAST   => M_MAC_TX_TLAST,
        M_PHY_TX_TKEEP   => M_MAC_TX_TKEEP,
        M_PHY_TX_TUSER   => M_MAC_TX_TUSER,
        M_PHY_TX_TREADY  => M_MAC_TX_TREADY
      );

    -- TX Rate Meter
    inst_axis_rate_meter_tx : axis_rate_meter
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_TKEEP_WIDTH   => C_UOE_TKEEP_WIDTH,
        G_CNT_WIDTH     => C_RM_CNT_WIDTH - integer(ceil(log2(real(C_UOE_TKEEP_WIDTH))))
      )
      port map(
        CLK                => CLK_UOE,
        RST                => RST_UOE,
        AXIS_TKEEP         => axis_udp_tx_tkeep,
        AXIS_TVALID        => axis_udp_tx_tvalid,
        AXIS_TREADY        => axis_udp_tx_tready,
        TRIG_TVALID        => reg_tx_rate_meter_trigger_p,
        TRIG_TDATA_INIT    => reg_tx_rate_meter_init_counter,
        TRIG_TDATA_BYTES   => reg_tx_rate_meter_bytes_expected,
        CNT_TDATA_BYTES    => st_tx_rate_meter_cnt_bytes,
        CNT_TDATA_CYCLES   => st_tx_rate_meter_cnt_cycles_i,
        CNT_TUSER_OVERFLOW => irq_tx_rate_meter_overflow,
        CNT_TVALID         => irq_tx_rate_meter_done
      );

    st_tx_rate_meter_cnt_cycles <= std_logic_vector(resize(unsigned(st_tx_rate_meter_cnt_cycles_i),64));

    -- RX Rate Meter
    inst_axis_rate_meter_rx : axis_rate_meter
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_TKEEP_WIDTH   => C_UOE_TKEEP_WIDTH,
        G_CNT_WIDTH     => C_RM_CNT_WIDTH - integer(ceil(log2(real(C_UOE_TKEEP_WIDTH))))
      )
      port map(
        CLK                => CLK_UOE,
        RST                => RST_UOE,
        AXIS_TKEEP         => axis_udp_rx_tkeep,
        AXIS_TVALID        => axis_udp_rx_tvalid,
        AXIS_TREADY        => axis_udp_rx_tready,
        TRIG_TVALID        => reg_rx_rate_meter_trigger_p,
        TRIG_TDATA_INIT    => reg_rx_rate_meter_init_counter,
        TRIG_TDATA_BYTES   => reg_rx_rate_meter_bytes_expected,
        CNT_TDATA_BYTES    => st_rx_rate_meter_cnt_bytes,
        CNT_TDATA_CYCLES   => st_rx_rate_meter_cnt_cycles_i,
        CNT_TUSER_OVERFLOW => irq_rx_rate_meter_overflow,
        CNT_TVALID         => irq_rx_rate_meter_done
      );

    st_rx_rate_meter_cnt_cycles <= std_logic_vector(resize(unsigned(st_rx_rate_meter_cnt_cycles_i),64));

    -- Integrated test on UDP interface
    inst_uoe_integrated_tests_udp : uoe_integrated_tests_udp
      generic map(
        G_ACTIVE_RST      => G_ACTIVE_RST,
        G_ASYNC_RST       => G_ASYNC_RST,
        G_TDATA_WIDTH     => G_UOE_TDATA_WIDTH,
        G_FIFO_ADDR_WIDTH => 8
      )
      port map(
        CLK                   => CLK_UOE,
        RST                   => RST_UOE,
        S_CORE_RX_TDATA       => axis_udp_rx_tdata,
        S_CORE_RX_TVALID      => axis_udp_rx_tvalid,
        S_CORE_RX_TLAST       => axis_udp_rx_tlast,
        S_CORE_RX_TKEEP       => axis_udp_rx_tkeep,
        S_CORE_RX_TUSER       => axis_udp_rx_tuser,
        S_CORE_RX_TREADY      => axis_udp_rx_tready,
        M_EXT_RX_TDATA        => M_UDP_RX_TDATA,
        M_EXT_RX_TVALID       => M_UDP_RX_TVALID,
        M_EXT_RX_TLAST        => M_UDP_RX_TLAST,
        M_EXT_RX_TKEEP        => M_UDP_RX_TKEEP,
        M_EXT_RX_TUSER        => M_UDP_RX_TUSER,
        M_EXT_RX_TREADY       => M_UDP_RX_TREADY,
        S_EXT_TX_TDATA        => S_UDP_TX_TDATA,
        S_EXT_TX_TVALID       => S_UDP_TX_TVALID,
        S_EXT_TX_TLAST        => S_UDP_TX_TLAST,
        S_EXT_TX_TKEEP        => S_UDP_TX_TKEEP,
        S_EXT_TX_TUSER        => S_UDP_TX_TUSER,
        S_EXT_TX_TREADY       => S_UDP_TX_TREADY,
        M_CORE_TX_TDATA       => axis_udp_tx_tdata,
        M_CORE_TX_TVALID      => axis_udp_tx_tvalid,
        M_CORE_TX_TLAST       => axis_udp_tx_tlast,
        M_CORE_TX_TKEEP       => axis_udp_tx_tkeep,
        M_CORE_TX_TUSER       => axis_udp_tx_tuser,
        M_CORE_TX_TREADY      => axis_udp_tx_tready,
        LOOPBACK_EN           => reg_loopback_udp_en,
        GEN_START_P           => reg_gen_start_p,
        GEN_STOP_P            => reg_gen_stop_p,
        CHK_START_P           => reg_chk_start_p,
        CHK_STOP_P            => reg_chk_stop_p,
        GEN_FRAME_SIZE_TYPE   => reg_gen_frame_size_type,
        GEN_FRAME_SIZE_STATIC => reg_gen_frame_size_static,
        GEN_RATE_LIMITATION   => reg_gen_rate_limitation,
        GEN_NB_BYTES          => reg_gen_nb_bytes,
        CHK_FRAME_SIZE_TYPE   => reg_chk_frame_size_type,
        CHK_FRAME_SIZE_STATIC => reg_chk_frame_size_static,
        CHK_RATE_LIMITATION   => reg_chk_rate_limitation,
        CHK_NB_BYTES          => reg_chk_nb_bytes,
        LB_GEN_DEST_PORT      => reg_lb_gen_dest_port,
        LB_GEN_SRC_PORT       => reg_lb_gen_src_port,
        LB_GEN_DEST_IP_ADDR   => reg_lb_gen_dest_ip_addr,
        CHK_LISTENING_PORT    => reg_chk_listening_port,
        GEN_TEST_DURATION     => st_gen_test_duration,
        GEN_DONE              => st_gen_done,
        GEN_ERR_TIMEOUT       => st_gen_err_timeout,
        CHK_TEST_DURATION     => st_chk_test_duration,
        CHK_DONE              => st_chk_done,
        CHK_ERR_DATA          => st_chk_err_data,
        CHK_ERR_TIMEOUT       => st_chk_err_timeout
      );

    ------------------------------
    -- Test Registers
    ------------------------------
    inst_test_uoe_registers_itf : test_uoe_registers_itf
      port map(
        S_AXI_ACLK                   => CLK_UOE,
        S_AXI_ARESET                 => RST_UOE,
        S_AXI_AWADDR                 => axi_sw_awaddr((C_IDX_TEST_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_TEST_REGS * C_AXI_ADDR_WIDTH)),
        S_AXI_AWVALID(0)             => axi_sw_awvalid(C_IDX_TEST_REGS),
        S_AXI_AWREADY(0)             => axi_sw_awready(C_IDX_TEST_REGS),
        S_AXI_WDATA                  => axi_sw_wdata((C_IDX_TEST_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_TEST_REGS * C_AXI_DATA_WIDTH)),
        S_AXI_WVALID(0)              => axi_sw_wvalid(C_IDX_TEST_REGS),
        S_AXI_WSTRB                  => axi_sw_wstrb((C_IDX_TEST_REGS * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_TEST_REGS * C_AXI_STRB_WIDTH)),
        S_AXI_WREADY(0)              => axi_sw_wready(C_IDX_TEST_REGS),
        S_AXI_BRESP                  => axi_sw_bresp((C_IDX_TEST_REGS * 2) + 1 downto (C_IDX_TEST_REGS * 2)),
        S_AXI_BVALID(0)              => axi_sw_bvalid(C_IDX_TEST_REGS),
        S_AXI_BREADY(0)              => axi_sw_bready(C_IDX_TEST_REGS),
        S_AXI_ARADDR                 => axi_sw_araddr((C_IDX_TEST_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_TEST_REGS * C_AXI_ADDR_WIDTH)),
        S_AXI_ARVALID(0)             => axi_sw_arvalid(C_IDX_TEST_REGS),
        S_AXI_ARREADY(0)             => axi_sw_arready(C_IDX_TEST_REGS),
        S_AXI_RDATA                  => axi_sw_rdata((C_IDX_TEST_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_TEST_REGS * C_AXI_DATA_WIDTH)),
        S_AXI_RRESP                  => axi_sw_rresp((C_IDX_TEST_REGS * 2) + 1 downto (C_IDX_TEST_REGS * 2)),
        S_AXI_RVALID(0)              => axi_sw_rvalid(C_IDX_TEST_REGS),
        S_AXI_RREADY(0)              => axi_sw_rready(C_IDX_TEST_REGS),
        GEN_TEST_DURATION_LSB        => st_gen_test_duration(31 downto 0),
        GEN_TEST_DURATION_MSB        => st_gen_test_duration(63 downto 32),
        CHK_TEST_DURATION_LSB        => st_chk_test_duration(31 downto 0),
        CHK_TEST_DURATION_MSB        => st_chk_test_duration(63 downto 32),
        TX_RM_CNT_BYTES_LSB          => st_tx_rate_meter_cnt_bytes(31 downto 0),
        TX_RM_CNT_BYTES_MSB          => st_tx_rate_meter_cnt_bytes(63 downto 32),
        TX_RM_CNT_CYCLES_LSB         => st_tx_rate_meter_cnt_cycles(31 downto 0),
        TX_RM_CNT_CYCLES_MSB         => st_tx_rate_meter_cnt_cycles(63 downto 32),
        RX_RM_CNT_BYTES_LSB          => st_rx_rate_meter_cnt_bytes(31 downto 0),
        RX_RM_CNT_BYTES_MSB          => st_rx_rate_meter_cnt_bytes(63 downto 32),
        RX_RM_CNT_CYCLES_LSB         => st_rx_rate_meter_cnt_cycles(31 downto 0),
        RX_RM_CNT_CYCLES_MSB         => st_rx_rate_meter_cnt_cycles(63 downto 32),
        LOOPBACK_MAC_EN_IN           => reg_loopback_mac_en,
        LOOPBACK_UDP_EN_IN           => reg_loopback_udp_en,
        GEN_START_IN                 => '0',
        GEN_STOP_IN                  => '0',
        CHK_START_IN                 => '0',
        CHK_STOP_IN                  => '0',
        TX_RM_INIT_COUNTER_IN        => reg_tx_rate_meter_init_counter,
        RX_RM_INIT_COUNTER_IN        => reg_rx_rate_meter_init_counter,
        GEN_FRAME_SIZE_TYPE          => reg_gen_frame_size_type,
        GEN_FRAME_SIZE_STATIC        => reg_gen_frame_size_static,
        GEN_RATE_LIMITATION          => reg_gen_rate_limitation,
        GEN_NB_BYTES_LSB             => reg_gen_nb_bytes(31 downto 0),
        GEN_NB_BYTES_MSB             => reg_gen_nb_bytes(63 downto 32),
        CHK_FRAME_SIZE_TYPE          => reg_chk_frame_size_type,
        CHK_FRAME_SIZE_STATIC        => reg_chk_frame_size_static,
        CHK_RATE_LIMITATION          => reg_chk_rate_limitation,
        CHK_NB_BYTES_LSB             => reg_chk_nb_bytes(31 downto 0),
        CHK_NB_BYTES_MSB             => reg_chk_nb_bytes(63 downto 32),
        LB_GEN_DEST_PORT             => reg_lb_gen_dest_port,
        LB_GEN_SRC_PORT              => reg_lb_gen_src_port,
        LB_GEN_DEST_IP_ADDR          => reg_lb_gen_dest_ip_addr,
        CHK_LISTENING_PORT           => reg_chk_listening_port,
        TX_RM_BYTES_EXPT_LSB         => reg_tx_rate_meter_bytes_expected(31 downto 0),
        TX_RM_BYTES_EXPT_MSB         => reg_tx_rate_meter_bytes_expected(63 downto 32),
        RX_RM_BYTES_EXPT_LSB         => reg_rx_rate_meter_bytes_expected(31 downto 0),
        RX_RM_BYTES_EXPT_MSB         => reg_rx_rate_meter_bytes_expected(63 downto 32),
        LOOPBACK_MAC_EN_OUT          => reg_loopback_mac_en,
        LOOPBACK_UDP_EN_OUT          => reg_loopback_udp_en,
        GEN_START_OUT                => reg_gen_start,
        GEN_STOP_OUT                 => reg_gen_stop,
        CHK_START_OUT                => reg_chk_start,
        CHK_STOP_OUT                 => reg_chk_stop,
        TX_RM_INIT_COUNTER_OUT       => reg_tx_rate_meter_init_counter,
        RX_RM_INIT_COUNTER_OUT       => reg_rx_rate_meter_init_counter,
        REG_GEN_CHK_CONTROL_WRITE    => reg_gen_chk_control_p,
        REG_TX_RATE_METER_CTRL_WRITE => reg_tx_rate_meter_trigger_p,
        REG_RX_RATE_METER_CTRL_WRITE => reg_rx_rate_meter_trigger_p,
        IRQ_GEN_DONE                 => st_gen_done,
        IRQ_GEN_ERR_TIMEOUT          => st_gen_err_timeout,
        IRQ_CHK_DONE                 => st_chk_done,
        IRQ_CHK_ERR_FRAME_SIZE       => '0',
        IRQ_CHK_ERR_DATA             => st_chk_err_data,
        IRQ_CHK_ERR_TIMEOUT          => st_chk_err_timeout,
        IRQ_RATE_METER_TX_DONE       => irq_tx_rate_meter_overflow,
        IRQ_RATE_METER_TX_OVERFLOW   => irq_tx_rate_meter_done,
        IRQ_RATE_METER_RX_DONE       => irq_rx_rate_meter_overflow,
        IRQ_RATE_METER_RX_OVERFLOW   => irq_rx_rate_meter_done,
        REG_INTERRUPT                => INTERRUPT(1)
      );

    -- Generate pulse
    reg_gen_start_p <= reg_gen_chk_control_p and reg_gen_start;
    reg_gen_stop_p  <= reg_gen_chk_control_p and reg_gen_stop;
    reg_chk_start_p <= reg_gen_chk_control_p and reg_chk_start;
    reg_chk_stop_p  <= reg_gen_chk_control_p and reg_chk_stop;

  end generate GEN_TEST_ENV;

  GEN_NO_TEST_ENV : if not G_ENABLE_TESTENV generate

    ------------------------------
    -- MAC interface
    ------------------------------

    axis_mac_rx_tdata  <= S_MAC_RX_TDATA;
    axis_mac_rx_tvalid <= S_MAC_RX_TVALID;
    axis_mac_rx_tlast  <= S_MAC_RX_TLAST;
    axis_mac_rx_tkeep  <= S_MAC_RX_TKEEP;
    axis_mac_rx_tuser  <= S_MAC_RX_TUSER;

    M_MAC_TX_TDATA     <= axis_mac_tx_tdata;
    M_MAC_TX_TVALID    <= axis_mac_tx_tvalid;
    M_MAC_TX_TLAST     <= axis_mac_tx_tlast;
    M_MAC_TX_TKEEP     <= axis_mac_tx_tkeep;
    M_MAC_TX_TUSER     <= axis_mac_tx_tuser;
    axis_mac_tx_tready <= M_MAC_TX_TREADY;

    ------------------------------
    -- UDP interface
    ------------------------------
    axis_udp_tx_tdata  <= S_UDP_TX_TDATA;
    axis_udp_tx_tvalid <= S_UDP_TX_TVALID;
    axis_udp_tx_tlast  <= S_UDP_TX_TLAST;
    axis_udp_tx_tkeep  <= S_UDP_TX_TKEEP;
    axis_udp_tx_tuser  <= S_UDP_TX_TUSER;
    S_UDP_TX_TREADY    <= axis_udp_tx_tready;

    M_UDP_RX_TDATA     <= axis_udp_rx_tdata;
    M_UDP_RX_TVALID    <= axis_udp_rx_tvalid;
    M_UDP_RX_TLAST     <= axis_udp_rx_tlast;
    M_UDP_RX_TKEEP     <= axis_udp_rx_tkeep;
    M_UDP_RX_TUSER     <= axis_udp_rx_tuser;
    axis_udp_rx_tready <= M_UDP_RX_TREADY;

  end generate GEN_NO_TEST_ENV;

end rtl;

