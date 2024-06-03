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

----------------------------------------------------
-- LINK LAYER
----------------------------------------------------
-- This module composed the link layer of the stack
--
-- It is composed of :
-- * FRAME ROUTER
-- * RAW ETHERNET
-- * MAC SHAPING
-- * ARP MODULE
--
----------------------------------------------------

entity uoe_link_layer is
  generic(
    G_ACTIVE_RST        : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST         : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_MAC_TDATA_WIDTH   : positive  := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_UOE_TDATA_WIDTH   : positive  := 64; -- Number of bits used along AXI datapath of UOE
    G_ROUTER_FIFO_DEPTH : positive  := 1536; -- Depth of router Fifos (in bytes)
    G_ENABLE_ARP_MODULE : boolean   := true; -- Enable or disable ARP Module
    G_ENABLE_ARP_TABLE  : boolean   := false; -- Disable ARP Table IP/MAC Addr.
    G_FREQ_KHZ          : integer   := 156250 -- System Frequency use to reference timeout
  );
  port(
    -- Clock domain of MAC in rx
    CLK_RX                        : in  std_logic;
    RST_RX                        : in  std_logic;
    -- Clock domain of MAC in tx
    CLK_TX                        : in  std_logic;
    RST_TX                        : in  std_logic;
    -- Internal clock domain
    CLK_UOE                       : in  std_logic;
    RST_UOE                       : in  std_logic;
    -- Interface MAC with Physical interface
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
    -- Interface EXT
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
    -- Interface RAW
    S_RAW_TX_TDATA                : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_RAW_TX_TVALID               : in  std_logic;
    S_RAW_TX_TLAST                : in  std_logic;
    S_RAW_TX_TKEEP                : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_RAW_TX_TUSER                : in  std_logic_vector(15 downto 0); -- Frame Size
    S_RAW_TX_TREADY               : out std_logic;
    M_RAW_RX_TDATA                : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_RAW_RX_TVALID               : out std_logic;
    M_RAW_RX_TLAST                : out std_logic;
    M_RAW_RX_TKEEP                : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_RAW_RX_TUSER                : out std_logic_vector(15 downto 0); -- Frame Size
    M_RAW_RX_TREADY               : in  std_logic;
    -- From Internet layer
    S_INTERNET_TX_TDATA           : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    S_INTERNET_TX_TVALID          : in  std_logic;
    S_INTERNET_TX_TLAST           : in  std_logic;
    S_INTERNET_TX_TKEEP           : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_INTERNET_TX_TID             : in  std_logic_vector(15 downto 0); -- Ethertype value
    S_INTERNET_TX_TUSER           : in  std_logic_vector(31 downto 0); -- DEST IP Address
    S_INTERNET_TX_TREADY          : out std_logic;
    -- To Internet Layer
    M_INTERNET_RX_TDATA           : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    M_INTERNET_RX_TVALID          : out std_logic;
    M_INTERNET_RX_TLAST           : out std_logic;
    M_INTERNET_RX_TKEEP           : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_INTERNET_RX_TID             : out std_logic_vector(15 downto 0); -- Protocol
    M_INTERNET_RX_TREADY          : in  std_logic;
    -- Registers
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
    LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0); -- Local MAC
    LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0); -- Local IP
    RAW_DEST_MAC_ADDR             : in  std_logic_vector(47 downto 0); -- Destination MAC
    FORCE_IP_ADDR_DEST            : in  std_logic_vector(31 downto 0);
    FORCE_ARP_REQUEST             : in  std_logic;
    CLEAR_ARP_TABLE               : in  std_logic;
    CLEAR_ARP_TABLE_DONE          : out std_logic;
    ARP_TIMEOUT_MS                : in  std_logic_vector(11 downto 0);
    ARP_TRYINGS                   : in  std_logic_vector(3 downto 0);
    ARP_GRATUITOUS_REQ            : in  std_logic;
    ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0);
    ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
    -- Status
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
    -- AXI4-Lite interface to ARP Table (used for debug)
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
end uoe_link_layer;

