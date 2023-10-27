-- Copyright (c) 2022-2023 THALES. All Rights Reserved
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uoe_module_pkg.all;

entity wrapped_uoe_core is
  generic(
    G_ACTIVE_RST          : std_logic := '1'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST           : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_MAC_TDATA_WIDTH     : integer   := 64; -- Number of bits used along MAC AXIS itf datapath of MAC interface
    G_UOE_TDATA_WIDTH     : integer   := 64; -- Number of bits used along AXI datapath of UOE
    G_UOE_FREQ_KHZ        : integer   := 156250 -- System Frequency use to reference timeout
  );
  port(
    -- Clock domain of MAC in rx
    CLK_RX                  : out  std_logic;
    RST_RX                  : out  std_logic;
    -- Clock domain of MAC in tx
    CLK_TX                  : out  std_logic;
    RST_TX                  : out  std_logic;
    -- Internal clock domain
    CLK_UOE                 : out  std_logic;
    RST_UOE                 : out  std_logic;
    -- Status Physical Layer
    PHY_LAYER_RDY           : in  std_logic;
    -- UOE Interrupt Output
    INTERRUPT               : out std_logic;
    -- Interface MAC with Physical interface
    S_MAC_RX_TDATA          : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
    S_MAC_RX_TVALID         : in  std_logic;
    S_MAC_RX_TLAST          : in  std_logic;
    S_MAC_RX_TKEEP          : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
    S_MAC_RX_TUSER          : in  std_logic;
    M_MAC_TX_TDATA          : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
    M_MAC_TX_TVALID         : out std_logic;
    M_MAC_TX_TLAST          : out std_logic;
    M_MAC_TX_TKEEP          : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
    M_MAC_TX_TUSER          : out std_logic;
    M_MAC_TX_TREADY         : in  std_logic;
    -- Interface EXT
    S_EXT_TX_TDATA          : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    S_EXT_TX_TVALID         : in  std_logic;
    S_EXT_TX_TLAST          : in  std_logic;
    S_EXT_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_EXT_TX_TREADY         : out std_logic;
    M_EXT_RX_TDATA          : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
    M_EXT_RX_TVALID         : out std_logic;
    M_EXT_RX_TLAST          : out std_logic;
    M_EXT_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_EXT_RX_TREADY         : in  std_logic;
    -- Interface RAW
    S_RAW_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_RAW_TX_TVALID         : in  std_logic;
    S_RAW_TX_TLAST          : in  std_logic;
    S_RAW_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_RAW_TX_TUSER          : in  std_logic_vector(15 downto 0); -- Frame Size
    S_RAW_TX_TREADY         : out std_logic;
    M_RAW_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_RAW_RX_TVALID         : out std_logic;
    M_RAW_RX_TLAST          : out std_logic;
    M_RAW_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_RAW_RX_TUSER          : out std_logic_vector(15 downto 0); -- Frame Size
    M_RAW_RX_TREADY         : in  std_logic;
    -- Interface UDP
    S_UDP_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    S_UDP_TX_TVALID         : in  std_logic;
    S_UDP_TX_TLAST          : in  std_logic;
    S_UDP_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    S_UDP_TX_TUSER          : in  std_logic_vector(79 downto 0);
    S_UDP_TX_TREADY         : out std_logic;
    M_UDP_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
    M_UDP_RX_TVALID         : out std_logic;
    M_UDP_RX_TLAST          : out std_logic;
    M_UDP_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
    M_UDP_RX_TUSER          : out std_logic_vector(79 downto 0);
    M_UDP_RX_TREADY         : in  std_logic;
    -- AXI4-Lite interface to registers
    S_AXI_AWADDR            : in  std_logic_vector(7 downto 0);
    S_AXI_AWVALID           : in  std_logic;
    S_AXI_AWREADY           : out std_logic;
    S_AXI_WDATA             : in  std_logic_vector(31 downto 0);
    S_AXI_WVALID            : in  std_logic;
    S_AXI_WSTRB             : in  std_logic_vector(3 downto 0);
    S_AXI_WREADY            : out std_logic;
    S_AXI_BRESP             : out std_logic_vector(1 downto 0);
    S_AXI_BVALID            : out std_logic;
    S_AXI_BREADY            : in  std_logic;
    S_AXI_ARADDR            : in  std_logic_vector(7 downto 0);
    S_AXI_ARVALID           : in  std_logic;
    S_AXI_ARREADY           : out std_logic;
    S_AXI_RDATA             : out std_logic_vector(31 downto 0);
    S_AXI_RRESP             : out std_logic_vector(1 downto 0);
    S_AXI_RVALID            : out std_logic;
    S_AXI_RREADY            : in  std_logic;
    -- AXI4-Lite interface to ARP Table (used for debug)
    S_AXI_ARP_TABLE_AWADDR  : in  std_logic_vector(11 downto 0);
    S_AXI_ARP_TABLE_AWVALID : in  std_logic;
    S_AXI_ARP_TABLE_AWREADY : out std_logic;
    S_AXI_ARP_TABLE_WDATA   : in  std_logic_vector(31 downto 0);
    S_AXI_ARP_TABLE_WVALID  : in  std_logic;
    S_AXI_ARP_TABLE_WREADY  : out std_logic;
    S_AXI_ARP_TABLE_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_ARP_TABLE_BVALID  : out std_logic;
    S_AXI_ARP_TABLE_BREADY  : in  std_logic;
    S_AXI_ARP_TABLE_ARADDR  : in  std_logic_vector(11 downto 0);
    S_AXI_ARP_TABLE_ARVALID : in  std_logic;
    S_AXI_ARP_TABLE_ARREADY : out std_logic;
    S_AXI_ARP_TABLE_RDATA   : out std_logic_vector(31 downto 0);
    S_AXI_ARP_TABLE_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_ARP_TABLE_RVALID  : out std_logic;
    S_AXI_ARP_TABLE_RREADY  : in  std_logic
  );
