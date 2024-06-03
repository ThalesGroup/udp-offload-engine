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

--------------------------------------
-- UOE CORE
--------------------------------------
--
-- This module instanciate the functionnal part of the IP
--
--------------------------------------

library common;
use common.cdc_utils_pkg.cdc_bit_sync;

use common.axis_utils_pkg.axis_pkt_drop;

use work.uoe_module_pkg.all;

entity uoe_core is
  generic(
    G_ACTIVE_RST          : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST           : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_MAC_TDATA_WIDTH     : integer   := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_UOE_TDATA_WIDTH     : integer   := 64; -- Number of bits used along AXI datapath of UOE
    G_ROUTER_FIFO_DEPTH   : integer   := 1536; -- Depth of router Fifos (in bytes)
    G_ENABLE_ARP_MODULE   : boolean   := true; -- Enable or disable ARP Module
    G_ENABLE_ARP_TABLE    : boolean   := true; -- Disable ARP Table IP/MAC Addr.
    G_ENABLE_PKT_DROP_EXT : boolean   := true; -- Enable Packet DROP on EXT RX interface
    G_ENABLE_PKT_DROP_RAW : boolean   := true; -- Enable Packet DROP on RAW RX interface
    G_ENABLE_PKT_DROP_UDP : boolean   := true; -- Enable Packet DROP on UDP RX interface
    G_UOE_FREQ_KHZ        : integer   := 156250 -- System Frequency use to reference timeout
  );
  port(
    -- Clock domain of MAC in rx
    CLK_RX                  : in  std_logic;
    RST_RX                  : in  std_logic;
    -- Clock domain of MAC in tx
    CLK_TX                  : in  std_logic;
    RST_TX                  : in  std_logic;
    -- Internal clock domain
    CLK_UOE                 : in  std_logic;
    RST_UOE                 : in  std_logic;
    -- Status Physical Layer
    PHY_LAYER_RDY           : in  std_logic;
    -- UOE Interrupt Output
    INTERRUPT               : out std_logic;
    -- Interface MAC with Physical interface
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
    -- Interface EXT
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
    -- Interface RAW
    S_RAW_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_RAW_TX_TVALID         : in  std_logic;
    S_RAW_TX_TLAST          : in  std_logic;
    S_RAW_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_RAW_TX_TUSER          : in  std_logic_vector(15 downto 0); -- Frame Size
    S_RAW_TX_TREADY         : out std_logic;
    M_RAW_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_RAW_RX_TVALID         : out std_logic;
    M_RAW_RX_TLAST          : out std_logic;
    M_RAW_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_RAW_RX_TUSER          : out std_logic_vector(15 downto 0); -- Frame Size
    M_RAW_RX_TREADY         : in  std_logic;
    -- Interface UDP
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
    -- AXI4-Lite interface to registers
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
    -- AXI4-Lite interface to ARP Table (used for debug)
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
end uoe_core;

architecture rtl of uoe_core is

  --------------------------------------------------
  -- Component declaration
  --------------------------------------------------

  -- Link layer
  component uoe_link_layer is
    generic(
      G_ACTIVE_RST        : std_logic := '0';
      G_ASYNC_RST         : boolean   := false;
      G_MAC_TDATA_WIDTH   : positive  := 64;
      G_UOE_TDATA_WIDTH   : positive  := 64;
      G_ROUTER_FIFO_DEPTH : positive  := 1536;
      G_ENABLE_ARP_MODULE : boolean   := true;
      G_ENABLE_ARP_TABLE  : boolean   := false;
      G_FREQ_KHZ          : integer   := 156250
    );
    port(
      CLK_RX                        : in  std_logic;
      RST_RX                        : in  std_logic;
      CLK_TX                        : in  std_logic;
      RST_TX                        : in  std_logic;
      CLK_UOE                       : in  std_logic;
      RST_UOE                       : in  std_logic;
      S_MAC_RX_TDATA                : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      S_MAC_RX_TVALID               : in  std_logic;
      S_MAC_RX_TLAST                : in  std_logic;
      S_MAC_RX_TKEEP                : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      S_MAC_RX_TUSER                : in  std_logic;
      M_MAC_TX_TDATA                : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      M_MAC_TX_TVALID               : out std_logic;
      M_MAC_TX_TLAST                : out std_logic;
      M_MAC_TX_TKEEP                : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      M_MAC_TX_TUSER                : out std_logic;
      M_MAC_TX_TREADY               : in  std_logic;
      S_EXT_TX_TDATA                : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_TVALID               : in  std_logic;
      S_EXT_TX_TLAST                : in  std_logic;
      S_EXT_TX_TKEEP                : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_TREADY               : out std_logic;
      M_EXT_RX_TDATA                : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_TVALID               : out std_logic;
      M_EXT_RX_TLAST                : out std_logic;
      M_EXT_RX_TKEEP                : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_TREADY               : in  std_logic;
      S_RAW_TX_TDATA                : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_RAW_TX_TVALID               : in  std_logic;
      S_RAW_TX_TLAST                : in  std_logic;
      S_RAW_TX_TKEEP                : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_RAW_TX_TUSER                : in  std_logic_vector(15 downto 0);
      S_RAW_TX_TREADY               : out std_logic;
      M_RAW_RX_TDATA                : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_RAW_RX_TVALID               : out std_logic;
      M_RAW_RX_TLAST                : out std_logic;
      M_RAW_RX_TKEEP                : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_RAW_RX_TUSER                : out std_logic_vector(15 downto 0);
      M_RAW_RX_TREADY               : in  std_logic;
      S_INTERNET_TX_TDATA           : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_INTERNET_TX_TVALID          : in  std_logic;
      S_INTERNET_TX_TLAST           : in  std_logic;
      S_INTERNET_TX_TKEEP           : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_INTERNET_TX_TID             : in  std_logic_vector(15 downto 0);
      S_INTERNET_TX_TUSER           : in  std_logic_vector(31 downto 0);
      S_INTERNET_TX_TREADY          : out std_logic;
      M_INTERNET_RX_TDATA           : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_INTERNET_RX_TVALID          : out std_logic;
      M_INTERNET_RX_TLAST           : out std_logic;
      M_INTERNET_RX_TKEEP           : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_INTERNET_RX_TID             : out std_logic_vector(15 downto 0);
      M_INTERNET_RX_TREADY          : in  std_logic;
      INIT_DONE                     : in  std_logic;
      BROADCAST_FILTER_ENABLE       : in  std_logic;
      IPV4_MULTICAST_FILTER_ENABLE  : in  std_logic;
      IPV4_MULTICAST_MAC_ADDR_LSB_1 : in  std_logic_vector(23 downto 0);
      IPV4_MULTICAST_MAC_ADDR_LSB_2 : in  std_logic_vector(23 downto 0);
      IPV4_MULTICAST_MAC_ADDR_LSB_3 : in  std_logic_vector(23 downto 0);
      IPV4_MULTICAST_MAC_ADDR_LSB_4 : in  std_logic_vector(23 downto 0);
      IPV4_MULTICAST_ADDR_1_ENABLE  : in  std_logic;
      IPV4_MULTICAST_ADDR_2_ENABLE  : in  std_logic;
      IPV4_MULTICAST_ADDR_3_ENABLE  : in  std_logic;
      IPV4_MULTICAST_ADDR_4_ENABLE  : in  std_logic;
      UNICAST_FILTER_ENABLE         : in  std_logic;
      LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
      LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0);
      RAW_DEST_MAC_ADDR             : in  std_logic_vector(47 downto 0);
      FORCE_IP_ADDR_DEST            : in  std_logic_vector(31 downto 0);
      FORCE_ARP_REQUEST             : in  std_logic;
      CLEAR_ARP_TABLE               : in  std_logic;
      CLEAR_ARP_TABLE_DONE          : out std_logic;
      ARP_TIMEOUT_MS                : in  std_logic_vector(11 downto 0);
      ARP_TRYINGS                   : in  std_logic_vector(3 downto 0);
      ARP_GRATUITOUS_REQ            : in  std_logic;
      ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0);
      ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
      FLAG_CRC_FILTER               : out std_logic;
      FLAG_MAC_FILTER               : out std_logic;
      LINK_LAYER_RDY                : out std_logic;
      ROUTER_DATA_RX_FIFO_OVERFLOW  : out std_logic;
      ROUTER_CRC_RX_FIFO_OVERFLOW   : out std_logic;
      ARP_RX_FIFO_OVERFLOW          : out std_logic;
      ARP_IP_CONFLICT               : out std_logic;
      ARP_MAC_CONFLICT              : out std_logic;
      ARP_ERROR                     : out std_logic;
      ARP_INIT_DONE                 : out std_logic;
      S_AXI_ARP_TABLE_AWADDR        : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_AWVALID       : in  std_logic;
      S_AXI_ARP_TABLE_AWREADY       : out std_logic;
      S_AXI_ARP_TABLE_WDATA         : in  std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_WVALID        : in  std_logic;
      S_AXI_ARP_TABLE_WREADY        : out std_logic;
      S_AXI_ARP_TABLE_BRESP         : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_BVALID        : out std_logic;
      S_AXI_ARP_TABLE_BREADY        : in  std_logic;
      S_AXI_ARP_TABLE_ARADDR        : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_ARVALID       : in  std_logic;
      S_AXI_ARP_TABLE_ARREADY       : out std_logic;
      S_AXI_ARP_TABLE_RDATA         : out std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_RRESP         : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_RVALID        : out std_logic;
      S_AXI_ARP_TABLE_RREADY        : in  std_logic
    );
  end component uoe_link_layer;

  -- Internet layer
  component uoe_internet_layer is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := false;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK                       : in  std_logic;
      RST                       : in  std_logic;
      S_LINK_RX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_LINK_RX_TVALID          : in  std_logic;
      S_LINK_RX_TLAST           : in  std_logic;
      S_LINK_RX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_LINK_RX_TID             : in  std_logic_vector(15 downto 0);
      S_LINK_RX_TREADY          : out std_logic;
      M_LINK_TX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_LINK_TX_TVALID          : out std_logic;
      M_LINK_TX_TLAST           : out std_logic;
      M_LINK_TX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_LINK_TX_TID             : out std_logic_vector(15 downto 0);
      M_LINK_TX_TUSER           : out std_logic_vector(31 downto 0);
      M_LINK_TX_TREADY          : in  std_logic;
      S_TRANSPORT_TX_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TRANSPORT_TX_TVALID     : in  std_logic;
      S_TRANSPORT_TX_TLAST      : in  std_logic;
      S_TRANSPORT_TX_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TRANSPORT_TX_TID        : in  std_logic_vector(7 downto 0);
      S_TRANSPORT_TX_TUSER      : in  std_logic_vector(47 downto 0);
      S_TRANSPORT_TX_TREADY     : out std_logic;
      M_TRANSPORT_RX_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TRANSPORT_RX_TVALID     : out std_logic;
      M_TRANSPORT_RX_TLAST      : out std_logic;
      M_TRANSPORT_RX_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TRANSPORT_RX_TID        : out std_logic_vector(7 downto 0);
      M_TRANSPORT_RX_TUSER      : out std_logic_vector(31 downto 0);
      M_TRANSPORT_RX_TREADY     : in  std_logic;
      INIT_DONE                 : in  std_logic;
      TTL                       : in  std_logic_vector(7 downto 0);
      LOCAL_IP_ADDR             : in  std_logic_vector(31 downto 0);
      IPV4_RX_FRAG_OFFSET_ERROR : out std_logic
    );
  end component uoe_internet_layer;

  -- Transport layer
  component uoe_transport_layer is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := false;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK                  : in  std_logic;
      RST                  : in  std_logic;
      S_INTERNET_RX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_INTERNET_RX_TVALID : in  std_logic;
      S_INTERNET_RX_TLAST  : in  std_logic;
      S_INTERNET_RX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_INTERNET_RX_TID    : in  std_logic_vector(7 downto 0);
      S_INTERNET_RX_TUSER  : in  std_logic_vector(31 downto 0);
      S_INTERNET_RX_TREADY : out std_logic;
      M_INTERNET_TX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_INTERNET_TX_TVALID : out std_logic;
      M_INTERNET_TX_TLAST  : out std_logic;
      M_INTERNET_TX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_INTERNET_TX_TID    : out std_logic_vector(7 downto 0);
      M_INTERNET_TX_TUSER  : out std_logic_vector(47 downto 0);
      M_INTERNET_TX_TREADY : in  std_logic;
      S_UDP_TX_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_UDP_TX_TVALID      : in  std_logic;
      S_UDP_TX_TLAST       : in  std_logic;
      S_UDP_TX_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_UDP_TX_TUSER       : in  std_logic_vector(79 downto 0);
      S_UDP_TX_TREADY      : out std_logic;
      M_UDP_RX_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_UDP_RX_TVALID      : out std_logic;
      M_UDP_RX_TLAST       : out std_logic;
      M_UDP_RX_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_UDP_RX_TUSER       : out std_logic_vector(79 downto 0);
      M_UDP_RX_TREADY      : in  std_logic;
      INIT_DONE            : in  std_logic
    );
  end component uoe_transport_layer;

  component main_uoe_registers_itf
    port(
      S_AXI_ACLK                       : in  std_logic;
      S_AXI_ARESET                     : in  std_logic;
      S_AXI_AWADDR                     : in  std_logic_vector(7 downto 0);
      S_AXI_AWVALID                    : in  std_logic_vector(0 downto 0);
      S_AXI_AWREADY                    : out std_logic_vector(0 downto 0);
      S_AXI_WDATA                      : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID                     : in  std_logic_vector(0 downto 0);
      S_AXI_WSTRB                      : in  std_logic_vector(3 downto 0);
      S_AXI_WREADY                     : out std_logic_vector(0 downto 0);
      S_AXI_BRESP                      : out std_logic_vector(1 downto 0);
      S_AXI_BVALID                     : out std_logic_vector(0 downto 0);
      S_AXI_BREADY                     : in  std_logic_vector(0 downto 0);
      S_AXI_ARADDR                     : in  std_logic_vector(7 downto 0);
      S_AXI_ARVALID                    : in  std_logic_vector(0 downto 0);
      S_AXI_ARREADY                    : out std_logic_vector(0 downto 0);
      S_AXI_RDATA                      : out std_logic_vector(31 downto 0);
      S_AXI_RRESP                      : out std_logic_vector(1 downto 0);
      S_AXI_RVALID                     : out std_logic_vector(0 downto 0);
      S_AXI_RREADY                     : in  std_logic_vector(0 downto 0);
      VERSION                          : in  std_logic_vector(7 downto 0);
      REVISION                         : in  std_logic_vector(7 downto 0);
      DEBUG                            : in  std_logic_vector(15 downto 0);
      CRC_FILTER_COUNTER               : in  std_logic_vector(31 downto 0);
      MAC_FILTER_COUNTER               : in  std_logic_vector(31 downto 0);
      EXT_DROP_COUNTER                 : in  std_logic_vector(31 downto 0);
      RAW_DROP_COUNTER                 : in  std_logic_vector(31 downto 0);
      UDP_DROP_COUNTER                 : in  std_logic_vector(31 downto 0);
      ARP_SW_REQ_DEST_IP_ADDR_IN       : in  std_logic_vector(31 downto 0);
      LOCAL_MAC_ADDR_LSB               : out std_logic_vector(31 downto 0);
      LOCAL_MAC_ADDR_MSB               : out std_logic_vector(15 downto 0);
      LOCAL_IP_ADDR                    : out std_logic_vector(31 downto 0);
      RAW_DEST_MAC_ADDR_LSB            : out std_logic_vector(31 downto 0);
      RAW_DEST_MAC_ADDR_MSB            : out std_logic_vector(15 downto 0);
      TTL                              : out std_logic_vector(7 downto 0);
      BROADCAST_FILTER_ENABLE          : out std_logic;
      IPV4_MULTICAST_FILTER_ENABLE     : out std_logic;
      UNICAST_FILTER_ENABLE            : out std_logic;
      MULTICAST_IP_ADDR_1              : out std_logic_vector(27 downto 0);
      MULTICAST_IP_ADDR_1_ENABLE       : out std_logic;
      MULTICAST_IP_ADDR_2              : out std_logic_vector(27 downto 0);
      MULTICAST_IP_ADDR_2_ENABLE       : out std_logic;
      MULTICAST_IP_ADDR_3              : out std_logic_vector(27 downto 0);
      MULTICAST_IP_ADDR_3_ENABLE       : out std_logic;
      MULTICAST_IP_ADDR_4              : out std_logic_vector(27 downto 0);
      MULTICAST_IP_ADDR_4_ENABLE       : out std_logic;
      ARP_TIMEOUT_MS                   : out std_logic_vector(11 downto 0);
      ARP_TRYINGS                      : out std_logic_vector(3 downto 0);
      ARP_GRATUITOUS_REQ               : out std_logic;
      ARP_RX_TARGET_IP_FILTER          : out std_logic_vector(1 downto 0);
      ARP_RX_TEST_LOCAL_IP_CONFLICT    : out std_logic;
      ARP_TABLE_CLEAR                  : out std_logic;
      CONFIG_DONE                      : out std_logic;
      ARP_SW_REQ_DEST_IP_ADDR_OUT      : out std_logic_vector(31 downto 0);
      REG_ARP_SW_REQ_WRITE             : out std_logic;
      REG_MONITORING_CRC_FILTER_READ   : out std_logic;
      REG_MONITORING_MAC_FILTER_READ   : out std_logic;
      REG_MONITORING_EXT_DROP_READ     : out std_logic;
      REG_MONITORING_RAW_DROP_READ     : out std_logic;
      REG_MONITORING_UDP_DROP_READ     : out std_logic;
      IRQ_INIT_DONE                    : in  std_logic;
      IRQ_ARP_TABLE_CLEAR_DONE         : in  std_logic;
      IRQ_ARP_IP_CONFLICT              : in  std_logic;
      IRQ_ARP_MAC_CONFLICT             : in  std_logic;
      IRQ_ARP_ERROR                    : in  std_logic;
      IRQ_ARP_RX_FIFO_OVERFLOW         : in  std_logic;
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW : in  std_logic;
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW  : in  std_logic;
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR    : in  std_logic;
      REG_INTERRUPT                    : out std_logic
    );
  end component main_uoe_registers_itf;

  --------------------------------------------------
  -- Component declaration
  --------------------------------------------------

  -- From Internet layer to Link layer
  signal axis_tx_int_to_link_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_tx_int_to_link_tvalid : std_logic;
  signal axis_tx_int_to_link_tlast  : std_logic;
  signal axis_tx_int_to_link_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_tx_int_to_link_tid    : std_logic_vector(15 downto 0); -- Ethertype value
  signal axis_tx_int_to_link_tuser  : std_logic_vector(31 downto 0); -- DEST IP Address
  signal axis_tx_int_to_link_tready : std_logic;
  -- From Link layer to Internet layer
  signal axis_rx_link_to_int_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_link_to_int_tvalid : std_logic;
  signal axis_rx_link_to_int_tlast  : std_logic;
  signal axis_rx_link_to_int_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_link_to_int_tid    : std_logic_vector(15 downto 0); -- Protocol
  signal axis_rx_link_to_int_tready : std_logic;

  -- From Transport layer to Internet layer
  signal axis_tx_trans_to_int_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_tx_trans_to_int_tvalid : std_logic;
  signal axis_tx_trans_to_int_tlast  : std_logic;
  signal axis_tx_trans_to_int_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_tx_trans_to_int_tid    : std_logic_vector(7 downto 0);
  signal axis_tx_trans_to_int_tuser  : std_logic_vector(47 downto 0);
  signal axis_tx_trans_to_int_tready : std_logic;
  -- From Internet layer to Transport layer
  signal axis_rx_int_to_trans_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_int_to_trans_tvalid : std_logic;
  signal axis_rx_int_to_trans_tlast  : std_logic;
  signal axis_rx_int_to_trans_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_int_to_trans_tid    : std_logic_vector(7 downto 0);
  signal axis_rx_int_to_trans_tuser  : std_logic_vector(31 downto 0);
  signal axis_rx_int_to_trans_tready : std_logic;

  -- EXT RX to pkt drop module
  signal axis_ext_rx_to_drop_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_ext_rx_to_drop_tvalid : std_logic;
  signal axis_ext_rx_to_drop_tlast  : std_logic;
  signal axis_ext_rx_to_drop_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_ext_rx_to_drop_tready : std_logic;

  -- RAW RX to pkt drop module
  signal axis_raw_rx_to_drop_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_raw_rx_to_drop_tvalid : std_logic;
  signal axis_raw_rx_to_drop_tlast  : std_logic;
  signal axis_raw_rx_to_drop_tuser  : std_logic_vector(15 downto 0);
  signal axis_raw_rx_to_drop_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_raw_rx_to_drop_tready : std_logic;

  -- RAW RX to pkt drop module
  signal axis_udp_rx_to_drop_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_udp_rx_to_drop_tvalid : std_logic;
  signal axis_udp_rx_to_drop_tlast  : std_logic;
  signal axis_udp_rx_to_drop_tuser  : std_logic_vector(79 downto 0);
  signal axis_udp_rx_to_drop_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_udp_rx_to_drop_tready : std_logic;

  -- Global Registers
  signal reg_local_mac_addr    : std_logic_vector(47 downto 0);
  signal reg_local_ip_addr     : std_logic_vector(31 downto 0);
  signal reg_raw_dest_mac_addr : std_logic_vector(47 downto 0);
  signal reg_ttl               : std_logic_vector(7 downto 0);

  signal reg_broadcast_filter_enable      : std_logic;
  signal reg_ipv4_multicast_filter_enable : std_logic;
  signal reg_unicast_filter_enable        : std_logic;

  signal reg_multicast_ip_addr_1      : std_logic_vector(27 downto 0);
  signal reg_multicast_ip_addr_2      : std_logic_vector(27 downto 0);
  signal reg_multicast_ip_addr_3      : std_logic_vector(27 downto 0);
  signal reg_multicast_ip_addr_4      : std_logic_vector(27 downto 0);
  signal reg_multicast_mac_addr_lsb_1 : std_logic_vector(23 downto 0);
  signal reg_multicast_mac_addr_lsb_2 : std_logic_vector(23 downto 0);
  signal reg_multicast_mac_addr_lsb_3 : std_logic_vector(23 downto 0);
  signal reg_multicast_mac_addr_lsb_4 : std_logic_vector(23 downto 0);
  signal reg_multicast_addr_1_enable  : std_logic;
  signal reg_multicast_addr_2_enable  : std_logic;
  signal reg_multicast_addr_3_enable  : std_logic;
  signal reg_multicast_addr_4_enable  : std_logic;

  -- ARP Register
  signal reg_arp_timeout_ms                : std_logic_vector(11 downto 0);
  signal reg_arp_tryings                   : std_logic_vector(3 downto 0);
  signal reg_arp_gratuitous_req            : std_logic;
  signal reg_arp_rx_target_ip_filter       : std_logic_vector(1 downto 0);
  signal reg_arp_rx_test_local_ip_conflict : std_logic;
  signal reg_arp_sw_req_dest_ip_addr       : std_logic_vector(31 downto 0);
  signal reg_arp_sw_req                    : std_logic;
  signal reg_arp_table_clear               : std_logic;
  signal reg_config_done                   : std_logic;

  -- Status
  signal st_phy_layer_rdy      : std_logic;
  signal st_link_layer_rdy     : std_logic;
  signal st_crc_filter_counter : std_logic_vector(31 downto 0);
  signal st_mac_filter_counter : std_logic_vector(31 downto 0);
  signal st_ext_drop_counter   : std_logic_vector(31 downto 0);
  signal st_raw_drop_counter   : std_logic_vector(31 downto 0);
  signal st_udp_drop_counter   : std_logic_vector(31 downto 0);
  signal st_arp_init_done      : std_logic;
  signal st_arp_init_done_z    : std_logic;

  -- Interrupt request
  signal irq_init_done                    : std_logic;
  signal irq_arp_table_clear_done         : std_logic;
  signal irq_arp_ip_conflict              : std_logic;
  signal irq_arp_mac_conflict             : std_logic;
  signal irq_arp_error                    : std_logic;
  signal irq_arp_rx_fifo_overflow         : std_logic;
  signal irq_router_data_rx_fifo_overflow : std_logic;
  signal irq_router_crc_rx_fifo_overflow  : std_logic;
  signal irq_ipv4_rx_frag_offset_error    : std_logic;

  -- others
  signal uoe_init_done            : std_logic;
  signal clear_crc_filter_counter : std_logic;
  signal clear_mac_filter_counter : std_logic;
  signal clear_ext_drop_counter   : std_logic;
  signal clear_raw_drop_counter   : std_logic;
  signal clear_udp_drop_counter   : std_logic;
  signal flag_crc_filter          : std_logic;
  signal flag_mac_filter          : std_logic;
  signal flag_ext_drop            : std_logic;
  signal flag_raw_drop            : std_logic;
  signal flag_udp_drop            : std_logic;

