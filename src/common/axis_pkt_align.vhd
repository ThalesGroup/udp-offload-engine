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
-- AXIS_PKT_ALIGN
--
----------------------------------------------------------------------------------
--
-- This module aims at aligning a packet on the first byte of the first valid transfer of the packet
-- It is considered that all the bytes of the frame are contiguous
--
-- On the first valid transfer of the packet, it searches the position of the first valid byte.
-- This position is then used to shift all bytes of the packet
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axis_utils_pkg.axis_register;

entity axis_pkt_align is
  generic(
    G_ACTIVE_RST    : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST     : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH   : positive  := 64;  -- Width of the data bus
    G_TUSER_WIDTH   : positive  := 1;   -- Width of the tuser vector of the stream
    G_TID_WIDTH     : positive  := 1;   -- Width of the tid vector of the stream
    G_TDEST_WIDTH   : positive  := 1;   -- Width of the tdest vector of the stream
    G_LITTLE_ENDIAN : boolean   := true -- Whether endianness is little or big
  );
  port(
    -- Clocks and resets
    CLK      : in  std_logic;
    RST      : in  std_logic;
    -- Input
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY : out std_logic;
    -- Output
    M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID : out std_logic;
    M_TLAST  : out std_logic;
    M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY : in  std_logic;
    -- Error Flag
    ERR      : out std_logic
  );
begin
  -- synthesis translate_off
  assert (G_TDATA_WIDTH mod 8) = 0 report "TDATA is not a multiple of byte" severity failure;
  -- synthesis translate_on
end axis_pkt_align;