end wrapped_uoe_core;

architecture rtl of wrapped_uoe_core is

component uoe_core
    generic(
      G_ACTIVE_RST          : std_logic := '0';
      G_ASYNC_RST           : boolean   := false;
      G_MAC_TDATA_WIDTH     : integer   := 64;
      G_UOE_TDATA_WIDTH     : integer   := 64;
      G_ROUTER_FIFO_DEPTH   : integer   := 1536;
      G_ENABLE_ARP_MODULE   : boolean   := true;
      G_ENABLE_ARP_TABLE    : boolean   := true;
      G_ENABLE_PKT_DROP_EXT : boolean   := true;
      G_ENABLE_PKT_DROP_RAW : boolean   := true;
      G_ENABLE_PKT_DROP_UDP : boolean   := true;
      G_UOE_FREQ_KHZ        : integer   := 156250
    );
    port(
      CLK_RX                  : in  std_logic;
      RST_RX                  : in  std_logic;
      CLK_TX                  : in  std_logic;
      RST_TX                  : in  std_logic;
      CLK_UOE                 : in  std_logic;
      RST_UOE                 : in  std_logic;
      PHY_LAYER_RDY           : in  std_logic;
      INTERRUPT               : out std_logic;
      S_MAC_RX_TDATA          : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      S_MAC_RX_TVALID         : in  std_logic;
      S_MAC_RX_TLAST          : in  std_logic;
      S_MAC_RX_TKEEP          : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      S_MAC_RX_TUSER          : in  std_logic;
      M_MAC_TX_TDATA          : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      M_MAC_TX_TVALID         : out std_logic;
      M_MAC_TX_TLAST          : out std_logic;
      M_MAC_TX_TKEEP          : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      M_MAC_TX_TUSER          : out std_logic;
      M_MAC_TX_TREADY         : in  std_logic;
      S_EXT_TX_TDATA          : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_TVALID         : in  std_logic;
      S_EXT_TX_TLAST          : in  std_logic;
      S_EXT_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_TREADY         : out std_logic;
      M_EXT_RX_TDATA          : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_TVALID         : out std_logic;
      M_EXT_RX_TLAST          : out std_logic;
      M_EXT_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_TREADY         : in  std_logic;
      S_RAW_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_RAW_TX_TVALID         : in  std_logic;
      S_RAW_TX_TLAST          : in  std_logic;
      S_RAW_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_RAW_TX_TUSER          : in  std_logic_vector(15 downto 0);
      S_RAW_TX_TREADY         : out std_logic;
      M_RAW_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_RAW_RX_TVALID         : out std_logic;
      M_RAW_RX_TLAST          : out std_logic;
      M_RAW_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_RAW_RX_TUSER          : out std_logic_vector(15 downto 0);
      M_RAW_RX_TREADY         : in  std_logic;
      S_UDP_TX_TDATA          : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_UDP_TX_TVALID         : in  std_logic;
      S_UDP_TX_TLAST          : in  std_logic;
      S_UDP_TX_TKEEP          : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_UDP_TX_TUSER          : in  std_logic_vector(79 downto 0);
      S_UDP_TX_TREADY         : out std_logic;
      M_UDP_RX_TDATA          : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_UDP_RX_TVALID         : out std_logic;
      M_UDP_RX_TLAST          : out std_logic;
      M_UDP_RX_TKEEP          : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_UDP_RX_TUSER          : out std_logic_vector(79 downto 0);
      M_UDP_RX_TREADY         : in  std_logic;
      S_AXI_AWADDR            : in  std_logic_vector(7 downto 0);
      S_AXI_AWVALID           : in  std_logic;
      S_AXI_AWREADY           : out std_logic;
      S_AXI_WDATA             : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID            : in  std_logic;
      S_AXI_WSTRB             : in  std_logic_vector(3 downto 0);
      S_AXI_WREADY            : out std_logic;
      S_AXI_BRESP             : out std_logic_vector(1 downto 0);
      S_AXI_BVALID            : out std_logic;
      S_AXI_BREADY            : in  std_logic;
      S_AXI_ARADDR            : in  std_logic_vector(7 downto 0);
      S_AXI_ARVALID           : in  std_logic;
      S_AXI_ARREADY           : out std_logic;
      S_AXI_RDATA             : out std_logic_vector(31 downto 0);
      S_AXI_RRESP             : out std_logic_vector(1 downto 0);
      S_AXI_RVALID            : out std_logic;
      S_AXI_RREADY            : in  std_logic;
      S_AXI_ARP_TABLE_AWADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_AWVALID : in  std_logic;
      S_AXI_ARP_TABLE_AWREADY : out std_logic;
      S_AXI_ARP_TABLE_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_WVALID  : in  std_logic;
      S_AXI_ARP_TABLE_WREADY  : out std_logic;
      S_AXI_ARP_TABLE_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_BVALID  : out std_logic;
      S_AXI_ARP_TABLE_BREADY  : in  std_logic;
      S_AXI_ARP_TABLE_ARADDR  : in  std_logic_vector(11 downto 0);
      S_AXI_ARP_TABLE_ARVALID : in  std_logic;
      S_AXI_ARP_TABLE_ARREADY : out std_logic;
      S_AXI_ARP_TABLE_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_ARP_TABLE_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_ARP_TABLE_RVALID  : out std_logic;
      S_AXI_ARP_TABLE_RREADY  : in  std_logic
    );
  end component uoe_core;

