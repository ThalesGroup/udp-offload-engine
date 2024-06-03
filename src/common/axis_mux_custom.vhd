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
--        AXIS_MUX_CUSTOM
--
------------------------------------------------
-- Axi4-Stream multiplexer
----------------------
-- The entity uses an arbiter to determine which port has priority
--
-- Several architecture are available:
--
-- FAST (ONE HOT) :
-- The arbiter grants the priority thanks to a one hot encoded vector.
-- This arbiter is optimized for clock frequency
--
-- not FAST (BINARY) :
-- The arbiter grants the priority thanks to a binary encoded vector
-- This arbiter is optimized for area occupation
--
-- When several masters want to send a stream at the same time, an arbitration decision must be taken.
-- Several arbitration schemes are available:
--
-- FIXED:
-- The highest priority is given to the port with the lowest index
--
-- ROUND ROBIN:
-- The last arbitrated port gets the lowest priority for next arbitration
--
----------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.dev_utils_pkg.to_boolean;

use common.axis_utils_pkg.axis_register;


entity axis_mux_custom is
  generic(
    G_ACTIVE_RST          : std_logic        := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST           : boolean          := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH         : positive         := 32; -- Width of the tdata vector of the stream
    G_TUSER_WIDTH         : positive         := 1; -- Width of the tuser vector of the stream
    G_TID_WIDTH           : positive         := 1; -- Width of the tid vector of the stream
    G_TDEST_WIDTH         : positive         := 1; -- Width of the tdest vector of the stream
    G_NB_SLAVE            : positive         := 2; -- Number of Slave interfaces
    G_REG_SLAVES_FORWARD  : std_logic_vector := "11"; -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
    G_REG_SLAVES_BACKWARD : std_logic_vector := "11"; -- Whether to register the backward path (tready) for slaves ports
    G_REG_MASTER_FORWARD  : boolean          := true; -- Whether to register the forward path (tdata, tvalid and others) for master ports
    G_REG_MASTER_BACKWARD : boolean          := false; -- Whether to register the backward path (tready) for master ports
    G_REG_ARB_FORWARD     : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for arbitration path
    G_REG_ARB_BACKWARD    : boolean          := false; -- Whether to register the backward path (tready) for arbitration path
    G_PACKET_MODE         : boolean          := false; -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
    G_ROUND_ROBIN         : boolean          := false; -- Whether to use a round_robin or fixed priorities
    G_FAST_ARCH           : boolean          := false -- Whether to use the fast architecture (one hot) or the area efficient one (binary)
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
end axis_mux_custom;


architecture rtl of axis_mux_custom is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------
  constant C_TSTRB_WIDTH : positive := ((G_TDATA_WIDTH + 7) / 8);

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- from input registers
  signal s_from_reg_tdata  : std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0);
  signal s_from_reg_tvalid : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal s_from_reg_tlast  : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal s_from_reg_tuser  : std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0);
  signal s_from_reg_tstrb  : std_logic_vector((G_NB_SLAVE * C_TSTRB_WIDTH) - 1 downto 0);
  signal s_from_reg_tkeep  : std_logic_vector((G_NB_SLAVE * C_TSTRB_WIDTH) - 1 downto 0);
  signal s_from_reg_tid    : std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0);
  signal s_from_reg_tdest  : std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0);
  signal s_from_reg_tready : std_logic_vector(G_NB_SLAVE - 1 downto 0);

