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
-- INTEGRATED TESTS UDP
--------------------------------------
--
-- This module integrated some tests tools to be used on the UDP interface.
-- * A loopback path with a fifo
-- * A frame generator to create flow on the TX interface
-- * A frame checker to compare incoming frame received on RX interface with an expected pattern 
--
--------------------------------------

library common;
use common.axis_utils_pkg.axis_mux_custom;
use common.axis_utils_pkg.axis_demux_custom;
use common.axis_utils_pkg.axis_fifo;
use common.axis_utils_pkg.axis_rate_limit;

use common.datatest_tools_pkg.axis_pkt_gen;
use common.datatest_tools_pkg.axis_frame_chk;
use common.datatest_tools_pkg.axis_monitor;
use common.datatest_tools_pkg.C_GEN_PRBS;

entity uoe_integrated_tests_udp is
  generic(
    G_ACTIVE_RST      : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST       : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH     : positive  := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_FIFO_ADDR_WIDTH : positive  := 8 -- FIFO address width (depth is 2**ADDR_WIDTH)
  );
  port(
    -- Clock domain of MAC in rx
    CLK                   : in  std_logic;
    RST                   : in  std_logic;
    -- RX Path PHY => Core
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
    -- TX Path Core => PHY
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
    -- Global Control
    LOOPBACK_EN           : in  std_logic;
    LB_GEN_DEST_PORT      : in  std_logic_vector(15 downto 0); -- Use for loopback and generator
    LB_GEN_SRC_PORT       : in  std_logic_vector(15 downto 0); -- Use for loopback and generator
    LB_GEN_DEST_IP_ADDR   : in  std_logic_vector(31 downto 0); -- Use for loopback and generator
    CHK_LISTENING_PORT    : in  std_logic_vector(15 downto 0);
    -- Control/Status Generator
    GEN_ENABLE            : in  std_logic;
    GEN_NB_FRAME          : in  std_logic_vector(15 downto 0);
    GEN_FRAME_SIZE_TYPE   : in  std_logic;
    GEN_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
    GEN_DONE              : out std_logic;
    GEN_MON_TIMEOUT_VALUE : in  std_logic_vector(15 downto 0);
    GEN_MON_ERROR         : out std_logic_vector(6 downto 0);
    GEN_RATE_NB_TRANSFERS : in  std_logic_vector(7 downto 0);
    GEN_RATE_WINDOW_SIZE  : in  std_logic_vector(7 downto 0);
    GEN_TEST_DURATION     : out std_logic_vector(63 downto 0);
    -- Control/Status Checker
    CHK_ENABLE            : in  std_logic;
    CHK_NB_FRAME          : in  std_logic_vector(15 downto 0);
    CHK_FRAME_SIZE_TYPE   : in  std_logic;
    CHK_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
    CHK_DONE              : out std_logic;
    CHK_ERROR             : out std_logic_vector(2 downto 0);
    CHK_MON_TIMEOUT_VALUE : in  std_logic_vector(15 downto 0);
    CHK_MON_ERROR         : out std_logic_vector(6 downto 0);
    CHK_TEST_DURATION     : out std_logic_vector(63 downto 0)
  );
end uoe_integrated_tests_udp;

