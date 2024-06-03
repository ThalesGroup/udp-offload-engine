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
--        AXIS_DEMUX_NOTDEST
--
------------------------------------------------
-- Axi4-Stream demultiplexer without using the tdest field
----------------------
-- The entity uses the master select port to to determine which master is selected
--
-- The entity is parametrizable in sizes of buses
-- The entity is parametrizable in number of masters
-- The entity is parametrizable in reset type and polarity
-- The entity is parametrizable in arbitration type (by packet or each sample of data)
-- The entity is parametrizable in registering
--
-- The master ports are concatenated on one single port with the least significant master on LSB
--
----------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.dev_utils_pkg.to_boolean;

use common.axis_utils_pkg.axis_register;


entity axis_demux_notdest is
  generic(
    G_ACTIVE_RST           : std_logic        := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST            : boolean          := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH          : positive         := 32;    -- Width of the tdata vector of the stream
    G_TUSER_WIDTH          : positive         := 1;     -- Width of the tuser vector of the stream
    G_TID_WIDTH            : positive         := 1;     -- Width of the tid vector of the stream
    G_TDEST_WIDTH          : positive         := 1;     -- Width of the tdest vector of the stream
    G_NB_MASTER            : positive         := 2;     -- Number of Master interfaces
    G_REG_SLAVE_FORWARD    : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for slave ports
    G_REG_SLAVE_BACKWARD   : boolean          := false; -- Whether to register the backward path (tready) for slave ports
    G_REG_MASTERS_FORWARD  : std_logic_vector := "00";  -- Whether to register the forward path (tdata, tvalid and others) for masters ports
    G_REG_MASTERS_BACKWARD : std_logic_vector := "00";  -- Whether to register the backward path (tready) for masters ports
    G_REG_SELECT_FORWARD   : boolean          := false; -- Whether to register the forward path (tdata, tvalid and others) for selection ports
    G_REG_SELECT_BACKWARD  : boolean          := false; -- Whether to register the backward path (tready) for selection ports
    G_PACKET_MODE          : boolean          := false  -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
  );
  port(
    CLK        : in  std_logic;
    RST        : in  std_logic;
    -- SELECTION INTERFACE
    SEL_TDATA  : in  std_logic_vector(integer(ceil(log2(real(G_NB_MASTER)))) - 1 downto 0);
    SEL_TVALID : in  std_logic;
    SEL_TREADY : out std_logic;
    -- SLAVE INTERFACE
    S_TDATA    : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID   : in  std_logic;
    S_TLAST    : in  std_logic;
    S_TUSER    : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP    : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID      : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST    : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY   : out std_logic;
    -- MASTER INTERFACES
    M_TDATA    : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);
    M_TVALID   : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TLAST    : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TUSER    : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);
    M_TSTRB    : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TKEEP    : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TID      : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);
    M_TDEST    : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);
    M_TREADY   : in  std_logic_vector(G_NB_MASTER - 1 downto 0)
  );
end axis_demux_notdest;