begin

  --------------------------------------------------------------------
  --
  -- Generate a register for each slave
  --
  --------------------------------------------------------------------

  GEN_SLAVE : for slave in 0 to G_NB_SLAVE - 1 generate

    -- Constants for register generics
    constant C_REG_FORWARD  : boolean := to_boolean(G_REG_SLAVES_FORWARD(slave));
    constant C_REG_BACKWARD : boolean := to_boolean(G_REG_SLAVES_BACKWARD(slave));

  begin

    --------------------------------------------------------------------
    -- Register the slave port
    --------------------------------------------------------------------
    inst_axis_register_slave : component axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_TDATA_WIDTH,
        G_TUSER_WIDTH  => G_TUSER_WIDTH,
        G_TID_WIDTH    => G_TID_WIDTH,
        G_TDEST_WIDTH  => G_TDEST_WIDTH,
        G_REG_FORWARD  => C_REG_FORWARD,
        G_REG_BACKWARD => C_REG_BACKWARD
      )
      port map(
        -- GLOBAL
        CLK      => CLK,
        RST      => RST,
        -- axi4-stream slave
        S_TDATA  => S_TDATA(((slave + 1) * G_TDATA_WIDTH) - 1 downto slave * G_TDATA_WIDTH),
        S_TVALID => S_TVALID(slave),
        S_TLAST  => S_TLAST(slave),
        S_TUSER  => S_TUSER(((slave + 1) * G_TUSER_WIDTH) - 1 downto slave * G_TUSER_WIDTH),
        S_TSTRB  => S_TSTRB(((slave + 1) * C_TSTRB_WIDTH) - 1 downto slave * C_TSTRB_WIDTH),
        S_TKEEP  => S_TKEEP(((slave + 1) * C_TSTRB_WIDTH) - 1 downto slave * C_TSTRB_WIDTH),
        S_TID    => S_TID(((slave + 1) * G_TID_WIDTH) - 1 downto slave * G_TID_WIDTH),
        S_TDEST  => S_TDEST(((slave + 1) * G_TDEST_WIDTH) - 1 downto slave * G_TDEST_WIDTH),
        S_TREADY => S_TREADY(slave),
        -- axi4-stream master
        M_TDATA  => s_from_reg_tdata(((slave + 1) * G_TDATA_WIDTH) - 1 downto slave * G_TDATA_WIDTH),
        M_TVALID => s_from_reg_tvalid(slave),
        M_TLAST  => s_from_reg_tlast(slave),
        M_TUSER  => s_from_reg_tuser(((slave + 1) * G_TUSER_WIDTH) - 1 downto slave * G_TUSER_WIDTH),
        M_TSTRB  => s_from_reg_tstrb(((slave + 1) * C_TSTRB_WIDTH) - 1 downto slave * C_TSTRB_WIDTH),
        M_TKEEP  => s_from_reg_tkeep(((slave + 1) * C_TSTRB_WIDTH) - 1 downto slave * C_TSTRB_WIDTH),
        M_TID    => s_from_reg_tid(((slave + 1) * G_TID_WIDTH) - 1 downto slave * G_TID_WIDTH),
        M_TDEST  => s_from_reg_tdest(((slave + 1) * G_TDEST_WIDTH) - 1 downto slave * G_TDEST_WIDTH),
        M_TREADY => s_from_reg_tready(slave)
      );

  end generate GEN_SLAVE;

  --------------------------------------------------------------------
  --
  -- Generate the area efficient architecture
  --
  --------------------------------------------------------------------

  GEN_BINARY : if not G_FAST_ARCH generate


    --------------------------------------------------------------------
    -- Components declaration
    --------------------------------------------------------------------

    -- arbiter
    component arbiter_binary
      generic(
        G_ACTIVE_RST   : std_logic := '1';   -- State at which the reset signal is asserted (active low or active high)
        G_ASYNC_RST    : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
        G_NB_SLAVE     : positive  := 2;     -- Number of Slave interfaces
        G_REG_FORWARD  : boolean   := true;  -- Whether to register the forward path (tdata, tvalid and others) for selection ports
        G_REG_BACKWARD : boolean   := true;  -- Whether to register the backward path (tready) for selection ports
        G_PACKET_MODE  : boolean   := false; -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
        G_ROUND_ROBIN  : boolean   := false  -- Whether to use a round_robin or fixed priorities
      );
      port(
        RST        : in  std_logic;
        CLK        : in  std_logic;
        -- SLAVE INTERFACES MONITORING
        S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TREADY   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        -- SELECTION INTERFACE
        SEL_TDATA  : out std_logic_vector(integer(ceil(log2(real(G_NB_SLAVE)))) - 1 downto 0);
        SEL_TVALID : out std_logic;
        SEL_TREADY : in  std_logic
      );
    end component arbiter_binary;


    -- mux with no arbiter
    component axis_mux_noarb_binary
      generic(
        G_ACTIVE_RST          : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
        G_ASYNC_RST           : boolean          := true;  -- Type of reset used (synchronous or asynchronous resets)
        G_TDATA_WIDTH         : positive         := 32;    -- Width of the tdata vector of the stream
        G_TUSER_WIDTH         : positive         := 1;     -- Width of the tuser vector of the stream
        G_TID_WIDTH           : positive         := 1;     -- Width of the tid vector of the stream
        G_TDEST_WIDTH         : positive         := 1;     -- Width of the tdest vector of the stream
        G_NB_SLAVE            : positive         := 2;     -- Number of Slave interfaces
        G_REG_SLAVES_FORWARD  : std_logic_vector := "00";  -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
        G_REG_SLAVES_BACKWARD : std_logic_vector := "00";  -- Whether to register the backward path (tready) for slaves ports
        G_REG_MASTER_FORWARD  : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for master ports
        G_REG_MASTER_BACKWARD : boolean          := false; -- Whether to register the backward path (tready) for master ports
        G_REG_SELECT_FORWARD  : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for selection ports
        G_REG_SELECT_BACKWARD : boolean          := false; -- Whether to register the backward path (tready) for selection ports
        G_PACKET_MODE         : boolean          := false  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      );
      port(
        -- GLOBAL
        CLK        : in  std_logic;
        RST        : in  std_logic;
        -- SELECTION INTERFACE
        SEL_TDATA  : in  std_logic_vector(integer(ceil(log2(real(G_NB_SLAVE)))) - 1 downto 0);
        SEL_TVALID : in  std_logic;
        SEL_TREADY : out std_logic;
        -- SLAVE INTERFACES
        S_TDATA    : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0);
        S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TUSER    : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0);
        S_TSTRB    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
        S_TKEEP    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
        S_TID      : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0);
        S_TDEST    : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0);
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
        M_TREADY   : in  std_logic
      );
    end component axis_mux_noarb_binary;


    --------------------------------------------------------------------
    -- Signals declaration
    --------------------------------------------------------------------

    -- arbitration bus
    signal sel_bin_tdata  : std_logic_vector(integer(ceil(log2(real(G_NB_SLAVE)))) - 1 downto 0);
    signal sel_bin_tvalid : std_logic;
    signal sel_bin_tready : std_logic;


  begin

    -- arbiter
    inst_arbiter_binary : component arbiter_binary
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_NB_SLAVE     => G_NB_SLAVE,
        G_REG_FORWARD  => G_REG_ARB_FORWARD,
        G_REG_BACKWARD => G_REG_ARB_BACKWARD,
        G_PACKET_MODE  => G_PACKET_MODE,
        G_ROUND_ROBIN  => G_ROUND_ROBIN
      )
      port map(
        RST        => RST,
        CLK        => CLK,
        S_TVALID   => s_from_reg_tvalid,
        S_TLAST    => s_from_reg_tlast,
        S_TREADY   => s_from_reg_tready,
        SEL_TDATA  => sel_bin_tdata,
        SEL_TVALID => sel_bin_tvalid,
        SEL_TREADY => sel_bin_tready
      );

    -- multiplexer
    inst_axis_mux_noarb_binary : component axis_mux_noarb_binary
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TDATA_WIDTH         => G_TDATA_WIDTH,
        G_TUSER_WIDTH         => G_TUSER_WIDTH,
        G_TID_WIDTH           => G_TID_WIDTH,
        G_TDEST_WIDTH         => G_TDEST_WIDTH,
        G_NB_SLAVE            => G_NB_SLAVE,
        G_REG_SLAVES_FORWARD  => (G_NB_SLAVE - 1 downto 0 => '0'),
        G_REG_SLAVES_BACKWARD => (G_NB_SLAVE - 1 downto 0 => '0'),
        G_REG_MASTER_FORWARD  => G_REG_MASTER_FORWARD,
        G_REG_MASTER_BACKWARD => G_REG_MASTER_BACKWARD,
        G_REG_SELECT_FORWARD  => false,
        G_REG_SELECT_BACKWARD => false,
        G_PACKET_MODE         => G_PACKET_MODE
      )
      port map(
        -- GLOBAL
        CLK        => CLK,
        RST        => RST,
        -- SELECTION
        SEL_TDATA  => sel_bin_tdata,
        SEL_TVALID => sel_bin_tvalid,
        SEL_TREADY => sel_bin_tready,
        -- SLAVES
        S_TDATA    => s_from_reg_tdata,
        S_TVALID   => s_from_reg_tvalid,
        S_TLAST    => s_from_reg_tlast,
        S_TUSER    => s_from_reg_tuser,
        S_TSTRB    => s_from_reg_tstrb,
        S_TKEEP    => s_from_reg_tkeep,
        S_TID      => s_from_reg_tid,
        S_TDEST    => s_from_reg_tdest,
        S_TREADY   => s_from_reg_tready,
        -- MASTERS
        M_TDATA    => M_TDATA,
        M_TVALID   => M_TVALID,
        M_TLAST    => M_TLAST,
        M_TUSER    => M_TUSER,
        M_TSTRB    => M_TSTRB,
        M_TKEEP    => M_TKEEP,
        M_TID      => M_TID,
        M_TDEST    => M_TDEST,
        M_TREADY   => M_TREADY
      );


  end generate GEN_BINARY;

  --------------------------------------------------------------------
  --
  -- Generate the speed optimized architecture
  --
  --------------------------------------------------------------------

  GEN_ONEHOT : if G_FAST_ARCH generate

    --------------------------------------------------------------------
    -- Components declaration
    --------------------------------------------------------------------

    -- arbiter
    component arbiter_onehot
      generic(
        G_ACTIVE_RST   : std_logic := '1';   -- State at which the reset signal is asserted (active low or active high)
        G_ASYNC_RST    : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
        G_NB_SLAVE     : positive  := 2;     -- Number of Slave interfaces
        G_REG_FORWARD  : boolean   := true;  -- Whether to register the forward path (tdata, tvalid and others) for selection ports
        G_REG_BACKWARD : boolean   := true;  -- Whether to register the backward path (tready) for selection ports
        G_PACKET_MODE  : boolean   := false; -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
        G_ROUND_ROBIN  : boolean   := false  -- Whether to use a round_robin or fixed priorities
      );
      port(
        RST        : in  std_logic;
        CLK        : in  std_logic;
        -- SLAVE INTERFACES MONITORING
        S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TREADY   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        -- SELECTION INTERFACE
        SEL_TDATA  : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
        SEL_TVALID : out std_logic;
        SEL_TREADY : in  std_logic
      );
    end component arbiter_onehot;

    -- mux with no arbiter
    component axis_mux_noarb_onehot is
      generic(
        G_ACTIVE_RST          : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
        G_ASYNC_RST           : boolean          := true;  -- Type of reset used (synchronous or asynchronous resets)
        G_TDATA_WIDTH         : positive         := 32;    -- Width of the tdata vector of the stream
        G_TUSER_WIDTH         : positive         := 1;     -- Width of the tuser vector of the stream
        G_TID_WIDTH           : positive         := 1;     -- Width of the tid vector of the stream
        G_TDEST_WIDTH         : positive         := 1;     -- Width of the tdest vector of the stream
        G_NB_SLAVE            : positive         := 2;     -- Number of Slave interfaces
        G_REG_SLAVES_FORWARD  : std_logic_vector := "00";  -- Whether to register the forward path (tdata, tvalid and others) for slaves ports
        G_REG_SLAVES_BACKWARD : std_logic_vector := "00";  -- Whether to register the backward path (tready) for slaves ports
        G_REG_MASTER_FORWARD  : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for master ports
        G_REG_MASTER_BACKWARD : boolean          := false; -- Whether to register the backward path (tready) for master ports
        G_REG_SELECT_FORWARD  : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for selection ports
        G_REG_SELECT_BACKWARD : boolean          := false; -- Whether to register the backward path (tready) for selection ports
        G_PACKET_MODE         : boolean          := false  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
      );
      port(
        -- GLOBAL
        CLK        : in  std_logic;
        RST        : in  std_logic;
        -- SELECTION INTERFACE
        SEL_TDATA  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        SEL_TVALID : in  std_logic;
        SEL_TREADY : out std_logic;
        -- SLAVE INTERFACES
        S_TDATA    : in  std_logic_vector((G_NB_SLAVE * G_TDATA_WIDTH) - 1 downto 0);
        S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
        S_TUSER    : in  std_logic_vector((G_NB_SLAVE * G_TUSER_WIDTH) - 1 downto 0);
        S_TSTRB    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
        S_TKEEP    : in  std_logic_vector((G_NB_SLAVE * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
        S_TID      : in  std_logic_vector((G_NB_SLAVE * G_TID_WIDTH) - 1 downto 0);
        S_TDEST    : in  std_logic_vector((G_NB_SLAVE * G_TDEST_WIDTH) - 1 downto 0);
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
        M_TREADY   : in  std_logic
      );
    end component axis_mux_noarb_onehot;


    --------------------------------------------------------------------
    -- Signals declaration
    --------------------------------------------------------------------

    -- arbitration bus
    signal sel_onehot_tdata  : std_logic_vector(G_NB_SLAVE - 1 downto 0);
    signal sel_onehot_tvalid : std_logic;
    signal sel_onehot_tready : std_logic;


  begin

    -- arbiter
    inst_arbiter_onehot : component arbiter_onehot
      generic map(
        G_ACTIVE_RST         => G_ACTIVE_RST,
        G_ASYNC_RST          => G_ASYNC_RST,
        G_NB_SLAVE           => G_NB_SLAVE,
        G_REG_FORWARD        => G_REG_ARB_FORWARD,
        G_REG_BACKWARD       => G_REG_ARB_BACKWARD,
        G_PACKET_MODE        => G_PACKET_MODE,
        G_ROUND_ROBIN        => G_ROUND_ROBIN
      )
      port map(
        RST        => RST,
        CLK        => CLK,
        S_TVALID   => s_from_reg_tvalid,
        S_TLAST    => s_from_reg_tlast,
        S_TREADY   => s_from_reg_tready,
        SEL_TDATA  => sel_onehot_tdata,
        SEL_TVALID => sel_onehot_tvalid,
        SEL_TREADY => sel_onehot_tready
      );

    -- multiplexer
    inst_axis_mux_noarb_onehot : component axis_mux_noarb_onehot
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TDATA_WIDTH         => G_TDATA_WIDTH,
        G_TUSER_WIDTH         => G_TUSER_WIDTH,
        G_TID_WIDTH           => G_TID_WIDTH,
        G_TDEST_WIDTH         => G_TDEST_WIDTH,
        G_NB_SLAVE            => G_NB_SLAVE,
        G_REG_SLAVES_FORWARD  => (G_NB_SLAVE - 1 downto 0 => '0'),
        G_REG_SLAVES_BACKWARD => (G_NB_SLAVE - 1 downto 0 => '0'),
        G_REG_MASTER_FORWARD  => G_REG_MASTER_FORWARD,
        G_REG_MASTER_BACKWARD => G_REG_MASTER_BACKWARD,
        G_REG_SELECT_FORWARD  => false,
        G_REG_SELECT_BACKWARD => false,
        G_PACKET_MODE         => G_PACKET_MODE
      )
      port map(
        -- GLOBAL
        CLK        => CLK,
        RST        => RST,
        -- SELECTION
        SEL_TDATA  => sel_onehot_tdata,
        SEL_TVALID => sel_onehot_tvalid,
        SEL_TREADY => sel_onehot_tready,
        -- SLAVES
        S_TDATA    => s_from_reg_tdata,
        S_TVALID   => s_from_reg_tvalid,
        S_TLAST    => s_from_reg_tlast,
        S_TUSER    => s_from_reg_tuser,
        S_TSTRB    => s_from_reg_tstrb,
        S_TKEEP    => s_from_reg_tkeep,
        S_TID      => s_from_reg_tid,
        S_TDEST    => s_from_reg_tdest,
        S_TREADY   => s_from_reg_tready,
        -- MASTERS
        M_TDATA    => M_TDATA,
        M_TVALID   => M_TVALID,
        M_TLAST    => M_TLAST,
        M_TUSER    => M_TUSER,
        M_TSTRB    => M_TSTRB,
        M_TKEEP    => M_TKEEP,
        M_TID      => M_TID,
        M_TDEST    => M_TDEST,
        M_TREADY   => M_TREADY
      );


  end generate GEN_ONEHOT;

end rtl;