architecture rtl of uoe_integrated_tests_udp is

  ----------------------------------
  -- Constants declaration
  ----------------------------------

  constant C_FRAME_SIZE_MIN_TEST_ENVT : integer := 1; -- Minimal size in bytes of the frame for the test envt
  constant C_FRAME_SIZE_MAX_TEST_ENVT : integer := 1460; -- Maximal size in bytes of the frame for the test envt
  constant C_FRAME_SIZE               : integer := integer(ceil(log2(real(C_FRAME_SIZE_MAX_TEST_ENVT))));

  constant C_TUSER_WIDTH : integer := 80;

  ----------------------------------
  -- Signals declaration
  ----------------------------------

  -- Interface mux/demux
  signal axis_tx_mux_tdata  : std_logic_vector((2 * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_tx_mux_tvalid : std_logic_vector(1 downto 0);
  signal axis_tx_mux_tlast  : std_logic_vector(1 downto 0);
  signal axis_tx_mux_tkeep  : std_logic_vector(((2 * (G_TDATA_WIDTH / 8)) - 1) downto 0);
  signal axis_tx_mux_tuser  : std_logic_vector((2 * C_TUSER_WIDTH) - 1 downto 0);
  signal axis_tx_mux_tready : std_logic_vector(1 downto 0);

  signal axis_tx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_tx_tvalid : std_logic;
  signal axis_tx_tlast  : std_logic;
  signal axis_tx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_tx_tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_tx_tready : std_logic;

  signal axis_rx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_rx_tvalid : std_logic;
  signal axis_rx_tlast  : std_logic;
  signal axis_rx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_rx_tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_rx_tdest  : std_logic;
  signal axis_rx_tready : std_logic;

  signal axis_rx_demux_tdata  : std_logic_vector((2 * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_rx_demux_tvalid : std_logic_vector(1 downto 0);
  signal axis_rx_demux_tlast  : std_logic_vector(1 downto 0);
  signal axis_rx_demux_tkeep  : std_logic_vector(((2 * (G_TDATA_WIDTH / 8)) - 1) downto 0);
  signal axis_rx_demux_tuser  : std_logic_vector((2 * C_TUSER_WIDTH) - 1 downto 0);
  signal axis_rx_demux_tready : std_logic_vector(1 downto 0);

  -- Interface Fifo
  signal axis_udp_fifo_tx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_udp_fifo_tx_tvalid : std_logic;
  signal axis_udp_fifo_tx_tlast  : std_logic;
  signal axis_udp_fifo_tx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_udp_fifo_tx_tuser  : std_logic_vector(15 downto 0);
  signal axis_udp_fifo_tx_tready : std_logic;

  signal axis_udp_fifo_rx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_udp_fifo_rx_tvalid : std_logic;
  signal axis_udp_fifo_rx_tlast  : std_logic;
  signal axis_udp_fifo_rx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_udp_fifo_rx_tuser  : std_logic_vector(15 downto 0);
  signal axis_udp_fifo_rx_tready : std_logic;

  -- Axis Frame Generator
  signal axis_gen_tdata      : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_gen_tvalid     : std_logic;
  signal axis_gen_tlast      : std_logic;
  signal axis_gen_tuser      : std_logic_vector(C_FRAME_SIZE-1 downto 0);
  signal axis_gen_tkeep      : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_gen_tready     : std_logic;

  signal axis_gen_rate_tdata      : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_gen_rate_tvalid     : std_logic;
  signal axis_gen_rate_tlast      : std_logic;
  signal axis_gen_rate_tuser      : std_logic_vector(C_FRAME_SIZE-1 downto 0);
  signal axis_gen_rate_tkeep      : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_gen_rate_tready     : std_logic;

  -- Axis Frame Checker
  signal axis_chk_tdata      : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_chk_tvalid     : std_logic;
  signal axis_chk_tlast      : std_logic;
  signal axis_chk_tuser      : std_logic_vector(C_FRAME_SIZE-1 downto 0);
  signal axis_chk_tkeep      : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_chk_tready     : std_logic;

  -- others signals used to compute test duration
  signal gen_enable_r  : std_logic;
  signal gen_done_i    : std_logic;
  signal gen_done_r    : std_logic;
  
  signal chk_enable_r  : std_logic;
  signal chk_done_i    : std_logic;
  signal chk_done_r    : std_logic;
  signal chk_active    : std_logic;

begin

  -------------------------------------------
  -- LOOPBACK FIFO
  -------------------------------------------

  axis_rx_tdata  <= S_CORE_RX_TDATA;
  axis_rx_tvalid <= S_CORE_RX_TVALID when not (LOOPBACK_EN = '1') else '0';
  axis_rx_tlast  <= S_CORE_RX_TLAST;
  axis_rx_tkeep  <= S_CORE_RX_TKEEP;
  axis_rx_tuser  <= S_CORE_RX_TUSER;

  S_CORE_RX_TREADY <= axis_rx_tready when not (LOOPBACK_EN = '1') else axis_udp_fifo_rx_tready;

  axis_udp_fifo_rx_tdata  <= S_CORE_RX_TDATA;
  axis_udp_fifo_rx_tvalid <= S_CORE_RX_TVALID when LOOPBACK_EN = '1' else '0';
  axis_udp_fifo_rx_tlast  <= S_CORE_RX_TLAST;
  axis_udp_fifo_rx_tkeep  <= S_CORE_RX_TKEEP;
  axis_udp_fifo_rx_tuser  <= S_CORE_RX_TUSER(47 downto 32);

  -- Axis fifo loopback UDP
  inst_axis_fifo_udp_rx_tx : axis_fifo
    generic map(
      G_COMMON_CLK  => true,
      G_ADDR_WIDTH  => G_FIFO_ADDR_WIDTH,
      G_TDATA_WIDTH => G_TDATA_WIDTH,
      G_TUSER_WIDTH => 16,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 0,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => 2
    )
    port map(
      S_CLK         => CLK,
      S_RST         => RST,
      S_TDATA       => axis_udp_fifo_rx_tdata,
      S_TVALID      => axis_udp_fifo_rx_tvalid,
      S_TLAST       => axis_udp_fifo_rx_tlast,
      S_TUSER       => axis_udp_fifo_rx_tuser,
      S_TSTRB       => (others => '-'),
      S_TKEEP       => axis_udp_fifo_rx_tkeep,
      S_TID         => (others => '-'),
      S_TDEST       => (others => '-'),
      S_TREADY      => axis_udp_fifo_rx_tready,
      M_CLK         => CLK,
      M_TDATA       => axis_udp_fifo_tx_tdata,
      M_TVALID      => axis_udp_fifo_tx_tvalid,
      M_TLAST       => axis_udp_fifo_tx_tlast,
      M_TUSER       => axis_udp_fifo_tx_tuser,
      M_TSTRB       => open,
      M_TKEEP       => axis_udp_fifo_tx_tkeep,
      M_TID         => open,
      M_TDEST       => open,
      M_TREADY      => axis_udp_fifo_tx_tready,
      WR_DATA_COUNT => open,
      WR_PKT_COUNT  => open,
      RD_DATA_COUNT => open,
      RD_PKT_COUNT  => open
    );

  M_CORE_TX_TDATA  <= axis_tx_tdata when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tdata;
  M_CORE_TX_TVALID <= axis_tx_tvalid when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tvalid;
  M_CORE_TX_TLAST  <= axis_tx_tlast when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tlast;
  M_CORE_TX_TKEEP  <= axis_tx_tkeep when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tkeep;
  M_CORE_TX_TUSER  <= axis_tx_tuser when not (LOOPBACK_EN = '1') else LB_GEN_DEST_PORT & LB_GEN_SRC_PORT & axis_udp_fifo_tx_tuser & LB_GEN_DEST_IP_ADDR;

  axis_udp_fifo_tx_tready <= M_CORE_TX_TREADY when LOOPBACK_EN = '1' else '1'; -- Empty fifo
  axis_tx_tready          <= M_CORE_TX_TREADY when not (LOOPBACK_EN = '1') else '1';

  --======================================
  --   AXIS FRAME Generator
  --======================================

  -- Packet Generator
  inst_axis_pkt_gen : axis_pkt_gen
    generic map(
      G_ASYNC_RST      => G_ASYNC_RST,
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TUSER_WIDTH    => C_FRAME_SIZE,
      G_LSB_TKEEP      => true,
      G_FRAME_SIZE_MIN => C_FRAME_SIZE_MIN_TEST_ENVT,
      G_FRAME_SIZE_MAX => C_FRAME_SIZE_MAX_TEST_ENVT,
      G_DATA_TYPE      => C_GEN_PRBS
    )
    port map(
      -- Global
      CLK               => CLK,
      RST               => RST,
      -- Output ports
      M_TDATA           => axis_gen_tdata,
      M_TVALID          => axis_gen_tvalid,
      M_TLAST           => axis_gen_tlast,
      M_TKEEP           => axis_gen_tkeep,
      M_TUSER           => axis_gen_tuser,
      M_TREADY          => axis_gen_tready,
      ENABLE            => GEN_ENABLE,
      NB_FRAME          => GEN_NB_FRAME,
      FRAME_TYPE        => GEN_FRAME_SIZE_TYPE,
      FRAME_STATIC_SIZE => GEN_FRAME_SIZE_STATIC(C_FRAME_SIZE - 1 downto 0),
      DONE              => gen_done_i
    );
  
  -- Rate limiter
  inst_axis_rate_limit : axis_rate_limit
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => G_TDATA_WIDTH,
      G_TUSER_WIDTH  => C_FRAME_SIZE,
      G_TID_WIDTH    => 1,
      G_TDEST_WIDTH  => 1,
      G_WINDOW_WIDTH => 8
    )
    port map(
      
      CLK          => CLK,
      RST          => RST,
      NB_TRANSFERS => GEN_RATE_NB_TRANSFERS,
      WINDOW_SIZE  => GEN_RATE_WINDOW_SIZE,
      S_TDATA      => axis_gen_tdata,
      S_TVALID     => axis_gen_tvalid,
      S_TLAST      => axis_gen_tlast,
      S_TUSER      => axis_gen_tuser,
      S_TSTRB      => (others => '-'),
      S_TKEEP      => axis_gen_tkeep,
      S_TID        => (others => '-'),
      S_TDEST      => (others => '-'),
      S_TREADY     => axis_gen_tready,
      M_TDATA      => axis_gen_rate_tdata,
      M_TVALID     => axis_gen_rate_tvalid,
      M_TLAST      => axis_gen_rate_tlast,
      M_TUSER      => axis_gen_rate_tuser,
      M_TSTRB      => open,
      M_TKEEP      => axis_gen_rate_tkeep,
      M_TID        => open,
      M_TDEST      => open,
      M_TREADY     => axis_gen_rate_tready
    );
  
  -- Monitor 
  inst_axis_monitor_tx : axis_monitor
    generic map(
      G_ASYNC_RST     => G_ASYNC_RST,
      G_ACTIVE_RST    => G_ACTIVE_RST,
      G_TDATA_WIDTH   => G_TDATA_WIDTH,
      G_TUSER_WIDTH   => C_FRAME_SIZE,
      G_TID_WIDTH     => 1,
      G_TDEST_WIDTH   => 1,
      G_TIMEOUT_WIDTH => 16
    )
    port map(
      CLK                 => CLK,
      RST                 => RST,
      S_TDATA             => axis_gen_rate_tdata,
      S_TVALID            => axis_gen_rate_tvalid,
      S_TLAST             => axis_gen_rate_tlast,
      S_TUSER             => axis_gen_rate_tuser,
      S_TSTRB             => (others => '-'),
      S_TKEEP             => axis_gen_rate_tkeep,
      S_TID               => (others => '-'),
      S_TDEST             => (others => '-'),
      S_TREADY            => axis_gen_rate_tready,
      ENABLE              => GEN_ENABLE,
      TIMEOUT_VALUE       => GEN_MON_TIMEOUT_VALUE,
      TIMEOUT_READY_ERROR => GEN_MON_ERROR(0),
      TIMEOUT_VALID_ERROR => GEN_MON_ERROR(1),
      VALID_ERROR         => GEN_MON_ERROR(2),
      DATA_ERROR          => GEN_MON_ERROR(3),
      LAST_ERROR          => GEN_MON_ERROR(4),
      USER_ERROR          => GEN_MON_ERROR(5),
      STRB_ERROR          => open,
      KEEP_ERROR          => GEN_MON_ERROR(6),
      ID_ERROR            => open,
      DEST_ERROR          => open
    );

  -- Compute test duration 
  P_GEN_DURATION : process(CLK,RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      GEN_TEST_DURATION <= (others => '0');
      gen_enable_r      <= '0';
      gen_done_r        <= '0';
      
    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        GEN_TEST_DURATION <= (others => '0');
        gen_enable_r      <= '0';
        gen_done_r        <= '0';
        
      else
        gen_enable_r <= GEN_ENABLE;
        gen_done_r   <= gen_done_i;
        
        -- Increment counter when enable and not done
        if (GEN_ENABLE = '1') and (gen_done_i /= '1') then
          GEN_TEST_DURATION <= std_logic_vector(unsigned(GEN_TEST_DURATION) + 1);
        end if;
        
        -- Init Time on rising_edge
        if (gen_enable_r /= '1') and (GEN_ENABLE = '1') then
          GEN_TEST_DURATION <= (others => '0');
        end if;
        
      end if;
    end if;
  end process P_GEN_DURATION;

  -- Generate Pulse done
  GEN_DONE <= '1' when (gen_done_r /= '1') and (gen_done_i = '1') else '0';

  --======================================
  --   AXIS FRAME Checker
  --======================================

  -- Checker
  inst_axis_frame_chk : axis_frame_chk
    generic map(
      G_ASYNC_RST      => G_ASYNC_RST,
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TUSER_WIDTH    => C_FRAME_SIZE,
      G_LSB_TKEEP      => true,
      G_FRAME_SIZE_MIN => C_FRAME_SIZE_MIN_TEST_ENVT,
      G_FRAME_SIZE_MAX => C_FRAME_SIZE_MAX_TEST_ENVT,
      G_DATA_TYPE      => C_GEN_PRBS
    )
    port map(
      CLK               => CLK,
      RST               => RST,
      S_TDATA           => axis_chk_tdata,
      S_TVALID          => axis_chk_tvalid,
      S_TLAST           => axis_chk_tlast,
      S_TUSER           => axis_chk_tuser,
      S_TKEEP           => axis_chk_tkeep,
      S_TREADY          => axis_chk_tready,
      ENABLE            => CHK_ENABLE,
      NB_FRAME          => CHK_NB_FRAME,
      FRAME_TYPE        => CHK_FRAME_SIZE_TYPE,
      FRAME_STATIC_SIZE => CHK_FRAME_SIZE_STATIC(C_FRAME_SIZE - 1 downto 0),
      DONE              => chk_done_i,
      DATA_ERROR        => CHK_ERROR(0),
      LAST_ERROR        => CHK_ERROR(1),
      KEEP_ERROR        => open,
      USER_ERROR        => CHK_ERROR(2)
    );
  

  -- Monitor 
  inst_axis_monitor_rx : axis_monitor
    generic map(
      G_ASYNC_RST     => G_ASYNC_RST,
      G_ACTIVE_RST    => G_ACTIVE_RST,
      G_TDATA_WIDTH   => G_TDATA_WIDTH,
      G_TUSER_WIDTH   => C_FRAME_SIZE,
      G_TID_WIDTH     => 1,
      G_TDEST_WIDTH   => 1,
      G_TIMEOUT_WIDTH => 16
    )
    port map(
      CLK                 => CLK,
      RST                 => RST,
      S_TDATA             => axis_chk_tdata,
      S_TVALID            => axis_chk_tvalid,
      S_TLAST             => axis_chk_tlast,
      S_TUSER             => axis_chk_tuser,
      S_TSTRB             => (others => '-'),
      S_TKEEP             => axis_chk_tkeep,
      S_TID               => (others => '-'),
      S_TDEST             => (others => '-'),
      S_TREADY            => axis_chk_tready,
      ENABLE              => CHK_ENABLE,
      TIMEOUT_VALUE       => CHK_MON_TIMEOUT_VALUE,
      TIMEOUT_READY_ERROR => CHK_MON_ERROR(0),
      TIMEOUT_VALID_ERROR => CHK_MON_ERROR(1),
      VALID_ERROR         => CHK_MON_ERROR(2),
      DATA_ERROR          => CHK_MON_ERROR(3),
      LAST_ERROR          => CHK_MON_ERROR(4),
      USER_ERROR          => CHK_MON_ERROR(5),
      STRB_ERROR          => open,
      KEEP_ERROR          => CHK_MON_ERROR(6),
      ID_ERROR            => open,
      DEST_ERROR          => open
    );

  -- Compute test duration 
  P_CHK_DURATION : process(CLK,RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      CHK_TEST_DURATION <= (others => '0');
      chk_enable_r      <= '0';
      chk_done_r        <= '0';
      chk_active        <= '0';
      
    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        CHK_TEST_DURATION <= (others => '0');
        chk_enable_r      <= '0';
        chk_done_r        <= '0';
        chk_active        <= '0';
      
      else
        chk_enable_r <= CHK_ENABLE;
        chk_done_r   <= chk_done_i;
        
        if CHK_ENABLE = '1' then
          -- Activate counter on the first transfer after ENABLE
          if (axis_chk_tvalid = '1') and (axis_chk_tready = '1') then
            chk_active <= '1';
          end if;
        else
          chk_active <= '0';
        end if;
          
        -- Increment counter when enable and not done
        if (chk_active = '1') and (chk_done_i /= '1') then
          CHK_TEST_DURATION <= std_logic_vector(unsigned(CHK_TEST_DURATION) + 1);
        end if;
        
        -- Init Time on rising_edge
        if (chk_enable_r /= '1') and (GEN_ENABLE = '1') then
          CHK_TEST_DURATION <= (others => '0');
        end if;
      end if;
    end if;
  end process P_CHK_DURATION;

  -- Generate Pulse done
  CHK_DONE <= '1' when (chk_done_r /= '1') and (chk_done_i = '1') else '0';

  --======================================
  -- TX MUX
  --======================================

  -- Custom instance
  inst_axis_mux_custom_tx : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_TUSER_WIDTH         => 80,
      G_TID_WIDTH           => 1,
      G_TDEST_WIDTH         => 1,
      G_NB_SLAVE            => 2,
      G_REG_SLAVES_FORWARD  => "00",
      G_REG_SLAVES_BACKWARD => "00",
      G_REG_MASTER_FORWARD  => true,
      G_REG_MASTER_BACKWARD => true,
      G_REG_ARB_FORWARD     => false,
      G_REG_ARB_BACKWARD    => false,
      G_PACKET_MODE         => true,
      G_ROUND_ROBIN         => false,
      G_FAST_ARCH           => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => axis_tx_mux_tdata,
      S_TVALID => axis_tx_mux_tvalid,
      S_TLAST  => axis_tx_mux_tlast,
      S_TUSER  => axis_tx_mux_tuser,
      S_TSTRB  => (others => '-'),
      S_TKEEP  => axis_tx_mux_tkeep,
      S_TID    => (others => '-'),
      S_TDEST  => (others => '-'),
      S_TREADY => axis_tx_mux_tready,
      M_TDATA  => axis_tx_tdata,
      M_TVALID => axis_tx_tvalid,
      M_TLAST  => axis_tx_tlast,
      M_TUSER  => axis_tx_tuser,
      M_TSTRB  => open,
      M_TKEEP  => axis_tx_tkeep,
      M_TID    => open,
      M_TDEST  => open,
      M_TREADY => axis_tx_tready
    );

  axis_tx_mux_tdata(G_TDATA_WIDTH - 1 downto 0)         <= S_EXT_TX_TDATA;
  axis_tx_mux_tvalid(0)                                 <= S_EXT_TX_TVALID;
  axis_tx_mux_tlast(0)                                  <= S_EXT_TX_TLAST;
  axis_tx_mux_tuser(C_TUSER_WIDTH - 1 downto 0)         <= S_EXT_TX_TUSER;
  axis_tx_mux_tkeep(((G_TDATA_WIDTH / 8) - 1) downto 0) <= S_EXT_TX_TKEEP;
  S_EXT_TX_TREADY                                       <= axis_tx_mux_tready(0);

  axis_tx_mux_tdata(axis_tx_mux_tdata'high downto G_TDATA_WIDTH)       <= axis_gen_rate_tdata;
  axis_tx_mux_tvalid(1)                                                <= axis_gen_rate_tvalid;
  axis_tx_mux_tlast(1)                                                 <= axis_gen_rate_tlast;
  axis_tx_mux_tuser(C_TUSER_WIDTH + 31 downto C_TUSER_WIDTH + 0)       <= LB_GEN_DEST_IP_ADDR;
  axis_tx_mux_tuser(C_TUSER_WIDTH + 47 downto C_TUSER_WIDTH + 32)      <= std_logic_vector(resize(unsigned(axis_gen_rate_tuser),16));
  axis_tx_mux_tuser(C_TUSER_WIDTH + 63 downto C_TUSER_WIDTH + 48)      <= LB_GEN_SRC_PORT;
  axis_tx_mux_tuser(C_TUSER_WIDTH + 79 downto C_TUSER_WIDTH + 64)      <= LB_GEN_DEST_PORT;
  axis_tx_mux_tkeep(axis_tx_mux_tkeep'high downto (G_TDATA_WIDTH / 8)) <= axis_gen_rate_tkeep;
  axis_gen_rate_tready                                                 <= axis_tx_mux_tready(1);


  --======================================
  -- RX DEMUX
  --======================================

  axis_rx_tdest <= '1' when axis_rx_tuser(79 downto 64) = CHK_LISTENING_PORT else '0';

  inst_axis_demux_custom_rx : axis_demux_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TUSER_WIDTH          => 80,
      G_TID_WIDTH            => 1,
      G_TDEST_WIDTH          => 1,
      G_NB_MASTER            => 2,
      G_REG_SLAVE_FORWARD    => false,
      G_REG_SLAVE_BACKWARD   => false,
      G_REG_MASTERS_FORWARD  => "01",
      G_REG_MASTERS_BACKWARD => "01"
    )
    port map(
      CLK        => CLK,
      RST        => RST,
      S_TDATA    => axis_rx_tdata,
      S_TVALID   => axis_rx_tvalid,
      S_TLAST    => axis_rx_tlast,
      S_TUSER    => axis_rx_tuser,
      S_TSTRB    => (others => '-'),
      S_TKEEP    => axis_rx_tkeep,
      S_TID      => (others => '-'),
      S_TDEST(0) => axis_rx_tdest,
      S_TREADY   => axis_rx_tready,
      M_TDATA    => axis_rx_demux_tdata,
      M_TVALID   => axis_rx_demux_tvalid,
      M_TLAST    => axis_rx_demux_tlast,
      M_TUSER    => axis_rx_demux_tuser,
      M_TSTRB    => open,
      M_TKEEP    => axis_rx_demux_tkeep,
      M_TID      => open,
      M_TDEST    => open,
      M_TREADY   => axis_rx_demux_tready
    );

  M_EXT_RX_TDATA          <= axis_rx_demux_tdata(G_TDATA_WIDTH - 1 downto 0);
  M_EXT_RX_TVALID         <= axis_rx_demux_tvalid(0);
  M_EXT_RX_TLAST          <= axis_rx_demux_tlast(0);
  M_EXT_RX_TUSER          <= axis_rx_demux_tuser(C_TUSER_WIDTH - 1 downto 0);
  M_EXT_RX_TKEEP          <= axis_rx_demux_tkeep(((G_TDATA_WIDTH / 8) - 1) downto 0);
  axis_rx_demux_tready(0) <= M_EXT_RX_TREADY;

  axis_chk_tdata          <= axis_rx_demux_tdata(axis_tx_mux_tdata'high downto G_TDATA_WIDTH);
  axis_chk_tvalid         <= axis_rx_demux_tvalid(1);
  axis_chk_tlast          <= axis_rx_demux_tlast(1);
  axis_chk_tuser          <= axis_rx_demux_tuser((C_TUSER_WIDTH + 32) + (C_FRAME_SIZE - 1) downto C_TUSER_WIDTH + 32);
  axis_chk_tkeep          <= axis_rx_demux_tkeep(axis_tx_mux_tkeep'high downto (G_TDATA_WIDTH / 8));
  axis_rx_demux_tready(1) <= axis_chk_tready;

end rtl;

