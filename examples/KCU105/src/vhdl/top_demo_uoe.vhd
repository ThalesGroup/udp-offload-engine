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

library common;
use common.axi4lite_utils_pkg.axi4lite_switch;
use common.axi4lite_utils_pkg.bridge_ascii_to_axi4lite;

use common.axis_utils_pkg.axis_fifo;
use common.axis_utils_pkg.axis_dwidth_converter;

use common.cdc_utils_pkg.cdc_reset_sync;
use common.cdc_utils_pkg.cdc_bit_sync;

use work.serial_if_pkg.all;

entity top_demo_uoe is
  port(
    CPU_RESET    : in  std_logic;
    CLK_125_P    : in  std_logic;
    CLK_125_N    : in  std_logic;
    SFP_REFCLK_P : in  std_logic;
    SFP_REFCLK_N : in  std_logic;
    SFP_TX_N     : out std_logic_vector(1 downto 0);
    SFP_TX_P     : out std_logic_vector(1 downto 0);
    SFP_RX_N     : in  std_logic_vector(1 downto 0);
    SFP_RX_P     : in  std_logic_vector(1 downto 0);
    SFP_LOS      : in  std_logic_vector(1 downto 0);
    UART_RX      : in  std_logic;
    UART_TX      : out std_logic;
    GPIO_LED     : out std_logic_vector(7 downto 0);
    GPIO_DIP_SW  : in  std_logic_vector(3 downto 0)
  );
end top_demo_uoe;

