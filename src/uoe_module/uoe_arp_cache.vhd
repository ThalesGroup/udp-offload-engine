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
-- ARP CACHE
----------------------------------
--
-- This module define the cache used for ARP
-- This cache is used to be more reactive when an IP address is received for association with a MAC Address 
-- It can store one unique couple IP/MAC Address
--
-- When a IP address is required by MAC Shaping, if the cached MAC address corresponds, the MAC address is directly returned.
-- Otherwise, the request is transmitted to ARP Table.
-- When MAC address is coming from ARP table, the address is stored in cache if valid, and transmit to mac shaping. 
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_arp_cache is
  generic(
    G_ACTIVE_RST : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true    -- Type of reset used (synchronous or asynchronous resets)
  );
  port(
    CLK                   : in  std_logic;
    RST                   : in  std_logic;
    -- IP ADDR interface
    S_IP_ADDR_TDATA       : in  std_logic_vector(31 downto 0);
    S_IP_ADDR_TVALID      : in  std_logic;
    S_IP_ADDR_TREADY      : out std_logic;
    -- MAC ADDR interface
    M_MAC_ADDR_TDATA      : out std_logic_vector(47 downto 0);
    M_MAC_ADDR_TVALID     : out std_logic;
    M_MAC_ADDR_TUSER      : out std_logic_vector(0 downto 0);
    M_MAC_ADDR_TREADY     : in  std_logic;
    -- ARP Table interface
    M_ARP_IP_ADDR_TDATA   : out std_logic_vector(31 downto 0);
    M_ARP_IP_ADDR_TVALID  : out std_logic;
    M_ARP_IP_ADDR_TREADY  : in  std_logic;
    S_ARP_MAC_ADDR_TDATA  : in  std_logic_vector(47 downto 0);
    S_ARP_MAC_ADDR_TVALID : in  std_logic;
    S_ARP_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0);
    S_ARP_MAC_ADDR_TREADY : out std_logic;
    -- Registers
    LOCAL_IP_ADDR         : in  std_logic_vector(31 downto 0);
    LOCAL_MAC_ADDR        : in  std_logic_vector(47 downto 0)
  );
end entity uoe_arp_cache;

architecture rtl of uoe_arp_cache is

  -------------------------------
  -- signals declaration
  -------------------------------

  signal s_ip_addr_tready_i      : std_logic;
  signal s_arp_mac_addr_tready_i : std_logic;
  signal m_mac_addr_tvalid_i     : std_logic;

  -- reset output
  signal cache_init : std_logic;

  -- memorize IP address during processing
  signal ip_addr_mem : std_logic_vector(31 downto 0);

  -- Cache
  signal ip_addr_cache      : std_logic_vector(31 downto 0);
  signal mac_addr_cache     : std_logic_vector(47 downto 0);
  signal multicast_mac_conv : std_logic_vector(47 downto 0);