architecture rtl of uoe_link_layer is

  -- Eth frame router
  component uoe_frame_router
    generic(
      G_ACTIVE_RST        : std_logic := '0';
      G_ASYNC_RST         : boolean   := false;
      G_MAC_TDATA_WIDTH   : positive  := 64;
      G_UOE_TDATA_WIDTH   : positive  := 64;
      G_ROUTER_FIFO_DEPTH : positive  := 1536
    );
    port(
      CLK_RX                        : in  std_logic;
      RST_RX                        : in  std_logic;
      CLK_TX                        : in  std_logic;
      RST_TX                        : in  std_logic;
      CLK_UOE                       : in  std_logic;
      RST_UOE                       : in  std_logic;
      INIT_DONE                     : in  std_logic;
      MAC_RX_AXIS_TDATA             : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      MAC_RX_AXIS_TVALID            : in  std_logic;
      MAC_RX_AXIS_TLAST             : in  std_logic;
      MAC_RX_AXIS_TKEEP             : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      MAC_RX_AXIS_TUSER             : in  std_logic;
      MAC_TX_AXIS_TDATA             : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      MAC_TX_AXIS_TVALID            : out std_logic;
      MAC_TX_AXIS_TLAST             : out std_logic;
      MAC_TX_AXIS_TKEEP             : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      MAC_TX_AXIS_TUSER             : out std_logic;
      MAC_TX_AXIS_TREADY            : in  std_logic;
      S_RAW_TX_AXIS_TDATA           : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_RAW_TX_AXIS_TVALID          : in  std_logic;
      S_RAW_TX_AXIS_TLAST           : in  std_logic;
      S_RAW_TX_AXIS_TKEEP           : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_RAW_TX_AXIS_TREADY          : out std_logic;
      M_RAW_RX_AXIS_TDATA           : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_RAW_RX_AXIS_TVALID          : out std_logic;
      M_RAW_RX_AXIS_TLAST           : out std_logic;
      M_RAW_RX_AXIS_TKEEP           : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RAW_RX_AXIS_TREADY          : in  std_logic;
      S_SHAPING_TX_AXIS_TDATA       : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_SHAPING_TX_AXIS_TVALID      : in  std_logic;
      S_SHAPING_TX_AXIS_TLAST       : in  std_logic;
      S_SHAPING_TX_AXIS_TKEEP       : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_SHAPING_TX_AXIS_TREADY      : out std_logic;
      M_SHAPING_RX_AXIS_TDATA       : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_SHAPING_RX_AXIS_TVALID      : out std_logic;
      M_SHAPING_RX_AXIS_TLAST       : out std_logic;
      M_SHAPING_RX_AXIS_TKEEP       : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_SHAPING_RX_AXIS_TREADY      : in  std_logic;
      S_ARP_TX_AXIS_TDATA           : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_ARP_TX_AXIS_TVALID          : in  std_logic;
      S_ARP_TX_AXIS_TLAST           : in  std_logic;
      S_ARP_TX_AXIS_TKEEP           : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_ARP_TX_AXIS_TREADY          : out std_logic;
      M_ARP_RX_AXIS_TDATA           : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_ARP_RX_AXIS_TVALID          : out std_logic;
      M_ARP_RX_AXIS_TLAST           : out std_logic;
      M_ARP_RX_AXIS_TKEEP           : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_ARP_RX_AXIS_TREADY          : in  std_logic;
      S_EXT_TX_AXIS_TDATA           : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_AXIS_TVALID          : in  std_logic;
      S_EXT_TX_AXIS_TLAST           : in  std_logic;
      S_EXT_TX_AXIS_TKEEP           : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_AXIS_TREADY          : out std_logic;
      M_EXT_RX_AXIS_TDATA           : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_AXIS_TVALID          : out std_logic;
      M_EXT_RX_AXIS_TLAST           : out std_logic;
      M_EXT_RX_AXIS_TKEEP           : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_AXIS_TREADY          : in  std_logic;
      FRAME_ROUTER_RDY              : out std_logic;
      ROUTER_DATA_RX_FIFO_OVERFLOW  : out std_logic;
      ROUTER_CRC_RX_FIFO_OVERFLOW   : out std_logic;
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
      FLAG_CRC_FILTER               : out std_logic;
      FLAG_MAC_FILTER               : out std_logic
    );
  end component uoe_frame_router;

  -- RAW Ethernet
  component uoe_raw_ethernet is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : positive  := 64
    );
    port(
      CLK            : in  std_logic;
      RST            : in  std_logic;
      INIT_DONE      : in  std_logic;
      S_TX_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TX_TVALID    : in  std_logic;
      S_TX_TLAST     : in  std_logic;
      S_TX_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TX_TID       : in  std_logic_vector(15 downto 0);
      S_TX_TREADY    : out std_logic;
      M_TX_TDATA     : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TX_TVALID    : out std_logic;
      M_TX_TLAST     : out std_logic;
      M_TX_TKEEP     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TX_TREADY    : in  std_logic;
      S_RX_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_RX_TVALID    : in  std_logic;
      S_RX_TLAST     : in  std_logic;
      S_RX_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_RX_TREADY    : out std_logic;
      M_RX_TDATA     : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_RX_TVALID    : out std_logic;
      M_RX_TLAST     : out std_logic;
      M_RX_TKEEP     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RX_TID       : out std_logic_vector(15 downto 0);
      M_RX_TREADY    : in  std_logic;
      DEST_MAC_ADDR  : in  std_logic_vector(47 downto 0);
      LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0)
    );
  end component uoe_raw_ethernet;

  component uoe_mac_shaping is
    generic(
      G_ENABLE_ARP_TABLE : boolean   := false;
      G_ACTIVE_RST       : std_logic := '0';
      G_ASYNC_RST        : boolean   := true;
      G_TDATA_WIDTH      : positive  := 64
    );
    port(
      CLK                  : in  std_logic;
      RST                  : in  std_logic;
      S_TX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TX_TVALID          : in  std_logic;
      S_TX_TLAST           : in  std_logic;
      S_TX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TX_TID             : in  std_logic_vector(15 downto 0);
      S_TX_TUSER           : in  std_logic_vector(31 downto 0);
      S_TX_TREADY          : out std_logic;
      M_TX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TX_TVALID          : out std_logic;
      M_TX_TLAST           : out std_logic;
      M_TX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TX_TREADY          : in  std_logic;
      S_RX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_RX_TVALID          : in  std_logic;
      S_RX_TLAST           : in  std_logic;
      S_RX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_RX_TREADY          : out std_logic;
      M_RX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_RX_TVALID          : out std_logic;
      M_RX_TLAST           : out std_logic;
      M_RX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RX_TID             : out std_logic_vector(15 downto 0);
      M_RX_TREADY          : in  std_logic;
      M_ARP_IP_TDATA       : out std_logic_vector(31 downto 0);
      M_ARP_IP_TVALID      : out std_logic;
      M_ARP_IP_TREADY      : in  std_logic;
      S_ARP_IP_MAC_TDATA   : in  std_logic_vector(79 downto 0);
      S_ARP_IP_MAC_TVALID  : in  std_logic;
      S_ARP_IP_MAC_TUSER   : in  std_logic_vector(0 downto 0);
      S_ARP_IP_MAC_TREADY  : out std_logic;
      FORCE_IP_ADDR_DEST   : in  std_logic_vector(31 downto 0);
      FORCE_ARP_REQUEST    : in  std_logic;
      LOCAL_MAC_ADDR       : in  std_logic_vector(47 downto 0);
      LOCAL_IP_ADDR        : in  std_logic_vector(31 downto 0);
      CLEAR_ARP_TABLE      : in  std_logic;
      CLEAR_ARP_TABLE_DONE : out std_logic;
      S_AXI_AWADDR         : in  std_logic_vector(11 downto 0);
      S_AXI_AWVALID        : in  std_logic;
      S_AXI_AWREADY        : out std_logic;
      S_AXI_WDATA          : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID         : in  std_logic;
      S_AXI_WREADY         : out std_logic;
      S_AXI_BRESP          : out std_logic_vector(1 downto 0);
      S_AXI_BVALID         : out std_logic;
      S_AXI_BREADY         : in  std_logic;
      S_AXI_ARADDR         : in  std_logic_vector(11 downto 0);
      S_AXI_ARVALID        : in  std_logic;
      S_AXI_ARREADY        : out std_logic;
      S_AXI_RDATA          : out std_logic_vector(31 downto 0);
      S_AXI_RRESP          : out std_logic_vector(1 downto 0);
      S_AXI_RVALID         : out std_logic;
      S_AXI_RREADY         : in  std_logic
    );
  end component uoe_mac_shaping;

  -- Interface RAW From/To Eth Frame Router
  signal axis_raw_tx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_raw_tx_tvalid : std_logic;
  signal axis_raw_tx_tlast  : std_logic;
  signal axis_raw_tx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_raw_tx_tready : std_logic;

  signal axis_raw_rx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_raw_rx_tvalid : std_logic;
  signal axis_raw_rx_tlast  : std_logic;
  signal axis_raw_rx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_raw_rx_tready : std_logic;

  -- Interface RAW From/To Eth Frame Router
  signal axis_mac_shaping_tx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_shaping_tx_tvalid : std_logic;
  signal axis_mac_shaping_tx_tlast  : std_logic;
  signal axis_mac_shaping_tx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_mac_shaping_tx_tready : std_logic;

  signal axis_mac_shaping_rx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_shaping_rx_tvalid : std_logic;
  signal axis_mac_shaping_rx_tlast  : std_logic;
  signal axis_mac_shaping_rx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_mac_shaping_rx_tready : std_logic;

  -- Interface RAW From/To Eth Frame Router
  signal axis_arp_tx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_arp_tx_tvalid : std_logic;
  signal axis_arp_tx_tlast  : std_logic;
  signal axis_arp_tx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_arp_tx_tready : std_logic;

  signal axis_arp_rx_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_arp_rx_tvalid : std_logic;
  signal axis_arp_rx_tlast  : std_logic;
  signal axis_arp_rx_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_arp_rx_tready : std_logic;

  signal axis_mac_to_arp_tdata  : std_logic_vector(31 downto 0);
  signal axis_mac_to_arp_tvalid : std_logic;
  signal axis_mac_to_arp_tready : std_logic;
  signal axis_arp_to_mac_tdata  : std_logic_vector(79 downto 0);
  signal axis_arp_to_mac_tvalid : std_logic;
  signal axis_arp_to_mac_tuser  : std_logic_vector(0 downto 0);
  signal axis_arp_to_mac_tready : std_logic;

