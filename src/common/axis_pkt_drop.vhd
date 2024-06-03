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

use work.axis_utils_pkg.axis_fifo;

------------------------------------------------
-- AXIS PKT DROP
------------------------------------------------

entity axis_pkt_drop is
  generic(
    G_ACTIVE_RST    : std_logic                         := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST     : boolean                           := false; -- Type of reset used (synchronous or asynchronous resets)
    G_COMMON_CLK    : boolean                           := true; -- 2 or 1 clock domain
    G_TDATA_WIDTH   : positive                          := 64; -- Width of the tdata vector of the stream
    G_TUSER_WIDTH   : positive                          := 1; -- Width of the tuser vector of the stream
    G_TID_WIDTH     : positive                          := 1; -- Width of the tid vector of the stream
    G_TDEST_WIDTH   : positive                          := 1; -- Width of the tdest vector of the stream
    G_RAM_STYLE   : string                              := "AUTO"; -- Specify the ram synthesis style (technology dependant)
    G_ADDR_WIDTH    : positive                          := 10; -- FIFO address width (depth is 2**ADDR_WIDTH)
    G_PKT_THRESHOLD : positive range 2 to positive'high := 2; -- Maximum number of packet into the fifo
    G_SYNC_STAGE  : integer range 2 to integer'high     := 2 -- Number of synchronization stages (to reduce MTBF)
  );
  port(
    -- Slave interface
    S_CLK    : in  std_logic;           -- Global clock, signals are samples at rising edge
    S_RST    : in  std_logic;           -- Global reset depends on configuration
    S_TDATA  : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY : out std_logic;
    -- Status (S_CLK domain)
    DROP     : out std_logic;
    -- master interface
    M_CLK    : in  std_logic;           -- Global clock, signals are samples at rising edge
    M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID : out std_logic;
    M_TLAST  : out std_logic;
    M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY : in  std_logic
  );
end axis_pkt_drop;

architecture rtl of axis_pkt_drop is

  ------------------------------
  -- Constants declaration
  ------------------------------

  constant C_PKT_WIDTH : integer := integer(ceil(log2(1.0 + real(G_PKT_THRESHOLD))));

  ------------------------------
  -- Signals declaration
  ------------------------------

  -- Internal axis signals
  signal s_tready_i : std_logic;
  signal m_tvalid_i : std_logic;
  signal m_tlast_i  : std_logic;

  -- Fifo Data
  signal axis_fifo_data_in_tvalid : std_logic;
  signal axis_fifo_data_in_tready : std_logic;

  -- Fifo Others
  signal axis_fifo_others_in_tvalid  : std_logic;
  signal axis_fifo_others_out_tready : std_logic;

  -- control
  signal pkt_count        : std_logic_vector(C_PKT_WIDTH - 1 downto 0);
  signal sop              : std_logic;  -- Start of packet
  signal load_in_progress : std_logic;
  signal drop_packet      : std_logic;

begin

  -- select FIFO or drop new packet asynchronously
  axis_fifo_data_in_tvalid   <= S_TVALID and (not drop_packet);
  axis_fifo_others_in_tvalid <= S_TVALID and (not drop_packet) and sop;

  s_tready_i <= axis_fifo_data_in_tready or drop_packet;
  S_TREADY   <= s_tready_i;

  -- Store data into fifo 
  inst_axis_fifo_data : axis_fifo
    generic map(
      G_COMMON_CLK  => G_COMMON_CLK,
      G_ADDR_WIDTH  => G_ADDR_WIDTH,
      G_TDATA_WIDTH => G_TDATA_WIDTH,
      G_TUSER_WIDTH => G_TUSER_WIDTH,
      G_TID_WIDTH   => G_TID_WIDTH,
      G_TDEST_WIDTH => G_TDEST_WIDTH,
      G_PKT_WIDTH   => C_PKT_WIDTH,
      G_RAM_STYLE   => G_RAM_STYLE,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => G_SYNC_STAGE
    )
    port map(
      S_CLK        => S_CLK,
      S_RST        => S_RST,
      S_TDATA      => S_TDATA,
      S_TVALID     => axis_fifo_data_in_tvalid,
      S_TLAST      => S_TLAST,
      S_TUSER      => S_TUSER,
      S_TSTRB      => S_TSTRB,
      S_TKEEP      => S_TKEEP,
      S_TREADY     => axis_fifo_data_in_tready,
      M_CLK        => M_CLK,
      M_TDATA      => M_TDATA,
      M_TVALID     => m_tvalid_i,
      M_TLAST      => m_tlast_i,
      M_TUSER      => M_TUSER,
      M_TSTRB      => M_TSTRB,
      M_TKEEP      => M_TKEEP,
      M_TREADY     => M_TREADY,
      WR_PKT_COUNT => pkt_count
    );

  -- Store other signals into fifo
  inst_axis_fifo_others : axis_fifo
    generic map(
      G_COMMON_CLK  => G_COMMON_CLK,
      G_ADDR_WIDTH  => C_PKT_WIDTH,
      G_TDATA_WIDTH => 1,
      G_TUSER_WIDTH => 1,
      G_TID_WIDTH   => G_TID_WIDTH,
      G_TDEST_WIDTH => G_TDEST_WIDTH,
      G_RAM_STYLE   => G_RAM_STYLE,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_SYNC_STAGE  => G_SYNC_STAGE
    )
    port map(
      S_CLK    => S_CLK,
      S_RST    => S_RST,
      S_TVALID => axis_fifo_others_in_tvalid,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => open,
      M_CLK    => M_CLK,
      M_TVALID => open,
      M_TID    => M_TID,
      M_TDEST  => M_TDEST,
      M_TREADY => axis_fifo_others_out_tready
    );

  axis_fifo_others_out_tready <= m_tvalid_i and M_TREADY and m_tlast_i;

  -- Assignment
  M_TVALID <= m_tvalid_i;
  M_TLAST  <= m_tlast_i;

  -- Handle the dropping of frames
  p_drop : process(S_CLK, S_RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (S_RST = G_ACTIVE_RST) then
      sop              <= '1';
      load_in_progress <= '0';
      drop_packet      <= '0';
      DROP             <= '0';
    elsif rising_edge(S_CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (S_RST = G_ACTIVE_RST) then
        sop              <= '1';
        load_in_progress <= '0';
        drop_packet      <= '0';
        DROP             <= '0';
      else

        -- Clear pulse
        DROP <= '0';

        if (S_TVALID = '1') and (s_tready_i = '1') then
          sop <= '0';
          --update at the end of current packet
          if (S_TLAST = '1') then
            sop              <= '1';
            load_in_progress <= '0';

            -- if more than PACKET_THRESHOLD in memory and no packet in progress --> drop next packet 
            if unsigned(pkt_count) >= (to_unsigned(G_PKT_THRESHOLD, pkt_count'length) - 1) then
              drop_packet <= '1';
            else
              drop_packet <= '0';
            end if;

            -- Generate pulse
            if (drop_packet = '1') then
              DROP <= '1';
            end if;
          else
            load_in_progress <= '1';
          end if;
        -- update immediatly if there is no packet in progress
        elsif (load_in_progress /= '1') and (unsigned(pkt_count) < (to_unsigned(G_PKT_THRESHOLD, pkt_count'length))) then
          -- Clear drop_packet flag if pkt_count is lower than threshold
          drop_packet <= '0';
        end if;
      end if;
    end if;
  end process p_drop;

end rtl;