begin

  -- Component mapping
  inst_uoe_core : uoe_core
    generic map (
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_MAC_TDATA_WIDTH     => G_MAC_TDATA_WIDTH,
      G_UOE_TDATA_WIDTH     => G_UOE_TDATA_WIDTH,
      G_ROUTER_FIFO_DEPTH   =>  8192,
      G_ENABLE_ARP_MODULE   => true,
      G_ENABLE_ARP_TABLE    => true,
      G_ENABLE_PKT_DROP_EXT => false,
      G_ENABLE_PKT_DROP_RAW => false,
      G_ENABLE_PKT_DROP_UDP => false,
      G_UOE_FREQ_KHZ        => G_UOE_FREQ_KHZ -- accelerate simulation
    )
    port map (
      CLK_RX => CLK_RX,
      RST_RX => RST_RX,
      CLK_TX => CLK_TX,
      RST_TX => RST_TX,
      CLK_UOE => CLK_UOE,
      RST_UOE => RST_UOE,
      PHY_LAYER_RDY => PHY_LAYER_RDY,
      INTERRUPT => INTERRUPT,
      S_MAC_RX_TDATA => S_MAC_RX_TDATA,
      S_MAC_RX_TVALID => S_MAC_RX_TVALID,
      S_MAC_RX_TLAST => S_MAC_RX_TLAST,
      S_MAC_RX_TKEEP => S_MAC_RX_TKEEP,
      S_MAC_RX_TUSER => S_MAC_RX_TUSER,
      M_MAC_TX_TDATA => M_MAC_TX_TDATA,
      M_MAC_TX_TVALID => M_MAC_TX_TVALID,
      M_MAC_TX_TLAST => M_MAC_TX_TLAST,
      M_MAC_TX_TKEEP => M_MAC_TX_TKEEP,
      M_MAC_TX_TUSER => M_MAC_TX_TUSER,
      M_MAC_TX_TREADY => M_MAC_TX_TREADY,
      S_EXT_TX_TDATA => S_EXT_TX_TDATA,
      S_EXT_TX_TVALID => S_EXT_TX_TVALID,
      S_EXT_TX_TLAST => S_EXT_TX_TLAST,
      S_EXT_TX_TKEEP => S_EXT_TX_TKEEP,
      S_EXT_TX_TREADY => S_EXT_TX_TREADY,
      M_EXT_RX_TDATA => M_EXT_RX_TDATA,
      M_EXT_RX_TVALID => M_EXT_RX_TVALID,
      M_EXT_RX_TLAST => M_EXT_RX_TLAST,
      M_EXT_RX_TKEEP => M_EXT_RX_TKEEP,
      M_EXT_RX_TREADY => M_EXT_RX_TREADY,
      S_RAW_TX_TDATA => S_RAW_TX_TDATA,
      S_RAW_TX_TVALID => S_RAW_TX_TVALID,
      S_RAW_TX_TLAST => S_RAW_TX_TLAST,
      S_RAW_TX_TKEEP => S_RAW_TX_TKEEP,
      S_RAW_TX_TUSER => S_RAW_TX_TUSER,
      S_RAW_TX_TREADY => S_RAW_TX_TREADY,
      M_RAW_RX_TDATA => M_RAW_RX_TDATA,
      M_RAW_RX_TVALID => M_RAW_RX_TVALID,
      M_RAW_RX_TLAST => M_RAW_RX_TLAST,
      M_RAW_RX_TKEEP => M_RAW_RX_TKEEP,
      M_RAW_RX_TUSER => M_RAW_RX_TUSER,
      M_RAW_RX_TREADY => M_RAW_RX_TREADY,
      S_UDP_TX_TDATA => S_UDP_TX_TDATA,
      S_UDP_TX_TVALID => S_UDP_TX_TVALID,
      S_UDP_TX_TLAST => S_UDP_TX_TLAST,
      S_UDP_TX_TKEEP => S_UDP_TX_TKEEP,
      S_UDP_TX_TUSER => S_UDP_TX_TUSER,
      S_UDP_TX_TREADY => S_UDP_TX_TREADY,
      M_UDP_RX_TDATA => M_UDP_RX_TDATA,
      M_UDP_RX_TVALID => M_UDP_RX_TVALID,
      M_UDP_RX_TLAST => M_UDP_RX_TLAST,
      M_UDP_RX_TKEEP => M_UDP_RX_TKEEP,
      M_UDP_RX_TUSER => M_UDP_RX_TUSER,
      M_UDP_RX_TREADY => M_UDP_RX_TREADY,
      S_AXI_AWADDR => S_AXI_AWADDR,
      S_AXI_AWVALID => S_AXI_AWVALID,
      S_AXI_AWREADY => S_AXI_AWREADY,
      S_AXI_WDATA => S_AXI_WDATA,
      S_AXI_WVALID => S_AXI_WVALID,
      S_AXI_WSTRB => S_AXI_WSTRB,
      S_AXI_WREADY => S_AXI_WREADY,
      S_AXI_BRESP => S_AXI_BRESP,
      S_AXI_BVALID => S_AXI_BVALID,
      S_AXI_BREADY => S_AXI_BREADY,
      S_AXI_ARADDR => S_AXI_ARADDR,
      S_AXI_ARVALID => S_AXI_ARVALID,
      S_AXI_ARREADY => S_AXI_ARREADY,
      S_AXI_RDATA => S_AXI_RDATA,
      S_AXI_RRESP => S_AXI_RRESP,
      S_AXI_RVALID => S_AXI_RVALID,
      S_AXI_RREADY => S_AXI_RREADY,
      S_AXI_ARP_TABLE_AWADDR => S_AXI_ARP_TABLE_AWADDR,
      S_AXI_ARP_TABLE_AWVALID => S_AXI_ARP_TABLE_AWVALID,
      S_AXI_ARP_TABLE_AWREADY => S_AXI_ARP_TABLE_AWREADY,
      S_AXI_ARP_TABLE_WDATA => S_AXI_ARP_TABLE_WDATA,
      S_AXI_ARP_TABLE_WVALID => S_AXI_ARP_TABLE_WVALID,
      S_AXI_ARP_TABLE_WREADY => S_AXI_ARP_TABLE_WREADY,
      S_AXI_ARP_TABLE_BRESP => S_AXI_ARP_TABLE_BRESP,
      S_AXI_ARP_TABLE_BVALID => S_AXI_ARP_TABLE_BVALID,
      S_AXI_ARP_TABLE_BREADY => S_AXI_ARP_TABLE_BREADY,
      S_AXI_ARP_TABLE_ARADDR => S_AXI_ARP_TABLE_ARADDR,
      S_AXI_ARP_TABLE_ARVALID => S_AXI_ARP_TABLE_ARVALID,
      S_AXI_ARP_TABLE_ARREADY => S_AXI_ARP_TABLE_ARREADY,
      S_AXI_ARP_TABLE_RDATA => S_AXI_ARP_TABLE_RDATA,
      S_AXI_ARP_TABLE_RRESP => S_AXI_ARP_TABLE_RRESP,
      S_AXI_ARP_TABLE_RVALID => S_AXI_ARP_TABLE_RVALID,
      S_AXI_ARP_TABLE_RREADY => S_AXI_ARP_TABLE_RREADY
    );
    
    -- Reset RX
    SYSTEM_RESET_RX : process
    begin
      RST_RX <= G_ACTIVE_RST;
      wait for 200 ns;
      RST_RX <= not G_ACTIVE_RST;
      wait;
    end process SYSTEM_RESET_RX;

    -- Clock RX generation
    OSCIL_RX : process
      constant C_CLK_RX_PERIOD : time := 6 ns;
    begin
      CLK_RX <= '0';
      wait for C_CLK_RX_PERIOD / 2;
      CLK_RX <= '1';
      wait for C_CLK_RX_PERIOD / 2;
    end process OSCIL_RX;
    
    -- Reset TX
    SYSTEM_RESET_TX : process
    begin
      RST_TX <= G_ACTIVE_RST;
      wait for 200 ns;
      RST_TX <= not G_ACTIVE_RST;
      wait;
    end process SYSTEM_RESET_TX;
    
    -- Clock RX generation
    OSCIL_TX : process
      constant C_CLK_TX_PERIOD : time := 6 ns;
    begin
      CLK_TX <= '0';
      wait for C_CLK_TX_PERIOD / 2;
      CLK_TX <= '1';
      wait for C_CLK_TX_PERIOD / 2;
    end process OSCIL_TX;
    
    -- Reset UOE
    SYSTEM_RESET_UOE : process
    begin
      RST_UOE <= G_ACTIVE_RST;
      wait for 200 ns;
      RST_UOE <= not G_ACTIVE_RST;
      wait;
    end process SYSTEM_RESET_UOE;
    
    -- Clock RX generation
	OSCIL_UOE : process
	  constant C_CLK_UOE_PERIOD : time := 4 ns;
	begin
	  CLK_UOE <= '0';
	  wait for C_CLK_UOE_PERIOD / 2;
	  CLK_UOE <= '1';
	  wait for C_CLK_UOE_PERIOD / 2;
	end process OSCIL_UOE;


end rtl;
