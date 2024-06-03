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
use ieee.math_real.all;

--------------------------------------
-- FRAME ROUTER
--------------------------------------
--
-- This module is the router of the IPs
-- 
-- It integrate the following modules :
-- * 2 CDC fifos and 2 Data width converter 
-- * A firewall used to filter the incoming frame following
-- * A switch to multiplex TX Frames or demultiplex RX Frames
--
--------------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_dwidth_converter;
use common.axis_utils_pkg.axis_fifo;

use common.cdc_utils_pkg.cdc_bit_sync;
use common.cdc_utils_pkg.cdc_pulse_sync;

use work.uoe_module_pkg.all;

----------------------------------
-- ethernet_frame_router
----------------------------------
--
-- Route incoming frame to the appropriate destination (RAW, ARP, MAC or EXT)
-- according to Ethertype and IPV4 Protocol fields values
--
----------------------------------

entity uoe_frame_router is
  generic(
    G_ACTIVE_RST        : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST         : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_MAC_TDATA_WIDTH   : positive  := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_UOE_TDATA_WIDTH   : positive  := 64; -- Number of bits used along AXi datapath of UOE
    G_ROUTER_FIFO_DEPTH : positive  := 1536 -- Depth of TX and RX Fifos in bytes
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
    INIT_DONE                     : in  std_logic;
    -- MAC interface
    -- Axis
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
    -- RAW ETHERNET INTERFACE
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
    -- MAC SHAPING INTERFACE
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
    -- ARP INTERFACE
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
    -- EXTERNAL INTERFACE
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
    -- Router init status
    FRAME_ROUTER_RDY              : out std_logic;
    -- Register interface
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
end entity uoe_frame_router;

architecture rtl of uoe_frame_router is

  -------------------------------------
  --
  -- Components declaration
  --
  -------------------------------------

  component uoe_generic_filter is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK             : in  std_logic;
      RST             : in  std_logic;
      INIT_DONE       : in  std_logic;
      S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID        : in  std_logic;
      S_TLAST         : in  std_logic;
      S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY        : out std_logic;
      S_STATUS_TDATA  : in  std_logic;
      S_STATUS_TVALID : in  std_logic;
      S_STATUS_TREADY : out std_logic;
      M_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID        : out std_logic;
      M_TLAST         : out std_logic;
      M_TKEEP         : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY        : in  std_logic;
      FLAG            : out std_logic
    );
  end component uoe_generic_filter;

  component uoe_mac_filter is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK                           : in  std_logic;
      RST                           : in  std_logic;
      S_TDATA                       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID                      : in  std_logic;
      S_TLAST                       : in  std_logic;
      S_TKEEP                       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY                      : out std_logic;
      M_TDATA                       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID                      : out std_logic;
      M_TLAST                       : out std_logic;
      M_TKEEP                       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY                      : in  std_logic;
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
      FLAG_MAC_FILTER               : out std_logic
    );
  end component uoe_mac_filter;

  component uoe_frame_switch is
    generic(
      G_ACTIVE_RST  : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH : positive  := 32   -- Width of the tdata vector of the stream
    );
    port(
      -- GLOBAL
      CLK                      : in  std_logic;
      RST                      : in  std_logic;
      -- FROM / TO PHYSICAL LAYER
      S_PHY_RX_AXIS_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_PHY_RX_AXIS_TVALID     : in  std_logic;
      S_PHY_RX_AXIS_TLAST      : in  std_logic;
      S_PHY_RX_AXIS_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_PHY_RX_AXIS_TREADY     : out std_logic;
      M_PHY_TX_AXIS_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_PHY_TX_AXIS_TVALID     : out std_logic;
      M_PHY_TX_AXIS_TLAST      : out std_logic;
      M_PHY_TX_AXIS_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_PHY_TX_AXIS_TREADY     : in  std_logic;
      -- RAW ETHERNET INTERFACE
      S_RAW_TX_AXIS_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_RAW_TX_AXIS_TVALID     : in  std_logic;
      S_RAW_TX_AXIS_TLAST      : in  std_logic;
      S_RAW_TX_AXIS_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_RAW_TX_AXIS_TREADY     : out std_logic;
      M_RAW_RX_AXIS_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_RAW_RX_AXIS_TVALID     : out std_logic;
      M_RAW_RX_AXIS_TLAST      : out std_logic;
      M_RAW_RX_AXIS_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RAW_RX_AXIS_TREADY     : in  std_logic;
      -- MAC SHAPING INTERFACE
      S_SHAPING_TX_AXIS_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_SHAPING_TX_AXIS_TVALID : in  std_logic;
      S_SHAPING_TX_AXIS_TLAST  : in  std_logic;
      S_SHAPING_TX_AXIS_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_SHAPING_TX_AXIS_TREADY : out std_logic;
      M_SHAPING_RX_AXIS_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_SHAPING_RX_AXIS_TVALID : out std_logic;
      M_SHAPING_RX_AXIS_TLAST  : out std_logic;
      M_SHAPING_RX_AXIS_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_SHAPING_RX_AXIS_TREADY : in  std_logic;
      -- ARP INTERFACE
      S_ARP_TX_AXIS_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_ARP_TX_AXIS_TVALID     : in  std_logic;
      S_ARP_TX_AXIS_TLAST      : in  std_logic;
      S_ARP_TX_AXIS_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_ARP_TX_AXIS_TREADY     : out std_logic;
      M_ARP_RX_AXIS_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_ARP_RX_AXIS_TVALID     : out std_logic;
      M_ARP_RX_AXIS_TLAST      : out std_logic;
      M_ARP_RX_AXIS_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_ARP_RX_AXIS_TREADY     : in  std_logic;
      -- EXTERNAL INTERFACE
      S_EXT_TX_AXIS_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_AXIS_TVALID     : in  std_logic;
      S_EXT_TX_AXIS_TLAST      : in  std_logic;
      S_EXT_TX_AXIS_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_AXIS_TREADY     : out std_logic;
      M_EXT_RX_AXIS_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_AXIS_TVALID     : out std_logic;
      M_EXT_RX_AXIS_TLAST      : out std_logic;
      M_EXT_RX_AXIS_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_AXIS_TREADY     : in  std_logic
    );
  end component uoe_frame_switch;

  -------------------------------------
  --
  -- Constants declaration
  --
  -------------------------------------
  constant C_MAC_TKEEP_WIDTH : positive := ((G_MAC_TDATA_WIDTH + 7) / 8);

  constant C_FIFO_MAC_ADDR_WIDTH : positive := integer(ceil(log2(real(G_ROUTER_FIFO_DEPTH) / real(C_MAC_TKEEP_WIDTH))));
  -- Minimum size of a frame equal C_MAC_HEADER_SIZE + 1 bytes of payload
  constant C_FIFO_FRC_ADDR_WIDTH : positive := integer(ceil(log2(real(G_ROUTER_FIFO_DEPTH) / real(C_MAC_HEADER_SIZE + 1))));

  -------------------------------------
  --
  -- Signals declaration
  --
  -------------------------------------

  -- TX
  signal axis_tx_switch_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_tx_switch_tvalid : std_logic;
  signal axis_tx_switch_tlast  : std_logic;
  signal axis_tx_switch_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_tx_switch_tready : std_logic;

  signal axis_tx_resize_tdata  : std_logic_vector(G_MAC_TDATA_WIDTH - 1 downto 0);
  signal axis_tx_resize_tvalid : std_logic;
  signal axis_tx_resize_tlast  : std_logic;
  signal axis_tx_resize_tkeep  : std_logic_vector(((G_MAC_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_tx_resize_tready : std_logic;

  -- RX
  signal mac_rx_axis_tready : std_logic;

  signal axis_rx_fifo_tdata  : std_logic_vector(G_MAC_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_fifo_tvalid : std_logic;
  signal axis_rx_fifo_tlast  : std_logic;
  signal axis_rx_fifo_tkeep  : std_logic_vector(((G_MAC_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_fifo_tready : std_logic;

  signal axis_rx_resize_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_resize_tvalid : std_logic;
  signal axis_rx_resize_tlast  : std_logic;
  signal axis_rx_resize_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_resize_tready : std_logic;

  signal axis_rx_crc_filter_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_crc_filter_tvalid : std_logic;
  signal axis_rx_crc_filter_tlast  : std_logic;
  signal axis_rx_crc_filter_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_crc_filter_tready : std_logic;

  signal axis_rx_mac_filter_tdata  : std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_mac_filter_tvalid : std_logic;
  signal axis_rx_mac_filter_tlast  : std_logic;
  signal axis_rx_mac_filter_tkeep  : std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_rx_mac_filter_tready : std_logic;

  -- RX Checker
  signal axis_pkt_status_tdata  : std_logic;
  signal axis_pkt_status_tvalid : std_logic;
  signal axis_pkt_status_tready : std_logic;

  signal axis_pkt_status_fifo_tdata  : std_logic;
  signal axis_pkt_status_fifo_tvalid : std_logic;
  signal axis_pkt_status_fifo_tready : std_logic;

  signal router_data_rx_fifo_overflow_rxclk : std_logic;
  signal router_crc_rx_fifo_overflow_rxclk  : std_logic;

  signal rst_rx_resync : std_logic;

begin

  -- Asynchronous assignments
  MAC_TX_AXIS_TUSER <= '0';

  -------------------------------------
  --
  -- FIFO / CDC
  --
  -------------------------------------

  -- TX Fifo
  inst_axis_fifo_mac_tx : axis_fifo
    generic map(
      G_COMMON_CLK  => false,
      G_ADDR_WIDTH  => C_FIFO_MAC_ADDR_WIDTH,
      G_TDATA_WIDTH => G_MAC_TDATA_WIDTH,
      G_TUSER_WIDTH => 1,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 10,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => 3
    )
    port map(
      -- slave interface
      S_CLK    => CLK_UOE,
      S_RST    => RST_UOE,
      S_TDATA  => axis_tx_resize_tdata,
      S_TVALID => axis_tx_resize_tvalid,
      S_TLAST  => axis_tx_resize_tlast,
      S_TUSER  => (others => '-'),
      S_TSTRB  => (others => '-'),
      S_TKEEP  => axis_tx_resize_tkeep,
      S_TID    => (others => '-'),
      S_TDEST  => (others => '-'),
      S_TREADY => axis_tx_resize_tready,
      -- master interface
      M_CLK    => CLK_TX,
      M_TDATA  => MAC_TX_AXIS_TDATA,
      M_TVALID => MAC_TX_AXIS_TVALID,
      M_TLAST  => MAC_TX_AXIS_TLAST,
      M_TUSER  => open,
      M_TSTRB  => open,
      M_TKEEP  => MAC_TX_AXIS_TKEEP,
      M_TID    => open,
      M_TDEST  => open,
      M_TREADY => MAC_TX_AXIS_TREADY
    );

  -- RX Fifo
  inst_axis_fifo_mac_rx : axis_fifo
    generic map(
      G_COMMON_CLK  => false,
      G_ADDR_WIDTH  => C_FIFO_MAC_ADDR_WIDTH,
      G_TDATA_WIDTH => G_MAC_TDATA_WIDTH,
      G_TUSER_WIDTH => 1,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 10,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => 3
    )
    port map(
      -- slave interface
      S_CLK    => CLK_RX,
      S_RST    => RST_RX,
      S_TDATA  => MAC_RX_AXIS_TDATA,
      S_TVALID => MAC_RX_AXIS_TVALID,
      S_TLAST  => MAC_RX_AXIS_TLAST,
      S_TUSER  => (others => '-'),
      S_TSTRB  => (others => '-'),
      S_TKEEP  => MAC_RX_AXIS_TKEEP,
      S_TID    => (others => '-'),
      S_TDEST  => (others => '-'),
      S_TREADY => mac_rx_axis_tready,
      -- master interface
      M_CLK    => CLK_UOE,
      M_TDATA  => axis_rx_fifo_tdata,
      M_TVALID => axis_rx_fifo_tvalid,
      M_TLAST  => axis_rx_fifo_tlast,
      M_TUSER  => open,
      M_TSTRB  => open,
      M_TKEEP  => axis_rx_fifo_tkeep,
      M_TID    => open,
      M_TDEST  => open,
      M_TREADY => axis_rx_fifo_tready
    );

  -- RX Fifo for checker status
  inst_axis_fifo_mac_rx_checker : axis_fifo
    generic map(
      G_COMMON_CLK  => false,
      G_ADDR_WIDTH  => C_FIFO_FRC_ADDR_WIDTH,
      G_TDATA_WIDTH => 1,
      G_TUSER_WIDTH => 1,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 0,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => 3
    )
    port map(
      -- slave interface
      S_CLK      => CLK_RX,
      S_RST      => RST_RX,
      S_TDATA(0) => axis_pkt_status_tdata,
      S_TVALID   => axis_pkt_status_tvalid,
      S_TLAST    => '-',
      S_TUSER    => (others => '-'),
      S_TSTRB    => (others => '-'),
      S_TKEEP    => (others => '-'),
      S_TID      => (others => '-'),
      S_TDEST    => (others => '-'),
      S_TREADY   => axis_pkt_status_tready,
      -- master interface
      M_CLK      => CLK_UOE,
      M_TDATA(0) => axis_pkt_status_fifo_tdata,
      M_TVALID   => axis_pkt_status_fifo_tvalid,
      M_TLAST    => open,
      M_TUSER    => open,
      M_TSTRB    => open,
      M_TKEEP    => open,
      M_TID      => open,
      M_TDEST    => open,
      M_TREADY   => axis_pkt_status_fifo_tready
    );

  axis_pkt_status_tdata  <= MAC_RX_AXIS_TUSER;
  axis_pkt_status_tvalid <= MAC_RX_AXIS_TVALID and MAC_RX_AXIS_TLAST;

  router_data_rx_fifo_overflow_rxclk <= MAC_RX_AXIS_TVALID and (not mac_rx_axis_tready);
  router_crc_rx_fifo_overflow_rxclk  <= axis_pkt_status_tvalid and (not axis_pkt_status_tready);

  -- Resync Data RX FIFO Overflow pulse
  inst_cdc_pulse_sync_data : cdc_pulse_sync
    generic map(
      G_NB_STAGE   => 2,
      G_REG_OUTPUT => true,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST
    )
    port map(
      CLK_IN    => CLK_RX,
      RST_IN    => RST_RX,
      PULSE_IN  => router_data_rx_fifo_overflow_rxclk,
      CLK_OUT   => CLK_UOE,
      RST_OUT   => RST_UOE,
      PULSE_OUT => ROUTER_DATA_RX_FIFO_OVERFLOW
    );

  -- Resync CRC RX FIFO Overflow pulse
  inst_cdc_pulse_sync_crc : cdc_pulse_sync
    generic map(
      G_NB_STAGE   => 2,
      G_REG_OUTPUT => true,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST
    )
    port map(
      CLK_IN    => CLK_RX,
      RST_IN    => RST_RX,
      PULSE_IN  => router_crc_rx_fifo_overflow_rxclk,
      CLK_OUT   => CLK_UOE,
      RST_OUT   => RST_UOE,
      PULSE_OUT => ROUTER_CRC_RX_FIFO_OVERFLOW
    );

  -- Resync FIFO status from MAC domain to UOE domain
  inst_cdc_bit_sync_frame_router_rdy : cdc_bit_sync
    generic map(
      G_NB_STAGE   => 2,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_RST_VALUE  => G_ACTIVE_RST
    )
    port map(
      -- asynchronous domain
      DATA_ASYNC => RST_RX,
      -- synchronous domain
      CLK        => CLK_UOE,
      RST        => RST_UOE,
      DATA_SYNC  => rst_rx_resync
    );

  FRAME_ROUTER_RDY <= '1' when rst_rx_resync /= G_ACTIVE_RST else '0';

  -------------------------------------
  --
  -- Resizing
  --
  -------------------------------------

  -- Data width conversion
  GEN_WITHOUT_DATA_WIDTH_CONV : if G_MAC_TDATA_WIDTH = G_UOE_TDATA_WIDTH generate
    
    -- Register TX Fifo input
    inst_axis_register_tx_fifo : axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TDATA_WIDTH    => G_UOE_TDATA_WIDTH
      )
      port map(
        CLK      => CLK_UOE,
        RST      => RST_UOE,
        S_TDATA  => axis_tx_switch_tdata,
        S_TVALID => axis_tx_switch_tvalid,
        S_TLAST  => axis_tx_switch_tlast,
        S_TKEEP  => axis_tx_switch_tkeep,
        S_TREADY => axis_tx_switch_tready,
        M_TDATA  => axis_tx_resize_tdata,
        M_TVALID => axis_tx_resize_tvalid,
        M_TLAST  => axis_tx_resize_tlast,
        M_TKEEP  => axis_tx_resize_tkeep,
        M_TREADY => axis_tx_resize_tready
      );
    

    -- Register Rx Fifo Output
    inst_axis_register_rx_fifo : axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TDATA_WIDTH    => G_UOE_TDATA_WIDTH
      )
      port map(
        CLK      => CLK_UOE,
        RST      => RST_UOE,
        S_TDATA  => axis_rx_fifo_tdata,
        S_TVALID => axis_rx_fifo_tvalid,
        S_TLAST  => axis_rx_fifo_tlast,
        S_TKEEP  => axis_rx_fifo_tkeep,
        S_TREADY => axis_rx_fifo_tready,
        M_TDATA  => axis_rx_resize_tdata,
        M_TVALID => axis_rx_resize_tvalid,
        M_TLAST  => axis_rx_resize_tlast,
        M_TKEEP  => axis_rx_resize_tkeep,
        M_TREADY => axis_rx_resize_tready
      );

  end generate GEN_WITHOUT_DATA_WIDTH_CONV;

  GEN_WITH_DATA_WIDTH_CONV : if G_MAC_TDATA_WIDTH /= G_UOE_TDATA_WIDTH generate

    -- TX data width Converter
    inst_axis_dwidth_converter_tx : axis_dwidth_converter
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_S_TDATA_WIDTH => G_UOE_TDATA_WIDTH,
        G_M_TDATA_WIDTH => G_MAC_TDATA_WIDTH,
        G_LITTLE_ENDIAN => true
      )
      port map(
        -- Global
        CLK      => CLK_UOE,
        RST      => RST_UOE,
        -- Axi4-stream slave
        S_TDATA  => axis_tx_switch_tdata,
        S_TVALID => axis_tx_switch_tvalid,
        S_TLAST  => axis_tx_switch_tlast,
        S_TKEEP  => axis_tx_switch_tkeep,
        S_TREADY => axis_tx_switch_tready,
        -- Axi4-stream master
        M_TDATA  => axis_tx_resize_tdata,
        M_TVALID => axis_tx_resize_tvalid,
        M_TLAST  => axis_tx_resize_tlast,
        M_TKEEP  => axis_tx_resize_tkeep,
        M_TREADY => axis_tx_resize_tready
      );

    -- RX data width Converter
    inst_axis_dwidth_converter_rx : axis_dwidth_converter
      generic map(
        G_ACTIVE_RST    => G_ACTIVE_RST,
        G_ASYNC_RST     => G_ASYNC_RST,
        G_S_TDATA_WIDTH => G_MAC_TDATA_WIDTH,
        G_M_TDATA_WIDTH => G_UOE_TDATA_WIDTH,
        G_LITTLE_ENDIAN => true
      )
      port map(
        -- Global
        CLK      => CLK_UOE,
        RST      => RST_UOE,
        -- Axi4-stream slave
        S_TDATA  => axis_rx_fifo_tdata,
        S_TVALID => axis_rx_fifo_tvalid,
        S_TLAST  => axis_rx_fifo_tlast,
        S_TKEEP  => axis_rx_fifo_tkeep,
        S_TREADY => axis_rx_fifo_tready,
        -- Axi4-stream master
        M_TDATA  => axis_rx_resize_tdata,
        M_TVALID => axis_rx_resize_tvalid,
        M_TLAST  => axis_rx_resize_tlast,
        M_TKEEP  => axis_rx_resize_tkeep,
        M_TREADY => axis_rx_resize_tready
      );

  end generate GEN_WITH_DATA_WIDTH_CONV;

  -------------------------------------
  --
  -- Rx Filtering
  --
  -------------------------------------

  -- Filter frame with bad CRC
  inst_uoe_generic_filter_crc : component uoe_generic_filter
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK             => CLK_UOE,
      RST             => RST_UOE,
      INIT_DONE       => INIT_DONE,
      S_TDATA         => axis_rx_resize_tdata,
      S_TVALID        => axis_rx_resize_tvalid,
      S_TLAST         => axis_rx_resize_tlast,
      S_TKEEP         => axis_rx_resize_tkeep,
      S_TREADY        => axis_rx_resize_tready,
      S_STATUS_TDATA  => axis_pkt_status_fifo_tdata,
      S_STATUS_TVALID => axis_pkt_status_fifo_tvalid,
      S_STATUS_TREADY => axis_pkt_status_fifo_tready,
      M_TDATA         => axis_rx_crc_filter_tdata,
      M_TVALID        => axis_rx_crc_filter_tvalid,
      M_TLAST         => axis_rx_crc_filter_tlast,
      M_TKEEP         => axis_rx_crc_filter_tkeep,
      M_TREADY        => axis_rx_crc_filter_tready,
      FLAG            => FLAG_CRC_FILTER
    );

  -- Filtering following MAC Address
  inst_uoe_mac_filter : uoe_mac_filter
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK                           => CLK_UOE,
      RST                           => RST_UOE,
      S_TDATA                       => axis_rx_crc_filter_tdata,
      S_TVALID                      => axis_rx_crc_filter_tvalid,
      S_TLAST                       => axis_rx_crc_filter_tlast,
      S_TKEEP                       => axis_rx_crc_filter_tkeep,
      S_TREADY                      => axis_rx_crc_filter_tready,
      M_TDATA                       => axis_rx_mac_filter_tdata,
      M_TVALID                      => axis_rx_mac_filter_tvalid,
      M_TLAST                       => axis_rx_mac_filter_tlast,
      M_TKEEP                       => axis_rx_mac_filter_tkeep,
      M_TREADY                      => axis_rx_mac_filter_tready,
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
      FLAG_MAC_FILTER               => FLAG_MAC_FILTER
    );

  --------------------------
  --
  -- Switch
  --
  --------------------------

  inst_uoe_frame_switch : uoe_frame_switch
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_UOE_TDATA_WIDTH
    )
    port map(
      CLK                      => CLK_UOE,
      RST                      => RST_UOE,
      -- FROM / TO PHYSICAL LAYER
      S_PHY_RX_AXIS_TDATA      => axis_rx_mac_filter_tdata,
      S_PHY_RX_AXIS_TVALID     => axis_rx_mac_filter_tvalid,
      S_PHY_RX_AXIS_TLAST      => axis_rx_mac_filter_tlast,
      S_PHY_RX_AXIS_TKEEP      => axis_rx_mac_filter_tkeep,
      S_PHY_RX_AXIS_TREADY     => axis_rx_mac_filter_tready,
      M_PHY_TX_AXIS_TDATA      => axis_tx_switch_tdata,
      M_PHY_TX_AXIS_TVALID     => axis_tx_switch_tvalid,
      M_PHY_TX_AXIS_TLAST      => axis_tx_switch_tlast,
      M_PHY_TX_AXIS_TKEEP      => axis_tx_switch_tkeep,
      M_PHY_TX_AXIS_TREADY     => axis_tx_switch_tready,
      -- RAW ETHERNET INTERFACE
      S_RAW_TX_AXIS_TDATA      => S_RAW_TX_AXIS_TDATA,
      S_RAW_TX_AXIS_TVALID     => S_RAW_TX_AXIS_TVALID,
      S_RAW_TX_AXIS_TLAST      => S_RAW_TX_AXIS_TLAST,
      S_RAW_TX_AXIS_TKEEP      => S_RAW_TX_AXIS_TKEEP,
      S_RAW_TX_AXIS_TREADY     => S_RAW_TX_AXIS_TREADY,
      M_RAW_RX_AXIS_TDATA      => M_RAW_RX_AXIS_TDATA,
      M_RAW_RX_AXIS_TVALID     => M_RAW_RX_AXIS_TVALID,
      M_RAW_RX_AXIS_TLAST      => M_RAW_RX_AXIS_TLAST,
      M_RAW_RX_AXIS_TKEEP      => M_RAW_RX_AXIS_TKEEP,
      M_RAW_RX_AXIS_TREADY     => M_RAW_RX_AXIS_TREADY,
      -- MAC SHAPING INTERFACE
      S_SHAPING_TX_AXIS_TDATA  => S_SHAPING_TX_AXIS_TDATA,
      S_SHAPING_TX_AXIS_TVALID => S_SHAPING_TX_AXIS_TVALID,
      S_SHAPING_TX_AXIS_TLAST  => S_SHAPING_TX_AXIS_TLAST,
      S_SHAPING_TX_AXIS_TKEEP  => S_SHAPING_TX_AXIS_TKEEP,
      S_SHAPING_TX_AXIS_TREADY => S_SHAPING_TX_AXIS_TREADY,
      M_SHAPING_RX_AXIS_TDATA  => M_SHAPING_RX_AXIS_TDATA,
      M_SHAPING_RX_AXIS_TVALID => M_SHAPING_RX_AXIS_TVALID,
      M_SHAPING_RX_AXIS_TLAST  => M_SHAPING_RX_AXIS_TLAST,
      M_SHAPING_RX_AXIS_TKEEP  => M_SHAPING_RX_AXIS_TKEEP,
      M_SHAPING_RX_AXIS_TREADY => M_SHAPING_RX_AXIS_TREADY,
      -- ARP INTERFACE
      S_ARP_TX_AXIS_TDATA      => S_ARP_TX_AXIS_TDATA,
      S_ARP_TX_AXIS_TVALID     => S_ARP_TX_AXIS_TVALID,
      S_ARP_TX_AXIS_TLAST      => S_ARP_TX_AXIS_TLAST,
      S_ARP_TX_AXIS_TKEEP      => S_ARP_TX_AXIS_TKEEP,
      S_ARP_TX_AXIS_TREADY     => S_ARP_TX_AXIS_TREADY,
      M_ARP_RX_AXIS_TDATA      => M_ARP_RX_AXIS_TDATA,
      M_ARP_RX_AXIS_TVALID     => M_ARP_RX_AXIS_TVALID,
      M_ARP_RX_AXIS_TLAST      => M_ARP_RX_AXIS_TLAST,
      M_ARP_RX_AXIS_TKEEP      => M_ARP_RX_AXIS_TKEEP,
      M_ARP_RX_AXIS_TREADY     => M_ARP_RX_AXIS_TREADY,
      -- EXTERNAL INTERFACE
      S_EXT_TX_AXIS_TDATA      => S_EXT_TX_AXIS_TDATA,
      S_EXT_TX_AXIS_TVALID     => S_EXT_TX_AXIS_TVALID,
      S_EXT_TX_AXIS_TLAST      => S_EXT_TX_AXIS_TLAST,
      S_EXT_TX_AXIS_TKEEP      => S_EXT_TX_AXIS_TKEEP,
      S_EXT_TX_AXIS_TREADY     => S_EXT_TX_AXIS_TREADY,
      M_EXT_RX_AXIS_TDATA      => M_EXT_RX_AXIS_TDATA,
      M_EXT_RX_AXIS_TVALID     => M_EXT_RX_AXIS_TVALID,
      M_EXT_RX_AXIS_TLAST      => M_EXT_RX_AXIS_TLAST,
      M_EXT_RX_AXIS_TKEEP      => M_EXT_RX_AXIS_TKEEP,
      M_EXT_RX_AXIS_TREADY     => M_EXT_RX_AXIS_TREADY
    );

end rtl;
