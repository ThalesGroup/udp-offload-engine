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

------------------------------------------------
--
--        CDC_RESET_SYNC
--
------------------------------------------------
-- Entity to resynchronize an asynchronous reset
--
-- The synchronized resets are asserted asynchronously but
-- de-asserted synchronously to the clocks
--
-- This entity is usually used with a PLL that generates multiple clocks.
-- Its clocks then gets their associated resets based on the lock signal of the PLL
--
-- The entity is parametrizable in number of clocks used, active edge of the
-- asynchronous reset, and the number of resynchronization stage.
--
-- The number of resynchronization stages can be used to ensure at least a given
-- number of edge before the reset becomes de-asserted (could be used with
-- synchronous resets for example)
--
--
----------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity cdc_reset_sync is
  generic (
    G_NB_STAGE    : integer range 2 to integer'high := 2; -- Number of synchronization stages (to reduce MTBF)
    G_NB_CLOCK    : positive                        := 5; -- Number of clock domain to synchronize the reset to
    G_ACTIVE_ARST : std_logic                       := '1' -- State at which the reset signal is asserted (active low or active high)
  );
  port (
    ----------------------
    -- Asynchronous domain
    ----------------------
    ARST          : in  std_logic; -- asynchronous reset to resynchronize
    ----------------------
    -- Synchronous domain
    ----------------------
    CLK           : in  std_logic_vector(G_NB_CLOCK - 1 downto 0); -- clocks for reset synchronisation
    SRST          : out std_logic_vector(G_NB_CLOCK - 1 downto 0); -- synchronized active high resets
    SRST_N        : out std_logic_vector(G_NB_CLOCK - 1 downto 0)  -- synchronized active low resets
  );
end cdc_reset_sync;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of cdc_reset_sync is

  --------------------------------------------
  -- TYPES
  --------------------------------------------
  type t_rst_sync is array (0 to G_NB_CLOCK-1) of std_logic_vector(G_NB_STAGE-1 downto 0);


  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  signal srst_arr   : t_rst_sync;
  signal srst_arr_n : t_rst_sync;
  
  
  --------------------------------------------
  -- ATTRIBUTES
  --------------------------------------------
  -- async reg attribute for xilinx
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of srst_arr   : signal is "TRUE";
  attribute ASYNC_REG of srst_arr_n : signal is "TRUE";


begin

  -- Generate Reset and Resetn for each clock
  GEN_RANGE : for i in 0 to G_NB_CLOCK - 1 generate
  begin

    --------------------------------------------
    -- For active High reset
    --------------------------------------------
    SYNC_CDC_POS : process(CLK(i), ARST)
    begin
      if ARST = G_ACTIVE_ARST then
        -- Asynchronous reset
        srst_arr(i) <= (others => '1');
      elsif rising_edge(CLK(i)) then
        -- Generate reset with synchronous de-assertion
        srst_arr(i) <= srst_arr(i)(G_NB_STAGE-2 downto 0) & '0';
      end if;
    end process SYNC_CDC_POS;
    
    SRST(i) <= srst_arr(i)(G_NB_STAGE-1);
  

    --------------------------------------------
    -- For active low reset
    --------------------------------------------
    SYNC_CDC_NEG : process(CLK(i), ARST)
    begin
      if ARST = G_ACTIVE_ARST then
        -- Asynchronous reset
        srst_arr_n(i) <= (others => '0');
      elsif rising_edge(CLK(i)) then
        -- Generate reset with synchronous de-assertion
        srst_arr_n(i) <= srst_arr_n(i)(G_NB_STAGE-2 downto 0) & '1';
      end if;
    end process SYNC_CDC_NEG;
    
    SRST_N(i) <= srst_arr_n(i)(G_NB_STAGE-1);
    
    
  end generate GEN_RANGE;

end rtl;
