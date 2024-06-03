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

----------------------------------
-- FRAME SWITCH
----------------------------------
--
-- Route incoming frame to the appropriate destination (RAW, ARP, MAC or EXT)
-- according to Ethertype and IPV4 Protocol fields values
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_mux_custom;
use common.axis_utils_pkg.axis_demux_custom;
use common.axis_utils_pkg.axis_broadcast_custom;

use work.uoe_module_pkg.all;

entity uoe_frame_switch is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 32     -- Width of the tdata vector of the stream
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
end uoe_frame_switch;

architecture rtl of uoe_frame_switch is

  -------------------------------------
  --
  -- Components declaration
  --
  -------------------------------------

  component uoe_frame_switch_tdest is
    generic(
      G_ACTIVE_RST  : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH : positive  := 32   -- Width of the tdata vector of the stream
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic;
      RST      : in  std_logic;
      -- axi4-stream slave
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY : out std_logic;
      -- axi4-stream master
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TDEST  : out std_logic_vector(2 downto 0);
      M_TREADY : in  std_logic
    );
  end component uoe_frame_switch_tdest;

  -------------------------------------
  --
  -- Constants declaration
  --
  -------------------------------------
  constant C_NB_ITF_TX   : integer := 4;
  constant C_NB_ITF_RX   : integer := 5;
  constant C_INDEX_RAW   : integer := to_integer(unsigned(C_TDEST_RAW));
  constant C_INDEX_ARP   : integer := to_integer(unsigned(C_TDEST_ARP));
  constant C_INDEX_MAC   : integer := to_integer(unsigned(C_TDEST_MAC_SHAPING));
  constant C_INDEX_EXT   : integer := to_integer(unsigned(C_TDEST_EXT));
  constant C_INDEX_TRASH : integer := to_integer(unsigned(C_TDEST_TRASH));

  constant C_TKEEP_WIDTH : positive := (G_TDATA_WIDTH + 7) / 8;

  -------------------------------------
  --
  -- Signals declaration
  --
  -------------------------------------

  -- Tx PATH
  signal axis_tx_tdata  : std_logic_vector((C_NB_ITF_TX * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_tx_tvalid : std_logic_vector(C_NB_ITF_TX - 1 downto 0);
  signal axis_tx_tlast  : std_logic_vector(C_NB_ITF_TX - 1 downto 0);
  signal axis_tx_tkeep  : std_logic_vector((C_NB_ITF_TX * C_TKEEP_WIDTH) - 1 downto 0);
  signal axis_tx_tready : std_logic_vector(C_NB_ITF_TX - 1 downto 0);

  -- RX PATH
  signal axis_rx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_tvalid : std_logic;
  signal axis_rx_tlast  : std_logic;
  signal axis_rx_tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
  signal axis_rx_tdest  : std_logic_vector(2 downto 0);
  signal axis_rx_tready : std_logic;

  signal axis_rx_demux_tdata  : std_logic_vector((C_NB_ITF_RX * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_rx_demux_tvalid : std_logic_vector(C_NB_ITF_RX - 1 downto 0);
  signal axis_rx_demux_tlast  : std_logic_vector(C_NB_ITF_RX - 1 downto 0);
  signal axis_rx_demux_tkeep  : std_logic_vector((C_NB_ITF_RX * C_TKEEP_WIDTH) - 1 downto 0);
  signal axis_rx_demux_tready : std_logic_vector(C_NB_ITF_RX - 1 downto 0);

  signal axis_arp_bc_tdata  : std_logic_vector((2 * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_arp_bc_tvalid : std_logic_vector(1 downto 0);
  signal axis_arp_bc_tlast  : std_logic_vector(1 downto 0);
  signal axis_arp_bc_tkeep  : std_logic_vector((2 * C_TKEEP_WIDTH) - 1 downto 0);
  signal axis_arp_bc_tready : std_logic_vector(1 downto 0);

  signal axis_ext_rx_tdata  : std_logic_vector((2 * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_ext_rx_tvalid : std_logic_vector(1 downto 0);
  signal axis_ext_rx_tlast  : std_logic_vector(1 downto 0);
  signal axis_ext_rx_tkeep  : std_logic_vector((2 * C_TKEEP_WIDTH) - 1 downto 0);
  signal axis_ext_rx_tready : std_logic_vector(1 downto 0);

begin

  ------------------------------
  ----- Tx Path Output MUX -----
  ------------------------------

  -- MUX with fixed priority : S00 channel higher
  inst_axis_mux_custom_tx : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_NB_SLAVE            => C_NB_ITF_TX,
      G_REG_SLAVES_FORWARD  => "1000",  -- Disable input register when it is an internal connection
      G_REG_SLAVES_BACKWARD => "1000",
      G_REG_MASTER_FORWARD  => false,   -- Disable output register because bus is directly connected to width converter with PIPELINE=true
      G_REG_MASTER_BACKWARD => false,
      G_PACKET_MODE         => true
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACES are packed together
      S_TDATA  => axis_tx_tdata,
      S_TVALID => axis_tx_tvalid,
      S_TLAST  => axis_tx_tlast,
      S_TKEEP  => axis_tx_tkeep,
      S_TREADY => axis_tx_tready,
      -- MASTER INTERFACE
      M_TDATA  => M_PHY_TX_AXIS_TDATA,
      M_TVALID => M_PHY_TX_AXIS_TVALID,
      M_TLAST  => M_PHY_TX_AXIS_TLAST,
      M_TKEEP  => M_PHY_TX_AXIS_TKEEP,
      M_TREADY => M_PHY_TX_AXIS_TREADY
    );

  -- S00 : RAW Ethernet
  axis_tx_tdata((G_TDATA_WIDTH * (C_INDEX_RAW + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_RAW)) <= S_RAW_TX_AXIS_TDATA;
  axis_tx_tvalid(C_INDEX_RAW)                                                                 <= S_RAW_TX_AXIS_TVALID;
  axis_tx_tlast(C_INDEX_RAW)                                                                  <= S_RAW_TX_AXIS_TLAST;
  axis_tx_tkeep((C_TKEEP_WIDTH * (C_INDEX_RAW + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_RAW)) <= S_RAW_TX_AXIS_TKEEP;
  S_RAW_TX_AXIS_TREADY                                                                        <= axis_tx_tready(C_INDEX_RAW);

  -- S01 : ARP
  axis_tx_tdata((G_TDATA_WIDTH * (C_INDEX_ARP + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_ARP)) <= S_ARP_TX_AXIS_TDATA;
  axis_tx_tvalid(C_INDEX_ARP)                                                                 <= S_ARP_TX_AXIS_TVALID;
  axis_tx_tlast(C_INDEX_ARP)                                                                  <= S_ARP_TX_AXIS_TLAST;
  axis_tx_tkeep((C_TKEEP_WIDTH * (C_INDEX_ARP + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_ARP)) <= S_ARP_TX_AXIS_TKEEP;
  S_ARP_TX_AXIS_TREADY                                                                        <= axis_tx_tready(C_INDEX_ARP);

  -- S02 : MAC Shaping
  axis_tx_tdata((G_TDATA_WIDTH * (C_INDEX_MAC + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_MAC)) <= S_SHAPING_TX_AXIS_TDATA;
  axis_tx_tvalid(C_INDEX_MAC)                                                                 <= S_SHAPING_TX_AXIS_TVALID;
  axis_tx_tlast(C_INDEX_MAC)                                                                  <= S_SHAPING_TX_AXIS_TLAST;
  axis_tx_tkeep((C_TKEEP_WIDTH * (C_INDEX_MAC + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_MAC)) <= S_SHAPING_TX_AXIS_TKEEP;
  S_SHAPING_TX_AXIS_TREADY                                                                    <= axis_tx_tready(C_INDEX_MAC);

  -- S03 : EXT
  axis_tx_tdata((G_TDATA_WIDTH * (C_INDEX_EXT + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_EXT)) <= S_EXT_TX_AXIS_TDATA;
  axis_tx_tvalid(C_INDEX_EXT)                                                                 <= S_EXT_TX_AXIS_TVALID;
  axis_tx_tlast(C_INDEX_EXT)                                                                  <= S_EXT_TX_AXIS_TLAST;
  axis_tx_tkeep((C_TKEEP_WIDTH * (C_INDEX_EXT + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_EXT)) <= S_EXT_TX_AXIS_TKEEP;
  S_EXT_TX_AXIS_TREADY                                                                        <= axis_tx_tready(C_INDEX_EXT);

  -------------------------------
  ----- Rx Path input demux -----
  -------------------------------

  -- Route incoming frame to the appropriate destination (RAW, ARP, MAC or EXT)
  inst_uoe_frame_switch_tdest : uoe_frame_switch_tdest
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- axi4-stream slave
      S_TDATA  => S_PHY_RX_AXIS_TDATA,
      S_TVALID => S_PHY_RX_AXIS_TVALID,
      S_TLAST  => S_PHY_RX_AXIS_TLAST,
      S_TKEEP  => S_PHY_RX_AXIS_TKEEP,
      S_TREADY => S_PHY_RX_AXIS_TREADY,
      -- axi4-stream master
      M_TDATA  => axis_rx_tdata,
      M_TVALID => axis_rx_tvalid,
      M_TLAST  => axis_rx_tlast,
      M_TKEEP  => axis_rx_tkeep,
      M_TDEST  => axis_rx_tdest,
      M_TREADY => axis_rx_tready
    );

  -- Demux
  inst_axis_demux_custom_rx : axis_demux_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TDEST_WIDTH          => 3,
      G_NB_MASTER            => C_NB_ITF_RX,
      G_REG_SLAVE_FORWARD    => false,    -- Disable input registers FW
      G_REG_SLAVE_BACKWARD   => false,    -- Disable input registers BW
      G_REG_MASTERS_FORWARD  => "00000",  -- Disable output registers FW
      G_REG_MASTERS_BACKWARD => "00000"
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACE
      S_TDATA  => axis_rx_tdata,
      S_TVALID => axis_rx_tvalid,
      S_TLAST  => axis_rx_tlast,
      S_TKEEP  => axis_rx_tkeep,
      S_TDEST  => axis_rx_tdest,
      S_TREADY => axis_rx_tready,
      -- MASTER INTERFACES are packed together
      M_TDATA  => axis_rx_demux_tdata,
      M_TVALID => axis_rx_demux_tvalid,
      M_TLAST  => axis_rx_demux_tlast,
      M_TKEEP  => axis_rx_demux_tkeep,
      M_TDEST  => open,
      M_TREADY => axis_rx_demux_tready
    );

  -- M00 - RAW Ethernet
  M_RAW_RX_AXIS_TDATA               <= axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_RAW + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_RAW));
  M_RAW_RX_AXIS_TVALID              <= axis_rx_demux_tvalid(C_INDEX_RAW);
  M_RAW_RX_AXIS_TLAST               <= axis_rx_demux_tlast(C_INDEX_RAW);
  M_RAW_RX_AXIS_TKEEP               <= axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_RAW + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_RAW));
  axis_rx_demux_tready(C_INDEX_RAW) <= M_RAW_RX_AXIS_TREADY;

  -- M01 : ARP

  -- M02 - MAC Ethernet
  M_SHAPING_RX_AXIS_TDATA           <= axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_MAC + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_MAC));
  M_SHAPING_RX_AXIS_TVALID          <= axis_rx_demux_tvalid(C_INDEX_MAC);
  M_SHAPING_RX_AXIS_TLAST           <= axis_rx_demux_tlast(C_INDEX_MAC);
  M_SHAPING_RX_AXIS_TKEEP           <= axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_MAC + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_MAC));
  axis_rx_demux_tready(C_INDEX_MAC) <= M_SHAPING_RX_AXIS_TREADY;

  -- M03 : Ext

  -- M04 : Trash
  axis_rx_demux_tready(C_INDEX_TRASH) <= '1';

  -- ARP are broadcast to internal module and external SW stack
  inst_axis_broadcast_custom : axis_broadcast_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_NB_MASTER            => 2,
      G_REG_SLAVE_FORWARD    => false,
      G_REG_SLAVE_BACKWARD   => false,
      G_REG_MASTERS_FORWARD  => "00",   -- Disable output registers
      G_REG_MASTERS_BACKWARD => "00"
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACE
      S_TDATA  => axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_ARP + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_ARP)),
      S_TVALID => axis_rx_demux_tvalid(C_INDEX_ARP),
      S_TLAST  => axis_rx_demux_tlast(C_INDEX_ARP),
      S_TKEEP  => axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_ARP + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_ARP)),
      S_TREADY => axis_rx_demux_tready(C_INDEX_ARP),
      -- MASTER INTERFACE
      M_TDATA  => axis_arp_bc_tdata,
      M_TVALID => axis_arp_bc_tvalid,
      M_TLAST  => axis_arp_bc_tlast,
      M_TKEEP  => axis_arp_bc_tkeep,
      M_TREADY => axis_arp_bc_tready
    );

  -- ARP interface
  M_ARP_RX_AXIS_TDATA   <= axis_arp_bc_tdata(G_TDATA_WIDTH - 1 downto 0);
  M_ARP_RX_AXIS_TVALID  <= axis_arp_bc_tvalid(0);
  M_ARP_RX_AXIS_TLAST   <= axis_arp_bc_tlast(0);
  M_ARP_RX_AXIS_TKEEP   <= axis_arp_bc_tkeep(C_TKEEP_WIDTH - 1 downto 0);
  axis_arp_bc_tready(0) <= M_ARP_RX_AXIS_TREADY;

  -- Arbiter between Ext and arp to ext
  -- Fixed priority, arbitrate on tlast
  inst_axis_mux_custom_rx_ext : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_NB_SLAVE            => 2,
      G_REG_SLAVES_FORWARD  => "00",    -- Disable input registers
      G_REG_SLAVES_BACKWARD => "00",
      G_REG_MASTER_FORWARD  => true,
      G_REG_MASTER_BACKWARD => false,
      G_PACKET_MODE         => true
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACES are packed together
      S_TDATA  => axis_ext_rx_tdata,
      S_TVALID => axis_ext_rx_tvalid,
      S_TLAST  => axis_ext_rx_tlast,
      S_TKEEP  => axis_ext_rx_tkeep,
      S_TREADY => axis_ext_rx_tready,
      -- MASTER INTERFACE
      M_TDATA  => M_EXT_RX_AXIS_TDATA,
      M_TVALID => M_EXT_RX_AXIS_TVALID,
      M_TLAST  => M_EXT_RX_AXIS_TLAST,
      M_TKEEP  => M_EXT_RX_AXIS_TKEEP,
      M_TREADY => M_EXT_RX_AXIS_TREADY
    );

  -- S00 : ext
  axis_ext_rx_tdata(G_TDATA_WIDTH - 1 downto 0) <= axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_EXT + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_EXT));
  axis_ext_rx_tvalid(0)                         <= axis_rx_demux_tvalid(C_INDEX_EXT);
  axis_ext_rx_tlast(0)                          <= axis_rx_demux_tlast(C_INDEX_EXT);
  axis_ext_rx_tkeep(C_TKEEP_WIDTH - 1 downto 0) <= axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_EXT + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_EXT));
  axis_rx_demux_tready(C_INDEX_EXT)             <= axis_ext_rx_tready(0);

  -- S01 : arp
  axis_ext_rx_tdata((2 * G_TDATA_WIDTH) - 1 downto G_TDATA_WIDTH) <= axis_arp_bc_tdata((2 * G_TDATA_WIDTH) - 1 downto G_TDATA_WIDTH);
  axis_ext_rx_tvalid(1)                                           <= axis_arp_bc_tvalid(1);
  axis_ext_rx_tlast(1)                                            <= axis_arp_bc_tlast(1);
  axis_ext_rx_tkeep((2 * C_TKEEP_WIDTH) - 1 downto C_TKEEP_WIDTH) <= axis_arp_bc_tkeep((2 * C_TKEEP_WIDTH) - 1 downto C_TKEEP_WIDTH);
  axis_arp_bc_tready(1)                                           <= axis_ext_rx_tready(1);

end rtl;