architecture rtl of axis_demux_notdest is

  -- Constants declaration
  constant C_TSTRB_WIDTH : positive := ((G_TDATA_WIDTH + 7) / 8);

  -- Types declaration
  type t_axis_forward is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tvalid : std_logic;
    tlast  : std_logic;
    tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    tstrb  : std_logic_vector(C_TSTRB_WIDTH - 1 downto 0);
    tkeep  : std_logic_vector(C_TSTRB_WIDTH - 1 downto 0);
    tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
    tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
  end record t_axis_forward;

  type t_axis_forward_arr is array (natural range <>) of t_axis_forward;

  -- Signals declaration
  signal sel_from_reg_tdata  : std_logic_vector(SEL_TDATA'range);
  signal sel_from_reg_tvalid : std_logic;
  signal sel_from_reg_tready : std_logic;

  signal s_from_reg        : t_axis_forward;
  signal s_from_reg_tready : std_logic;

  signal m_to_reg        : t_axis_forward_arr(G_NB_MASTER - 1 downto 0); -- @suppress array of record of allowed types
  signal m_to_reg_tready : std_logic_vector(G_NB_MASTER - 1 downto 0);

  -- selection
  signal sel : integer range 0 to G_NB_MASTER - 1;

begin

  --------------------------------------------------------------------
  -- Register the selection port
  --------------------------------------------------------------------

  inst_axis_register_select : component axis_register
    generic map(                         -- @suppress All parameters are not used
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => SEL_TDATA'length,
      G_REG_FORWARD  => G_REG_SELECT_FORWARD,
      G_REG_BACKWARD => G_REG_SELECT_BACKWARD
    )
    port map(                            -- @suppress All unused ports are left to default values
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- axi4-stream slave
      S_TDATA  => SEL_TDATA,
      S_TVALID => SEL_TVALID,
      S_TREADY => SEL_TREADY,
      -- axi4-stream master
      M_TDATA  => sel_from_reg_tdata,
      M_TVALID => sel_from_reg_tvalid,
      M_TREADY => sel_from_reg_tready
    );

  --------------------------------------------------------------------
  -- Logic for selection
  --------------------------------------------------------------------

  -- decode input selection
  sel <= to_integer(unsigned(sel_from_reg_tdata)) when sel_from_reg_tvalid = '1' else 0;

  -- SEL_TREADY -> activated each time a word is sent (or a frame is ended in case of TLAST update)
  sel_from_reg_tready <= s_from_reg.tlast and (s_from_reg_tready and s_from_reg.tvalid) when G_PACKET_MODE else s_from_reg_tready and s_from_reg.tvalid;

  --------------------------------------------------------------------
  -- Register the slave port
  --------------------------------------------------------------------

  inst_axis_register_slave : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => G_TDATA_WIDTH,
      G_TUSER_WIDTH  => G_TUSER_WIDTH,
      G_TID_WIDTH    => G_TID_WIDTH,
      G_TDEST_WIDTH  => G_TDEST_WIDTH,
      G_REG_FORWARD  => G_REG_SLAVE_FORWARD,
      G_REG_BACKWARD => G_REG_SLAVE_BACKWARD
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- axi4-stream slave
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TUSER  => S_TUSER,
      S_TSTRB  => S_TSTRB,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => S_TREADY,
      -- axi4-stream master
      M_TDATA  => s_from_reg.tdata,
      M_TVALID => s_from_reg.tvalid,
      M_TLAST  => s_from_reg.tlast,
      M_TUSER  => s_from_reg.tuser,
      M_TSTRB  => s_from_reg.tstrb,
      M_TKEEP  => s_from_reg.tkeep,
      M_TID    => s_from_reg.tid,
      M_TDEST  => s_from_reg.tdest,
      M_TREADY => s_from_reg_tready
    );

  --------------------------------------------------------------------
  -- Multiplexing the backward signals
  --------------------------------------------------------------------
  -- only when selection is valid
  s_from_reg_tready <= m_to_reg_tready(sel) and sel_from_reg_tvalid;

  --------------------------------------------------------------------
  -- Generate logic for each master
  --------------------------------------------------------------------
  GEN_MASTER : for master in G_NB_MASTER - 1 downto 0 generate
    -- Constants for register generics
    constant C_REG_FORWARD  : boolean := to_boolean(G_REG_MASTERS_FORWARD(master));
    constant C_REG_BACKWARD : boolean := to_boolean(G_REG_MASTERS_BACKWARD(master));

    -- value when bus is not selected (all is don't care except TVALID which is '0')
    constant C_AXIS_FORWARD_DEFAULT : t_axis_forward := (
      tdata  => (others => '-'),
      tvalid => '0',
      tlast  => '-',
      tuser  => (others => '-'),
      tstrb  => (others => '-'),
      tkeep  => (others => '-'),
      tid    => (others => '-'),
      tdest  => (others => '-')
    );
  begin

    --------------------------------------------------------------------
    -- Demultiplexing the forward signals
    --------------------------------------------------------------------
    -- only when selection is valid
    m_to_reg(master) <= s_from_reg when (sel = master) and (sel_from_reg_tvalid = '1') else C_AXIS_FORWARD_DEFAULT;

    --------------------------------------------------------------------
    -- Register the master port
    --------------------------------------------------------------------
    inst_axis_register_master : component axis_register
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
        S_TDATA  => m_to_reg(master).tdata,
        S_TVALID => m_to_reg(master).tvalid,
        S_TLAST  => m_to_reg(master).tlast,
        S_TUSER  => m_to_reg(master).tuser,
        S_TSTRB  => m_to_reg(master).tstrb,
        S_TKEEP  => m_to_reg(master).tkeep,
        S_TID    => m_to_reg(master).tid,
        S_TDEST  => m_to_reg(master).tdest,
        S_TREADY => m_to_reg_tready(master),
        -- axi4-stream master
        M_TDATA  => M_TDATA(((master + 1) * G_TDATA_WIDTH) - 1 downto master * G_TDATA_WIDTH),
        M_TVALID => M_TVALID(master),
        M_TLAST  => M_TLAST(master),
        M_TUSER  => M_TUSER(((master + 1) * G_TUSER_WIDTH) - 1 downto master * G_TUSER_WIDTH),
        M_TSTRB  => M_TSTRB(((master + 1) * C_TSTRB_WIDTH) - 1 downto master * C_TSTRB_WIDTH),
        M_TKEEP  => M_TKEEP(((master + 1) * C_TSTRB_WIDTH) - 1 downto master * C_TSTRB_WIDTH),
        M_TID    => M_TID(((master + 1) * G_TID_WIDTH) - 1 downto master * G_TID_WIDTH),
        M_TDEST  => M_TDEST(((master + 1) * G_TDEST_WIDTH) - 1 downto master * G_TDEST_WIDTH),
        M_TREADY => M_TREADY(master)
      );

  end generate GEN_MASTER;

end rtl;
