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

-- Code inspired by C. BARA, Xilinx template, Altera template

----------------------------------
--       TRUE_DP_RAM
----------------------------------
-- True Dual Port (2 write + 2 read ports) Random Access Memory
-- with 2 clock domains
-----------
-- The entity is parametrizable in data width
-- The entity is parametrizable in address width (memory depth)
-- The entity is parametrizable in optional output registers for each port
-- The entity is parametrizable in asymmetric ratio
-- The entity is parametrizable in initial content at power up
-- The entity is parametrizable in synthesis ram style
--
-- On both ports, data are written and read on the rising edge of the
-- corresponding clock.
-- The WR_EN signal allows the user to select the operation (write when asserted,
-- read otherwise). It's not possible to read and write in the same cycle on the same port: "write no read"
-- (avoid the read/write behaviour confusion and save power on 7 series devices)
-- The EN signal acts as an enable for the operation. Deassert this signal when
-- the memory is unused to save power
-- The DIN data are written at ADDR address in the memory
-- The DOUT data are read from the ADDR address in the memory
-- (available at next cycle if no output registers or after 2 cycles otherwise)
--
-- The code is optimized for Xilinx 7 series but is written in generic VHDL
----------------------------------

use std.textio.all; -- to parse the .mif

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use ieee.math_real.all;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity true_dp_ram is
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
    RST_A            : in  std_logic; -- Port A reset used to clear output registers (not used if G_OUT_REG_A = false)
    EN_A             : in  std_logic; -- Port A RAM Enable, for additional power savings, disable port when not in use
    REGCE_A          : in  std_logic; -- Port A Output register clock enable
    ADDR_A           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_A))))) - 1 downto 0); -- Port A Address bus, width determined from RAM_DEPTH
    DIN_A            : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_A) - 1 downto 0); -- Port A RAM input data
    WREN_A           : in  std_logic; -- Port A Write enable
    DOUT_A           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_A) - 1 downto 0); -- Port A RAM output data
    ----------------------
    -- PORT B
    ----------------------
    CLK_B            : in  std_logic; -- Port B Clock
    RST_B            : in  std_logic; -- Port B reset used to clear output registers (not used if G_OUT_REG_B = false)
    EN_B             : in  std_logic; -- Port B RAM Enable, for additional power savings, disable port when not in use
    REGCE_B          : in  std_logic; -- Port B Output register clock enable
    ADDR_B           : in  std_logic_vector((G_ADDR_WIDTH - integer(floor(log2(real(G_PACK_RATIO_B))))) - 1 downto 0); -- Port B Address bus, width determined from RAM_DEPTH
    DIN_B            : in  std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_B) - 1 downto 0); -- Port B RAM input data
    WREN_B           : in  std_logic; -- Port B Write enable
    DOUT_B           : out std_logic_vector((G_DATA_WIDTH * G_PACK_RATIO_B) - 1 downto 0)  -- Port B RAM output data
  );
begin
  -- Check that PACK ratios are power of 2
  -- synthesis translate_off
  assert G_PACK_RATIO_A = (2 ** integer(log2(real(G_PACK_RATIO_A)))) report "Pack ratio for port A must be a power of 2" severity error;
  assert G_PACK_RATIO_B = (2 ** integer(log2(real(G_PACK_RATIO_B)))) report "Pack ratio for port B must be a power of 2" severity error;
  -- synthesis translate_on
end true_dp_ram;