begin

  -- Router
  inst_uoe_frame_router : uoe_frame_router
    generic map(
      G_ACTIVE_RST        => G_ACTIVE_RST,
      G_ASYNC_RST         => G_ASYNC_RST,
      G_MAC_TDATA_WIDTH   => G_MAC_TDATA_WIDTH,
      G_UOE_TDATA_WIDTH   => G_UOE_TDATA_WIDTH,
      G_ROUTER_FIFO_DEPTH => G_ROUTER_FIFO_DEPTH
    )
    port map(
      CLK_RX                        => CLK_RX,
      RST_RX                        => RST_RX,
      CLK_TX                        => CLK_TX,
      RST_TX                        => RST_TX,
      CLK_UOE                       => CLK_UOE,
      RST_UOE                       => RST_UOE,
      INIT_DONE                     => INIT_DONE,
      MAC_RX_AXIS_TDATA             => S_MAC_RX_TDATA,
      MAC_RX_AXIS_TVALID            => S_MAC_RX_TVALID,
      MAC_RX_AXIS_TLAST             => S_MAC_RX_TLAST,
      MAC_RX_AXIS_TKEEP             => S_MAC_RX_TKEEP,
      MAC_RX_AXIS_TUSER             => S_MAC_RX_TUSER,
      MAC_TX_AXIS_TDATA             => M_MAC_TX_TDATA,
      MAC_TX_AXIS_TVALID            => M_MAC_TX_TVALID,
      MAC_TX_AXIS_TLAST             => M_MAC_TX_TLAST,
      MAC_TX_AXIS_TKEEP             => M_MAC_TX_TKEEP,
      MAC_TX_AXIS_TUSER             => M_MAC_TX_TUSER,
      MAC_TX_AXIS_TREADY            => M_MAC_TX_TREADY,
      S_RAW_TX_AXIS_TDATA           => axis_raw_tx_tdata,
      S_RAW_TX_AXIS_TVALID          => axis_raw_tx_tvalid,
      S_RAW_TX_AXIS_TLAST           => axis_raw_tx_tlast,
      S_RAW_TX_AXIS_TKEEP           => axis_raw_tx_tkeep,
      S_RAW_TX_AXIS_TREADY          => axis_raw_tx_tready,
      M_RAW_RX_AXIS_TDATA           => axis_raw_rx_tdata,
      M_RAW_RX_AXIS_TVALID          => axis_raw_rx_tvalid,
      M_RAW_RX_AXIS_TLAST           => axis_raw_rx_tlast,
      M_RAW_RX_AXIS_TKEEP           => axis_raw_rx_tkeep,
      M_RAW_RX_AXIS_TREADY          => axis_raw_rx_tready,
      S_SHAPING_TX_AXIS_TDATA       => axis_mac_shaping_tx_tdata,
      S_SHAPING_TX_AXIS_TVALID      => axis_mac_shaping_tx_tvalid,
      S_SHAPING_TX_AXIS_TLAST       => axis_mac_shaping_tx_tlast,
      S_SHAPING_TX_AXIS_TKEEP       => axis_mac_shaping_tx_tkeep,
      S_SHAPING_TX_AXIS_TREADY      => axis_mac_shaping_tx_tready,
      M_SHAPING_RX_AXIS_TDATA       => axis_mac_shaping_rx_tdata,
      M_SHAPING_RX_AXIS_TVALID      => axis_mac_shaping_rx_tvalid,
      M_SHAPING_RX_AXIS_TLAST       => axis_mac_shaping_rx_tlast,
      M_SHAPING_RX_AXIS_TKEEP       => axis_mac_shaping_rx_tkeep,
      M_SHAPING_RX_AXIS_TREADY      => axis_mac_shaping_rx_tready,
      S_ARP_TX_AXIS_TDATA           => axis_arp_tx_tdata,
      S_ARP_TX_AXIS_TVALID          => axis_arp_tx_tvalid,
      S_ARP_TX_AXIS_TLAST           => axis_arp_tx_tlast,
      S_ARP_TX_AXIS_TKEEP           => axis_arp_tx_tkeep,
      S_ARP_TX_AXIS_TREADY          => axis_arp_tx_tready,
      M_ARP_RX_AXIS_TDATA           => axis_arp_rx_tdata,
      M_ARP_RX_AXIS_TVALID          => axis_arp_rx_tvalid,
      M_ARP_RX_AXIS_TLAST           => axis_arp_rx_tlast,
      M_ARP_RX_AXIS_TKEEP           => axis_arp_rx_tkeep,
      M_ARP_RX_AXIS_TREADY          => axis_arp_rx_tready,
      S_EXT_TX_AXIS_TDATA           => S_EXT_TX_TDATA,
      S_EXT_TX_AXIS_TVALID          => S_EXT_TX_TVALID,
      S_EXT_TX_AXIS_TLAST           => S_EXT_TX_TLAST,
      S_EXT_TX_AXIS_TKEEP           => S_EXT_TX_TKEEP,
      S_EXT_TX_AXIS_TREADY          => S_EXT_TX_TREADY,
      M_EXT_RX_AXIS_TDATA           => M_EXT_RX_TDATA,
      M_EXT_RX_AXIS_TVALID          => M_EXT_RX_TVALID,
      M_EXT_RX_AXIS_TLAST           => M_EXT_RX_TLAST,
      M_EXT_RX_AXIS_TKEEP           => M_EXT_RX_TKEEP,
      M_EXT_RX_AXIS_TREADY          => M_EXT_RX_TREADY,
      FRAME_ROUTER_RDY              => LINK_LAYER_RDY,
      ROUTER_DATA_RX_FIFO_OVERFLOW  => ROUTER_DATA_RX_FIFO_OVERFLOW,
      ROUTER_CRC_RX_FIFO_OVERFLOW   => ROUTER_CRC_RX_FIFO_OVERFLOW,
      BROADCAST_FILTER_ENABLE       => BROADCAST_FILTER_ENABLE,
      IPV4_MULTICAST_FILTER_ENABLE  => IPV4_MULTICAST_FILTER_ENABLE,
      IPV4_MULTICAST_MAC_ADDR_LSB_1 => IPV4_MULTICAST_MAC_ADDR_LSB_1,
      IPV4_MULTICAST_MAC_ADDR_LSB_2 => IPV4_MULTICAST_MAC_ADDR_LSB_2,
      IPV4_MULTICAST_MAC_ADDR_LSB_3 => IPV4_MULTICAST_MAC_ADDR_LSB_3,
      IPV4_MULTICAST_MAC_ADDR_LSB_4 => IPV4_MULTICAST_MAC_ADDR_LSB_4,
      IPV4_MULTICAST_ADDR_1_ENABLE  => IPV4_MULTICAST_ADDR_1_ENABLE,
      IPV4_MULTICAST_ADDR_2_ENABLE  => IPV4_MULTICAST_ADDR_2_ENABLE,
      IPV4_MULTICAST_ADDR_3_ENABLE  => IPV4_MULTICAST_ADDR_3_ENABLE,
      IPV4_MULTICAST_ADDR_4_ENABLE  => IPV4_MULTICAST_ADDR_4_ENABLE,
      UNICAST_FILTER_ENABLE         => UNICAST_FILTER_ENABLE,
      LOCAL_MAC_ADDR                => LOCAL_MAC_ADDR,
      FLAG_CRC_FILTER               => FLAG_CRC_FILTER,
      FLAG_MAC_FILTER               => FLAG_MAC_FILTER
    );

  -- RAW Ethernet
  inst_uoe_raw_ethernet : uoe_raw_ethernet
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK            => CLK_UOE,
      RST            => RST_UOE,
      INIT_DONE      => INIT_DONE,
      -- TX Path
      S_TX_TDATA     => S_RAW_TX_TDATA,
      S_TX_TVALID    => S_RAW_TX_TVALID,
      S_TX_TLAST     => S_RAW_TX_TLAST,
      S_TX_TKEEP     => S_RAW_TX_TKEEP,
      S_TX_TID       => S_RAW_TX_TUSER,
      S_TX_TREADY    => S_RAW_TX_TREADY,
      M_TX_TDATA     => axis_raw_tx_tdata,
      M_TX_TVALID    => axis_raw_tx_tvalid,
      M_TX_TLAST     => axis_raw_tx_tlast,
      M_TX_TKEEP     => axis_raw_tx_tkeep,
      M_TX_TREADY    => axis_raw_tx_tready,
      -- RX Path
      S_RX_TDATA     => axis_raw_rx_tdata,
      S_RX_TVALID    => axis_raw_rx_tvalid,
      S_RX_TLAST     => axis_raw_rx_tlast,
      S_RX_TKEEP     => axis_raw_rx_tkeep,
      S_RX_TREADY    => axis_raw_rx_tready,
      M_RX_TDATA     => M_RAW_RX_TDATA,
      M_RX_TVALID    => M_RAW_RX_TVALID,
      M_RX_TLAST     => M_RAW_RX_TLAST,
      M_RX_TKEEP     => M_RAW_RX_TKEEP,
      M_RX_TID       => M_RAW_RX_TUSER,
      M_RX_TREADY    => M_RAW_RX_TREADY,
      -- Registers
      DEST_MAC_ADDR  => RAW_DEST_MAC_ADDR,
      LOCAL_MAC_ADDR => LOCAL_MAC_ADDR
    );

  -- MAC Shaping
  inst_uoe_mac_shaping : uoe_mac_shaping
    generic map(
      G_ENABLE_ARP_TABLE => G_ENABLE_ARP_TABLE,
      G_ACTIVE_RST       => G_ACTIVE_RST,
      G_ASYNC_RST        => G_ASYNC_RST,
      G_TDATA_WIDTH      => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK                  => CLK_UOE,
      RST                  => RST_UOE,
      -------- TX Flow --------
      -- From internet layer
      S_TX_TDATA           => S_INTERNET_TX_TDATA,
      S_TX_TVALID          => S_INTERNET_TX_TVALID,
      S_TX_TLAST           => S_INTERNET_TX_TLAST,
      S_TX_TKEEP           => S_INTERNET_TX_TKEEP,
      S_TX_TID             => S_INTERNET_TX_TID,
      S_TX_TUSER           => S_INTERNET_TX_TUSER,
      S_TX_TREADY          => S_INTERNET_TX_TREADY,
      -- To Ethernet frame router
      M_TX_TDATA           => axis_mac_shaping_tx_tdata,
      M_TX_TVALID          => axis_mac_shaping_tx_tvalid,
      M_TX_TLAST           => axis_mac_shaping_tx_tlast,
      M_TX_TKEEP           => axis_mac_shaping_tx_tkeep,
      M_TX_TREADY          => axis_mac_shaping_tx_tready,
      -------- RX Flow --------
      -- From Ethernet frame router
      S_RX_TDATA           => axis_mac_shaping_rx_tdata,
      S_RX_TVALID          => axis_mac_shaping_rx_tvalid,
      S_RX_TLAST           => axis_mac_shaping_rx_tlast,
      S_RX_TKEEP           => axis_mac_shaping_rx_tkeep,
      S_RX_TREADY          => axis_mac_shaping_rx_tready,
      -- To internet layer
      M_RX_TDATA           => M_INTERNET_RX_TDATA,
      M_RX_TVALID          => M_INTERNET_RX_TVALID,
      M_RX_TLAST           => M_INTERNET_RX_TLAST,
      M_RX_TKEEP           => M_INTERNET_RX_TKEEP,
      M_RX_TID             => M_INTERNET_RX_TID,
      M_RX_TREADY          => M_INTERNET_RX_TREADY,
      -- ARP interface
      M_ARP_IP_TDATA       => axis_mac_to_arp_tdata,
      M_ARP_IP_TVALID      => axis_mac_to_arp_tvalid,
      M_ARP_IP_TREADY      => axis_mac_to_arp_tready,
      S_ARP_IP_MAC_TDATA   => axis_arp_to_mac_tdata,
      S_ARP_IP_MAC_TVALID  => axis_arp_to_mac_tvalid,
      S_ARP_IP_MAC_TUSER   => axis_arp_to_mac_tuser,
      S_ARP_IP_MAC_TREADY  => axis_arp_to_mac_tready,
      -- Registers interface
      FORCE_IP_ADDR_DEST   => FORCE_IP_ADDR_DEST,
      FORCE_ARP_REQUEST    => FORCE_ARP_REQUEST,
      LOCAL_MAC_ADDR       => LOCAL_MAC_ADDR,
      LOCAL_IP_ADDR        => LOCAL_IP_ADDR,
      CLEAR_ARP_TABLE      => CLEAR_ARP_TABLE,
      CLEAR_ARP_TABLE_DONE => CLEAR_ARP_TABLE_DONE,
      -- Debug interface
      S_AXI_AWADDR         => S_AXI_ARP_TABLE_AWADDR,
      S_AXI_AWVALID        => S_AXI_ARP_TABLE_AWVALID,
      S_AXI_AWREADY        => S_AXI_ARP_TABLE_AWREADY,
      S_AXI_WDATA          => S_AXI_ARP_TABLE_WDATA,
      S_AXI_WVALID         => S_AXI_ARP_TABLE_WVALID,
      S_AXI_WREADY         => S_AXI_ARP_TABLE_WREADY,
      S_AXI_BRESP          => S_AXI_ARP_TABLE_BRESP,
      S_AXI_BVALID         => S_AXI_ARP_TABLE_BVALID,
      S_AXI_BREADY         => S_AXI_ARP_TABLE_BREADY,
      S_AXI_ARADDR         => S_AXI_ARP_TABLE_ARADDR,
      S_AXI_ARVALID        => S_AXI_ARP_TABLE_ARVALID,
      S_AXI_ARREADY        => S_AXI_ARP_TABLE_ARREADY,
      S_AXI_RDATA          => S_AXI_ARP_TABLE_RDATA,
      S_AXI_RRESP          => S_AXI_ARP_TABLE_RRESP,
      S_AXI_RVALID         => S_AXI_ARP_TABLE_RVALID,
      S_AXI_RREADY         => S_AXI_ARP_TABLE_RREADY
    );

  -- Handle ARP Request/Reply protocol
  GEN_ARP_MODULE : if G_ENABLE_ARP_MODULE generate

    component uoe_arp_module is
      generic(
        G_ACTIVE_RST  : std_logic := '0';
        G_ASYNC_RST   : boolean   := true;
        G_FREQ_KHZ    : integer   := 156250;
        G_TDATA_WIDTH : integer   := 64
      );
      port(
        CLK                           : in  std_logic;
        RST                           : in  std_logic;
        S_IP_ADDR_TDATA               : in  std_logic_vector(31 downto 0);
        S_IP_ADDR_TVALID              : in  std_logic;
        S_IP_ADDR_TREADY              : out std_logic;
        M_IP_MAC_ADDR_TDATA           : out std_logic_vector(79 downto 0);
        M_IP_MAC_ADDR_TVALID          : out std_logic;
        M_IP_MAC_ADDR_TUSER           : out std_logic_vector(0 downto 0);
        M_IP_MAC_ADDR_TREADY          : in  std_logic;
        S_RX_TDATA                    : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        S_RX_TVALID                   : in  std_logic;
        S_RX_TLAST                    : in  std_logic;
        S_RX_TKEEP                    : in  std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
        S_RX_TREADY                   : out std_logic;
        M_TX_TDATA                    : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
        M_TX_TVALID                   : out std_logic;
        M_TX_TLAST                    : out std_logic;
        M_TX_TKEEP                    : out std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
        M_TX_TREADY                   : in  std_logic;
        INIT_DONE                     : in  std_logic;
        LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0);
        LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
        ARP_TIMEOUT_MS                : in  std_logic_vector(11 downto 0);
        ARP_TRYINGS                   : in  std_logic_vector(3 downto 0);
        ARP_GRATUITOUS_REQ            : in  std_logic;
        ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0);
        ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
        ARP_RX_FIFO_OVERFLOW          : out std_logic;
        ARP_IP_CONFLICT               : out std_logic;
        ARP_MAC_CONFLICT              : out std_logic;
        ARP_INIT_DONE                 : out std_logic;
        ARP_ERROR                     : out std_logic
      );
    end component uoe_arp_module;

  begin

    inst_uoe_arp_module : uoe_arp_module
      generic map(
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_ASYNC_RST   => G_ASYNC_RST,
        G_FREQ_KHZ    => G_FREQ_KHZ,
        G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
      )
      port map(
        CLK                           => CLK_UOE,
        RST                           => RST_UOE,
        S_IP_ADDR_TDATA               => axis_mac_to_arp_tdata,
        S_IP_ADDR_TVALID              => axis_mac_to_arp_tvalid,
        S_IP_ADDR_TREADY              => axis_mac_to_arp_tready,
        M_IP_MAC_ADDR_TDATA           => axis_arp_to_mac_tdata,
        M_IP_MAC_ADDR_TVALID          => axis_arp_to_mac_tvalid,
        M_IP_MAC_ADDR_TUSER           => axis_arp_to_mac_tuser,
        M_IP_MAC_ADDR_TREADY          => axis_arp_to_mac_tready,
        S_RX_TDATA                    => axis_arp_rx_tdata,
        S_RX_TVALID                   => axis_arp_rx_tvalid,
        S_RX_TLAST                    => axis_arp_rx_tlast,
        S_RX_TKEEP                    => axis_arp_rx_tkeep,
        S_RX_TREADY                   => axis_arp_rx_tready,
        M_TX_TDATA                    => axis_arp_tx_tdata,
        M_TX_TVALID                   => axis_arp_tx_tvalid,
        M_TX_TLAST                    => axis_arp_tx_tlast,
        M_TX_TKEEP                    => axis_arp_tx_tkeep,
        M_TX_TREADY                   => axis_arp_tx_tready,
        INIT_DONE                     => INIT_DONE,
        LOCAL_IP_ADDR                 => LOCAL_IP_ADDR,
        LOCAL_MAC_ADDR                => LOCAL_MAC_ADDR,
        ARP_TIMEOUT_MS                => ARP_TIMEOUT_MS,
        ARP_TRYINGS                   => ARP_TRYINGS,
        ARP_GRATUITOUS_REQ            => ARP_GRATUITOUS_REQ,
        ARP_RX_TARGET_IP_FILTER       => ARP_RX_TARGET_IP_FILTER,
        ARP_RX_TEST_LOCAL_IP_CONFLICT => ARP_RX_TEST_LOCAL_IP_CONFLICT,
        ARP_RX_FIFO_OVERFLOW          => ARP_RX_FIFO_OVERFLOW,
        ARP_IP_CONFLICT               => ARP_IP_CONFLICT,
        ARP_MAC_CONFLICT              => ARP_MAC_CONFLICT,
        ARP_INIT_DONE                 => ARP_INIT_DONE,
        ARP_ERROR                     => ARP_ERROR
      );

  end generate GEN_ARP_MODULE;

  -- ARP Request/Reply protocol disabled
  GEN_NO_ARP_MODULE : if not G_ENABLE_ARP_MODULE generate

    component uoe_arp_module_disable_protocol is
      generic(
        G_ACTIVE_RST : std_logic := '0';
        G_ASYNC_RST  : boolean   := true
      );
      port(
        CLK                  : in  std_logic;
        RST                  : in  std_logic;
        S_IP_ADDR_TDATA      : in  std_logic_vector(31 downto 0);
        S_IP_ADDR_TVALID     : in  std_logic;
        S_IP_ADDR_TREADY     : out std_logic;
        M_IP_MAC_ADDR_TDATA  : out std_logic_vector(79 downto 0);
        M_IP_MAC_ADDR_TVALID : out std_logic;
        M_IP_MAC_ADDR_TUSER  : out std_logic_vector(0 downto 0);
        M_IP_MAC_ADDR_TREADY : in  std_logic;
        RAW_DEST_MAC_ADDR    : in  std_logic_vector(47 downto 0)
      );
    end component uoe_arp_module_disable_protocol;

  begin

    ARP_IP_CONFLICT  <= '0';
    ARP_MAC_CONFLICT <= '0';
    ARP_ERROR        <= '0';

    ARP_INIT_DONE <= INIT_DONE;

    axis_arp_tx_tdata  <= (others => '0');
    axis_arp_tx_tvalid <= '0';
    axis_arp_tx_tlast  <= '0';
    axis_arp_tx_tkeep  <= (others => '0');
    axis_arp_rx_tready <= '1';

    inst_uoe_arp_module_disable_protocol : uoe_arp_module_disable_protocol
      generic map(
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST
      )
      port map(
        CLK                  => CLK_UOE,
        RST                  => RST_UOE,
        S_IP_ADDR_TDATA      => axis_mac_to_arp_tdata,
        S_IP_ADDR_TVALID     => axis_mac_to_arp_tvalid,
        S_IP_ADDR_TREADY     => axis_mac_to_arp_tready,
        M_IP_MAC_ADDR_TDATA  => axis_arp_to_mac_tdata,
        M_IP_MAC_ADDR_TVALID => axis_arp_to_mac_tvalid,
        M_IP_MAC_ADDR_TUSER  => axis_arp_to_mac_tuser,
        M_IP_MAC_ADDR_TREADY => axis_arp_to_mac_tready,
        RAW_DEST_MAC_ADDR    => RAW_DEST_MAC_ADDR
      );

  end generate GEN_NO_ARP_MODULE;

end rtl;
