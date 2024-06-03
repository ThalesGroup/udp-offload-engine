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

---------------------------------------------------
--
-- AXI4LITE_SP_RAM_CTRL
--
--------------------------------------------------
--
-- This module has a role of axi4lite wrapper on a BRAM interface.
-- Its purpose is to be directly connected to an interface of the TRUE_DP_RAM module of the memory_utils library.
--
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4lite_utils_pkg.C_AXI_RESP_OKAY;
use work.axi4lite_utils_pkg.C_AXI_RESP_SLVERR;

entity axi4lite_sp_ram_ctrl is
  generic(
    G_ACTIVE_RST     : std_logic              := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST      : boolean                := true; -- Type of reset used (synchronous or asynchronous resets)
    G_AXI_DATA_WIDTH : positive               := 32; -- Width of the data vector of the axi4-lite (32 or 64 bits following standard)
    G_AXI_ADDR_WIDTH : positive               := 8; -- Width of the address vector of the axi4-lite
    G_RD_LATENCY     : positive range 2 to 32 := 2;
    G_BYTE_ENABLE    : boolean                := false -- If true, allow STRB /= (others => '1')
  );
  port(
    -- GLOBAL SIGNALS
    CLK           : in  std_logic;
    RST           : in  std_logic;
    -- SLAVE AXI4-LITE
    -- -- ADDRESS WRITE (AW)
    S_AXI_AWADDR  : in  std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
    S_AXI_AWPROT  : in  std_logic_vector(2 downto 0); -- not used
    S_AXI_AWVALID : in  std_logic;
    S_AXI_AWREADY : out std_logic;
    -- -- WRITE (W)
    S_AXI_WDATA   : in  std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
    S_AXI_WSTRB   : in  std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0);
    S_AXI_WVALID  : in  std_logic;
    S_AXI_WREADY  : out std_logic;
    -- -- RESPONSE WRITE (B)
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in  std_logic;
    -- -- ADDRESS READ (AR)
    S_AXI_ARADDR  : in  std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
    S_AXI_ARPROT  : in  std_logic_vector(2 downto 0); -- not used
    S_AXI_ARVALID : in  std_logic;
    S_AXI_ARREADY : out std_logic;
    -- -- READ (R)
    S_AXI_RDATA   : out std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RREADY  : in  std_logic;
    -- Interface RAM
    BRAM_EN       : out std_logic;
    BRAM_WREN     : out std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0);
    BRAM_ADDR     : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
    BRAM_DIN      : out std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
    BRAM_DOUT     : in  std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0)
  );
end axi4lite_sp_ram_ctrl;

architecture rtl of axi4lite_sp_ram_ctrl is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  constant C_STRB_ALL_ONE : std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0) := (others => '1');

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- signals used to release tready after reset
  signal axi_wr_init : std_logic;
  signal axi_rd_init : std_logic;

  -- internal signals
  signal s_axi_awready_i : std_logic;
  signal s_axi_wready_i  : std_logic;
  signal s_axi_bvalid_i  : std_logic;

  signal s_axi_arready_i : std_logic;
  signal s_axi_rvalid_i  : std_logic;

  -- memorization of transaction AW/W
  signal axi_awvalid : std_logic;
  signal axi_wvalid  : std_logic;

  -- rd latency
  signal rd_req   : std_logic;
  signal rd_req_r : std_logic_vector(G_RD_LATENCY - 1 downto 0);

  signal mem_wr_addr : std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
  signal mem_wr_data : std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
  signal mem_wr_strb : std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0);

  -- memorization of read request when concurent access RD/WR
  signal mem_rd_req  : std_logic;
  signal mem_rd_addr : std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);

