-- Copyright (c) 2022-2023 THALES. All Rights Reserved
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

----------------------------------
-- Package datatest_tools_pkg
----------------------------------
--
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a library user
--
-- This package contains the declaration of the following components
-- * gen_prbs
-- * gen_ramp
-- * axis_pkt_gen
-- * axis_pkt_chk
-- * axis_rate_meter
-- * axis_monitor
-- * axis_frame_chk
--
----------------------------------

package datatest_tools_pkg is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------
  -- Data type
  constant C_GEN_PRBS : integer := 0;
  constant C_GEN_RAMP : integer := 1;

  -- Frame type
  constant C_STATIC_SIZE  : std_logic := '0';
  constant C_DYNAMIC_SIZE : std_logic := '1';

  --------------------------------------------------------------------
  -- Components declaration
  --------------------------------------------------------------------

  -- gen_prbs
  component gen_prbs is
    generic(
      G_ASYNC_RST   : boolean               := false;
      G_ACTIVE_RST  : std_logic             := '1';
      G_TDATA_WIDTH : positive              := 8;
      G_PRBS_LENGTH : integer range 2 to 63 := 8
    );
    port(
      CLK             : in  std_logic;
      RST             : in  std_logic;
      S_CONFIG_TREADY : out std_logic;
      S_CONFIG_TVALID : in  std_logic;
      S_CONFIG_TDATA  : in  std_logic_vector(G_PRBS_LENGTH - 1 downto 0);
      M_TREADY        : in  std_logic := '1';
      M_TVALID        : out std_logic;
      M_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0)
    );
  end component gen_prbs;

  -- gen_ramp
  component gen_ramp is
    generic(
      G_ASYNC_RST   : boolean   := false;
      G_ACTIVE_RST  : std_logic := '1';
      G_TDATA_WIDTH : positive  := 8
    );
    port(
      CLK                 : in  std_logic;
      RST                 : in  std_logic;
      S_CONFIG_TREADY     : out std_logic;
      S_CONFIG_TVALID     : in  std_logic;
      S_CONFIG_TDATA_INIT : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_CONFIG_TDATA_STEP : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TREADY            : in  std_logic := '1';
      M_TVALID            : out std_logic;
      M_TDATA             : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0)
    );
  end component gen_ramp;

  -- axis_pkt_gen
  component axis_pkt_gen is
    generic(
      G_ASYNC_RST      : boolean   := false;
      G_ACTIVE_RST     : std_logic := '1';
      G_TDATA_WIDTH    : positive  := 8; -- Data bus size
      G_TUSER_WIDTH    : positive  := 8; -- User bus size used to transmit frame size
      G_LSB_TKEEP      : boolean   := true; -- To choose if the TKEEP must be in LSB or MSB
      G_FRAME_SIZE_MIN : positive  := 1; -- Minimum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
      G_FRAME_SIZE_MAX : positive  := 255; -- Maximum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
      G_DATA_TYPE      : integer   := C_GEN_PRBS -- PRBS : 0 / RAMP : 1
    );
    port(
      CLK               : in  std_logic;
      RST               : in  std_logic;
      -- Output ports
      M_TREADY          : in  std_logic := '1';
      M_TVALID          : out std_logic;
      M_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TLAST           : out std_logic;
      M_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TUSER           : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
      --Configuration ports
      ENABLE            : in  std_logic;
      NB_FRAME          : in  std_logic_vector(15 downto 0); -- Number of trame to generate : if 0, frame are generated endlessly
      FRAME_TYPE        : in  std_logic; -- '0' (static) : frames generated will always have the same size / '1' (dynamic) : frames will have different sizes
      FRAME_STATIC_SIZE : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0); -- Number of bytes in each frame in case the frame type is static
      DONE              : out std_logic -- When asserted, indicate the end of data generation
    );
  end component axis_pkt_gen;

  -- axis_pkt_chk
  component axis_pkt_chk is
    generic(
      G_ASYNC_RST   : boolean   := false;
      G_ACTIVE_RST  : std_logic := '1';
      G_TDATA_WIDTH : positive  := 64;  -- Data bus size
      G_TUSER_WIDTH : positive  := 1;   -- User bus size
      G_TDEST_WIDTH : positive  := 1;   -- Dest bus size
      G_TID_WIDTH   : positive  := 1    -- ID bus size
    );
    port(
      CLK       : in  std_logic;
      RST       : in  std_logic;
      -- Input ports for interface 0
      S0_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S0_TVALID : in  std_logic;
      S0_TLAST  : in  std_logic                                                := '-';
      S0_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S0_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S0_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S0_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S0_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S0_TREADY : out std_logic;
      -- Input ports for interface 1
      S1_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S1_TVALID : in  std_logic;
      S1_TLAST  : in  std_logic                                                := '-';
      S1_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S1_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S1_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S1_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S1_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      S1_TREADY : out std_logic;
      -- Error ports
      ERR_DATA  : out std_logic;        -- Indicate a difference in data between the two interfaces
      ERR_LAST  : out std_logic;        -- Indicate a difference on tlast between the two interfaces
      ERR_KEEP  : out std_logic;        -- Indicate a difference on tkeep between the two interfaces
      ERR_STRB  : out std_logic;        -- Indicate a difference on tstrb between the two interfaces
      ERR_USER  : out std_logic;        -- Indicate a difference on tuser between the two interfaces
      ERR_DEST  : out std_logic;        -- Indicate a difference on tdest between the two interfaces
      ERR_ID    : out std_logic         -- Indicate a difference on tid between the two interfaces
    );
  end component axis_pkt_chk;

  -- axis_rate_meter
  component axis_rate_meter is
    generic(
      G_ACTIVE_RST  : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean   := false; -- Type of reset used (synchronous or asynchronous resets)
      G_TKEEP_WIDTH : positive  := 1;   -- Width of the tkeep vector of the stream
      G_CNT_WIDTH   : positive  := 32   -- Width of the internal counter
    );
    port(
      CLK                : in  std_logic;
      RST                : in  std_logic;
      -- Axis
      AXIS_TKEEP         : in  std_logic_vector(G_TKEEP_WIDTH - 1 downto 0)                                            := (others => '1');
      AXIS_TVALID        : in  std_logic;
      AXIS_TREADY        : in  std_logic;
      -- Ctrl
      TRIG_TVALID        : in  std_logic;
      TRIG_TDATA_INIT    : in  std_logic                                                                               := '1';
      TRIG_TDATA_BYTES   : in  std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0) := (others => '0');
      -- Status
      CNT_TDATA_BYTES    : out std_logic_vector((G_CNT_WIDTH + integer(ceil(log2(real(G_TKEEP_WIDTH))))) - 1 downto 0);
      CNT_TDATA_CYCLES   : out std_logic_vector(G_CNT_WIDTH - 1 downto 0);
      CNT_TUSER_OVERFLOW : out std_logic;
      CNT_TVALID         : out std_logic
    );
  end component axis_rate_meter;

  -- axis_monitor
  component axis_monitor
    generic(
      G_ASYNC_RST     : boolean   := false;
      G_ACTIVE_RST    : std_logic := '1';
      G_TDATA_WIDTH   : positive  := 64;
      G_TUSER_WIDTH   : positive  := 8;
      G_TID_WIDTH     : positive  := 1;
      G_TDEST_WIDTH   : positive  := 1;
      G_TIMEOUT_WIDTH : positive  := 32
    );
    port(
      CLK                 : in  std_logic;
      RST                 : in  std_logic;
      -- Inputs
      S_TREADY            : in  std_logic;
      S_TVALID            : in  std_logic;
      S_TDATA             : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TLAST             : in  std_logic                                                := '-';
      S_TKEEP             : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TSTRB             : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TUSER             : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TID               : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (others => '-');
      S_TDEST             : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (others => '-');
      -- Configuration
      ENABLE              : in  std_logic                                                := '1';
      TIMEOUT_VALUE       : in  std_logic_vector(G_TIMEOUT_WIDTH - 1 downto 0)           := (others => '0'); -- Maximum value allowed without receiving or sending any data       
      -- Errors
      TIMEOUT_READY_ERROR : out std_logic;
      TIMEOUT_VALID_ERROR : out std_logic;
      VALID_ERROR         : out std_logic;
      DATA_ERROR          : out std_logic;
      LAST_ERROR          : out std_logic;
      KEEP_ERROR          : out std_logic;
      STRB_ERROR          : out std_logic;
      USER_ERROR          : out std_logic;
      ID_ERROR            : out std_logic;
      DEST_ERROR          : out std_logic
    );
  end component axis_monitor;

  -- axis_frame_chk
  component axis_frame_chk is
    generic(
      G_ASYNC_RST      : boolean   := false;
      G_ACTIVE_RST     : std_logic := '1';
      G_TDATA_WIDTH    : positive  := 64;                                                 -- Data bus size
      G_TUSER_WIDTH    : positive  := 8;                                                  -- User bus size used to transmit frame size 
      G_LSB_TKEEP      : boolean   := true;                                               -- To choose if the TKEEP must be in LSB or MSB
      G_FRAME_SIZE_MIN : positive  := 1;                                                  -- Minimum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
      G_FRAME_SIZE_MAX : positive  := 255;                                                -- Maximum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
      G_DATA_TYPE      : integer   := C_GEN_PRBS                                          -- PRBS : 0 / RAMP : 1
    );
    port(
      CLK               : in  std_logic;
      RST               : in  std_logic;
      -- Input ports
      S_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (others => '-');
      S_TVALID          : in  std_logic;
      S_TLAST           : in  std_logic                                                := '-';
      S_TUSER           : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (others => '-');
      S_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (others => '-');
      S_TREADY          : out std_logic;
      --Configuration ports
      ENABLE            : in  std_logic                                                := '1';
      NB_FRAME          : in  std_logic_vector(15 downto 0);                              -- Number of trame to generate : if 0, frame are generated endlessly
      FRAME_TYPE        : in  std_logic;                                                  -- '0' (static) : frames generated will always have the same size / '1' (dynamic) : frames will have different sizes
      FRAME_STATIC_SIZE : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);               -- Number of bytes in each frame in case the frame type is static
      DONE              : out std_logic;                                                  -- When asserted, indicate the end of data generation
      -- Error ports
      DATA_ERROR        : out std_logic;                                                  -- Indicate a difference in data between the two interfaces
      LAST_ERROR        : out std_logic;                                                  -- Indicate a difference on tlast between the two interfaces
      KEEP_ERROR        : out std_logic;                                                  -- Indicate a difference on tkeep between the two interfaces
      USER_ERROR        : out std_logic                                                   -- Indicate a difference on tuser between the two interfaces
    );
  end component axis_frame_chk;

end datatest_tools_pkg;

--========================================
-- Package Body
--========================================

package body datatest_tools_pkg is

end datatest_tools_pkg;
