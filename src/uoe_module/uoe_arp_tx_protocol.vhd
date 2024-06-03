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
-- ARP TX PROTOCOL
----------------------------------
--
-- This module is used to generate a request or reply ARP frame
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_arp_tx_protocol is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Number of bits used along AXI datapath of UOE
  );
  port(
    -- Clock & reset
    CLK            : in  std_logic;
    RST            : in  std_logic;
    -- Ethernet Frame router interface
    M_TDATA        : out std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
    M_TVALID       : out std_logic;
    M_TLAST        : out std_logic;
    M_TKEEP        : out std_logic_vector((((G_TDATA_WIDTH + 7) / 8) - 1) downto 0);
    M_TREADY       : in  std_logic;
    --Interface with ARP Controller
    S_CTRL_TDATA   : in  std_logic_vector(79 downto 0); -- (79..32) Target MAC Addr., (31..0) Target IP Addr.
    S_CTRL_TVALID  : in  std_logic;
    S_CTRL_TUSER   : in  std_logic_vector(0 downto 0);  -- 0 => Request, 1 => Reply
    S_CTRL_TREADY  : out std_logic;
    -- Registers interface
    LOCAL_IP_ADDR  : in  std_logic_vector(31 downto 0);
    LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0)
  );
end uoe_arp_tx_protocol;

architecture rtl of uoe_arp_tx_protocol is

  -------------------------------
  -- Constants declaration
  -------------------------------

  constant C_TKEEP_WIDTH    : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_ARP_FRAME_SIZE : integer := 60;
  constant C_CNT_MAX        : integer := integer(ceil(real(C_ARP_FRAME_SIZE) / real(C_TKEEP_WIDTH)));

  -------------------------------
  -- Signals declaration
  -------------------------------

  signal dest_addr : std_logic_vector(47 downto 0);
  signal opcode : std_logic_vector(15 downto 0);
  signal cnt       : integer range 0 to C_CNT_MAX;

  signal m_tvalid_i : std_logic;

begin

  -- Assignement
  M_TVALID <= m_tvalid_i;

  -- Handle header generation
  p_protocol_arp : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      S_CTRL_TREADY <= '0';
      M_TDATA       <= (others => '0');
      m_tvalid_i    <= '0';
      M_TLAST       <= '0';
      M_TKEEP       <= (others => '0');
      cnt           <= 0;
      dest_addr     <= (others => '0');
      opcode     <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        S_CTRL_TREADY <= '0';
        M_TDATA       <= (others => '0');
        m_tvalid_i    <= '0';
        M_TLAST       <= '0';
        M_TKEEP       <= (others => '0');
        cnt           <= 0;
        dest_addr     <= (others => '0');
        opcode     <= (others => '0');

      else

        -- Clear pulse
        S_CTRL_TREADY <= '0';

        if (M_TREADY = '1') or (m_tvalid_i /= '1') then

          -- A new control transfer is asserted
          if (S_CTRL_TVALID = '1') and (cnt = 0) then
            -- Start emission of ARP
            m_tvalid_i <= '1';
            cnt        <= 1;
  
            if S_CTRL_TDATA(79 downto 32) = C_ARP_BROADCAST_MAC then
              dest_addr <= C_ARP_BROADCAST_TARGET;
            else
              dest_addr <= S_CTRL_TDATA(79 downto 32);
            end if;
            
            if S_CTRL_TUSER(0) = C_ARP_REPLY then
              opcode <= C_ARP_OPCODE_REPLY;
            else
              opcode <= C_ARP_OPCODE_REQUEST;
            end if;
              
          end if;

          -- Counter
          if (cnt = C_CNT_MAX) then
            cnt        <= 0;
            m_tvalid_i <= '0';
            M_TLAST    <= '0';

          elsif cnt /= 0 then
            cnt <= cnt + 1;
          end if;

          -- Assert TLAST
          if (cnt = (C_CNT_MAX - 1)) then
            M_TLAST       <= '1';
            S_CTRL_TREADY <= '1';
          end if;

          -- TDATA and TKEEP
          for i in 0 to C_TKEEP_WIDTH - 1 loop
            -- Little Endian
            case ((cnt * C_TKEEP_WIDTH) + i) is
              -- Big Endian
              --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
              when 0  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(79 downto 72);
              when 1  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(71 downto 64);
              when 2  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(63 downto 56);
              when 3  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(55 downto 48);
              when 4  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(47 downto 40);
              when 5  => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(39 downto 32);
              when 6  => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(47 downto 40);
              when 7  => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(39 downto 32);
              when 8  => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(31 downto 24);
              when 9  => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(23 downto 16);
              when 10 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(15 downto 8);
              when 11 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(7 downto 0);
              when 12 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ETHERTYPE_ARP(15 downto 8);
              when 13 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ETHERTYPE_ARP(7 downto 0);
              when 14 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ARP_HW_TYPE(15 downto 8);
              when 15 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ARP_HW_TYPE(7 downto 0);
              when 16 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ETHERTYPE_IPV4(15 downto 8);
              when 17 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ETHERTYPE_IPV4(7 downto 0);
              when 18 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ARP_HW_ADDR_LENGTH;
              when 19 => M_TDATA((8 * i) + 7 downto 8 * i) <= C_ARP_PROTOCOL_ADDR_LENGTH;
              when 20 => M_TDATA((8 * i) + 7 downto 8 * i) <= opcode(15 downto 8);
              when 21 => M_TDATA((8 * i) + 7 downto 8 * i) <= opcode(7 downto 0);
              when 22 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(47 downto 40);
              when 23 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(39 downto 32);
              when 24 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(31 downto 24);
              when 25 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(23 downto 16);
              when 26 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(15 downto 8);
              when 27 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(7 downto 0);
              when 28 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_IP_ADDR(31 downto 24);
              when 29 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_IP_ADDR(23 downto 16);
              when 30 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_IP_ADDR(15 downto 8);
              when 31 => M_TDATA((8 * i) + 7 downto 8 * i) <= LOCAL_IP_ADDR(7 downto 0);
              when 32 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(47 downto 40);
              when 33 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(39 downto 32);
              when 34 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(31 downto 24);
              when 35 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(23 downto 16);
              when 36 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(15 downto 8);
              when 37 => M_TDATA((8 * i) + 7 downto 8 * i) <= dest_addr(7 downto 0);
              when 38 => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(31 downto 24);
              when 39 => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(23 downto 16);
              when 40 => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(15 downto 8);
              when 41 => M_TDATA((8 * i) + 7 downto 8 * i) <= S_CTRL_TDATA(7 downto 0);
              when others =>
                M_TDATA((8 * i) + 7 downto 8 * i) <= (others => '0');
            end case;

            -- Little Endian
            if ((cnt * C_TKEEP_WIDTH) + i) < C_ARP_FRAME_SIZE then
              -- Big Endian
              --if ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) < 14 then
              M_TKEEP(i) <= '1';
            else
              M_TKEEP(i) <= '0';
            end if;
          end loop;
        end if;

      end if;
    end if;
  end process p_protocol_arp;

end rtl;
