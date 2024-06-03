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
--        AXIS_PKT_CHK
--
------------------------------------------------
-- AXI4-Stream packet checker
------------------------------
-- This module is used to test other module by checking AXI4-Stream signals
-- of each AXI4-Stream interface
-- 
-- It checks TDATA, TKEEP, TSTRB, TUSER, TDEST and TID buses.
-- It checks TLAST signal.
-- 
------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.axis_utils_pkg.axis_combine;

use common.datatest_tools_pkg.all;

entity axis_pkt_chk is
  generic(
    G_ASYNC_RST   : boolean   := false;
    G_ACTIVE_RST  : std_logic := '1';
    G_TDATA_WIDTH : positive  := 64;                                                      -- Data bus size
    G_TUSER_WIDTH : positive  := 1;                                                       -- User bus size
    G_TDEST_WIDTH : positive  := 1;                                                       -- Dest bus size
    G_TID_WIDTH   : positive  := 1                                                        -- ID bus size
  );
  port(
    CLK       : in  std_logic;
    RST       : in  std_logic;
    -- Input ports for interface 0
    S0_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S0_TVALID : in  std_logic;
    S0_TLAST  : in  std_logic;
    S0_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S0_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S0_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S0_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S0_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S0_TREADY : out std_logic;
    -- Input ports for interface 1
    S1_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S1_TVALID : in  std_logic;
    S1_TLAST  : in  std_logic;
    S1_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S1_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S1_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S1_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S1_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S1_TREADY : out std_logic;
    -- Error ports
    ERR_DATA  : out std_logic;                                                            -- Indicate a difference in data between the two interfaces
    ERR_LAST  : out std_logic;                                                            -- Indicate a difference on tlast between the two interfaces
    ERR_KEEP  : out std_logic;                                                            -- Indicate a difference on tkeep between the two interfaces
    ERR_STRB  : out std_logic;                                                            -- Indicate a difference on tstrb between the two interfaces
    ERR_USER  : out std_logic;                                                            -- Indicate a difference on tuser between the two interfaces
    ERR_DEST  : out std_logic;                                                            -- Indicate a difference on tdest between the two interfaces
    ERR_ID    : out std_logic                                                             -- Indicate a difference on tid between the two interfaces
  );
end axis_pkt_chk;

architecture rtl of axis_pkt_chk is

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------
  -- Signals after comparaison
  signal s_tdata : std_logic_vector(0 downto 0);
  signal s_tlast : std_logic;
  signal s_tuser : std_logic_vector(0 downto 0);
  signal s_tkeep : std_logic_vector(0 downto 0);
  signal s_tstrb : std_logic_vector(0 downto 0);
  signal s_tid   : std_logic_vector(0 downto 0);
  signal s_tdest : std_logic_vector(0 downto 0);

  -- AXIS output of axis_combine
  signal m_tvalid : std_logic;
  signal m_tdata  : std_logic_vector(0 downto 0);
  signal m_tlast  : std_logic;
  signal m_tkeep  : std_logic_vector(0 downto 0);
  signal m_tstrb  : std_logic_vector(0 downto 0);
  signal m_tuser  : std_logic_vector(0 downto 0);
  signal m_tdest  : std_logic_vector(0 downto 0);
  signal m_tid    : std_logic_vector(0 downto 0);

begin

  --===================================
  -- INPUT
  --===================================
  -- Comparaison of input signals
  -- If the two buses are the the same there is no difference so we put the signal at 0
  -- The idea is to use one bit for each signal to reduce resources in axis_combine
  s_tdata <= "0" when (S0_TDATA = S1_TDATA) else "1";
  s_tlast <= '0' when (S0_TLAST = S1_TLAST) else '1';
  s_tuser <= "0" when (S0_TUSER = S1_TUSER) else "1";
  s_tkeep <= "0" when (S0_TKEEP = S1_TKEEP) else "1";                                     --@suppress PR5 : size will be the same
  s_tstrb <= "0" when (S0_TSTRB = S1_TSTRB) else "1";                                     --@suppress PR5 : size will be the same
  s_tid   <= "0" when (S0_TID = S1_TID) else "1";
  s_tdest <= "0" when (S0_TDEST = S1_TDEST) else "1";

  -- To combine the two flow in one
  inst_axis_combine : axis_combine
    generic map(
      G_ACTIVE_RST       => G_ACTIVE_RST,
      G_ASYNC_RST        => G_ASYNC_RST,
      G_TDATA_WIDTH      => 1,
      G_TUSER_WIDTH      => 1,
      G_TID_WIDTH        => 1,
      G_TDEST_WIDTH      => 1,
      G_NB_SLAVE         => 2,
      G_REG_OUT_FORWARD  => true,
      G_REG_OUT_BACKWARD => false
    )
    port map(
      CLK         => CLK,
      RST         => RST,
      S_TDATA     => s_tdata,
      S_TVALID(1) => S1_TVALID,
      S_TVALID(0) => S0_TVALID,
      S_TLAST     => s_tlast,
      S_TUSER     => s_tuser,
      S_TSTRB     => s_tstrb,
      S_TKEEP     => s_tkeep,
      S_TID       => s_tid,
      S_TDEST     => s_tdest,
      S_TREADY(1) => S1_TREADY,
      S_TREADY(0) => S0_TREADY,
      M_TDATA     => m_tdata,
      M_TVALID    => m_tvalid,
      M_TLAST     => m_tlast,
      M_TUSER     => m_tuser,
      M_TSTRB     => m_tstrb,
      M_TKEEP     => m_tkeep,
      M_TID       => m_tid,
      M_TDEST     => m_tdest,
      M_TREADY    => '1'
    );

  --===================================
  -- CHECK FLOW
  --===================================
  P_CHECK_FLOW : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      ERR_DATA <= '0';
      ERR_LAST <= '0';
      ERR_KEEP <= '0';
      ERR_STRB <= '0';
      ERR_USER <= '0';
      ERR_DEST <= '0';
      ERR_ID   <= '0';
    else
      if rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          ERR_DATA <= '0';
          ERR_LAST <= '0';
          ERR_KEEP <= '0';
          ERR_STRB <= '0';
          ERR_USER <= '0';
          ERR_DEST <= '0';
          ERR_ID   <= '0';
        else

          ERR_DATA <= '0';
          ERR_LAST <= '0';
          ERR_KEEP <= '0';
          ERR_STRB <= '0';
          ERR_USER <= '0';
          ERR_DEST <= '0';
          ERR_ID   <= '0';

          -- When there is a valid transaction, the process compare each signal
          -- If there is a 1 on the signal, there is a difference between interfaces
          if (m_tvalid = '1') then
            -- Check TDATA
            if (m_tdata = "1") then
              ERR_DATA <= '1';
            end if;

            -- Check TLAST
            if (m_tlast = '1') then
              ERR_LAST <= '1';
            end if;

            -- Check TKEEP
            if (m_tkeep = "1") then
              ERR_KEEP <= '1';
            end if;

            -- Check TSTRB
            if (m_tstrb = "1") then
              ERR_STRB <= '1';
            end if;

            -- Check TUSER
            if (m_tuser = "1") then
              ERR_USER <= '1';
            end if;

            -- Check TDEST
            if (m_tdest = "1") then
              ERR_DEST <= '1';
            end if;

            -- Check TID
            if (m_tid = "1") then
              ERR_ID <= '1';
            end if;

          end if;

        end if;
      end if;
    end if;

  end process P_CHECK_FLOW;

end rtl;
