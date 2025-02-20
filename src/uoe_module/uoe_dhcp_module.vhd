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
-- This design was created in collaboration for an academic project at Polytech Nantes by
--**************************************************************
-- Student        : BLO, lo.babacar@outlook.com
--**************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
----------------------------------
-- DHCP MODULE 
----------------------------------
--
-- This module insert DHCP Header and payload on TX frames or extract DHCP Header and payload on RX Frames
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_dhcp_module is
  generic(
    G_ACTIVE_RST        : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST         : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH       : positive  := 32     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                 : in  std_logic;
    RST                 : in  std_logic;
    -- control input signal
    INIT_DONE           : in  std_logic;
    DHCP_START          : in  std_logic;
    -- outputs signal for register
    DHCP_NETWORK_CONFIG : out t_dhcp_network_config;
    DHCP_STATUS         : out std_logic_vector(2 downto 0);
    -- From UDP Transport Layer
    S_TDATA             : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID            : in  std_logic;
    S_TLAST             : in  std_logic;
    S_TKEEP             : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TUSER             : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    S_TREADY            : out std_logic;

    -- To UDP Transport Layer
    M_TDATA             : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID            : out std_logic;
    M_TLAST             : out std_logic;
    M_TKEEP             : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TUSER             : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    M_TREADY            : in  std_logic

    -- signification of status value
    -- if DHCP_STATUS(1 downto 0) = : 
    -- 0 --> dhcp configuration not started yet(IDLE mode)
    -- 1 --> dhcp configuration is in progress
    -- 2 --> dhcp configuration is failed(process will be restarted from DISCOVER)
    -- 3 --> dhcp configuration is succesfull (we are in bound)  
    -- if DHCP_STATUS(2) = 1 --> ducp_Rx_error  : there might be an error or the received pacquets is not destinated to the DHCP

  );
end uoe_dhcp_module;

architecture rtl of uoe_dhcp_module is


  -- DHCP Module TX
  component uoe_dhcp_module_tx is
    generic(
      G_ACTIVE_RST          : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive  := 32     -- Width of the data bus
    );
    port(
      -- Clocks and resets
      CLK                   : in  std_logic;
      RST                   : in  std_logic;
      INIT_DONE             : in  std_logic;
    
      DHCP_SEND_DISCOVER    : in  std_logic;
      DHCP_SEND_REQUEST     : in  std_logic;
      DHCP_STATE            : in  t_dhcp_state;
      DHCP_NETWORK_CONFIG   : in  t_dhcp_network_config;
      DHCP_XID              : in  std_logic_vector(31 downto 0);
      DHCP_MESSAGE_SENT     : out std_logic;

      -- To UDP Transport Layer
      M_TDATA               : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID              : out std_logic;
      M_TLAST               : out std_logic;
      M_TKEEP               : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TUSER               : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
      M_TREADY              : in  std_logic

    );
  end component uoe_dhcp_module_tx;

  -- DHCP Module RX
  component uoe_dhcp_module_rx is
    generic(
      G_ACTIVE_RST          : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive  := 32     -- Width of the data bus
    );
    port(
      -- Clocks and resets
      CLK                   : in  std_logic;
      RST                   : in  std_logic;
      INIT_DONE             : in  std_logic;

      DHCP_XID              : in  std_logic_vector(31 downto 0);
      DHCP_STATE            : in  t_dhcp_state;
      DHCP_NETWORK_CONFIG   : out t_dhcp_network_config;
      DHCP_OFFER_SEL        : out std_logic;
      DHCP_ACK              : out std_logic;
      DHCP_NACK             : out std_logic;
      DHCP_RX_ERROR         : out std_logic;
      
      -- From UDP Transport Layer
      S_TDATA               : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID              : in  std_logic;
      S_TLAST               : in  std_logic;
      S_TKEEP               : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TUSER               : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
      S_TREADY              : out std_logic

    );
  end component uoe_dhcp_module_rx;


  --  DHCP Module controller

  component uoe_dhcp_module_controller is

    generic(
      G_ACTIVE_RST          : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive  := 32     -- Width of the data bus
    );
    port (
      -- Clocks and resets
      CLK                   : in  std_logic;
      RST                   : in  std_logic;
      INIT_DONE             : in  std_logic;
      DHCP_START            : in  std_logic;

      DHCP_MESSAGE_SENT     : in  std_logic;
      DHCP_OFFER_SEL        : in  std_logic;
      DHCP_ACK              : in  std_logic;
      DHCP_NACK             : in  std_logic;

      DHCP_SEND_DISCOVER    : out std_logic;
      DHCP_SEND_REQUEST     : out std_logic;
      DHCP_XID              : out std_logic_vector(31 downto 0);
      DHCP_STATE            : out t_dhcp_state;
      DHCP_STATUS           : out std_logic_vector(1 downto 0)
    );
  end component uoe_dhcp_module_controller;

  -------------------------------
  -- Signals declaration
  -------------------------------

  signal dhcp_message_sent   : std_logic;
  signal dhcp_offer_selected : std_logic;
  signal dhcp_acknowledge    : std_logic;
  signal dhcp_n_acknowledge  : std_logic;
  signal dhcp_send_discover  : std_logic;
  signal dhcp_send_request   : std_logic;
  signal dhcp_xid            : std_logic_vector(31 downto 0);
  signal dhcp_state          : t_dhcp_state;
  signal network_config      : t_dhcp_network_config;
