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
-- INTERNET LAYER
----------------------------------------------------
-- This module integrates the internet layer of the stack
--
-- Supported protocol :
-- - IPv4 Protocol
----------------------------------------------------

entity uoe_internet_layer is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                       : in  std_logic;
    RST                       : in  std_logic;
    -- From Link Layer
    S_LINK_RX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_LINK_RX_TVALID          : in  std_logic;
    S_LINK_RX_TLAST           : in  std_logic;
    S_LINK_RX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_LINK_RX_TID             : in  std_logic_vector(15 downto 0); -- Protocol --@suppress : provision / At the moment, Internet layer implement only IPV4 Protocol 
    S_LINK_RX_TREADY          : out std_logic;
    -- To Link Layer 
    M_LINK_TX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_LINK_TX_TVALID          : out std_logic;
    M_LINK_TX_TLAST           : out std_logic;
    M_LINK_TX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_LINK_TX_TID             : out std_logic_vector(15 downto 0); -- Ethertype value
    M_LINK_TX_TUSER           : out std_logic_vector(31 downto 0); -- Target IP Address
    M_LINK_TX_TREADY          : in  std_logic;
    -- From Transport Layer
    S_TRANSPORT_TX_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TRANSPORT_TX_TVALID     : in  std_logic;
    S_TRANSPORT_TX_TLAST      : in  std_logic;
    S_TRANSPORT_TX_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TRANSPORT_TX_TID        : in  std_logic_vector(7 downto 0); -- Protocol UDP/TCP
    S_TRANSPORT_TX_TUSER      : in  std_logic_vector(47 downto 0); -- 31:0 -> Target IP addr, 47:32 -> Size of transport datagram
    S_TRANSPORT_TX_TREADY     : out std_logic;
    -- To Transport Layer
    M_TRANSPORT_RX_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TRANSPORT_RX_TVALID     : out std_logic;
    M_TRANSPORT_RX_TLAST      : out std_logic;
    M_TRANSPORT_RX_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TRANSPORT_RX_TID        : out std_logic_vector(7 downto 0); -- Protocol UDP/TCP
    M_TRANSPORT_RX_TUSER      : out std_logic_vector(31 downto 0); -- Sender IP Address
    M_TRANSPORT_RX_TREADY     : in  std_logic;
    -- Registers interface
    INIT_DONE                 : in  std_logic;
    TTL                       : in  std_logic_vector(7 downto 0);
    LOCAL_IP_ADDR             : in  std_logic_vector(31 downto 0);
    IPV4_RX_FRAG_OFFSET_ERROR : out std_logic
  );
end uoe_internet_layer;

architecture rtl of uoe_internet_layer is

  -----------------------------------
  -- Components declaration
  -----------------------------------

  component uoe_ipv4_module is
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
  end component uoe_ipv4_module;

begin

  -- IPV4 Module
  inst_uoe_ipv4_module : uoe_ipv4_module
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK                       => CLK,
      RST                       => RST,
      S_LINK_RX_TDATA           => S_LINK_RX_TDATA,
      S_LINK_RX_TVALID          => S_LINK_RX_TVALID,
      S_LINK_RX_TLAST           => S_LINK_RX_TLAST,
      S_LINK_RX_TKEEP           => S_LINK_RX_TKEEP,
      S_LINK_RX_TREADY          => S_LINK_RX_TREADY,
      M_LINK_TX_TDATA           => M_LINK_TX_TDATA,
      M_LINK_TX_TVALID          => M_LINK_TX_TVALID,
      M_LINK_TX_TLAST           => M_LINK_TX_TLAST,
      M_LINK_TX_TKEEP           => M_LINK_TX_TKEEP,
      M_LINK_TX_TID             => M_LINK_TX_TID,
      M_LINK_TX_TUSER           => M_LINK_TX_TUSER,
      M_LINK_TX_TREADY          => M_LINK_TX_TREADY,
      S_TRANSPORT_TX_TDATA      => S_TRANSPORT_TX_TDATA,
      S_TRANSPORT_TX_TVALID     => S_TRANSPORT_TX_TVALID,
      S_TRANSPORT_TX_TLAST      => S_TRANSPORT_TX_TLAST,
      S_TRANSPORT_TX_TKEEP      => S_TRANSPORT_TX_TKEEP,
      S_TRANSPORT_TX_TID        => S_TRANSPORT_TX_TID,
      S_TRANSPORT_TX_TUSER      => S_TRANSPORT_TX_TUSER,
      S_TRANSPORT_TX_TREADY     => S_TRANSPORT_TX_TREADY,
      M_TRANSPORT_RX_TDATA      => M_TRANSPORT_RX_TDATA,
      M_TRANSPORT_RX_TVALID     => M_TRANSPORT_RX_TVALID,
      M_TRANSPORT_RX_TLAST      => M_TRANSPORT_RX_TLAST,
      M_TRANSPORT_RX_TKEEP      => M_TRANSPORT_RX_TKEEP,
      M_TRANSPORT_RX_TID        => M_TRANSPORT_RX_TID,
      M_TRANSPORT_RX_TUSER      => M_TRANSPORT_RX_TUSER,
      M_TRANSPORT_RX_TREADY     => M_TRANSPORT_RX_TREADY,
      INIT_DONE                 => INIT_DONE,
      TTL                       => TTL,
      LOCAL_IP_ADDR             => LOCAL_IP_ADDR,
      IPV4_RX_FRAG_OFFSET_ERROR => IPV4_RX_FRAG_OFFSET_ERROR
    );

end rtl;

