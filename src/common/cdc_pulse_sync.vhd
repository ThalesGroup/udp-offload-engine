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
--       CDC_PULSE_SYNC
----------------------------------
-- Clock Domain Crossing Synchronization for a Pulse
-----------
-- The entity is parametrizable in synchronization stage
-- The entity is parametrizable in output registering
-- The entity is parametrizable in reset polarity (active 1 or active 0) and mode (synchronous/asynchronous)
--
-- The synchronization is based on an internal signal which toggles
-- on each input pulse.
-- The toggling is then resynchronized and decoded to generate a pulse at the output.
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cdc_utils_pkg.cdc_bit_sync;

entity cdc_pulse_sync is
  generic(
    G_NB_STAGE   : integer range 2 to integer'high := 2; -- Number of synchronization stages (to reduce MTBF)
    G_REG_OUTPUT : boolean                         := true; -- Register the output pulse (for better timing)
    G_ACTIVE_RST : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean                         := false -- Type of reset used (synchronous or asynchronous resets)
  );
  port(
    -- input clokc domain
    CLK_IN    : in  std_logic;          -- Clock for input
    RST_IN    : in  std_logic;          -- Reset for input clock domain
    PULSE_IN  : in  std_logic;          -- Pulse signal to transmit (from input clock domain)
    -- output clock domain
    CLK_OUT   : in  std_logic;          -- Clock for output
    RST_OUT   : in  std_logic;          -- Reset for output clock domain
    PULSE_OUT : out std_logic           -- Pulse signal received (in output clock domain)
  );
end cdc_pulse_sync;

architecture rtl of cdc_pulse_sync is

  -- toggle signal on pulse
  signal toggle_in    : std_logic;
  signal toggle_out   : std_logic;
  signal toggle_out_r : std_logic;

  -- edge detection signals
  signal pulse_out_int : std_logic;

begin

  ----------------------------
  -- Input toggle generation
  ----------------------------
  SYNC_TOGGLE : process(RST_IN, CLK_IN)
  begin
    if G_ASYNC_RST and (RST_IN = G_ACTIVE_RST) then
      toggle_in <= '0';
    elsif rising_edge(CLK_IN) then
      if (not G_ASYNC_RST) and (RST_IN = G_ACTIVE_RST) then
        toggle_in <= '0';
      else
        toggle_in <= PULSE_IN xor toggle_in; -- toggle on pulse
      end if;
    end if;
  end process SYNC_TOGGLE;

  -------------------------
  -- Wire synchronization
  -------------------------
  inst_cdc_bit_sync : cdc_bit_sync
    generic map(
      G_NB_STAGE   => G_NB_STAGE,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_RST_VALUE  => '0'
    )
    port map(
      DATA_ASYNC => toggle_in,
      CLK        => CLK_OUT,
      RST        => RST_OUT,
      DATA_SYNC  => toggle_out
    );

  ----------------------------
  -- Edge detection on toggle
  ----------------------------

  -- register toggle
  SYNC_PULSE : process(RST_OUT, CLK_OUT)
  begin
    if G_ASYNC_RST and (RST_OUT = G_ACTIVE_RST) then
      toggle_out_r <= '0';
    elsif rising_edge(CLK_OUT) then
      if (not G_ASYNC_RST) and (RST_OUT = G_ACTIVE_RST) then
        toggle_out_r <= '0';
      else
        toggle_out_r <= toggle_out;     -- register the toggle for edge detection
      end if;
    end if;
  end process SYNC_PULSE;

  -- pulse out when detection of an edge
  pulse_out_int <= toggle_out_r xor toggle_out;

  ------------------------------
  -- Register the output pulse
  ------------------------------

  -- generate the output with no register
  GEN_NOREG : if not G_REG_OUTPUT generate
  begin
    -- direct assignation
    PULSE_OUT <= pulse_out_int; -- @suppress PID1 implemented rule is case sensitive
  end generate GEN_NOREG;

  -- generate the output with a register
  GEN_REG : if G_REG_OUTPUT generate
  begin

    -- output pulse registering
    SYNC_REG : process(RST_OUT, CLK_OUT)
    begin
      if G_ASYNC_RST and (RST_OUT = G_ACTIVE_RST) then
        PULSE_OUT <= '0';
      elsif rising_edge(CLK_OUT) then
        if (not G_ASYNC_RST) and (RST_OUT = G_ACTIVE_RST) then
          PULSE_OUT <= '0';
        else
          PULSE_OUT <= pulse_out_int;   -- registering the output pulse
        end if;
      end if;
    end process SYNC_REG;

  end generate GEN_REG;

end rtl;
