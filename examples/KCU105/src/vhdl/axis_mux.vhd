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
--        AXIS_MUX
--
------------------------------------------------
-- Axi4-Stream multiplexer
----------------------
-- The entity instantiate the axis_mux_custom sub module with pre-made
-- choices on generics parameters:
--  * architecture is not FAST (BINARY). The arbiter grants the priority thanks to a binary
--    encoded vector.
--
--  * arbitration scheme is FIXED priority. Highest priority is given to the port with the
--    lowest index
--
--  * Slave interface is registered both ways
--
--  * Master interface is register in forward direction only
--
-- Choices were made as trade-off on complexity (area) versus performance (max frequency).
--
--
----------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.axis_utils_pkg.axis_mux_custom;

entity axis_mux is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 32;    -- Width of the tdata vector of the stream
    G_TUSER_WIDTH : positive  := 1;     -- Width of the tuser vector of the stream
    G_TID_WIDTH   : positive  := 1;     -- Width of the tid vector of the stream
    G_TDEST_WIDTH : positive  := 1;     -- Width of the tdest vector of the stream
    G_NB_SLAVE    : positive  := 2;     -- Number of Slave interfaces
    G_PIPELINE    : boolean   := true;  -- Whether to insert pipeline registers
    G_PACKET_MODE : boolean   := false  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
  );
  port(
    -- GLOBAL
    CLK      : in  std_logic;
    RST      : in  std_logic;
    -- SLAVE INTERFACE
    S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0);
    S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0);
    S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0);
    S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0);
    S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
    -- MASTER INTERFACE
    M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID : out std_logic;
    M_TLAST  : out std_logic;
    M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY : in  std_logic
  );
end axis_mux;

architecture rtl of axis_mux is

  -- function for conversion from boolean to std_logic
  function to_std_logic(constant b: in boolean) return std_logic is

    variable s : std_logic;

  begin

    if b then
      s := '1';
    else
      s := '0';
    end if;

    return s;
  end function to_std_logic;

  -- constants for generic parameters deduced from the G_PIPELINE parameter
  constant C_REG_MASTER_FORWARD  : boolean                                   := G_PIPELINE;
  constant C_REG_MASTER_BACKWARD : boolean                                   := false;
  constant C_REG_SLAVES_FORWARD  : std_logic_vector(G_NB_SLAVE - 1 downto 0) := (others => to_std_logic(G_PIPELINE));
  constant C_REG_SLAVES_BACKWARD : std_logic_vector(G_NB_SLAVE - 1 downto 0) := (others => to_std_logic(G_PIPELINE));
  constant C_REG_ARB_FORWARD     : boolean                                   := false;
  constant C_REG_ARB_BACKWARD    : boolean                                   := false;


begin

  inst_axis_mux_custom : component axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_TUSER_WIDTH         => G_TUSER_WIDTH,
      G_TID_WIDTH           => G_TID_WIDTH,
      G_TDEST_WIDTH         => G_TDEST_WIDTH,
      G_NB_SLAVE            => G_NB_SLAVE,
      G_REG_SLAVES_FORWARD  => C_REG_SLAVES_FORWARD,
      G_REG_SLAVES_BACKWARD => C_REG_SLAVES_BACKWARD,
      G_REG_MASTER_FORWARD  => C_REG_MASTER_FORWARD,
      G_REG_MASTER_BACKWARD => C_REG_MASTER_BACKWARD,
      G_REG_ARB_FORWARD     => C_REG_ARB_FORWARD,
      G_REG_ARB_BACKWARD    => C_REG_ARB_BACKWARD,
      G_PACKET_MODE         => G_PACKET_MODE,
      G_ROUND_ROBIN         => false,
      G_FAST_ARCH           => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TUSER  => S_TUSER,
      S_TSTRB  => S_TSTRB,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => S_TREADY,
      M_TDATA  => M_TDATA,
      M_TVALID => M_TVALID,
      M_TLAST  => M_TLAST,
      M_TUSER  => M_TUSER,
      M_TSTRB  => M_TSTRB,
      M_TKEEP  => M_TKEEP,
      M_TID    => M_TID,
      M_TDEST  => M_TDEST,
      M_TREADY => M_TREADY
    );


end rtl;
