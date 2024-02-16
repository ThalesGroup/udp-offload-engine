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

----------------------------------------------------
-- INTERNET LAYER
----------------------------------------------------
-- This module integrates the internet layer of the stack
--
-- Supported protocol :
-- - IPv4 Protocol
-- - ICMP echo reply
----------------------------------------------------

entity uoe_internet_layer is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64;    -- Width of the data bus
    G_NBR_PROT    : integer   := 2      -- Number of protocols used in internet leayer
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
    IPV4_RX_FRAG_OFFSET_ERROR : out std_logic;
    ICMP_MODULE_ERROR         : out std_logic_vector(1 downto 0)
  );
end uoe_internet_layer;

architecture rtl of uoe_internet_layer is

  -----------------------------------
  -- Constant declaration
  -----------------------------------
  constant C_PING_SIZE  : integer := 32;
  constant C_NBR_BITS   : integer := 64+C_PING_SIZE*8;
  constant C_FIFO_DEPTH : integer := 40;
  constant C_INDEX_ICMP : integer := 0;
  constant C_INDEX_IPV4 : integer := 1;
  constant C_TKEEP_WIDTH : positive := (G_TDATA_WIDTH + 7) / 8;
  
  -----------------------------------
  -- Components declaration
  -----------------------------------
  component axis_mux_custom is
    generic(
      G_ACTIVE_RST          : std_logic;
      G_ASYNC_RST           : boolean;
      G_TDATA_WIDTH         : positive;
      G_TUSER_WIDTH         : positive;
      G_TID_WIDTH           : positive;
--      G_TDEST_WIDTH         : positive;
      G_NB_SLAVE            : positive;
      G_REG_SLAVES_FORWARD  : std_logic_vector;
      G_REG_SLAVES_BACKWARD : std_logic_vector;
      G_REG_MASTER_FORWARD  : boolean;
      G_REG_MASTER_BACKWARD : boolean;
      G_REG_ARB_FORWARD     : boolean;
      G_REG_ARB_BACKWARD    : boolean;
      G_PACKET_MODE         : boolean;
      G_ROUND_ROBIN         : boolean;
      G_FAST_ARCH           : boolean
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic;
      RST      : in  std_logic;
      -- SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0);
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0);
--      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0);
--      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0);
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- MASTER INTERFACE
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
--      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
--      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY : in  std_logic
    );
  end component axis_mux_custom;
  
  component axis_demux_custom is
    generic(
      G_ACTIVE_RST           : std_logic;
      G_ASYNC_RST            : boolean;
      G_TDATA_WIDTH          : positive;
--      G_TUSER_WIDTH          : positive;
      G_TID_WIDTH            : positive;
      G_TDEST_WIDTH          : positive;
      G_NB_MASTER            : positive;
      G_REG_SLAVE_FORWARD    : boolean;
      G_REG_SLAVE_BACKWARD   : boolean;
      G_REG_MASTERS_FORWARD  : std_logic_vector;
      G_REG_MASTERS_BACKWARD : std_logic_vector
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic;
      RST      : in  std_logic;
  
      -- SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
--      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
--      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      S_TREADY : out std_logic;
  
      -- MASTER INTERFACE
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);
--      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);
--      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);
--      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)
    );
  end component axis_demux_custom;

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
  
  component uoe_icmp_module_echo_reply is
    generic(
      G_PING_SIZE : integer;      -- Ping payload size
      G_FIFO_DEPTH : positive;    -- Depth of FIFO
      G_DATA_SIZE : integer;      -- Width of the data bus
      G_LE : boolean
    );
    port(
      CLK              : in  std_logic;
      RST              : in  std_logic;
      ERROR_REG        : out std_logic_vector(1 downto 0);

      REQUEST_TDATA    : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      REQUEST_TVALID   : in  std_logic;
      REQUEST_TLAST    : in  std_logic;
      REQUEST_TKEEP    : in  std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
      REQUEST_TID      : in  std_logic_vector(15 downto 0);
      REQUEST_TREADY   : out std_logic;

      ECHO_TDATA       : out std_logic_vector(G_DATA_SIZE-1 downto 0);
      ECHO_TVALID      : out std_logic;
      ECHO_TLAST       : out std_logic;
      ECHO_TKEEP       : out std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
      ECHO_TID         : out std_logic_vector(15 downto 0);                        -- Type + Code
      ECHO_TREADY      : in  std_logic
    );
  end component uoe_icmp_module_echo_reply;
  
  component uoe_icmp_error_handler is
    port(
      CLK         : in  std_logic;
      RST         : in  std_logic;
      ERROR_REG   : in  std_logic_vector(1 downto 0);
      DATA        : out std_logic_vector(1 downto 0)
    );
  end component uoe_icmp_error_handler;
  
  -----------------------------------
  -- Signals declaration
  -----------------------------------

  signal ipv4_to_mux_tdata     :  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal ipv4_to_mux_tvalid    :  std_logic;
  signal ipv4_to_mux_tlast     :  std_logic;
  signal ipv4_to_mux_tkeep     :  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal ipv4_to_mux_tid       :  std_logic_vector(15 downto 0);
  signal ipv4_to_mux_tuser     :  std_logic_vector(31 downto 0);
  signal ipv4_to_mux_tready    :  std_logic;

  signal icmp_to_mux_tdata     :  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal icmp_to_mux_tvalid    :  std_logic;
  signal icmp_to_mux_tlast     :  std_logic;
  signal icmp_to_mux_tkeep     :  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal icmp_to_mux_tid       :  std_logic_vector(15 downto 0);
  signal icmp_to_mux_tready    :  std_logic;
  
  signal demux_to_ipv4_tdata   :  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal demux_to_ipv4_tvalid  :  std_logic;
  signal demux_to_ipv4_tlast   :  std_logic;
  signal demux_to_ipv4_tkeep   :  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal demux_to_ipv4_tid     :  std_logic_vector(15 downto 0);
  signal demux_to_ipv4_tready  :  std_logic;
  
  signal demux_to_icmp_tdata   :  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal demux_to_icmp_tvalid  :  std_logic;
  signal demux_to_icmp_tlast   :  std_logic;
  signal demux_to_icmp_tkeep   :  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal demux_to_icmp_tid     :  std_logic_vector(15 downto 0);
  signal demux_to_icmp_tready  :  std_logic;
  
  signal axis_rx_demux_tdata   :  std_logic_vector((G_NBR_PROT * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_rx_demux_tvalid  :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  signal axis_rx_demux_tlast   :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  signal axis_rx_demux_tkeep   :  std_logic_vector((G_NBR_PROT * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
  signal axis_rx_demux_tid     :  std_logic_vector((G_NBR_PROT * 16) - 1 downto 0);
  signal axis_rx_demux_tready  :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  
  signal axis_tx_mux_tdata     :  std_logic_vector((G_NBR_PROT * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_tx_mux_tvalid    :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  signal axis_tx_mux_tlast     :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  signal axis_tx_mux_tkeep     :  std_logic_vector((G_NBR_PROT * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
  signal axis_tx_mux_tid       :  std_logic_vector((G_NBR_PROT * 16) - 1 downto 0);
  signal axis_tx_mux_tuser     :  std_logic_vector((G_NBR_PROT * 32) - 1 downto 0);
  signal axis_tx_mux_tready    :  std_logic_vector(G_NBR_PROT - 1 downto 0);
  
  signal protocol               : std_logic_vector (15 downto 0);
  signal destination            : std_logic_vector (0 downto 0);
  
begin

  protocol <= S_LINK_RX_TID;
  destination <= "0" when protocol = x"0001" else "1";

  -- Demux
  inst_axis_demux_custom_rx : axis_demux_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TDEST_WIDTH          => 1,
      G_TID_WIDTH            => 16,
      G_NB_MASTER            => 2,
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
      S_TDATA  => S_LINK_RX_TDATA, 
      S_TVALID => S_LINK_RX_TVALID,
      S_TLAST  => S_LINK_RX_TLAST, 
      S_TKEEP  => S_LINK_RX_TKEEP,
      S_TID    => (others => '0'),
      S_TDEST  => destination,
      S_TREADY => S_LINK_RX_TREADY,
      -- MASTER INTERFACES are packed together
      M_TDATA  => axis_rx_demux_tdata,
      M_TVALID => axis_rx_demux_tvalid,
      M_TLAST  => axis_rx_demux_tlast,
      M_TKEEP  => axis_rx_demux_tkeep,
      M_TID    => axis_rx_demux_tid,
      M_TREADY => axis_rx_demux_tready
    );
    
    -- M00
    demux_to_icmp_tdata                 <= axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_ICMP + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_ICMP));
    demux_to_icmp_tvalid                <= axis_rx_demux_tvalid(C_INDEX_ICMP);
    demux_to_icmp_tlast                 <= axis_rx_demux_tlast(C_INDEX_ICMP); 
    demux_to_icmp_tkeep                 <= axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_ICMP + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_ICMP));
    demux_to_icmp_tid                   <= axis_rx_demux_tid((G_NBR_PROT-1)*16*(C_INDEX_ICMP + 1) - 1 downto (G_NBR_PROT-1)*16*(C_INDEX_ICMP));
    axis_rx_demux_tready(C_INDEX_ICMP)  <= demux_to_icmp_tready;
	
	-- M01
    demux_to_ipv4_tdata                 <= axis_rx_demux_tdata((G_TDATA_WIDTH * (C_INDEX_IPV4 + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_IPV4));
    demux_to_ipv4_tvalid                <= axis_rx_demux_tvalid(C_INDEX_IPV4);
    demux_to_ipv4_tlast                 <= axis_rx_demux_tlast(C_INDEX_IPV4); 
    demux_to_ipv4_tkeep                 <= axis_rx_demux_tkeep((C_TKEEP_WIDTH * (C_INDEX_IPV4 + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_IPV4));
	demux_to_ipv4_tid                   <= axis_rx_demux_tid((G_NBR_PROT-1)*16*(C_INDEX_IPV4 + 1) - 1 downto (G_NBR_PROT-1)*16*(C_INDEX_IPV4));
    axis_rx_demux_tready(C_INDEX_IPV4)  <= demux_to_ipv4_tready;
   
    
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
      S_LINK_RX_TDATA           => demux_to_ipv4_tdata,
      S_LINK_RX_TVALID          => demux_to_ipv4_tvalid,
      S_LINK_RX_TLAST           => demux_to_ipv4_tlast,
      S_LINK_RX_TKEEP           => demux_to_ipv4_tkeep,
      S_LINK_RX_TREADY          => demux_to_ipv4_tready,
      
      M_LINK_TX_TDATA           => ipv4_to_mux_tdata,
      M_LINK_TX_TVALID          => ipv4_to_mux_tvalid,
      M_LINK_TX_TLAST           => ipv4_to_mux_tlast,
      M_LINK_TX_TKEEP           => ipv4_to_mux_tkeep,
      M_LINK_TX_TID             => ipv4_to_mux_tid, 
      M_LINK_TX_TUSER           => ipv4_to_mux_tuser,
      M_LINK_TX_TREADY          => ipv4_to_mux_tready,
      
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
    
  inst_axis_mux_custom_rx_ext : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_TUSER_WIDTH         => 32,
      G_TID_WIDTH           => 16,
      G_NB_SLAVE            => 2,
      G_REG_SLAVES_FORWARD  => "00",    -- Disable input registers
      G_REG_SLAVES_BACKWARD => "00",
      G_REG_MASTER_FORWARD  => true,
      G_REG_MASTER_BACKWARD => false,
      G_REG_ARB_FORWARD     => false,
      G_REG_ARB_BACKWARD    => false,
      G_ROUND_ROBIN         => false,
      G_PACKET_MODE         => true,
      G_FAST_ARCH           => false
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACES are packed together
      S_TDATA  => axis_tx_mux_tdata,
      S_TVALID => axis_tx_mux_tvalid,
      S_TLAST  => axis_tx_mux_tlast,
      S_TKEEP  => axis_tx_mux_tkeep,
	  S_TID    => axis_tx_mux_tid,
	  S_TUSER  => axis_tx_mux_tuser,
      S_TREADY => axis_tx_mux_tready,
      -- MASTER INTERFACE
      M_TDATA  => M_LINK_TX_TDATA,
      M_TVALID => M_LINK_TX_TVALID,
      M_TLAST  => M_LINK_TX_TLAST,
      M_TKEEP  => M_LINK_TX_TKEEP,
      M_TID    => M_LINK_TX_TID,
      M_TUSER  => M_LINK_TX_TUSER, -- Target IP Address 
      M_TREADY => M_LINK_TX_TREADY
    );
    
    
	-- S00
    axis_tx_mux_tdata((G_TDATA_WIDTH * (C_INDEX_ICMP + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_ICMP))   <= icmp_to_mux_tdata;
    axis_tx_mux_tvalid(C_INDEX_ICMP)                                                                    <= icmp_to_mux_tvalid;
    axis_tx_mux_tlast(C_INDEX_ICMP)                                                                     <= icmp_to_mux_tlast; 
    axis_tx_mux_tkeep((C_TKEEP_WIDTH * (C_INDEX_ICMP + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_ICMP))   <= icmp_to_mux_tkeep;
	axis_tx_mux_tid((G_NBR_PROT-1)*16*(C_INDEX_ICMP + 1) - 1 downto (G_NBR_PROT-1)*16*(C_INDEX_ICMP))   <= icmp_to_mux_tid;
	icmp_to_mux_tready                                                                                  <= axis_tx_mux_tready(C_INDEX_ICMP);
	axis_tx_mux_tuser((G_NBR_PROT-1)*32*(C_INDEX_ICMP + 1) - 1 downto (G_NBR_PROT-1)*32*(C_INDEX_ICMP)) <= (others => '0');
    
	-- S01
    axis_tx_mux_tdata((G_TDATA_WIDTH * (C_INDEX_IPV4 + 1)) - 1 downto (G_TDATA_WIDTH * C_INDEX_IPV4))   <= ipv4_to_mux_tdata;
    axis_tx_mux_tvalid(C_INDEX_IPV4)                                                                    <= ipv4_to_mux_tvalid;
    axis_tx_mux_tlast(C_INDEX_IPV4)                                                                     <= ipv4_to_mux_tlast; 
    axis_tx_mux_tkeep((C_TKEEP_WIDTH * (C_INDEX_IPV4 + 1)) - 1 downto (C_TKEEP_WIDTH * C_INDEX_IPV4))   <= ipv4_to_mux_tkeep;
	axis_tx_mux_tid((G_NBR_PROT-1)*16*(C_INDEX_IPV4 + 1) - 1 downto (G_NBR_PROT-1)*16*(C_INDEX_IPV4))   <= ipv4_to_mux_tid;
    ipv4_to_mux_tready                                                                                  <= axis_tx_mux_tready(C_INDEX_IPV4);
    axis_tx_mux_tuser((G_NBR_PROT-1)*32*(C_INDEX_IPV4 + 1) - 1 downto (G_NBR_PROT-1)*32*(C_INDEX_IPV4)) <= ipv4_to_mux_tuser;
    
  inst_uoe_icmp_module_echo_reply : component uoe_icmp_module_echo_reply
    generic map(
      G_PING_SIZE => C_PING_SIZE,
      G_FIFO_DEPTH => C_FIFO_DEPTH,
      G_DATA_SIZE => G_TDATA_WIDTH, 
      G_LE => true
    )
    port map(       
      CLK             => CLK,
      RST             => RST,
	  ERROR_REG   	  => ICMP_MODULE_ERROR, 
      
      REQUEST_TDATA    => demux_to_icmp_tdata, 
      REQUEST_TVALID   => demux_to_icmp_tvalid,
      REQUEST_TLAST    => demux_to_icmp_tlast, 
      REQUEST_TKEEP    => demux_to_icmp_tkeep, 
      REQUEST_TID      => demux_to_icmp_tid,   
      REQUEST_TREADY   => demux_to_icmp_tready,
      
      ECHO_TDATA       => icmp_to_mux_tdata, 
      ECHO_TVALID      => icmp_to_mux_tvalid,
      ECHO_TLAST       => icmp_to_mux_tlast, 
      ECHO_TKEEP       => icmp_to_mux_tkeep, 
      ECHO_TID         => icmp_to_mux_tid,   
      ECHO_TREADY      => icmp_to_mux_tready
    );

end rtl;

