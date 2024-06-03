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
--        AXIS_BROADCAST
--
------------------------------------------------
-- Axi4-Stream broadcast
----------------------
--
-- The entity is parametrizable in reset type and polarity
-- The entity is parametrizable in sizes of buses
-- The entity is parametrizable in number of masters
-- The entity is parametrizable in registering (roughly)
--
-- The master ports are concatenated on one single port with the least significant master on LSB
----------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.axis_utils_pkg.axis_broadcast_custom;


entity axis_broadcast is
  generic(
    G_ACTIVE_RST  : std_logic                         := '0';  -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean                           := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive                          := 32;   -- Width of the tdata vector of the stream
    G_TUSER_WIDTH : positive                          := 1;    -- Width of the tuser vector of the stream
    G_TID_WIDTH   : positive                          := 1;    -- Width of the tid vector of the stream
    G_TDEST_WIDTH : positive                          := 1;    -- Width of the tdest vector of the stream
    G_NB_MASTER   : positive range 2 to positive'high := 2;    -- Number of Master interfaces
    G_PIPELINE    : boolean                           := true  -- Whether to insert pipeline registers
  );
  port(
    -- GLOBAL
    CLK             : in  std_logic;
    RST             : in  std_logic;
    -- SLAVE INTERFACE
    S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID        : in  std_logic;
    S_TLAST         : in  std_logic;
    S_TUSER         : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID           : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST         : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY        : out std_logic;
    -- MASTER INTERFACE
    M_TDATA         : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);
    M_TVALID        : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TLAST         : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TUSER         : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);
    M_TSTRB         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TKEEP         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TID           : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);
    M_TDEST         : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);
    M_TREADY        : in  std_logic_vector(G_NB_MASTER - 1 downto 0)
  );
end axis_broadcast;


architecture rtl of axis_broadcast is


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
  constant C_REG_SLAVE_FORWARD    : boolean := G_PIPELINE;
  constant C_REG_SLAVE_BACKWARD   : boolean := G_PIPELINE;
  constant C_REG_MASTERS_FORWARD  : std_logic_vector(G_NB_MASTER - 1  downto 0) := (others => to_std_logic(G_PIPELINE));
  constant C_REG_MASTERS_BACKWARD : std_logic_vector(G_NB_MASTER - 1  downto 0) := (others => '0');


begin

  inst_axis_broadcast_custom : component axis_broadcast_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TUSER_WIDTH          => G_TUSER_WIDTH,
      G_TID_WIDTH            => G_TID_WIDTH,
      G_TDEST_WIDTH          => G_TDEST_WIDTH,
      G_NB_MASTER            => G_NB_MASTER,
      G_REG_SLAVE_FORWARD    => C_REG_SLAVE_FORWARD,
      G_REG_SLAVE_BACKWARD   => C_REG_SLAVE_BACKWARD,
      G_REG_MASTERS_FORWARD  => C_REG_MASTERS_FORWARD,
      G_REG_MASTERS_BACKWARD => C_REG_MASTERS_BACKWARD
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- SLAVE INTERFACE
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TUSER  => S_TUSER,
      S_TSTRB  => S_TSTRB,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => S_TREADY,
      -- MASTER INTERFACE
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
