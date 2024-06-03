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
--        AXIS_COMBINE
--
------------------------------------------------
-- Axi4-Stream combine
----------------------
-- The entity is used to combine and synchronize several AXI Stream buses
--
-- The number of slave is configurable by generic G_NB_SLAVE
-- The concatenation of signals should be done outside of the module
-- Slave interface has only one TLAST to allow the user to choose the source
--
----------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axis_utils_pkg.axis_register;


entity axis_combine is
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
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    S_TLAST  : in  std_logic;
    S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
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
    M_TREADY : in  std_logic
  );
end axis_combine;


architecture rtl of axis_combine is

  --signal declaration 
  signal axis_to_reg_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_to_reg_tvalid : std_logic;
  signal axis_to_reg_tready : std_logic;
  signal axis_to_reg_tstrb  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_to_reg_tkeep  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal axis_to_reg_tlast  : std_logic;
  signal axis_to_reg_tid    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
  signal axis_to_reg_tdest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
  signal axis_to_reg_tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);


begin

  -- direct copy
  axis_to_reg_tdata <= S_TDATA;
  axis_to_reg_tstrb <= S_TSTRB;
  axis_to_reg_tkeep <= S_TKEEP;
  axis_to_reg_tlast <= S_TLAST;
  axis_to_reg_tid   <= S_TID;
  axis_to_reg_tdest <= S_TDEST;
  axis_to_reg_tuser <= S_TUSER;


  -- tvalid is set to '1' when all tvalid are equal to '1'
  axis_to_reg_tvalid <= '1' when S_TVALID = (S_TVALID'range => '1') else '0'; --@suppress : PR5
  
  S_TREADY <= (others => axis_to_reg_tready and axis_to_reg_tvalid);


  --Output register 
  inst_axis_register : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => G_TDATA_WIDTH,
      G_TUSER_WIDTH  => G_TUSER_WIDTH,
      G_TID_WIDTH    => G_TID_WIDTH,
      G_TDEST_WIDTH  => G_TDEST_WIDTH,
      G_REG_FORWARD  => G_REG_OUT_FORWARD,
      G_REG_BACKWARD => G_REG_OUT_BACKWARD
    )
    port map(
      -- GLOBAL
      CLK      => CLK,
      RST      => RST,
      -- axi4-stream slave
      S_TDATA  => axis_to_reg_tdata,
      S_TVALID => axis_to_reg_tvalid,
      S_TLAST  => axis_to_reg_tlast,
      S_TUSER  => axis_to_reg_tuser,
      S_TSTRB  => axis_to_reg_tstrb,
      S_TKEEP  => axis_to_reg_tkeep,
      S_TID    => axis_to_reg_tid,
      S_TDEST  => axis_to_reg_tdest,
      S_TREADY => axis_to_reg_tready,
      -- axi4-stream slave
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
