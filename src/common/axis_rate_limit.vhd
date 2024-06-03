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

----------------------------------------------------------------------------------
--
-- AXIS_RATE_LIMIT
--
----------------------------------------------------------------------------------
--
-- This module is used to limit the rate on an AXI4-Stream link.
-- It consists in allowing a limited number of transfers during a time window expressed as number of clock period.
--
-- The maximum rate is given by the following formula:
--    Max Rate = Clock Frequency x (NB_TRANSFERS / WINDOW_SIZE)
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axis_utils_pkg.axis_register;

entity axis_rate_limit is
  generic(
    G_ACTIVE_RST   : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST    : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH  : positive  := 32;    -- Width of the tdata vector of the stream
    G_TUSER_WIDTH  : positive  := 1;     -- Width of the tuser vector of the stream
    G_TID_WIDTH    : positive  := 1;     -- Width of the tid vector of the stream
    G_TDEST_WIDTH  : positive  := 1;     -- Width of the tdest vector of the stream
    G_WINDOW_WIDTH : positive  := 8      -- Width of the internal counters
  );
  port(
    -- Global
    CLK          : in  std_logic;       -- Clock
    RST          : in  std_logic;       -- Reset
    -- Parameters
    NB_TRANSFERS : in  std_logic_vector(G_WINDOW_WIDTH - 1 downto 0);
    WINDOW_SIZE  : in  std_logic_vector(G_WINDOW_WIDTH - 1 downto 0);
    -- Axi4-stream slave
    S_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID     : in  std_logic;
    S_TLAST      : in  std_logic;
    S_TUSER      : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID        : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST      : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY     : out std_logic;
    -- Axi4-stream master
    M_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID     : out std_logic;
    M_TLAST      : out std_logic;
    M_TUSER      : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID        : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST      : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY     : in  std_logic
  );
end axis_rate_limit;

architecture rtl of axis_rate_limit is

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- Record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    tstrb  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    tkeep  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
    tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    tvalid : std_logic;
  end record t_forward_data;

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  -- Constant for record initialization
  constant C_FORWARD_DATA_INIT : t_forward_data := (
    tdata  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tlast  => '0',                      -- Could be anything because the tvalid signal is 0
    tuser  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tstrb  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tid    => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tdest  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tvalid => '0'                       -- Data are not valid at initialization
  );

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- Axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  -- Axis bus at output
  signal m_int        : t_forward_data;
  signal m_tready_int : std_logic;

  -- Counter
  signal cnt_win   : unsigned(G_WINDOW_WIDTH - 1 downto 0);
  signal cnt_trans : unsigned(G_WINDOW_WIDTH - 1 downto 0);
  signal pending   : std_logic;
  signal enable    : std_logic;

begin

  -- Connect output bus to the records
  M_TDATA      <= m_int.tdata;
  M_TLAST      <= m_int.tlast;
  M_TUSER      <= m_int.tuser;
  M_TSTRB      <= m_int.tstrb;
  M_TKEEP      <= m_int.tkeep;
  M_TID        <= m_int.tid;
  M_TDEST      <= m_int.tdest;
  M_TVALID     <= m_int.tvalid;
  m_tready_int <= M_TREADY;

  -----------------------------------------------------
  --
  --   BACKWARD Register
  --
  -----------------------------------------------------
  inst_axis_register_backward : axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TUSER_WIDTH    => G_TUSER_WIDTH,
      G_TID_WIDTH      => G_TID_WIDTH,
      G_TDEST_WIDTH    => G_TDEST_WIDTH,
      G_REG_FORWARD    => false,
      G_REG_BACKWARD   => true,
      G_FULL_BANDWIDTH => true
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TUSER  => S_TUSER,
      S_TSTRB  => S_TSTRB,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => S_TREADY,
      M_TDATA  => mid.tdata,
      M_TVALID => mid.tvalid,
      M_TLAST  => mid.tlast,
      M_TUSER  => mid.tuser,
      M_TSTRB  => mid.tstrb,
      M_TKEEP  => mid.tkeep,
      M_TID    => mid.tid,
      M_TDEST  => mid.tdest,
      M_TREADY => mid_tready
    );

  -----------------------------------------------------
  --
  --   Rate limitation (FORWARD Path)
  --
  -----------------------------------------------------

  -- Asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= (m_tready_int or (not m_int.tvalid)) and (not pending);

  pending <= '1' when cnt_trans = 0 else '0';

  ----------------------
  -- P_RATE_LIMIT
  ----------------------
  -- Synchronous process to limit the rate on the forward path
  ----------------------
  P_RATE_LIMIT : process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- Asynchronous reset
      m_int     <= C_FORWARD_DATA_INIT;
      cnt_win   <= (others => '0');
      cnt_trans <= (others => '0');
      enable    <= '0';

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        m_int     <= C_FORWARD_DATA_INIT;
        cnt_win   <= (others => '0');
        cnt_trans <= (others => '0');
        enable    <= '0';

      else

        -- Register
        if mid_tready = '1' then
          -- May acquire new data
          if mid.tvalid = '1' then
            -- Register the bus when data are valid
            m_int <= mid;

            -- Decrement Transfer counter
            cnt_trans <= cnt_trans - 1;

          else
            -- Change only valid state to avoid logic toggling (and save power)
            m_int.tvalid <= '0';
          end if;

        else

          -- Clear handshake
          if m_tready_int = '1' then
            m_int.tvalid <= '0';
          end if;

        end if;

        -- Enable if parameters are valid
        if (unsigned(WINDOW_SIZE) /= 0) and (unsigned(NB_TRANSFERS) /= 0) and (unsigned(NB_TRANSFERS) <= unsigned(WINDOW_SIZE)) then
          enable <= '1';
        else
          enable <= '0';
        end if;

        -- Window counter
        if enable = '1' then
          if cnt_win = 0  then
            cnt_win   <= (unsigned(WINDOW_SIZE) - 1);
            cnt_trans <= unsigned(NB_TRANSFERS);
          else
            cnt_win <= cnt_win - 1;
          end if;

        else
          cnt_trans <= (others => '1');
          cnt_win   <= (others => '0');
        end if;


      end if;
    end if;
  end process P_RATE_LIMIT;

end rtl;