begin

  S_IP_ADDR_TREADY      <= s_ip_addr_tready_i;
  S_ARP_MAC_ADDR_TREADY <= s_arp_mac_addr_tready_i;
  M_MAC_ADDR_TVALID     <= m_mac_addr_tvalid_i;

  -- when received a multicast IP request (bits 31 => 28 = "1110"), lsb bits (27 => 0) is copied on the mac address lsb bits
  multicast_mac_conv <= x"01_00_5E" & "0" & S_IP_ADDR_TDATA(22 downto 0);

  -- process use to handle cache
  P_FSM_CACHE : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      cache_init              <= '1';
      s_ip_addr_tready_i      <= '0';
      M_MAC_ADDR_TDATA        <= (others => '0');
      M_MAC_ADDR_TUSER        <= (others => '0');
      m_mac_addr_tvalid_i     <= '0';
      M_ARP_IP_ADDR_TDATA     <= (others => '0');
      M_ARP_IP_ADDR_TVALID    <= '0';
      s_arp_mac_addr_tready_i <= '0';
      ip_addr_mem             <= (others => '0');
      ip_addr_cache           <= (others => '0');
      mac_addr_cache          <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        cache_init              <= '1';
        s_ip_addr_tready_i      <= '0';
        M_MAC_ADDR_TDATA        <= (others => '0');
        M_MAC_ADDR_TUSER        <= (others => '0');
        m_mac_addr_tvalid_i     <= '0';
        M_ARP_IP_ADDR_TDATA     <= (others => '0');
        M_ARP_IP_ADDR_TVALID    <= '0';
        s_arp_mac_addr_tready_i <= '0';
        ip_addr_mem             <= (others => '0');
        ip_addr_cache           <= (others => '0');
        mac_addr_cache          <= (others => '0');

      else

        -- assert tready when previous data has been return 
        if (m_mac_addr_tvalid_i = '1') and (M_MAC_ADDR_TREADY = '1') then
          s_ip_addr_tready_i <= '1';
        -- or after reset
        elsif cache_init = '1' then
          s_ip_addr_tready_i <= '1';
          cache_init         <= '0';
        end if;

        -- clear valid when TREADY is assert
        if (M_MAC_ADDR_TREADY = '1') then
          m_mac_addr_tvalid_i <= '0';
        end if;

        -- clear valid when TREADY is assert
        if (M_ARP_IP_ADDR_TREADY = '1') then
          M_ARP_IP_ADDR_TVALID <= '0';
        end if;

        -- received request
        if (S_IP_ADDR_TVALID = '1') and (s_ip_addr_tready_i = '1') then
          s_ip_addr_tready_i  <= '0';
          ip_addr_mem         <= S_IP_ADDR_TDATA;
          M_MAC_ADDR_TUSER(0) <= C_STATUS_VALID;

          -- Request IP is broadcast addr
          if S_IP_ADDR_TDATA = C_BROADCAST_IP_ADDR then
            M_MAC_ADDR_TDATA    <= C_BROADCAST_MAC_ADDR;
            m_mac_addr_tvalid_i <= '1';

          -- Request IP is local addr
          elsif S_IP_ADDR_TDATA = LOCAL_IP_ADDR then  
            M_MAC_ADDR_TDATA    <= LOCAL_MAC_ADDR;
            m_mac_addr_tvalid_i <= '1';

          -- Request IP is multicast addr
          elsif S_IP_ADDR_TDATA(31 downto 28) = "1110" then
            M_MAC_ADDR_TDATA    <= multicast_mac_conv;
            m_mac_addr_tvalid_i <= '1';

          -- Request IP corresponds to the cached IP
          elsif S_IP_ADDR_TDATA = ip_addr_cache then
            M_MAC_ADDR_TDATA    <= mac_addr_cache;
            m_mac_addr_tvalid_i <= '1';

          -- else transfer request to the table
          else
            M_ARP_IP_ADDR_TDATA     <= S_IP_ADDR_TDATA;
            M_ARP_IP_ADDR_TVALID    <= '1';
            s_arp_mac_addr_tready_i <= '1';
          end if;

        end if;

        -- Waiting answers from table or arp
        if (S_ARP_MAC_ADDR_TVALID = '1') and (s_arp_mac_addr_tready_i = '1') then
          M_MAC_ADDR_TDATA        <= S_ARP_MAC_ADDR_TDATA;
          M_MAC_ADDR_TUSER        <= S_ARP_MAC_ADDR_TUSER;
          m_mac_addr_tvalid_i     <= '1';
          s_arp_mac_addr_tready_i <= '0';

          -- If received MAC address is valid, new couple is saved in cache
          if S_ARP_MAC_ADDR_TUSER(0) = C_STATUS_VALID then
            mac_addr_cache <= S_ARP_MAC_ADDR_TDATA;
            ip_addr_cache  <= ip_addr_mem;
          end if;
        end if;

      end if;
    end if;
  end process P_FSM_CACHE;

end architecture rtl;
