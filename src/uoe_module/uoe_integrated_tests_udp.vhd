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
    -- Ctrl
    LOOPBACK_EN           : in  std_logic;
    GEN_START_P           : in  std_logic;
    GEN_STOP_P            : in  std_logic;
    CHK_START_P           : in  std_logic;
    CHK_STOP_P            : in  std_logic;
    GEN_FRAME_SIZE_TYPE   : in  std_logic;
    GEN_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
    --GEN_TIMEOUT_VALUE      : in std_logic_vector(31 downto 0);
    GEN_RATE_LIMITATION   : in  std_logic_vector(7 downto 0);
    GEN_NB_BYTES          : in  std_logic_vector(63 downto 0);
    CHK_FRAME_SIZE_TYPE   : in  std_logic;
    CHK_FRAME_SIZE_STATIC : in  std_logic_vector(15 downto 0);
    --CHK_TIMEOUT_VALUE      : in std_logic_vector(31 downto 0);
    CHK_RATE_LIMITATION   : in  std_logic_vector(7 downto 0);
    CHK_NB_BYTES          : in  std_logic_vector(63 downto 0);
    LB_GEN_DEST_PORT      : in  std_logic_vector(15 downto 0);
    LB_GEN_SRC_PORT       : in  std_logic_vector(15 downto 0);
    LB_GEN_DEST_IP_ADDR   : in  std_logic_vector(31 downto 0);
    CHK_LISTENING_PORT    : in  std_logic_vector(15 downto 0);
    -- STATUS
    GEN_TEST_DURATION     : out std_logic_vector(63 downto 0);
    --GEN_TEST_NB_BYTES       : std_logic_vector(63 downto 0);
    GEN_DONE              : out std_logic;
    GEN_ERR_TIMEOUT       : out std_logic;
    CHK_TEST_DURATION     : out std_logic_vector(63 downto 0);
    --CHK_TEST_NB_BYTES       : out std_logic_vector(63 downto 0);
    CHK_DONE              : out std_logic;
    --CHK_ERR_FRAME_SIZE      : out std_logic;
    CHK_ERR_DATA          : out std_logic;
    CHK_ERR_TIMEOUT       : out std_logic
  );
end uoe_integrated_tests_udp;

