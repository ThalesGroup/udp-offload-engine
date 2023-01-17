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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

----------------------------------
-- Package axis_pkg
----------------------------------
--
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a library user
--
-- This package contains the declaration of the following component
-- * axis_register
-- * axis_mux
-- * axis_mux_custom
-- * axis_demux
-- * axis_demux_custom
-- * axis_switch
-- * axis_switch_crossbar
-- * axis_switch_backbone
-- * axis_cdc
-- * axis_fifo
-- * axis_broadcast
-- * axis_broadcast_custom
-- * axis_dwidth_converter
-- * axis_combine
-- * axis_rate_limit
-- * axis_enable
-- * axis_pkt_concat
-- * axis_pkt_split_bytes
-- * axis_pkt_split_words
-- * axis_pkt_align
--
-- This package also contains the declaration of the following functions
-- * is_bytes_align
----------------------------------
package axis_utils_pkg is


  ---------------------------------------------------
  --
  -- Type declaration
  --
  ---------------------------------------------------

  -- unconstrained type for internal use of components to ease the instanciation and use of an axi-stream bus in the forward direction
  type t_axis_forward is record
    tdata  : std_logic_vector;
    tvalid : std_logic;
    tlast  : std_logic;
    tuser  : std_logic_vector;
    tstrb  : std_logic_vector;
    tkeep  : std_logic_vector;
    tid    : std_logic_vector;
    tdest  : std_logic_vector;
  end record t_axis_forward;

  ---------------------------------------------------
  --
  -- Registers
  --
  ---------------------------------------------------

  -- use to break combinational paths (forward path or backward path)
  component axis_register is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST     : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST      : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH    : positive  := 32;   -- Width of the tdata vector of the stream
      G_TUSER_WIDTH    : positive  := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH      : positive  := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH    : positive  := 1;    -- Width of the tdest vector of the stream

      -- REGISTER STAGES
      G_REG_FORWARD    : boolean   := true; -- Whether to register the forward path (tdata, tvalid and others)
      G_REG_BACKWARD   : boolean   := true; -- Whether to register the backward path (tready)
      G_FULL_BANDWIDTH : boolean   := true  -- Whether the full bandwidth is reachable
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic;         -- Global clock, signals are samples at rising edge
      RST      : in  std_logic;         -- Global reset depends on configuration

      -- SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST  : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACE
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);                   -- payload on master interface
      M_TVALID : out std_logic;                                                      -- validity of transfer on master interface
      M_TLAST  : out std_logic;                                                      -- packet boundary on master interface
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                   -- sideband information on master interface
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);       -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);       -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                     -- stream identifier on master interface
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                   -- routing destination on master interface
      M_TREADY : in  std_logic                                                := '1' -- acceptation of transfer on master interface
    );
  end component axis_register;


  ---------------------------------------------------
  --
  -- Multiplexers
  --
  ---------------------------------------------------
  -- Use to multiplex multiple slaves to a single master AXI-Stream buses using an internal arbiter

  -- simple multiplexer to use in most design with a simplified choice of generic parameters
  component axis_mux
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST  : std_logic                       := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean                         := true;  -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH : positive                        := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH : positive                        := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH   : positive                        := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH : positive                        := 1;     -- Width of the tdest vector of the stream

      -- MUX SIZE
      G_NB_SLAVE    : integer range 2 to integer'high := 2;     -- Number of Slave interfaces

      -- REGISTER STAGES
      G_PIPELINE    : boolean                         := true;  -- Whether to insert pipeline registers

      -- MUX ARCHITECTURE
      G_PACKET_MODE : boolean                         := false  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACES are packed together
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- validity of transfer on slave interface
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0)                               := (others => '-'); -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- acceptation of transfer on slave interface

      -- MASTER INTERFACE
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);                                  -- payload on master interface
      M_TVALID : out std_logic;                                                                     -- validity of transfer on master interface
      M_TLAST  : out std_logic;                                                                     -- packet boundary on master interface
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                                  -- sideband information on master interface
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);                      -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);                      -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                                    -- stream identifier on master interface
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                                  -- routing destination on master interface
      M_TREADY : in  std_logic                                                               := '1' -- acceptation of transfer on master interface
    );
  end component axis_mux;

  -- customizable multiplexer to use when a better granularity is needed
  component axis_mux_custom is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST          : std_logic                       := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean                         := true;  -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH         : positive                        := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH         : positive                        := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH           : positive                        := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH         : positive                        := 1;     -- Width of the tdest vector of the stream

      -- MUX SIZE
      G_NB_SLAVE            : integer range 2 to integer'high := 2;     -- Number of Slave interfaces

      -- REGISTER STAGES
      G_REG_SLAVES_FORWARD  : std_logic_vector                := "11";  -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
      G_REG_SLAVES_BACKWARD : std_logic_vector                := "11";  -- Whether to register the backward path (tready) for slaves ports
      G_REG_MASTER_FORWARD  : boolean                         := true;  -- Whether to register the forward path (tdata, tvalid and others) for master ports
      G_REG_MASTER_BACKWARD : boolean                         := false; -- Whether to register the backward path (tready) for master ports
      G_REG_ARB_FORWARD     : boolean                         := false; -- Whether to register the forward path (tdata, tvalid and others) for arbitration path
      G_REG_ARB_BACKWARD    : boolean                         := false; -- Whether to register the backward path (tready) for arbitration path

      -- MUX ARCHITECTURE
      G_PACKET_MODE         : boolean                         := false; -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      G_ROUND_ROBIN         : boolean                         := false; -- Whether to use a round_robin or fixed priorities
      G_FAST_ARCH           : boolean                         := false  -- Whether to use the fast architecture (one hot) or the area efficient one (binary)
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACES are packed together
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- validity of transfer on slave interface
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0)                               := (others => '-'); -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- acceptation of transfer on slave interface

      -- MASTER INTERFACE
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);                                  -- payload on master interface
      M_TVALID : out std_logic;                                                                     -- validity of transfer on master interface
      M_TLAST  : out std_logic;                                                                     -- packet boundary on master interface
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                                  -- sideband information on master interface
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);                      -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);                      -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                                    -- stream identifier on master interface
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                                  -- routing destination on master interface
      M_TREADY : in  std_logic                                                               := '1' -- acceptation of transfer on master interface
    );
  end component axis_mux_custom;


  ---------------------------------------------------
  --
  -- Demultiplexers
  --
  ---------------------------------------------------
  -- Use to demultiplex a single slave to multiple masters AXI-Stream buses using the tdest field

  -- simple demultiplexer to use in most design with a simplified choice of generic parameters
  component axis_demux is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST  : std_logic                       := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean                         := true; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH : positive                        := 32;   -- Width of the tdata vector of the stream
      G_TUSER_WIDTH : positive                        := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH   : positive                        := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH : positive                        := 1;    -- Width of the tdest vector of the stream

      -- DEMUX SIZE
      G_NB_MASTER   : integer range 2 to integer'high := 2;    -- Number of Master interfaces

      -- REGISTER STAGES
      G_PIPELINE    : boolean                         := true  -- Whether to insert pipeline registers
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST  : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);               -- payload on master interface
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- validity of transfer on master interface
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- packet boundary on master interface
      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);               -- sideband information on master interface
      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                 -- stream identifier on master interface
      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);               -- routing destination on master interface
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)               := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_demux;

  -- customizable demultiplexer to use when a better granularity is needed
  component axis_demux_custom is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST           : std_logic                        := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST            : boolean                          := true; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH          : positive                         := 32;   -- Width of the tdata vector of the stream
      G_TUSER_WIDTH          : positive                         := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH            : positive                         := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH          : positive                         := 1;    -- Width of the tdest vector of the stream

      -- DEMUX SIZE
      G_NB_MASTER            : integer range 2 to integer'high  := 2;    -- Number of Master interface

      -- REGISTER STAGES
      G_REG_SLAVE_FORWARD    : boolean                          := true; -- Whether to register the forward path (tdata, tvalid and others) for slave ports
      G_REG_SLAVE_BACKWARD   : boolean                          := true; -- Whether to register the backward path (tready) for slave ports
      G_REG_MASTERS_FORWARD  : std_logic_vector                 := "11"; -- Whether to register the forward path (tdata, tvalid and others) for masters ports
      G_REG_MASTERS_BACKWARD : std_logic_vector                 := "00"  -- Whether to register the backward path (tready) for masters ports
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST  : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);               -- payload on master interface
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- validity of transfer on master interface
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- packet boundary on master interface
      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);               -- sideband information on master interface
      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                 -- stream identifier on master interface
      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);               -- routing destination on master interface
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)               := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_demux_custom;

  ---------------------------------------------------
  --
  -- Switch
  --
  ---------------------------------------------------
  -- Use to interconnect multiple slaves to multiple masters AXI-Stream buses using the tdest field

  -- simple switch to use in most design with a simplified choice of generic parameters
  component axis_switch
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST           : std_logic                       := '0';    -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST            : boolean                         := true;   -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH          : positive                        := 32;     -- Width of the tdata vector of the stream
      G_TUSER_WIDTH          : positive                        := 1;      -- Width of the tuser vector of the stream
      G_TID_WIDTH            : positive                        := 1;      -- Width of the tid vector of the stream
      G_TDEST_WIDTH          : positive                        := 1;      -- Width of the tdest vector of the stream

      -- SWITCH SIZE
      G_NB_SLAVE             : integer range 2 to integer'high := 2;      -- Number of Slave interfaces
      G_NB_MASTER            : integer range 2 to integer'high := 2;      -- Number of Master interfaces

      -- REGISTER STAGES
      G_PIPELINE             : boolean                         := true;   -- Whether to insert pipeline register

      -- SWITCH ARCHITECTURE
      G_PACKET_MODE          : boolean                         := true    -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACES are packed together
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- validity of transfer on slave interface
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0)                               := (others => '-'); -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);                              -- payload on master interface
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- validity of transfer on master interface
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- packet boundary on master interface
      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);                              -- sideband information on master interface
      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                                -- stream identifier on master interface
      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);                              -- routing destination on master interface
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)                              := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_switch;

  -- customizable switch with a crossbar architecture to use when a better granularity is needed
  component axis_switch_crossbar
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST           : std_logic                       := '0';    -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST            : boolean                         := true;   -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH          : positive                        := 32;     -- Width of the tdata vector of the stream
      G_TUSER_WIDTH          : positive                        := 1;      -- Width of the tuser vector of the stream
      G_TID_WIDTH            : positive                        := 1;      -- Width of the tid vector of the stream
      G_TDEST_WIDTH          : positive                        := 1;      -- Width of the tdest vector of the stream

      -- SWITCH SIZE
      G_NB_SLAVE             : integer range 2 to integer'high := 2;      -- Number of Slave interfaces
      G_NB_MASTER            : integer range 2 to integer'high := 2;      -- Number of Master interfaces

      -- REGISTER STAGES
      G_REG_SLAVES_FORWARD   : std_logic_vector                := "11";   -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
      G_REG_SLAVES_BACKWARD  : std_logic_vector                := "11";   -- Whether to register the backward path (tready) for slaves ports
      G_REG_MASTERS_FORWARD  : std_logic_vector                := "11";   -- Whether to register the forward path (tdata, tvalid and others) for master ports
      G_REG_MASTERS_BACKWARD : std_logic_vector                := "00";   -- Whether to register the backward path (tready) for master ports
      G_REG_ARBS_FORWARD     : std_logic_vector                := "00";   -- Whether to register the forward path (tdata, tvalid and others) for arbitration paths
      G_REG_ARBS_BACKWARD    : std_logic_vector                := "00";   -- Whether to register the backward path (tready) for arbitration paths
      G_REG_LINKS_FORWARD    : std_logic_vector                := "0000"; -- Whether to register the forward path (tdata, tvalid and others) for internal link paths
      G_REG_LINKS_BACKWARD   : std_logic_vector                := "0000"; -- Whether to register the backward path (tready) for internal link paths

      -- SWITCH ARCHITECTURE
      G_LINKS_ENABLE         : std_logic_vector                := "1111"; -- Whether to authorize communication on a link (simplification)
      G_PACKET_MODE          : boolean                         := true;   -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      G_ROUND_ROBIN          : boolean                         := false;  -- Whether to use a round_robin or fixed priorities
      G_FAST_ARCH            : boolean                         := false   -- Whether to use the fast architecture (one hot) or the area efficient one (binary)
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACES are packed together
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- validity of transfer on slave interface
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0)                               := (others => '-'); -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);                              -- payload on master interface
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- validity of transfer on master interface
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- packet boundary on master interface
      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);                              -- sideband information on master interface
      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                                -- stream identifier on master interface
      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);                              -- routing destination on master interface
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)                              := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_switch_crossbar;

  -- customizable switch with a backbone architecture to use when a better granularity is needed
  component axis_switch_backbone
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST           : std_logic                       := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST            : boolean                         := true;  -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH          : positive                        := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH          : positive                        := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH            : positive                        := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH          : positive                        := 1;     -- Width of the tdest vector of the stream

      -- SWITCH SIZE
      G_NB_SLAVE             : integer range 2 to integer'high := 2;     -- Number of Slave interfaces
      G_NB_MASTER            : integer range 2 to integer'high := 2;     -- Number of Master interfaces

      -- REGISTER STAGES
      G_REG_SLAVES_FORWARD   : std_logic_vector                := "11";  -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
      G_REG_SLAVES_BACKWARD  : std_logic_vector                := "11";  -- Whether to register the backward path (tready) for slaves ports
      G_REG_MASTERS_FORWARD  : std_logic_vector                := "11";  -- Whether to register the forward path (tdata, tvalid and others) for master ports
      G_REG_MASTERS_BACKWARD : std_logic_vector                := "00";  -- Whether to register the backward path (tready) for master ports
      G_REG_ARB_FORWARD      : boolean                         := false; -- Whether to register the forward path (tdata, tvalid and others) for arbitration path
      G_REG_ARB_BACKWARD     : boolean                         := false; -- Whether to register the backward path (tready) for arbitration path
      G_REG_LINK_FORWARD     : boolean                         := false; -- Whether to register the forward path (tdata, tvalid and others) for backbone path
      G_REG_LINK_BACKWARD    : boolean                         := false; -- Whether to register the backward path (tready) for backbone path

      -- SWITCH ARCHITECTURE
      G_PACKET_MODE          : boolean                         := true;  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      G_ROUND_ROBIN          : boolean                         := false; -- Whether to use a round_robin or fixed priorities
      G_FAST_ARCH            : boolean                         := false  -- Whether to use the fast architecture (one hot) or the area efficient one (binary)
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic; -- Global clock, signals are samples at rising edge
      RST      : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACES are packed together
      S_TDATA  : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- validity of transfer on slave interface
      S_TLAST  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0)                               := (others => '-'); -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);                                                  -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);                              -- payload on master interface
      M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- validity of transfer on master interface
      M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                                -- packet boundary on master interface
      M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);                              -- sideband information on master interface
      M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);                  -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                                -- stream identifier on master interface
      M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);                              -- routing destination on master interface
      M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)                              := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_switch_backbone;


  ---------------------------------------------------
  --
  -- Clock Domain Crossing
  --
  ---------------------------------------------------

  -- use change of clock domain with a limited data rate
  component axis_cdc is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST  : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH : positive                        := 32; -- Width of the tdata vector of the stream
      G_TUSER_WIDTH : positive                        := 1; -- Width of the tuser vector of the stream
      G_TID_WIDTH   : positive                        := 1; -- Width of the tid vector of the stream
      G_TDEST_WIDTH : positive                        := 1; -- Width of the tdest vector of the stream

      -- REGISTER STAGES
      G_NB_STAGE    : integer range 2 to integer'high := 2 -- Number of synchronization stages (to reduce MTBF)
    );
    port(

      -- SLAVE INTERFACE
      S_CLK    : in  std_logic;                                                                   -- clock for slave interface
      S_RST    : in  std_logic;                                                                   -- reset for slave interface
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST  : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACE
      M_CLK    : in  std_logic;                                                      -- clock for master interface
      M_RST    : in  std_logic;                                                      -- reset for master interface
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);                   -- payload on master interface
      M_TVALID : out std_logic;                                                      -- validity of transfer on master interface
      M_TLAST  : out std_logic;                                                      -- packet boundary on master interface
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                   -- sideband information on master interface
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);       -- byte qualifier (position or data) on master interface
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);       -- byte qualifier (null when deasserted) on master interface
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                     -- stream identifier on master interface
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                   -- routing destination on master interface
      M_TREADY : in  std_logic                                                := '1' -- acceptation of transfer on master interface
    );
  end component axis_cdc;


  ---------------------------------------------------
  --
  -- Fifo with axis interface
  --
  ---------------------------------------------------

  -- FIFO for AXI-Stream buses
  component axis_fifo is
    generic(
      G_COMMON_CLK  : boolean                         := false;  -- 2 or 1 clock domain
      G_ADDR_WIDTH  : positive                        := 16;     -- FIFO address width (depth is 2**ADDR_WIDTH)
      G_TDATA_WIDTH : positive                        := 32;     -- Width of the tdata vector of the stream
      G_TUSER_WIDTH : positive                        := 1;      -- Width of the tuser vector of the stream
      G_TID_WIDTH   : positive                        := 1;      -- Width of the tid vector of the stream
      G_TDEST_WIDTH : positive                        := 1;      -- Width of the tdest vector of the stream
      G_PKT_WIDTH   : natural                         := 0;      -- Width of the packet counters in FIFO in packet mode (0 to disable)
      G_RAM_STYLE   : string                          := "AUTO"; -- Specify the ram synthesis style (technology dependant)
      G_ACTIVE_RST  : std_logic                       := '1';    -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean                         := false;  -- Type of reset used (synchronous or asynchronous resets)
      G_SYNC_STAGE  : integer range 2 to integer'high := 2       -- Number of synchronization stages (to reduce MTBF)
    );
    port(
      -- axi4-stream slave
      S_CLK         : in  std_logic;                                                                                                   -- clock for slave bus
      S_RST         : in  std_logic;                                                                                                   -- reset for slave bus
      S_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (G_TDATA_WIDTH - 1 downto 0 => '-');             -- payload on slave interface
      S_TVALID      : in  std_logic;                                                                                                   -- validity of transfer on slave interface
      S_TLAST       : in  std_logic                                                := '-';                                             -- packet boundary on slave interface
      S_TUSER       : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (G_TUSER_WIDTH - 1 downto 0 => '-');             -- sideband information on slave interface
      S_TSTRB       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (((G_TDATA_WIDTH + 7) / 8) - 1 downto 0 => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (((G_TDATA_WIDTH + 7) / 8) - 1 downto 0 => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID         : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (G_TID_WIDTH - 1 downto 0 => '-');               -- stream identifier on slave interface
      S_TDEST       : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (G_TDEST_WIDTH - 1 downto 0 => '-');             -- routing destination on slave interface
      S_TREADY      : out std_logic;                                                                                                   -- acceptation of transfer on slave interface
      -- axi4-stream slave
      M_CLK         : in  std_logic;                                                       -- clock for master interface
      M_RST         : in  std_logic;                                                       -- reset for master interface
      M_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);                    -- payload on master interface
      M_TVALID      : out std_logic;                                                       -- validity of transfer on master interface
      M_TLAST       : out std_logic;                                                       -- packet boundary on master interface
      M_TUSER       : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                    -- sideband information on master interface
      M_TSTRB       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);        -- byte qualifier (position or data) on master interface
      M_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);        -- byte qualifier (null when deasserted) on master interface
      M_TID         : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                      -- stream identifier on master interface
      M_TDEST       : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                    -- routing destination on master interface
      M_TREADY      : in  std_logic                                                := '1'; -- acceptation of transfer on master interface
      -- status
      WR_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);                -- Data count written in the FIFO (synchronous with S_CLK)
      WR_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0);  -- Pkt count written in the FIFO (synchronous with S_CLK)
      RD_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);                -- Data count readable from the FIFO (synchronous with M_CLK)
      RD_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0)   -- Pkt count readable from the FIFO (synchronous with M_CLK)
    );
  end component axis_fifo;

  ---------------------------------------------------
  --
  -- Broadcast
  --
  ---------------------------------------------------
  -- Use to duplicate a single slave to multiple masters AXI-Stream bus

  -- simple broadcaster to use in most design with a simplified choice of generic parameters
  component axis_broadcast is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST  : std_logic                         := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean                           := true; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH : positive                          := 32;   -- Width of the tdata vector of the stream
      G_TUSER_WIDTH : positive                          := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH   : positive                          := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH : positive                          := 1;    -- Width of the tdest vector of the stream

      -- BROADCASTER SIZE
      G_NB_MASTER   : positive range 2 to positive'high := 2;    -- Number of Master interfaces

      -- REGISTER STAGES
      G_PIPELINE    : boolean                           := true  -- Whether to insert pipeline registers
    );
    port(
      -- GLOBAL
      CLK             : in  std_logic; -- Global clock, signals are samples at rising edge
      RST             : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACE
      S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID        : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST         : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER         : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID           : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST         : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY        : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA         : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);               -- payload on master interface
      M_TVALID        : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- validity of transfer on master interface
      M_TLAST         : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- packet boundary on master interface
      M_TUSER         : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);               -- sideband information on master interface
      M_TSTRB         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (position or data) on master interface
      M_TKEEP         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (null when deasserted) on master interface
      M_TID           : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                 -- stream identifier on master interface
      M_TDEST         : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);               -- routing destination on master interface
      M_TREADY        : in  std_logic_vector(G_NB_MASTER - 1 downto 0)               := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_broadcast;

  -- customizable broadcaster to use when a better granularity is needed
  component axis_broadcast_custom is
    generic(
      -- RESET CONFIGURATION
      G_ACTIVE_RST            : std_logic                         := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST             : boolean                           := true; -- Type of reset used (synchronous or asynchronous resets)

      -- SIZE OF BUSES
      G_TDATA_WIDTH           : positive                          := 32;   -- Width of the tdata vector of the stream
      G_TUSER_WIDTH           : positive                          := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH             : positive                          := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH           : positive                          := 1;    -- Width of the tdest vector of the stream

      -- BROADCASTER SIZE
      G_NB_MASTER             : positive range 2 to positive'high := 2;    -- Number of Master interfaces

      -- REGISTER STAGES
      G_REG_SLAVE_FORWARD     : boolean                           := true; -- Whether to register the forward path (tdata, tvalid and others) for slave ports
      G_REG_SLAVE_BACKWARD    : boolean                           := true; -- Whether to register the backward path (tready) for slave ports
      G_REG_MASTERS_FORWARD   : std_logic_vector                  := "11"; -- Whether to register the forward path (tdata, tvalid and others) for masters ports
      G_REG_MASTERS_BACKWARD  : std_logic_vector                  := "00"  -- Whether to register the backward path (tready) for masters ports
    );
    port(
      -- GLOBAL
      CLK             : in  std_logic; -- Global clock, signals are samples at rising edge
      RST             : in  std_logic; -- Global reset depends on configuration

      -- SLAVE INTERFACE
      S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-'); -- payload on slave interface
      S_TVALID        : in  std_logic;                                                                   -- validity of transfer on slave interface
      S_TLAST         : in  std_logic                                                := '-';             -- packet boundary on slave interface
      S_TUSER         : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-'); -- sideband information on slave interface
      S_TSTRB         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID           : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-'); -- stream identifier on slave interface
      S_TDEST         : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-'); -- routing destination on slave interface
      S_TREADY        : out std_logic;                                                                   -- acceptation of transfer on slave interface

      -- MASTER INTERFACES are packed together
      M_TDATA         : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);               -- payload on master interface
      M_TVALID        : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- validity of transfer on master interface
      M_TLAST         : out std_logic_vector(G_NB_MASTER - 1 downto 0);                                 -- packet boundary on master interface
      M_TUSER         : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);               -- sideband information on master interface
      M_TSTRB         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (position or data) on master interface
      M_TKEEP         : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);   -- byte qualifier (null when deasserted) on master interface
      M_TID           : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);                 -- stream identifier on master interface
      M_TDEST         : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);               -- routing destination on master interface
      M_TREADY        : in  std_logic_vector(G_NB_MASTER - 1 downto 0)               := (others => '1') -- acceptation of transfer on master interface
    );
  end component axis_broadcast_custom;


  ---------------------------------------------------
  --
  -- Dwidth converter
  --
  ---------------------------------------------------

  -- Use to convert the size of an AXI Stream bus
  component axis_dwidth_converter is
    generic(
      G_ACTIVE_RST      : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST       : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_S_TDATA_WIDTH   : positive  := 8;    -- Width of the input tdata vector of the stream
      G_M_TDATA_WIDTH   : positive  := 32;    -- Width of the output tdata vector of the stream
      G_TUSER_WIDTH     : positive  := 1;    -- Width of the tuser vector of the stream
      G_TID_WIDTH       : positive  := 1;    -- Width of the tid vector of the stream
      G_TDEST_WIDTH     : positive  := 1;    -- Width of the tdest vector of the stream
      G_PIPELINE        : boolean   := true; -- Whether to register the forward and backward path
      G_LITTLE_ENDIAN   : boolean   := true  -- Whether endianness is little or big
    );
    port(
      -- Global
      CLK         : in  std_logic;           -- Clock
      RST         : in  std_logic;           -- Reset
      -- Axi4-stream slave
      S_TDATA     : in  std_logic_vector(G_S_TDATA_WIDTH - 1 downto 0);                                 -- payload on slave interface
      S_TVALID    : in  std_logic;                                                                      -- validity of transfer on slave interface
      S_TLAST     : in  std_logic                                                   := '-';             -- packet boundary on slave interface
      S_TUSER     : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)                := (others => '-'); -- sideband information on slave interface
      S_TSTRB     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0)  := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0)  := (others => '-'); -- byte qualifier (null when deasserted) on slave interface
      S_TID       : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)                  := (others => '-'); -- stream identifier on slave interface
      S_TDEST     : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)                := (others => '-'); -- routing destination on slave interface
      S_TREADY    : out std_logic;                                                                      -- acceptation of transfer on slave interface
      -- Axi4-stream master
      M_TDATA     : out std_logic_vector(G_M_TDATA_WIDTH - 1 downto 0);                                 -- payload on master interface
      M_TVALID    : out std_logic;                                                                      -- validity of transfer on master interface
      M_TLAST     : out std_logic;                                                                      -- packet boundary on master interface
      M_TUSER     : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                                   -- sideband information on master interface
      M_TSTRB     : out std_logic_vector(((G_M_TDATA_WIDTH + 7) / 8) - 1 downto 0);                     -- byte qualifier (position or data) on master interface
      M_TKEEP     : out std_logic_vector(((G_M_TDATA_WIDTH + 7) / 8) - 1 downto 0);                     -- byte qualifier (null when deasserted) on master interface
      M_TID       : out std_logic_vector(G_TID_WIDTH - 1 downto 0);                                     -- stream identifier on master interface
      M_TDEST     : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);                                   -- routing destination on master interface
      M_TREADY    : in  std_logic                                                   := '1';             -- acceptation of transfer on master interface
      -- Error
      ERR         : out std_logic_vector(2 downto 0)                                                    -- only when bigger mode and byte align, Bit 0 => Error on TLAST, Bit 1 => Error on TID, Bit 2 => Error on TDEST
    );
  end component axis_dwidth_converter;


  ---------------------------------------------------
  --
  -- Combine
  --
  ---------------------------------------------------

  -- Use to combine the size of an AXI Stream bus
  component axis_combine is
    generic(
      G_ACTIVE_RST       : std_logic := '0';    --State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST        : boolean   := false;  --Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH      : positive  := 64;     --Width of the tdata vector of the stream
      G_TUSER_WIDTH      : positive  := 1;      --Width of the tuser vector of the stream
      G_TID_WIDTH        : positive  := 1;      --Width of the tid vector of the stream
      G_TDEST_WIDTH      : positive  := 1;      --Width of the tdest vector of the stream
      G_NB_SLAVE         : positive  := 2;      --Number of slave interface
      G_REG_OUT_FORWARD  : boolean   := true;   --Whether to regiser the forward path (tdata, tvalid and others)
      G_REG_OUT_BACKWARD : boolean   := false   --Whether to regiser the backward path (tready)
    );
    port(
      --GLOBAL
      CLK      : in  std_logic;
      RST      : in  std_logic;
      --SLAVE INTERFACE
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_TLAST  : in  std_logic                                                := '-';
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      --MASTER INTERFACE
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY : in  std_logic                                                := '1'
    );
  end component axis_combine;

  ---------------------------------------------------
  --
  -- Rate limit
  --
  ---------------------------------------------------

  component axis_rate_limit is
    generic(
      G_ACTIVE_RST   : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST    : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH  : positive  := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH  : positive  := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH    : positive  := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH  : positive  := 1;     -- Width of the tdest vector of the stream
      G_WINDOW_WIDTH : positive  := 8      -- Width of the internal counters
    );
    port(
      -- Global
      CLK          : in  std_logic;       -- Clock
      RST          : in  std_logic;       -- Reset
      -- Parameters
      NB_TRANSFERS : in  std_logic_vector(G_WINDOW_WIDTH - 1 downto 0);
      WINDOW_SIZE  : in  std_logic_vector(G_WINDOW_WIDTH - 1 downto 0);
      -- Axi4-stream slave
      S_TDATA      : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID     : in  std_logic;
      S_TLAST      : in  std_logic                                                := '-';
      S_TUSER      : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP      : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID        : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST      : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY     : out std_logic;
      -- Axi4-stream master
      M_TDATA      : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID     : out std_logic;
      M_TLAST      : out std_logic;
      M_TUSER      : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP      : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID        : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST      : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY     : in  std_logic                                                := '1'
    );
  end component axis_rate_limit;

  ---------------------------------------------------
  --
  -- enable
  --
  ---------------------------------------------------

  component axis_enable is
    generic(
      G_ACTIVE_RST           : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST            : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH          : positive  := 32; -- Width of the tdata vector of the stream
      G_TUSER_WIDTH          : positive  := 1; -- Width of the tuser vector of the stream
      G_TID_WIDTH            : positive  := 1; -- Width of the tid vector of the stream
      G_TDEST_WIDTH          : positive  := 1; -- Width of the tdest vector of the stream
      G_REG_FORWARD          : boolean   := true; -- Whether to register the forward path (tdata, tvalid and others)
      G_REG_BACKWARD         : boolean   := true; -- Whether to register the backward path (tready)
      G_FULL_BANDWIDTH       : boolean   := true; -- Whether the full bandwidth is reachable
      G_PACKET_MODE          : boolean   := false -- Whether to enable on TLAST (packet mode) or for each sample (sample mode)
    );
    port(
      -- GLOBAL
      CLK         : in  std_logic;        -- Clock
      RST         : in  std_logic;        -- Reset
      -- ENABLE
      S_EN_TDATA  : in  std_logic                                                := '1';
      S_EN_TVALID : in  std_logic                                                := '1';
      S_EN_TREADY : out std_logic;
      -- Axi4-stream slave
      S_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID    : in  std_logic;
      S_TLAST     : in  std_logic                                                := '-';
      S_TUSER     : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID       : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST     : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY    : out std_logic;
      -- Axi4-stream master
      M_TDATA     : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID    : out std_logic;
      M_TLAST     : out std_logic;
      M_TUSER     : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP     : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID       : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST     : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY    : in  std_logic                                                := '1'
    );
  end component axis_enable;

  ---------------------------------------------------
  --
  -- pkt_concat
  --
  ---------------------------------------------------

  -- use to concat several packets from several interfaces
  component axis_pkt_concat is
    generic(
      G_ACTIVE_RST          : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean          := false;  -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive         := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH         : positive         := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH           : positive         := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH         : positive         := 1;     -- Width of the tdest vector of the stream
      G_NB_SLAVE            : positive         := 2;     -- Number of Slave interfaces
      G_PIPELINE            : boolean          := true  -- Whether to register the forward and backward path
    );
    port(
      -- GLOBAL
      CLK        : in  std_logic;
      RST        : in  std_logic;
      -- SLAVE INTERFACES
      S_TDATA    : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0)              := (others => '-');
      S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_TUSER    : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0)              := (others => '-');
      S_TSTRB    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0)  := (others => '-');
      S_TKEEP    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0)  := (others => '-');
      S_TID      : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0)                := (others => '-');
      S_TDEST    : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0)              := (others => '-');
      S_TREADY   : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- MASTER INTERFACE
      M_TDATA    : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID   : out std_logic;
      M_TLAST    : out std_logic;
      M_TUSER    : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB    : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP    : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID      : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST    : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY   : in  std_logic                                                                := '1'
    );
  end component axis_pkt_concat;

    ---------------------------------------------------
  --
  -- pkt_split_bytes
  --
  ---------------------------------------------------

  -- use to split a packet (Split size given in bytes)
  component axis_pkt_split_bytes is
    generic(
      G_ACTIVE_RST          : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean          := true;  -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive         := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH         : positive         := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH           : positive         := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH         : positive         := 1;     -- Width of the tdest vector of the stream
      G_SPLIT_SIZE          : positive         := 2;     -- Split index of the input frame (number of bytes)
      G_PIPELINE            : boolean          := false; -- Whether to register the forward and backward path
      G_LITTLE_ENDIAN       : boolean          := true
    );
    port(
      -- GLOBAL
      CLK        : in  std_logic;
      RST        : in  std_logic;
      -- SLAVE INTERFACES
      S_TDATA    : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID   : in  std_logic;
      S_TLAST    : in  std_logic;
      S_TUSER    : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '1');
      S_TID      : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST    : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY   : out std_logic;
      -- MASTER INTERFACE
      M_TDATA    : out std_logic_vector((2*G_TDATA_WIDTH) - 1 downto 0);
      M_TVALID   : out std_logic_vector(1 downto 0);
      M_TLAST    : out std_logic_vector(1 downto 0);
      M_TUSER    : out std_logic_vector((2*G_TUSER_WIDTH) - 1 downto 0);
      M_TSTRB    : out std_logic_vector((2*((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TKEEP    : out std_logic_vector((2*((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TID      : out std_logic_vector((2*G_TID_WIDTH) - 1 downto 0);
      M_TDEST    : out std_logic_vector((2*G_TDEST_WIDTH) - 1 downto 0);
      M_TREADY   : in  std_logic_vector(1 downto 0)                             := (others => '1')
    );
  end component axis_pkt_split_bytes;

  ---------------------------------------------------
  --
  -- pkt_split_words
  --
  ---------------------------------------------------

  -- use to split a packet (Split size given in words)
  component axis_pkt_split_words is
    generic(
      G_ACTIVE_RST          : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST           : boolean          := true;  -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH         : positive         := 32;    -- Width of the tdata vector of the stream
      G_TUSER_WIDTH         : positive         := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH           : positive         := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH         : positive         := 1;     -- Width of the tdest vector of the stream
      G_SPLIT_SIZE          : positive         := 2;     -- Split index of the input frame (number of words)
      G_PIPELINE            : boolean          := false  -- Whether to register the forward and backward path
    );
    port(
      -- GLOBAL
      CLK        : in  std_logic;
      RST        : in  std_logic;
      -- SLAVE INTERFACES
      S_TDATA    : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID   : in  std_logic;
      S_TLAST    : in  std_logic;
      S_TUSER    : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID      : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST    : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY   : out std_logic;
      -- MASTER INTERFACE
      M_TDATA    : out std_logic_vector((2*G_TDATA_WIDTH) - 1 downto 0);
      M_TVALID   : out std_logic_vector(1 downto 0);
      M_TLAST    : out std_logic_vector(1 downto 0);
      M_TUSER    : out std_logic_vector((2*G_TUSER_WIDTH) - 1 downto 0);
      M_TSTRB    : out std_logic_vector((2*((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TKEEP    : out std_logic_vector((2*((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
      M_TID      : out std_logic_vector((2*G_TID_WIDTH) - 1 downto 0);
      M_TDEST    : out std_logic_vector((2*G_TDEST_WIDTH) - 1 downto 0);
      M_TREADY   : in  std_logic_vector(1 downto 0)                             := (others => '1')
    );
  end component axis_pkt_split_words;

  ---------------------------------------------------
  --
  -- pkt_align
  --
  ---------------------------------------------------

  component axis_pkt_align is
    generic(
      G_ACTIVE_RST    : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST     : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH   : positive  := 64;    -- Width of the data bus
      G_TUSER_WIDTH   : positive  := 1;     -- Width of the tuser vector of the stream
      G_TID_WIDTH     : positive  := 1;     -- Width of the tid vector of the stream
      G_TDEST_WIDTH   : positive  := 1;     -- Width of the tdest vector of the stream
      G_LITTLE_ENDIAN : boolean   := true   -- Whether endianness is little or big
    );
    port(
      -- Clocks and resets
      CLK      : in  std_logic;
      RST      : in  std_logic;
      -- Input
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY : out std_logic;
      -- Output
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY : in  std_logic                                                := '1';
      -- Error Flag
      ERR      : out std_logic
    );
  end component axis_pkt_align;


  ---------------------------------------------------
  --
  -- pkt_drop
  --
  ---------------------------------------------------

  component axis_pkt_drop is
    generic(
      G_ACTIVE_RST    : std_logic                         := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST     : boolean                           := false; -- Type of reset used (synchronous or asynchronous resets)
      G_COMMON_CLK    : boolean                           := true; -- 2 or 1 clock domain
      G_TDATA_WIDTH   : positive                          := 64; -- Width of the tdata vector of the stream
      G_TUSER_WIDTH   : positive                          := 1; -- Width of the tuser vector of the stream
      G_TID_WIDTH     : positive                          := 1; -- Width of the tid vector of the stream
      G_TDEST_WIDTH   : positive                          := 1; -- Width of the tdest vector of the stream
      G_ADDR_WIDTH    : positive                          := 10; -- FIFO address width (depth is 2**ADDR_WIDTH)
      G_PKT_THRESHOLD : positive range 2 to positive'high := 2 -- Maximum number of packet into the fifo
    );
    port(
      -- Slave interface
      S_CLK    : in  std_logic;           -- Global clock, signals are samples at rising edge
      S_RST    : in  std_logic;           -- Global reset depends on configuration
      S_TDATA  : in  std_logic_vector((G_TDATA_WIDTH - 1) downto 0)           := (others => '-');
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY : out std_logic;
      -- Status (S_CLK domain)
      DROP     : out std_logic;
      -- master interface
      M_CLK    : in  std_logic;           -- Global clock, signals are samples at rising edge
      M_RST    : in  std_logic;           -- Global reset depends on configuration
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY : in  std_logic                                                := '1'
    );
  end component axis_pkt_drop;


  ---------------------------------------------------
  --
  -- Functions
  --
  ---------------------------------------------------

  -- Define if size is bytes aligned
  function is_bytes_align(constant size : in positive) return boolean;

end axis_utils_pkg;

package body axis_utils_pkg is

  ---------------------------------------------------
  --
  -- Functions
  --
  ---------------------------------------------------

  -- Define if size is bytes aligned
  function is_bytes_align(constant size : in positive) return boolean is
    begin
      return ((size mod 8) = 0);
  end function is_bytes_align;

end package body axis_utils_pkg;

