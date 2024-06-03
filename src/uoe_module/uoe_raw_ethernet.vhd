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

-------------------------------------------------
-- RAW ETHERNET
-------------------------------------------------
--
-- This module insert MAC Header on TX frames or extract MAC Header on RX Frames for frame using the RAW Protocol 
--
----------------------------------------------------

entity uoe_raw_ethernet is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 64
  );
  port(
    -- Clocks and resets
    CLK            : in  std_logic;
    RST            : in  std_logic;
    INIT_DONE      : in  std_logic;
    -------- TX Flow --------
    -- From internet layer
    S_TX_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TX_TVALID    : in  std_logic;
    S_TX_TLAST     : in  std_logic;
    S_TX_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TX_TID       : in  std_logic_vector(15 downto 0); -- Ethertype = Frame Size
    S_TX_TREADY    : out std_logic;
    -- To Ethernet frame router
    M_TX_TDATA     : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TX_TVALID    : out std_logic;
    M_TX_TLAST     : out std_logic;
    M_TX_TKEEP     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TX_TREADY    : in  std_logic;
    -------- RX Flow --------
    -- From Ethernet frame router
    S_RX_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_RX_TVALID    : in  std_logic;
    S_RX_TLAST     : in  std_logic;
    S_RX_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_RX_TREADY    : out std_logic;
    -- To internet layer
    M_RX_TDATA     : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_RX_TVALID    : out std_logic;
    M_RX_TLAST     : out std_logic;
    M_RX_TKEEP     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_RX_TID       : out std_logic_vector(15 downto 0); -- Ethertype = Frame Size
    M_RX_TREADY    : in  std_logic;
    -- Registers interface
    DEST_MAC_ADDR  : in  std_logic_vector(47 downto 0); -- Destination MAC
    LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0) -- Source MAC
  );
end uoe_raw_ethernet;

architecture rtl of uoe_raw_ethernet is

  component uoe_raw_ethernet_tx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : positive  := 64
    );
    port(
      CLK            : in  std_logic;
      RST            : in  std_logic;
      INIT_DONE      : in  std_logic;
      S_TDATA        : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID       : in  std_logic;
      S_TLAST        : in  std_logic;
      S_TKEEP        : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TID          : in  std_logic_vector(15 downto 0);
      S_TREADY       : out std_logic;
      M_TDATA        : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID       : out std_logic;
      M_TLAST        : out std_logic;
      M_TKEEP        : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY       : in  std_logic;
      DEST_MAC_ADDR  : in  std_logic_vector(47 downto 0);
      LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0)
    );
  end component uoe_raw_ethernet_tx;

  component uoe_raw_ethernet_rx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : positive  := 64
    );
    port(
      CLK      : in  std_logic;
      RST      : in  std_logic;
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY : out std_logic;
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(15 downto 0);
      M_TREADY : in  std_logic
    );
  end component uoe_raw_ethernet_rx;

begin

  -- TX Path
  inst_uoe_raw_ethernet_tx : uoe_raw_ethernet_tx
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK            => CLK,
      RST            => RST,
      INIT_DONE      => INIT_DONE,
      S_TDATA        => S_TX_TDATA,
      S_TVALID       => S_TX_TVALID,
      S_TLAST        => S_TX_TLAST,
      S_TKEEP        => S_TX_TKEEP,
      S_TID          => S_TX_TID,
      S_TREADY       => S_TX_TREADY,
      M_TDATA        => M_TX_TDATA,
      M_TVALID       => M_TX_TVALID,
      M_TLAST        => M_TX_TLAST,
      M_TKEEP        => M_TX_TKEEP,
      M_TREADY       => M_TX_TREADY,
      DEST_MAC_ADDR  => DEST_MAC_ADDR,
      LOCAL_MAC_ADDR => LOCAL_MAC_ADDR
    );

  -- RX Path
  inst_uoe_raw_ethernet_rx : uoe_raw_ethernet_rx
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_RX_TDATA,
      S_TVALID => S_RX_TVALID,
      S_TLAST  => S_RX_TLAST,
      S_TKEEP  => S_RX_TKEEP,
      S_TREADY => S_RX_TREADY,
      M_TDATA  => M_RX_TDATA,
      M_TVALID => M_RX_TVALID,
      M_TLAST  => M_RX_TLAST,
      M_TKEEP  => M_RX_TKEEP,
      M_TID    => M_RX_TID,
      M_TREADY => M_RX_TREADY
    );

end rtl;
