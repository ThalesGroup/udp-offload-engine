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
--       CDC_GRAY_SYNC
----------------------------------
-- Clock Domain Crossing Synchronization for a gray coded vector
----------------------------------
-- The entity is parametrizable in synchronization stage
-- The entity is parametrizable in data width
-- The entity is parametrizable in output registering
-- The entity is parametrizable in reset polarity (active 1 or active 0) and mode (synchronous/asynchronous)
--
-- The module adds one flip-flop stage in the source domain to ensure
-- gray vector to resynchronize does not come from combinational path
-- (which could make the resynchronization failed)
-- 
-- The synchronization in destination domain is done thanks to a multiple flip flop
-- architecture which ensures to control metastability.
-- The more stages, the more stable
--
-- The architecture implies a delay of at least CLK_SRC + CLK_DST*G_NB_STAGE cycles
--
-- The input and output vectors are binary coded. Conversion from binary to gray and
-- gray to binary are done inside the module.
--
-- Gray coding is used for counter resynchronization because only one bit can
-- change at one time (unit-distance code)
-- The skew on all the bits of the vector must be less than one source clock
-- cycle. This mecanism avoid vector discrepancy when a metastability happens.
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cdc_utils_pkg.bin2gray;
use work.cdc_utils_pkg.gray2bin;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity cdc_gray_sync is
  generic (
    G_NB_STAGE   : integer range 2 to integer'high := 2;     -- Number of synchronization stages (to reduce MTBF)
    G_REG_OUTPUT : boolean                         := true;  -- Register the output (for better timing)
    G_ACTIVE_RST : std_logic                       := '1';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)
    G_DATA_WIDTH : positive                        := 8      -- Binary vector data width
  );
  port (
    ----------------------
    -- Source domain
    ----------------------
    CLK_SRC      : in  std_logic;                                   -- Source clock
    RST_SRC      : in  std_logic;                                   -- Source reset (leave unconnected if not needed)
    DATA_SRC     : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- Binary vector to synchronize (synchronous to CLK_SRC)
    ----------------------
    -- Destination domain
    ----------------------
    CLK_DST      : in  std_logic;                                  -- Destination clock
    RST_DST      : in  std_logic;                                  -- Destination reset (leave unconnected if not needed)
    DATA_DST     : out std_logic_vector(G_DATA_WIDTH - 1 downto 0) -- Binary vector synchronized (synchronous to CLK_DST)
  );
end cdc_gray_sync;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of cdc_gray_sync is

  --------------------------------------------
  -- TYPES
  --------------------------------------------
  type t_sync_arr is array (G_NB_STAGE - 1 downto 0) of std_logic_vector(G_DATA_WIDTH - 1 downto 0);


  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  signal data_src_r   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  signal data_dst_arr : t_sync_arr;

  -- async reg attribute for xilinx
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of data_dst_arr : signal is "true";

begin

  --------------------------------------------
  -- Process: P_REG_DATA_SRC
  -- Description: Flip-flop stage for source data
  -- and gray encoding
  --------------------------------------------
  P_REG_DATA_SRC: process(CLK_SRC, RST_SRC)
  begin
    if G_ASYNC_RST and (RST_SRC = G_ACTIVE_RST) then
      -- Asynchronous reset
      data_src_r <= (others => '0');
    elsif rising_edge(CLK_SRC) then
      if (not G_ASYNC_RST) and (RST_SRC = G_ACTIVE_RST) then
        -- Synchronous reset
        data_src_r <= (others => '0');
      else
        -- Encode in gray and register data
        data_src_r <= bin2gray(DATA_SRC);
      end if;
    end if;
  end process P_REG_DATA_SRC;
  
  
  --------------------------------------------
  -- Process: P_CDC_GRAY_SYNC
  -- Description: Gray vector resynchronization
  --------------------------------------------
  P_CDC_GRAY_SYNC: process(CLK_DST, RST_DST)
  begin
    if G_ASYNC_RST and (RST_DST = G_ACTIVE_RST) then
      -- Asynchronous reset
      data_dst_arr <= (others => (others => '0'));
    elsif rising_edge(CLK_DST) then
      if (not G_ASYNC_RST) and (RST_DST = G_ACTIVE_RST) then
        -- Synchronous reset
        data_dst_arr <= (others => (others => '0'));
      else
        -- shift data
        data_dst_arr((G_NB_STAGE - 1) downto 1) <= data_dst_arr((G_NB_STAGE - 2) downto 0);
        data_dst_arr(0)                         <= data_src_r;
      end if;
    end if;
  end process P_CDC_GRAY_SYNC;


  --------------------------------------------
  -- Register the output data
  --------------------------------------------

  -- generate the output with no register
  GEN_NO_OUT_REG: if not G_REG_OUTPUT generate
  begin
    -- Decode from gray and set output data
    DATA_DST <= gray2bin(data_dst_arr(G_NB_STAGE - 1));
  end generate GEN_NO_OUT_REG;

  -- generate the output with a register
  GEN_OUT_REG: if G_REG_OUTPUT generate
  begin

    -- output data registering
    SYNC_REG: process(CLK_DST, RST_DST)
    begin
      if G_ASYNC_RST and (RST_DST = G_ACTIVE_RST) then
        -- Asynchronous reset
        DATA_DST <= (others => '0');
      elsif rising_edge(CLK_DST) then
        if (not G_ASYNC_RST) and (RST_DST = G_ACTIVE_RST) then
          -- Synchronous reset
          DATA_DST <= (others => '0');
        else
          DATA_DST <= gray2bin(data_dst_arr(G_NB_STAGE - 1));
        end if;
      end if;
    end process SYNC_REG;

  end generate GEN_OUT_REG;


end rtl;