architecture rtl of uoe_integrated_tests_udp is

  ----------------------------------
  -- Components declaration
  ----------------------------------

  component uoe_axis_frame is
    generic(
      C_TYPE             : string                     := "WO";
      C_AXIS_TDATA_WIDTH : integer range 1 to 64      := 64;
      C_TIMEOUT          : integer range 1 to 2 ** 30 := 2 ** 30;
      C_FRAME_SIZE_MIN   : integer range 1 to 65535   := 1;
      C_FRAME_SIZE_MAX   : integer range 1 to 65535   := 65535;
      C_INIT_VALUE       : integer range 1 to 2048    := 4;
      C_DATA_TYPE        : string                     := "PRBS"
    );
    port(
      clk               : in  std_logic;
      rst               : in  std_logic;
      m_axis_tdata      : out std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
      m_axis_tvalid     : out std_logic;
      m_axis_tlast      : out std_logic;
      m_axis_tkeep      : out std_logic_vector((C_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
      m_axis_tuser      : out std_logic_vector(31 downto 0);
      m_axis_tready     : in  std_logic;
      s_axis_tdata      : in  std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
      s_axis_tvalid     : in  std_logic;
      s_axis_tlast      : in  std_logic;
      s_axis_tready     : out std_logic;
      s_axis_tuser      : in  std_logic_vector(31 downto 0);
      s_axis_tkeep      : in  std_logic_vector((C_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
      start             : in  std_logic;
      stop              : in  std_logic;
      frame_size_type   : in  std_logic;
      random_threshold  : in  std_logic_vector(7 downto 0);
      nb_data           : in  std_logic_vector(63 downto 0);
      frame_size        : in  std_logic_vector(15 downto 0);
      transfert_time    : out std_logic_vector(63 downto 0);
      end_of_axis_frame : out std_logic;
      tdata_error       : out std_logic;
      link_error        : out std_logic
    );
  end component uoe_axis_frame;

  ----------------------------------
  -- Constants declaration
  ----------------------------------

  constant C_TIMEOUT_TEST_ENVT        : integer range 1 to 2 ** 30 := 2 ** 30; -- Timeout used for gen/checker test envt
  constant C_FRAME_SIZE_MIN_TEST_ENVT : integer                    := 1; -- Minimal size in bytes of the frame for the test envt
  constant C_FRAME_SIZE_MAX_TEST_ENVT : integer                    := 1460; -- Maximal size in bytes of the frame for the test envt
  constant C_INIT_VALUE_TEST_ENVT     : integer                    := 4; -- Seed used for the test envt

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
  signal axis_gen_tuser      : std_logic_vector(31 downto 0); -- <= OLD, NEW => (15 downto 0);
  signal axis_gen_tuser_full : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_gen_tkeep      : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_gen_tready     : std_logic;

  -- Axis Frame Checker
  signal axis_chk_tdata      : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_chk_tvalid     : std_logic;
  signal axis_chk_tlast      : std_logic;
  signal axis_chk_tuser      : std_logic_vector(31 downto 0); -- <= OLD, NEW => (15 downto 0);
  signal axis_chk_tuser_full : std_logic_vector(C_TUSER_WIDTH - 1 downto 0); -- <= OLD, NEW => (15 downto 0);
  signal axis_chk_tkeep      : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_chk_tready     : std_logic;

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
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST
    )
    port map(
      S_CLK    => CLK,
      S_RST    => RST,
      S_TDATA  => axis_udp_fifo_rx_tdata,
      S_TVALID => axis_udp_fifo_rx_tvalid,
      S_TLAST  => axis_udp_fifo_rx_tlast,
      S_TUSER  => axis_udp_fifo_rx_tuser,
      S_TKEEP  => axis_udp_fifo_rx_tkeep,
      S_TREADY => axis_udp_fifo_rx_tready,
      M_CLK    => CLK,
      M_RST    => RST,
      M_TDATA  => axis_udp_fifo_tx_tdata,
      M_TVALID => axis_udp_fifo_tx_tvalid,
      M_TLAST  => axis_udp_fifo_tx_tlast,
      M_TUSER  => axis_udp_fifo_tx_tuser,
      M_TKEEP  => axis_udp_fifo_tx_tkeep,
      M_TREADY => axis_udp_fifo_tx_tready
    );

  M_CORE_TX_TDATA  <= axis_tx_tdata when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tdata;
  M_CORE_TX_TVALID <= axis_tx_tvalid when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tvalid;
  M_CORE_TX_TLAST  <= axis_tx_tlast when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tlast;
  M_CORE_TX_TKEEP  <= axis_tx_tkeep when not (LOOPBACK_EN = '1') else axis_udp_fifo_tx_tkeep;
  M_CORE_TX_TUSER  <= axis_tx_tuser when not (LOOPBACK_EN = '1') else LB_GEN_DEST_PORT & LB_GEN_SRC_PORT & axis_udp_fifo_tx_tuser & LB_GEN_DEST_IP_ADDR;

  axis_udp_fifo_tx_tready <= M_CORE_TX_TREADY when LOOPBACK_EN = '1' else '1'; -- Empty fifo
  axis_tx_tready          <= M_CORE_TX_TREADY when not (LOOPBACK_EN = '1') else '1';

  ------------------------------
  -- AXIS FRAME
  ------------------------------

  -- Generator
  inst_uoe_axis_frame_gen : uoe_axis_frame
    generic map(
      C_TYPE             => "WO",
      C_AXIS_TDATA_WIDTH => G_TDATA_WIDTH,
      C_TIMEOUT          => C_TIMEOUT_TEST_ENVT,
      C_FRAME_SIZE_MIN   => C_FRAME_SIZE_MIN_TEST_ENVT,
      C_FRAME_SIZE_MAX   => C_FRAME_SIZE_MAX_TEST_ENVT,
      C_INIT_VALUE       => C_INIT_VALUE_TEST_ENVT,
      C_DATA_TYPE        => "PRBS"      -- "PRBS" "RAMP"
    )
    port map(
      clk               => CLK,
      rst               => RST,
      -- Master interface
      m_axis_tdata      => axis_gen_tdata,
      m_axis_tvalid     => axis_gen_tvalid,
      m_axis_tlast      => axis_gen_tlast,
      m_axis_tkeep      => axis_gen_tkeep,
      m_axis_tuser      => axis_gen_tuser,
      m_axis_tready     => axis_gen_tready,
      -- Slave interface
      s_axis_tdata      => (others => '0'),
      s_axis_tvalid     => '0',
      s_axis_tlast      => '0',
      s_axis_tready     => open,
      s_axis_tuser      => (others => '0'),
      s_axis_tkeep      => (others => '0'),
      -- Control      
      start             => GEN_START_P,
      stop              => GEN_STOP_P,
      frame_size_type   => GEN_FRAME_SIZE_TYPE,
      random_threshold  => GEN_RATE_LIMITATION,
      nb_data           => GEN_NB_BYTES,
      frame_size        => GEN_FRAME_SIZE_STATIC,
      -- Status
      transfert_time    => GEN_TEST_DURATION,
      end_of_axis_frame => GEN_DONE,
      tdata_error       => open,
      link_error        => GEN_ERR_TIMEOUT
    );

  axis_gen_tuser_full <= LB_GEN_DEST_PORT & LB_GEN_SRC_PORT & axis_gen_tuser(15 downto 0) & LB_GEN_DEST_IP_ADDR;

  -- Checker
  inst_uoe_axis_frame_chk : uoe_axis_frame
    generic map(
      C_TYPE             => "RO",
      C_AXIS_TDATA_WIDTH => G_TDATA_WIDTH,
      C_TIMEOUT          => C_TIMEOUT_TEST_ENVT,
      C_FRAME_SIZE_MIN   => C_FRAME_SIZE_MIN_TEST_ENVT,
      C_FRAME_SIZE_MAX   => C_FRAME_SIZE_MAX_TEST_ENVT,
      C_INIT_VALUE       => C_INIT_VALUE_TEST_ENVT,
      C_DATA_TYPE        => "PRBS"      -- "PRBS" "RAMP"
    )
    port map(
      clk               => CLK,
      rst               => RST,
      --axis interface
      m_axis_tdata      => open,
      m_axis_tvalid     => open,
      m_axis_tlast      => open,
      m_axis_tkeep      => open,
      m_axis_tuser      => open,
      m_axis_tready     => '1',
      s_axis_tdata      => axis_chk_tdata,
      s_axis_tvalid     => axis_chk_tvalid,
      s_axis_tlast      => axis_chk_tlast,
      s_axis_tready     => axis_chk_tready,
      s_axis_tuser      => axis_chk_tuser,
      s_axis_tkeep      => axis_chk_tkeep,
      --parameters      
      start             => CHK_START_P,
      stop              => CHK_STOP_P,
      frame_size_type   => CHK_FRAME_SIZE_TYPE,
      random_threshold  => CHK_RATE_LIMITATION,
      nb_data           => CHK_NB_BYTES,
      frame_size        => CHK_FRAME_SIZE_STATIC,
      -- Results
      transfert_time    => CHK_TEST_DURATION,
      end_of_axis_frame => CHK_DONE,
      tdata_error       => CHK_ERR_DATA,
      link_error        => CHK_ERR_TIMEOUT
    );

  axis_chk_tuser <= x"0000" & axis_chk_tuser_full(47 downto 32);

  -------------------------------------------
  -- TX MUX
  -------------------------------------------

  -- Custom instance
  inst_axis_mux_custom_tx : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_TUSER_WIDTH         => 80,
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
      S_TKEEP  => axis_tx_mux_tkeep,
      S_TREADY => axis_tx_mux_tready,
      M_TDATA  => axis_tx_tdata,
      M_TVALID => axis_tx_tvalid,
      M_TLAST  => axis_tx_tlast,
      M_TUSER  => axis_tx_tuser,
      M_TKEEP  => axis_tx_tkeep,
      M_TREADY => axis_tx_tready
    );

  axis_tx_mux_tdata(G_TDATA_WIDTH - 1 downto 0)         <= S_EXT_TX_TDATA;
  axis_tx_mux_tvalid(0)                                 <= S_EXT_TX_TVALID;
  axis_tx_mux_tlast(0)                                  <= S_EXT_TX_TLAST;
  axis_tx_mux_tuser(C_TUSER_WIDTH - 1 downto 0)         <= S_EXT_TX_TUSER;
  axis_tx_mux_tkeep(((G_TDATA_WIDTH / 8) - 1) downto 0) <= S_EXT_TX_TKEEP;
  S_EXT_TX_TREADY                                       <= axis_tx_mux_tready(0);

  axis_tx_mux_tdata(axis_tx_mux_tdata'high downto G_TDATA_WIDTH)       <= axis_gen_tdata;
  axis_tx_mux_tvalid(1)                                                <= axis_gen_tvalid;
  axis_tx_mux_tlast(1)                                                 <= axis_gen_tlast;
  axis_tx_mux_tuser(axis_tx_mux_tuser'high downto C_TUSER_WIDTH)       <= axis_gen_tuser_full;
  axis_tx_mux_tkeep(axis_tx_mux_tkeep'high downto (G_TDATA_WIDTH / 8)) <= axis_gen_tkeep;
  axis_gen_tready                                                      <= axis_tx_mux_tready(1);

  -------------------------------------------
  -- RX DEMUX
  -------------------------------------------

  axis_rx_tdest <= '1' when axis_rx_tuser(79 downto 64) = CHK_LISTENING_PORT else '0';

  inst_axis_demux_custom_rx : axis_demux_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TUSER_WIDTH          => 80,
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
      S_TKEEP    => axis_rx_tkeep,
      S_TDEST(0) => axis_rx_tdest,
      S_TREADY   => axis_rx_tready,
      M_TDATA    => axis_rx_demux_tdata,
      M_TVALID   => axis_rx_demux_tvalid,
      M_TLAST    => axis_rx_demux_tlast,
      M_TUSER    => axis_rx_demux_tuser,
      M_TKEEP    => axis_rx_demux_tkeep,
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
  axis_chk_tuser_full     <= axis_rx_demux_tuser(axis_tx_mux_tuser'high downto C_TUSER_WIDTH);
  axis_chk_tkeep          <= axis_rx_demux_tkeep(axis_tx_mux_tkeep'high downto (G_TDATA_WIDTH / 8));
  axis_rx_demux_tready(1) <= axis_chk_tready;

end rtl;

