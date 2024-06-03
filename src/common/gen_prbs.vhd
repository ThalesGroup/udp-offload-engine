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
--        GEN_PRBS
--
------------------------------------------------
-- Pseudo-Random Bit Sequence Generator
------------------------------
-- This module is used to generate Pseudo Random Bit Sequence.
--
-- It uses two optimum LFSR tables to consume 
-- less resources for each XOR depending of the data size.
--
-- To do XOR in LFSR, it needs to register previous values of
-- a bus. The number of bits to register can be choose with generic.
--
-- LFSR tables are defined in prbs_pkg.
--
-- User can configure the initial value for PRBS with interface S_CONFIG.
------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.prbs_pkg.all;

entity gen_prbs is
  generic(
    G_ASYNC_RST   : boolean               := false;                                       -- Reset type
    G_ACTIVE_RST  : std_logic             := '1';                                         -- Value for active reset
    G_TDATA_WIDTH : positive              := 8;                                           -- Width of data bus
    G_PRBS_LENGTH : integer range 2 to 63 := 8                                            -- Number of bits to memorize for LFSR
  );
  port(
    CLK             : in  std_logic;
    RST             : in  std_logic;
    -- User configuration interface
    S_CONFIG_TREADY : out std_logic;
    S_CONFIG_TVALID : in  std_logic;
    S_CONFIG_TDATA  : in  std_logic_vector(G_PRBS_LENGTH - 1 downto 0);
    -- Output
    M_TREADY        : in  std_logic;
    M_TVALID        : out std_logic;
    M_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0)
  );
end gen_prbs;

architecture rtl of gen_prbs is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------
  constant C_PRBS_INIT : std_logic_vector(G_PRBS_LENGTH - 1 downto 0) := std_logic_vector(to_unsigned(C_INIT_PRBS, G_PRBS_LENGTH)); -- Default value to initialize PRBS  

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------
  type prbs_type is array (G_TDATA_WIDTH downto 0) of std_logic_vector(1 to G_PRBS_LENGTH); -- Array of G_TDATA_WIDTH + 1 raws and G_PRBS_LENGTH columns

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------
  signal prbs     : prbs_type;
  signal prbs_xor : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);

begin

  -- LFSR is applied only on 1 bit at time --> loop to randomize each bit of the bus
  G_PRBS_XOR : for I in 0 to G_TDATA_WIDTH - 1 generate

    prbs_xor(I) <= xor_lfsr(prbs => prbs(I), prbs_size => G_PRBS_LENGTH);
    -- XOR result is reinjected in the firts flip-flop (_xor_a) and then shifted (begin at 1)
    prbs(I + 1) <= prbs_xor(I) & prbs(I)(1 to G_PRBS_LENGTH - 1);

  end generate G_PRBS_XOR;

  -- Handle the axis interface
  P_PRBS_FF : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- When RST, PRBS is initialized with default value
      prbs(0)         <= C_PRBS_INIT;
      S_CONFIG_TREADY <= '0';
      M_TVALID        <= '0';
      M_TDATA         <= (others => '0');
    else
      if rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          prbs(0)         <= C_PRBS_INIT;
          S_CONFIG_TREADY <= '0';
          M_TVALID        <= '0';
          M_TDATA         <= (others => '0');
        else

          S_CONFIG_TREADY <= '1';
          M_TVALID        <= '1';

          -- Data are sending
          if (M_TREADY = '1') and (M_TVALID = '1') then
            M_TDATA <= prbs_xor;
            prbs(0) <= prbs(G_TDATA_WIDTH);
          end if;

          -- User can configure init value for PRBS
          if (S_CONFIG_TREADY = '1') and (S_CONFIG_TVALID = '1') then
            prbs(0) <= S_CONFIG_TDATA;
          end if;

        end if;
      end if;
    end if;
  end process P_PRBS_FF;

end rtl;
