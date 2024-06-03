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

-----------------------------
-- memory_utils_pkg
-----------------------------
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a library user
-----------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


------------------------------------------------------------------------
-- Package declaration
------------------------------------------------------------------------
package memory_utils_pkg is


  --------------------------------------------
  --
  -- MEMORY BLOCKS
  --
  --------------------------------------------

  -- True Dual Port Random Access Memory
  -- Memory with 2 read/write ports that can both be used independently
  component true_dp_ram is
    generic (
      G_DATA_WIDTH     : positive  := 32; -- Specify RAM word width (total port width depends on G_PACK_RATIO)
      G_ADDR_WIDTH     : positive  := 10; -- Specify RAM address width (number of entries is 2**ADDR_WIDTH)
      G_PACK_RATIO_A   : positive  := 1;  -- Specify RAM pack factor of word on each access on Port A (allow assymetry)
      G_OUT_REG_A      : boolean   := false; -- Specify output registers for Port A
      G_PACK_RATIO_B   : positive  := 1;  -- Specify RAM pack factor of word on each access on Port B (allow assymetry)
      G_OUT_REG_B      : boolean   := false; -- Specify output registers for Port B
      G_ACTIVE_RST     : std_logic := '1'; -- State at which the reset signal is asserted: active low or active high (not used if G_OUT_REG_* = false)
      G_ASYNC_RST      : boolean   := false; -- Type of reset used for the output registers: synchronous or asynchronous (not used if G_OUT_REG_* = false)
      G_RAM_STYLE      : string    := "AUTO"; -- Specify the ram synthesis style (technology dependant)
      G_MEM_INIT_FILE  : string    := ""; -- Specify name/location of memory initialization file if using one (leave blank if not)
      G_MEM_INIT_VALUE : std_logic := 'U' -- Specify the memory contents default initialization value if a file is not used
    );
    port (
      ----------------------
      -- PORT A
      ----------------------
      CLK_A            : in  std_logic; -- Port A Clock
      RST_A            : in  std_logic := not G_ACTIVE_RST; -- Port A reset used to clear output registers (not used if G_OUT_REG_A = false)
      EN_A             : in  std_logic := '1'; -- Port A RAM Enable, for additional power savings, disable port when not in use
      REGCE_A          : in  std_logic := '1'; -- Port A Output register clock enable
      ADDR_A           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_A))))) - 1 downto 0); -- Port A Address bus, width determined from RAM_DEPTH
      DIN_A            : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_A) - 1 downto 0) := (others => '-'); -- Port A RAM input data
      WREN_A           : in  std_logic := '0'; -- Port A Write enable
      DOUT_A           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_A) - 1 downto 0); -- Port A RAM output data
      ----------------------
      -- PORT B
      ----------------------
      CLK_B            : in  std_logic; -- Port B Clock
      RST_B            : in  std_logic := not G_ACTIVE_RST; -- Port B reset used to clear output registers (not used if G_OUT_REG_B = false)
      EN_B             : in  std_logic := '1'; -- Port B RAM Enable, for additional power savings, disable port when not in use
      REGCE_B          : in  std_logic := '1'; -- Port B Output register clock enable
      ADDR_B           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_B))))) - 1 downto 0); -- Port B Address bus, width determined from RAM_DEPTH
      DIN_B            : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_B) - 1 downto 0) := (others => '-'); -- Port B RAM input data
      WREN_B           : in  std_logic := '0'; -- Port B Write enable
      DOUT_B           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_B) - 1 downto 0)  -- Port B RAM output data
    );
  end component true_dp_ram;


  -- True Dual Port Random Access Memory with Byte Enable
  -- Memory with 2 read/write ports that can both be used independently
  component true_dp_ram_be is
    generic (
      G_DATA_WIDTH     : positive  := 32; -- Specify RAM word width (total port width depends on G_PACK_RATIO)
      G_ADDR_WIDTH     : positive  := 10; -- Specify RAM address width (number of entries is 2**ADDR_WIDTH)
      G_OUT_REG_A      : boolean   := false; -- Specify output registers for Port A
      G_OUT_REG_B      : boolean   := false; -- Specify output registers for Port B
      G_ACTIVE_RST     : std_logic := '1'; -- State at which the reset signal is asserted: active low or active high (not used if G_OUT_REG_* = false)
      G_ASYNC_RST      : boolean   := false; -- Type of reset used for the output registers: synchronous or asynchronous (not used if G_OUT_REG_* = false)
      G_RAM_STYLE      : string    := "AUTO"; -- Specify the ram synthesis style (technology dependant)
      G_MEM_INIT_FILE  : string    := ""; -- Specify name/location of memory initialization file if using one (leave blank if not)
      G_MEM_INIT_VALUE : std_logic := 'U' -- Specify the memory contents default initialization value if a file is not used
    );
    port (
      ----------------------
      -- PORT A
      ----------------------
      CLK_A            : in  std_logic; -- Port A Clock
      RST_A            : in  std_logic := not G_ACTIVE_RST; -- Port A reset used to clear output registers (not used if G_OUT_REG_A = false)
      EN_A             : in  std_logic := '1'; -- Port A RAM Enable, for additional power savings, disable port when not in use
      REGCE_A          : in  std_logic := '1'; -- Port A Output register clock enable
      ADDR_A           : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0); -- Port A Address bus, width determined from RAM_DEPTH
      DIN_A            : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0) := (others => '-'); -- Port A RAM input data
      WREN_A           : in  std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0) := (others => '0'); -- Port A Byte enable
      DOUT_A           : out std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- Port A RAM output data
      ----------------------
      -- PORT B
      ----------------------
      CLK_B            : in  std_logic; -- Port B Clock
      RST_B            : in  std_logic := not G_ACTIVE_RST; -- Port B reset used to clear output registers (not used if G_OUT_REG_B = false)
      EN_B             : in  std_logic := '1'; -- Port B RAM Enable, for additional power savings, disable port when not in use
      REGCE_B          : in  std_logic := '1'; -- Port B Output register clock enable
      ADDR_B           : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0); -- Port B Address bus, width determined from RAM_DEPTH
      DIN_B            : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0) := (others => '-'); -- Port B RAM input data
      WREN_B           : in  std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0) := (others => '0'); -- Port B Byte enable
      DOUT_B           : out std_logic_vector(G_DATA_WIDTH - 1 downto 0)  -- Port B RAM output data
    );
  end component true_dp_ram_be;


  -- Simple Dual Port Random Access Memory
  -- Memory with 1 write port and 1 read port with independent clocks
  component simple_dp_ram is
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
      R_RST            : in  std_logic := not G_ACTIVE_RST; -- Read Port Reset used to clear output registers (not used if G_OUT_REG = false)
      R_EN             : in  std_logic := '1'; -- Read Port RAM Enable, for additional power savings, disable port when not in use
      R_REGCE          : in  std_logic := '1'; -- Read Output Register Enable
      R_ADDR           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_R))))) - 1 downto 0); -- Read Port Address bus, width determined from RAM_DEPTH
      R_DATA           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_R) - 1 downto 0) -- Read Port RAM output data
    );
  end component simple_dp_ram;


  -- Simple Dual Port Random Access Memory and byte enable
  -- Memory with 1 write port and 1 read port with independent clocks
  component simple_dp_ram_be is
    generic (
      G_DATA_WIDTH     : positive  := 32; -- Specify RAM word width (total port width depends on G_PACK_RATIO)
      G_ADDR_WIDTH     : positive  := 10; -- Specify RAM address width (number of entries is 2**ADDR_WIDTH)
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
      W_EN             : in  std_logic; -- Write Port Enable (set to 0 to save energy while not used)
      W_BEN            : in  std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0); -- Write Port Byte enable
      W_ADDR           : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0); -- Write Port Address bus, width determined from RAM_DEPTH
      W_DATA           : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- Write Port RAM input data
      ----------------------
      -- Read port
      ----------------------
      R_CLK            : in  std_logic; -- Read Port Clock
      R_RST            : in  std_logic; -- Read Port Reset used to clear output registers (not used if G_OUT_REG = false)
      R_EN             : in  std_logic; -- Read Port RAM Enable, for additional power savings, disable port when not in use
      R_REGCE          : in  std_logic; -- Read Output Register Enable
      R_ADDR           : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0); -- Read Port Address bus, width determined from RAM_DEPTH
      R_DATA           : out std_logic_vector(G_DATA_WIDTH - 1 downto 0) -- Read Port RAM output data
    );
  end component simple_dp_ram_be;



  --------------------------------------------
  --
  -- FIFO (First In First Out) MEMORIES
  --
  --------------------------------------------

  -- Generic FIFO
  component fifo_gen is
    generic(
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
    port(
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
  end component fifo_gen;


end memory_utils_pkg;
