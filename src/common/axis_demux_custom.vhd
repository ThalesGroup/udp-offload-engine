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
--        AXIS_DEMUX_CUSTOM
--
------------------------------------------------
-- Axi4-Stream demultiplexer
----------------------
-- The output port is selected thanks to the TDEST field (coded as plain binary)
--
-- The entity is parametrizable in reset type and polarity
-- The entity is parametrizable in sizes of buses
-- The entity is parametrizable in number of masters
-- The entity is parametrizable in registering (finely)
--
-- The master ports are concatenated on one single port with the least significant master on LSB
----------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


use work.axis_utils_pkg.axis_register;


entity axis_demux_custom is
  generic(
    G_ACTIVE_RST           : std_logic        := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST            : boolean          := false; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH          : positive         := 32; -- Width of the tdata vector of the stream
    G_TUSER_WIDTH          : positive         := 1; -- Width of the tuser vector of the stream
    G_TID_WIDTH            : positive         := 1; -- Width of the tid vector of the stream
    G_TDEST_WIDTH          : positive         := 1; -- Width of the tdest vector of the stream
    G_NB_MASTER            : positive         := 2; -- Number of Master interfaces
    G_REG_SLAVE_FORWARD    : boolean          := true; -- Whether to register the forward path (tdata, tvalid and others) for slave ports
    G_REG_SLAVE_BACKWARD   : boolean          := true; -- Whether to register the backward path (tready) for slave ports
    G_REG_MASTERS_FORWARD  : std_logic_vector := "11"; -- Whether to register the forward path (tdata, tvalid and others) for masters ports
    G_REG_MASTERS_BACKWARD : std_logic_vector := "00" -- Whether to register the backward path (tready) for masters ports
  );
  port(
    -- GLOBAL
    CLK      : in  std_logic;
    RST      : in  std_logic;

    -- SLAVE INTERFACE
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY : out std_logic;

    -- MASTER INTERFACE
    M_TDATA  : out std_logic_vector((G_NB_MASTER * G_TDATA_WIDTH) - 1 downto 0);
    M_TVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TLAST  : out std_logic_vector(G_NB_MASTER - 1 downto 0);
    M_TUSER  : out std_logic_vector((G_NB_MASTER * G_TUSER_WIDTH) - 1 downto 0);
    M_TSTRB  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TKEEP  : out std_logic_vector((G_NB_MASTER * ((G_TDATA_WIDTH + 7) / 8)) - 1 downto 0);
    M_TID    : out std_logic_vector((G_NB_MASTER * G_TID_WIDTH) - 1 downto 0);
    M_TDEST  : out std_logic_vector((G_NB_MASTER * G_TDEST_WIDTH) - 1 downto 0);
    M_TREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0)
  );
end axis_demux_custom;


architecture rtl of axis_demux_custom is

  --------------------------------------------------------------------
  -- Components declaration
  --------------------------------------------------------------------

  --demultipler logic
  component axis_demux_notdest
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
  end component axis_demux_notdest;


  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- signals for selection
  signal sel_tdata  : std_logic_vector(integer(ceil(log2(real(G_NB_MASTER)))) - 1 downto 0);
  signal sel_tvalid : std_logic;

  -- input signal after registering
  signal input_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal input_tvalid : std_logic;
  signal input_tlast  : std_logic;
  signal input_tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal input_tstrb  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal input_tkeep  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal input_tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
  signal input_tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
  signal input_tready : std_logic;


begin

  --------------------------------------------------------------------
  -- INPUT REGISTER
  --------------------------------------------------------------------

  -- register the sel and the slave bus
  inst_axis_register : component axis_register
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
      CLK      => CLK,
      RST      => RST,

      -- slave
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TUSER  => S_TUSER,
      S_TSTRB  => S_TSTRB,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TDEST  => S_TDEST,
      S_TREADY => S_TREADY,

      -- master
      M_TDATA  => input_tdata,
      M_TVALID => input_tvalid,
      M_TLAST  => input_tlast,
      M_TUSER  => input_tuser,
      M_TSTRB  => input_tstrb,
      M_TKEEP  => input_tkeep,
      M_TID    => input_tid,
      M_TDEST  => input_tdest,
      M_TREADY => input_tready
    );


  --------------------------------------------------------------------
  -- SELECT
  --------------------------------------------------------------------

  -- connecting the select value to the tdest field
  sel_tdata  <= std_logic_vector(resize(unsigned(input_tdest), integer(ceil(log2(real(G_NB_MASTER))))));
  sel_tvalid <= input_tvalid;


  --------------------------------------------------------------------
  -- DEMUX
  --------------------------------------------------------------------

  -- using component for pure demuxing logic
  inst_axis_demux_notdest : component axis_demux_notdest
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_TUSER_WIDTH          => G_TUSER_WIDTH,
      G_TID_WIDTH            => G_TID_WIDTH,
      G_TDEST_WIDTH          => G_TDEST_WIDTH,
      G_NB_MASTER            => G_NB_MASTER,
      G_REG_SLAVE_FORWARD    => false,
      G_REG_SLAVE_BACKWARD   => false,
      G_REG_MASTERS_FORWARD  => G_REG_MASTERS_FORWARD,
      G_REG_MASTERS_BACKWARD => G_REG_MASTERS_BACKWARD,
      G_REG_SELECT_FORWARD   => false,
      G_REG_SELECT_BACKWARD  => false,
      G_PACKET_MODE          => false
    )
    port map(
      CLK        => CLK,
      RST        => RST,

      -- selection
      SEL_TDATA  => sel_tdata,
      SEL_TVALID => sel_tvalid,
      SEL_TREADY => open, -- not necessary because no register on selection bus

      -- slave
      S_TDATA    => input_tdata,
      S_TVALID   => input_tvalid,
      S_TLAST    => input_tlast,
      S_TUSER    => input_tuser,
      S_TSTRB    => input_tstrb,
      S_TKEEP    => input_tkeep,
      S_TID      => input_tid,
      S_TDEST    => input_tdest,
      S_TREADY   => input_tready,

      -- masters
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

end rtl;
