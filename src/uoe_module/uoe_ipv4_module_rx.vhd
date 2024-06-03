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
-- IPV4 MODULE RX
----------------------------------
--
-- This module is used to remove IPV4 Header from incoming frame
-- Moreover, it remove the padding inserted to reach the minimum ethernet size 
-- and reconstruct the defragmented frame
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_ipv4_module_rx is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Width of the data bus
  );
  port(
    CLK                       : in  std_logic;
    RST                       : in  std_logic;
    -- Input data from link layer
    S_TDATA                   : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID                  : in  std_logic;
    S_TLAST                   : in  std_logic;
    S_TKEEP                   : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TREADY                  : out std_logic;
    -- Output data to transport layer
    M_TDATA                   : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID                  : out std_logic;
    M_TLAST                   : out std_logic;
    M_TKEEP                   : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID                     : out std_logic_vector(7 downto 0); -- Protocol
    M_TUSER                   : out std_logic_vector(31 downto 0); -- Sender IP
    M_TREADY                  : in  std_logic;
    -- Error
    IPV4_RX_FRAG_OFFSET_ERROR : out std_logic -- pulse
  );
end entity uoe_ipv4_module_rx;

architecture rtl of uoe_ipv4_module_rx is

  ----------------------------
  -- Constants declaration
  ----------------------------

  constant C_TUSER_WIDTH      : positive := 32; -- Sender IP
  constant C_TID_WIDTH        : positive := 8;  -- Protocol
  constant C_TKEEP_WIDTH      : positive := ((G_TDATA_WIDTH + 7) / 8);
  constant C_LOG2_TKEEP_WIDTH : integer  := integer(ceil(log2(real(C_TKEEP_WIDTH))));
  -- TODO Add assert to check if TKEEP width is a power of 2

  -- Minimum size of the header is 5 words (32-bit)
  constant C_HEADER_LENGTH_MIN : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(5, 4));

  constant C_LOG2_MAX_PACKET_SIZE_WORDS : positive := integer(ceil(log2(real(C_IPV4_MAX_PACKET_SIZE) / real(C_TKEEP_WIDTH))));

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
    tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
    tid    : std_logic_vector(C_TID_WIDTH - 1 downto 0);
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
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tid    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  ----------------------------
  -- Signals declaration
  ----------------------------

  -- axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  -- axis bus at output
  signal m_int        : t_forward_data;
  signal m_int_tready : std_logic;

  signal cnt : unsigned(C_LOG2_MAX_PACKET_SIZE_WORDS - 1 downto 0);

  ----------------------------
  -- Signals declaration
  ----------------------------

  -- Extract value from header
  signal header_length : std_logic_vector(3 downto 0); -- in 32-bit words
  signal total_length  : std_logic_vector(15 downto 0);
  signal frag_more     : std_logic;
  signal frag_offset   : std_logic_vector(12 downto 0);

  signal header_length_words : unsigned(C_LOG2_MAX_PACKET_SIZE_WORDS - 1 downto 0);
  signal header_length_rest  : unsigned(C_LOG2_TKEEP_WIDTH downto 0);
  signal total_length_words  : unsigned(C_LOG2_MAX_PACKET_SIZE_WORDS - 1 downto 0);
  signal total_length_rest   : unsigned(C_LOG2_TKEEP_WIDTH downto 0);

  signal frag_offset_reg : std_logic_vector(12 downto 0);
  --signal frame_id : std_logic_vector(15 downto 0);

