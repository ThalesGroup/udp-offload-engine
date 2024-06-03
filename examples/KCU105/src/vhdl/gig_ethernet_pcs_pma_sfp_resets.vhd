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


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------
-- The entity declaration for the example design
--------------------------------------------------------------------------------

entity gig_ethernet_pcs_pma_sfp_resets is
   port (
    reset                    : in  std_logic;                -- Asynchronous reset for entire core.
    independent_clock_bufg   : in  std_logic;                -- System clock
    pma_reset                : out std_logic                 -- Synchronous transcevier PMA reset
   );
end gig_ethernet_pcs_pma_sfp_resets;

architecture rtl of gig_ethernet_pcs_pma_sfp_resets is

  ------------------------------------------------------------------------------
  -- internal signals used in this entity.
  ------------------------------------------------------------------------------

   -- PMA reset generation signals for tranceiver
   signal  pma_reset_pipe         : std_logic_vector(3 downto 0);   -- flip-flop pipeline for reset duration stretch

   -- These attributes will stop timing errors being reported in back annotated
   -- SDF simulation.
   attribute ASYNC_REG                   : string;
   attribute ASYNC_REG of pma_reset_pipe : signal is "TRUE";

begin


   -----------------------------------------------------------------------------
   -- Transceiver PMA reset circuitry
   -----------------------------------------------------------------------------
   process(reset, independent_clock_bufg)
   begin
     if (reset = '1' ) then
       pma_reset_pipe <= "1111";
     elsif independent_clock_bufg'event and independent_clock_bufg = '1' then
       pma_reset_pipe <= pma_reset_pipe(2 downto 0) & reset;
     end if;
   end process;

   pma_reset <= pma_reset_pipe(3)  ;

end rtl;
