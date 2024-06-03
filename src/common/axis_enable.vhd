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


----------------------------------------------------------------------------------
--
-- AXIS_ENABLE
--
----------------------------------------------------------------------------------
--
-- This module handle the enable/disable of an AXI4-Stream flow.
--
-- Width of AXI4-Stream signals can be configured by generics
-- G_PACKET_MODE generic define if enable should be taken into account at each transfer or each packet (TLAST = '1')
--
-- The control (Enable) is available through an AXI4-Stream interface
-- It allows the user to associate a specific transfer (or packet) with a control.
--
-- It is also possible to control enable with a discret signal following expected behavior when disable
-- * Blocking enable (S_TREADY = '0') => signal should be connected on S_EN_TVALID
-- * Filtering enable (S_TREADY = '1') => signal should be connected on S_EN_TDATA
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axis_utils_pkg.axis_register;


entity axis_enable is
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
    S_EN_TDATA  : in  std_logic;
    S_EN_TVALID : in  std_logic;
    S_EN_TREADY : out std_logic;
    -- Axi4-stream slave
    S_TDATA     : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID    : in  std_logic;
    S_TLAST     : in  std_logic;
    S_TUSER     : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP     : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID       : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST     : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
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
    M_TREADY    : in  std_logic
  );
end axis_enable;

architecture rtl of axis_enable is

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- Record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    tstrb  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    tkeep  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
    tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    tvalid : std_logic;
  end record t_forward_data;


  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- Axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  signal en_tdata  : std_logic;
  signal en_tvalid : std_logic;
  signal en_tready : std_logic;

  -- combine tvalid between data and enable
  signal cb_tvalid : std_logic;

  -- tvalid and tready after enable
  signal mid_tvalid_en : std_logic;
  signal mid_tready_en : std_logic;


begin

  -- Insert a register on enable backward path
  inst_axis_register_enable_backward : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => 1,
      G_REG_FORWARD    => false,
      G_REG_BACKWARD   => G_REG_BACKWARD,
      G_FULL_BANDWIDTH => G_FULL_BANDWIDTH
    )
    port map(
      CLK        => CLK,
      RST        => RST,
      S_TDATA(0) => S_EN_TDATA,
      S_TVALID   => S_EN_TVALID,
      S_TREADY   => S_EN_TREADY,
      M_TDATA(0) => en_tdata,
      M_TVALID   => en_tvalid,
      M_TREADY   => en_tready
    );

  -- Insert a register on backward path
  inst_axis_register_backward : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TUSER_WIDTH    => G_TUSER_WIDTH,
      G_TID_WIDTH      => G_TID_WIDTH,
      G_TDEST_WIDTH    => G_TDEST_WIDTH,
      G_REG_FORWARD    => false,
      G_REG_BACKWARD   => G_REG_BACKWARD,
      G_FULL_BANDWIDTH => G_FULL_BANDWIDTH
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
      M_TDATA  => mid.tdata,
      M_TVALID => mid.tvalid,
      M_TLAST  => mid.tlast,
      M_TUSER  => mid.tuser,
      M_TSTRB  => mid.tstrb,
      M_TKEEP  => mid.tkeep,
      M_TID    => mid.tid,
      M_TDEST  => mid.tdest,
      M_TREADY => mid_tready
    );

  -- Combine
  cb_tvalid  <= en_tvalid and mid.tvalid;
  mid_tready <= cb_tvalid and mid_tready_en;
  en_tready  <= cb_tvalid and mid_tready_en and mid.tlast when G_PACKET_MODE else
                cb_tvalid and mid_tready_en ;

  -- Enable
  mid_tvalid_en <= cb_tvalid when en_tdata = '1' else '0';


  -- Generate a register on forward path
  inst_axis_register_forward : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TUSER_WIDTH    => G_TUSER_WIDTH,
      G_TID_WIDTH      => G_TID_WIDTH,
      G_TDEST_WIDTH    => G_TDEST_WIDTH,
      G_REG_FORWARD    => G_REG_FORWARD,
      G_REG_BACKWARD   => false,
      G_FULL_BANDWIDTH => true          -- don't care when G_REG_BACKWARD is disable
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => mid.tdata,
      S_TVALID => mid_tvalid_en,
      S_TLAST  => mid.tlast,
      S_TUSER  => mid.tuser,
      S_TSTRB  => mid.tstrb,
      S_TKEEP  => mid.tkeep,
      S_TID    => mid.tid,
      S_TDEST  => mid.tdest,
      S_TREADY => mid_tready_en,
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