begin

  -------------------------------------------
  -- link layer
  -------------------------------------------
  inst_uoe_link_layer : uoe_link_layer
    generic map(
      G_ACTIVE_RST        => G_ACTIVE_RST,
      G_ASYNC_RST         => G_ASYNC_RST,
      G_MAC_TDATA_WIDTH   => G_MAC_TDATA_WIDTH,
      G_UOE_TDATA_WIDTH   => G_UOE_TDATA_WIDTH,
      G_ROUTER_FIFO_DEPTH => G_ROUTER_FIFO_DEPTH,
      G_ENABLE_ARP_MODULE => G_ENABLE_ARP_MODULE,
      G_ENABLE_ARP_TABLE  => G_ENABLE_ARP_TABLE,
      G_FREQ_KHZ          => G_UOE_FREQ_KHZ
    )
    port map(
      CLK_RX                        => CLK_RX,
      RST_RX                        => RST_RX,
      CLK_TX                        => CLK_TX,
      RST_TX                        => RST_TX,
      CLK_UOE                       => CLK_UOE,
      RST_UOE                       => RST_UOE,
      S_MAC_RX_TDATA                => S_MAC_RX_TDATA,
      S_MAC_RX_TVALID               => S_MAC_RX_TVALID,
      S_MAC_RX_TLAST                => S_MAC_RX_TLAST,
      S_MAC_RX_TKEEP                => S_MAC_RX_TKEEP,
      S_MAC_RX_TUSER                => S_MAC_RX_TUSER,
      M_MAC_TX_TDATA                => M_MAC_TX_TDATA,
      M_MAC_TX_TVALID               => M_MAC_TX_TVALID,
      M_MAC_TX_TLAST                => M_MAC_TX_TLAST,
      M_MAC_TX_TKEEP                => M_MAC_TX_TKEEP,
      M_MAC_TX_TUSER                => M_MAC_TX_TUSER,
      M_MAC_TX_TREADY               => M_MAC_TX_TREADY,
      S_EXT_TX_TDATA                => S_EXT_TX_TDATA,
      S_EXT_TX_TVALID               => S_EXT_TX_TVALID,
      S_EXT_TX_TLAST                => S_EXT_TX_TLAST,
      S_EXT_TX_TKEEP                => S_EXT_TX_TKEEP,
      S_EXT_TX_TREADY               => S_EXT_TX_TREADY,
      M_EXT_RX_TDATA                => axis_ext_rx_to_drop_tdata,
      M_EXT_RX_TVALID               => axis_ext_rx_to_drop_tvalid,
      M_EXT_RX_TLAST                => axis_ext_rx_to_drop_tlast,
      M_EXT_RX_TKEEP                => axis_ext_rx_to_drop_tkeep,
      M_EXT_RX_TREADY               => axis_ext_rx_to_drop_tready,
      S_RAW_TX_TDATA                => S_RAW_TX_TDATA,
      S_RAW_TX_TVALID               => S_RAW_TX_TVALID,
      S_RAW_TX_TLAST                => S_RAW_TX_TLAST,
      S_RAW_TX_TKEEP                => S_RAW_TX_TKEEP,
      S_RAW_TX_TUSER                => S_RAW_TX_TUSER,
      S_RAW_TX_TREADY               => S_RAW_TX_TREADY,
      M_RAW_RX_TDATA                => axis_raw_rx_to_drop_tdata,
      M_RAW_RX_TVALID               => axis_raw_rx_to_drop_tvalid,
      M_RAW_RX_TLAST                => axis_raw_rx_to_drop_tlast,
      M_RAW_RX_TKEEP                => axis_raw_rx_to_drop_tkeep,
      M_RAW_RX_TUSER                => axis_raw_rx_to_drop_tuser,
      M_RAW_RX_TREADY               => axis_raw_rx_to_drop_tready,
      S_INTERNET_TX_TDATA           => axis_tx_int_to_link_tdata,
      S_INTERNET_TX_TVALID          => axis_tx_int_to_link_tvalid,
      S_INTERNET_TX_TLAST           => axis_tx_int_to_link_tlast,
      S_INTERNET_TX_TKEEP           => axis_tx_int_to_link_tkeep,
      S_INTERNET_TX_TID             => axis_tx_int_to_link_tid,
      S_INTERNET_TX_TUSER           => axis_tx_int_to_link_tuser,
      S_INTERNET_TX_TREADY          => axis_tx_int_to_link_tready,
      M_INTERNET_RX_TDATA           => axis_rx_link_to_int_tdata,
      M_INTERNET_RX_TVALID          => axis_rx_link_to_int_tvalid,
      M_INTERNET_RX_TLAST           => axis_rx_link_to_int_tlast,
      M_INTERNET_RX_TKEEP           => axis_rx_link_to_int_tkeep,
      M_INTERNET_RX_TID             => axis_rx_link_to_int_tid,
      M_INTERNET_RX_TREADY          => axis_rx_link_to_int_tready,
      INIT_DONE                     => uoe_init_done,
      BROADCAST_FILTER_ENABLE       => reg_broadcast_filter_enable,
      IPV4_MULTICAST_FILTER_ENABLE  => reg_ipv4_multicast_filter_enable,
      IPV4_MULTICAST_MAC_ADDR_LSB_1 => reg_multicast_mac_addr_lsb_1,
      IPV4_MULTICAST_MAC_ADDR_LSB_2 => reg_multicast_mac_addr_lsb_2,
      IPV4_MULTICAST_MAC_ADDR_LSB_3 => reg_multicast_mac_addr_lsb_3,
      IPV4_MULTICAST_MAC_ADDR_LSB_4 => reg_multicast_mac_addr_lsb_4,
      IPV4_MULTICAST_ADDR_1_ENABLE  => reg_multicast_addr_1_enable,
      IPV4_MULTICAST_ADDR_2_ENABLE  => reg_multicast_addr_2_enable,
      IPV4_MULTICAST_ADDR_3_ENABLE  => reg_multicast_addr_3_enable,
      IPV4_MULTICAST_ADDR_4_ENABLE  => reg_multicast_addr_4_enable,
      UNICAST_FILTER_ENABLE         => reg_unicast_filter_enable,
      LOCAL_MAC_ADDR                => reg_local_mac_addr,
      LOCAL_IP_ADDR                 => reg_local_ip_addr,
      RAW_DEST_MAC_ADDR             => reg_raw_dest_mac_addr,
      FORCE_IP_ADDR_DEST            => reg_arp_sw_req_dest_ip_addr,
      FORCE_ARP_REQUEST             => reg_arp_sw_req,
      CLEAR_ARP_TABLE               => reg_arp_table_clear,
      CLEAR_ARP_TABLE_DONE          => irq_arp_table_clear_done,
      ARP_TIMEOUT_MS                => reg_arp_timeout_ms,
      ARP_TRYINGS                   => reg_arp_tryings,
      ARP_GRATUITOUS_REQ            => reg_arp_gratuitous_req,
      ARP_RX_TARGET_IP_FILTER       => reg_arp_rx_target_ip_filter,
      ARP_RX_TEST_LOCAL_IP_CONFLICT => reg_arp_rx_test_local_ip_conflict,
      FLAG_CRC_FILTER               => flag_crc_filter,
      FLAG_MAC_FILTER               => flag_mac_filter,
      LINK_LAYER_RDY                => st_link_layer_rdy,
      ROUTER_DATA_RX_FIFO_OVERFLOW  => irq_router_data_rx_fifo_overflow,
      ROUTER_CRC_RX_FIFO_OVERFLOW   => irq_router_crc_rx_fifo_overflow,
      ARP_RX_FIFO_OVERFLOW          => irq_arp_rx_fifo_overflow,
      ARP_IP_CONFLICT               => irq_arp_ip_conflict,
      ARP_MAC_CONFLICT              => irq_arp_mac_conflict,
      ARP_ERROR                     => irq_arp_error,
      ARP_INIT_DONE                 => st_arp_init_done,
      S_AXI_ARP_TABLE_AWADDR        => S_AXI_ARP_TABLE_AWADDR,
      S_AXI_ARP_TABLE_AWVALID       => S_AXI_ARP_TABLE_AWVALID,
      S_AXI_ARP_TABLE_AWREADY       => S_AXI_ARP_TABLE_AWREADY,
      S_AXI_ARP_TABLE_WDATA         => S_AXI_ARP_TABLE_WDATA,
      S_AXI_ARP_TABLE_WVALID        => S_AXI_ARP_TABLE_WVALID,
      S_AXI_ARP_TABLE_WREADY        => S_AXI_ARP_TABLE_WREADY,
      S_AXI_ARP_TABLE_BRESP         => S_AXI_ARP_TABLE_BRESP,
      S_AXI_ARP_TABLE_BVALID        => S_AXI_ARP_TABLE_BVALID,
      S_AXI_ARP_TABLE_BREADY        => S_AXI_ARP_TABLE_BREADY,
      S_AXI_ARP_TABLE_ARADDR        => S_AXI_ARP_TABLE_ARADDR,
      S_AXI_ARP_TABLE_ARVALID       => S_AXI_ARP_TABLE_ARVALID,
      S_AXI_ARP_TABLE_ARREADY       => S_AXI_ARP_TABLE_ARREADY,
      S_AXI_ARP_TABLE_RDATA         => S_AXI_ARP_TABLE_RDATA,
      S_AXI_ARP_TABLE_RRESP         => S_AXI_ARP_TABLE_RRESP,
      S_AXI_ARP_TABLE_RVALID        => S_AXI_ARP_TABLE_RVALID,
      S_AXI_ARP_TABLE_RREADY        => S_AXI_ARP_TABLE_RREADY
    );

  -------------------------------------------
  -- Internet Layer
  -------------------------------------------
  inst_uoe_internet_layer : uoe_internet_layer
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK                       => CLK_UOE,
      RST                       => RST_UOE,
      S_LINK_RX_TDATA           => axis_rx_link_to_int_tdata,
      S_LINK_RX_TVALID          => axis_rx_link_to_int_tvalid,
      S_LINK_RX_TLAST           => axis_rx_link_to_int_tlast,
      S_LINK_RX_TKEEP           => axis_rx_link_to_int_tkeep,
      S_LINK_RX_TID             => axis_rx_link_to_int_tid,
      S_LINK_RX_TREADY          => axis_rx_link_to_int_tready,
      M_LINK_TX_TDATA           => axis_tx_int_to_link_tdata,
      M_LINK_TX_TVALID          => axis_tx_int_to_link_tvalid,
      M_LINK_TX_TLAST           => axis_tx_int_to_link_tlast,
      M_LINK_TX_TKEEP           => axis_tx_int_to_link_tkeep,
      M_LINK_TX_TID             => axis_tx_int_to_link_tid,
      M_LINK_TX_TUSER           => axis_tx_int_to_link_tuser,
      M_LINK_TX_TREADY          => axis_tx_int_to_link_tready,
      S_TRANSPORT_TX_TDATA      => axis_tx_trans_to_int_tdata,
      S_TRANSPORT_TX_TVALID     => axis_tx_trans_to_int_tvalid,
      S_TRANSPORT_TX_TLAST      => axis_tx_trans_to_int_tlast,
      S_TRANSPORT_TX_TKEEP      => axis_tx_trans_to_int_tkeep,
      S_TRANSPORT_TX_TID        => axis_tx_trans_to_int_tid,
      S_TRANSPORT_TX_TUSER      => axis_tx_trans_to_int_tuser,
      S_TRANSPORT_TX_TREADY     => axis_tx_trans_to_int_tready,
      M_TRANSPORT_RX_TDATA      => axis_rx_int_to_trans_tdata,
      M_TRANSPORT_RX_TVALID     => axis_rx_int_to_trans_tvalid,
      M_TRANSPORT_RX_TLAST      => axis_rx_int_to_trans_tlast,
      M_TRANSPORT_RX_TKEEP      => axis_rx_int_to_trans_tkeep,
      M_TRANSPORT_RX_TID        => axis_rx_int_to_trans_tid,
      M_TRANSPORT_RX_TUSER      => axis_rx_int_to_trans_tuser,
      M_TRANSPORT_RX_TREADY     => axis_rx_int_to_trans_tready,
      INIT_DONE                 => st_arp_init_done,
      TTL                       => reg_ttl,
      LOCAL_IP_ADDR             => reg_local_ip_addr,
      IPV4_RX_FRAG_OFFSET_ERROR => irq_ipv4_rx_frag_offset_error
    );

  -------------------------------------------
  -- Transport layer
  -------------------------------------------
  inst_uoe_transport_layer : uoe_transport_layer
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK                  => CLK_UOE,
      RST                  => RST_UOE,
      S_INTERNET_RX_TDATA  => axis_rx_int_to_trans_tdata,
      S_INTERNET_RX_TVALID => axis_rx_int_to_trans_tvalid,
      S_INTERNET_RX_TLAST  => axis_rx_int_to_trans_tlast,
      S_INTERNET_RX_TKEEP  => axis_rx_int_to_trans_tkeep,
      S_INTERNET_RX_TID    => axis_rx_int_to_trans_tid,
      S_INTERNET_RX_TUSER  => axis_rx_int_to_trans_tuser,
      S_INTERNET_RX_TREADY => axis_rx_int_to_trans_tready,
      M_INTERNET_TX_TDATA  => axis_tx_trans_to_int_tdata,
      M_INTERNET_TX_TVALID => axis_tx_trans_to_int_tvalid,
      M_INTERNET_TX_TLAST  => axis_tx_trans_to_int_tlast,
      M_INTERNET_TX_TKEEP  => axis_tx_trans_to_int_tkeep,
      M_INTERNET_TX_TID    => axis_tx_trans_to_int_tid,
      M_INTERNET_TX_TUSER  => axis_tx_trans_to_int_tuser,
      M_INTERNET_TX_TREADY => axis_tx_trans_to_int_tready,
      S_UDP_TX_TDATA       => S_UDP_TX_TDATA,
      S_UDP_TX_TVALID      => S_UDP_TX_TVALID,
      S_UDP_TX_TLAST       => S_UDP_TX_TLAST,
      S_UDP_TX_TKEEP       => S_UDP_TX_TKEEP,
      S_UDP_TX_TUSER       => S_UDP_TX_TUSER,
      S_UDP_TX_TREADY      => S_UDP_TX_TREADY,
      M_UDP_RX_TDATA       => axis_udp_rx_to_drop_tdata,
      M_UDP_RX_TVALID      => axis_udp_rx_to_drop_tvalid,
      M_UDP_RX_TLAST       => axis_udp_rx_to_drop_tlast,
      M_UDP_RX_TKEEP       => axis_udp_rx_to_drop_tkeep,
      M_UDP_RX_TUSER       => axis_udp_rx_to_drop_tuser,
      M_UDP_RX_TREADY      => axis_udp_rx_to_drop_tready,
      INIT_DONE            => st_arp_init_done
    );

  -------------------------------------------
  -- PACKET DROP EXT
  -------------------------------------------

  GEN_PKT_DROP_EXT : if G_ENABLE_PKT_DROP_EXT generate

    -- Packet Drop to avoid saturation of the link
    inst_axis_pkt_drop_ext : axis_pkt_drop
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_TDATA_WIDTH   => G_UOE_TDATA_WIDTH,
        G_ADDR_WIDTH    => 10,
        G_PKT_THRESHOLD => 2
      )
      port map(
        S_CLK    => CLK_UOE,
        S_RST    => RST_UOE,
        S_TDATA  => axis_ext_rx_to_drop_tdata,
        S_TVALID => axis_ext_rx_to_drop_tvalid,
        S_TLAST  => axis_ext_rx_to_drop_tlast,
        S_TKEEP  => axis_ext_rx_to_drop_tkeep,
        S_TREADY => axis_ext_rx_to_drop_tready,
        DROP     => flag_ext_drop,
        M_CLK    => CLK_UOE,
        M_TDATA  => M_EXT_RX_TDATA,
        M_TVALID => M_EXT_RX_TVALID,
        M_TLAST  => M_EXT_RX_TLAST,
        M_TKEEP  => M_EXT_RX_TKEEP,
        M_TREADY => M_EXT_RX_TREADY
      );

  end generate GEN_PKT_DROP_EXT;

  GEN_NO_PKT_DROP_EXT : if not G_ENABLE_PKT_DROP_EXT generate

    M_EXT_RX_TDATA             <= axis_ext_rx_to_drop_tdata;
    M_EXT_RX_TVALID            <= axis_ext_rx_to_drop_tvalid;
    M_EXT_RX_TLAST             <= axis_ext_rx_to_drop_tlast;
    M_EXT_RX_TKEEP             <= axis_ext_rx_to_drop_tkeep;
    axis_ext_rx_to_drop_tready <= M_EXT_RX_TREADY;

    flag_ext_drop <= '0';

  end generate GEN_NO_PKT_DROP_EXT;

  -------------------------------------------
  -- PACKET DROP RAW
  -------------------------------------------

  GEN_PKT_DROP_RAW : if G_ENABLE_PKT_DROP_RAW generate

    -- Packet Drop to avoid saturation of the link
    inst_axis_pkt_drop_raw : axis_pkt_drop
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH   => G_UOE_TDATA_WIDTH,
        G_TUSER_WIDTH   => 16,
        G_ADDR_WIDTH    => 10,
        G_PKT_THRESHOLD => 2
      )
      port map(
        S_CLK    => CLK_UOE,
        S_RST    => RST_UOE,
        S_TDATA  => axis_raw_rx_to_drop_tdata,
        S_TVALID => axis_raw_rx_to_drop_tvalid,
        S_TLAST  => axis_raw_rx_to_drop_tlast,
        S_TUSER  => axis_raw_rx_to_drop_tuser,
        S_TKEEP  => axis_raw_rx_to_drop_tkeep,
        S_TREADY => axis_raw_rx_to_drop_tready,
        DROP     => flag_raw_drop,
        M_CLK    => CLK_UOE,
        M_TDATA  => M_RAW_RX_TDATA,
        M_TVALID => M_RAW_RX_TVALID,
        M_TLAST  => M_RAW_RX_TLAST,
        M_TUSER  => M_RAW_RX_TUSER,
        M_TKEEP  => M_RAW_RX_TKEEP,
        M_TREADY => M_RAW_RX_TREADY
      );

  end generate GEN_PKT_DROP_RAW;

  GEN_NO_PKT_DROP_RAW : if not G_ENABLE_PKT_DROP_RAW generate

    M_RAW_RX_TDATA             <= axis_raw_rx_to_drop_tdata;
    M_RAW_RX_TVALID            <= axis_raw_rx_to_drop_tvalid;
    M_RAW_RX_TLAST             <= axis_raw_rx_to_drop_tlast;
    M_RAW_RX_TUSER             <= axis_raw_rx_to_drop_tuser;
    M_RAW_RX_TKEEP             <= axis_raw_rx_to_drop_tkeep;
    axis_raw_rx_to_drop_tready <= M_RAW_RX_TREADY;

    flag_raw_drop <= '0';

  end generate GEN_NO_PKT_DROP_RAW;

  -------------------------------------------
  -- PACKET DROP UDP
  -------------------------------------------

  GEN_PKT_DROP_UDP : if G_ENABLE_PKT_DROP_UDP generate

    -- Packet Drop to avoid saturation of the link
    --TODO: Size of memory by generic
    --TODO: Drop following the remaining place in the fifo.
    inst_axis_pkt_drop_udp : axis_pkt_drop
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_TDATA_WIDTH   => G_UOE_TDATA_WIDTH,
        G_TUSER_WIDTH   => 80,
        G_ADDR_WIDTH    => 10,
        G_PKT_THRESHOLD => 2
      )
      port map(
        S_CLK    => CLK_UOE,
        S_RST    => RST_UOE,
        S_TDATA  => axis_udp_rx_to_drop_tdata,
        S_TVALID => axis_udp_rx_to_drop_tvalid,
        S_TLAST  => axis_udp_rx_to_drop_tlast,
        S_TUSER  => axis_udp_rx_to_drop_tuser,
        S_TKEEP  => axis_udp_rx_to_drop_tkeep,
        S_TREADY => axis_udp_rx_to_drop_tready,
        DROP     => flag_udp_drop,
        M_CLK    => CLK_UOE,
        M_TDATA  => M_UDP_RX_TDATA,
        M_TVALID => M_UDP_RX_TVALID,
        M_TLAST  => M_UDP_RX_TLAST,
        M_TUSER  => M_UDP_RX_TUSER,
        M_TKEEP  => M_UDP_RX_TKEEP,
        M_TREADY => M_UDP_RX_TREADY
      );

  end generate GEN_PKT_DROP_UDP;

  GEN_NO_PKT_DROP_UDP : if not G_ENABLE_PKT_DROP_UDP generate

    M_UDP_RX_TDATA             <= axis_udp_rx_to_drop_tdata;
    M_UDP_RX_TVALID            <= axis_udp_rx_to_drop_tvalid;
    M_UDP_RX_TLAST             <= axis_udp_rx_to_drop_tlast;
    M_UDP_RX_TUSER             <= axis_udp_rx_to_drop_tuser;
    M_UDP_RX_TKEEP             <= axis_udp_rx_to_drop_tkeep;
    axis_udp_rx_to_drop_tready <= M_UDP_RX_TREADY;

    flag_udp_drop <= '0';

  end generate GEN_NO_PKT_DROP_UDP;

  -------------------------------------------
  -- Interface Registers
  -------------------------------------------
  inst_main_uoe_registers_itf : main_uoe_registers_itf
    port map(
      S_AXI_ACLK                       => CLK_UOE,
      S_AXI_ARESET                     => RST_UOE,
      S_AXI_AWADDR                     => S_AXI_AWADDR,
      S_AXI_AWVALID(0)                 => S_AXI_AWVALID,
      S_AXI_AWREADY(0)                 => S_AXI_AWREADY,
      S_AXI_WDATA                      => S_AXI_WDATA,
      S_AXI_WVALID(0)                  => S_AXI_WVALID,
      S_AXI_WSTRB                      => S_AXI_WSTRB,
      S_AXI_WREADY(0)                  => S_AXI_WREADY,
      S_AXI_BRESP                      => S_AXI_BRESP,
      S_AXI_BVALID(0)                  => S_AXI_BVALID,
      S_AXI_BREADY(0)                  => S_AXI_BREADY,
      S_AXI_ARADDR                     => S_AXI_ARADDR,
      S_AXI_ARVALID(0)                 => S_AXI_ARVALID,
      S_AXI_ARREADY(0)                 => S_AXI_ARREADY,
      S_AXI_RDATA                      => S_AXI_RDATA,
      S_AXI_RRESP                      => S_AXI_RRESP,
      S_AXI_RVALID(0)                  => S_AXI_RVALID,
      S_AXI_RREADY(0)                  => S_AXI_RREADY,
      -- RO Registers 
      VERSION                          => C_VERSION,
      REVISION                         => C_REVISION,
      DEBUG                            => C_DEBUG,
      -- RZ Registers 
      CRC_FILTER_COUNTER               => st_crc_filter_counter,
      MAC_FILTER_COUNTER               => st_mac_filter_counter,
      EXT_DROP_COUNTER                 => st_ext_drop_counter,
      RAW_DROP_COUNTER                 => st_raw_drop_counter,
      UDP_DROP_COUNTER                 => st_udp_drop_counter,
      -- WO Registers Input
      ARP_SW_REQ_DEST_IP_ADDR_IN       => reg_arp_sw_req_dest_ip_addr,
      -- RW Registers 
      LOCAL_MAC_ADDR_LSB               => reg_local_mac_addr(31 downto 0),
      LOCAL_MAC_ADDR_MSB               => reg_local_mac_addr(47 downto 32),
      LOCAL_IP_ADDR                    => reg_local_ip_addr,
      RAW_DEST_MAC_ADDR_LSB            => reg_raw_dest_mac_addr(31 downto 0),
      RAW_DEST_MAC_ADDR_MSB            => reg_raw_dest_mac_addr(47 downto 32),
      TTL                              => reg_ttl,
      BROADCAST_FILTER_ENABLE          => reg_broadcast_filter_enable,
      IPV4_MULTICAST_FILTER_ENABLE     => reg_ipv4_multicast_filter_enable,
      UNICAST_FILTER_ENABLE            => reg_unicast_filter_enable,
      MULTICAST_IP_ADDR_1              => reg_multicast_ip_addr_1,
      MULTICAST_IP_ADDR_1_ENABLE       => reg_multicast_addr_1_enable,
      MULTICAST_IP_ADDR_2              => reg_multicast_ip_addr_2,
      MULTICAST_IP_ADDR_2_ENABLE       => reg_multicast_addr_2_enable,
      MULTICAST_IP_ADDR_3              => reg_multicast_ip_addr_3,
      MULTICAST_IP_ADDR_3_ENABLE       => reg_multicast_addr_3_enable,
      MULTICAST_IP_ADDR_4              => reg_multicast_ip_addr_4,
      MULTICAST_IP_ADDR_4_ENABLE       => reg_multicast_addr_4_enable,
      ARP_TIMEOUT_MS                   => reg_arp_timeout_ms,
      ARP_TRYINGS                      => reg_arp_tryings,
      ARP_GRATUITOUS_REQ               => reg_arp_gratuitous_req,
      ARP_RX_TARGET_IP_FILTER          => reg_arp_rx_target_ip_filter,
      ARP_RX_TEST_LOCAL_IP_CONFLICT    => reg_arp_rx_test_local_ip_conflict,
      ARP_TABLE_CLEAR                  => reg_arp_table_clear,
      CONFIG_DONE                      => reg_config_done,
      -- WO Registers 
      ARP_SW_REQ_DEST_IP_ADDR_OUT      => reg_arp_sw_req_dest_ip_addr,
      -- WO Pulses Registers 
      REG_ARP_SW_REQ_WRITE             => reg_arp_sw_req,
      -- RZ Pulses Registers 
      REG_MONITORING_CRC_FILTER_READ   => clear_crc_filter_counter,
      REG_MONITORING_MAC_FILTER_READ   => clear_mac_filter_counter,
      REG_MONITORING_EXT_DROP_READ     => clear_ext_drop_counter,
      REG_MONITORING_RAW_DROP_READ     => clear_raw_drop_counter,
      REG_MONITORING_UDP_DROP_READ     => clear_udp_drop_counter,
      -- IRQ sources
      IRQ_INIT_DONE                    => irq_init_done,
      IRQ_ARP_TABLE_CLEAR_DONE         => irq_arp_table_clear_done,
      IRQ_ARP_IP_CONFLICT              => irq_arp_ip_conflict,
      IRQ_ARP_MAC_CONFLICT             => irq_arp_mac_conflict,
      IRQ_ARP_ERROR                    => irq_arp_error,
      IRQ_ARP_RX_FIFO_OVERFLOW         => irq_arp_rx_fifo_overflow,
      IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW => irq_router_data_rx_fifo_overflow,
      IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW  => irq_router_crc_rx_fifo_overflow,
      IRQ_IPV4_RX_FRAG_OFFSET_ERROR    => irq_ipv4_rx_frag_offset_error,
      -- IRQ output
      REG_INTERRUPT                    => INTERRUPT
    );

  -- Internal Init Done : Wait Readyness of Physical layer and link layer and user configuration
  uoe_init_done <= st_phy_layer_rdy and st_link_layer_rdy and reg_config_done;

  -- Get LSB of Multicast MAC Address from Multicast IP Address
  reg_multicast_mac_addr_lsb_1 <= '0' & reg_multicast_ip_addr_1(22 downto 0);
  reg_multicast_mac_addr_lsb_2 <= '0' & reg_multicast_ip_addr_2(22 downto 0);
  reg_multicast_mac_addr_lsb_3 <= '0' & reg_multicast_ip_addr_3(22 downto 0);
  reg_multicast_mac_addr_lsb_4 <= '0' & reg_multicast_ip_addr_4(22 downto 0);

  -------------------------------------------
  -- Resync Physical Layer Ready
  -------------------------------------------
  inst_cdc_bit_sync : cdc_bit_sync
    generic map(
      G_NB_STAGE   => 2,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_RST_VALUE  => '0'
    )
    port map(
      DATA_ASYNC => PHY_LAYER_RDY,
      CLK        => CLK_UOE,
      RST        => RST_UOE,
      DATA_SYNC  => st_phy_layer_rdy
    );

  -------------------------------------------
  -- Generate INIT_DONE Interrupt request when assertion of ARP_INIT_DONE
  -------------------------------------------
  P_IRQ_INIT_DONE : process(CLK_UOE, RST_UOE)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST_UOE = G_ACTIVE_RST) then
      st_arp_init_done_z <= '0';
      irq_init_done      <= '0';

    elsif (rising_edge(CLK_UOE)) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST_UOE = G_ACTIVE_RST) then
        st_arp_init_done_z <= '0';
        irq_init_done      <= '0';

      else
        st_arp_init_done_z <= st_arp_init_done;
        -- Rising edge detection
        if (st_arp_init_done_z /= '1') and (st_arp_init_done = '1') then
          irq_init_done <= '1';
        else
          irq_init_done <= '0';
        end if;

      end if;
    end if;
  end process P_IRQ_INIT_DONE;

  -------------------------------------------
  -- CRC Error counter
  -------------------------------------------
  P_FLAG_COUNTER : process(CLK_UOE, RST_UOE)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST_UOE = G_ACTIVE_RST) then
      st_crc_filter_counter <= (others => '0');
      st_mac_filter_counter <= (others => '0');
      st_ext_drop_counter   <= (others => '0');
      st_raw_drop_counter   <= (others => '0');
      st_udp_drop_counter   <= (others => '0');

    elsif rising_edge(CLK_UOE) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST_UOE = G_ACTIVE_RST) then
        st_crc_filter_counter <= (others => '0');
        st_mac_filter_counter <= (others => '0');
        st_ext_drop_counter   <= (others => '0');
        st_raw_drop_counter   <= (others => '0');
        st_udp_drop_counter   <= (others => '0');

      else
        -- Count the number of frame removed because of CRC error 
        if (clear_crc_filter_counter = '1') then
          st_crc_filter_counter <= (others => '0');
        elsif (flag_crc_filter = '1') then
          st_crc_filter_counter <= std_logic_vector(unsigned(st_crc_filter_counter) + 1);
        end if;

        -- Count the number of frame filtered by the MAC configuration
        if (clear_mac_filter_counter = '1') then
          st_mac_filter_counter <= (others => '0');
        elsif (flag_mac_filter = '1') then
          st_mac_filter_counter <= std_logic_vector(unsigned(st_mac_filter_counter) + 1);
        end if;

        -- Count the number of dropped frame on EXT Interface
        if (clear_ext_drop_counter = '1') then
          st_ext_drop_counter <= (others => '0');
        elsif (flag_ext_drop = '1') then
          st_ext_drop_counter <= std_logic_vector(unsigned(st_ext_drop_counter) + 1);
        end if;

        -- Count the number of dropped frame on RAW Interface
        if (clear_raw_drop_counter = '1') then
          st_raw_drop_counter <= (others => '0');
        elsif (flag_raw_drop = '1') then
          st_raw_drop_counter <= std_logic_vector(unsigned(st_raw_drop_counter) + 1);
        end if;

        -- Count the number of dropped frame on UDP Interface
        if (clear_udp_drop_counter = '1') then
          st_udp_drop_counter <= (others => '0');
        elsif (flag_udp_drop = '1') then
          st_udp_drop_counter <= std_logic_vector(unsigned(st_udp_drop_counter) + 1);
        end if;
      end if;
    end if;
  end process P_FLAG_COUNTER;

end rtl;

