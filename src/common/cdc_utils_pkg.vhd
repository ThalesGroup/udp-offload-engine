-- Copyright (c) 2022-2022 THALES. All Rights Reserved
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- File subject to timestamp TSP22X5365 Thales, in the name of Thales SIX GTS France, made on 10/06/2022.
--

-----------------------------
-- cdc_utils_pkg
-----------------------------
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a user of this library
-----------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-------------------------------------------
-- Package Declaration
-------------------------------------------
package cdc_utils_pkg is

  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------
  -- Convert a binary count to gray count
  function bin2gray(constant b : in std_logic_vector) return std_logic_vector;

  -- Convert a gray count to binary count
  function gray2bin(constant g : in std_logic_vector) return std_logic_vector;


  --------------------------------------------
  -- COMPONENTS
  --------------------------------------------

  ----------------------------------------------------------------------
  --
  -- Reset resynchronization components
  --
  ----------------------------------------------------------------------

  -- Synchronize a reset to multiple clocks
  -- This module generates reset signals that are asserted asynchronously
  -- but deasserted synchronously (thus garrantying a coherent initial state value)
  component cdc_reset_sync is
    generic(
      G_NB_STAGE    : integer range 2 to integer'high := 2;
      G_NB_CLOCK    : positive                        := 5;
      G_ACTIVE_ARST : std_logic                       := '1'
    );
    port(
      -- asynchronous domain
      ARST   : in  std_logic;           -- asynchronous reset to resynchronize

      -- synchronous domain
      CLK    : in  std_logic_vector(G_NB_CLOCK - 1 downto 0); -- clocks for reset synchronisation
      SRST   : out std_logic_vector(G_NB_CLOCK - 1 downto 0); -- synchronized active high resets
      SRST_N : out std_logic_vector(G_NB_CLOCK - 1 downto 0) -- synchronized active low resets
    );
  end component cdc_reset_sync;

  ----------------------------------------------------------------------
  --
  -- Single wire resynchronization components
  --
  ----------------------------------------------------------------------

  -- Synchronize a single wire
  -- Must be used for single wire signals only, you may encounter data discrepancy otherwise
  component cdc_bit_sync is
    generic(
      G_NB_STAGE   : integer range 2 to integer'high := 2; -- Number of synchronization stages (to reduce MTBF)
      G_ACTIVE_RST : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)
      G_RST_VALUE  : std_logic                       := '0' -- Value to which the internal vector resets
    );
    port(
      -- asynchronous domain
      DATA_ASYNC : in  std_logic;       -- Data to synchronize

      -- synchronous domain
      CLK        : in  std_logic;       -- Clock to which to resynchronize the data
      RST        : in  std_logic := not G_ACTIVE_RST; -- Reset (leave unconnected if not needed)
      DATA_SYNC  : out std_logic        -- Data synchronized in the output clock domain
    );
  end component cdc_bit_sync;

  -- Resynchronize a pulse signal
  -- A pulse signal is a signal being high only for 1 clock cycle
  -- If 2 clock cycles are to close one from the other, both cycles may be missed
  -- If this is a concern, you should consider using a handshake mechanism with no data
  component cdc_pulse_sync is
    generic(
      G_NB_STAGE   : integer range 2 to integer'high := 2; -- Number of synchronization stages (to reduce MTBF)
      G_REG_OUTPUT : boolean                         := true; -- Register the output pulse (for better timing)
      G_ACTIVE_RST : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean                         := false -- Type of reset used (synchronous or asynchronous resets)
    );
    port(
      -- input clokc domain
      CLK_IN    : in  std_logic;        -- Clock for input
      RST_IN    : in  std_logic;        -- Reset for input clock domain
      PULSE_IN  : in  std_logic;        -- Pulse signal to transmit (from input clock domain)

      -- output clock domain
      CLK_OUT   : in  std_logic;        -- Clock for output
      RST_OUT   : in  std_logic;        -- Reset for output clock domain
      PULSE_OUT : out std_logic         -- Pulse signal received (in output clock domain)
    );
  end component cdc_pulse_sync;

  ----------------------------------------------------------------------
  --
  -- Bus resynchronization
  --
  ----------------------------------------------------------------------

  -- Resynchronize binary vector via gray encoding/decoding
  -- Must be used only for vector resynchronization.
  -- As this vector will be encoded in gray, it can only increment or decrement by 1 for a proper resynchronization.
  component cdc_gray_sync is
    generic (
      G_NB_STAGE   : integer range 2 to integer'high := 2;     -- Number of synchronization stages (to reduce MTBF)
      G_REG_OUTPUT : boolean                         := true;  -- Register the output (for better timing)
      G_ACTIVE_RST : std_logic                       := '1';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)
      G_DATA_WIDTH : positive                        := 8      -- Binary vector data width
    );
    port (
      ----------------------
      -- Source domain
      ----------------------
      CLK_SRC      : in  std_logic;                                   -- Source clock
      RST_SRC      : in  std_logic := not G_ACTIVE_RST;               -- Source reset (leave unconnected if not needed)
      DATA_SRC     : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- Binary vector to synchronize (synchronous to CLK_SRC)
      ----------------------
      -- Destination domain
      ----------------------
      CLK_DST      : in  std_logic;                                  -- Destination clock
      RST_DST      : in  std_logic := not G_ACTIVE_RST;              -- Destination reset (leave unconnected if not needed)
      DATA_DST     : out std_logic_vector(G_DATA_WIDTH - 1 downto 0) -- Binary vector synchronized (synchronous to CLK_DST)
    );
  end component cdc_gray_sync;

end cdc_utils_pkg;


-------------------------------------------
-- Package Body
-------------------------------------------
package body cdc_utils_pkg is

  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------

  ---------------------
  -- bin2gray
  ---------------------
  -- Convert a binary count to gray count
  ---------------------
  function bin2gray(constant b : in std_logic_vector)
  return std_logic_vector is

    variable g : std_logic_vector(b'range);

  begin

    g(g'high) := b(b'high);
    for i in b'high - 1 downto b'low loop
      g(i) := b(i + 1) xor b(i);
    end loop;
    return g;

  end bin2gray;

  ---------------------
  -- gray2bin
  ---------------------
  -- Convert a gray count to binary count
  ---------------------
  function gray2bin(constant g : in std_logic_vector)
  return std_logic_vector is

    variable b : std_logic_vector(g'range);

  begin

    b(g'high) := g(b'high);
    for i in g'high - 1 downto g'low loop
      b(i) := b(i + 1) xor g(i);
    end loop;
    return b;

  end gray2bin;


end cdc_utils_pkg;