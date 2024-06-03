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
-- AXIS_REGISTER
--
----------------------------------------------------------------------------------
-- This component introduce a register slice on a AXI-Stream data bus so as to break
-- timing dependencies
----------
-- The entity is generic in data width and other signals of AXI-Stream.
--
-- If the forward path is registered, a simple register is introduced. This mode implements a
-- number of flip flops equal to the width of the input data (as a normal register would do)
--
-- If the backward path is registered, a skid register structure is produced. A simple register
-- is produced for the back-pressure, and a register is also used for the forward data. Input data
-- are then muxed with the forward buffer.
--
-- Thus when both mode are activated, this register produced roughly twice more FF than signals.
--
-- If full bandwidth is deactivated, then the backward path doesn't use a skid buffer structure
-- but deactivate the TREADY for one cycle, thus limiting the bandwidth to 50 % of the maximum rate.
--------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity axis_register is
  generic(
    G_ACTIVE_RST     : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST      : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH    : positive  := 32;   -- Width of the tdata vector of the stream
    G_TUSER_WIDTH    : positive  := 1;    -- Width of the tuser vector of the stream
    G_TID_WIDTH      : positive  := 1;    -- Width of the tid vector of the stream
    G_TDEST_WIDTH    : positive  := 1;    -- Width of the tdest vector of the stream
    G_REG_FORWARD    : boolean   := true; -- Whether to register the forward path (tdata, tvalid and others)
    G_REG_BACKWARD   : boolean   := true; -- Whether to register the backward path (tready)
    G_FULL_BANDWIDTH : boolean   := true  -- Whether the full bandwidth is reachable
  );
  port(
    -- GLOBAL
    CLK      : in  std_logic;           -- Clock
    RST      : in  std_logic;           -- Reset
    -- Axi4-stream slave
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TUSER  : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID    : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST  : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY : out std_logic;
    -- Axi4-stream master
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
end axis_register;


architecture rtl of axis_register is

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
  -- Constants declaration
  --------------------------------------------------------------------

  -- Constant for record initialization
  constant C_FORWARD_DATA_INIT : t_forward_data := (
    tdata  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tlast  => '0',                      -- Could be anything because the tvalid signal is 0
    tuser  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tstrb  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tid    => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tdest  => (others => '0'),          -- Could be anything because the tvalid signal is 0
    tvalid => '0'                       -- Data are not valid at initialization
  );

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- Axis bus at input
  signal s_int        : t_forward_data;
  signal s_tready_int : std_logic;

  -- Axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  -- Axis bus at output
  signal m_int        : t_forward_data;
  signal m_tready_int : std_logic;

begin

  -- Connect input bus to the records
  s_int.tdata  <= S_TDATA;
  s_int.tlast  <= S_TLAST;
  s_int.tuser  <= S_TUSER;
  s_int.tstrb  <= S_TSTRB;
  s_int.tkeep  <= S_TKEEP;
  s_int.tid    <= S_TID;
  s_int.tdest  <= S_TDEST;
  s_int.tvalid <= S_TVALID;
  S_TREADY     <= s_tready_int;

  -- Connect output bus to the records
  M_TDATA      <= m_int.tdata;
  M_TLAST      <= m_int.tlast;
  M_TUSER      <= m_int.tuser;
  M_TSTRB      <= m_int.tstrb;
  M_TKEEP      <= m_int.tkeep;
  M_TID        <= m_int.tid;
  M_TDEST      <= m_int.tdest;
  M_TVALID     <= m_int.tvalid;
  m_tready_int <= M_TREADY;


  -----------------------------------------------------
  --
  --   BACKWARD
  --
  -----------------------------------------------------


  -- Insert a register on backward path
  -- Generate a buffer and a mux on forward path (skid register structure)
  GEN_BACKWARD_FULL : if G_REG_BACKWARD and G_FULL_BANDWIDTH generate
    -- Buffer register for skid structure
    signal buff : t_forward_data;

  begin

    ----------------------
    -- SYNC_SKID_REG
    ----------------------
    -- Synchronous process to buffer forward data
    -- and register the backward path
    ----------------------
    SYNC_SKID_REG : process(CLK, RST) is
    begin
      if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
        -- Asynchronous reset
        buff         <= C_FORWARD_DATA_INIT;
        s_tready_int <= '0';

      elsif rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          -- Synchronous reset
          buff         <= C_FORWARD_DATA_INIT;
          s_tready_int <= '0';

        else

          -- Bufferize data (skid register)
          if s_tready_int = '1' then
            -- May acquire new data
            if s_int.tvalid = '1' then
              -- Bufferize the bus when data are valid
              buff <= s_int;
            else
              -- Change only the valid state to avoid logic toggling (and save power)
              buff.tvalid <= '0';
            end if;
          end if;

          -- Register: ready when downstream is ready or no data are valid
          s_tready_int <= mid_tready or (not mid.tvalid);

        end if;
      end if;
    end process SYNC_SKID_REG;

    -- Assign the middle layer with a mux
    mid <= s_int when s_tready_int = '1' else buff;

  end generate GEN_BACKWARD_FULL;

  -- Insert a register on backward path
  -- Nothing on forward path
  GEN_BACKWARD_LIGHT : if G_REG_BACKWARD and (not G_FULL_BANDWIDTH) generate
  begin

    ----------------------
    -- SYNC_BACKWARD_REG
    ----------------------
    -- Synchronous process to register the backward path
    ----------------------
    SYNC_BACKWARD_REG : process(CLK, RST) is
    begin
      if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
        -- Asynchronous reset
        s_tready_int <= '0';

      elsif rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          -- Synchronous reset
          s_tready_int <= '0';

        else

          -- Register: ready if downstream is ready on a transaction
          s_tready_int <= mid_tready and mid.tvalid;

        end if;
      end if;
    end process SYNC_BACKWARD_REG;

    -- Assign the middle layer directly with a mask on TVALID
    -- if not ready.
    -- No violation of protocol can occur, because the TVALID
    -- is forced low only after a previous transaction,
    -- so downstream has never seen it up.
    ASYNC_FORWARD_MASK: process(s_int, s_tready_int) is
    begin
      -- Assign all bus
      mid        <= s_int;
      -- Mask the TVALID
      mid.tvalid <= s_int.tvalid and (not s_tready_int);
    end process ASYNC_FORWARD_MASK;

  end generate GEN_BACKWARD_LIGHT;


  -- Do not register the backward path
  GEN_NO_BACKWARD : if not G_REG_BACKWARD generate
    -- Direct connection to middle layer
    mid          <= s_int;
    s_tready_int <= mid_tready;
  end generate GEN_NO_BACKWARD;


  -----------------------------------------------------
  --
  --   FORWARD
  --
  -----------------------------------------------------


  -- Generate a register on forward path
  GEN_FORWARD : if G_REG_FORWARD generate

    -- Asynchonous: ready when downstream is ready or no data are valid
    mid_tready <= m_tready_int or (not m_int.tvalid);

    ----------------------
    -- SYNC_FORWARD_REG
    ----------------------
    -- Synchronous process to register the different signals on the forward path
    ----------------------
    SYNC_FORWARD_REG : process(CLK, RST) is
    begin
      if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
        -- Asynchronous reset
        m_int <= C_FORWARD_DATA_INIT;

      elsif rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          -- Synchronous reset
          m_int <= C_FORWARD_DATA_INIT;

        else

          -- Register
          if mid_tready = '1' then
            -- May acquire new data
            if mid.tvalid = '1' then
              -- Register the bus when data are valid
              m_int <= mid;
            else
              -- Change only valid state to avoid logic toggling (and save power)
              m_int.tvalid <= '0';
            end if;
          end if;

        end if;
      end if;
    end process SYNC_FORWARD_REG;
  end generate GEN_FORWARD;


  -- Do not generate a register on forward path
  GEN_NO_FORWARD : if not G_REG_FORWARD generate
    -- Direct connection from middle layer
    m_int      <= mid;
    mid_tready <= m_tready_int;
  end generate GEN_NO_FORWARD;

end rtl;
