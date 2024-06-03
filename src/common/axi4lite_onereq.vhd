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
-- AXI4LITE_ONEREQ
--
----------------------------------------------------------------------------------
-- This component blocks the read or write request until the completion of the
-- previous request.
----------
-- The entity is generic in data and address width.
--
-- The entity registers slave port and master port
-- the logic is done asynchronously between the registers
--------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi4lite_utils_pkg.axi4lite_register;

entity axi4lite_onereq is
  generic(
    G_ACTIVE_RST : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_DATA_WIDTH : positive  := 32;   -- Width of the data vector of the axi4-lite
    G_ADDR_WIDTH : positive  := 16;   -- Width of the address vector of the axi4-lite
    G_REG_MASTER : boolean   := true; -- Whether to register outputs on Master port side
    G_REG_SLAVE  : boolean   := true  -- Whether to register outputs on Slave port side
  );
  port (
    -- GLOBAL SIGNALS
    CLK       : in  std_logic;
    RST       : in  std_logic;

    --------------------------------------
    -- SLAVE AXI4-LITE
    --------------------------------------
    -- -- ADDRESS WRITE (AW)
    S_AWADDR  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    S_AWPROT  : in  std_logic_vector(2 downto 0);
    S_AWVALID : in  std_logic;
    S_AWREADY : out std_logic;
    -- -- WRITE (W)
    S_WDATA   : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    S_WSTRB   : in  std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0);
    S_WVALID  : in  std_logic;
    S_WREADY  : out std_logic;
    -- -- RESPONSE WRITE (B)
    S_BRESP   : out std_logic_vector(1 downto 0);
    S_BVALID  : out std_logic;
    S_BREADY  : in  std_logic;
    -- -- ADDRESS READ (AR)
    S_ARADDR  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    S_ARPROT  : in  std_logic_vector(2 downto 0);
    S_ARVALID : in  std_logic;
    S_ARREADY : out std_logic;
    -- -- READ (R)
    S_RDATA   : out std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    S_RVALID  : out std_logic;
    S_RRESP   : out std_logic_vector(1 downto 0);
    S_RREADY  : in  std_logic;

    --------------------------------------
    -- MASTER AXI4-LITE
    --------------------------------------
    -- -- ADDRESS WRITE (AW)
    M_AWADDR  : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    M_AWPROT  : out std_logic_vector(2 downto 0);
    M_AWVALID : out std_logic;
    M_AWREADY : in  std_logic;
    -- -- WRITE (W)
    M_WDATA   : out std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    M_WSTRB   : out std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0);
    M_WVALID  : out std_logic;
    M_WREADY  : in  std_logic;
    -- -- RESPONSE WRITE (B)
    M_BRESP   : in  std_logic_vector(1 downto 0);
    M_BVALID  : in  std_logic;
    M_BREADY  : out std_logic;
    -- -- ADDRESS READ (AR)
    M_ARADDR  : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    M_ARPROT  : out std_logic_vector(2 downto 0);
    M_ARVALID : out std_logic;
    M_ARREADY : in  std_logic;
    -- -- READ (R)
    M_RDATA   : in  std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    M_RVALID  : in  std_logic;
    M_RRESP   : in  std_logic_vector(1 downto 0);
    M_RREADY  : out std_logic
  );
end axi4lite_onereq;

