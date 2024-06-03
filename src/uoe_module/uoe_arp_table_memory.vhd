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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

----------------------------------
-- ARP TABLE MEMORY
----------------------------------
--
-- This module define a table used to keep in memory until 256 couples of IP/MAC address
--
----------------------------------

library common;
use common.memory_utils_pkg.true_dp_ram;

use common.axi4lite_utils_pkg.axi4lite_sp_ram_ctrl;

use work.uoe_module_pkg.all;

------------------------------------------------------------------------
-- Entity ARP_TABLE_MEMORY
------------------------------------------------------------------------
entity uoe_arp_table_memory is
  generic(
    G_ACTIVE_RST : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true    -- Type of reset used (synchronous or asynchronous resets)
  );
  port(
    -- Clocks and resets
    CLK                    : in  std_logic;
    RST                    : in  std_logic;
    -- Interface with arp table (Read data)
    S_MEM_RD_IP_TDATA      : in  std_logic_vector(31 downto 0);
    S_MEM_RD_IP_TVALID     : in  std_logic;
    S_MEM_RD_IP_TREADY     : out std_logic;
    M_MEM_RD_MAC_TDATA     : out std_logic_vector(47 downto 0);
    M_MEM_RD_MAC_TUSER     : out std_logic_vector(0 downto 0); -- Validity of the return MAC Addr : 0 --> OK, 1 --> KO
    M_MEM_RD_MAC_TVALID    : out std_logic;
    M_MEM_RD_MAC_TREADY    : in  std_logic;
    -- Interface with arp table (Write data)
    S_MEM_WR_IP_MAC_TDATA  : in  std_logic_vector(79 downto 0); -- Bits 79..32 is MAC Addr. and bits 31..0 is IP Addr.
    S_MEM_WR_IP_MAC_TVALID : in  std_logic;
    S_MEM_WR_IP_MAC_TREADY : out std_logic;
    -- Ctrl/Status
    CLEAR_ARP              : in  std_logic;
    CLEAR_ARP_DONE         : out std_logic;
    -- AXI4-Lite interface to ARP Table (used for debug)
    S_AXI_AWADDR           : in  std_logic_vector(11 downto 0);
    S_AXI_AWVALID          : in  std_logic;
    S_AXI_AWREADY          : out std_logic;
    S_AXI_WDATA            : in  std_logic_vector(31 downto 0);
    S_AXI_WVALID           : in  std_logic;
    S_AXI_WREADY           : out std_logic;
    S_AXI_BRESP            : out std_logic_vector(1 downto 0);
    S_AXI_BVALID           : out std_logic;
    S_AXI_BREADY           : in  std_logic;
    S_AXI_ARADDR           : in  std_logic_vector(11 downto 0);
    S_AXI_ARVALID          : in  std_logic;
    S_AXI_ARREADY          : out std_logic;
    S_AXI_RDATA            : out std_logic_vector(31 downto 0);
    S_AXI_RRESP            : out std_logic_vector(1 downto 0);
    S_AXI_RVALID           : out std_logic;
    S_AXI_RREADY           : in  std_logic
  );
end uoe_arp_table_memory;

architecture rtl of uoe_arp_table_memory is

  ---------------------------------------------------------------------
  -- Signals declaration
  ---------------------------------------------------------------------

  -- signals used to release tready after reset
  signal axis_init : std_logic;

  -- axis internal signals
  signal s_mem_rd_ip_tready_i     : std_logic;
  signal m_mem_rd_mac_tvalid_i    : std_logic;
  signal s_mem_wr_ip_mac_tready_i : std_logic;

  -- functionnal interface 
  signal ram_addr : std_logic_vector(7 downto 0);
  signal ram_din  : std_logic_vector(79 downto 0);
  signal ram_dout : std_logic_vector(79 downto 0);
  signal ram_wen  : std_logic;

  -- Debug interface
  signal axi_bram_en   : std_logic;
  signal axi_bram_addr : std_logic_vector(11 downto 0); -- in bytes 
  signal axi_bram_din  : std_logic_vector(31 downto 0);
  signal axi_bram_wren : std_logic_vector(3 downto 0);
  signal axi_bram_dout : std_logic_vector(31 downto 0);

  signal axi_brams_en   : std_logic_vector(2 downto 0);
  signal axi_brams_dout : std_logic_vector(79 downto 0);

  -- Signals declaration for CAM
  signal ip_addr_searched : std_logic_vector(31 downto 0); -- IP Addr. searched by MAC Shaping
  signal rd_req           : std_logic;
  signal rd_req_r         : std_logic_vector(1 downto 0);

  -- memorization of read request when concurent access RD/WR
  signal mem_rd_req  : std_logic;
  signal mem_rd_addr : std_logic_vector(7 downto 0);

  signal clear_arp_in_progress : std_logic;

