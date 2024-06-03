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
-- AXIS_DWIDTH_CONVERTER
--
----------------------------------------------------------------------------------
-- This component is used to convert the size of an AXI Stream bus by serializing or parallelizing incoming data
----------
-- The entity is generic in data width and other signals of AXI-Stream.
--
-- If G_PIPELINE is enabled, both registers are introduced in input and output of the module on the forward path, and one register
-- is introduced in output on the backward path
--
-- Data width conversion is deduced from the size of the generics G_S_TDATA_WIDTH and G_M_TDATA_WIDTH.
--
--------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.dev_utils_pkg.find_first;

use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.is_bytes_align;

entity axis_dwidth_converter is
  generic(
    G_ACTIVE_RST      : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST       : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_S_TDATA_WIDTH   : positive  := 8;   -- Width of the input tdata vector of the stream
    G_M_TDATA_WIDTH   : positive  := 32;    -- Width of the output tdata vector of the stream
    G_TUSER_WIDTH     : positive  := 1;    -- Width of the tuser vector of the stream
    G_TID_WIDTH       : positive  := 1;    -- Width of the tid vector of the stream
    G_TDEST_WIDTH     : positive  := 1;    -- Width of the tdest vector of the stream
    G_PIPELINE        : boolean   := true; -- Whether to register the forward and backward path
    G_LITTLE_ENDIAN   : boolean   := true  -- Whether endianness is little or big
  );
  port(
    -- Global
    CLK         : in  std_logic;           -- Clock
    RST         : in  std_logic;           -- Reset
    -- Axi4-stream slave
    S_TDATA     : in  std_logic_vector(G_S_TDATA_WIDTH - 1 downto 0);
    S_TVALID    : in  std_logic;
    S_TLAST     : in  std_logic;
    S_TUSER     : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID       : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST     : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY    : out std_logic;
    -- Axi4-stream master
    M_TDATA     : out std_logic_vector(G_M_TDATA_WIDTH - 1 downto 0);
    M_TVALID    : out std_logic;
    M_TLAST     : out std_logic;
    M_TUSER     : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB     : out std_logic_vector(((G_M_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP     : out std_logic_vector(((G_M_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID       : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST     : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY    : in  std_logic;
    -- Error
    ERR       : out std_logic_vector(2 downto 0)
  );
begin
  -- synthesis translate_off
  assert(((G_S_TDATA_WIDTH > G_M_TDATA_WIDTH) and ((G_S_TDATA_WIDTH mod G_M_TDATA_WIDTH) = 0)) or
         ((G_M_TDATA_WIDTH > G_S_TDATA_WIDTH) and ((G_M_TDATA_WIDTH mod G_S_TDATA_WIDTH) = 0))) report "Inexact ratio" severity failure;
  -- synthesis translate_on
end axis_dwidth_converter;

architecture rtl of axis_dwidth_converter is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  constant C_S_TKEEP_WIDTH     : positive := (G_S_TDATA_WIDTH + 7) / 8;
  constant C_S_TSTRB_WIDTH     : positive := (G_S_TDATA_WIDTH + 7) / 8;
  constant C_M_TKEEP_WIDTH     : positive := (G_M_TDATA_WIDTH + 7) / 8;
  constant C_M_TSTRB_WIDTH     : positive := (G_M_TDATA_WIDTH + 7) / 8;
  constant C_BYTES_ALIGN       : boolean  := is_bytes_align(G_S_TDATA_WIDTH) and is_bytes_align(G_M_TDATA_WIDTH);

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  signal s_from_reg_tdata     : std_logic_vector(G_S_TDATA_WIDTH - 1 downto 0);
  signal s_from_reg_tvalid    : std_logic;
  signal s_from_reg_tlast     : std_logic;
  signal s_from_reg_tuser     : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal s_from_reg_tstrb     : std_logic_vector(C_S_TSTRB_WIDTH - 1 downto 0);
  signal s_from_reg_tkeep     : std_logic_vector(C_S_TKEEP_WIDTH - 1 downto 0);
  signal s_from_reg_tid       : std_logic_vector(G_TID_WIDTH - 1 downto 0);
  signal s_from_reg_tdest     : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
  signal s_from_reg_tready    : std_logic;

  signal m_to_reg_tdata       : std_logic_vector(G_M_TDATA_WIDTH - 1 downto 0);
  signal m_to_reg_tvalid      : std_logic;
  signal m_to_reg_tlast       : std_logic;
  signal m_to_reg_tuser       : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal m_to_reg_tstrb       : std_logic_vector(C_M_TSTRB_WIDTH - 1 downto 0);
  signal m_to_reg_tkeep       : std_logic_vector(C_M_TKEEP_WIDTH - 1 downto 0);
  signal m_to_reg_tid         : std_logic_vector(G_TID_WIDTH - 1 downto 0);
  signal m_to_reg_tdest       : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
  signal m_to_reg_tready      : std_logic;

begin

  -- Just for compatibility, when both side use the same data width
  GEN_PASSTHROUGH : if G_S_TDATA_WIDTH = G_M_TDATA_WIDTH generate
  begin

    --------------------------------------------------------------------
    -- Register the slave port
    --------------------------------------------------------------------
    inst_axis_register_slave : axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_S_TDATA_WIDTH,
        G_TUSER_WIDTH  => G_TUSER_WIDTH,
        G_TID_WIDTH    => G_TID_WIDTH,
        G_TDEST_WIDTH  => G_TDEST_WIDTH,
        G_REG_FORWARD  => G_PIPELINE,
        G_REG_BACKWARD => G_PIPELINE
      )
      port map(
        -- global
        CLK      => CLK,
        RST      => RST,
        -- axi4-stream slave
        S_TDATA  => S_TDATA,
        S_TVALID => S_TVALID,
        S_TLAST  => S_TLAST,
        S_TUSER  => S_TUSER,
        S_TSTRB  => S_TSTRB,
        S_TKEEP  => S_TKEEP,
        S_TID    => S_TID,
        S_TDEST  => S_TDEST,
        S_TREADY => S_TREADY,
        -- axi4-stream master
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TUSER  => M_TUSER,
        M_TSTRB  => M_TSTRB,
        M_TKEEP  => M_TKEEP,
        M_TID    => M_TID,
        M_TDEST  => M_TDEST,
        M_TREADY => M_TREADY
      );

    -- No Error
    ERR <= (others => '0');

  end generate GEN_PASSTHROUGH;

  -- Real Data Width Converter
  GEN_DWIDTH_CONV : if G_S_TDATA_WIDTH /= G_M_TDATA_WIDTH generate
  begin

    --------------------------------------------------------------------
    -- Register the slave port
    --------------------------------------------------------------------
    inst_axis_register_slave : axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_S_TDATA_WIDTH,
        G_TUSER_WIDTH  => G_TUSER_WIDTH,
        G_TID_WIDTH    => G_TID_WIDTH,
        G_TDEST_WIDTH  => G_TDEST_WIDTH,
        G_REG_FORWARD  => G_PIPELINE,
        G_REG_BACKWARD => G_PIPELINE
      )
      port map(
        -- global
        CLK      => CLK,
        RST      => RST,
        -- axi4-stream slave
        S_TDATA  => S_TDATA,
        S_TVALID => S_TVALID,
        S_TLAST  => S_TLAST,
        S_TUSER  => S_TUSER,
        S_TSTRB  => S_TSTRB,
        S_TKEEP  => S_TKEEP,
        S_TID    => S_TID,
        S_TDEST  => S_TDEST,
        S_TREADY => S_TREADY,
        -- axi4-stream master
        M_TDATA  => s_from_reg_tdata,
        M_TVALID => s_from_reg_tvalid,
        M_TLAST  => s_from_reg_tlast,
        M_TUSER  => s_from_reg_tuser,
        M_TSTRB  => s_from_reg_tstrb,
        M_TKEEP  => s_from_reg_tkeep,
        M_TID    => s_from_reg_tid,
        M_TDEST  => s_from_reg_tdest,
        M_TREADY => s_from_reg_tready
      );

    --------------------------------------------------------------------
    -- In case of WIDTH OUTPUT < WIDTH INPUT
    --------------------------------------------------------------------

    GEN_SMALLER : if G_M_TDATA_WIDTH < G_S_TDATA_WIDTH generate

      --------------------------------------------------------------------
      -- Signals declaration
      --------------------------------------------------------------------

      -- Output word counter
      signal count      : integer range 0 to (G_S_TDATA_WIDTH/G_M_TDATA_WIDTH) - 1;
      -- Byte counter used to avoid TLAST with null TKEEP
      signal count_byte : integer range 0 to C_S_TKEEP_WIDTH - 1;
      signal last_byte  : integer range -1 to C_S_TKEEP_WIDTH - 1;

    begin

      -- Get index of last byte
      last_byte <= find_first(data => s_from_reg_tkeep, val => '1', start_high => G_LITTLE_ENDIAN);

      -- Conversion process
      P_CONV_SMALLER : process(CLK, RST)
      begin
        if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
          -- Asynchronous reset
          count      <= 0;
          count_byte <= 0;
        elsif rising_edge(CLK) then
          if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
            -- Synchronous reset
            count      <= 0;
            count_byte <= 0;
          else

            if ((s_from_reg_tvalid = '1') and (m_to_reg_tready = '1')) then
              -- Master word counter
              if (count = ((G_S_TDATA_WIDTH/G_M_TDATA_WIDTH) - 1)) then
                count <= 0;
              else
                count <= count + 1;
              end if;

              -- Byte counter
              if count_byte = (C_S_TKEEP_WIDTH - C_M_TKEEP_WIDTH) then
                count_byte <= 0;
              else
                count_byte <= count_byte + C_M_TKEEP_WIDTH;
              end if;
            end if;

          end if;
        end if;
      end process P_CONV_SMALLER;

      -- Big Endian
      SMALL_GENERATE_BE : if not(G_LITTLE_ENDIAN) generate
        m_to_reg_tdata    <= s_from_reg_tdata((G_S_TDATA_WIDTH - (count * G_M_TDATA_WIDTH)) - 1 downto (G_S_TDATA_WIDTH - ((count+1) * G_M_TDATA_WIDTH)));

        -- DATA is align on bytes
        SMALL_GENERATE_BE_ALIGN : if C_BYTES_ALIGN generate
          m_to_reg_tstrb    <= s_from_reg_tstrb((C_S_TSTRB_WIDTH - (count * C_M_TSTRB_WIDTH)) - 1 downto (C_S_TSTRB_WIDTH - ((count+1) * C_M_TSTRB_WIDTH)));
          m_to_reg_tkeep    <= s_from_reg_tkeep((C_S_TKEEP_WIDTH - (count * C_M_TKEEP_WIDTH)) - 1 downto (C_S_TKEEP_WIDTH - ((count+1) * C_M_TKEEP_WIDTH)));

          -- Direct assignment in case of
          -- - Not the last word
          -- - TLAST anticipation to avoid null TKEEP on output
          -- - Last input TKEEP is Null, additionnal output with TKEEP null to ensure TLAST generation
          m_to_reg_tvalid <= s_from_reg_tvalid when (s_from_reg_tlast = '0') or
                                                    ((last_byte /= (-1)) and (count_byte <= ((C_S_TKEEP_WIDTH-1) - last_byte))) or
                                                    ((last_byte  = (-1)) and (count_byte < C_M_TKEEP_WIDTH))
                                               else '0';
          m_to_reg_tlast  <= s_from_reg_tlast  when ((last_byte /= (-1)) and (((C_S_TKEEP_WIDTH-1) - last_byte) < (count_byte + C_M_TKEEP_WIDTH)) and
                                                        (((C_S_TKEEP_WIDTH-1) - last_byte) >= count_byte)) or
                                                    ((last_byte  = (-1)) and (count_byte < C_M_TKEEP_WIDTH))
                                               else '0';
        end generate SMALL_GENERATE_BE_ALIGN;

      end generate SMALL_GENERATE_BE;

      -- Little Endian
      SMALL_GENERATE_LE : if G_LITTLE_ENDIAN generate

        -- Map data
        m_to_reg_tdata    <= s_from_reg_tdata((G_M_TDATA_WIDTH + (count * G_M_TDATA_WIDTH)) - 1 downto (count * G_M_TDATA_WIDTH));

        -- DATA is align on bytes
        SMALL_GENERATE_LE_ALIGN : if C_BYTES_ALIGN generate
          m_to_reg_tstrb    <= s_from_reg_tstrb((C_M_TSTRB_WIDTH + (count * C_M_TSTRB_WIDTH)) - 1 downto (count * C_M_TSTRB_WIDTH));
          m_to_reg_tkeep    <= s_from_reg_tkeep((C_M_TKEEP_WIDTH + (count * C_M_TKEEP_WIDTH)) - 1 downto (count * C_M_TKEEP_WIDTH));

          -- Direct assignment in case of
          -- - Not the last word
          -- - TLAST anticipation to avoid null TKEEP on output
          -- - Last input TKEEP is Null, additionnal output with TKEEP null to ensure TLAST generation
          m_to_reg_tvalid <= s_from_reg_tvalid when (s_from_reg_tlast = '0') or 
                                                    ((last_byte /= (-1)) and (count_byte <= last_byte)) or
                                                    ((last_byte  = (-1)) and (count_byte < C_M_TKEEP_WIDTH))
                                               else '0';
          m_to_reg_tlast  <= s_from_reg_tlast when ((last_byte /= (-1)) and (last_byte < (count_byte + C_M_TKEEP_WIDTH)) and (last_byte >= count_byte)) or
                                                   ((last_byte  = (-1)) and (count_byte < C_M_TKEEP_WIDTH))
                                              else '0';
        end generate SMALL_GENERATE_LE_ALIGN;

      end generate SMALL_GENERATE_LE;

    -- Data are not aligned on bytes, TSTRB and TKEEP are forced to 1
      SMALL_GENERATE_NOT_ALIGN : if (not C_BYTES_ALIGN) generate
        m_to_reg_tstrb    <= (others => '1');
        m_to_reg_tkeep    <= (others => '1');

        m_to_reg_tvalid <= s_from_reg_tvalid;
        m_to_reg_tlast  <= s_from_reg_tlast when (count = ((G_S_TDATA_WIDTH/G_M_TDATA_WIDTH) - 1)) else '0';
      end generate SMALL_GENERATE_NOT_ALIGN;

      -- Slave TREADY
      s_from_reg_tready <= '1' when (m_to_reg_tready = '1') and (count = ((G_S_TDATA_WIDTH/G_M_TDATA_WIDTH) - 1)) else '0';

      -- Master to reg
      m_to_reg_tuser  <= s_from_reg_tuser;
      m_to_reg_tid    <= s_from_reg_tid;
      m_to_reg_tdest  <= s_from_reg_tdest;

      -- Not used in this case
      ERR           <= (others => '0');

    end generate GEN_SMALLER;

    --------------------------------------------------------------------
    -- In case of WIDTH OUTPUT > WIDTH INPUT
    --------------------------------------------------------------------

    GEN_BIGGER : if G_M_TDATA_WIDTH > G_S_TDATA_WIDTH generate

      --------------------------------------------------------------------
      -- Constants declaration
      --------------------------------------------------------------------
      constant C_RATIO           : integer := (G_M_TDATA_WIDTH/G_S_TDATA_WIDTH);

      --------------------------------------------------------------------
      -- Signals declaration
      --------------------------------------------------------------------
      signal cnt                 : integer range 0 to C_RATIO - 1;
      signal b_tdata             : std_logic_vector(G_M_TDATA_WIDTH - 1 downto 0);
      signal b_tstrb             : std_logic_vector(C_M_TSTRB_WIDTH - 1 downto 0);
      signal b_tkeep             : std_logic_vector(C_M_TKEEP_WIDTH - 1 downto 0);
      signal b_tuser             : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      signal b_tid               : std_logic_vector(G_TID_WIDTH - 1 downto 0);
      signal b_tdest             : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      signal unaligned_tlast     : std_logic;
      signal unaligned_tid_tdest : std_logic;
    begin

      -- Conversion process
      P_CONV_BIGGER : process(CLK,RST)
      begin
        if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
          -- Asynchronous reset
          cnt       <= 0;
          b_tdata   <= (others => '0');
          b_tstrb   <= (others => '0');
          b_tkeep   <= (others => '0');
          b_tuser   <= (others => '0');
          b_tid     <= (others => '0');
          b_tdest   <= (others => '0');
          ERR       <= (others => '0');

        elsif rising_edge(CLK) then
          if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
            -- Synchronous reset
            cnt       <= 0;
            b_tdata   <= (others => '0');
            b_tstrb   <= (others => '0');
            b_tkeep   <= (others => '0');
            b_tuser   <= (others => '0');
            b_tid     <= (others => '0');
            b_tdest   <= (others => '0');
            ERR       <= (others => '0');

          else

            -- Clear error pulse
            ERR <= (others => '0');

            -- Manage Counter and M_TDATA
            if ((s_from_reg_tvalid = '1') and (s_from_reg_tready = '1')) then

              if (cnt = (C_RATIO- 1)) or (unaligned_tlast = '1') then
                cnt       <= 0;
                b_tdata   <= (others => '0');
                b_tstrb   <= (others => '0');
                b_tkeep   <= (others => '0');

              else
                cnt   <= cnt + 1;

                -- Bufferize Data
                if G_LITTLE_ENDIAN then
                  b_tdata((G_S_TDATA_WIDTH*(cnt+1))-1 downto (G_S_TDATA_WIDTH*cnt)) <= s_from_reg_tdata;
                  if (C_BYTES_ALIGN) then
                    b_tstrb((C_S_TSTRB_WIDTH*(cnt+1))-1 downto (C_S_TSTRB_WIDTH*cnt)) <= s_from_reg_tstrb;
                    b_tkeep((C_S_TKEEP_WIDTH*(cnt+1))-1 downto (C_S_TKEEP_WIDTH*cnt)) <= s_from_reg_tkeep;
                  end if;
                else
                  b_tdata(b_tdata'high-(G_S_TDATA_WIDTH*cnt) downto b_tdata'length-(G_S_TDATA_WIDTH*(cnt+1))) <= s_from_reg_tdata;
                  if (C_BYTES_ALIGN) then
                    b_tstrb(b_tstrb'high-(C_S_TSTRB_WIDTH*cnt) downto b_tstrb'length-(C_S_TSTRB_WIDTH*(cnt+1))) <= s_from_reg_tstrb;
                    b_tkeep(b_tkeep'high-(C_S_TKEEP_WIDTH*cnt) downto b_tkeep'length-(C_S_TKEEP_WIDTH*(cnt+1))) <= s_from_reg_tkeep;
                  end if;
                end if;

                -- Check unexpected tlast
                if (not C_BYTES_ALIGN) and (s_from_reg_tlast = '1') then
                  ERR(0) <= '1';
                end if;

              end if;

              -- Buffer used in case of unaligned TID or TDEST
              b_tuser <= s_from_reg_tuser;

              -- Check if tid and tdest are consistent during the packet conversion
              if (cnt = 0) then
                b_tid   <= s_from_reg_tid;
                b_tdest <= s_from_reg_tdest;

              elsif (not C_BYTES_ALIGN) then
                if b_tid /= s_from_reg_tid then
                  ERR(1) <= '1';
                end if;
                if b_tdest /= s_from_reg_tdest then
                  ERR(2) <= '1';
                end if;

              end if;

            -- Particular case of unaligned TID or TDEST
            elsif (unaligned_tid_tdest = '1') and (s_from_reg_tvalid = '1') and (m_to_reg_tready = '1') then
              cnt       <= 0;
              b_tdata   <= (others => '0');
              b_tstrb   <= (others => '0');
              b_tkeep   <= (others => '0');

            end if;

          end if;
        end if;
      end process P_CONV_BIGGER;

      -- Intermediate signals to increase lisibility
      unaligned_tlast     <= '1' when (C_BYTES_ALIGN and (s_from_reg_tlast = '1')) else '0';
      unaligned_tid_tdest <= '1' when (C_BYTES_ALIGN and (cnt /= 0) and ((s_from_reg_tid /= b_tid) or (s_from_reg_tdest /= b_tdest))) else '0';

      -- Gestion du TREADY
      s_from_reg_tready <= '0' when (((cnt = (C_RATIO - 1)) or (unaligned_tlast = '1')) and (m_to_reg_tvalid = '1') and (m_to_reg_tready = '0')) or
                                    (unaligned_tid_tdest = '1') else
                           '1';

      -- Big Endian
      BIG_GENERATE_BE : if not(G_LITTLE_ENDIAN) generate

        -- DATA is align on bytes
        BIG_GENERATE_BE_ALIGN : if C_BYTES_ALIGN generate

          -- Generate TDATA
          BIG_GEN_BE_ALIGN_TDATA : for m in 0 to (C_RATIO - 1) generate
            -- In case of first fragment (cnt = 0) and anticipate TLAST, output data correspond at s_from_reg_tdata
            -- In case of TID or TDEST anticipate changed, output data should be the memorized data b_tdata
            m_to_reg_tdata(b_tdata'high-(G_S_TDATA_WIDTH*m) downto b_tdata'length-(G_S_TDATA_WIDTH*(m+1))) <= s_from_reg_tdata when (m = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                                              b_tdata(b_tdata'high-(G_S_TDATA_WIDTH*m) downto b_tdata'length-(G_S_TDATA_WIDTH*(m+1)));
          end generate BIG_GEN_BE_ALIGN_TDATA;

          -- Generate TSTRB/TKEEP
          BIG_GEN_BE_TSTRB_TKEEP : for n in 0 to (C_RATIO - 1) generate
            -- Condition is the same as TDATA
            m_to_reg_tstrb(b_tstrb'high-(C_S_TSTRB_WIDTH*n) downto b_tstrb'length-(C_S_TSTRB_WIDTH*(n+1))) <= s_from_reg_tstrb when (n = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                                              b_tstrb(b_tstrb'high-(C_S_TSTRB_WIDTH*n) downto b_tstrb'length-(C_S_TSTRB_WIDTH*(n+1)));
            m_to_reg_tkeep(b_tkeep'high-(C_S_TKEEP_WIDTH*n) downto b_tkeep'length-(C_S_TKEEP_WIDTH*(n+1))) <= s_from_reg_tkeep when (n = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                                              b_tkeep(b_tkeep'high-(C_S_TKEEP_WIDTH*n) downto b_tkeep'length-(C_S_TKEEP_WIDTH*(n+1)));
          end generate BIG_GEN_BE_TSTRB_TKEEP;

        end generate BIG_GENERATE_BE_ALIGN;

        -- Data is not align on bytes, TSTRB and TKEEP are forced to 1
        BIG_GENERATE_BE_NOT_ALIGN : if (not C_BYTES_ALIGN) generate

          -- Generate TDATA
          BIG_GEN_BE_NOT_ALIGN_TDATA : for m in 0 to (C_RATIO - 2) generate
            m_to_reg_tdata(b_tdata'high-(G_S_TDATA_WIDTH*m) downto b_tdata'length-(G_S_TDATA_WIDTH*(m+1))) <= b_tdata(b_tdata'high-(G_S_TDATA_WIDTH*m) downto b_tdata'length-(G_S_TDATA_WIDTH*(m+1)));
          end generate BIG_GEN_BE_NOT_ALIGN_TDATA;
          m_to_reg_tdata(b_tdata'high-(G_S_TDATA_WIDTH*(C_RATIO - 1)) downto b_tdata'length-(G_S_TDATA_WIDTH*C_RATIO)) <= s_from_reg_tdata;

          m_to_reg_tstrb    <= (others => '1');
          m_to_reg_tkeep    <= (others => '1');
        end generate BIG_GENERATE_BE_NOT_ALIGN;

      end generate BIG_GENERATE_BE;

      -- Little Endian
      BIG_GENERATE_LE : if G_LITTLE_ENDIAN generate

        -- DATA is align on bytes
        BIG_GENERATE_LE_ALIGN : if C_BYTES_ALIGN generate

          -- Generate TDATA
          BIG_GEN_LE_ALIGN_TDATA : for m in 0 to (C_RATIO - 1) generate
            -- In case of first fragment (cnt = 0) and anticipate TLAST, output data correspond at s_from_reg_tdata
            -- In case of TID or TDEST anticipate changed, output data should be the memorized data b_tdata
            m_to_reg_tdata((G_S_TDATA_WIDTH*(m+1))-1 downto (G_S_TDATA_WIDTH*m)) <= s_from_reg_tdata when (m = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                    b_tdata((G_S_TDATA_WIDTH*(m+1))-1 downto (G_S_TDATA_WIDTH*m));
          end generate BIG_GEN_LE_ALIGN_TDATA;

          -- Generate TSTRB/TKEEP
          -- /!\ Do not take into accound modelsim warning during elaboration when C_BYTES_ALIGN is false
          BIG_GEN_LE_TSTRB_TKEEP : for n in 0 to (C_RATIO - 1) generate
            -- Condition is the same as TDATA
            m_to_reg_tstrb((C_S_TSTRB_WIDTH*(n+1))-1 downto (C_S_TSTRB_WIDTH*n)) <= s_from_reg_tstrb when (n = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                    b_tstrb((C_S_TSTRB_WIDTH*(n+1))-1 downto (C_S_TSTRB_WIDTH*n));
            m_to_reg_tkeep((C_S_TKEEP_WIDTH*(n+1))-1 downto (C_S_TKEEP_WIDTH*n)) <= s_from_reg_tkeep when (n = cnt) and ((cnt = 0) or ((s_from_reg_tid = b_tid) and (s_from_reg_tdest = b_tdest))) else
                                                                                    b_tkeep((C_S_TKEEP_WIDTH*(n+1))-1 downto (C_S_TKEEP_WIDTH*n));
          end generate BIG_GEN_LE_TSTRB_TKEEP;

        end generate BIG_GENERATE_LE_ALIGN;

        -- Data is not align on bytes, TSTRB and TKEEP are forced to 1
        BIG_GENERATE_LE_NOT_ALIGN : if (not C_BYTES_ALIGN) generate

          -- Generate TDATA
          BIG_GEN_LE_NOT_ALIGN_TDATA : for m in 0 to (C_RATIO - 2) generate
            m_to_reg_tdata((G_S_TDATA_WIDTH*(m+1))-1 downto (G_S_TDATA_WIDTH*m)) <= b_tdata((G_S_TDATA_WIDTH*(m+1))-1 downto (G_S_TDATA_WIDTH*m));
          end generate BIG_GEN_LE_NOT_ALIGN_TDATA;
          m_to_reg_tdata((G_S_TDATA_WIDTH*C_RATIO)-1 downto (G_S_TDATA_WIDTH*(C_RATIO - 1))) <= s_from_reg_tdata;

          m_to_reg_tstrb    <= (others => '1');
          m_to_reg_tkeep    <= (others => '1');

        end generate BIG_GENERATE_LE_NOT_ALIGN;

      end generate BIG_GENERATE_LE;

      -- Output data when word is complete or unaligned tlast / tid / tdest
      m_to_reg_tvalid <= s_from_reg_tvalid when (cnt = (C_RATIO - 1)) or
                                                (unaligned_tlast = '1') or
                                                (unaligned_tid_tdest= '1') else '0';

      m_to_reg_tlast  <= '0'     when (unaligned_tid_tdest = '1') else s_from_reg_tlast;
      m_to_reg_tid    <= s_from_reg_tid   when (cnt = 0) or (not C_BYTES_ALIGN) else b_tid;
      m_to_reg_tdest  <= s_from_reg_tdest when (cnt = 0) or (not C_BYTES_ALIGN) else b_tdest;
      m_to_reg_tuser  <= b_tuser when (unaligned_tid_tdest = '1') else s_from_reg_tuser;


    end generate GEN_BIGGER;


    --------------------------------------------------------------------
    -- Register the master port
    --------------------------------------------------------------------
    inst_axis_register_master : axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_M_TDATA_WIDTH,
        G_TUSER_WIDTH  => G_TUSER_WIDTH,
        G_TID_WIDTH    => G_TID_WIDTH,
        G_TDEST_WIDTH  => G_TDEST_WIDTH,
        G_REG_FORWARD  => G_PIPELINE,
        G_REG_BACKWARD => false
      )
      port map(
        -- global
        CLK      => CLK,
        RST      => RST,
        -- axi4-stream slave
        S_TDATA  => m_to_reg_tdata,
        S_TVALID => m_to_reg_tvalid,
        S_TLAST  => m_to_reg_tlast,
        S_TUSER  => m_to_reg_tuser,
        S_TSTRB  => m_to_reg_tstrb,
        S_TKEEP  => m_to_reg_tkeep,
        S_TID    => m_to_reg_tid,
        S_TDEST  => m_to_reg_tdest,
        S_TREADY => m_to_reg_tready,
        -- axi4-stream master
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TUSER  => M_TUSER,
        M_TSTRB  => M_TSTRB,
        M_TKEEP  => M_TKEEP,
        M_TID    => M_TID,
        M_TDEST  => M_TDEST,
        M_TREADY => M_TREADY
      );
  end generate GEN_DWIDTH_CONV;

end rtl;
