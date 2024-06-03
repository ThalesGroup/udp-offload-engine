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

----------------------------------
--       FIFO_GEN
----------------------------------
-- First In First Out structure Generator
-----------
-- The entity is parametrizable in data width
-- The entity is parametrizable in addr width (FIFO depth)
-- The entity is parametrizable in synchronization stage number (for cdc)
-- The entity is parametrizable in reset polarity (active 1 or active 0) and mode (synchronous/asynchronous)
-- The entity is parametrizable in clock domain (optimization are made for common clocks)
-- The entity is parametrizable in show ahead mode (useful for AXI4-stream)
--
-- Write reset is synchronous to write clock domain
-- An internal read reset for the read clock domain is generated inside the module
--
-- In case of common clocks:
-- - the read reset and the write reset are the same
-- - the pointers are passed in plain binary to the other side
--   without any resynchronization nor registering.
--
-- In case of no common clocks:
-- - the read reset is generated from the write reset via a reset resynchronization.
--   The number of resynchronization stages is G_SYNC_STAGE
-- - the pointers are passed in gray code then synchronized
--   thanks to a multiple stage Flip Flop.
--
-- In case of show ahead mode, a mechanism is made to read the data the first
-- time the FIFO is not empty, and then the read pointer keeps an advance of 1
-- until the FIFO becomes empty again.
-- The EMPTY flag takes one cycle to be deasserted. This implies that the RD_COUNT
-- may be different of zero while the EMPTY flag is still asserted. This state means
-- that data are present in the FIFO but they may not be read yet.
--
-- This FIFO is optimized for Xilinx 7 series architecture but is written
-- in generic VHDL
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.cdc_utils_pkg.cdc_gray_sync;
use common.cdc_utils_pkg.cdc_bit_sync;
use common.cdc_utils_pkg.cdc_reset_sync;

use common.memory_utils_pkg.simple_dp_ram;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity fifo_gen is
  generic (
    G_COMMON_CLK    : boolean                         := false;  -- 2 or 1 clock domains
    G_SHOW_AHEAD    : boolean                         := false;  -- Whether in Show Ahead mode
    G_ADDR_WIDTH    : positive                        := 10;     -- FIFO address width (depth is 2**ADDR_WIDTH)
    G_DATA_WIDTH    : positive                        := 16;     -- FIFO word width (total port width depends on G_PACK_RATIO)
    G_PACK_RATIO_WR : positive                        := 1;      -- Specify RAM pack factor of word on each access on write port (allow assymetry)
    G_PACK_RATIO_RD : positive                        := 1;      -- Specify RAM pack factor of word on each access on read port (allow assymetry)
    G_RAM_STYLE     : string                          := "AUTO"; -- Specify the ram synthesis style (technology dependant)
    G_ACTIVE_RST    : std_logic range '0' to '1'      := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST     : boolean                         := true;   -- Type of reset used (synchronous or asynchronous resets)
    G_SYNC_STAGE    : integer range 2 to integer'high := 2       -- Number of synchronization stages (to reduce MTBF)
  );
  port (
    -- Write clock domain
    CLK_WR   : in  std_logic;                                                                             -- Write port clock
    RST_WR   : in  std_logic;                                                                             -- Write port reset
    FULL     : out std_logic;                                                                             -- FIFO is full
    FULL_N   : out std_logic;                                                                             -- FIFO is not full
    WR_EN    : in  std_logic;                                                                             -- Write enable
    WR_DATA  : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_WR) - 1 downto 0);                       -- Data to write
    WR_COUNT : out std_logic_vector(G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_WR)))) downto 0); -- Data count written in the FIFO
    -- Read clock domain
    CLK_RD   : in  std_logic;                                                                             -- Read port clock
    EMPTY    : out std_logic;                                                                             -- FIFO is empty
    EMPTY_N  : out std_logic;                                                                             -- FIFO is not empty
    RD_EN    : in  std_logic;                                                                             -- Read enable
    RD_DATA  : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_RD) - 1 downto 0);                       -- Data read
    RD_COUNT : out std_logic_vector(G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_RD)))) downto 0)  -- Data count readable from the FIFO
  );
