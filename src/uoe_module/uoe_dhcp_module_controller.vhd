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
-- DHCP MODULE Controller
----------------------------------
-- DHCP client according to RFC 2131
-- This module is used to control the DHCP Rx and Tx module 
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_dhcp_module_controller is

  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 32     -- Width of the data bus
  );
  port (
    -- Clocks and resets
    CLK                : in  std_logic;
    RST                : in  std_logic;
    INIT_DONE          : in  std_logic;
    DHCP_START         : in  std_logic;

    DHCP_MESSAGE_SENT  : in  std_logic;
    DHCP_OFFER_SEL     : in  std_logic;
    DHCP_ACK           : in  std_logic;
    DHCP_NACK          : in  std_logic;

    DHCP_SEND_DISCOVER : out std_logic;
    DHCP_SEND_REQUEST  : out std_logic;
    DHCP_XID           : out std_logic_vector(31 downto 0);
    DHCP_STATE         : out t_dhcp_state;
    DHCP_STATUS        : out std_logic_vector(1 downto 0)
    -- signification of status value
    -- 0 --> dhcp configuration not started yet(IDLE mode)
    -- 1 --> dhcp configuration is in progress
    -- 2 --> dhcp configuration is failed(process will be restarted from DISCOVER)
    -- 3 --> dhcp configuration is succesfull (we are in bound)  
  );
end uoe_dhcp_module_controller;

architecture rtl of uoe_dhcp_module_controller is

  --state machine signal
  signal s_dhcp_state         : t_dhcp_state;
  --send discover signal
  signal send_dhcp_discover   : std_logic;
  --send request signal
  signal send_dhcp_request    : std_logic;
  signal status_dhcp          : std_logic_vector(1 downto 0);
  --xid used to identify client-server interaction
  signal xid                  : unsigned(31 downto 0);

begin

  DHCP_STATE                   <= s_dhcp_state;
  DHCP_SEND_DISCOVER           <= send_dhcp_discover;
  DHCP_SEND_REQUEST            <= send_dhcp_request;
  DHCP_STATUS                  <= status_dhcp;
  DHCP_XID                     <= std_logic_vector(xid);

  proc_dhcp_state : process(CLK, RST)
  begin

    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      s_dhcp_state             <= IDLE;
      send_dhcp_discover       <= '0';
      send_dhcp_request        <= '0';
      xid                      <= (others => '0');
      status_dhcp              <= (others => '0');
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        s_dhcp_state           <= IDLE;
        send_dhcp_discover     <= '0';
        send_dhcp_request      <= '0';
        xid                    <= (others => '0');
        status_dhcp            <= (others => '0');
      
      else

        case s_dhcp_state is
         
          when IDLE =>
            if (INIT_DONE = '1' and DHCP_START ='1')  then
              s_dhcp_state       <= DISCOVER;
              send_dhcp_discover <= '1';
              status_dhcp        <=(0 => '1', others => '0');  -- dhcp configuration is in progress 
              xid                <= xid + 3 ;
              
            else
              s_dhcp_state <= IDLE;
            end if;

          when DISCOVER =>
            if DHCP_MESSAGE_SENT = '1' then                    -- Discover message is sent, go to the offer state
              send_dhcp_discover <= '0';
              s_dhcp_state       <= OFFER;
            else
              s_dhcp_state       <= DISCOVER;
            end if;

          when OFFER =>
            if DHCP_OFFER_SEL = '1' then                       -- an offer is selected, we send the request message
              send_dhcp_request <= '1';
              s_dhcp_state      <= REQUEST;
            else
              s_dhcp_state      <= OFFER;
            end if;
         
          When REQUEST =>
            if DHCP_MESSAGE_SENT = '1' then                    -- the request message is sent, go to ack state 
              send_dhcp_request <= '0';
              s_dhcp_state      <= ACK;
            else
              s_dhcp_state      <= REQUEST;
            end if;
         
          when ACK => 

            if DHCP_NACK = '1' then
              status_dhcp        <=(1 => '1', others => '0');  --dhcp configuration failed we restart the process
              send_dhcp_discover <= '1';
              xid                <= xid + 4;
              s_dhcp_state       <= DISCOVER;

            elsif DHCP_ACK = '1' then 
              status_dhcp        <=(others => '1');            --dhcp configuration is succesfull
              s_dhcp_state       <= BOUND;
              send_dhcp_discover <= '0';
              send_dhcp_request  <= '0';
            else 
              s_dhcp_state       <= ACK;
            end if;

          when BOUND =>                                        -- an IP and all configuration parameters are set correctly                                             
            s_dhcp_state        <= BOUND;

          when others =>
            s_dhcp_state        <= IDLE;
        end case;
      end if;
    end if;
  end process proc_dhcp_state;
end rtl;
