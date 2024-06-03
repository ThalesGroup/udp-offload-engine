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

----------------------------------
--       AXIS_FIFO
----------------------------------
-- First In First Out structure Generator
-----------
-- The entity is parametrizable in data width
-- The entity is parametrizable in addr width (FIFO depth)
-- The entity is parametrizable in synchronization stage number (for cdc)
-- The entity is parametrizable in reset polarity (active 1 or active 0) and mode (synchronous/asynchronous)
-- The entity is parametrizable in clock domain (optimization are made for common clocks)
--
-- Slave reset is synchronous to slave clock domain
-- An internal master reset for the master clock domain is generated inside the module
--
-- This entity is a pure renaming of ports for the FIFO_GEN
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.cdc_utils_pkg.all;

use common.memory_utils_pkg.fifo_gen;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity axis_fifo is
  generic (
    G_COMMON_CLK  : boolean                         := false; -- 2 or 1 clock domain
    G_ADDR_WIDTH  : positive                        := 10; -- FIFO address width (depth is 2**ADDR_WIDTH)
    G_TDATA_WIDTH : positive                        := 32; -- Width of the tdata vector of the stream
    G_TUSER_WIDTH : positive                        := 1; -- Width of the tuser vector of the stream
    G_TID_WIDTH   : positive                        := 1; -- Width of the tid vector of the stream
    G_TDEST_WIDTH : positive                        := 1; -- Width of the tdest vector of the stream
    G_PKT_WIDTH   : natural                         := 0; -- Width of the packet counters in FIFO in packet mode (0 to disable)
    G_RAM_STYLE   : string                          := "AUTO"; -- Specify the ram synthesis style (technology dependant)
    G_ACTIVE_RST  : std_logic                       := '1'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean                         := false; -- Type of reset used (synchronous or asynchronous resets)
    G_SYNC_STAGE  : integer range 2 to integer'high := 2 -- Number of synchronization stages (to reduce MTBF)
  );
  port (
    -- axi4-stream slave
    S_CLK         : in  std_logic;                                     
    S_RST         : in  std_logic;                                     
    S_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0)             := (G_TDATA_WIDTH - 1 downto 0 => '-');                              
    S_TVALID      : in  std_logic;                 
    S_TLAST       : in  std_logic                                                := '-';                      
    S_TUSER       : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0)             := (G_TUSER_WIDTH - 1 downto 0 => '-');                 
    S_TSTRB       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (((G_TDATA_WIDTH + 7) / 8) - 1 downto 0 => '-');    
    S_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0) := (((G_TDATA_WIDTH + 7) / 8) - 1 downto 0 => '-');
    S_TID         : in  std_logic_vector(G_TID_WIDTH - 1 downto 0)               := (G_TID_WIDTH - 1 downto 0 => '-');                    
    S_TDEST       : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0)             := (G_TDEST_WIDTH - 1 downto 0 => '-');                  
    S_TREADY      : out std_logic;              
    -- axi4-stream slave
    M_CLK         : in  std_logic;
    M_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID      : out std_logic;
    M_TLAST       : out std_logic;
    M_TUSER       : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID         : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST       : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY      : in  std_logic                                                := '1';
    -- status
    WR_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);
    WR_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0);
    RD_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);
    RD_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0)
  );
end axis_fifo;

------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of axis_fifo is


  --------------------------------------------
  -- CONSTANTS
  --------------------------------------------
  -- indices for slicing the data vector
  constant C_TDATA_ILOW  : integer := 0;
  constant C_TDATA_IHIGH : integer := (G_TDATA_WIDTH - 1) + C_TDATA_ILOW;

  constant C_TUSER_ILOW  : integer := C_TDATA_IHIGH + 1;
  constant C_TUSER_IHIGH : integer := (G_TUSER_WIDTH - 1) + C_TUSER_ILOW;

  constant C_TID_ILOW  : integer := C_TUSER_IHIGH + 1;
  constant C_TID_IHIGH : integer := (G_TID_WIDTH - 1) + C_TID_ILOW;

  constant C_TDEST_ILOW  : integer := C_TID_IHIGH + 1;
  constant C_TDEST_IHIGH : integer := (G_TDEST_WIDTH - 1) + C_TDEST_ILOW;

  constant C_TSTRB_ILOW  : integer := C_TDEST_IHIGH + 1;
  constant C_TSTRB_IHIGH : integer := (((G_TDATA_WIDTH + 7) / 8) - 1) + C_TSTRB_ILOW;

  constant C_TKEEP_ILOW  : integer := C_TSTRB_IHIGH + 1;
  constant C_TKEEP_IHIGH : integer := (((G_TDATA_WIDTH + 7) / 8) - 1) + C_TKEEP_ILOW;

  constant C_TLAST_I : integer := C_TKEEP_IHIGH + 1;

  -- length of total data vector
  constant C_DATA_LENGTH : integer := C_TLAST_I + 1;

  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  -- aggregate of stream
  signal data_in       : std_logic_vector(C_DATA_LENGTH - 1 downto 0);
  signal data_out      : std_logic_vector(C_DATA_LENGTH - 1 downto 0);

  -- internal signals
  signal s_tready_int  : std_logic;
  signal m_tlast_int   : std_logic;
  signal m_tvalid_int  : std_logic;
  signal m_tready_int  : std_logic;

  signal fifo_wr_en    : std_logic;
  signal s_tready_data : std_logic;
  signal m_tvalid_data : std_logic;