------------------------------------------------------------------------
--
-- Generic architecture (Xilinx 7 series optimized)
--
------------------------------------------------------------------------
architecture rtl of true_dp_ram is

  --------------------------------------------
  -- TYPES
  --------------------------------------------
  -- memory type
  type mem_array is array ((2**(G_ADDR_WIDTH)) - 1 downto 0) of std_logic_vector(G_DATA_WIDTH - 1 downto 0);


  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------
  -- function for initialization from a file
  impure function init_ram_from_file(constant ramfilename : in string) return mem_array is
    -- hds checking_off
    -- Deactivate DRC (SR9 rule) because signal type "file" is synthesizable for RAM initialization
    file ramfile         : text;
    -- hds checking_on

    -- hds checking_off
    -- Deactivate DRC (STYP4 rule) because signal type "line" is synthesizable for RAM initialization
    variable ramfileline : line;
    -- hds checking_on
    variable ram_name    : mem_array;
    variable bitvec      : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  begin
    ram_name := (others => (others => G_MEM_INIT_VALUE));
    if ramfilename /= "" then
      file_open(ramfile, ramfilename, READ_MODE);
      for i in ram_name'low to ram_name'high loop
        if endfile(ramfile) then
          exit; -- check if end of file is reached
        end if;
        readline(ramfile, ramfileline);
        read(ramfileline, bitvec);
        ram_name(i) := bitvec;
      end loop;
      assert endfile(ramfile) report "Init_ram_from_file : Out of memory range! End of file has not been loaded" severity error;

      file_close(ramfile);
    end if;
    return ram_name;
  end function init_ram_from_file;


  --------------------------------------------
  -- VARIABLES
  --------------------------------------------
  -- memory itself
  -- hds checking_off
  -- Deactivate DRC (SIN1 rule) because RAM/ROM can be initialized at declaration (synthesizable)
  shared variable mem : mem_array := init_ram_from_file(G_MEM_INIT_FILE);
  -- hds checking_on


  --------------------------------------------
  -- ATTRIBUTES
  --------------------------------------------
  -- memory style
  attribute ramstyle  : string;         -- altera
  attribute ramstyle of mem : variable is G_RAM_STYLE;
  attribute ram_style : string;         -- xilinx
  attribute ram_style of mem : variable is G_RAM_STYLE;


  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  -- Data output registers
  signal dout_a_int : std_logic_vector(DOUT_A'range);
  signal dout_b_int : std_logic_vector(DOUT_B'range);


begin

  --------------------------------------------
  -- SYNC_PORT_A
  --------------------------------------------
  -- synchronous process to write on port A
  SYNC_PORT_A : process(CLK_A)
    -- Address extension for sub word access
    constant C_ADDR_WIDTH_EXT_A : integer := integer(ceil(log2(real(G_PACK_RATIO_A))));
  begin
    if rising_edge(CLK_A) then
      -- Loop over the words in the data port
      for w in 0 to G_PACK_RATIO_A - 1 loop
        -- Check if memory is enabled
        if EN_A = '1' then
          -- Work in write no read mode
          if WREN_A = '1' then
            -- Write the word into memory
            mem(to_integer(unsigned(ADDR_A) & to_unsigned(w, C_ADDR_WIDTH_EXT_A)))
              := DIN_A(((w + 1) * G_DATA_WIDTH) - 1 downto w * G_DATA_WIDTH);
          else
            -- Read the word from memory
            dout_a_int(((w + 1) * G_DATA_WIDTH) - 1 downto w * G_DATA_WIDTH)
              <= mem(to_integer(unsigned(ADDR_A) & to_unsigned(w, C_ADDR_WIDTH_EXT_A)));
          end if;
        end if;
      end loop;
    end if;
  end process SYNC_PORT_A;


  --------------------------------------------
  -- GEN_OUTPUT_REG_PORT_A
  -- Add one series of registers at Port A output
  -- to increase memory performance (max frequency)
  --------------------------------------------
  GEN_OUTPUT_REG_PORT_A : if G_OUT_REG_A generate
    -- internal signals for resets
    signal rst_a_async : std_logic;     -- asynchronous reset for input
    signal rst_a_sync  : std_logic;     -- synchronous reset for input

  begin

    -- selecting the required resets
    rst_a_async <= RST_A when G_ASYNC_RST else (not G_ACTIVE_RST);
    rst_a_sync  <= (not G_ACTIVE_RST) when G_ASYNC_RST else RST_A;

    --------------------------------------------
    -- OUTPUT_REG_PORT_A
    --------------------------------------------
    -- Process managing output registers for Port A
    OUTPUT_REG_PORT_A : process(CLK_A, rst_a_async)
    begin
      if rst_a_async = G_ACTIVE_RST then
        DOUT_A <= (others => '0');
      elsif rising_edge(CLK_A) then
        if rst_a_sync = G_ACTIVE_RST then
          DOUT_A <= (others => '0');
        elsif REGCE_A = '1' then
          DOUT_A <= dout_a_int;
        end if;
      end if;
    end process OUTPUT_REG_PORT_A;

  end generate GEN_OUTPUT_REG_PORT_A;


  --------------------------------------------
  -- NO_OUTPUT_REG_PORT_A
  -- No register at Port A output
  --------------------------------------------
  NO_OUTPUT_REG_PORT_A : if not G_OUT_REG_A generate
    DOUT_A <= dout_a_int;
  end generate NO_OUTPUT_REG_PORT_A;


  --------------------------------------------
  -- SYNC_PORT_B
  --------------------------------------------
  -- synchronous process to write on port B
  SYNC_PORT_B : process(CLK_B)
    -- Address extension for sub word access
    constant C_ADDR_WIDTH_EXT_B : integer := integer(ceil(log2(real(G_PACK_RATIO_B))));
  begin
    if rising_edge(CLK_B) then
      -- Loop over the words in the data port
      for w in 0 to G_PACK_RATIO_B - 1 loop
        -- Check if memory is enabled
        if EN_B = '1' then
          -- Work in write no read mode
          if WREN_B = '1' then
            -- Write the word into memory
            mem(to_integer(unsigned(ADDR_B) & to_unsigned(w, C_ADDR_WIDTH_EXT_B)))
              := DIN_B(((w + 1) * G_DATA_WIDTH) - 1 downto w * G_DATA_WIDTH);
          else
            -- Read the word from memory
            dout_b_int(((w + 1) * G_DATA_WIDTH) - 1 downto w * G_DATA_WIDTH)
              <= mem(to_integer(unsigned(ADDR_B) & to_unsigned(w, C_ADDR_WIDTH_EXT_B)));
          end if;
        end if;
      end loop;
    end if;
  end process SYNC_PORT_B;


  --------------------------------------------
  -- GEN_OUTPUT_REG_PORT_B
  -- Add one series of registers at Port B output
  -- to increase memory performance (max frequency)
  --------------------------------------------
  GEN_OUTPUT_REG_PORT_B : if G_OUT_REG_B generate
    -- internal signals for resets
    signal rst_b_async : std_logic;     -- asynchronous reset for output
    signal rst_b_sync  : std_logic;     -- synchronous reset for output

  begin

    -- selecting the required resets
    rst_b_async <= RST_B when G_ASYNC_RST else (not G_ACTIVE_RST);
    rst_b_sync  <= (not G_ACTIVE_RST) when G_ASYNC_RST else RST_B;

    --------------------------------------------
    -- OUTPUT_REG_PORT_B
    --------------------------------------------
    -- Process managing output registers for Port B
    OUTPUT_REG_PORT_B : process(CLK_B, rst_b_async)
    begin
      if rst_b_async = G_ACTIVE_RST then
        DOUT_B <= (others => '0');
      elsif rising_edge(CLK_B) then
        if rst_b_sync = G_ACTIVE_RST then
          DOUT_B <= (others => '0');
        elsif REGCE_B = '1' then
          DOUT_B <= dout_b_int;
        end if;
      end if;
    end process OUTPUT_REG_PORT_B;

  end generate GEN_OUTPUT_REG_PORT_B;


  --------------------------------------------
  -- NO_OUTPUT_REG_PORT_B
  -- No register at Port B output
  --------------------------------------------
  NO_OUTPUT_REG_PORT_B : if not G_OUT_REG_B generate
    DOUT_B <= dout_b_int;
  end generate NO_OUTPUT_REG_PORT_B;

end rtl;
