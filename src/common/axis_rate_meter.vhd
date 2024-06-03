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

--------------------------------------------------
-- AXIS RATE METER
--------------------------------------------------
-- The purpose of this module is to measure the flow on the input AXIS bus
-- It counts the number of valid bytes (TKEEP) and the number of clock cycles
--
-- The entity is generic in tkeep and counter width.
--
-- The trigger allows to initialize the measure if required and register the current values of counters
--
-- It is possible to associate the measurement to a number of bytes.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.dev_utils_pkg.count_bits;

entity axis_rate_meter is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TKEEP_WIDTH : positive  := 1;     -- Width of the tkeep vector of the stream
    G_CNT_WIDTH   : positive  := 32     -- Width of the clock counter
  );
  port(
    CLK                : in  std_logic;
    RST                : in  std_logic;
    -- Axis
    AXIS_TKEEP         : in  std_logic_vector(G_TKEEP_WIDTH - 1 downto 0);
    AXIS_TVALID        : in  std_logic;
    AXIS_TREADY        : in  std_logic;
    -- Ctrl
    TRIG_TVALID        : in  std_logic;
    TRIG_TDATA_INIT    : in  std_logic;
    TRIG_TDATA_BYTES   : in  std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
    -- Status
    CNT_TDATA_BYTES    : out std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
    CNT_TDATA_CYCLES   : out std_logic_vector(G_CNT_WIDTH - 1 downto 0);
    CNT_TUSER_OVERFLOW : out std_logic;
    CNT_TVALID         : out std_logic
  );
end axis_rate_meter;

architecture rtl of axis_rate_meter is

  --------------------------------
  -- Constant declaration
  --------------------------------
  constant C_MODE_RATE_MEAS : std_logic := '1';
  constant C_MODE_TIME_MEAS : std_logic := '0';

  --------------------------------
  -- Signals declaration
  --------------------------------

  -- Counter
  signal cnt_bytes  : unsigned((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
  signal cnt_cycles : unsigned(G_CNT_WIDTH - 1 downto 0);

  -- flags
  signal processing          : std_logic;
  signal mode                : std_logic;
  signal wait_first_transfer : std_logic;
  signal done                : std_logic;

begin

  mode <= C_MODE_RATE_MEAS when unsigned(TRIG_TDATA_BYTES) = 0 else C_MODE_TIME_MEAS;
  done <= '1' when (unsigned(TRIG_TDATA_BYTES) <= cnt_bytes) and (mode = C_MODE_TIME_MEAS) and (processing = '1') else '0';

  -- Handle counters
  P_RATE_METER : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- Asynchronous reset
      cnt_bytes           <= (others => '0');
      cnt_cycles          <= (others => '0');
      processing          <= '0';
      wait_first_transfer <= '0';
      CNT_TDATA_BYTES     <= (others => '0');
      CNT_TDATA_CYCLES    <= (others => '0');
      CNT_TUSER_OVERFLOW  <= '0';
      CNT_TVALID          <= '0';

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        cnt_bytes           <= (others => '0');
        cnt_cycles          <= (others => '0');
        processing          <= '0';
        wait_first_transfer <= '0';
        CNT_TDATA_BYTES     <= (others => '0');
        CNT_TDATA_CYCLES    <= (others => '0');
        CNT_TUSER_OVERFLOW  <= '0';
        CNT_TVALID          <= '0';

      else

        -- Clear handshake
        CNT_TVALID <= '0';

        -- Processing measurement
        if (processing = '1') then

          -- Bytes counter
          if (AXIS_TVALID = '1') and (AXIS_TREADY = '1') then
            cnt_bytes <= cnt_bytes + count_bits(AXIS_TKEEP);

            -- Clear flag
            wait_first_transfer <= '0';
          end if;

          -- time counter
          if (wait_first_transfer /= '1') or ((AXIS_TVALID = '1') and (AXIS_TREADY = '1')) then
            cnt_cycles <= cnt_cycles + 1;
          end if;
        end if;

        -- Handle trigger
        if TRIG_TVALID = '1' then
          -- reset overflow flag
          CNT_TUSER_OVERFLOW <= '0';

          -- Register counters values in continuous mode
          if (processing = '1') and (mode = C_MODE_RATE_MEAS) then
            CNT_TDATA_BYTES  <= std_logic_vector(cnt_bytes);
            CNT_TDATA_CYCLES <= std_logic_vector(cnt_cycles);
            CNT_TVALID       <= '1';
          end if;

          -- Init counters
          if TRIG_TDATA_INIT = '1' then
            cnt_bytes           <= (others => '0');
            cnt_cycles          <= (others => '0');
            wait_first_transfer <= '1';
          end if;

          -- Start processing
          processing <= '1';
        end if;

        -- Discontinuous mode
        if done = '1' then
          CNT_TDATA_BYTES  <= std_logic_vector(cnt_bytes);
          CNT_TDATA_CYCLES <= std_logic_vector(cnt_cycles);
          CNT_TVALID       <= '1';
          processing       <= '0';
        end if;

        -- Overflow 
        if (cnt_cycles = (cnt_cycles'range => '1')) then
          cnt_bytes          <= (others => '0');
          cnt_cycles         <= (others => '0');
          processing         <= '0';
          CNT_TDATA_BYTES    <= std_logic_vector(cnt_bytes);
          CNT_TDATA_CYCLES   <= std_logic_vector(cnt_cycles);
          CNT_TUSER_OVERFLOW <= '1';
          CNT_TVALID         <= '1';

        end if;
      end if;
    end if;
  end process P_RATE_METER;

end rtl;