begin
  

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
      S_TKEEP  => S_TKEEP,
      S_TREADY => S_TREADY,
      M_TDATA  => mid.tdata,
      M_TVALID => mid.tvalid,
      M_TLAST  => mid.tlast,
      M_TKEEP  => mid.tkeep,
      M_TREADY => mid_tready
    );

  -----------------------------------------------------
  --
  --   FORWARD
  --
  -----------------------------------------------------

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= m_int_tready or (not m_int.tvalid);

  -------------------------------------------------
  -- Handle header and padding remove
  P_REMOVE_HEADER_PADDING : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      m_int                     <= C_FORWARD_DATA_INIT;
      header_length             <= C_HEADER_LENGTH_MIN;
      total_length              <= (others => '0');
      frag_more                 <= '0';
      frag_offset               <= (others => '0');
      frag_offset_reg           <= (others => '0');
      cnt                       <= (others => '0');
      --frame_id      <= (others => '0');
      IPV4_RX_FRAG_OFFSET_ERROR <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        m_int                     <= C_FORWARD_DATA_INIT;
        header_length             <= C_HEADER_LENGTH_MIN;
        total_length              <= (others => '0');
        frag_more                 <= '0';
        frag_offset               <= (others => '0');
        frag_offset_reg           <= (others => '0');
        cnt                       <= (others => '0');
        IPV4_RX_FRAG_OFFSET_ERROR <= '0';

      else
        -- Clear pulse 
        IPV4_RX_FRAG_OFFSET_ERROR <= '0';

        -- Clear TVALID
        if mid_tready = '1' then

          m_int.tvalid <= '0';

          if mid.tvalid = '1' then
            m_int.tdata <= mid.tdata;

            -- reset counter when tlast
            if (mid.tlast = '1') then
              cnt <= (others => '0');
            else
              cnt <= cnt + 1;
            end if;

            -- Search field in flow
            for i in 0 to C_TKEEP_WIDTH - 1 loop
              case (to_integer(cnt) * C_TKEEP_WIDTH) + i is
                -- Header Length
                when 0 => header_length <= mid.tdata((8 * i) + 3 downto (8 * i));
                -- Length
                when 2 => total_length(15 downto 8) <= mid.tdata((8 * i) + 7 downto (8 * i));
                when 3 => total_length(7 downto 0)  <= mid.tdata((8 * i) + 7 downto (8 * i));
                -- Fragment
                when 6 => frag_more                <= mid.tdata((8 * i) + 5);
                          frag_offset(12 downto 8) <= mid.tdata((8 * i) + 4 downto (8 * i));
                when 7 => frag_offset(7 downto 0)  <= mid.tdata((8 * i) + 7 downto (8 * i));
                -- Protocol
                when 9 => m_int.tid <= mid.tdata((8 * i) + 7 downto (8 * i));
                -- Sender IP
                when 12 => m_int.tuser(31 downto 24) <= mid.tdata((8 * i) + 7 downto (8 * i));
                when 13 => m_int.tuser(23 downto 16) <= mid.tdata((8 * i) + 7 downto (8 * i));
                when 14 => m_int.tuser(15 downto 8)  <= mid.tdata((8 * i) + 7 downto (8 * i));
                when 15 => m_int.tuser(7 downto 0)   <= mid.tdata((8 * i) + 7 downto (8 * i));
                when others =>
              end case;
            end loop;

            ------------------------------
            -- TLAST
            ------------------------------

            -- On the last fragment only
            if frag_more /= '1' then
              -- Total length is multiple of C_TKEEP_WIDTH
              if total_length_rest = 0 then
                if cnt = (total_length_words - 1) then
                  m_int.tlast <= '1';
                else
                  m_int.tlast <= '0';
                end if;
              else
                if cnt = total_length_words then
                  m_int.tlast <= '1';
                else
                  m_int.tlast <= '0';
                end if;
              end if;
            else
              m_int.tlast <= '0';
            end if;

            ------------------------------
            -- TVALID / TKEEP
            ------------------------------

            m_int.tkeep  <= (others => '1');
            m_int.tvalid <= '1';

            -- Remove Header or Padding
            if (cnt < header_length_words) or (cnt > total_length_words) or ((cnt = total_length_words) and (total_length_rest = 0)) then
              m_int.tkeep  <= (others => '0');
              m_int.tvalid <= '0';
            end if;

            -- Transition Header / Payload and Header length is not a multiple of C_TKEEP_WIDTH 
            if (cnt = header_length_words) and (header_length_rest /= 0) then
              for i in 0 to C_TKEEP_WIDTH - 1 loop
                if i < header_length_rest then
                  m_int.tkeep(i) <= '0';
                end if;
              end loop;
            end if;

            -- Transition Payload / Padding and Total length is multiple of C_TKEEP_WIDTH
            if (cnt = total_length_words) and (total_length_rest /= 0) then
              for i in 0 to C_TKEEP_WIDTH - 1 loop
                if i >= total_length_rest then
                  m_int.tkeep(i) <= '0';
                end if;
              end loop;
            end if;

            ------------------------------
            -- ERROR generated on tlast
            ------------------------------
            if (mid.tlast = '1') then

              -- Previous was a last
              if (unsigned(frag_offset_reg) /= unsigned(frag_offset)) then
                IPV4_RX_FRAG_OFFSET_ERROR <= '1';
              end if;

              -- Current is Last Frag
              if (frag_more /= '1') then
                frag_offset_reg <= (others => '0');

              else                      -- More Frag
                frag_offset_reg <= frag_offset;
              end if;
            end if;
          end if;

        end if;
      end if;
    end if;
  end process P_REMOVE_HEADER_PADDING;

  -- Compute length in number of words (G_TDATA_WIDTH) and rest in bytes 
  header_length_words <= resize(unsigned(header_length & "00") srl C_LOG2_TKEEP_WIDTH, C_LOG2_MAX_PACKET_SIZE_WORDS);
  header_length_rest  <= resize(unsigned(header_length & "00") mod C_TKEEP_WIDTH, C_LOG2_TKEEP_WIDTH + 1);

  total_length_words <= resize(unsigned(total_length) srl C_LOG2_TKEEP_WIDTH, C_LOG2_MAX_PACKET_SIZE_WORDS);
  total_length_rest  <= resize(unsigned(total_length) mod C_TKEEP_WIDTH, C_LOG2_TKEEP_WIDTH + 1);

  -- TODO : Alignment not working when several fragment

  -- IPv4 Header is multiple of 32 bits
  GEN_PKT_ALIGN : if G_TDATA_WIDTH > 32 generate

    -- Realign frame on first bytes of the first transfer
    inst_axis_pkt_align : axis_pkt_align
      generic map(
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_ASYNC_RST   => G_ASYNC_RST,
        G_TDATA_WIDTH => G_TDATA_WIDTH,
        G_TUSER_WIDTH => 32,
        G_TID_WIDTH   => 8
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => m_int.tdata,
        S_TVALID => m_int.tvalid,
        S_TLAST  => m_int.tlast,
        S_TUSER  => m_int.tuser,
        S_TKEEP  => m_int.tkeep,
        S_TID    => m_int.tid,
        S_TREADY => m_int_tready,
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TUSER  => M_TUSER,
        M_TKEEP  => M_TKEEP,
        M_TID    => M_TID,
        M_TREADY => M_TREADY
      );

  end generate GEN_PKT_ALIGN;

  -- No need pkt align in case 8, 16 or 32 bits
  GEN_NO_PKT_ALIGN : if G_TDATA_WIDTH <= 32 generate

    M_TDATA      <= m_int.tdata;
    M_TVALID     <= m_int.tvalid;
    M_TLAST      <= m_int.tlast;
    M_TUSER      <= m_int.tuser;
    M_TKEEP      <= m_int.tkeep;
    M_TID        <= m_int.tid;
    m_int_tready <= M_TREADY;

  end generate GEN_NO_PKT_ALIGN;

end rtl;