architecture rtl of top_demo_uoe is

  component top_uoe
    generic(
      G_ACTIVE_RST          : std_logic := '0';
      G_ASYNC_RST           : boolean   := false;
      G_ENABLE_ARP_MODULE   : boolean   := true;
      G_ENABLE_ARP_TABLE    : boolean   := true;
      G_ENABLE_TESTENV      : boolean   := true;
      G_ENABLE_PKT_DROP_EXT : boolean   := true;
      G_ENABLE_PKT_DROP_RAW : boolean   := true;
      G_ENABLE_PKT_DROP_UDP : boolean   := true;
      G_MAC_TDATA_WIDTH     : integer   := 64;
      G_UOE_TDATA_WIDTH     : integer   := 64;
      G_ROUTER_FIFO_DEPTH   : integer   := 1536;
      G_UOE_FREQ_KHZ        : integer   := 156250
    );
    port(
      CLK_RX          : in  std_logic;
      RST_RX          : in  std_logic;
      CLK_TX          : in  std_logic;
      RST_TX          : in  std_logic;
      CLK_UOE         : in  std_logic;
      RST_UOE         : in  std_logic;
      PHY_LAYER_RDY   : in  std_logic;
      INTERRUPT       : out std_logic_vector(1 downto 0);
      S_MAC_RX_TDATA  : in  std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      S_MAC_RX_TVALID : in  std_logic;
      S_MAC_RX_TLAST  : in  std_logic;
      S_MAC_RX_TKEEP  : in  std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      S_MAC_RX_TUSER  : in  std_logic;
      M_MAC_TX_TDATA  : out std_logic_vector((G_MAC_TDATA_WIDTH - 1) downto 0);
      M_MAC_TX_TVALID : out std_logic;
      M_MAC_TX_TLAST  : out std_logic;
      M_MAC_TX_TKEEP  : out std_logic_vector(((G_MAC_TDATA_WIDTH / 8) - 1) downto 0);
      M_MAC_TX_TUSER  : out std_logic;
      M_MAC_TX_TREADY : in  std_logic;
      S_EXT_TX_TDATA  : in  std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      S_EXT_TX_TVALID : in  std_logic;
      S_EXT_TX_TLAST  : in  std_logic;
      S_EXT_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_EXT_TX_TREADY : out std_logic;
      M_EXT_RX_TDATA  : out std_logic_vector(G_UOE_TDATA_WIDTH - 1 downto 0);
      M_EXT_RX_TVALID : out std_logic;
      M_EXT_RX_TLAST  : out std_logic;
      M_EXT_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_EXT_RX_TREADY : in  std_logic;
      S_RAW_TX_TDATA  : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_RAW_TX_TVALID : in  std_logic;
      S_RAW_TX_TLAST  : in  std_logic;
      S_RAW_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_RAW_TX_TUSER  : in  std_logic_vector(15 downto 0);
      S_RAW_TX_TREADY : out std_logic;
      M_RAW_RX_TDATA  : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_RAW_RX_TVALID : out std_logic;
      M_RAW_RX_TLAST  : out std_logic;
      M_RAW_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_RAW_RX_TUSER  : out std_logic_vector(15 downto 0);
      M_RAW_RX_TREADY : in  std_logic;
      S_UDP_TX_TDATA  : in  std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      S_UDP_TX_TVALID : in  std_logic;
      S_UDP_TX_TLAST  : in  std_logic;
      S_UDP_TX_TKEEP  : in  std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      S_UDP_TX_TUSER  : in  std_logic_vector(79 downto 0);
      S_UDP_TX_TREADY : out std_logic;
      M_UDP_RX_TDATA  : out std_logic_vector((G_UOE_TDATA_WIDTH - 1) downto 0);
      M_UDP_RX_TVALID : out std_logic;
      M_UDP_RX_TLAST  : out std_logic;
      M_UDP_RX_TKEEP  : out std_logic_vector(((G_UOE_TDATA_WIDTH / 8) - 1) downto 0);
      M_UDP_RX_TUSER  : out std_logic_vector(79 downto 0);
      M_UDP_RX_TREADY : in  std_logic;
      S_AXI_AWADDR    : in  std_logic_vector(13 downto 0);
      S_AXI_AWVALID   : in  std_logic;
      S_AXI_AWREADY   : out std_logic;
      S_AXI_WDATA     : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID    : in  std_logic;
      S_AXI_WSTRB     : in  std_logic_vector(3 downto 0);
      S_AXI_WREADY    : out std_logic;
      S_AXI_BRESP     : out std_logic_vector(1 downto 0);
      S_AXI_BVALID    : out std_logic;
      S_AXI_BREADY    : in  std_logic;
      S_AXI_ARADDR    : in  std_logic_vector(13 downto 0);
      S_AXI_ARVALID   : in  std_logic;
      S_AXI_ARREADY   : out std_logic;
      S_AXI_RDATA     : out std_logic_vector(31 downto 0);
      S_AXI_RRESP     : out std_logic_vector(1 downto 0);
      S_AXI_RVALID    : out std_logic;
      S_AXI_RREADY    : in  std_logic
    );
  end component top_uoe;

  -- Component declaration
  component sfp_interfaces is
    generic(
      G_DEBUG : boolean := false
    );
    port(
      -- Clocking
      GT_REFCLK_P        : in  std_logic;
      GT_REFCLK_N        : in  std_logic;
      CLK_50_MHZ         : in  std_logic; -- Free running clock
      CLK_100_MHZ        : in  std_logic; -- Free running clock
      -- Resets
      SYS_RST            : in  std_logic; -- Global async reset active high
      SYS_RST_N          : in  std_logic; -- Global async reset active low
      RX_RST             : in  std_logic; -- Reset of Rx part
      TX_RST             : in  std_logic; -- Reset of Tx part
      RX_RST_N           : in  std_logic; -- Reset of Rx part
      TX_RST_N           : in  std_logic; -- Reset of Tx part
      -- SFP
      SFP_TX_N           : out std_logic_vector(1 downto 0);
      SFP_TX_P           : out std_logic_vector(1 downto 0);
      SFP_RX_N           : in  std_logic_vector(1 downto 0);
      SFP_RX_P           : in  std_logic_vector(1 downto 0);
      -- Rx interface
      M_RX_ACLK          : out std_logic_vector(1 downto 0);
      M_RX_RST           : out std_logic_vector(1 downto 0);
      M_RX_TDATA         : out std_logic_vector(127 downto 0);
      M_RX_TKEEP         : out std_logic_vector(15 downto 0);
      M_RX_TVALID        : out std_logic_vector(1 downto 0);
      M_RX_TUSER         : out std_logic_vector(1 downto 0); -- 1 when frame is ok
      M_RX_TLAST         : out std_logic_vector(1 downto 0);
      -- Pause don't connect yet as not implemented in SFP10G
      --PAUSE_REQ          : in  std_logic_vector(1 downto 0);
      --PAUSE_VAL          : in  std_logic_vector(31 downto 0);
      -- Tx 10G interface
      S_TX_ACLK          : out std_logic_vector(1 downto 0);
      S_TX_RST           : out std_logic_vector(1 downto 0);
      S_TX_TDATA         : in  std_logic_vector(127 downto 0);
      S_TX_TKEEP         : in  std_logic_vector(15 downto 0);
      S_TX_TVALID        : in  std_logic_vector(1 downto 0);
      S_TX_TLAST         : in  std_logic_vector(1 downto 0);
      S_TX_TUSER         : in  std_logic_vector(1 downto 0); -- 1 when frame is ok
      S_TX_TREADY        : out std_logic_vector(1 downto 0);
      -- Control/status
      SFP_MOD_DEF0       : in  std_logic_vector(1 downto 0); -- '0' = module present   '1' = module not present
      SFP_RX_LOS         : in  std_logic_vector(1 downto 0);
      PHY_LAYER_READY    : out std_logic_vector(1 downto 0);
      STATUS_VECTOR_SFP  : out std_logic_vector(31 downto 0);
      -- DBG
      DBG_LOOPBACK_EN    : in  std_logic; -- 1 : loopback enable
      DBG_CLK_PHY_ACTIVE : out std_logic_vector(1 downto 0)
    );
  end component sfp_interfaces;

  component clk_wiz_design is           --@suppress Xilinx IP
    port(
      clk_50    : out std_logic;
      clk_100   : out std_logic;
      clk_200   : out std_logic;
      -- Status and control signals
      reset     : in  std_logic;
      locked    : out std_logic;
      clk_in1_p : in  std_logic;
      clk_in1_n : in  std_logic
    );
  end component clk_wiz_design;

  component jtag_axi is                 --@suppress Xilinx IP
    port(
      aclk          : in  std_logic;
      aresetn       : in  std_logic;
      m_axi_awaddr  : out std_logic_vector(31 downto 0);
      m_axi_awprot  : out std_logic_vector(2 downto 0);
      m_axi_awvalid : out std_logic;
      m_axi_awready : in  std_logic;
      m_axi_wdata   : out std_logic_vector(31 downto 0);
      m_axi_wstrb   : out std_logic_vector(3 downto 0);
      m_axi_wvalid  : out std_logic;
      m_axi_wready  : in  std_logic;
      m_axi_bresp   : in  std_logic_vector(1 downto 0);
      m_axi_bvalid  : in  std_logic;
      m_axi_bready  : out std_logic;
      m_axi_araddr  : out std_logic_vector(31 downto 0);
      m_axi_arprot  : out std_logic_vector(2 downto 0);
      m_axi_arvalid : out std_logic;
      m_axi_arready : in  std_logic;
      m_axi_rdata   : in  std_logic_vector(31 downto 0);
      m_axi_rresp   : in  std_logic_vector(1 downto 0);
      m_axi_rvalid  : in  std_logic;
      m_axi_rready  : out std_logic
    );
  end component jtag_axi;

  component main_demo_registers_itf
    port(
      S_AXI_ACLK        : in  std_logic;
      S_AXI_ARESET      : in  std_logic;
      S_AXI_AWADDR      : in  std_logic_vector(7 downto 0);
      S_AXI_AWVALID     : in  std_logic_vector(0 downto 0);
      S_AXI_AWREADY     : out std_logic_vector(0 downto 0);
      S_AXI_WDATA       : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID      : in  std_logic_vector(0 downto 0);
      S_AXI_WSTRB       : in  std_logic_vector(3 downto 0);
      S_AXI_WREADY      : out std_logic_vector(0 downto 0);
      S_AXI_BRESP       : out std_logic_vector(1 downto 0);
      S_AXI_BVALID      : out std_logic_vector(0 downto 0);
      S_AXI_BREADY      : in  std_logic_vector(0 downto 0);
      S_AXI_ARADDR      : in  std_logic_vector(7 downto 0);
      S_AXI_ARVALID     : in  std_logic_vector(0 downto 0);
      S_AXI_ARREADY     : out std_logic_vector(0 downto 0);
      S_AXI_RDATA       : out std_logic_vector(31 downto 0);
      S_AXI_RRESP       : out std_logic_vector(1 downto 0);
      S_AXI_RVALID      : out std_logic_vector(0 downto 0);
      S_AXI_RREADY      : in  std_logic_vector(0 downto 0);
      VERSION           : in  std_logic_vector(7 downto 0);
      REVISION          : in  std_logic_vector(7 downto 0);
      DEBUG             : in  std_logic_vector(11 downto 0);
      BOARD_ID          : in  std_logic_vector(3 downto 0);
      UOE_10G_TARGET_IP : out std_logic_vector(31 downto 0);
      UOE_10G_PORT_SRC  : out std_logic_vector(15 downto 0);
      UOE_1G_TARGET_IP  : out std_logic_vector(31 downto 0);
      UOE_1G_PORT_SRC   : out std_logic_vector(15 downto 0)
    );
  end component main_demo_registers_itf;

  -------------------------------------
  -- Constant declaration
  -------------------------------------

  constant C_DEMO_VERSION  : std_logic_vector(7 downto 0)  := x"00";
  constant C_DEMO_REVISION : std_logic_vector(7 downto 0)  := x"03";
  constant C_DEMO_DEBUG    : std_logic_vector(11 downto 0) := x"000";

  constant C_AXI_ADDR_WIDTH : integer := 16;
  constant C_AXI_DATA_WIDTH : integer := 32;
  constant C_AXI_STRB_WIDTH : integer := C_AXI_DATA_WIDTH / 8;

  constant C_NB_MASTER : integer := 2;
  constant C_NB_SLAVE  : integer := 3;

  constant C_IDX_MASTER_JTAG2AXI : integer := 0;
  constant C_IDX_MASTER_UART     : integer := 1;

  constant C_IDX_SLAVE_UOE_10G   : integer := 0;
  constant C_IDX_SLAVE_UOE_1G    : integer := 1;
  constant C_IDX_SLAVE_MAIN_REGS : integer := 2;

  -------------------------------------
  -- Signals declaration
  -------------------------------------

  -- clock and reset
  signal clk_50_mhz  : std_logic;
  signal clk_100_mhz : std_logic;

  signal rx_rst   : std_logic;
  signal tx_rst   : std_logic;
  signal rx_rst_n : std_logic;
  signal tx_rst_n : std_logic;

  signal sys_clk   : std_logic;
  signal sys_rst   : std_logic;
  signal sys_rst_n : std_logic;

  -- Board ID
  signal board_id : std_logic_vector(3 downto 0);

  -- PCS PMA from/to UOE
  signal axis_rx_aclk   : std_logic_vector(1 downto 0);
  signal axis_rx_rst    : std_logic_vector(1 downto 0);
  signal axis_rx_tdata  : std_logic_vector(127 downto 0);
  signal axis_rx_tkeep  : std_logic_vector(15 downto 0);
  signal axis_rx_tvalid : std_logic_vector(1 downto 0);
  signal axis_rx_tuser  : std_logic_vector(1 downto 0);
  signal axis_rx_tlast  : std_logic_vector(1 downto 0);

  signal axis_tx_aclk   : std_logic_vector(1 downto 0);
  signal axis_tx_rst    : std_logic_vector(1 downto 0);
  signal axis_tx_tdata  : std_logic_vector(127 downto 0);
  signal axis_tx_tkeep  : std_logic_vector(15 downto 0);
  signal axis_tx_tvalid : std_logic_vector(1 downto 0);
  signal axis_tx_tlast  : std_logic_vector(1 downto 0);
  signal axis_tx_tuser  : std_logic_vector(1 downto 0);
  signal axis_tx_tready : std_logic_vector(1 downto 0);

  -- UDP UOE 1G
  signal axis_rx_1g_tdata  : std_logic_vector(31 downto 0);
  signal axis_rx_1g_tkeep  : std_logic_vector(3 downto 0);
  signal axis_rx_1g_tvalid : std_logic;
  signal axis_rx_1g_tuser  : std_logic_vector(79 downto 0);
  signal axis_rx_1g_tlast  : std_logic;
  signal axis_rx_1g_tready : std_logic;

  signal axis_rx_1g_64b_tdata  : std_logic_vector(63 downto 0);
  signal axis_rx_1g_64b_tkeep  : std_logic_vector(7 downto 0);
  signal axis_rx_1g_64b_tvalid : std_logic;
  signal axis_rx_1g_64b_tuser  : std_logic_vector(31 downto 0);
  signal axis_rx_1g_64b_tlast  : std_logic;
  signal axis_rx_1g_64b_tready : std_logic;

  signal axis_tx_1g_64b_tdata  : std_logic_vector(63 downto 0);
  signal axis_tx_1g_64b_tkeep  : std_logic_vector(7 downto 0);
  signal axis_tx_1g_64b_tvalid : std_logic;
  signal axis_tx_1g_64b_tlast  : std_logic;
  signal axis_tx_1g_64b_tuser  : std_logic_vector(31 downto 0);
  signal axis_tx_1g_64b_tready : std_logic;

  signal axis_tx_1g_tdata  : std_logic_vector(31 downto 0);
  signal axis_tx_1g_tkeep  : std_logic_vector(3 downto 0);
  signal axis_tx_1g_tvalid : std_logic;
  signal axis_tx_1g_tlast  : std_logic;
  signal axis_tx_1g_tuser  : std_logic_vector(79 downto 0);
  signal axis_tx_1g_tready : std_logic;

  -- UDP UOE 10G
  signal axis_rx_10g_tdata  : std_logic_vector(63 downto 0);
  signal axis_rx_10g_tkeep  : std_logic_vector(7 downto 0);
  signal axis_rx_10g_tvalid : std_logic;
  signal axis_rx_10g_tuser  : std_logic_vector(79 downto 0);
  signal axis_rx_10g_tlast  : std_logic;
  signal axis_rx_10g_tready : std_logic;

  signal axis_tx_10g_tdata  : std_logic_vector(63 downto 0);
  signal axis_tx_10g_tkeep  : std_logic_vector(7 downto 0);
  signal axis_tx_10g_tvalid : std_logic;
  signal axis_tx_10g_tlast  : std_logic;
  signal axis_tx_10g_tuser  : std_logic_vector(79 downto 0);
  signal axis_tx_10g_tready : std_logic;

  -- PCS/PMA Debug
  signal sfp_mod_def0       : std_logic_vector(1 downto 0);
  signal phy_layer_ready    : std_logic_vector(1 downto 0);
  signal status_vector_sfp  : std_logic_vector(31 downto 0);
  signal dbg_loopback_en    : std_logic;
  signal dbg_clk_phy_active : std_logic_vector(1 downto 0);
  signal locked             : std_logic;

  -- UOE Interrupt
  signal interrupt_1g  : std_logic_vector(1 downto 0);
  signal interrupt_10g : std_logic_vector(1 downto 0);

  -- Uart to bridge ascii
  signal uart_rx_sync : std_logic;

  signal axis_uart_dr_tdata  : std_logic_vector(7 downto 0);
  signal axis_uart_dr_tvalid : std_logic;
  signal axis_uart_dr_tready : std_logic;

  signal axis_uart_dx_tdata  : std_logic_vector(7 downto 0);
  signal axis_uart_dx_tvalid : std_logic;
  signal axis_uart_dx_tready : std_logic;

  -- Switch Input
  -- 0 => JTAG to AXI output, 1 => Uart
  signal axi_jtag2axi_awaddr : std_logic_vector(31 downto 0);
  signal axi_jtag2axi_araddr : std_logic_vector(31 downto 0);

  signal axi_switch_in_awaddr  : std_logic_vector((C_NB_MASTER * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_switch_in_awvalid : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_awready : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_wdata   : std_logic_vector((C_NB_MASTER * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_switch_in_wstrb   : std_logic_vector((C_NB_MASTER * C_AXI_STRB_WIDTH) - 1 downto 0);
  signal axi_switch_in_wvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_wready  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_bresp   : std_logic_vector((C_NB_MASTER * 2) - 1 downto 0);
  signal axi_switch_in_bvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_bready  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_araddr  : std_logic_vector((C_NB_MASTER * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_switch_in_arvalid : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_arready : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_rdata   : std_logic_vector((C_NB_MASTER * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_switch_in_rvalid  : std_logic_vector(C_NB_MASTER - 1 downto 0);
  signal axi_switch_in_rresp   : std_logic_vector((C_NB_MASTER * 2) - 1 downto 0);
  signal axi_switch_in_rready  : std_logic_vector(C_NB_MASTER - 1 downto 0);

  -- Switch output
  -- 0 => UOE 10G, 1 => UOE 1G
  signal axi_switch_out_awaddr  : std_logic_vector((C_NB_SLAVE * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_switch_out_awvalid : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_awready : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_wdata   : std_logic_vector((C_NB_SLAVE * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_switch_out_wstrb   : std_logic_vector((C_NB_SLAVE * C_AXI_STRB_WIDTH) - 1 downto 0);
  signal axi_switch_out_wvalid  : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_wready  : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_bresp   : std_logic_vector((C_NB_SLAVE * 2) - 1 downto 0);
  signal axi_switch_out_bvalid  : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_bready  : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_araddr  : std_logic_vector((C_NB_SLAVE * C_AXI_ADDR_WIDTH) - 1 downto 0);
  signal axi_switch_out_arvalid : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_arready : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_rdata   : std_logic_vector((C_NB_SLAVE * C_AXI_DATA_WIDTH) - 1 downto 0);
  signal axi_switch_out_rvalid  : std_logic_vector(C_NB_SLAVE - 1 downto 0);
  signal axi_switch_out_rresp   : std_logic_vector((C_NB_SLAVE * 2) - 1 downto 0);
  signal axi_switch_out_rready  : std_logic_vector(C_NB_SLAVE - 1 downto 0);

  -- Registers
  signal reg_uoe_10g_target_ip : std_logic_vector(31 downto 0);
  signal reg_uoe_10g_port_src  : std_logic_vector(15 downto 0);
  signal reg_uoe_10g_port_dest : std_logic_vector(15 downto 0);
  signal reg_uoe_1g_target_ip  : std_logic_vector(31 downto 0);
  signal reg_uoe_1g_port_src   : std_logic_vector(15 downto 0);
  signal reg_uoe_1g_port_dest  : std_logic_vector(15 downto 0);

begin

  -- Async Reset
  rx_rst   <= CPU_RESET;
  tx_rst   <= CPU_RESET;
  rx_rst_n <= not CPU_RESET;
  tx_rst_n <= not CPU_RESET;

  -- clocking
  inst_clk_wiz_design : clk_wiz_design
    port map(
      -- Clock out ports
      clk_50    => clk_50_mhz,
      clk_100   => clk_100_mhz,
      clk_200   => sys_clk,
      -- Status and control signals
      reset     => CPU_RESET,
      locked    => locked,
      -- Clock in ports
      clk_in1_p => CLK_125_P,
      clk_in1_n => CLK_125_N
    );

  -- reset sync
  inst_cdc_reset_sync : component cdc_reset_sync
    generic map(
      G_NB_STAGE    => 2,
      G_NB_CLOCK    => 1,
      G_ACTIVE_ARST => '1'
    )
    port map(
      ARST      => CPU_RESET,
      CLK(0)    => sys_clk,
      SRST(0)   => sys_rst,
      SRST_N(0) => sys_rst_n
    );

  -- SFP interfaces
  inst_sfp_interfaces : sfp_interfaces
    generic map(
      G_DEBUG => true
    )
    port map(
      GT_REFCLK_P        => SFP_REFCLK_P,
      GT_REFCLK_N        => SFP_REFCLK_N,
      CLK_50_MHZ         => clk_50_mhz,
      CLK_100_MHZ        => clk_100_mhz,
      SYS_RST            => sys_rst,
      SYS_RST_N          => sys_rst_n,
      RX_RST             => rx_rst,
      TX_RST             => tx_rst,
      RX_RST_N           => rx_rst_n,
      TX_RST_N           => tx_rst_n,
      SFP_TX_N           => SFP_TX_N,
      SFP_TX_P           => SFP_TX_P,
      SFP_RX_N           => SFP_RX_N,
      SFP_RX_P           => SFP_RX_P,
      M_RX_ACLK          => axis_rx_aclk,
      M_RX_RST           => axis_rx_rst,
      M_RX_TDATA         => axis_rx_tdata,
      M_RX_TKEEP         => axis_rx_tkeep,
      M_RX_TVALID        => axis_rx_tvalid,
      M_RX_TUSER         => axis_rx_tuser,
      M_RX_TLAST         => axis_rx_tlast,
      S_TX_ACLK          => axis_tx_aclk,
      S_TX_RST           => axis_tx_rst,
      S_TX_TDATA         => axis_tx_tdata,
      S_TX_TKEEP         => axis_tx_tkeep,
      S_TX_TVALID        => axis_tx_tvalid,
      S_TX_TLAST         => axis_tx_tlast,
      S_TX_TUSER         => axis_tx_tuser,
      S_TX_TREADY        => axis_tx_tready,
      SFP_MOD_DEF0       => sfp_mod_def0,
      SFP_RX_LOS         => SFP_LOS,
      PHY_LAYER_READY    => phy_layer_ready,
      STATUS_VECTOR_SFP  => status_vector_sfp,
      DBG_LOOPBACK_EN    => dbg_loopback_en,
      DBG_CLK_PHY_ACTIVE => dbg_clk_phy_active
    );

  -- UOE connection
  -- Interface 0 : 10G
  -- Interface 1 : 1G

  -------------------------------------------------------------------------------
  -- UOE 10G
  -------------------------------------------------------------------------------

  inst_top_uoe_10g : component top_uoe
    generic map(
      G_ACTIVE_RST          => '1',
      G_ASYNC_RST           => false,
      G_ENABLE_ARP_MODULE   => true,
      G_ENABLE_ARP_TABLE    => true,
      G_ENABLE_TESTENV      => true,
      G_ENABLE_PKT_DROP_EXT => true,
      G_ENABLE_PKT_DROP_RAW => true,
      G_ENABLE_PKT_DROP_UDP => true,
      G_MAC_TDATA_WIDTH     => 64,
      G_UOE_TDATA_WIDTH     => 64,
      G_ROUTER_FIFO_DEPTH   => 8192,
      G_UOE_FREQ_KHZ        => 200000
    )
    port map(
      CLK_RX          => axis_rx_aclk(C_IDX_SLAVE_UOE_10G),
      RST_RX          => axis_rx_rst(C_IDX_SLAVE_UOE_10G),
      CLK_TX          => axis_tx_aclk(C_IDX_SLAVE_UOE_10G),
      RST_TX          => axis_tx_rst(C_IDX_SLAVE_UOE_10G),
      CLK_UOE         => sys_clk,
      RST_UOE         => sys_rst,
      PHY_LAYER_RDY   => phy_layer_ready(C_IDX_SLAVE_UOE_10G),
      INTERRUPT       => interrupt_10g,
      S_MAC_RX_TDATA  => axis_rx_tdata((C_IDX_SLAVE_UOE_10G * 64) + 63 downto (C_IDX_SLAVE_UOE_10G * 64)),
      S_MAC_RX_TVALID => axis_rx_tvalid(C_IDX_SLAVE_UOE_10G),
      S_MAC_RX_TLAST  => axis_rx_tlast(C_IDX_SLAVE_UOE_10G),
      S_MAC_RX_TKEEP  => axis_rx_tkeep((C_IDX_SLAVE_UOE_10G * 8) + 7 downto (C_IDX_SLAVE_UOE_10G * 8)),
      S_MAC_RX_TUSER  => axis_rx_tuser(C_IDX_SLAVE_UOE_10G),
      M_MAC_TX_TDATA  => axis_tx_tdata((C_IDX_SLAVE_UOE_10G * 64) + 63 downto (C_IDX_SLAVE_UOE_10G * 64)),
      M_MAC_TX_TVALID => axis_tx_tvalid(C_IDX_SLAVE_UOE_10G),
      M_MAC_TX_TLAST  => axis_tx_tlast(C_IDX_SLAVE_UOE_10G),
      M_MAC_TX_TKEEP  => axis_tx_tkeep((C_IDX_SLAVE_UOE_10G * 8) + 7 downto (C_IDX_SLAVE_UOE_10G * 8)),
      M_MAC_TX_TUSER  => axis_tx_tuser(C_IDX_SLAVE_UOE_10G),
      M_MAC_TX_TREADY => axis_tx_tready(C_IDX_SLAVE_UOE_10G),
      S_EXT_TX_TDATA  => (others => '0'),
      S_EXT_TX_TVALID => '0',
      S_EXT_TX_TLAST  => '0',
      S_EXT_TX_TKEEP  => (others => '0'),
      S_EXT_TX_TREADY => open,
      M_EXT_RX_TDATA  => open,
      M_EXT_RX_TVALID => open,
      M_EXT_RX_TLAST  => open,
      M_EXT_RX_TKEEP  => open,
      M_EXT_RX_TREADY => '1',
      S_RAW_TX_TDATA  => (others => '0'),
      S_RAW_TX_TVALID => '0',
      S_RAW_TX_TLAST  => '0',
      S_RAW_TX_TKEEP  => (others => '0'),
      S_RAW_TX_TUSER  => (others => '0'),
      S_RAW_TX_TREADY => open,
      M_RAW_RX_TDATA  => open,
      M_RAW_RX_TVALID => open,
      M_RAW_RX_TLAST  => open,
      M_RAW_RX_TKEEP  => open,
      M_RAW_RX_TUSER  => open,
      M_RAW_RX_TREADY => '1',
      S_UDP_TX_TDATA  => axis_tx_10g_tdata,
      S_UDP_TX_TVALID => axis_tx_10g_tvalid,
      S_UDP_TX_TLAST  => axis_tx_10g_tlast,
      S_UDP_TX_TKEEP  => axis_tx_10g_tkeep,
      S_UDP_TX_TUSER  => axis_tx_10g_tuser,
      S_UDP_TX_TREADY => axis_tx_10g_tready,
      M_UDP_RX_TDATA  => axis_rx_10g_tdata,
      M_UDP_RX_TVALID => axis_rx_10g_tvalid,
      M_UDP_RX_TLAST  => axis_rx_10g_tlast,
      M_UDP_RX_TKEEP  => axis_rx_10g_tkeep,
      M_UDP_RX_TUSER  => axis_rx_10g_tuser,
      M_UDP_RX_TREADY => axis_rx_10g_tready,
      S_AXI_AWADDR    => axi_switch_out_awaddr((C_IDX_SLAVE_UOE_10G * C_AXI_ADDR_WIDTH) + 13 downto (C_IDX_SLAVE_UOE_10G * C_AXI_ADDR_WIDTH)),
      S_AXI_AWVALID   => axi_switch_out_awvalid(C_IDX_SLAVE_UOE_10G),
      S_AXI_AWREADY   => axi_switch_out_awready(C_IDX_SLAVE_UOE_10G),
      S_AXI_WDATA     => axi_switch_out_wdata((C_IDX_SLAVE_UOE_10G * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_UOE_10G * C_AXI_DATA_WIDTH)),
      S_AXI_WVALID    => axi_switch_out_wvalid(C_IDX_SLAVE_UOE_10G),
      S_AXI_WSTRB     => axi_switch_out_wstrb((C_IDX_SLAVE_UOE_10G * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_SLAVE_UOE_10G * C_AXI_STRB_WIDTH)),
      S_AXI_WREADY    => axi_switch_out_wready(C_IDX_SLAVE_UOE_10G),
      S_AXI_BRESP     => axi_switch_out_bresp((C_IDX_SLAVE_UOE_10G * 2) + 1 downto (C_IDX_SLAVE_UOE_10G * 2)),
      S_AXI_BVALID    => axi_switch_out_bvalid(C_IDX_SLAVE_UOE_10G),
      S_AXI_BREADY    => axi_switch_out_bready(C_IDX_SLAVE_UOE_10G),
      S_AXI_ARADDR    => axi_switch_out_araddr((C_IDX_SLAVE_UOE_10G * C_AXI_ADDR_WIDTH) + 13 downto (C_IDX_SLAVE_UOE_10G * C_AXI_ADDR_WIDTH)),
      S_AXI_ARVALID   => axi_switch_out_arvalid(C_IDX_SLAVE_UOE_10G),
      S_AXI_ARREADY   => axi_switch_out_arready(C_IDX_SLAVE_UOE_10G),
      S_AXI_RDATA     => axi_switch_out_rdata((C_IDX_SLAVE_UOE_10G * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_UOE_10G * C_AXI_DATA_WIDTH)),
      S_AXI_RRESP     => axi_switch_out_rresp((C_IDX_SLAVE_UOE_10G * 2) + 1 downto (C_IDX_SLAVE_UOE_10G * 2)),
      S_AXI_RVALID    => axi_switch_out_rvalid(C_IDX_SLAVE_UOE_10G),
      S_AXI_RREADY    => axi_switch_out_rready(C_IDX_SLAVE_UOE_10G)
    );

  -------------------------------------------------------------------------------
  -- UOE 1G
  -------------------------------------------------------------------------------

  inst_top_uoe_1g : component top_uoe
    generic map(
      G_ACTIVE_RST          => '1',
      G_ASYNC_RST           => false,
      G_ENABLE_ARP_MODULE   => true,
      G_ENABLE_ARP_TABLE    => true,
      G_ENABLE_TESTENV      => true,
      G_ENABLE_PKT_DROP_EXT => true,
      G_ENABLE_PKT_DROP_RAW => true,
      G_ENABLE_PKT_DROP_UDP => true,
      G_MAC_TDATA_WIDTH     => 8,
      G_UOE_TDATA_WIDTH     => 32,
      G_ROUTER_FIFO_DEPTH   => 8192,
      G_UOE_FREQ_KHZ        => 200000
    )
    port map(
      CLK_RX          => axis_rx_aclk(C_IDX_SLAVE_UOE_1G),
      RST_RX          => axis_rx_rst(C_IDX_SLAVE_UOE_1G),
      CLK_TX          => axis_tx_aclk(C_IDX_SLAVE_UOE_1G),
      RST_TX          => axis_tx_rst(C_IDX_SLAVE_UOE_1G),
      CLK_UOE         => sys_clk,
      RST_UOE         => sys_rst,
      PHY_LAYER_RDY   => phy_layer_ready(C_IDX_SLAVE_UOE_1G),
      INTERRUPT       => interrupt_1g,
      S_MAC_RX_TDATA  => axis_rx_tdata((C_IDX_SLAVE_UOE_1G * 64) + 7 downto (C_IDX_SLAVE_UOE_1G * 64)),
      S_MAC_RX_TVALID => axis_rx_tvalid(C_IDX_SLAVE_UOE_1G),
      S_MAC_RX_TLAST  => axis_rx_tlast(C_IDX_SLAVE_UOE_1G),
      S_MAC_RX_TKEEP  => axis_rx_tkeep((C_IDX_SLAVE_UOE_1G * 8) + 0 downto (C_IDX_SLAVE_UOE_1G * 8)),
      S_MAC_RX_TUSER  => axis_rx_tuser(C_IDX_SLAVE_UOE_1G),
      M_MAC_TX_TDATA  => axis_tx_tdata((C_IDX_SLAVE_UOE_1G * 64) + 7 downto (C_IDX_SLAVE_UOE_1G * 64)),
      M_MAC_TX_TVALID => axis_tx_tvalid(C_IDX_SLAVE_UOE_1G),
      M_MAC_TX_TLAST  => axis_tx_tlast(C_IDX_SLAVE_UOE_1G),
      M_MAC_TX_TKEEP  => axis_tx_tkeep((C_IDX_SLAVE_UOE_1G * 8) + 0 downto (C_IDX_SLAVE_UOE_1G * 8)),
      M_MAC_TX_TUSER  => axis_tx_tuser(C_IDX_SLAVE_UOE_1G),
      M_MAC_TX_TREADY => axis_tx_tready(C_IDX_SLAVE_UOE_1G),
      S_EXT_TX_TDATA  => (others => '0'),
      S_EXT_TX_TVALID => '0',
      S_EXT_TX_TLAST  => '0',
      S_EXT_TX_TKEEP  => (others => '0'),
      S_EXT_TX_TREADY => open,
      M_EXT_RX_TDATA  => open,
      M_EXT_RX_TVALID => open,
      M_EXT_RX_TLAST  => open,
      M_EXT_RX_TKEEP  => open,
      M_EXT_RX_TREADY => '1',
      S_RAW_TX_TDATA  => (others => '0'),
      S_RAW_TX_TVALID => '0',
      S_RAW_TX_TLAST  => '0',
      S_RAW_TX_TKEEP  => (others => '0'),
      S_RAW_TX_TUSER  => (others => '0'),
      S_RAW_TX_TREADY => open,
      M_RAW_RX_TDATA  => open,
      M_RAW_RX_TVALID => open,
      M_RAW_RX_TLAST  => open,
      M_RAW_RX_TKEEP  => open,
      M_RAW_RX_TUSER  => open,
      M_RAW_RX_TREADY => '1',
      S_UDP_TX_TDATA  => axis_tx_1g_tdata,
      S_UDP_TX_TVALID => axis_tx_1g_tvalid,
      S_UDP_TX_TLAST  => axis_tx_1g_tlast,
      S_UDP_TX_TKEEP  => axis_tx_1g_tkeep,
      S_UDP_TX_TUSER  => axis_tx_1g_tuser,
      S_UDP_TX_TREADY => axis_tx_1g_tready,
      M_UDP_RX_TDATA  => axis_rx_1g_tdata,
      M_UDP_RX_TVALID => axis_rx_1g_tvalid,
      M_UDP_RX_TLAST  => axis_rx_1g_tlast,
      M_UDP_RX_TKEEP  => axis_rx_1g_tkeep,
      M_UDP_RX_TUSER  => axis_rx_1g_tuser,
      M_UDP_RX_TREADY => axis_rx_1g_tready,
      S_AXI_AWADDR    => axi_switch_out_awaddr((C_IDX_SLAVE_UOE_1G * C_AXI_ADDR_WIDTH) + 13 downto (C_IDX_SLAVE_UOE_1G * C_AXI_ADDR_WIDTH)),
      S_AXI_AWVALID   => axi_switch_out_awvalid(C_IDX_SLAVE_UOE_1G),
      S_AXI_AWREADY   => axi_switch_out_awready(C_IDX_SLAVE_UOE_1G),
      S_AXI_WDATA     => axi_switch_out_wdata((C_IDX_SLAVE_UOE_1G * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_UOE_1G * C_AXI_DATA_WIDTH)),
      S_AXI_WVALID    => axi_switch_out_wvalid(C_IDX_SLAVE_UOE_1G),
      S_AXI_WSTRB     => axi_switch_out_wstrb((C_IDX_SLAVE_UOE_1G * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_SLAVE_UOE_1G * C_AXI_STRB_WIDTH)),
      S_AXI_WREADY    => axi_switch_out_wready(C_IDX_SLAVE_UOE_1G),
      S_AXI_BRESP     => axi_switch_out_bresp((C_IDX_SLAVE_UOE_1G * 2) + 1 downto (C_IDX_SLAVE_UOE_1G * 2)),
      S_AXI_BVALID    => axi_switch_out_bvalid(C_IDX_SLAVE_UOE_1G),
      S_AXI_BREADY    => axi_switch_out_bready(C_IDX_SLAVE_UOE_1G),
      S_AXI_ARADDR    => axi_switch_out_araddr((C_IDX_SLAVE_UOE_1G * C_AXI_ADDR_WIDTH) + 13 downto (C_IDX_SLAVE_UOE_1G * C_AXI_ADDR_WIDTH)),
      S_AXI_ARVALID   => axi_switch_out_arvalid(C_IDX_SLAVE_UOE_1G),
      S_AXI_ARREADY   => axi_switch_out_arready(C_IDX_SLAVE_UOE_1G),
      S_AXI_RDATA     => axi_switch_out_rdata((C_IDX_SLAVE_UOE_1G * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_UOE_1G * C_AXI_DATA_WIDTH)),
      S_AXI_RRESP     => axi_switch_out_rresp((C_IDX_SLAVE_UOE_1G * 2) + 1 downto (C_IDX_SLAVE_UOE_1G * 2)),
      S_AXI_RVALID    => axi_switch_out_rvalid(C_IDX_SLAVE_UOE_1G),
      S_AXI_RREADY    => axi_switch_out_rready(C_IDX_SLAVE_UOE_1G)
    );

  -------------------------------------------------------------------------------
  -- Link 1G to 10G
  -------------------------------------------------------------------------------

  -- Resize bus
  inst_axis_dwidth_converter_1g_to_10g : axis_dwidth_converter
    generic map(
      G_ACTIVE_RST    => '1',
      G_ASYNC_RST     => false,
      G_S_TDATA_WIDTH => 32,
      G_M_TDATA_WIDTH => 64,
      G_TUSER_WIDTH   => 32,
      G_TID_WIDTH     => 1,
      G_TDEST_WIDTH   => 1,
      G_PIPELINE      => true,
      G_LITTLE_ENDIAN => true
    )
    port map(
      CLK                   => sys_clk,
      RST                   => sys_rst,
      S_TDATA               => axis_rx_1g_tdata,
      S_TVALID              => axis_rx_1g_tvalid,
      S_TLAST               => axis_rx_1g_tlast,
      S_TUSER(15 downto 0)  => axis_rx_1g_tuser(47 downto 32), -- Size
      S_TUSER(31 downto 16) => axis_rx_1g_tuser(79 downto 64), -- Port Dest
      S_TSTRB               => (others => '-'),
      S_TKEEP               => axis_rx_1g_tkeep,
      S_TID                 => (others => '-'),
      S_TDEST               => (others => '-'),
      S_TREADY              => axis_rx_1g_tready,
      M_TDATA               => axis_rx_1g_64b_tdata,
      M_TVALID              => axis_rx_1g_64b_tvalid,
      M_TLAST               => axis_rx_1g_64b_tlast,
      M_TUSER               => axis_rx_1g_64b_tuser,
      M_TSTRB               => open,
      M_TKEEP               => axis_rx_1g_64b_tkeep,
      M_TID                 => open,
      M_TDEST               => open,
      M_TREADY              => axis_rx_1g_64b_tready,
      ERR                   => open
    );

  -- CDC
  inst_axis_fifo_cdc_1g_to_10g : axis_fifo
    generic map(
      G_COMMON_CLK  => true,
      G_ADDR_WIDTH  => 9,
      G_TDATA_WIDTH => 64,
      G_TUSER_WIDTH => 32,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 9,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => '1',
      G_ASYNC_RST   => false,
      G_SYNC_STAGE  => 2
    )
    port map(
      S_CLK                 => sys_clk,
      S_RST                 => sys_rst,
      S_TDATA               => axis_rx_1g_64b_tdata,
      S_TVALID              => axis_rx_1g_64b_tvalid,
      S_TLAST               => axis_rx_1g_64b_tlast,
      S_TUSER               => axis_rx_1g_64b_tuser,
      S_TSTRB               => (others => '-'),
      S_TKEEP               => axis_rx_1g_64b_tkeep,
      S_TID                 => (others => '-'),
      S_TDEST               => (others => '-'),
      S_TREADY              => axis_rx_1g_64b_tready,
      M_CLK                 => sys_clk,
      M_TDATA               => axis_tx_10g_tdata,
      M_TVALID              => axis_tx_10g_tvalid,
      M_TLAST               => axis_tx_10g_tlast,
      M_TUSER(15 downto 0)  => axis_tx_10g_tuser(47 downto 32), -- Size
      M_TUSER(31 downto 16) => reg_uoe_10g_port_dest,
      M_TSTRB               => open,
      M_TKEEP               => axis_tx_10g_tkeep,
      M_TID                 => open,
      M_TDEST               => open,
      M_TREADY              => axis_tx_10g_tready
    );

  axis_tx_10g_tuser(31 downto 0)  <= reg_uoe_10g_target_ip;
  axis_tx_10g_tuser(63 downto 48) <= reg_uoe_10g_port_src;
  axis_tx_10g_tuser(79 downto 64) <= std_logic_vector(unsigned(reg_uoe_10g_port_dest) + 100);

  -------------------------------------------------------------------------------
  -- Link 10G to 1G
  -------------------------------------------------------------------------------

  -- CDC
  inst_axis_fifo_cdc_10g_to_1g : axis_fifo
    generic map(
      G_COMMON_CLK  => true,
      G_ADDR_WIDTH  => 9,
      G_TDATA_WIDTH => 64,
      G_TUSER_WIDTH => 32,
      G_TID_WIDTH   => 1,
      G_TDEST_WIDTH => 1,
      G_PKT_WIDTH   => 9,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => '1',
      G_ASYNC_RST   => false,
      G_SYNC_STAGE  => 2
    )
    port map(
      S_CLK                 => sys_clk,
      S_RST                 => sys_rst,
      S_TDATA               => axis_rx_10g_tdata,
      S_TVALID              => axis_rx_10g_tvalid,
      S_TLAST               => axis_rx_10g_tlast,
      S_TUSER(15 downto 0)  => axis_rx_10g_tuser(47 downto 32),
      S_TUSER(31 downto 16) => axis_rx_10g_tuser(79 downto 64),
      S_TSTRB               => (others => '-'),
      S_TKEEP               => axis_rx_10g_tkeep,
      S_TID                 => (others => '-'),
      S_TDEST               => (others => '-'),
      S_TREADY              => axis_rx_10g_tready,
      M_CLK                 => sys_clk,
      M_TDATA               => axis_tx_1g_64b_tdata,
      M_TVALID              => axis_tx_1g_64b_tvalid,
      M_TLAST               => axis_tx_1g_64b_tlast,
      M_TUSER               => axis_tx_1g_64b_tuser,
      M_TSTRB               => open,
      M_TKEEP               => axis_tx_1g_64b_tkeep,
      M_TID                 => open,
      M_TDEST               => open,
      M_TREADY              => axis_tx_1g_64b_tready
    );

  -- Resize bus
  inst_axis_dwidth_converter_ch2 : axis_dwidth_converter
    generic map(
      G_ACTIVE_RST    => '1',
      G_ASYNC_RST     => false,
      G_S_TDATA_WIDTH => 64,
      G_M_TDATA_WIDTH => 32,
      G_TUSER_WIDTH   => 32,
      G_TID_WIDTH     => 1,
      G_TDEST_WIDTH   => 1,
      G_PIPELINE      => true,
      G_LITTLE_ENDIAN => true
    )
    port map(
      CLK                   => sys_clk,
      RST                   => sys_rst,
      S_TDATA               => axis_tx_1g_64b_tdata,
      S_TVALID              => axis_tx_1g_64b_tvalid,
      S_TLAST               => axis_tx_1g_64b_tlast,
      S_TUSER               => axis_tx_1g_64b_tuser,
      S_TSTRB               => (others => '-'),
      S_TKEEP               => axis_tx_1g_64b_tkeep,
      S_TID                 => (others => '-'),
      S_TDEST               => (others => '-'),
      S_TREADY              => axis_tx_1g_64b_tready,
      M_TDATA               => axis_tx_1g_tdata,
      M_TVALID              => axis_tx_1g_tvalid,
      M_TLAST               => axis_tx_1g_tlast,
      M_TUSER(15 downto 0)  => axis_tx_1g_tuser(47 downto 32),
      M_TUSER(31 downto 16) => reg_uoe_1g_port_dest,
      M_TSTRB               => open,
      M_TKEEP               => axis_tx_1g_tkeep,
      M_TID                 => open,
      M_TDEST               => open,
      M_TREADY              => axis_tx_1g_tready,
      ERR                   => open
    );

  axis_tx_1g_tuser(31 downto 0)  <= reg_uoe_1g_target_ip;
  axis_tx_1g_tuser(63 downto 48) <= reg_uoe_1g_port_src;
  axis_tx_1g_tuser(79 downto 64) <= std_logic_vector(unsigned(reg_uoe_1g_port_dest) + 100);

  -------------------------------------------------------------------------------
  -- JTAG2AXI
  -------------------------------------------------------------------------------

  inst_jtag_axi : component jtag_axi
    port map(
      aclk          => sys_clk,
      aresetn       => sys_rst_n,
      m_axi_awaddr  => axi_jtag2axi_awaddr,
      m_axi_awprot  => open,
      m_axi_awvalid => axi_switch_in_awvalid(C_IDX_MASTER_JTAG2AXI),
      m_axi_awready => axi_switch_in_awready(C_IDX_MASTER_JTAG2AXI),
      m_axi_wdata   => axi_switch_in_wdata((C_IDX_MASTER_JTAG2AXI * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MASTER_JTAG2AXI * C_AXI_DATA_WIDTH)),
      m_axi_wstrb   => axi_switch_in_wstrb((C_IDX_MASTER_JTAG2AXI * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_MASTER_JTAG2AXI * C_AXI_STRB_WIDTH)),
      m_axi_wvalid  => axi_switch_in_wvalid(C_IDX_MASTER_JTAG2AXI),
      m_axi_wready  => axi_switch_in_wready(C_IDX_MASTER_JTAG2AXI),
      m_axi_bresp   => axi_switch_in_bresp((C_IDX_MASTER_JTAG2AXI * 2) + 1 downto (C_IDX_MASTER_JTAG2AXI * 2)),
      m_axi_bvalid  => axi_switch_in_bvalid(C_IDX_MASTER_JTAG2AXI),
      m_axi_bready  => axi_switch_in_bready(C_IDX_MASTER_JTAG2AXI),
      m_axi_araddr  => axi_jtag2axi_araddr,
      m_axi_arprot  => open,
      m_axi_arvalid => axi_switch_in_arvalid(C_IDX_MASTER_JTAG2AXI),
      m_axi_arready => axi_switch_in_arready(C_IDX_MASTER_JTAG2AXI),
      m_axi_rdata   => axi_switch_in_rdata((C_IDX_MASTER_JTAG2AXI * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MASTER_JTAG2AXI * C_AXI_DATA_WIDTH)),
      m_axi_rresp   => axi_switch_in_rresp((C_IDX_MASTER_JTAG2AXI * 2) + 1 downto (C_IDX_MASTER_JTAG2AXI * 2)),
      m_axi_rvalid  => axi_switch_in_rvalid(C_IDX_MASTER_JTAG2AXI),
      m_axi_rready  => axi_switch_in_rready(C_IDX_MASTER_JTAG2AXI)
    );

  axi_switch_in_awaddr((C_IDX_MASTER_JTAG2AXI * C_AXI_ADDR_WIDTH) + 15 downto (C_IDX_MASTER_JTAG2AXI * C_AXI_ADDR_WIDTH)) <= axi_jtag2axi_awaddr(15 downto 0);
  axi_switch_in_araddr((C_IDX_MASTER_JTAG2AXI * C_AXI_ADDR_WIDTH) + 15 downto (C_IDX_MASTER_JTAG2AXI * C_AXI_ADDR_WIDTH)) <= axi_jtag2axi_araddr(15 downto 0);

  -------------------------------------------------------------------------------
  -- UART Interface + Bridge_ascii
  -------------------------------------------------------------------------------

  -- Resynchronization of uart_rx
  inst_cdc_bit_sync_uart_rx : cdc_bit_sync
    generic map(
      G_NB_STAGE   => 2,
      G_ACTIVE_RST => '1',
      G_ASYNC_RST  => false,
      G_RST_VALUE  => '1'
    )
    port map(
      -- asynchronous domain
      DATA_ASYNC => UART_RX,
      -- synchronous domain
      CLK        => sys_clk,
      RST        => sys_rst,
      DATA_SYNC  => uart_rx_sync
    );

  inst_uart_if : uart_if
    generic map(
      G_CLK_FREQ   => 200.0,
      G_ACTIVE_RST => '1',
      G_ASYNC_RST  => false,
      G_SIMU       => false
    )
    port map(
      -- Global
      RST                 => sys_rst,
      CLK                 => sys_clk,
      -- Control
      CFG_BAUDRATE        => C_UART_115200_BAUDS,
      CFG_BIT_STOP        => C_UART_ONE_STOP_BIT,
      CFG_PARITY_ON_OFF   => C_UART_PARITY_OFF,
      CFG_PARITY_ODD_EVEN => C_UART_PARITY_EVEN,
      CFG_USE_PROTOCOL    => '0',
      CFG_SIZE            => C_UART_NB_BIT_EIGHT,
      -- User Domain
      DX_TDATA            => axis_uart_dx_tdata,
      DX_TVALID           => axis_uart_dx_tvalid,
      DX_TREADY           => axis_uart_dx_tready,
      DR_TDATA            => axis_uart_dr_tdata,
      DR_TVALID           => axis_uart_dr_tvalid,
      DR_TREADY           => axis_uart_dr_tready,
      DR_TUSER            => open,
      ERROR_DATA_DROP     => open,
      -- Physical Interface
      TXD                 => UART_TX,
      RXD                 => uart_rx_sync,
      RTS                 => open,
      CTS                 => open
    );

  -- BRIDGE
  inst_bridge_ascii_to_axi4lite : bridge_ascii_to_axi4lite
    generic map(
      G_ACTIVE_RST     => '0',
      G_ASYNC_RST      => false,
      G_AXI_DATA_WIDTH => 32,
      G_AXI_ADDR_WIDTH => 16
    )
    port map(
      -- BASIC SIGNALS
      CLK            => sys_clk,
      RST            => sys_rst_n,
      -- SLAVE AXIS
      S_AXIS_TDATA   => axis_uart_dr_tdata,
      S_AXIS_TVALID  => axis_uart_dr_tvalid,
      S_AXIS_TREADY  => axis_uart_dr_tready,
      -- MASTER AXIS
      M_AXIS_TDATA   => axis_uart_dx_tdata,
      M_AXIS_TVALID  => axis_uart_dx_tvalid,
      M_AXIS_TREADY  => axis_uart_dx_tready,
      -- MASTER AXI4-LITE
      -- -- ADDRESS WRITE (AR)
      M_AXIL_AWADDR  => axi_switch_in_awaddr((C_IDX_MASTER_UART * C_AXI_ADDR_WIDTH) + 15 downto (C_IDX_MASTER_UART * C_AXI_ADDR_WIDTH)),
      M_AXIL_AWPROT  => open,
      M_AXIL_AWVALID => axi_switch_in_awvalid(C_IDX_MASTER_UART),
      M_AXIL_AWREADY => axi_switch_in_awready(C_IDX_MASTER_UART),
      -- -- WRITE (W)
      M_AXIL_WDATA   => axi_switch_in_wdata((C_IDX_MASTER_UART * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MASTER_UART * C_AXI_DATA_WIDTH)),
      M_AXIL_WSTRB   => axi_switch_in_wstrb((C_IDX_MASTER_UART * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_MASTER_UART * C_AXI_STRB_WIDTH)),
      M_AXIL_WVALID  => axi_switch_in_wvalid(C_IDX_MASTER_UART),
      M_AXIL_WREADY  => axi_switch_in_wready(C_IDX_MASTER_UART),
      -- -- RESPONSE WRITE (B)
      M_AXIL_BRESP   => axi_switch_in_bresp((C_IDX_MASTER_UART * 2) + 1 downto (C_IDX_MASTER_UART * 2)),
      M_AXIL_BVALID  => axi_switch_in_bvalid(C_IDX_MASTER_UART),
      M_AXIL_BREADY  => axi_switch_in_bready(C_IDX_MASTER_UART),
      -- -- ADDRESS READ (AR)
      M_AXIL_ARADDR  => axi_switch_in_araddr((C_IDX_MASTER_UART * C_AXI_ADDR_WIDTH) + 15 downto (C_IDX_MASTER_UART * C_AXI_ADDR_WIDTH)),
      M_AXIL_ARPROT  => open,
      M_AXIL_ARVALID => axi_switch_in_arvalid(C_IDX_MASTER_UART),
      M_AXIL_ARREADY => axi_switch_in_arready(C_IDX_MASTER_UART),
      -- -- READ (R)
      M_AXIL_RDATA   => axi_switch_in_rdata((C_IDX_MASTER_UART * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_MASTER_UART * C_AXI_DATA_WIDTH)),
      M_AXIL_RVALID  => axi_switch_in_rvalid(C_IDX_MASTER_UART),
      M_AXIL_RRESP   => axi_switch_in_rresp((C_IDX_MASTER_UART * 2) + 1 downto (C_IDX_MASTER_UART * 2)),
      M_AXIL_RREADY  => axi_switch_in_rready(C_IDX_MASTER_UART)
    );

  -------------------------------------------------------------------------------
  -- Switch
  -------------------------------------------------------------------------------

  inst_axi4lite_switch : component axi4lite_switch
    generic map(
      G_ACTIVE_RST  => '1',
      G_ASYNC_RST   => false,
      G_DATA_WIDTH  => C_AXI_DATA_WIDTH,
      G_ADDR_WIDTH  => C_AXI_ADDR_WIDTH,
      G_NB_SLAVE    => C_NB_MASTER,
      G_NB_MASTER   => C_NB_SLAVE,
      G_BASE_ADDR   => ((x"0000"), (x"4000"), (x"8000")),
      G_ADDR_RANGE  => (14, 14, 8),
      G_ROUND_ROBIN => false
    )
    port map(
      CLK       => sys_clk,
      RST       => sys_rst,
      S_AWADDR  => axi_switch_in_awaddr,
      S_AWPROT  => (others => '0'),
      S_AWVALID => axi_switch_in_awvalid,
      S_AWREADY => axi_switch_in_awready,
      S_WDATA   => axi_switch_in_wdata,
      S_WSTRB   => axi_switch_in_wstrb,
      S_WVALID  => axi_switch_in_wvalid,
      S_WREADY  => axi_switch_in_wready,
      S_BRESP   => axi_switch_in_bresp,
      S_BVALID  => axi_switch_in_bvalid,
      S_BREADY  => axi_switch_in_bready,
      S_ARADDR  => axi_switch_in_araddr,
      S_ARPROT  => (others => '0'),
      S_ARVALID => axi_switch_in_arvalid,
      S_ARREADY => axi_switch_in_arready,
      S_RDATA   => axi_switch_in_rdata,
      S_RVALID  => axi_switch_in_rvalid,
      S_RRESP   => axi_switch_in_rresp,
      S_RREADY  => axi_switch_in_rready,
      M_AWADDR  => axi_switch_out_awaddr,
      M_AWPROT  => open,
      M_AWVALID => axi_switch_out_awvalid,
      M_AWREADY => axi_switch_out_awready,
      M_WDATA   => axi_switch_out_wdata,
      M_WSTRB   => axi_switch_out_wstrb,
      M_WVALID  => axi_switch_out_wvalid,
      M_WREADY  => axi_switch_out_wready,
      M_BRESP   => axi_switch_out_bresp,
      M_BVALID  => axi_switch_out_bvalid,
      M_BREADY  => axi_switch_out_bready,
      M_ARADDR  => axi_switch_out_araddr,
      M_ARPROT  => open,
      M_ARVALID => axi_switch_out_arvalid,
      M_ARREADY => axi_switch_out_arready,
      M_RDATA   => axi_switch_out_rdata,
      M_RVALID  => axi_switch_out_rvalid,
      M_RRESP   => axi_switch_out_rresp,
      M_RREADY  => axi_switch_out_rready,
      ERR_RDDEC => open,
      ERR_WRDEC => open
    );

  -------------------------------------------------------------------------------
  -- Registers
  -------------------------------------------------------------------------------
  inst_main_demo_registers_itf : component main_demo_registers_itf
    port map(
      S_AXI_ACLK        => sys_clk,
      S_AXI_ARESET      => sys_rst,
      S_AXI_AWADDR      => axi_switch_out_awaddr((C_IDX_SLAVE_MAIN_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_SLAVE_MAIN_REGS * C_AXI_ADDR_WIDTH)),
      S_AXI_AWVALID(0)  => axi_switch_out_awvalid(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_AWREADY(0)  => axi_switch_out_awready(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_WDATA       => axi_switch_out_wdata((C_IDX_SLAVE_MAIN_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_MAIN_REGS * C_AXI_DATA_WIDTH)),
      S_AXI_WVALID(0)   => axi_switch_out_wvalid(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_WSTRB       => axi_switch_out_wstrb((C_IDX_SLAVE_MAIN_REGS * C_AXI_STRB_WIDTH) + 3 downto (C_IDX_SLAVE_MAIN_REGS * C_AXI_STRB_WIDTH)),
      S_AXI_WREADY(0)   => axi_switch_out_wready(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_BRESP       => axi_switch_out_bresp((C_IDX_SLAVE_MAIN_REGS * 2) + 1 downto (C_IDX_SLAVE_MAIN_REGS * 2)),
      S_AXI_BVALID(0)   => axi_switch_out_bvalid(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_BREADY(0)   => axi_switch_out_bready(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_ARADDR      => axi_switch_out_araddr((C_IDX_SLAVE_MAIN_REGS * C_AXI_ADDR_WIDTH) + 7 downto (C_IDX_SLAVE_MAIN_REGS * C_AXI_ADDR_WIDTH)),
      S_AXI_ARVALID(0)  => axi_switch_out_arvalid(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_ARREADY(0)  => axi_switch_out_arready(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_RDATA       => axi_switch_out_rdata((C_IDX_SLAVE_MAIN_REGS * C_AXI_DATA_WIDTH) + 31 downto (C_IDX_SLAVE_MAIN_REGS * C_AXI_DATA_WIDTH)),
      S_AXI_RRESP       => axi_switch_out_rresp((C_IDX_SLAVE_MAIN_REGS * 2) + 1 downto (C_IDX_SLAVE_MAIN_REGS * 2)),
      S_AXI_RVALID(0)   => axi_switch_out_rvalid(C_IDX_SLAVE_MAIN_REGS),
      S_AXI_RREADY(0)   => axi_switch_out_rready(C_IDX_SLAVE_MAIN_REGS),
      VERSION           => C_DEMO_VERSION,
      REVISION          => C_DEMO_REVISION,
      DEBUG             => C_DEMO_DEBUG,
      BOARD_ID          => board_id,
      UOE_10G_TARGET_IP => reg_uoe_10g_target_ip,
      UOE_10G_PORT_SRC  => reg_uoe_10g_port_src,
      UOE_1G_TARGET_IP  => reg_uoe_1g_target_ip,
      UOE_1G_PORT_SRC   => reg_uoe_1g_port_src
    );

  -------------------------------------------------------------------------------
  -- Debug
  -------------------------------------------------------------------------------

  board_id <= "000" & GPIO_DIP_SW(3);

  dbg_loopback_en <= GPIO_DIP_SW(0);
  sfp_mod_def0    <= GPIO_DIP_SW(2 downto 1);

  GPIO_LED(1 downto 0) <= interrupt_1g or interrupt_10g; --dbg_clk_phy_active;
  GPIO_LED(3 downto 2) <= phy_layer_ready;
  GPIO_LED(5 downto 4) <= sfp_mod_def0 or SFP_LOS;
  GPIO_LED(6)          <= dbg_loopback_en;
  GPIO_LED(7)          <= locked;
end rtl;
