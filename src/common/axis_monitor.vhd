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
--        AXIS_MONITOR
--
------------------------------------------------
-- AXI4-Stream monitor
------------------------------
-- This module is used to monitor an AXI4-Stream interface and
-- detect protocol violations.
--
-- When TREADY or TVALID is low, a counter will
-- increament until it reaches the value configured by the user.
-- When the value is reached, a pulse is generated 
-- to indicate a timeout error.
--
-- The module is also used to check the stability of other
-- AXI4-Stream signals (TVALID, TDATA, TLAST, TKEEP, TSTRB, TUSER, TID, TDEST).
-- If the value of this signals change when TVALID is high but TREADY is low,
-- a pulse is generated to indicate an error for the signal who changed.
------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.axis_utils_pkg.all;

use common.datatest_tools_pkg.all;

entity axis_monitor is
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
    -- Input ports
    S_TREADY            : in  std_logic;
    S_TVALID            : in  std_logic;
    S_TDATA             : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TLAST             : in  std_logic;
    S_TKEEP             : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TSTRB             : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TUSER             : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TID               : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST             : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    --Configuration ports
    ENABLE              : in  std_logic;
    TIMEOUT_VALUE       : in  std_logic_vector(G_TIMEOUT_WIDTH - 1 downto 0);             -- Maximum value allowed without receiving or sending any data
    TIMEOUT_READY_ERROR : out std_logic;                                                  -- When asserted, indicate that time allowed to wait for the ready signal is high is over
    TIMEOUT_VALID_ERROR : out std_logic;                                                  -- When asserted, indicate that time allowed to wait for data is over
    VALID_ERROR         : out std_logic;                                                  -- When asserted, indicate the value of TVALID changed without handshake processus
    DATA_ERROR          : out std_logic;                                                  -- When asserted, indicate the value of TDATA changed without handshake processus
    LAST_ERROR          : out std_logic;                                                  -- When asserted, indicate the value of TLAST changed without handshake processus
    KEEP_ERROR          : out std_logic;                                                  -- When asserted, indicate the value of TKEEP changed without handshake processus
    STRB_ERROR          : out std_logic;                                                  -- When asserted, indicate the value of TSTRB changed without handshake processus
    USER_ERROR          : out std_logic;                                                  -- When asserted, indicate the value of TUSER changed without handshake processus
    ID_ERROR            : out std_logic;                                                  -- When asserted, indicate the value of TID changed without handshake processus
    DEST_ERROR          : out std_logic                                                   -- When asserted, indicate the value of TDEST changed without handshake processus
  );
end axis_monitor;

architecture rtl of axis_monitor is

  --------------------------------------------------------------------
  -- Signal declaration
  --------------------------------------------------------------------
  -- To count time spent without a new data transfer
  signal cnt_timeout_ready : unsigned(G_TIMEOUT_WIDTH - 1 downto 0);
  signal cnt_timeout_valid : unsigned(G_TIMEOUT_WIDTH - 1 downto 0);

  -- To register input
  signal tvalid_r : std_logic;
  signal tdata_r  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal tlast_r  : std_logic;
  signal tkeep_r  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal tstrb_r  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  signal tuser_r  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal tid_r    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
  signal tdest_r  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);

  -- To enable check input value
  signal chk_input : std_logic;

