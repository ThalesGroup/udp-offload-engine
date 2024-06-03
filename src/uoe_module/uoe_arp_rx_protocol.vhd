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

----------------------------------
-- ARP RX PROTOCOL
----------------------------------
--
-- This module is used to received an ARP frame and extract IP/MAC address
-- Moreover, it handle the detection of IP CONFLICT
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_arp_rx_protocol is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Number of bits used along AXI datapath of UOE
  );
  port(
    -- Clock & reset
    CLK                           : in  std_logic;
    RST                           : in  std_logic;
    -- Ethernet Frame router interface
    S_TDATA                       : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
    S_TVALID                      : in  std_logic;
    S_TLAST                       : in  std_logic;
    S_TKEEP                       : in  std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0); --@suppress SI2 : TKEEP is not used
    S_TREADY                      : out std_logic;
    --Interface with ARP Controller
    M_TDATA                       : out std_logic_vector(79 downto 0); -- (79..32) Sender MAC Addr., (31..0) Sender IP Addr.
    M_TVALID                      : out std_logic;
    M_TUSER                       : out std_logic_vector(0 downto 0); -- 0 => Request, 1 => Reply
    -- Registers interface
    LOCAL_IP_ADDR                 : in  std_logic_vector(31 downto 0);
    LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
    ARP_IP_CONFLICT               : out std_logic;
    ARP_MAC_CONFLICT              : out std_logic;
    ARP_RX_TARGET_IP_FILTER       : in  std_logic_vector(1 downto 0);
    --TODO : Still used?
    ARP_RX_TEST_LOCAL_IP_CONFLICT : in  std_logic;
    ARP_SELF_ID_DONE              : in  std_logic
  );
end uoe_arp_rx_protocol;

architecture rtl of uoe_arp_rx_protocol is

  -------------------------------
  -- Constants declaration
  -------------------------------

  constant C_TKEEP_WIDTH : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_CNT_MAX     : integer := integer(ceil(real(42) / real(C_TKEEP_WIDTH)));

  -------------------------------
  -- Signals declaration
  -------------------------------

  signal cnt : integer range 0 to C_CNT_MAX;

  signal m_tvalid_i : std_logic;

  signal opcode     : std_logic_vector(15 downto 0);
  signal sender_mac : std_logic_vector(47 downto 0);
  signal sender_ip  : std_logic_vector(31 downto 0);
  signal target_mac : std_logic_vector(47 downto 0);
  signal target_ip  : std_logic_vector(31 downto 0);

  signal new_frame               : std_logic;
  signal new_frame_r             : std_logic;
  signal target_mac_is_broadcast : std_logic;
  signal target_mac_is_zero      : std_logic;
  signal target_ip_is_broadcast  : std_logic;
  signal target_ip_is_zero       : std_logic;
  signal target_ip_is_local      : std_logic;
  signal sender_ip_is_broadcast  : std_logic;
  signal sender_ip_is_zero       : std_logic;
  signal sender_ip_is_target_ip  : std_logic;
  signal sender_mac_is_local     : std_logic;
  signal sender_ip_is_local      : std_logic;

  -------------------------------
  -- Functions declaration
  -------------------------------

  -- Comparison of std_logic_vector
  function slv_compare(constant A, B : in std_logic_vector) return std_logic is
    variable res : std_logic;
  begin
    res := '0';
    if A = B then                       -- @suppress PR5 : by contruction
      res := '1';
    end if;
    return res;
  end function slv_compare;

