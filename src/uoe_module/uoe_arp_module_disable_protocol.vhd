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

use work.uoe_module_pkg.all;

----------------------------------
-- ARP MODULE DISABLE PROTOCOL
----------------------------------
--
-- This module aims at return a MAC address given by register when ARP Protocol is disable
--
----------------------------------

entity uoe_arp_module_disable_protocol is
  generic(
    G_ACTIVE_RST : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true    -- Type of reset used (synchronous or asynchronous resets)
  );
  port(
    -- Clock & reset
    CLK                  : in  std_logic;
    RST                  : in  std_logic;
    -- From MAC Shaping (ARP Table/Cache)
    S_IP_ADDR_TDATA      : in  std_logic_vector(31 downto 0);
    S_IP_ADDR_TVALID     : in  std_logic;
    S_IP_ADDR_TREADY     : out std_logic;
    -- To MAC Shaping (ARP Table/Cache)
    M_IP_MAC_ADDR_TDATA  : out std_logic_vector(79 downto 0); -- 79..32 => Targeted MAC, 31..0 => Targeted IP
    M_IP_MAC_ADDR_TVALID : out std_logic;
    M_IP_MAC_ADDR_TUSER  : out std_logic_vector(0 downto 0); -- Validity of the IP/MAC couple
    M_IP_MAC_ADDR_TREADY : in  std_logic;
    -- Registers
    RAW_DEST_MAC_ADDR    : in  std_logic_vector(47 downto 0)
  );
end uoe_arp_module_disable_protocol;

architecture rtl of uoe_arp_module_disable_protocol is

  --------------------------
  -- Signals declaration
  --------------------------

  signal s_ip_addr_tready_i     : std_logic;
  signal m_ip_mac_addr_tvalid_i : std_logic;

begin

  -- assignment
  S_IP_ADDR_TREADY       <= s_ip_addr_tready_i;     -- @suppress case is not matching but rule is OK
  M_IP_MAC_ADDR_TVALID   <= m_ip_mac_addr_tvalid_i; -- @suppress case is not matching but rule is OK
  M_IP_MAC_ADDR_TUSER(0) <= C_STATUS_VALID;         -- Always OK

  -- When MAC shaping requests a MAC address, return RAW_DEST_MAC_ADDR
  P_CTRL : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      s_ip_addr_tready_i     <= '0';
      M_IP_MAC_ADDR_TDATA    <= (others => '0');
      m_ip_mac_addr_tvalid_i <= '0';
    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        s_ip_addr_tready_i     <= '0';
        M_IP_MAC_ADDR_TDATA    <= (others => '0');
        m_ip_mac_addr_tvalid_i <= '0';
      else

        if (M_IP_MAC_ADDR_TREADY = '1') or (m_ip_mac_addr_tvalid_i /= '1') then
          m_ip_mac_addr_tvalid_i <= '0';
          s_ip_addr_tready_i     <= '1';
        end if;

        if (S_IP_ADDR_TVALID = '1') and (s_ip_addr_tready_i = '1') then
          s_ip_addr_tready_i                <= '0';
          M_IP_MAC_ADDR_TDATA(79 downto 32) <= RAW_DEST_MAC_ADDR;
          M_IP_MAC_ADDR_TDATA(31 downto 0)  <= S_IP_ADDR_TDATA;
          m_ip_mac_addr_tvalid_i            <= '1';
        end if;

      end if;
    end if;
  end process P_CTRL;

end rtl;