begin

  --===================================
  -- TIMEOUT MANAGEMENT
  --===================================
  P_TIMEOUT : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      cnt_timeout_ready   <= (others => '0');
      cnt_timeout_valid   <= (others => '0');
      tvalid_r            <= '0';
      tdata_r             <= (others => '0');
      tlast_r             <= '0';
      tkeep_r             <= (others => '0');
      tstrb_r             <= (others => '0');
      tuser_r             <= (others => '0');
      tid_r               <= (others => '0');
      tdest_r             <= (others => '0');
      chk_input           <= '0';
      TIMEOUT_READY_ERROR <= '0';
      TIMEOUT_VALID_ERROR <= '0';
      VALID_ERROR         <= '0';
      DATA_ERROR          <= '0';
      LAST_ERROR          <= '0';
      KEEP_ERROR          <= '0';
      STRB_ERROR          <= '0';
      USER_ERROR          <= '0';
      ID_ERROR            <= '0';
      DEST_ERROR          <= '0';
    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        cnt_timeout_ready   <= (others => '0');
        cnt_timeout_valid   <= (others => '0');
        tvalid_r            <= '0';
        tdata_r             <= (others => '0');
        tlast_r             <= '0';
        tkeep_r             <= (others => '0');
        tstrb_r             <= (others => '0');
        tuser_r             <= (others => '0');
        tid_r               <= (others => '0');
        tdest_r             <= (others => '0');
        chk_input           <= '0';
        TIMEOUT_READY_ERROR <= '0';
        TIMEOUT_VALID_ERROR <= '0';
        VALID_ERROR         <= '0';
        DATA_ERROR          <= '0';
        LAST_ERROR          <= '0';
        KEEP_ERROR          <= '0';
        STRB_ERROR          <= '0';
        USER_ERROR          <= '0';
        ID_ERROR            <= '0';
        DEST_ERROR          <= '0';
      else

        -- Default values for signals
        TIMEOUT_READY_ERROR <= '0';
        TIMEOUT_VALID_ERROR <= '0';
        VALID_ERROR         <= '0';
        DATA_ERROR          <= '0';
        LAST_ERROR          <= '0';
        KEEP_ERROR          <= '0';
        STRB_ERROR          <= '0';
        USER_ERROR          <= '0';
        ID_ERROR            <= '0';
        DEST_ERROR          <= '0';

        if (ENABLE = '0') then
          cnt_timeout_ready <= unsigned(TIMEOUT_VALUE);
          cnt_timeout_valid <= unsigned(TIMEOUT_VALUE);

        -- Module starts only when ENABLE = '1'
        else

          ---------------------
          -- Timeout
          ---------------------
          -- When value of TIMEOUT is 0, we don't care of timeout
          if (to_integer(unsigned(TIMEOUT_VALUE)) = 0) then
            TIMEOUT_READY_ERROR <= '0';
            TIMEOUT_VALID_ERROR <= '0';
          else
            
            -- We initialize counters with value in TIMEOUT_VALUE
            cnt_timeout_ready <= unsigned(TIMEOUT_VALUE);
            cnt_timeout_valid <= unsigned(TIMEOUT_VALUE);
              
            -- We reinitialize counter when a transfer occured
            if (S_TREADY = '1') and (S_TVALID = '1') then
              cnt_timeout_ready <= unsigned(TIMEOUT_VALUE);
              cnt_timeout_valid <= unsigned(TIMEOUT_VALUE);
            end if;

            -- When TREADY and TVALID are both low, it's considered like being a normal behavior (the module monitored is disable)
            -- Timeout check for TREADY
            if (S_TREADY = '0') and (S_TVALID = '1') then
              if (cnt_timeout_ready /= 0) then
                cnt_timeout_ready <= cnt_timeout_ready - 1;
              end if;
            end if;

            if (cnt_timeout_ready = 1) then
              -- Error is 1 when the timeout value is reached
              TIMEOUT_READY_ERROR <= '1';
            end if;

            -- Timeout check for TVALID
            if (S_TREADY = '1') and (S_TVALID = '0') then
              if (cnt_timeout_valid /= 0) then
                cnt_timeout_valid <= cnt_timeout_valid - 1;
              end if;

              if (cnt_timeout_valid = 1) then
                -- Error is 1 when the timeout value is reached
                TIMEOUT_VALID_ERROR <= '1';
              end if;
            end if;
          end if;

          ---------------------
          -- Stability
          ---------------------
          -- We register the value of input signals when a data is valid but not acknowledged
          -- The data must not change until TREADY is high
          if (S_TREADY = '0') and (S_TVALID = '1') then
            tvalid_r <= S_TVALID;
            tdata_r  <= S_TDATA;
            tlast_r  <= S_TLAST;
            tkeep_r  <= S_TKEEP;
            tstrb_r  <= S_TSTRB;
            tuser_r  <= S_TUSER;
            tid_r    <= S_TID;
            tdest_r  <= S_TDEST;
          end if;

          -- When a valid data is acknowledged, it's useless to compare the next data with the one saved because the data saved is out of date
          if (S_TREADY = '1') and (S_TVALID = '1') then
            chk_input <= '0';
          else
            -- In case we have a valid data but not acknowledge and the comparison is disable, that means it's the first valid data after a data acknowledged
            -- So this data is not compared with the one previously saved
            -- And we enable the data comparison for the next valid data
            if (S_TVALID = '1') and (chk_input = '0') then
              chk_input <= '1';
            end if;
          end if;

          -- When the data comparison is allowed, we check if the data received is equal than the one saved
          if (chk_input = '1') then
            -- Check VALID
            if (S_TVALID /= tvalid_r) then
              VALID_ERROR       <= '1';
              cnt_timeout_ready <= unsigned(TIMEOUT_VALUE);
              cnt_timeout_valid <= unsigned(TIMEOUT_VALUE);
              tvalid_r          <= S_TVALID;
            end if;
            -- Check DATA
            if (S_TDATA /= tdata_r) then
              DATA_ERROR <= '1';
            end if;
            --Check LAST
            if (S_TLAST /= tlast_r) then
              LAST_ERROR <= '1';
            end if;
            -- Check KEEP
            if (S_TKEEP /= tkeep_r) then                                                  --@suppress PR5 : sizes are the same
              KEEP_ERROR <= '1';
            end if;
            -- Check STRB
            if (S_TSTRB /= tstrb_r) then                                                  --@suppress PR5 : sizes are the same
              STRB_ERROR <= '1';
            end if;
            -- Check USER
            if (S_TUSER /= tuser_r) then
              USER_ERROR <= '1';
            end if;
            -- Check ID
            if (S_TID /= tid_r) then
              ID_ERROR <= '1';
            end if;
            -- Check DEST
            if (S_TDEST /= tdest_r) then
              DEST_ERROR <= '1';
            end if;
          end if;
        end if;

      end if;
    end if;

  end process P_TIMEOUT;

end rtl;
