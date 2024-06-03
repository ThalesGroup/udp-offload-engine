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
-- TRANSPORT LAYER
----------------------------------------------------
-- This module integrates the transport layer of the stack
--
-- Supported protocol :
-- - UDP Protocol
----------------------------------------------------

entity uoe_transport_layer is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                  : in  std_logic;
    RST                  : in  std_logic;
    -- From Internet Layer
    S_INTERNET_RX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_INTERNET_RX_TVALID : in  std_logic;
    S_INTERNET_RX_TLAST  : in  std_logic;
    S_INTERNET_RX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_INTERNET_RX_TID    : in  std_logic_vector(7 downto 0); -- Protocol UDP/TCP  --@suppress : provision / At the moment, transport layer implement only UDP Protocol
    S_INTERNET_RX_TUSER  : in  std_logic_vector(31 downto 0); -- Sender IP Address
    S_INTERNET_RX_TREADY : out std_logic;
    -- To Internet Layer
    M_INTERNET_TX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_INTERNET_TX_TVALID : out std_logic;
    M_INTERNET_TX_TLAST  : out std_logic;
    M_INTERNET_TX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_INTERNET_TX_TID    : out std_logic_vector(7 downto 0); -- Protocol UDP/TCP
    M_INTERNET_TX_TUSER  : out std_logic_vector(47 downto 0); -- 31:0 -> Target IP addr, 47:32 -> Size of transport datagram
    M_INTERNET_TX_TREADY : in  std_logic;
    -- From External interface
    S_UDP_TX_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_UDP_TX_TVALID      : in  std_logic;
    S_UDP_TX_TLAST       : in  std_logic;
    S_UDP_TX_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_UDP_TX_TUSER       : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of transport datagram, 31:0 -> Dest IP addr
    S_UDP_TX_TREADY      : out std_logic;
    -- To External interface
    M_UDP_RX_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_UDP_RX_TVALID      : out std_logic;
    M_UDP_RX_TLAST       : out std_logic;
    M_UDP_RX_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_UDP_RX_TUSER       : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of transport datagram, 31:0 -> Src IP addr
    M_UDP_RX_TREADY      : in  std_logic;
    -- Registers
    INIT_DONE            : in  std_logic
  );
end uoe_transport_layer;

architecture rtl of uoe_transport_layer is

  -- UDP Protocol management
  component uoe_udp_module is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK         : in  std_logic;
      RST         : in  std_logic;
      INIT_DONE   : in  std_logic;
      S_TX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TX_TVALID : in  std_logic;
      S_TX_TLAST  : in  std_logic;
      S_TX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TX_TUSER  : in  std_logic_vector(79 downto 0);
      S_TX_TREADY : out std_logic;
      M_TX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TX_TVALID : out std_logic;
      M_TX_TLAST  : out std_logic;
      M_TX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TX_TID    : out std_logic_vector(7 downto 0);
      M_TX_TUSER  : out std_logic_vector(47 downto 0);
      M_TX_TREADY : in  std_logic;
      S_RX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_RX_TVALID : in  std_logic;
      S_RX_TLAST  : in  std_logic;
      S_RX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_RX_TUSER  : in  std_logic_vector(31 downto 0);
      S_RX_TREADY : out std_logic;
      M_RX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_RX_TVALID : out std_logic;
      M_RX_TLAST  : out std_logic;
      M_RX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RX_TUSER  : out std_logic_vector(79 downto 0);
      M_RX_TREADY : in  std_logic
    );
  end component uoe_udp_module;

begin

  inst_uoe_udp_module : uoe_udp_module
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK         => CLK,
      RST         => RST,
      INIT_DONE   => INIT_DONE,
      S_TX_TDATA  => S_UDP_TX_TDATA,
      S_TX_TVALID => S_UDP_TX_TVALID,
      S_TX_TLAST  => S_UDP_TX_TLAST,
      S_TX_TKEEP  => S_UDP_TX_TKEEP,
      S_TX_TUSER  => S_UDP_TX_TUSER,
      S_TX_TREADY => S_UDP_TX_TREADY,
      M_TX_TDATA  => M_INTERNET_TX_TDATA,
      M_TX_TVALID => M_INTERNET_TX_TVALID,
      M_TX_TLAST  => M_INTERNET_TX_TLAST,
      M_TX_TKEEP  => M_INTERNET_TX_TKEEP,
      M_TX_TID    => M_INTERNET_TX_TID,
      M_TX_TUSER  => M_INTERNET_TX_TUSER,
      M_TX_TREADY => M_INTERNET_TX_TREADY,
      S_RX_TDATA  => S_INTERNET_RX_TDATA,
      S_RX_TVALID => S_INTERNET_RX_TVALID,
      S_RX_TLAST  => S_INTERNET_RX_TLAST,
      S_RX_TKEEP  => S_INTERNET_RX_TKEEP,
      S_RX_TUSER  => S_INTERNET_RX_TUSER,
      S_RX_TREADY => S_INTERNET_RX_TREADY,
      M_RX_TDATA  => M_UDP_RX_TDATA,
      M_RX_TVALID => M_UDP_RX_TVALID,
      M_RX_TLAST  => M_UDP_RX_TLAST,
      M_RX_TKEEP  => M_UDP_RX_TKEEP,
      M_RX_TUSER  => M_UDP_RX_TUSER,
      M_RX_TREADY => M_UDP_RX_TREADY
    );

end rtl;