begin

  -- output assignment
  DHCP_NETWORK_CONFIG        <= network_config;

  -- Instance ctrl
  inst_uoe_dhcp_module_ctrl : uoe_dhcp_module_controller
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      INIT_DONE             => INIT_DONE,
      DHCP_START            => DHCP_START,

      DHCP_MESSAGE_SENT     => dhcp_message_sent,
      DHCP_OFFER_SEL        => dhcp_offer_selected,

      DHCP_ACK              => dhcp_acknowledge,
      DHCP_NACK             => dhcp_n_acknowledge,

      DHCP_SEND_DISCOVER    => dhcp_send_discover,
      DHCP_SEND_REQUEST     => dhcp_send_request,
      DHCP_XID              => dhcp_xid,
      DHCP_STATE            => dhcp_state, 
      DHCP_STATUS           => DHCP_STATUS(1 downto 0)
    );

  -- Instance TX
  inst_uoe_dhcp_module_tx : uoe_dhcp_module_tx
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      INIT_DONE             => INIT_DONE,

      DHCP_SEND_DISCOVER    => dhcp_send_discover,
      DHCP_SEND_REQUEST     => dhcp_send_request,
      DHCP_STATE            => dhcp_state,
      DHCP_NETWORK_CONFIG   => network_config,
      DHCP_XID              => dhcp_xid,

      DHCP_MESSAGE_SENT     => dhcp_message_sent,
      -- To UDP Transport Layer
      M_TDATA               => M_TDATA,
      M_TVALID              => M_TVALID,
      M_TLAST               => M_TLAST,
      M_TKEEP               => M_TKEEP,
      M_TUSER               => M_TUSER,
      M_TREADY              => M_TREADY

    );
  -- Instance Rx
  inst_uoe_dhcp_module_rx : uoe_dhcp_module_rx
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      INIT_DONE             => INIT_DONE,

      DHCP_XID              => dhcp_xid,
      DHCP_STATE            => dhcp_state,
      DHCP_NETWORK_CONFIG   => network_config,
      DHCP_OFFER_SEL        => dhcp_offer_selected,
      DHCP_ACK              => dhcp_acknowledge,
      DHCP_NACK             => dhcp_n_acknowledge,
      DHCP_RX_ERROR         => DHCP_STATUS(2),
      -- From UDP Transport Layer
      S_TDATA               => S_TDATA,
      S_TVALID              => S_TVALID,
      S_TLAST               => S_TLAST,
      S_TKEEP               => S_TKEEP,
      S_TUSER               => S_TUSER,
      S_TREADY              => S_TREADY
    );
end rtl;