begin

  --------------------------------------------
  -- Management of AXI4-Lite to Bram conversion
  P_CTRL : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then

      axi_wr_init <= '1';
      axi_rd_init <= '1';

      s_axi_awready_i <= '0';
      s_axi_wready_i  <= '0';
      s_axi_bvalid_i  <= '0';

      s_axi_arready_i <= '0';
      s_axi_rvalid_i  <= '0';

      S_AXI_BRESP <= (others => '0');
      S_AXI_RDATA <= (others => '0');

      axi_awvalid <= '0';
      axi_wvalid  <= '0';
      mem_wr_addr <= (others => '0');
      mem_wr_data <= (others => '0');
      mem_wr_strb <= (others => '0');

      rd_req      <= '0';
      rd_req_r    <= (others => '0');
      mem_rd_req  <= '0';
      mem_rd_addr <= (others => '0');

      BRAM_EN   <= '0';
      BRAM_WREN <= (others => '0');
      BRAM_ADDR <= (others => '0');
      BRAM_DIN  <= (others => '0');

    elsif rising_edge(CLK) then

      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then

        axi_wr_init <= '1';
        axi_rd_init <= '1';

        s_axi_awready_i <= '0';
        s_axi_wready_i  <= '0';
        s_axi_bvalid_i  <= '0';

        s_axi_arready_i <= '0';
        s_axi_rvalid_i  <= '0';

        S_AXI_BRESP <= (others => '0');
        S_AXI_RDATA <= (others => '0');

        axi_awvalid <= '0';
        axi_wvalid  <= '0';
        mem_wr_addr <= (others => '0');
        mem_wr_data <= (others => '0');
        mem_wr_strb <= (others => '0');

        rd_req      <= '0';
        rd_req_r    <= (others => '0');
        mem_rd_req  <= '0';
        mem_rd_addr <= (others => '0');

        BRAM_EN   <= '0';
        BRAM_WREN <= (others => '0');
        BRAM_ADDR <= (others => '0');
        BRAM_DIN  <= (others => '0');

      else
        -- Default
        rd_req     <= '0';
        mem_rd_req <= '0';
        BRAM_EN    <= '0';
        BRAM_WREN  <= (others => '0');

        -- Assert awready and wready when previous transaction response has been accepted
        if (s_axi_bvalid_i = '1') and (S_AXI_BREADY = '1') then
          s_axi_awready_i <= '1';
          s_axi_wready_i  <= '1';

        -- or after reset
        elsif axi_wr_init = '1' then
          s_axi_awready_i <= '1';
          s_axi_wready_i  <= '1';
          axi_wr_init     <= '0';

        end if;

        -- Clear BVALID when BREADY is asserted
        if (S_AXI_BREADY = '1') then
          s_axi_bvalid_i <= '0';
        end if;

        -- Address Write Request
        if (S_AXI_AWVALID = '1') and (s_axi_awready_i = '1') then
          mem_wr_addr     <= S_AXI_AWADDR;
          s_axi_awready_i <= '0';

          -- memorize transaction if data transaction is not yet accepted  
          if not (((S_AXI_WVALID = '1') and (s_axi_wready_i = '1')) or (axi_wvalid = '1')) then
            axi_awvalid <= '1';
          end if;

          -- Clear flag W
          axi_wvalid <= '0';
        end if;

        -- Data Write Request
        if (S_AXI_WVALID = '1') and (s_axi_wready_i = '1') then
          mem_wr_data    <= S_AXI_WDATA;
          mem_wr_strb    <= S_AXI_WSTRB;
          s_axi_wready_i <= '0';

          -- memorize transaction if addr transaction is not yet accepted 
          if not (((S_AXI_AWVALID = '1') and (s_axi_awready_i = '1')) or (axi_awvalid = '1')) then
            axi_wvalid <= '1';
          end if;

          -- Clear flag AW
          axi_awvalid <= '0';

          -- set response value
          S_AXI_BRESP <= C_AXI_RESP_OKAY;
          -- With BYTE_ENABLE disabled, WSTRB must be full of 1
          if not G_BYTE_ENABLE then
            if (S_AXI_WSTRB /= C_STRB_ALL_ONE) then
              S_AXI_BRESP <= C_AXI_RESP_SLVERR;
            end if;
          end if;
        end if;

        -- launch access to ram
        if ((((S_AXI_AWVALID = '1') and (s_axi_awready_i = '1')) or (axi_awvalid = '1')) and (((S_AXI_WVALID = '1') and (s_axi_wready_i = '1')) or (axi_wvalid = '1'))) then
          s_axi_bvalid_i <= '1';

          if (axi_wvalid = '1') then
            -- memory access
            BRAM_EN   <= '1';
            BRAM_WREN <= mem_wr_strb;
            -- With BYTE_ENABLE disabled, allow write only when all strobe are one
            if not G_BYTE_ENABLE then
              if (mem_wr_strb /= C_STRB_ALL_ONE) then
                BRAM_EN   <= '0';
                BRAM_WREN <= (others => '0');
              end if;
            end if;
          else
            -- use current
            -- memory access
            BRAM_EN   <= '1';
            BRAM_WREN <= S_AXI_WSTRB;
            -- With BYTE_ENABLE disabled, allow write only when all strobe are one
            if not G_BYTE_ENABLE then
              if (S_AXI_WSTRB /= C_STRB_ALL_ONE) then
                BRAM_EN   <= '0';
                BRAM_WREN <= (others => '0');
              end if;
            end if;
          end if;

          -- use current or memorize
          if (axi_awvalid = '1') then
            BRAM_ADDR <= mem_wr_addr;
          else
            BRAM_ADDR <= S_AXI_AWADDR;
          end if;

          -- use current or memorize
          if (axi_wvalid = '1') then
            BRAM_DIN <= mem_wr_data;
          else
            BRAM_DIN <= S_AXI_WDATA;
          end if;
        end if;

        -- Assert arready when previous transaction response has been accepted
        if (s_axi_rvalid_i = '1') and (S_AXI_RREADY = '1') then
          s_axi_arready_i <= '1';

        -- or after reset
        elsif axi_rd_init = '1' then
          s_axi_arready_i <= '1';
          axi_rd_init     <= '0';

        end if;

        -- Address Read Request
        if (S_AXI_ARVALID = '1') and (s_axi_arready_i = '1') then
          s_axi_arready_i <= '0';

          -- if simultaneously write access, delayed read access
          if ((((S_AXI_AWVALID = '1') and (s_axi_awready_i = '1')) or (axi_awvalid = '1')) and (((S_AXI_WVALID = '1') and (s_axi_wready_i = '1')) or (axi_wvalid = '1'))) then
            mem_rd_req  <= '1';
            mem_rd_addr <= S_AXI_ARADDR;

          -- Launch read access to bram
          else
            rd_req    <= '1';
            BRAM_EN   <= '1';
            BRAM_ADDR <= S_AXI_ARADDR;

          end if;
        end if;

        -- Launch memorized read access to bram
        if (mem_rd_req = '1') then
          rd_req    <= '1';
          BRAM_EN   <= '1';
          BRAM_ADDR <= mem_rd_addr;
        end if;

        -- Register request during G_RD_LATENCY
        rd_req_r <= rd_req_r(G_RD_LATENCY - 2 downto 0) & rd_req;

        -- Set response when read command has been processed
        if rd_req_r(G_RD_LATENCY - 1) = '1' then
          -- Valid read data is available at the read data bus
          s_axi_rvalid_i <= '1';
          S_AXI_RDATA    <= BRAM_DOUT;

        -- Clear rvalid when transaction is accepted
        elsif S_AXI_RREADY = '1' then
          s_axi_rvalid_i <= '0';

        end if;

      end if;
    end if;
  end process P_CTRL;

  -- Output assignment
  S_AXI_AWREADY <= s_axi_awready_i;
  S_AXI_WREADY  <= s_axi_wready_i;

  S_AXI_ARREADY <= s_axi_arready_i;

  S_AXI_BVALID <= s_axi_bvalid_i;

  S_AXI_RVALID <= s_axi_rvalid_i;
  S_AXI_RRESP  <= C_AXI_RESP_OKAY;

end rtl;
