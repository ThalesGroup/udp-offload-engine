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

-------------------------------------------------
-- UDP MODULE
-------------------------------------------------
--
-- This module insert UDP Header on TX frames or extract UDP Header on RX Frames 
--
----------------------------------------------------

use work.uoe_module_pkg.all;

entity uoe_udp_module is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK         : in  std_logic;
    RST         : in  std_logic;
    INIT_DONE   : in  std_logic;
    -------- RX Path --------
    -- From External interface
    S_TX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TX_TVALID : in  std_logic;
    S_TX_TLAST  : in  std_logic;
    S_TX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TX_TUSER  : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    S_TX_TREADY : out std_logic;
    -- To Internet Layer
    M_TX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TX_TVALID : out std_logic;
    M_TX_TLAST  : out std_logic;
    M_TX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TX_TID    : out std_logic_vector(7 downto 0); -- Protocol UDP/TCP
    M_TX_TUSER  : out std_logic_vector(47 downto 0); -- 31:0 -> Target IP addr, 47:32 -> Size of transport datagram (Header + Payload)
    M_TX_TREADY : in  std_logic;
    -------- RX Path --------
    -- From Transport Layer
    S_RX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_RX_TVALID : in  std_logic;
    S_RX_TLAST  : in  std_logic;
    S_RX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_RX_TUSER  : in  std_logic_vector(31 downto 0); -- Sender IP Address
    S_RX_TREADY : out std_logic;
    -- To External interface
    M_RX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_RX_TVALID : out std_logic;
    M_RX_TLAST  : out std_logic;
    M_RX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_RX_TUSER  : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of transport datagram, 31:0 -> Src IP addr
    M_RX_TREADY : in  std_logic
  );
end uoe_udp_module;

architecture rtl of uoe_udp_module is
  
  -- UDP Module TX
  component uoe_udp_module_tx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK       : in  std_logic;
      RST       : in  std_logic;
      INIT_DONE : in  std_logic;
      S_TDATA   : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID  : in  std_logic;
      S_TLAST   : in  std_logic;
      S_TKEEP   : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TUSER   : in  std_logic_vector(79 downto 0);
      S_TREADY  : out std_logic;
      M_TDATA   : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID  : out std_logic;
      M_TLAST   : out std_logic;
      M_TKEEP   : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID     : out std_logic_vector(7 downto 0);
      M_TUSER   : out std_logic_vector(47 downto 0);
      M_TREADY  : in  std_logic
    );
  end component uoe_udp_module_tx;
  
  -- UDP Module RX
  component uoe_udp_module_rx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK      : in  std_logic;
      RST      : in  std_logic;
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TUSER  : in  std_logic_vector(31 downto 0);
      S_TREADY : out std_logic;
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TUSER  : out std_logic_vector(79 downto 0);
      M_TREADY : in  std_logic
    );
  end component uoe_udp_module_rx;
  
begin
  
  -- Instance TX
  inst_uoe_udp_module_tx : uoe_udp_module_tx
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK       => CLK,
      RST       => RST,
      INIT_DONE => INIT_DONE,
      S_TDATA   => S_TX_TDATA,
      S_TVALID  => S_TX_TVALID,
      S_TLAST   => S_TX_TLAST,
      S_TKEEP   => S_TX_TKEEP,
      S_TUSER   => S_TX_TUSER,
      S_TREADY  => S_TX_TREADY,
      M_TDATA   => M_TX_TDATA,
      M_TVALID  => M_TX_TVALID,
      M_TLAST   => M_TX_TLAST,
      M_TKEEP   => M_TX_TKEEP,
      M_TID     => M_TX_TID,
      M_TUSER   => M_TX_TUSER,
      M_TREADY  => M_TX_TREADY
    );
  
  -- Instance RX
  inst_uoe_udp_module_rx : uoe_udp_module_rx
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
      S_TUSER  => S_RX_TUSER,
      S_TREADY => S_RX_TREADY,
      M_TDATA  => M_RX_TDATA,
      M_TVALID => M_RX_TVALID,
      M_TLAST  => M_RX_TLAST,
      M_TKEEP  => M_RX_TKEEP,
      M_TUSER  => M_RX_TUSER,
      M_TREADY => M_RX_TREADY
    );
  
  
end rtl;