begin

  --------------------------------------------
  -- ASSIGNMENTS
  --------------------------------------------
  -- aggregating fields
  data_in <= S_TLAST & S_TKEEP & S_TSTRB & S_TDEST & S_TID & S_TUSER & S_TDATA;

  -- slicing the output for port assignations
  M_TDATA     <= data_out(C_TDATA_IHIGH downto C_TDATA_ILOW);
  M_TUSER     <= data_out(C_TUSER_IHIGH downto C_TUSER_ILOW);
  M_TID       <= data_out(C_TID_IHIGH downto C_TID_ILOW);
  M_TDEST     <= data_out(C_TDEST_IHIGH downto C_TDEST_ILOW);
  M_TSTRB     <= data_out(C_TSTRB_IHIGH downto C_TSTRB_ILOW);
  M_TKEEP     <= data_out(C_TKEEP_IHIGH downto C_TKEEP_ILOW);
  m_tlast_int <= data_out(C_TLAST_I);

  --------------------------------------------
  -- GENERIC FIFO instantiation
  --------------------------------------------
  inst_fifo_gen: fifo_gen
    generic map(
      G_COMMON_CLK => G_COMMON_CLK,
      G_SHOW_AHEAD => true,
      G_ADDR_WIDTH => G_ADDR_WIDTH,
      G_DATA_WIDTH => C_DATA_LENGTH,
      G_RAM_STYLE  => G_RAM_STYLE,
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_SYNC_STAGE => G_SYNC_STAGE
    )
    port map(
      CLK_WR   => S_CLK,
      RST_WR   => S_RST,
      FULL     => open,
      FULL_N   => s_tready_data,
      WR_EN    => fifo_wr_en,
      WR_DATA  => data_in,
      WR_COUNT => WR_DATA_COUNT,
      CLK_RD   => M_CLK,
      EMPTY    => open,
      EMPTY_N  => m_tvalid_data,
      RD_EN    => m_tready_int,
      RD_DATA  => data_out,
      RD_COUNT => RD_DATA_COUNT
    );

  -- output assignment
  S_TREADY <= s_tready_int;
  M_TLAST  <= m_tlast_int;
  M_TVALID <= m_tvalid_int;

  -- No packet mode when G_MAX_PACKET = 0
  GEN_NO_PACKET_MODE: if G_PKT_WIDTH = 0 generate
    fifo_wr_en   <= S_TVALID;
    s_tready_int <= s_tready_data;      -- Data FIFO not full
    m_tvalid_int <= m_tvalid_data;      -- Data FIFO not empty
    m_tready_int <= M_TREADY;           -- M_TREADY not locked by packet mode

    WR_PKT_COUNT <= (others => '0');
    RD_PKT_COUNT <= (others => '0');
  end generate GEN_NO_PACKET_MODE;

  --------------------------------------------------------------------------------------------------
  -- Packet Mode
  --
  -- Received data are available on output only if a full frame (until TLAST) has been received
  --
  -- The input and output TLAST are counted separately (resp counter_wr counter_rd).
  -- * If the counters are different, the number of packet in the FIFO is smaller than G_MAX_PACKET or bigger than zero
  --   So new frame can be received (S_TREADY high) and sent (M_VALID high).
  -- * With a new received packet, if counter_wr become equal to counter_rd, the FIFO is full, in term of packets.
  --   S_TREADY goes low.
  -- * With a new read packet, if counter_rd become equal to counter_wr, the FIFO is empty, in term of packets.
  --   M_TVALID goes low
  --------------------------------------------------------------------------------------------------
  GEN_PACKET_MODE : if G_PKT_WIDTH > 0 generate

    --------------------------------------------
    -- SIGNALS
    --------------------------------------------
    -- reset
    signal m_rst           : std_logic;

    signal s_tready_packet : std_logic;
    signal m_valid_packet  : std_logic;

    signal ptr_rd_rclk     : unsigned(G_PKT_WIDTH - 1 downto 0);
    signal ptr_rd_wclk     : unsigned(G_PKT_WIDTH - 1 downto 0);
    signal ptr_wr_wclk     : unsigned(G_PKT_WIDTH - 1 downto 0);
    signal ptr_wr_rclk     : unsigned(G_PKT_WIDTH - 1 downto 0);

    signal ptr_wr_next     : unsigned(G_PKT_WIDTH - 1 downto 0);
    signal ptr_rd_next     : unsigned(G_PKT_WIDTH - 1 downto 0);

    signal pkt_wr_incr     : std_logic;
    signal pkt_rd_incr     : std_logic;
  
  begin

    -----------------------------------------------------------------------
    --
    -- Write clock domain
    --
    -----------------------------------------------------------------------

    fifo_wr_en <= S_TVALID and s_tready_int;

    -- Increment packet counter on last transaction
    pkt_wr_incr   <= S_TVALID and s_tready_int and S_TLAST;

    -- Next value of pointers
    ptr_wr_next <= ptr_wr_wclk + 1 when pkt_wr_incr = '1' else ptr_wr_wclk;

    -- Manage write counter and full flag
    proc_counter_wr: process(S_CLK, S_RST)
    begin
      -- Asynchronous reset
      if G_ASYNC_RST and (S_RST = G_ACTIVE_RST) then
        ptr_wr_wclk     <= (others => '0');
        s_tready_packet <= '1';
        WR_PKT_COUNT    <= (others => '0');
        
      elsif rising_edge(S_CLK) then
        -- synchronous reset
        if (not G_ASYNC_RST) and (S_RST = G_ACTIVE_RST) then
          ptr_wr_wclk     <= (others => '0');
          s_tready_packet <= '1';
          WR_PKT_COUNT    <= (others => '0');
          
        else

          WR_PKT_COUNT <= std_logic_vector(ptr_wr_next - ptr_rd_wclk);

          -- counter_wr increase with tlast
          if (pkt_wr_incr = '1') then
            ptr_wr_wclk <= ptr_wr_next;

            -- if the read and write counters become equals, the FIFO if full
            if (ptr_wr_next = ptr_rd_wclk) then
              s_tready_packet <= '0';
            else
              s_tready_packet <= '1';
            end if;

          -- if a read operation is performed (counter_rd increase), the FIFO is no more full
          elsif (ptr_wr_wclk /= ptr_rd_wclk) then
            s_tready_packet <= '1';
          end if;
        end if;
      end if;
    end process proc_counter_wr;

    -----------------------------------------------------------------------
    --
    -- Read clock domain
    --
    -----------------------------------------------------------------------

    pkt_rd_incr <= m_tvalid_int and M_TREADY and m_tlast_int;

    -- Increment pointer on read
    ptr_rd_next <= ptr_rd_rclk + 1 when pkt_rd_incr = '1' else ptr_rd_rclk;

    -- Manage read counter and empty flag
    proc_counter_rd: process(M_CLK, m_rst)
    begin
      if G_ASYNC_RST and (m_rst = G_ACTIVE_RST) then
        ptr_rd_rclk     <= (others => '0');
        m_valid_packet  <= '0';
        RD_PKT_COUNT    <= (others => '0');
      elsif rising_edge(M_CLK) then
        if (not G_ASYNC_RST) and (m_rst = G_ACTIVE_RST) then
          ptr_rd_rclk     <= (others => '0');
          m_valid_packet  <= '0';
          RD_PKT_COUNT    <= (others => '0');
        else

          RD_PKT_COUNT <= std_logic_vector(unsigned(ptr_wr_rclk) - unsigned(ptr_rd_next));

          -- counter_rd increase with tlast
          if (pkt_rd_incr = '1') then
            
            ptr_rd_rclk <= ptr_rd_next;

            -- if the read and write counters become equals, the FIFO if empty
            if (ptr_rd_next = ptr_wr_rclk) then
              m_valid_packet <= '0';
            else
              m_valid_packet <= '1';
            end if;

          -- if a write operation is performed (counter_wr increase), the FIFO is no more full
          elsif (ptr_rd_rclk /= ptr_wr_rclk) then
            m_valid_packet <= '1';
          end if;
        end if;
      end if;
    end process proc_counter_rd;

    -- Control S_TREADY signal
    s_tready_int <= s_tready_data        -- Data FIFO not full
                    and s_tready_packet; -- Not maximum number of packet

    -- Control M_TVALID signal
    m_tvalid_int <= m_tvalid_data        -- Data FIFO not empty
                    and m_valid_packet; -- At least one packet

    -- Control M_TREADY signal to avoid reading FIFO too early
    m_tready_int <= M_TREADY            -- Associated slave ready
                    and m_valid_packet; -- At least one packet

    --------------------------------------------
    -- No resynchronization
    --------------------------------------------
    GEN_NO_RESYNC: if G_COMMON_CLK generate
      
      -- Reset
      m_rst <= S_RST;
      
      -- Direct assignment
      -- From Write
      ptr_wr_rclk <= ptr_wr_wclk;
      
      -- From Read
      ptr_rd_wclk <= ptr_rd_next;
      
    end generate GEN_NO_RESYNC;

    --------------------------------------------
    -- Pointer resychronization
    --------------------------------------------
    GEN_RESYNC: if G_COMMON_CLK = false generate

      -- Resets
      signal rst_resync       : std_logic;
      signal rst_resync_n     : std_logic;

      -- Signals for type conversion to map to cdc components
      signal ptr_wr_wclk_slv  : std_logic_vector(G_PKT_WIDTH - 1 downto 0);
      signal ptr_rd_rclk_slv  : std_logic_vector(G_PKT_WIDTH - 1 downto 0);
      signal ptr_wr_rclk_slv  : std_logic_vector(G_PKT_WIDTH - 1 downto 0);
      signal ptr_rd_wclk_slv  : std_logic_vector(G_PKT_WIDTH - 1 downto 0);

    begin

      -- Generate master reset via resynchronization from the slave reset
      inst_cdc_reset_sync: cdc_reset_sync
        generic map (
          G_NB_STAGE    => G_SYNC_STAGE,
          G_NB_CLOCK    => 1,
          G_ACTIVE_ARST => G_ACTIVE_RST
        )
        port map (
          ARST          => S_RST,
          CLK(0)        => M_CLK,
          SRST(0)       => rst_resync,
          SRST_N(0)     => rst_resync_n
        );

      -- Choose the correct reset polarity
      m_rst <= rst_resync when G_ACTIVE_RST = '1' else rst_resync_n;


      -- Convert to std_logic_vector
      ptr_wr_wclk_slv <= std_logic_vector(ptr_wr_wclk);
      ptr_rd_rclk_slv <= std_logic_vector(ptr_rd_rclk);
    
      -- Convert write counter in read clock domain
      inst_cdc_gray_sync_counter_wr: cdc_gray_sync
        generic map (
          G_NB_STAGE   => G_SYNC_STAGE,
          G_REG_OUTPUT => false,
          G_ACTIVE_RST => G_ACTIVE_RST,
          G_ASYNC_RST  => G_ASYNC_RST,
          G_DATA_WIDTH => G_PKT_WIDTH
        )
        port map (
          CLK_SRC      => S_CLK,
          RST_SRC      => S_RST,
          DATA_SRC     => ptr_wr_wclk_slv,
          CLK_DST      => M_CLK,
          RST_DST      => m_rst,
          DATA_DST     => ptr_wr_rclk_slv
        );

      -- Convert read counter in write clock domain
      inst_cdc_gray_sync_counter_rd: cdc_gray_sync
        generic map (
          G_NB_STAGE   => G_SYNC_STAGE,
          G_REG_OUTPUT => false,
          G_ACTIVE_RST => G_ACTIVE_RST,
          G_ASYNC_RST  => G_ASYNC_RST,
          G_DATA_WIDTH => G_PKT_WIDTH
        )
        port map (
          CLK_SRC      => M_CLK,
          RST_SRC      => m_rst,
          DATA_SRC     => ptr_rd_rclk_slv,
          CLK_DST      => S_CLK,
          RST_DST      => S_RST,
          DATA_DST     => ptr_rd_wclk_slv
        );

      -- Convert from std_logic_vector
      ptr_wr_rclk        <= unsigned(ptr_wr_rclk_slv);
      ptr_rd_wclk        <= unsigned(ptr_rd_wclk_slv);

    end generate GEN_RESYNC;

  end generate GEN_PACKET_MODE;


end rtl;
