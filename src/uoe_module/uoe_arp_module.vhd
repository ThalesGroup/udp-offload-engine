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
-- ARP MODULE
----------------------------------
--
-- This module contains all the blocks making up the ARP module
-- * ARP Controller
-- * ARP TX Protocol 
-- * ARP RX protocol
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_fifo;

entity uoe_arp_module is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_FREQ_KHZ    : integer   := 156250; -- System Frequency use to reference timeout
    G_TDATA_WIDTH : integer   := 64     -- Number of bits used along AXI datapath of UOE
  );
  port(
    -- Clock & reset
    CLK                           : in  std_logic;
    RST                           : in  std_logic;
    -- From MAC Shaping (ARP Table/Cache)
    S_IP_ADDR_TDATA               : in  std_logic_vector(31 downto 0);
    S_IP_ADDR_TVALID              : in  std_logic;
    S_IP_ADDR_TREADY              : out std_logic;
    -- To MAC Shaping (ARP Table/Cache)
    M_IP_MAC_ADDR_TDATA           : out std_logic_vector(79 downto 0); -- 79..32 => Targeted MAC, 31..0 => Targeted IP
    M_IP_MAC_ADDR_TVALID          : out std_logic;
    M_IP_MAC_ADDR_TUSER           : out std_logic_vector(0 downto 0); -- Validity of the IP/MAC couple
    M_IP_MAC_ADDR_TREADY          : in  std_logic;
    -- From Ethernet Frame router interface
    S_RX_TDATA                    : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
    S_RX_TVALID                   : in  std_logic;
    S_RX_TLAST                    : in  std_logic;
    S_RX_TKEEP                    : in  std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
    S_RX_TREADY                   : out std_logic;
    -- To Ethernet Frame router interface
    M_TX_TDATA                    : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
    M_TX_TVALID                   : out std_logic;
    M_TX_TLAST                    : out std_logic;
    M_TX_TKEEP                    : out std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
    M_TX_TREADY                   : in  std_logic;
    -- Registers
    INIT_DONE                     : in  std_logic; -- Initialization of parameters (LOCAL_IP_ADDR,...) is done
    LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0);
    LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
    ARP_TIMEOUT_MS                : in  std_logic_vector(11 downto 0); -- Max. time to wait an ARP answer before assert ARP_ERROR (in ms)
    ARP_TRYINGS                   : in  std_logic_vector(3 downto 0); -- Number of Query Retries
    ARP_GRATUITOUS_REQ            : in  std_logic; -- User request to g�n�rate a gratuitous ARP (ex : following a (re)connection)
    ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0); -- Filter mode selection
    ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
    -- Status
    ARP_RX_FIFO_OVERFLOW          : out std_logic; -- Fifo overflow
    ARP_IP_CONFLICT               : out std_logic; -- Detect an IP Conflict
    ARP_MAC_CONFLICT              : out std_logic; -- Detect an MAC Conflict
    ARP_INIT_DONE                 : out std_logic; -- Status of ARP initialization
    ARP_ERROR                     : out std_logic -- Indicates no response to a request
  );
end uoe_arp_module;

