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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.textio.all;

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
-- * axis_loopback
-- * axis_pkt_pad
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

  -- reorder axis packet along index on TUSER
  component axis_pkt_reorder is
    generic(
      G_ACTIVE_RST     : std_logic := '0';        -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST      : boolean   := true;       -- Type of reset used (synchronous or asynchronous resets)
      G_FULL_BANDWIDTH : boolean   := true;       -- Selection of operation mode (low resources/full bandwidth)
      G_INDEX_WIDTH    : positive  := 10;         -- Width of index in TUSER
      G_MEM_ADDR_WIDTH : positive  := 10;         -- Depth of memory map. Equal to G_INDEX_WIDTH in most cases
      G_TDATA_WIDTH    : positive  := 32;         -- Width of the tdata vector of the stream
      G_TUSER_WIDTH    : positive  := 10;         -- Width of the tuser vector of the stream
      G_TID_WIDTH      : positive  := 1;          -- Width of the tid vector of the stream
      G_TDEST_WIDTH    : positive  := 1           -- Width of the tdest vector of the stream
    );
    port(
      -- GLOBAL
      CLK                   : in  std_logic;      -- Clock
      RST                   : in  std_logic;      -- Reset
      -- axi4-stream slave configuration interface
      S_CFG_TDATA_FIRST_IDX : in  std_logic_vector(G_INDEX_WIDTH - 1 downto 0)             := (others => '0'); -- First index to keep
      S_CFG_TDATA_LAST_IDX  : in  std_logic_vector(G_INDEX_WIDTH - 1 downto 0)             := (others => '1'); -- Last index to keep      S_CFG_TVALID : in  std_logic                                                := '1';
      S_CFG_TVALID          : in  std_logic                                                := '1';
      S_CFG_TREADY          : out std_logic;
      -- axi4-stream slave
      S_TDATA               : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID              : in  std_logic;
      S_TLAST               : in  std_logic;
      S_TUSER               : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      S_TSTRB               : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP               : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TID                 : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST               : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TREADY              : out std_logic;
      -- axi4-stream master
      M_TDATA               : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID              : out std_logic;
      M_TLAST               : out std_logic;
      M_TUSER               : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TSTRB               : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP               : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID                 : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST               : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TREADY              : in  std_logic                                                := '1'
    );
  end component axis_pkt_reorder;

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
      S_TLAST     : in  std_logic                                                   := '1';             -- packet boundary on slave interface
      S_TUSER     : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)                := (others => '-'); -- sideband information on slave interface
      S_TSTRB     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0)  := (others => '-'); -- byte qualifier (position or data) on slave interface
      S_TKEEP     : in  std_logic_vector(((G_S_TDATA_WIDTH + 7) / 8) - 1 downto 0)  := (others => '1'); -- byte qualifier (null when deasserted) on slave interface
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
      G_RAM_STYLE     : string                            := "AUTO"; -- Specify the ram synthesis style (technology dependant)
      G_ADDR_WIDTH    : positive                          := 10; -- FIFO address width (depth is 2**ADDR_WIDTH)
      G_PKT_THRESHOLD : positive range 2 to positive'high := 2; -- Maximum number of packet into the fifo
      G_SYNC_STAGE    : integer range 2 to integer'high   := 2 -- Number of synchronization stages (to reduce MTBF)
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
  -- loopback
  --
  ---------------------------------------------------
  
  component axis_loopback is
    generic(
      G_ACTIVE_RST       : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST        : boolean   := false;  -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH      : positive  := 64;     -- Width of the tdata vector of the stream
      G_TUSER_WIDTH      : positive  := 1;      -- Width of the tuser vector of the stream
      G_TID_WIDTH        : positive  := 1;      -- Width of the tid vector of the stream
      G_TDEST_WIDTH      : positive  := 1;      -- Width of the tdest vector of the stream
      G_PACKET_MODE      : boolean   := false;  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      G_FIFO_DEPTH       : integer   := 256     -- Depth of the loopback fifo (0 = No fifo)
    );
    port(
      --GLOBAL
      CLK              : in  std_logic;
      RST              : in  std_logic;
      ENABLE           : in  std_logic;
      --RX SLAVE INTERFACE
      S_LOOP_RX_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)               := (others => '-');
      S_LOOP_RX_TVALID : in  std_logic;
      S_LOOP_RX_TLAST  : in  std_logic                                                  := '-';
      S_LOOP_RX_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)               := (others => '-');
      S_LOOP_RX_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0)   := (others => '-');
      S_LOOP_RX_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0)   := (others => '-');
      S_LOOP_RX_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)                 := (others => '-');
      S_LOOP_RX_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)               := (others => '-');
      S_LOOP_RX_TREADY : out std_logic;
      --RX MASTER INTERFACE
      M_RX_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_RX_TVALID      : out std_logic;
      M_RX_TLAST       : out std_logic;
      M_RX_TUSER       : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_RX_TSTRB       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RX_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_RX_TID         : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_RX_TDEST       : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_RX_TREADY      : in  std_logic                                                  := '1';
      --TX SLAVE INTERFACE
      S_TX_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)               := (others => '-');
      S_TX_TVALID      : in  std_logic;
      S_TX_TLAST       : in  std_logic                                                  := '-';
      S_TX_TUSER       : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)               := (others => '-');
      S_TX_TSTRB       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0)   := (others => '-');
      S_TX_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0)   := (others => '-');
      S_TX_TID         : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)                 := (others => '-');
      S_TX_TDEST       : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)               := (others => '-');
      S_TX_TREADY      : out std_logic;
      -- TX MASTER INTERFACE
      M_LOOP_TX_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_LOOP_TX_TVALID : out std_logic;
      M_LOOP_TX_TLAST  : out std_logic;
      M_LOOP_TX_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_LOOP_TX_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_LOOP_TX_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_LOOP_TX_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_LOOP_TX_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_LOOP_TX_TREADY : in  std_logic                                                  := '1'
    );
  end component axis_loopback;

  ---------------------------------------------------
  --
  -- axis_pkt_pad
  --
  ---------------------------------------------------

  component axis_pkt_pad is
    generic(
      G_ACTIVE_RST     : std_logic := '0';        -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST      : boolean   := true;       -- Type of reset used (synchronous or asynchronous resets)
      G_TDATA_WIDTH    : positive  := 64;         -- Width of the tdata vector of the stream
      G_TUSER_WIDTH    : positive  := 1;          -- Width of the tuser vector of the stream
      G_TID_WIDTH      : positive  := 1;          -- Width of the tid vector of the stream
      G_TDEST_WIDTH    : positive  := 1;          -- Width of the tdest vector of the stream
      G_PIPELINE       : boolean   := true;       -- Whether to insert pipeline registers
      G_MIN_SIZE_BYTES : positive  := 60;         -- Packet minimal size
      G_PADDING_VALUE  : std_logic := '0'         -- Value used for padding
    );
    port(
      -- GLOBAL
      CLK      : in  std_logic;                   -- Clock
      RST      : in  std_logic;                   -- Reset
      -- Axi4-stream slave
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '1');
      S_TREADY : out std_logic;
      -- Axi4-stream master
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TUSER  : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      M_TID    : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
      M_TDEST  : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
      M_TSTRB  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY : in  std_logic                                                := '1'
    );
  end component axis_pkt_pad;

  ---------------------------------------------------
  --
  -- Type
  --
  ---------------------------------------------------
  -- configuration for axis switch crossbar
  type t_axis_switch_crossbar_configuration is record
    reg_slaves_forward   : std_logic_vector;
    reg_slaves_backward  : std_logic_vector;
    reg_masters_forward  : std_logic_vector;
    reg_masters_backward : std_logic_vector;
    reg_arbs_forward     : std_logic_vector;
    reg_arbs_backward    : std_logic_vector;
    reg_links_forward    : std_logic_vector;
    reg_links_backward   : std_logic_vector;
    links_enable         : std_logic_vector;
  end record t_axis_switch_crossbar_configuration;

  ---------------------------------------------------
  --
  -- Functions
  --
  ---------------------------------------------------

  -- Define if size is bytes aligned
  function is_bytes_align(constant size : in positive) return boolean;

  -- Calculate length in bytes for tkeep and tstrb length
  function length_in_bytes(constant size : in positive) return positive;

  -- Generate an axis switch crossbar configuration from csv
  impure function load_axis_switch_configuration_from_csv(
    constant CONFIG_FILENAME : in string;
    constant NB_SLAVES       : in integer;
    constant NB_MASTERS      : in integer
  ) return t_axis_switch_crossbar_configuration;

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

  -- Calculate length in bytes for tkeep and tstrb length
  function length_in_bytes(constant size : in positive) return positive is
  begin
    return (size + 7) / 8;
  end function length_in_bytes;

  -- Return the forward, backward and link configuration from register string
  function parse_register_configuration(
    constant REG_STR : in string(1 to 4);
    constant ERR_STR : in string;
    constant EN_OPEN : in boolean := false
  ) return std_logic_vector is
    constant C_REG_FORWARD  : string := "forw";
    constant C_REG_BACKWARD : string := "back";
    constant C_REG_BOTH     : string := "both";
    constant C_REG_NONE     : string := "none";
    constant C_REG_OPEN     : string := "open";

    variable result : std_logic_vector(2 downto 0);
  begin
    result := "100";
    case REG_STR is
      when C_REG_NONE =>
        result(0) := '0';                         -- forward
        result(1) := '0';                         -- backward
      when C_REG_FORWARD =>
        result(0) := '1';                         -- forward
        result(1) := '0';                         -- backward
      when C_REG_BACKWARD =>
        result(0) := '0';                         -- forward
        result(1) := '1';                         -- backward
      when C_REG_BOTH =>
        result(0) := '1';                         -- forward
        result(1) := '1';                         -- backward
      when C_REG_OPEN =>
        assert EN_OPEN report ERR_STR & " can not be of type open" severity failure;
        result(2) := '0';
      when others =>
        report "Unknown register type: '" & REG_STR & "' for " & ERR_STR severity failure;
    end case;
    return result;
  end function parse_register_configuration;

  -- Generate an axis switch crossbar configuration from csv
  impure function load_axis_switch_configuration_from_csv( --@suppress
    constant CONFIG_FILENAME : in string;
    constant NB_SLAVES       : in integer;
    constant NB_MASTERS      : in integer
  ) return t_axis_switch_crossbar_configuration is

    subtype t_switch_config_constrained is t_axis_switch_crossbar_configuration(
      reg_slaves_forward(NB_SLAVES - 1 downto 0),
      reg_slaves_backward(NB_SLAVES - 1 downto 0),
      reg_masters_forward(NB_MASTERS - 1 downto 0),
      reg_masters_backward(NB_MASTERS - 1 downto 0),
      reg_arbs_forward(NB_MASTERS - 1 downto 0),
      reg_arbs_backward(NB_MASTERS - 1 downto 0),
      reg_links_forward((NB_SLAVES * NB_MASTERS) - 1 downto 0),
      reg_links_backward((NB_SLAVES * NB_MASTERS) - 1 downto 0),
      links_enable((NB_SLAVES * NB_MASTERS) - 1 downto 0)
    );

    constant C_SEP   : character := ';';
    constant C_SEP_S : string    := "';'";

    -- File reader
    file configfile         : text;               -- CSV file with configuration
    -- hds checking_off
    -- Deactivate DRC (STYP4 rule) because variable type "line" is not synthesized in this case
    variable configfileline : line;               -- @suppress line is not synthesized in this case
    -- hds checking_on

    variable rd_reg     : string(1 to 4);         -- Read register from line
    variable sep        : character;              -- Read separator             -- @suppress "variable sep is never read"
    variable config_reg : std_logic_vector(2 downto 0); -- Translation of register string in slv
    variable config     : t_switch_config_constrained; -- Output configuration
    variable link_index : integer range 0 to (NB_SLAVES * NB_MASTERS) - 1; -- Index for links configuratiton
  begin
    -- Access to file
    file_open(configfile, CONFIG_FILENAME, READ_MODE);

    -- Drop headers line with slave list
    readline(configfile, configfileline);

    -- **********************************************************
    -- Read Slave register line
    readline(configfile, configfileline);

    -- Drop the first 3 columns
    for drop in 1 to 3 loop
      sep := 'a';
      while (sep /= C_SEP) loop
        read(configfileline, sep);
      end loop;
    end loop;

    -- Load register configuration for slaves
    for slave in 0 to NB_SLAVES - 1 loop
      -- Read configuration
      read(configfileline, rd_reg);
      config_reg                        := parse_register_configuration(rd_reg, "slave register number " & integer'IMAGE(slave));
      config.reg_slaves_forward(slave)  := config_reg(0);
      config.reg_slaves_backward(slave) := config_reg(1);

      -- Drop separator
      if slave < (NB_SLAVES - 1) then
        read(configfileline, sep);
        assert sep = C_SEP report "Invalid format: " & C_SEP_S & " expected after configuration of slave register number " & integer'IMAGE(slave) severity failure;
      end if;
    end loop;                                     -- slaves' registers

    -- **********************************************************
    -- Read Masters configuration lines
    for master in 0 to NB_MASTERS - 1 loop
      readline(configfile, configfileline);

      -- Drop master name
      sep := 'a';
      while (sep /= C_SEP) loop
        read(configfileline, sep);
      end loop;

      -- Read master register configuration
      read(configfileline, rd_reg);
      config_reg                          := parse_register_configuration(rd_reg, "master register number " & integer'IMAGE(master));
      config.reg_masters_forward(master)  := config_reg(0);
      config.reg_masters_backward(master) := config_reg(1);
      read(configfileline, sep);                  -- Drop separator
      assert sep = C_SEP report "Invalid format: " & C_SEP_S & " expected after configuration of master register number " & integer'IMAGE(master) severity failure;

      -- Read arbiter register configuration
      read(configfileline, rd_reg);
      config_reg                       := parse_register_configuration(rd_reg, "arbiter register number " & integer'IMAGE(master));
      config.reg_arbs_forward(master)  := config_reg(0);
      config.reg_arbs_backward(master) := config_reg(1);
      read(configfileline, sep);                  -- Drop separator
      assert sep = C_SEP report "Invalid format: " & C_SEP_S & " expected after configuration of arbiter register number " & integer'IMAGE(master) severity failure;

      -- Read slave->master connection
      for slave in 0 to (NB_SLAVES - 1) loop
        link_index := (NB_MASTERS * slave) + master;

        -- Read slave->master connection
        read(configfileline, rd_reg);
        config_reg                            := parse_register_configuration(rd_reg, "connection slave " & integer'IMAGE(slave) & " to master " & integer'IMAGE(master), true);
        config.reg_links_forward(link_index)  := config_reg(0);
        config.reg_links_backward(link_index) := config_reg(1);
        config.links_enable(link_index)       := config_reg(2);

        -- Drop separator
        if slave < (NB_SLAVES - 1) then
          read(configfileline, sep);
          assert sep = C_SEP report "Invalid format: " & C_SEP_S & " expected after configuration of connection slave " & integer'IMAGE(slave) & " to master " & integer'IMAGE(master) severity failure;
        end if;
      end loop;                                   -- slaves connection
    end loop;                                     -- masters' registers
    file_close(configfile);
    return config;
  end function load_axis_switch_configuration_from_csv;

end package body axis_utils_pkg;

