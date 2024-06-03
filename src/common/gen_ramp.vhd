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
--        GEN_RAMP
--
------------------------------------------------
-- Ramp Generator
------------------------------
-- This module is used to generate incremental data.
--
-- It can incremente and decremente data. 
-- User can configure the ramp (init value and step).
------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_ramp is
  generic(
    G_ASYNC_RST   : boolean   := false;                                                   -- Reset type            
    G_ACTIVE_RST  : std_logic := '1';                                                     -- Value for active reset
    G_TDATA_WIDTH : positive  := 8                                                        -- Width of data bus     
  );
  port(
    CLK                 : in  std_logic;
    RST                 : in  std_logic;
    -- User configuration interface
    S_CONFIG_TREADY     : out std_logic;
    S_CONFIG_TVALID     : in  std_logic;
    S_CONFIG_TDATA_INIT : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_CONFIG_TDATA_STEP : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    -- Output
    M_TREADY            : in  std_logic;
    M_TVALID            : out std_logic;
    M_TDATA             : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0)
  );
end gen_ramp;

architecture rtl of gen_ramp is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------
  constant C_RAMP_STEP : signed(M_TDATA'high downto 0) := to_signed(1, M_TDATA'length);   -- Default value for increament

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------
  signal config_flag : std_logic;
  signal ramp_step   : signed(M_TDATA'high downto 0);
  signal ramp_init   : std_logic_vector(M_TDATA'high downto 0);

begin

  -- Handle the ramp generation and axis interface
  P_RAMP : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- When RST, RAMP is initialized with default value
      config_flag     <= '0';
      ramp_step       <= C_RAMP_STEP;
      ramp_init       <= (others => '0');
      S_CONFIG_TREADY <= '0';
      M_TVALID        <= '0';
      M_TDATA         <= (others => '0');
    else
      if rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          config_flag     <= '0';
          ramp_step       <= C_RAMP_STEP;
          ramp_init       <= (others => '0');
          S_CONFIG_TREADY <= '0';
          M_TVALID        <= '0';
          M_TDATA         <= (others => '0');
        else

          S_CONFIG_TREADY <= '1';
          M_TVALID        <= '1';

          -- Data are sending
          if (M_TREADY = '1') and (M_TVALID = '1') then
            if (config_flag /= '1') then
              M_TDATA <= std_logic_vector(signed(M_TDATA) + ramp_step);
            else
              M_TDATA     <= ramp_init;
              config_flag <= '0';
            end if;
          end if;

          -- User can configure init step and init value for RAMP
          if (S_CONFIG_TREADY = '1') and (S_CONFIG_TVALID = '1') then
            ramp_step <= signed(S_CONFIG_TDATA_STEP);
            if (M_TREADY = '1') then
              M_TDATA <= S_CONFIG_TDATA_INIT;
            else
              ramp_init   <= S_CONFIG_TDATA_INIT;
              config_flag <= '1';
            end if;
          end if;

        end if;
      end if;
    end if;
  end process P_RAMP;

end rtl;
