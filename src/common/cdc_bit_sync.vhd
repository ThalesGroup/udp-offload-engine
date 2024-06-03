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
--       CDC_BIT_SYNC
----------------------------------
-- Clock Domain Crossing Synchronization for an Asynchronous bit
-----------
-- The entity is parametrizable in number of synchronization stage
-- The entity is parametrizable in reset polarity
-- The entity is parametrizable in reset state
--
-- The synchronization is done thanks to a multiple flip flop
-- architecture which ensures to avoid metastability
-- The more stage, the more stable
--
-- The architecture implies a delay of at least G_NB_STAGE cycles
--
-- The reset is asynchronous and is applied on each flip flop. It is unnecessary
-- to use the reset signal when it is ensured to be hold at least G_NB_STAGE cycles
-- for downstream stages
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cdc_bit_sync is
  generic(
    G_NB_STAGE   : integer range 2 to integer'high := 2; -- Number of synchronization stages (to reduce MTBF)
    G_ACTIVE_RST : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)
    G_RST_VALUE  : std_logic                       := '0' -- Value to which the internal vector resets
  );
  port(
    -- asynchronous domain
    DATA_ASYNC : in  std_logic;         -- Data to synchronize
    -- synchronous domain
    CLK        : in  std_logic;         -- Clock to which to resynchronize the data
    RST        : in  std_logic;         -- Reset (leave unconnected if not needed)
    DATA_SYNC  : out std_logic          -- Data synchronized in the output clock domain
  );
end cdc_bit_sync;

architecture rtl of cdc_bit_sync is

  signal data_int : std_logic_vector(G_NB_STAGE - 1 downto 0);

  -- async reg attribute for xilinx
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of data_int : signal is "TRUE";

begin

  --------------------------
  -- Synchronization process
  --------------------------
  SYNC_CDC : process(RST, CLK)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      data_int <= (others => G_RST_VALUE);
    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        data_int <= (others => G_RST_VALUE);
      else
        data_int <= data_int(G_NB_STAGE - 2 downto 0) & DATA_ASYNC;
      end if;
    end if;

  end process SYNC_CDC;

  DATA_SYNC <= data_int(G_NB_STAGE - 1);

end rtl;