begin

  -- assignment
  M_TVALID <= m_tvalid_i;

  -- TREADY is always asserted
  S_TREADY <= '1';

  -- ARP decoding
  P_ARP_DECODER : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      cnt                     <= 0;
      M_TDATA                 <= (others => '0');
      M_TUSER(0)              <= C_ARP_REQUEST;
      m_tvalid_i              <= '0';
      opcode                  <= (others => '0');
      sender_mac              <= (others => '0');
      sender_ip               <= (others => '0');
      target_mac              <= (others => '0');
      target_ip               <= (others => '0');
      new_frame               <= '0';
      new_frame_r             <= '0';
      target_mac_is_broadcast <= '0';
      target_mac_is_zero      <= '0';
      target_ip_is_broadcast  <= '0';
      target_ip_is_zero       <= '0';
      target_ip_is_local      <= '0';
      sender_ip_is_broadcast  <= '0';
      sender_ip_is_zero       <= '0';
      sender_ip_is_target_ip  <= '0';
      sender_mac_is_local     <= '0';
      sender_ip_is_local      <= '0';
      ARP_IP_CONFLICT         <= '0';
      ARP_MAC_CONFLICT        <= '0';

    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        cnt                     <= 0;
        M_TDATA                 <= (others => '0');
        M_TUSER(0)              <= C_ARP_REQUEST;
        m_tvalid_i              <= '0';
        opcode                  <= (others => '0');
        sender_mac              <= (others => '0');
        sender_ip               <= (others => '0');
        target_mac              <= (others => '0');
        target_ip               <= (others => '0');
        new_frame               <= '0';
        new_frame_r             <= '0';
        target_mac_is_broadcast <= '0';
        target_mac_is_zero      <= '0';
        target_ip_is_broadcast  <= '0';
        target_ip_is_zero       <= '0';
        target_ip_is_local      <= '0';
        sender_ip_is_broadcast  <= '0';
        sender_ip_is_zero       <= '0';
        sender_ip_is_target_ip  <= '0';
        sender_mac_is_local     <= '0';
        sender_ip_is_local      <= '0';
        ARP_IP_CONFLICT         <= '0';
        ARP_MAC_CONFLICT        <= '0';

      else

        -- Clear pulse
        ARP_IP_CONFLICT  <= '0';
        ARP_MAC_CONFLICT <= '0';
        new_frame        <= '0';
        m_tvalid_i       <= '0';

        -- Received frame
        if (S_TVALID = '1') then        -- S_TREADY is always '1'

          -- Counter
          if (S_TLAST = '1') then
            cnt       <= 0;
            new_frame <= '1';
          elsif (cnt < C_CNT_MAX) then
            cnt <= cnt + 1;
          end if;

          -- Search field in flow
          for i in 0 to C_TKEEP_WIDTH - 1 loop
            -- Little Endian
            case (cnt * C_TKEEP_WIDTH) + i is
              -- Big Endian
              --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH-1) - i)) is
              when 20 => opcode(15 downto 8)      <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 21 => opcode(7 downto 0)       <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 22 => sender_mac(47 downto 40) <= S_TDATA((8 * i) + 7 downto 8 * i); -- Sender Hardware address (MAC)
              when 23 => sender_mac(39 downto 32) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 24 => sender_mac(31 downto 24) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 25 => sender_mac(23 downto 16) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 26 => sender_mac(15 downto 8)  <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 27 => sender_mac(7 downto 0)   <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 28 => sender_ip(31 downto 24)  <= S_TDATA((8 * i) + 7 downto 8 * i); -- Sender Protocol address (IP)
              when 29 => sender_ip(23 downto 16)  <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 30 => sender_ip(15 downto 8)   <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 31 => sender_ip(7 downto 0)    <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 32 => target_mac(47 downto 40) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 33 => target_mac(39 downto 32) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 34 => target_mac(31 downto 24) <= S_TDATA((8 * i) + 7 downto 8 * i); -- Sender Protocol address (IP)
              when 35 => target_mac(23 downto 16) <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 36 => target_mac(15 downto 8)  <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 37 => target_mac(7 downto 0)   <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 38 => target_ip(31 downto 24)  <= S_TDATA((8 * i) + 7 downto 8 * i); -- Sender Protocol address (IP)
              when 39 => target_ip(23 downto 16)  <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 40 => target_ip(15 downto 8)   <= S_TDATA((8 * i) + 7 downto 8 * i);
              when 41 => target_ip(7 downto 0)    <= S_TDATA((8 * i) + 7 downto 8 * i);
              when others =>
            end case;
          end loop;
        end if;

        -- register pulse
        new_frame_r             <= new_frame;
        target_mac_is_broadcast <= slv_compare(C_BROADCAST_MAC_ADDR, target_mac);
        target_mac_is_zero      <= slv_compare(C_ZERO_MAC_ADDR, target_mac);
        target_ip_is_broadcast  <= slv_compare(C_BROADCAST_IP_ADDR, target_ip);
        target_ip_is_zero       <= slv_compare(C_ZERO_IP_ADDR, target_ip);
        target_ip_is_local      <= slv_compare(LOCAL_IP_ADDR, target_ip);
        sender_ip_is_broadcast  <= slv_compare(C_BROADCAST_IP_ADDR, sender_ip);
        sender_ip_is_zero       <= slv_compare(C_ZERO_IP_ADDR, sender_ip);
        sender_ip_is_target_ip  <= slv_compare(target_ip, sender_ip);
        sender_mac_is_local     <= slv_compare(LOCAL_MAC_ADDR, sender_mac);
        sender_ip_is_local      <= slv_compare(LOCAL_IP_ADDR, sender_ip);

        -- Transmit answers
        if (new_frame_r = '1') then
          -- tdata
          M_TDATA <= sender_mac & sender_ip;

          -- Verification IP/MAC Conflict
          -- Add param reg ARP_RX_TEST_LOCAL_IP_CONFLICT to allow test conflict or not (goal : test loopback)
          if (sender_mac_is_local = '1') and (ARP_RX_TEST_LOCAL_IP_CONFLICT = '1') and (ARP_SELF_ID_DONE = '1') then
            ARP_MAC_CONFLICT <= '1';
          elsif (sender_ip_is_local = '1') and (ARP_RX_TEST_LOCAL_IP_CONFLICT = '1') then
            ARP_IP_CONFLICT <= '1';
          else
            -- ****************************************************************************************
            -- Operation code : REQUEST : Answer if we are concerned => Target IP Addr = LOCAL IP ADDR
            if opcode = C_ARP_OPCODE_REQUEST then

              -- Concerned by the request
              if target_ip_is_local = '1' then
                M_TUSER(0) <= C_ARP_REQUEST;
                m_tvalid_i <= '1';

              --------------------------
              -- Gestion cas Gratuitous avec OPCODE = REQ
              -- Gratuitous : if (SENDER IP ADDR = TARGET IP ADDR) && TARGET MAC = 0xFF ou 0x00
              -- Consider as reply and no need answers
              -- Warning : if SENDER IP ADDR = 0xFF ou 0x00 => don't take it for a gratuitous arp

              elsif (sender_ip_is_broadcast = '1') or (sender_ip_is_zero = '1') then
                m_tvalid_i <= '0';      -- nothing to do

              ----------------------------------------------
              -- Convert Gratuitous ARP Request to ARP Reply
              -- Case Unicast (ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_UNICAST) and Case static arp table (ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_STATIC_TABLE)
              -- => is similar case of "target_ip = LOCAL_IP_ADDR"

              -- Case Unicast and Broadcast
              elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_BROADCAST_UNICAST then
                if (sender_ip_is_target_ip = '1') and ((target_mac_is_broadcast = '1') or (target_mac_is_zero = '1')) then
                  M_TUSER(0) <= C_ARP_REPLY;
                  m_tvalid_i <= '1';
                end if;

              -- Case No filter
              elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_NO_FILTER then
                M_TUSER(0) <= C_ARP_REPLY;
                m_tvalid_i <= '1';
              end if;

            -- ****************************************************************************************
            -- Operation code : REPLY : Depends on ARP_RX_TARGET_IP_FILTER
            elsif opcode = C_ARP_OPCODE_REPLY then
              M_TUSER(0) <= C_ARP_REPLY;

              if ARP_SELF_ID_DONE /= '1' then -- cas arp_probe not done : accept temporarily at startup arp_probe_reply when ko (nota target ip = 0)
                m_tvalid_i <= '1';

              -- Case Unicast only
              elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_UNICAST then
                if (target_ip_is_local = '1') then
                  m_tvalid_i <= '1';
                end if;

              -- Case Unicast and Broadcast
              elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_BROADCAST_UNICAST then
                if (target_ip_is_local = '1') or (target_ip_is_broadcast = '1') or (target_ip_is_zero = '1') then
                  m_tvalid_i <= '1';
                end if;

              -- Case No filter
              elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_NO_FILTER then
                m_tvalid_i <= '1';

                -- Case static arp table  => No reply is transmit to ARP Controller
                -- elsif ARP_RX_TARGET_IP_FILTER = C_ARP_FILTER_STATIC_TABLE then
              end if;

            end if;
          end if;
        end if;

      end if;
    end if;
  end process P_ARP_DECODER;

end rtl;