architecture rtl of uoe_arp_module is

  --------------------------
  -- Components declaration
  --------------------------

  -- ARP TX Protocol
  component uoe_arp_tx_protocol is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK            : in  std_logic;
      RST            : in  std_logic;
      M_TDATA        : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
      M_TVALID       : out std_logic;
      M_TLAST        : out std_logic;
      M_TKEEP        : out std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
      M_TREADY       : in  std_logic;
      S_CTRL_TDATA   : in  std_logic_vector(79 downto 0);
      S_CTRL_TVALID  : in  std_logic;
      S_CTRL_TUSER   : in  std_logic_vector(0 downto 0);
      S_CTRL_TREADY  : out std_logic;
      LOCAL_IP_ADDR  : in  std_logic_vector(31 downto 0);
      LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0)
    );
  end component uoe_arp_tx_protocol;

  -- ARP RX Protocol
  component uoe_arp_rx_protocol is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK                           : in  std_logic;
      RST                           : in  std_logic;
      S_TDATA                       : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
      S_TVALID                      : in  std_logic;
      S_TLAST                       : in  std_logic;
      S_TKEEP                       : in  std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
      S_TREADY                      : out std_logic;
      M_TDATA                       : out std_logic_vector(79 downto 0);
      M_TVALID                      : out std_logic;
      M_TUSER                       : out std_logic_vector(0 downto 0);
      LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0);
      LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
      ARP_IP_CONFLICT               : out std_logic;
      ARP_MAC_CONFLICT              : out std_logic;
      ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0);
      ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
      ARP_SELF_ID_DONE              : in  std_logic
    );
  end component uoe_arp_rx_protocol;

  -- ARP Controller
  component uoe_arp_controller is
    generic(
      G_ACTIVE_RST : std_logic := '0';
      G_ASYNC_RST  : boolean   := true;
      G_FREQ_KHZ   : integer   := 156250
    );
    port(
      CLK                     : in  std_logic;
      RST                     : in  std_logic;
      S_IP_ADDR_TDATA         : in  std_logic_vector(31 downto 0);
      S_IP_ADDR_TVALID        : in  std_logic;
      S_IP_ADDR_TREADY        : out std_logic;
      M_IP_MAC_ADDR_TDATA     : out std_logic_vector(79 downto 0);
      M_IP_MAC_ADDR_TVALID    : out std_logic;
      M_IP_MAC_ADDR_TUSER     : out std_logic_vector(0 downto 0);
      M_IP_MAC_ADDR_TREADY    : in  std_logic;
      M_ARP_TX_TDATA          : out std_logic_vector(79 downto 0);
      M_ARP_TX_TVALID         : out std_logic;
      M_ARP_TX_TUSER          : out std_logic_vector(0 downto 0);
      M_ARP_TX_TREADY         : in  std_logic;
      S_ARP_RX_TDATA          : in  std_logic_vector(79 downto 0);
      S_ARP_RX_TVALID         : in  std_logic;
      S_ARP_RX_TUSER          : in  std_logic_vector(0 downto 0);
      S_ARP_RX_TREADY         : out std_logic;
      INIT_DONE               : in  std_logic;
      LOCAL_IP_ADDR           : in  std_logic_vector(31 downto 0);
      ARP_TIMEOUT_MS          : in  std_logic_vector(11 downto 0);
      ARP_TRYINGS             : in  std_logic_vector(3 downto 0);
      ARP_GRATUITOUS_REQ      : in  std_logic;
      ARP_RX_TARGET_IP_FILTER : in  std_logic_vector(1 downto 0);
      ARP_PROBE_DONE          : out std_logic;
      ARP_IP_CONFLICT         : out std_logic;
      ARP_ERROR               : out std_logic
    );
  end component uoe_arp_controller;

  --------------------------
  -- Signals declaration
  --------------------------

  signal axis_ctrl_to_tx_tdata  : std_logic_vector(79 downto 0);
  signal axis_ctrl_to_tx_tvalid : std_logic;
  signal axis_ctrl_to_tx_tuser  : std_logic_vector(0 downto 0); -- C_ARP_REQUEST (0) or C_ARP_REPLY (1)
  signal axis_ctrl_to_tx_tready : std_logic;

  signal axis_rx_to_fifo_tdata  : std_logic_vector(79 downto 0);
  signal axis_rx_to_fifo_tvalid : std_logic;
  signal axis_rx_to_fifo_tuser  : std_logic_vector(0 downto 0); -- C_ARP_REQUEST (0) or C_ARP_REPLY (1)
  signal axis_rx_to_fifo_tready : std_logic;

  signal axis_fifo_to_ctrl_tdata  : std_logic_vector(79 downto 0);
  signal axis_fifo_to_ctrl_tvalid : std_logic;
  signal axis_fifo_to_ctrl_tuser  : std_logic_vector(0 downto 0); -- C_ARP_REQUEST (0) or C_ARP_REPLY (1)
  signal axis_fifo_to_ctrl_tready : std_logic;

  signal axis_fifo_to_ctrl_reg_tdata  : std_logic_vector(79 downto 0);
  signal axis_fifo_to_ctrl_reg_tvalid : std_logic;
  signal axis_fifo_to_ctrl_reg_tuser  : std_logic_vector(0 downto 0); -- C_ARP_REQUEST (0) or C_ARP_REPLY (1)
  signal axis_fifo_to_ctrl_reg_tready : std_logic;

  signal arp_init_done_i      : std_logic;
  signal arp_ip_conflict_rx   : std_logic;
  signal arp_ip_conflict_ctrl : std_logic;

