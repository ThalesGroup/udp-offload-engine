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

use work.uoe_module_pkg.C_STATUS_INVALID;

----------------------------------
-- eth_generic_filter
----------------------------------
--
-- This module filter incoming frame following status value
--
----------------------------------

entity uoe_generic_filter is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Number of bits used along AXi datapath of UOE
  );
  port(
    -- Global
    CLK             : in  std_logic;
    RST             : in  std_logic;
    INIT_DONE       : in  std_logic;
    -- Slave interface
    S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID        : in  std_logic;
    S_TLAST         : in  std_logic;
    S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TREADY        : out std_logic;
    -- VALIDITY OF PACKET
    S_STATUS_TDATA  : in  std_logic;    -- '0' => Good packet, '1' => Bad packet
    S_STATUS_TVALID : in  std_logic;
    S_STATUS_TREADY : out std_logic;
    -- Slave interface
    M_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID        : out std_logic;
    M_TLAST         : out std_logic;
    M_TKEEP         : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TREADY        : in  std_logic;
    -- FLAG to indicate Frame has been filtered
    FLAG            : out std_logic
  );
end uoe_generic_filter;

architecture rtl of uoe_generic_filter is

  signal axis_init   : std_logic;
  signal init_done_r : std_logic;

  signal s_pkt_status_tready_i : std_logic;
  signal s_tready_int          : std_logic;
  signal m_tvalid_int          : std_logic;

  signal s_tready_en    : std_logic;
  signal frame_accepted : std_logic;

begin

  s_tready_int <= (M_TREADY or (not m_tvalid_int)) and s_tready_en;
  S_TREADY     <= s_tready_int;

  s_pkt_status_tready_i <= ((not s_tready_en) or (S_TVALID and s_tready_int and S_TLAST)) and (not axis_init);
  S_STATUS_TREADY       <= s_pkt_status_tready_i;

  M_TVALID <= m_tvalid_int;

  -- Control
  P_CTRL : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_init      <= '1';
      init_done_r    <= '0';
      M_TDATA        <= (others => '0');
      m_tvalid_int   <= '0';
      M_TLAST        <= '0';
      M_TKEEP        <= (others => '0');
      s_tready_en    <= '0';
      frame_accepted <= '0';
      FLAG           <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_init      <= '1';
        init_done_r    <= '0';
        M_TDATA        <= (others => '0');
        m_tvalid_int   <= '0';
        M_TLAST        <= '0';
        M_TKEEP        <= (others => '0');
        s_tready_en    <= '0';
        frame_accepted <= '0';
        FLAG           <= '0';
      else

        if axis_init = '1' then
          axis_init <= '0';
        end if;

        -- AXI4-Stream handshake
        if M_TREADY = '1' then
          m_tvalid_int <= '0';
        end if;

        -- clear pulse
        FLAG <= '0';

        -- Register Data bus
        if s_tready_int = '1' then
          -- may acquire new data
          if S_TVALID = '1' then
            -- register the bus when data are valid
            M_TDATA      <= S_TDATA;
            m_tvalid_int <= frame_accepted and init_done_r;
            M_TLAST      <= S_TLAST;
            M_TKEEP      <= S_TKEEP;

            if S_TLAST = '1' then
              s_tready_en <= '0';
              init_done_r <= INIT_DONE;
            end if;
          end if;
        else
          init_done_r <= INIT_DONE;
        end if;

        -- Read Status
        if (S_STATUS_TVALID = '1') and (s_pkt_status_tready_i = '1') then
          frame_accepted <= not S_STATUS_TDATA;
          s_tready_en    <= '1';
          if S_STATUS_TDATA = C_STATUS_INVALID then  -- Invalid frame
            FLAG <= '1';
          end if;
        end if;
      end if;
    end if;
  end process P_CTRL;

end rtl;