begin
  -- Check that PACK ratios are power of 2
  -- synthesis translate_off
  assert G_PACK_RATIO_WR = (2 ** integer(log2(real(G_PACK_RATIO_WR)))) report "Pack ratio for port WR must be a power of 2" severity error;
  assert G_PACK_RATIO_RD = (2 ** integer(log2(real(G_PACK_RATIO_RD)))) report "Pack ratio for port RD must be a power of 2" severity error;
  -- synthesis translate_on
end fifo_gen;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of fifo_gen is

  --------------------------------------------
  -- CONSTANTS
  --------------------------------------------
  -- Number of bit to shift pointers for comparison
  constant C_BIT_SHIFT_WR  : integer := integer(floor(log2(real(G_PACK_RATIO_WR))));
  constant C_BIT_SHIFT_RD  : integer := integer(floor(log2(real(G_PACK_RATIO_RD))));

  -- Size of pointer are reduced width
  constant C_ADDR_WIDTH_WR : integer := G_ADDR_WIDTH - C_BIT_SHIFT_WR;
  constant C_ADDR_WIDTH_RD : integer := G_ADDR_WIDTH - C_BIT_SHIFT_RD;

  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------
  -- Convert a pointer from one domain to the other adapting it's size.
  --   The rightmost bits are dropped in case of a conversion to a smaller pointer
  --   The pointer is extended by '0' to its right in case of a conversion to a larger pointer
  -- This change reflects the change in packing unit from one domain to the other
  function convert_ptr_size(constant arg: in unsigned; constant new_size: in positive) return unsigned is
    variable result   : UNSIGNED(new_size-1 downto 0) := (others => '0');
  begin
    if (new_size < arg'length) then
      result := resize(shift_right(arg, arg'length - new_size), new_size);
    else
      result := shift_left(resize(arg, new_size), new_size - arg'length);
    end if;
    return result;
  end function convert_ptr_size;

  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  -- Reset
  signal rst_rd             : std_logic;

  -- Pointers
  signal ptr_write_next     : unsigned(C_ADDR_WIDTH_WR - 1 downto 0);
  signal ptr_write          : unsigned(C_ADDR_WIDTH_WR - 1 downto 0);
  signal ptr_read_next      : unsigned(C_ADDR_WIDTH_RD - 1 downto 0);
  signal ptr_read           : unsigned(C_ADDR_WIDTH_RD - 1 downto 0);

  -- Pointers in std_logic_vector
  signal ptr_write_slv      : std_logic_vector(C_ADDR_WIDTH_WR - 1 downto 0);

  -- Anti-blocking system
  signal full_toggle_next   : std_logic;
  signal full_toggle        : std_logic;
  signal empty_toggle       : std_logic;

  -- Clock domain crossing
  -- pointers have the size of the other domain for comparison (size conversion is done in CDC sections)
  signal ptr_write_r        : unsigned(C_ADDR_WIDTH_RD - 1 downto 0);
  signal ptr_read_r         : unsigned(C_ADDR_WIDTH_WR - 1 downto 0);
  signal full_toggle_r      : std_logic;
  signal empty_toggle_r     : std_logic;

  -- Internal
  signal full_int           : std_logic;
  signal empty_a            : std_logic;
  signal empty_int          : std_logic;

  -- Filtered requests
  signal wr_en_int          : std_logic;
  signal rd_en_int          : std_logic;

  -- Read enable for ram
  signal rd_en_ram          : std_logic;

  -- Pull data for show_ahead
  signal addr_rd            : std_logic_vector(C_ADDR_WIDTH_RD - 1 downto 0);

begin

  ----------------------------------------------------------------------
  --
  -- Write clock domain
  --
  ----------------------------------------------------------------------

  --------------------------------------------
  -- Asynchronous signals
  --------------------------------------------

  -- Type conversion for ease of use in the code
  ptr_write_slv <= std_logic_vector(ptr_write);

  -- Data protection on FIFO overflow
  wr_en_int <= WR_EN and (not full_int);

  -- Increment pointer on write
  ptr_write_next <= ptr_write + 1 when wr_en_int = '1' else ptr_write;

  -- Toggle the signal to send the full information to the read process through CDC
  full_toggle_next <= (not empty_toggle_r) when (wr_en_int = '1') and (ptr_write_next = ptr_read_r) else full_toggle;

  -- Output assignment of readback signal
  FULL <= full_int;

  --------------------------------------------
  -- SYNC_WRITE
  --------------------------------------------
  -- Manage the full state and the counter of the FIFO
  -- Register the write pointer
  SYNC_WRITE: process(CLK_WR, RST_WR) is
  begin
    if G_ASYNC_RST and (RST_WR = G_ACTIVE_RST) then
      -- Asynchronous reset
      ptr_write   <= (others => '0');
      WR_COUNT    <= '1' & (C_ADDR_WIDTH_WR - 1 downto 0 => '0');
      full_int    <= '1'; -- Full at reset
      FULL_N      <= '0';
      full_toggle <= '0';

    elsif rising_edge(CLK_WR) then
      if (not G_ASYNC_RST) and (RST_WR = G_ACTIVE_RST) then
        -- Synchronous reset
        ptr_write   <= (others => '0');
        WR_COUNT    <= '1' & (C_ADDR_WIDTH_WR - 1 downto 0 => '0');
        full_int    <= '1'; -- Full at reset
        FULL_N      <= '0';
        full_toggle <= '0';

      else

        -- Register the pointer
        ptr_write <= ptr_write_next;

        -- Register the toggle
        full_toggle <= full_toggle_next;

        -- Write count
        WR_COUNT(C_ADDR_WIDTH_WR - 1 downto 0) <= std_logic_vector(ptr_write_next - ptr_read_r);

        -- Full management
        -- Become full on a write and pointers are equal
        -- Become unfull if pointers are different or the read part became empty while we were full
        if (wr_en_int = '1') and (ptr_write_next = ptr_read_r) then
          -- Become full
          full_int                  <= '1';
          FULL_N                    <= '0';
          WR_COUNT(C_ADDR_WIDTH_WR) <= '1'; -- Max level is reached

        elsif (ptr_write_next /= ptr_read_r) or (full_toggle = empty_toggle_r) then
          -- Become not full
          full_int                  <= '0';
          FULL_N                    <= '1';
          WR_COUNT(C_ADDR_WIDTH_WR) <= '0';

        end if;

      end if;
    end if;
  end process SYNC_WRITE;


  ----------------------------------------------------------------------
  --
  -- Clock domain crossing
  --
  ----------------------------------------------------------------------


  --------------------------------------------
  -- RAM BLOCK instantiation
  --------------------------------------------
  inst_simple_dp_ram : simple_dp_ram
    generic map(
      G_DATA_WIDTH     => G_DATA_WIDTH,
      G_ADDR_WIDTH     => G_ADDR_WIDTH,
      G_PACK_RATIO_W   => G_PACK_RATIO_WR,
      G_PACK_RATIO_R   => G_PACK_RATIO_RD,
      G_OUT_REG        => false,        -- TODO Add the possibility to register the memory output
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_RAM_STYLE      => G_RAM_STYLE,
      G_MEM_INIT_FILE  => "",
      G_MEM_INIT_VALUE => 'U'
    )
    port map(
      W_CLK            => CLK_WR,
      W_EN             => wr_en_int,
      W_ADDR           => ptr_write_slv,
      W_DATA           => WR_DATA,
      R_CLK            => CLK_RD,
      R_RST            => '-',
      R_EN             => rd_en_ram,
      R_REGCE          => '1',
      R_ADDR           => addr_rd,
      R_DATA           => RD_DATA
    );

  --------------------------------------------
  -- Pointer and reset resychronization
  --------------------------------------------
  GEN_RESYNC: if not G_COMMON_CLK generate

    -- Resets
    signal rst_resync         : std_logic;
    signal rst_resync_n       : std_logic;

    -- Signals for type conversion to map to cdc components
    signal ptr_write_next_slv : std_logic_vector(C_ADDR_WIDTH_WR - 1 downto 0);
    signal ptr_read_next_slv  : std_logic_vector(C_ADDR_WIDTH_RD - 1 downto 0);
    signal ptr_write_slv_r    : std_logic_vector(C_ADDR_WIDTH_WR - 1 downto 0);
    signal ptr_read_slv_r     : std_logic_vector(C_ADDR_WIDTH_RD - 1 downto 0);

  begin

    -- Generate read reset via resynchronization from the write reset
    inst_cdc_reset_sync: cdc_reset_sync
      generic map (
        G_NB_STAGE    => G_SYNC_STAGE,
        G_NB_CLOCK    => 1,
        G_ACTIVE_ARST => G_ACTIVE_RST
      )
      port map (
        ARST          => RST_WR,
        CLK(0)        => CLK_RD,
        SRST(0)       => rst_resync,
        SRST_N(0)     => rst_resync_n
      );

    -- Choose the correct reset polarity
    rst_rd <= rst_resync when G_ACTIVE_RST = '1' else rst_resync_n;


    -- Convert to std_logic_vector
    ptr_write_next_slv <= std_logic_vector(ptr_write_next);
    ptr_read_next_slv  <= std_logic_vector(ptr_read_next);

    -- Resynchronization via Gray vector encoding / decoding
    inst_cdc_gray_sync_wr_ptr: cdc_gray_sync
      generic map (
        G_NB_STAGE   => G_SYNC_STAGE,
        G_REG_OUTPUT => false,
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST,
        G_DATA_WIDTH => C_ADDR_WIDTH_WR
      )
      port map (
        CLK_SRC      => CLK_WR,
        RST_SRC      => RST_WR,
        DATA_SRC     => ptr_write_next_slv,
        CLK_DST      => CLK_RD,
        RST_DST      => rst_rd,
        DATA_DST     => ptr_write_slv_r
      );

    -- Resynchronization via Gray vector encoding / decoding
    inst_cdc_gray_sync_rd_ptr: cdc_gray_sync
      generic map (
        G_NB_STAGE   => G_SYNC_STAGE,
        G_REG_OUTPUT => false,
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST,
        G_DATA_WIDTH => C_ADDR_WIDTH_RD
      )
      port map (
        CLK_SRC      => CLK_RD,
        RST_SRC      => rst_rd,
        DATA_SRC     => ptr_read_next_slv,
        CLK_DST      => CLK_WR,
        RST_DST      => RST_WR,
        DATA_DST     => ptr_read_slv_r
      );

    -- Double flip flop on toggle on full signal
    inst_cdc_bit_sync_full_toggle: cdc_bit_sync
      generic map(
        G_NB_STAGE   => G_SYNC_STAGE,
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST,
        G_RST_VALUE  => '0'
      )
      port map(
        DATA_ASYNC => full_toggle,
        CLK        => CLK_RD,
        RST        => rst_rd,
        DATA_SYNC  => full_toggle_r
      );

    -- Double flip flop on toggle on empty signal
    inst_cdc_bit_sync_empty_toggle: cdc_bit_sync
      generic map(
        G_NB_STAGE   => G_SYNC_STAGE,
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST,
        G_RST_VALUE  => '0'
      )
      port map(
        DATA_ASYNC => empty_toggle,
        CLK        => CLK_WR,
        RST        => RST_WR,
        DATA_SYNC  => empty_toggle_r
      );

    -- Convert from std_logic_vector, and resize to the other domain value
    ptr_write_r        <= convert_ptr_size(unsigned(ptr_write_slv_r), C_ADDR_WIDTH_RD);
    ptr_read_r         <= convert_ptr_size(unsigned(ptr_read_slv_r), C_ADDR_WIDTH_WR);

  end generate GEN_RESYNC;

  --------------------------------------------
  -- No resynchronization
  --------------------------------------------
  GEN_NO_RESYNC: if G_COMMON_CLK generate

    -- Reset
    rst_rd <= RST_WR;

    -- From READ
    -- Direct assignment
    ptr_read_r     <= convert_ptr_size(ptr_read_next, C_ADDR_WIDTH_WR);
    empty_toggle_r <= empty_toggle;

    -- From Write
    -- No a register for normal mode
    GEN_CONNECT_NEXT: if not G_SHOW_AHEAD generate
      ptr_write_r   <= convert_ptr_size(ptr_write_next, C_ADDR_WIDTH_RD);
      full_toggle_r <= full_toggle_next;
    end generate GEN_CONNECT_NEXT;

    -- Register for SHOW_AHEAD mode
    GEN_CONNECT_REG: if G_SHOW_AHEAD generate
      ptr_write_r   <= convert_ptr_size(ptr_write, C_ADDR_WIDTH_RD);
      full_toggle_r <= full_toggle;
    end generate GEN_CONNECT_REG;

  end generate GEN_NO_RESYNC;

  ----------------------------------------------------------------------
  --
  -- Read clock domain
  --
  ----------------------------------------------------------------------

  --------------------------------------------
  -- Asynchronous signals
  --------------------------------------------

  -- Data protection on FIFO underflow
  rd_en_int <= RD_EN and (not empty_int);

  -- Increment pointer on read
  ptr_read_next <= ptr_read + 1 when rd_en_int = '1' else ptr_read;

  -- Asynchronous empty
  -- Become empty if pointers are equal and the write part didn't become full while we were empty
  empty_a <= '1' when (ptr_write_r = ptr_read_next) and (empty_toggle = full_toggle_r) else '0';

  -- Read in ram on request except on last request
  -- or when becoming unempty (first data) in show ahead mode
  -- Read ram on request in normal mode
  rd_en_ram <= ((rd_en_int) or (empty_int)) and (not empty_a) when G_SHOW_AHEAD else rd_en_int;

  -- Read_addr management
  addr_rd <= std_logic_vector(ptr_read_next)  -- Anticipation of read when show ahead
             when G_SHOW_AHEAD
             else std_logic_vector(ptr_read);

  -- Output assignment of readback signal
  EMPTY     <= empty_int;

  --------------------------------------------
  -- SYNC_READ
  --------------------------------------------
  -- Manage the read from the FIFO
  SYNC_READ: process(CLK_RD, rst_rd) is
  begin
    if G_ASYNC_RST and (rst_rd = G_ACTIVE_RST) then
      -- Asynchronous reset
      ptr_read      <= (others => '0');
      RD_COUNT      <= (others => '0');
      EMPTY_N       <= '0';
      empty_int     <= '1';
      empty_toggle  <= '0';

    elsif rising_edge(CLK_RD) then
      if (not G_ASYNC_RST) and (rst_rd = G_ACTIVE_RST) then
        -- Synchronous reset
        ptr_read      <= (others => '0');
        RD_COUNT      <= (others => '0');
        EMPTY_N       <= '0';
        empty_int     <= '1';
        empty_toggle  <= '0';

      else

        -- Register pointer
        ptr_read <= ptr_read_next;

        -- Read count is substraction
        RD_COUNT(C_ADDR_WIDTH_RD - 1 downto 0) <= std_logic_vector(ptr_write_r - ptr_read_next);

        -- MSB of read count is set when full.
        -- To be full, the pointers must be equal,
        -- no read is happening
        -- and we are not empty internally
        if ((ptr_write_r = ptr_read_next) and (rd_en_int /= '1')) and (empty_a /= '1') then
          RD_COUNT(C_ADDR_WIDTH_RD) <= '1';
        else
          RD_COUNT(C_ADDR_WIDTH_RD) <= '0';
        end if;

        -- Empty management
        -- Become empty on a read and pointers are equal
        -- Become unempty directly for normal mode, after first read in show ahead mode
        if (rd_en_int = '1') and (ptr_write_r = ptr_read_next) then
          -- Become empty
          empty_int              <= '1';
          EMPTY_N                <= '0';

          -- Signal to write process that we became empty
          empty_toggle           <= full_toggle_r;

        elsif empty_a /= '1' then
          -- Become not empty;
          empty_int <= '0';
          EMPTY_N   <= '1';
        end if;

      end if;
    end if;
  end process SYNC_READ;

end rtl;