begin

  -- Handle the ARP protocol in transmission
  inst_uoe_arp_tx_protocol : uoe_arp_tx_protocol
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK            => CLK,
      RST            => RST,
      M_TDATA        => M_TX_TDATA,
      M_TVALID       => M_TX_TVALID,
      M_TLAST        => M_TX_TLAST,
      M_TKEEP        => M_TX_TKEEP,
      M_TREADY       => M_TX_TREADY,
      S_CTRL_TDATA   => axis_ctrl_to_tx_tdata,
      S_CTRL_TVALID  => axis_ctrl_to_tx_tvalid,
      S_CTRL_TUSER   => axis_ctrl_to_tx_tuser,
      S_CTRL_TREADY  => axis_ctrl_to_tx_tready,
      LOCAL_IP_ADDR  => LOCAL_IP_ADDR,
      LOCAL_MAC_ADDR => LOCAL_MAC_ADDR
    );

  -- Handle the ARP protocol in reception
  inst_uoe_arp_rx_protocol : uoe_arp_rx_protocol
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK                           => CLK,
      RST                           => RST,
      S_TDATA                       => S_RX_TDATA,
      S_TVALID                      => S_RX_TVALID,
      S_TLAST                       => S_RX_TLAST,
      S_TKEEP                       => S_RX_TKEEP,
      S_TREADY                      => S_RX_TREADY,
      M_TDATA                       => axis_rx_to_fifo_tdata,
      M_TVALID                      => axis_rx_to_fifo_tvalid,
      M_TUSER                       => axis_rx_to_fifo_tuser,
      LOCAL_IP_ADDR                 => LOCAL_IP_ADDR,
      LOCAL_MAC_ADDR                => LOCAL_MAC_ADDR,
      ARP_IP_CONFLICT               => arp_ip_conflict_rx,
      ARP_MAC_CONFLICT              => ARP_MAC_CONFLICT,
      ARP_RX_TARGET_IP_FILTER       => ARP_RX_TARGET_IP_FILTER,
      ARP_RX_TEST_LOCAL_IP_CONFLICT => ARP_RX_TEST_LOCAL_IP_CONFLICT,
      ARP_SELF_ID_DONE              => arp_init_done_i
    );

  -- Fifo used to bufferize RX Request/Reply before threatment
  inst_axis_fifo : axis_fifo
    generic map(
      G_COMMON_CLK  => true,
      G_ADDR_WIDTH  => 2,
      G_TDATA_WIDTH => 80,
      G_TUSER_WIDTH => 1,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST
    )
    port map(
      S_CLK    => CLK,
      S_RST    => RST,
      S_TDATA  => axis_rx_to_fifo_tdata,
      S_TVALID => axis_rx_to_fifo_tvalid,
      S_TUSER  => axis_rx_to_fifo_tuser,
      S_TREADY => axis_rx_to_fifo_tready,
      M_CLK    => CLK,
      M_TDATA  => axis_fifo_to_ctrl_tdata,
      M_TVALID => axis_fifo_to_ctrl_tvalid,
      M_TUSER  => axis_fifo_to_ctrl_tuser,
      M_TREADY => axis_fifo_to_ctrl_tready
    );

  ARP_RX_FIFO_OVERFLOW <= axis_rx_to_fifo_tvalid and (not axis_rx_to_fifo_tready);

  -- Insert register to improve timings
  inst_axis_register_fifo : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => 80,
      G_TUSER_WIDTH  => 1,
      G_REG_FORWARD  => true,
      G_REG_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => axis_fifo_to_ctrl_tdata,
      S_TVALID => axis_fifo_to_ctrl_tvalid,
      S_TUSER  => axis_fifo_to_ctrl_tuser,
      S_TREADY => axis_fifo_to_ctrl_tready,
      M_TDATA  => axis_fifo_to_ctrl_reg_tdata,
      M_TVALID => axis_fifo_to_ctrl_reg_tvalid,
      M_TUSER  => axis_fifo_to_ctrl_reg_tuser,
      M_TREADY => axis_fifo_to_ctrl_reg_tready
    );

  -- ARP Controller 
  inst_uoe_arp_controller : uoe_arp_controller
    generic map(
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_FREQ_KHZ   => G_FREQ_KHZ
    )
    port map(
      CLK                     => CLK,
      RST                     => RST,
      S_IP_ADDR_TDATA         => S_IP_ADDR_TDATA,
      S_IP_ADDR_TVALID        => S_IP_ADDR_TVALID,
      S_IP_ADDR_TREADY        => S_IP_ADDR_TREADY,
      M_IP_MAC_ADDR_TDATA     => M_IP_MAC_ADDR_TDATA,
      M_IP_MAC_ADDR_TVALID    => M_IP_MAC_ADDR_TVALID,
      M_IP_MAC_ADDR_TUSER     => M_IP_MAC_ADDR_TUSER,
      M_IP_MAC_ADDR_TREADY    => M_IP_MAC_ADDR_TREADY,
      M_ARP_TX_TDATA          => axis_ctrl_to_tx_tdata,
      M_ARP_TX_TVALID         => axis_ctrl_to_tx_tvalid,
      M_ARP_TX_TUSER          => axis_ctrl_to_tx_tuser,
      M_ARP_TX_TREADY         => axis_ctrl_to_tx_tready,
      S_ARP_RX_TDATA          => axis_fifo_to_ctrl_reg_tdata,
      S_ARP_RX_TVALID         => axis_fifo_to_ctrl_reg_tvalid,
      S_ARP_RX_TUSER          => axis_fifo_to_ctrl_reg_tuser,
      S_ARP_RX_TREADY         => axis_fifo_to_ctrl_reg_tready,
      INIT_DONE               => INIT_DONE,
      LOCAL_IP_ADDR           => LOCAL_IP_ADDR,
      ARP_TIMEOUT_MS          => ARP_TIMEOUT_MS,
      ARP_TRYINGS             => ARP_TRYINGS,
      ARP_GRATUITOUS_REQ      => ARP_GRATUITOUS_REQ,
      ARP_RX_TARGET_IP_FILTER => ARP_RX_TARGET_IP_FILTER,
      ARP_PROBE_DONE          => arp_init_done_i,
      ARP_IP_CONFLICT         => arp_ip_conflict_ctrl,
      ARP_ERROR               => ARP_ERROR
    );

  -- assignment
  ARP_IP_CONFLICT <= arp_ip_conflict_ctrl or arp_ip_conflict_rx;
  ARP_INIT_DONE   <= arp_init_done_i; -- @suppress Case is not matching but rule is OK

end rtl;

