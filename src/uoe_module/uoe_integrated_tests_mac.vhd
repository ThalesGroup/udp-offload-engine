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
use common.axis_utils_pkg.axis_fifo;

use common.cdc_utils_pkg.cdc_bit_sync;

--------------------------------------
-- INTEGRATED TESTS MAC
--------------------------------------
--
-- This module integrated some tests tools to be used on the MAC interface.
-- * A loopback path with a fifo
--
--------------------------------------

entity uoe_integrated_tests_mac is
  generic(
    G_ACTIVE_RST      : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST       : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH     : positive  := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_FIFO_ADDR_WIDTH : positive  := 4  -- FIFO address width (depth is 2**ADDR_WIDTH)
  );
  port(
    -- Clock domain of MAC in rx
    CLK_RX           : in  std_logic;
    RST_RX           : in  std_logic;
    -- Clock domain of MAC in tx
    CLK_TX           : in  std_logic;
    RST_TX           : in  std_logic;
    -- LOOPBACK
    LOOPBACK_EN      : in  std_logic;
    -- RX Path PHY => Core
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
    -- TX Path Core => PHY
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
end uoe_integrated_tests_mac;

architecture rtl of uoe_integrated_tests_mac is

  ------------------------------
  -- Components declaration
  ------------------------------

  signal loopback_en_tx : std_logic;
  signal loopback_en_rx : std_logic;

  -- Interface Fifo MAC
  signal axis_mac_fifo_tx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_fifo_tx_tvalid : std_logic;
  signal axis_mac_fifo_tx_tlast  : std_logic;
  signal axis_mac_fifo_tx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_mac_fifo_tx_tuser  : std_logic;

  signal axis_mac_fifo_rx_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_mac_fifo_rx_tvalid : std_logic;
  signal axis_mac_fifo_rx_tlast  : std_logic;
  signal axis_mac_fifo_rx_tkeep  : std_logic_vector(((G_TDATA_WIDTH / 8) - 1) downto 0);
  signal axis_mac_fifo_rx_tuser  : std_logic;

begin

  -- Resync Loopback ctrl on TX clock
  inst_cdc_bit_sync_tx : cdc_bit_sync
    generic map(
      G_NB_STAGE   => 2,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_RST_VALUE  => '0'
    )
    port map(
      DATA_ASYNC => LOOPBACK_EN,
      CLK        => CLK_TX,
      RST        => RST_TX,
      DATA_SYNC  => loopback_en_tx
    );

  M_PHY_TX_TDATA  <= S_CORE_TX_TDATA when loopback_en_tx /= '1' else (others => '0');
  M_PHY_TX_TVALID <= S_CORE_TX_TVALID when loopback_en_tx /= '1' else '0';
  M_PHY_TX_TLAST  <= S_CORE_TX_TLAST when loopback_en_tx /= '1' else '0';
  M_PHY_TX_TKEEP  <= S_CORE_TX_TKEEP when loopback_en_tx /= '1' else (others => '0');
  M_PHY_TX_TUSER  <= S_CORE_TX_TUSER when loopback_en_tx /= '1' else '0';

  S_CORE_TX_TREADY <= M_PHY_TX_TREADY when loopback_en_tx /= '1' else '1';

  axis_mac_fifo_tx_tdata  <= S_CORE_TX_TDATA when loopback_en_tx = '1' else (others => '0');
  axis_mac_fifo_tx_tvalid <= S_CORE_TX_TVALID when loopback_en_tx = '1' else '0';
  axis_mac_fifo_tx_tlast  <= S_CORE_TX_TLAST when loopback_en_tx = '1' else '0';
  axis_mac_fifo_tx_tkeep  <= S_CORE_TX_TKEEP when loopback_en_tx = '1' else (others => '0');
  axis_mac_fifo_tx_tuser  <= S_CORE_TX_TUSER when loopback_en_tx = '1' else '0';

  -- Axis fifo loopback MAC
  inst_axis_fifo_mac_tx_rx : axis_fifo
    generic map(
      G_COMMON_CLK  => false,
      G_ADDR_WIDTH  => G_FIFO_ADDR_WIDTH,
      G_TDATA_WIDTH => G_TDATA_WIDTH,
      G_TUSER_WIDTH => 1,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST
    )
    port map(
      S_CLK      => CLK_TX,
      S_RST      => RST_TX,
      S_TDATA    => axis_mac_fifo_tx_tdata,
      S_TVALID   => axis_mac_fifo_tx_tvalid,
      S_TLAST    => axis_mac_fifo_tx_tlast,
      S_TKEEP    => axis_mac_fifo_tx_tkeep,
      S_TUSER(0) => axis_mac_fifo_tx_tuser,
      S_TREADY   => open,
      M_CLK      => CLK_RX,
      M_TDATA    => axis_mac_fifo_rx_tdata,
      M_TVALID   => axis_mac_fifo_rx_tvalid,
      M_TLAST    => axis_mac_fifo_rx_tlast,
      M_TKEEP    => axis_mac_fifo_rx_tkeep,
      M_TUSER(0) => axis_mac_fifo_rx_tuser,
      M_TREADY   => '1'
    );

  -- Resync Loopback ctrl on RX clock
  inst_cdc_bit_sync_rx : cdc_bit_sync
    generic map(
      G_NB_STAGE   => 2,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_RST_VALUE  => '0'
    )
    port map(
      DATA_ASYNC => LOOPBACK_EN,
      CLK        => CLK_RX,
      RST        => RST_RX,
      DATA_SYNC  => loopback_en_rx
    );

  M_CORE_RX_TDATA  <= axis_mac_fifo_rx_tdata when loopback_en_rx = '1' else S_PHY_RX_TDATA;
  M_CORE_RX_TVALID <= axis_mac_fifo_rx_tvalid when loopback_en_rx = '1' else S_PHY_RX_TVALID;
  M_CORE_RX_TLAST  <= axis_mac_fifo_rx_tlast when loopback_en_rx = '1' else S_PHY_RX_TLAST;
  M_CORE_RX_TKEEP  <= axis_mac_fifo_rx_tkeep when loopback_en_rx = '1' else S_PHY_RX_TKEEP;
  M_CORE_RX_TUSER  <= axis_mac_fifo_rx_tuser when loopback_en_rx = '1' else S_PHY_RX_TUSER;

end rtl;

