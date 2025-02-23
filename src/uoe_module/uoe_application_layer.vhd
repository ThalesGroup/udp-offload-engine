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

-- This design was created in collaboration for an academic project at Polytech Nantes by:
--**************************************************************
-- Student        : B. LO, lo.babacar@outlook.com
--**************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
----------------------------------------------------
-- APPLICATION LAYER
----------------------------------------------------
-- This module integrates the application layer of the stack
--
-- Supported protocol :
-- - DHCP Protocol
----------------------------------------------------


use work.uoe_module_pkg.all;

entity uoe_application_layer is
  generic(
    G_ACTIVE_RST            : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST             : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH           : positive  := 32     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                     : in  std_logic;
    RST                     : in  std_logic;
  
    -- control input signal from register
    INIT_DONE               : in  std_logic;
    DHCP_START              : in  std_logic;                     -- flag to start the DHCP process
    DHCP_USE_IP             : in  std_logic;                     -- Flag to indicate whether to use the user's IP address in Request IP option
    DHCP_USER_IP_ADDR       : in  std_logic_vector(31 downto 0); -- user defined IP addresse
    DHCP_USER_MAC_ADDR      : in  std_logic_vector(47 downto 0); -- user defined MAC address
   
    -- outputs signal for register
    DHCP_NETWORK_CONFIG_REG : out t_dhcp_network_config;         -- DHCP assigned parameters
    DHCP_STATUS_REG         : out std_logic_vector(2 downto 0);  -- DHCP status 
   
    -- From UDP Transport Layer
    S_DHCP_RX_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_DHCP_RX_TVALID        : in  std_logic;
    S_DHCP_RX_TLAST         : in  std_logic;
    S_DHCP_RX_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_DHCP_RX_TUSER         : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    S_DHCP_RX_TREADY        : out std_logic;
 
    -- To UDP Transport Layer
    M_DHCP_TX_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_DHCP_TX_TVALID        : out std_logic;
    M_DHCP_TX_TLAST         : out std_logic;
    M_DHCP_TX_TKEEP         : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_DHCP_TX_TUSER         : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    M_DHCP_TX_TREADY        : in  std_logic
  );

end uoe_application_layer;

architecture rtl of uoe_application_layer is

  -- DHCP Protocol management
  Component uoe_dhcp_module is
    generic(
      G_ACTIVE_RST            : std_logic := '0';            
      G_ASYNC_RST             : boolean   := true;               
      G_TDATA_WIDTH           : positive  := 32                     
    );
    port(
      CLK                     : in  std_logic;
      RST                     : in  std_logic;
      INIT_DONE               : in  std_logic;                      
      DHCP_START              : in  std_logic;                      
      DHCP_USE_IP             : in  std_logic;                      
      DHCP_USER_IP_ADDR       : in  std_logic_vector(31 downto 0);  
      DHCP_USER_MAC_ADDR      : in  std_logic_vector(47 downto 0);  
      DHCP_NETWORK_CONFIG_REG : out t_dhcp_network_config;          
      DHCP_STATUS_REG         : out std_logic_vector(2 downto 0);   
      S_TDATA                 : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID                : in  std_logic;
      S_TLAST                 : in  std_logic;
      S_TKEEP                 : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TUSER                 : in  std_logic_vector(79 downto 0);  
      S_TREADY                : out std_logic;
      M_TDATA                 : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID                : out std_logic;
      M_TLAST                 : out std_logic;
      M_TKEEP                 : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TUSER                 : out std_logic_vector(79 downto 0); 
      M_TREADY                : in  std_logic
    );
  end component uoe_dhcp_module;

begin 
  
  inst_uoe_dhcp_module : uoe_dhcp_module

    generic map(
      G_ACTIVE_RST            => G_ACTIVE_RST,           
      G_ASYNC_RST             => G_ASYNC_RST,             
      G_TDATA_WIDTH           => G_TDATA_WIDTH                   
    )
    port map(
      CLK                     => CLK,
      RST                     => RST,
      INIT_DONE               => INIT_DONE,                    
      DHCP_START              => DHCP_START,                 
      DHCP_USE_IP             => DHCP_USE_IP,             
      DHCP_USER_IP_ADDR       => DHCP_USER_IP_ADDR,
      DHCP_USER_MAC_ADDR      => DHCP_USER_MAC_ADDR,
      DHCP_NETWORK_CONFIG_REG => DHCP_NETWORK_CONFIG_REG,        
      DHCP_STATUS_REG         => DHCP_STATUS_REG,
      S_TDATA                 => S_DHCP_RX_TDATA,
      S_TVALID                => S_DHCP_RX_TVALID,
      S_TLAST                 => S_DHCP_RX_TLAST,
      S_TKEEP                 => S_DHCP_RX_TKEEP,
      S_TUSER                 => S_DHCP_RX_TUSER,
      S_TREADY                => S_DHCP_RX_TREADY,
      M_TDATA                 => M_DHCP_TX_TDATA,
      M_TVALID                => M_DHCP_TX_TVALID,
      M_TLAST                 => M_DHCP_TX_TLAST,
      M_TKEEP                 => M_DHCP_TX_TKEEP,
      M_TUSER                 => M_DHCP_TX_TUSER,
      M_TREADY                => M_DHCP_TX_TREADY
    );

    -- signification of status value
    -- if DHCP_STATUS(1 downto 0) = : 
    -- 0 --> dhcp configuration not started yet(IDLE mode)
    -- 1 --> dhcp configuration is in progress
    -- 2 --> dhcp configuration is failed(process will be restarted from DISCOVER)
    -- 3 --> dhcp configuration is succesfull (we are in bound)  
    -- if DHCP_STATUS(2) = 1 --> ducp_Rx_error  : there might be an error or the received pacquets is not destinated to the DHCP
end rtl;