begin

  -- Simple Port RAM Controller
  inst_axi4lite_sp_ram_ctrl : axi4lite_sp_ram_ctrl
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_AXI_DATA_WIDTH => 32,
      G_AXI_ADDR_WIDTH => 12,
      G_RD_LATENCY     => 2
    )
    port map(
      CLK           => CLK,
      RST           => RST,
      S_AXI_AWADDR  => S_AXI_AWADDR,
      S_AXI_AWPROT  => (others => '0'),
      S_AXI_AWVALID => S_AXI_AWVALID,
      S_AXI_AWREADY => S_AXI_AWREADY,
      S_AXI_WDATA   => S_AXI_WDATA,
      S_AXI_WSTRB   => (others => '1'),
      S_AXI_WVALID  => S_AXI_WVALID,
      S_AXI_WREADY  => S_AXI_WREADY,
      S_AXI_BRESP   => S_AXI_BRESP,
      S_AXI_BVALID  => S_AXI_BVALID,
      S_AXI_BREADY  => S_AXI_BREADY,
      S_AXI_ARADDR  => S_AXI_ARADDR,
      S_AXI_ARPROT  => (others => '0'),
      S_AXI_ARVALID => S_AXI_ARVALID,
      S_AXI_ARREADY => S_AXI_ARREADY,
      S_AXI_RDATA   => S_AXI_RDATA,
      S_AXI_RVALID  => S_AXI_RVALID,
      S_AXI_RRESP   => S_AXI_RRESP,
      S_AXI_RREADY  => S_AXI_RREADY,
      BRAM_EN       => axi_bram_en,
      BRAM_WREN     => axi_bram_wren,
      BRAM_ADDR     => axi_bram_addr,
      BRAM_DIN      => axi_bram_din,
      BRAM_DOUT     => axi_bram_dout
    );

  --============================================================================================--
  --===== Address Decoder for BRAMs (AXI4-Lite side) ===========================================--
  --============================================================================================--

  -- AXI ==> RAM : Enable Decoder
  p_ram_select : process(axi_bram_addr, axi_bram_en) is
  begin
    for I in 0 to 2 loop
      if (axi_bram_addr(11 downto 10) = std_logic_vector(to_unsigned(I, 2))) then
        axi_brams_en(I) <= axi_bram_en;
      else
        axi_brams_en(I) <= '0';
      end if;
    end loop;
  end process p_ram_select;

  -- RAM ==> AXI : Read Data Decoder
  -- for debugging, no need to register addr because concurrent acc�s should not be append
  axi_bram_dout <= axi_brams_dout(31 downto 0) when axi_bram_addr(11 downto 10) = "00"
                   else axi_brams_dout(63 downto 32) when axi_bram_addr(11 downto 10) = "01"
                   else (x"0000" & axi_brams_dout(79 downto 64)) when axi_bram_addr(11 downto 10) = "10"
                   else (others => '0');

  -----------------------------------------------------
  -- RAM to store IP/MAC couple
  -----------------------------------------------------

  inst_true_dp_ram_ip : true_dp_ram
    generic map(
      G_DATA_WIDTH     => 32,
      G_ADDR_WIDTH     => 8,
      G_OUT_REG_A      => false,
      G_OUT_REG_B      => false,
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_RAM_STYLE      => "BLOCK",
      G_MEM_INIT_FILE  => "",
      G_MEM_INIT_VALUE => '0'
    )
    port map(
      CLK_A  => CLK,
      RST_A  => RST,
      EN_A   => '1',
      ADDR_A => ram_addr,
      DIN_A  => ram_din(31 downto 0),
      WREN_A => ram_wen,
      DOUT_A => ram_dout(31 downto 0),
      CLK_B  => CLK,
      RST_B  => RST,
      EN_B   => axi_brams_en(0),
      ADDR_B => axi_bram_addr(9 downto 2),
      DIN_B  => axi_bram_din,
      WREN_B => axi_bram_wren(0),
      DOUT_B => axi_brams_dout(31 downto 0)
    );

  inst_true_dp_ram_lsb_mac : true_dp_ram
    generic map(
      G_DATA_WIDTH     => 32,
      G_ADDR_WIDTH     => 8,
      G_OUT_REG_A      => false,
      G_OUT_REG_B      => false,
      G_ACTIVE_RST     => '1',
      G_ASYNC_RST      => false,
      G_RAM_STYLE      => "BLOCK",
      G_MEM_INIT_FILE  => "",
      G_MEM_INIT_VALUE => '0'
    )
    port map(
      CLK_A  => CLK,
      RST_A  => RST,
      EN_A   => '1',
      ADDR_A => ram_addr,
      DIN_A  => ram_din(63 downto 32),
      WREN_A => ram_wen,
      DOUT_A => ram_dout(63 downto 32),
      CLK_B  => CLK,
      RST_B  => RST,
      EN_B   => axi_brams_en(1),
      ADDR_B => axi_bram_addr(9 downto 2),
      DIN_B  => axi_bram_din,
      WREN_B => axi_bram_wren(0),
      DOUT_B => axi_brams_dout(63 downto 32)
    );

  inst_true_dp_ram_msb_mac : true_dp_ram
    generic map(
      G_DATA_WIDTH     => 16,
      G_ADDR_WIDTH     => 8,
      G_OUT_REG_A      => false,
      G_OUT_REG_B      => false,
      G_ACTIVE_RST     => '1',
      G_ASYNC_RST      => false,
      G_RAM_STYLE      => "BLOCK",
      G_MEM_INIT_FILE  => "",
      G_MEM_INIT_VALUE => '0'
    )
    port map(
      CLK_A  => CLK,
      RST_A  => RST,
      EN_A   => '1',
      ADDR_A => ram_addr,
      DIN_A  => ram_din(79 downto 64),
      WREN_A => ram_wen,
      DOUT_A => ram_dout(79 downto 64),
      CLK_B  => CLK,
      RST_B  => RST,
      EN_B   => axi_brams_en(2),
      ADDR_B => axi_bram_addr(9 downto 2),
      DIN_B  => axi_bram_din(15 downto 0),
      WREN_B => axi_bram_wren(0),
      DOUT_B => axi_brams_dout(79 downto 64)
    );

  -- Affectations
  S_MEM_WR_IP_MAC_TREADY <= s_mem_wr_ip_mac_tready_i;
  S_MEM_RD_IP_TREADY     <= s_mem_rd_ip_tready_i;
  M_MEM_RD_MAC_TVALID    <= m_mem_rd_mac_tvalid_i;

  -- Process 
  PROCESS_MEM : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- AXIS interface
      axis_init                <= '1';
      s_mem_wr_ip_mac_tready_i <= '0';
      s_mem_rd_ip_tready_i     <= '0';
      M_MEM_RD_MAC_TDATA       <= (others => '0');
      M_MEM_RD_MAC_TUSER       <= (others => '0');
      m_mem_rd_mac_tvalid_i    <= '0';
      -- RAM Signals
      ram_addr                 <= (others => '0');
      ram_wen                  <= '0';
      ram_din                  <= (others => '0');
      -- Internal Signals
      ip_addr_searched         <= (others => '0');
      rd_req                   <= '0';
      rd_req_r                 <= (others => '0');
      mem_rd_req               <= '0';
      mem_rd_addr              <= (others => '0');
      -- Clear
      clear_arp_in_progress    <= '0';
      CLEAR_ARP_DONE           <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- AXIS interface
        axis_init                <= '1';
        s_mem_wr_ip_mac_tready_i <= '0';
        s_mem_rd_ip_tready_i     <= '0';
        M_MEM_RD_MAC_TDATA       <= (others => '0');
        M_MEM_RD_MAC_TUSER       <= (others => '0');
        m_mem_rd_mac_tvalid_i    <= '0';
        -- RAM Signals
        ram_addr                 <= (others => '0');
        ram_wen                  <= '0';
        ram_din                  <= (others => '0');
        -- Internal Signals
        ip_addr_searched         <= (others => '0');
        rd_req                   <= '0';
        rd_req_r                 <= (others => '0');
        mem_rd_req               <= '0';
        mem_rd_addr              <= (others => '0');
        -- Clear
        clear_arp_in_progress    <= '0';
        CLEAR_ARP_DONE           <= '0';
      else

        -- Default
        rd_req         <= '0';
        ram_wen        <= '0';
        CLEAR_ARP_DONE <= '0';

        --------------------------------
        -- WRITE
        --------------------------------
        if axis_init = '1' then
          s_mem_wr_ip_mac_tready_i <= '1';
        end if;

        -- Write received couple in ram
        if (S_MEM_WR_IP_MAC_TVALID = '1') and (s_mem_wr_ip_mac_tready_i = '1') then
          ram_addr <= (S_MEM_WR_IP_MAC_TDATA(31 downto 24) xor S_MEM_WR_IP_MAC_TDATA(23 downto 16)) xor (S_MEM_WR_IP_MAC_TDATA(15 downto 8) xor S_MEM_WR_IP_MAC_TDATA(7 downto 0));
          ram_din  <= S_MEM_WR_IP_MAC_TDATA;
          ram_wen  <= '1';
        end if;

        --------------------------------
        -- READ
        --------------------------------

        -- Assert tready when previous transaction response has been accepted
        if (m_mem_rd_mac_tvalid_i = '1') and (M_MEM_RD_MAC_TREADY = '1') then
          s_mem_rd_ip_tready_i <= '1';

        -- or after reset
        elsif axis_init = '1' then
          s_mem_rd_ip_tready_i <= '1';
          axis_init            <= '0';

        end if;

        -- Read access to memory (high priority)
        if (S_MEM_RD_IP_TVALID = '1') and (s_mem_rd_ip_tready_i = '1') then
          s_mem_rd_ip_tready_i <= '0';
          ip_addr_searched     <= S_MEM_RD_IP_TDATA; -- memorize IP addr

          -- if simultaneously write access, delayed read access
          if (S_MEM_WR_IP_MAC_TVALID = '1') and (s_mem_wr_ip_mac_tready_i = '1') then
            mem_rd_req  <= '1';
            mem_rd_addr <= (S_MEM_RD_IP_TDATA(31 downto 24) xor S_MEM_RD_IP_TDATA(23 downto 16)) xor (S_MEM_RD_IP_TDATA(15 downto 8) xor S_MEM_RD_IP_TDATA(7 downto 0)); -- byte XOR;

          -- Launch read access to bram
          else
            rd_req   <= '1';
            ram_addr <= (S_MEM_RD_IP_TDATA(31 downto 24) xor S_MEM_RD_IP_TDATA(23 downto 16)) xor (S_MEM_RD_IP_TDATA(15 downto 8) xor S_MEM_RD_IP_TDATA(7 downto 0)); -- byte XOR

          end if;
        end if;

        -- Launch memorized read access to bram
        if (mem_rd_req = '1') and (not ((S_MEM_WR_IP_MAC_TVALID = '1') and (s_mem_wr_ip_mac_tready_i = '1'))) then
          rd_req     <= '1';
          mem_rd_req <= '0';
          ram_addr   <= mem_rd_addr;
        end if;

        -- Register request during G_RD_LATENCY
        rd_req_r <= rd_req_r(0) & rd_req;

        -- Set response when read command has been processed
        if rd_req_r(1) = '1' then

          M_MEM_RD_MAC_TDATA    <= ram_dout(79 downto 32);
          m_mem_rd_mac_tvalid_i <= '1';

          -- IP addr has been found or not in table
          if (ip_addr_searched = ram_dout(31 downto 0)) then -- Data into ram is ethernet endianness
            M_MEM_RD_MAC_TUSER(0) <= C_STATUS_VALID;
          else
            M_MEM_RD_MAC_TUSER(0) <= C_STATUS_INVALID;
          end if;

        -- Clear tvalid when transaction is accepted
        elsif M_MEM_RD_MAC_TREADY = '1' then
          m_mem_rd_mac_tvalid_i <= '0';

        end if;

        --------------------------------
        -- CLEAR
        --------------------------------
        if (CLEAR_ARP = '1') and (not (clear_arp_in_progress = '1')) then
          s_mem_wr_ip_mac_tready_i <= '0';
          s_mem_rd_ip_tready_i     <= '0';
          clear_arp_in_progress    <= '1';
          ram_wen                  <= '1';
          ram_addr                 <= (others => '0');
          ram_din                  <= (others => '0');
        end if;

        if (clear_arp_in_progress = '1') then

          if (ram_addr = std_logic_vector(to_unsigned(255, 8))) then
            s_mem_wr_ip_mac_tready_i <= '1';
            s_mem_rd_ip_tready_i     <= '1';
            clear_arp_in_progress    <= '0';
            CLEAR_ARP_DONE           <= '1';
            ram_wen                  <= '0';
          else
            ram_addr <= std_logic_vector(unsigned(ram_addr) + 1);
            ram_wen  <= '1';
          end if;
        end if;

      end if;
    end if;
  end process PROCESS_MEM;

end rtl;