architecture rtl of axi4lite_onereq is

  -- AXI4-Lite bus from slave port registers
  signal s_from_reg_awaddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
  signal s_from_reg_awprot  : std_logic_vector(2 downto 0);
  signal s_from_reg_awvalid : std_logic;
  signal s_from_reg_awready : std_logic;

  signal s_from_reg_wdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  signal s_from_reg_wstrb   : std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0);
  signal s_from_reg_wvalid  : std_logic;
  signal s_from_reg_wready  : std_logic;

  signal s_from_reg_bresp   : std_logic_vector(1 downto 0);
  signal s_from_reg_bvalid  : std_logic;
  signal s_from_reg_bready  : std_logic;

  signal s_from_reg_araddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
  signal s_from_reg_arprot  : std_logic_vector(2 downto 0);
  signal s_from_reg_arvalid : std_logic;
  signal s_from_reg_arready : std_logic;

  signal s_from_reg_rdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  signal s_from_reg_rvalid  : std_logic;
  signal s_from_reg_rresp   : std_logic_vector(1 downto 0);
  signal s_from_reg_rready  : std_logic;

  -- internal logic to block flow while a request is pending
  signal pending_aw : std_logic;
  signal pending_w  : std_logic;
  signal pending_ar : std_logic;

  -- AXI4-Lite bus to master port registers
  signal m_to_reg_awaddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
  signal m_to_reg_awprot  : std_logic_vector(2 downto 0);
  signal m_to_reg_awvalid : std_logic;
  signal m_to_reg_awready : std_logic;

  signal m_to_reg_wdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  signal m_to_reg_wstrb   : std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0);
  signal m_to_reg_wvalid  : std_logic;
  signal m_to_reg_wready  : std_logic;

  signal m_to_reg_bresp   : std_logic_vector(1 downto 0);
  signal m_to_reg_bvalid  : std_logic;
  signal m_to_reg_bready  : std_logic;

  signal m_to_reg_araddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
  signal m_to_reg_arprot  : std_logic_vector(2 downto 0);
  signal m_to_reg_arvalid : std_logic;
  signal m_to_reg_arready : std_logic;

  signal m_to_reg_rdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
  signal m_to_reg_rvalid  : std_logic;
  signal m_to_reg_rresp   : std_logic_vector(1 downto 0);
  signal m_to_reg_rready  : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Slave outputs register
  -----------------------------------------------------------------------------

  -- Register slave port outputs
  inst_axi4lite_register_slave : component axi4lite_register
    generic map(
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_DATA_WIDTH => G_DATA_WIDTH,
      G_ADDR_WIDTH => G_ADDR_WIDTH,
      G_REG_MASTER => false,       -- Do not register to internal logic
      G_REG_SLAVE  => G_REG_SLAVE  -- Register to slave port depending on parameter
    )
    port map(
      -- Global
      CLK       => CLK,
      RST       => RST,

      -- Slave port from entity port
      S_AWADDR  => S_AWADDR,
      S_AWPROT  => S_AWPROT,
      S_AWVALID => S_AWVALID,
      S_AWREADY => S_AWREADY,
      S_WDATA   => S_WDATA,
      S_WSTRB   => S_WSTRB,
      S_WVALID  => S_WVALID,
      S_WREADY  => S_WREADY,
      S_BRESP   => S_BRESP,
      S_BVALID  => S_BVALID,
      S_BREADY  => S_BREADY,
      S_ARADDR  => S_ARADDR,
      S_ARPROT  => S_ARPROT,
      S_ARVALID => S_ARVALID,
      S_ARREADY => S_ARREADY,
      S_RDATA   => S_RDATA,
      S_RVALID  => S_RVALID,
      S_RRESP   => S_RRESP,
      S_RREADY  => S_RREADY,

      -- Master port to internal logic
      M_AWADDR  => s_from_reg_awaddr,
      M_AWPROT  => s_from_reg_awprot,
      M_AWVALID => s_from_reg_awvalid,
      M_AWREADY => s_from_reg_awready,
      M_WDATA   => s_from_reg_wdata,
      M_WSTRB   => s_from_reg_wstrb,
      M_WVALID  => s_from_reg_wvalid,
      M_WREADY  => s_from_reg_wready,
      M_BRESP   => s_from_reg_bresp,
      M_BVALID  => s_from_reg_bvalid,
      M_BREADY  => s_from_reg_bready,
      M_ARADDR  => s_from_reg_araddr,
      M_ARPROT  => s_from_reg_arprot,
      M_ARVALID => s_from_reg_arvalid,
      M_ARREADY => s_from_reg_arready,
      M_RDATA   => s_from_reg_rdata,
      M_RVALID  => s_from_reg_rvalid,
      M_RRESP   => s_from_reg_rresp,
      M_RREADY  => s_from_reg_rready
    );


  -----------------------------------------------------------------------------
  -- Internal logic
  -----------------------------------------------------------------------------

  -- Detect and register pending requests
  SYNC_PENDING: process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      pending_aw <= '0';
      pending_w  <= '0';
      pending_ar <= '0';

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        pending_aw <= '0';
        pending_w  <= '0';
        pending_ar <= '0';
      else

        -------------------------
        -- Start pending
        -------------------------
        -- pending starts when a transaction was seen on the channel
        -- watching s_from_reg or m_to_reg is equivalent

        -- aw channel
        if (s_from_reg_awvalid = '1') and (s_from_reg_awready = '1') then
          pending_aw <= '1';
        end if;

        -- w channel
        if (s_from_reg_wvalid = '1') and (s_from_reg_wready = '1') then
          pending_w  <= '1';
        end if;

        -- ar channel
        if (s_from_reg_arvalid = '1') and (s_from_reg_arready = '1') then
          pending_ar <= '1';
        end if;

        -------------------------
        -- Stop pending
        -------------------------
        -- pending stops when a transaction was seen on the reponse channel
        -- watching s_from_reg or m_to_reg is equivalent

        -- b channel to free aw and w channels
        if (s_from_reg_bvalid = '1') and (s_from_reg_bready = '1') then
          pending_aw <= '0';
          pending_w  <= '0';
        end if;

        -- r channel to free ar channel
        if (s_from_reg_rvalid = '1') and (s_from_reg_rready = '1') then
          pending_ar <= '0';
        end if;
      end if;
    end if;
  end process SYNC_PENDING;

  -- Connect slave to master
  -- Disable the flow control when a request is pending
  m_to_reg_awaddr    <= s_from_reg_awaddr;
  m_to_reg_awprot    <= s_from_reg_awprot;
  m_to_reg_awvalid   <= s_from_reg_awvalid when pending_aw /= '1' else '0';
  s_from_reg_awready <= m_to_reg_awready when pending_aw /= '1' else '0';

  m_to_reg_wdata     <= s_from_reg_wdata;
  m_to_reg_wstrb     <= s_from_reg_wstrb;
  m_to_reg_wvalid    <= s_from_reg_wvalid when pending_w /= '1' else '0';
  s_from_reg_wready  <= m_to_reg_wready when pending_w /= '1' else '0';

  s_from_reg_bresp   <= m_to_reg_bresp;
  s_from_reg_bvalid  <= m_to_reg_bvalid;
  m_to_reg_bready    <= s_from_reg_bready;

  m_to_reg_araddr    <= s_from_reg_araddr;
  m_to_reg_arprot    <= s_from_reg_arprot;
  m_to_reg_arvalid   <= s_from_reg_arvalid when pending_ar /= '1' else '0';
  s_from_reg_arready <= m_to_reg_arready when pending_ar /= '1' else '0';

  s_from_reg_rdata   <= m_to_reg_rdata;
  s_from_reg_rvalid  <= m_to_reg_rvalid;
  s_from_reg_rresp   <= m_to_reg_rresp;
  m_to_reg_rready    <= s_from_reg_rready;


  -----------------------------------------------------------------------------
  -- Master outputs register
  -----------------------------------------------------------------------------

  -- register master port outputs
  inst_axi4lite_register_master : component axi4lite_register
    generic map(
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST,
      G_DATA_WIDTH => G_DATA_WIDTH,
      G_ADDR_WIDTH => G_ADDR_WIDTH,
      G_REG_MASTER => G_REG_MASTER, -- Register to master port depending on parameter
      G_REG_SLAVE  => false         -- Do not register to internal logic
    )
    port map(
      -- Global
      CLK       => CLK,
      RST       => RST,

      -- Slave port from internal logic
      S_AWADDR  => m_to_reg_awaddr,
      S_AWPROT  => m_to_reg_awprot,
      S_AWVALID => m_to_reg_awvalid,
      S_AWREADY => m_to_reg_awready,
      S_WDATA   => m_to_reg_wdata,
      S_WSTRB   => m_to_reg_wstrb,
      S_WVALID  => m_to_reg_wvalid,
      S_WREADY  => m_to_reg_wready,
      S_BRESP   => m_to_reg_bresp,
      S_BVALID  => m_to_reg_bvalid,
      S_BREADY  => m_to_reg_bready,
      S_ARADDR  => m_to_reg_araddr,
      S_ARPROT  => m_to_reg_arprot,
      S_ARVALID => m_to_reg_arvalid,
      S_ARREADY => m_to_reg_arready,
      S_RDATA   => m_to_reg_rdata,
      S_RVALID  => m_to_reg_rvalid,
      S_RRESP   => m_to_reg_rresp,
      S_RREADY  => m_to_reg_rready,

      -- Master port from entity
      M_AWADDR  => M_AWADDR,
      M_AWPROT  => M_AWPROT,
      M_AWVALID => M_AWVALID,
      M_AWREADY => M_AWREADY,
      M_WDATA   => M_WDATA,
      M_WSTRB   => M_WSTRB,
      M_WVALID  => M_WVALID,
      M_WREADY  => M_WREADY,
      M_BRESP   => M_BRESP,
      M_BVALID  => M_BVALID,
      M_BREADY  => M_BREADY,
      M_ARADDR  => M_ARADDR,
      M_ARPROT  => M_ARPROT,
      M_ARVALID => M_ARVALID,
      M_ARREADY => M_ARREADY,
      M_RDATA   => M_RDATA,
      M_RVALID  => M_RVALID,
      M_RRESP   => M_RRESP,
      M_RREADY  => M_RREADY
    );

end rtl;
