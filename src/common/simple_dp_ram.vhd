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
--       SIMPLE_DP_RAM
----------------------------------
-- Simple Dual Port (1 write + 1 read ports) Random Access Memory
-- with 2 clock domains
-----------
-- The entity is parametrizable in data width
-- The entity is parametrizable in address width (memory depth)
-- The entity is parametrizable in optional output registers for read port
-- The entity is parametrizable in initial content at power up
-- The entity is parametrizable in synthesis ram style
--
-- On both ports, data are written and read on the rising edge of the
-- corresponding clock.
-- The W_EN signal acts as an enable for the write operation.
-- The R_EN signal acts as an enable for the read operation. Deassert theese
-- signals when the memory is unused to save power.
-- The W_DATA data are written at W_ADDR address in the memory
-- The R_DATA are read from the R_ADDR address in the memory
-- (available at next cycle if no output registers or after 2 cycles otherwise)
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.memory_utils_pkg.true_dp_ram;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity simple_dp_ram is
  generic (
    G_DATA_WIDTH     : positive  := 32; -- Specify RAM word width (total port width depends on G_PACK_RATIO)
    G_ADDR_WIDTH     : positive  := 10; -- Specify RAM address width (number of entries is 2**ADDR_WIDTH)
    G_PACK_RATIO_W   : positive  := 1;  -- Specify RAM pack factor of word on each access on Port W (allow assymetry)
    G_PACK_RATIO_R   : positive  := 1;  -- Specify RAM pack factor of word on each access on Port R (allow assymetry)
    G_OUT_REG        : boolean   := false; -- Specify output registers for read port
    G_ACTIVE_RST     : std_logic := '1'; -- State at which the reset signal is asserted: active low or active high (not used if G_OUT_REG = false)
    G_ASYNC_RST      : boolean   := false; -- Type of reset used for read port output registers: asynchronous or synchronous (not used if G_OUT_REG = false)
    G_RAM_STYLE      : string    := "AUTO"; -- Specify the ram synthesis style (technology dependant)
    G_MEM_INIT_FILE  : string    := ""; -- Specify name/location of memory initialization file if using one (leave blank if not)
    G_MEM_INIT_VALUE : std_logic := 'U' -- Specify the memory contents default initialization value if a file is not used
  );
  port (
    ----------------------
    -- Write port
    ----------------------
    W_CLK            : in  std_logic; -- Write Port Clock
    W_EN             : in  std_logic; -- Write Port Write enable
    W_ADDR           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_W))))) - 1 downto 0); -- Write Port Address bus, width determined from RAM_DEPTH
    W_DATA           : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_W)- 1 downto 0); -- Write Port RAM input data
    ----------------------
    -- Read port
    ----------------------
    R_CLK            : in  std_logic; -- Read Port Clock
    R_RST            : in  std_logic; -- Read Port Reset used to clear output registers (not used if G_OUT_REG = false)
    R_EN             : in  std_logic; -- Read Port RAM Enable, for additional power savings, disable port when not in use
    R_REGCE          : in  std_logic; -- Read Output Register Enable
    R_ADDR           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_R))))) - 1 downto 0); -- Read Port Address bus, width determined from RAM_DEPTH
    R_DATA           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_R) - 1 downto 0) -- Read Port RAM output data
  );
begin

  -- Check that PACK ratios are power of 2
  -- synthesis translate_off
  assert G_PACK_RATIO_W = (2 ** integer(log2(real(G_PACK_RATIO_W)))) report "Pack ratio for port W must be a power of 2" severity error;
  assert G_PACK_RATIO_R = (2 ** integer(log2(real(G_PACK_RATIO_R)))) report "Pack ratio for port R must be a power of 2" severity error;
  -- synthesis translate_on

end simple_dp_ram;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of simple_dp_ram is

begin


  --------------------------------------------
  -- True Dual Port RAM instantiation
  --------------------------------------------
  -- Use A port for Write and B port for Read
  inst_true_dp_ram: true_dp_ram
    generic map (
      G_DATA_WIDTH     => G_DATA_WIDTH,
      G_ADDR_WIDTH     => G_ADDR_WIDTH,
      G_PACK_RATIO_A   => G_PACK_RATIO_W,
      G_OUT_REG_A      => false,
      G_PACK_RATIO_B   => G_PACK_RATIO_R,
      G_OUT_REG_B      => G_OUT_REG,
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_RAM_STYLE      => G_RAM_STYLE,
      G_MEM_INIT_FILE  => G_MEM_INIT_FILE,
      G_MEM_INIT_VALUE => G_MEM_INIT_VALUE
    )
    port map (

      -- A Port for Write
      CLK_A            => W_CLK,
      RST_A            => '0',
      EN_A             => W_EN,
      REGCE_A          => '0',
      ADDR_A           => W_ADDR,
      DIN_A            => W_DATA,
      WREN_A           => '1',
      DOUT_A           => open,

      -- B port for Read
      CLK_B            => R_CLK,
      RST_B            => R_RST,
      EN_B             => R_EN,
      REGCE_B          => R_REGCE,
      ADDR_B           => R_ADDR,
      DIN_B            => (others => '-'),
      WREN_B           => '0',
      DOUT_B           => R_DATA
    );


end rtl;