architecture rtl of axis_pkt_align is

  ----------------------------
  -- Functions declaration
  ----------------------------

  -- returns the index of the first bit equal to val in the input vector, starting from its low index
  function find_first(constant data : in std_logic_vector; constant val : in std_logic := '1'; constant start_high : in boolean := True) return integer is
    variable v_idx : integer range -1 to data'high; -- std_logic_vector is defined using a natural index range
  begin
    v_idx := -1;                        -- default value if not found (std_logic_vector is only defined with a natural indexing)
    if start_high then
      for i in data'high downto data'low loop
        if data(i) = val then
          v_idx := i;
          exit;
        end if;
      end loop;
    else
      for i in data'low to data'high loop
        if data(i) = val then
          v_idx := i;
          exit;
        end if;
      end loop;
    end if;
    -- Same function of dev_utils with assert removed.
    --assert v_idx > (-1) report "Bit value not found" severity error;
    return v_idx;
  end function find_first;

  ----------------------------
  -- Constants declaration
  ----------------------------

  constant C_TKEEP_WIDTH : positive := (G_TDATA_WIDTH + 7) / 8;
  constant C_TSTRB_WIDTH : positive := (G_TDATA_WIDTH + 7) / 8;

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    tstrb  : std_logic_vector(C_TSTRB_WIDTH - 1 downto 0);
    tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
    tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
    tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    tvalid : std_logic;
  end record t_forward_data;

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  -- constant for record initialization
  constant C_FORWARD_DATA_INIT : t_forward_data := (
    tdata  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast  => '0',                      -- could be anything because the tvalid signal is 0
    tuser  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tstrb  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tid    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tdest  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  ----------------------------
  -- Signals declaration
  ----------------------------

  -- start of frame flag used to indicate the next transfer is a first transfer of a packet
  signal sof : std_logic;

  signal pos_start : integer range -1 to C_TKEEP_WIDTH - 1;
  signal pos_reg   : integer range -1 to C_TKEEP_WIDTH - 1;
  signal pos_end   : integer range -1 to C_TKEEP_WIDTH - 1;

  -- axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  -- axis bus at output
  signal m_int        : t_forward_data;
  signal m_int_tready : std_logic;

  signal buf_tdata : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal buf_tkeep : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
  signal buf_tstrb : std_logic_vector(C_TSTRB_WIDTH - 1 downto 0);

  signal flag_remainder : std_logic;

begin

  -- connecting output bus to the records
  M_TDATA      <= m_int.tdata;
  M_TLAST      <= m_int.tlast;
  M_TUSER      <= m_int.tuser;
  M_TSTRB      <= m_int.tstrb;
  M_TKEEP      <= m_int.tkeep;
  M_TID        <= m_int.tid;
  M_TDEST      <= m_int.tdest;
  M_TVALID     <= m_int.tvalid;
  m_int_tready <= M_TREADY;

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
  --  Alignment (FORWARD Path)
  --
  -----------------------------------------------------

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= (m_int_tready or (not m_int.tvalid)) and (not flag_remainder);

  -- Find first valid byte
  pos_start <= find_first(data => mid.tkeep, val => '1', start_high => not G_LITTLE_ENDIAN);

  -- Find first null byte
  pos_end <= find_first(data => mid.tkeep, val => '0', start_high => not G_LITTLE_ENDIAN);

  -- Handle Valid Alignment
  P_ALIGN : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      sof            <= '1';
      pos_reg        <= 0;
      buf_tdata      <= (others => '0');
      buf_tkeep      <= (others => '0');
      buf_tstrb      <= (others => '0');
      m_int          <= C_FORWARD_DATA_INIT;
      flag_remainder <= '0';
      ERR            <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        sof            <= '1';
        pos_reg        <= 0;
        buf_tdata      <= (others => '0');
        buf_tkeep      <= (others => '0');
        buf_tstrb      <= (others => '0');
        m_int          <= C_FORWARD_DATA_INIT;
        flag_remainder <= '0';
        ERR            <= '0';

      else

        -- Clear error pulse
        ERR   <= '0';

        if (m_int_tready = '1') or (m_int.tvalid /= '1') then
          -- Clear handshake
          m_int.tvalid <= '0';
          m_int.tlast  <= '0';

          -- Output the remaining data
          if (flag_remainder = '1') then
            m_int.tvalid   <= '1';
            m_int.tlast    <= '1';
            flag_remainder <= '0';

          elsif (mid.tvalid = '1') then
            -- Bufferized data
            buf_tdata <= mid.tdata;
            buf_tkeep <= mid.tkeep;
            buf_tstrb <= mid.tstrb;

            -- On start of frame, register position of the first valid byte
            if sof = '1' then
              sof         <= '0';
              pos_reg     <= pos_start;
              m_int.tuser <= mid.tuser;
              m_int.tid   <= mid.tid;
              m_int.tdest <= mid.tdest;
            else
              m_int.tvalid <= '1';
              if (m_int.tuser /= mid.tuser) or (m_int.tid /= mid.tid) or (m_int.tdest /= mid.tdest) then
                ERR <= '1';
              end if;
            end if;

            -- Re-assert sof on tlast
            if mid.tlast = '1' then
              sof <= '1';
            end if;

            if (mid.tlast = '1') then
              -- Generate last when no remaining data
              -- excluding case where last transfer is the first transfer (pos_reg is not valid)
              if (sof /= '1') and (pos_end >= 0) and ((G_LITTLE_ENDIAN and (pos_end <= pos_reg)) or ((not G_LITTLE_ENDIAN) and (pos_reg <= pos_end))) then
                m_int.tlast <= '1';
              -- There are remaining data => assert flag_remainder
              else
                flag_remainder <= '1';
              end if;
            end if;

          end if;

          -- Little Endian
          if G_LITTLE_ENDIAN then
            for i in 0 to C_TKEEP_WIDTH - 1 loop
              -- Put the registered bytes on the first indexes
              if i < (C_TKEEP_WIDTH - pos_reg) then
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= buf_tdata((8 * (i + pos_reg)) + 7 downto (8 * (i + pos_reg)));
                m_int.tkeep(i)                          <= buf_tkeep(i + pos_reg);
                m_int.tstrb(i)                          <= buf_tstrb(i + pos_reg);

              -- In case of last word, force bytes to '0'
              elsif flag_remainder = '1' then
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= (others => '0');
                m_int.tkeep(i)                          <= '0';
                m_int.tstrb(i)                          <= '0';

              -- In others case, put the incoming bytes
              else
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= mid.tdata((8 * (i - (C_TKEEP_WIDTH - pos_reg))) + 7 downto (8 * (i - (C_TKEEP_WIDTH - pos_reg))));
                m_int.tkeep(i)                          <= mid.tkeep(i - (C_TKEEP_WIDTH - pos_reg));
                m_int.tstrb(i)                          <= mid.tstrb(i - (C_TKEEP_WIDTH - pos_reg));
              end if;
            end loop;

          -- Big Endian
          else
            for i in C_TKEEP_WIDTH - 1 downto 0 loop
              -- Put the registered bytes on the first indexes
              if ((C_TKEEP_WIDTH - 1) - i) <= pos_reg then
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= buf_tdata((8 * ((i + pos_reg) - (C_TKEEP_WIDTH - 1))) + 7 downto (8 * ((i + pos_reg) - (C_TKEEP_WIDTH - 1))));
                m_int.tkeep(i)                          <= buf_tkeep((i + pos_reg) - (C_TKEEP_WIDTH - 1));
                m_int.tstrb(i)                          <= buf_tstrb((i + pos_reg) - (C_TKEEP_WIDTH - 1));

              -- In case of last word, force bytes to '0'
              elsif flag_remainder = '1' then
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= (others => '0');
                m_int.tkeep(i)                          <= '0';
                m_int.tstrb(i)                          <= '0';

              -- In others case, put the incoming bytes
              else
                m_int.tdata((8 * i) + 7 downto (8 * i)) <= mid.tdata((8 * ((i + pos_reg) + 1)) + 7 downto (8 * ((i + pos_reg) + 1)));
                m_int.tkeep(i)                          <= mid.tkeep((i + pos_reg) + 1);
                m_int.tstrb(i)                          <= mid.tstrb((i + pos_reg) + 1);
              end if;

            end loop;
          end if;
        end if;

      end if;
    end if;
  end process P_ALIGN;

end rtl;

