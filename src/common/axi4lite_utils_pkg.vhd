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
use ieee.math_real.all;

library common;
use common.dev_utils_pkg.all;
use common.dev_utils_2008_pkg.all;

----------------------------------
-- Package axi4lite_pkg
----------------------------------
--
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a library user
--
-- This package contains the declaration of the following component
-- * bridge_axi4lite
-- * register
-- * switch
-- * cdc
--
----------------------------------

package axi4lite_utils_pkg is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  constant C_AXI_PROT_WIDTH   : integer := 3;
  constant C_AXI_RESP_WIDTH   : integer := 2;

  constant C_AXI_RESP_OKAY    : std_logic_vector(1 downto 0) := "00"; -- Normal access success
  constant C_AXI_RESP_EXOKAY  : std_logic_vector(1 downto 0) := "01"; -- Exclusive access okay
  constant C_AXI_RESP_SLVERR  : std_logic_vector(1 downto 0) := "10"; -- Slave error
  constant C_AXI_RESP_DECERR  : std_logic_vector(1 downto 0) := "11"; -- Decode error

  ----------------------------------
  -- Bridge
  ----------------------------------

  component bridge_ascii_to_axi4lite is
    generic(
      G_ACTIVE_RST     : std_logic              := '0';       -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST      : boolean                := true;      -- Type of reset used (synchronous or asynchronous resets)
      G_AXI_DATA_WIDTH : positive range 8 to 64 := 32;        -- Width of the data vector of the axi4-lite
      G_AXI_ADDR_WIDTH : positive range 4 to 64 := 16         -- Width of the address vector of the axi4-lite
    );
    port(
      -- BASIC SIGNALS
      CLK            : in  std_logic;                         -- Global clock, signals are samples at rising edge
      RST            : in  std_logic;                         -- Global reset depends on configuration

      -- SLAVE AXIS
      S_AXIS_TDATA   : in  std_logic_vector(7 downto 0);      -- payload on slave interface
      S_AXIS_TVALID  : in  std_logic;                         -- validity of transfer on slave interface
      S_AXIS_TREADY  : out std_logic;                         -- acceptation of transfer on slave interface

      -- MASTER AXIS
      M_AXIS_TDATA   : out std_logic_vector(7 downto 0);      -- payload on master interface
      M_AXIS_TVALID  : out std_logic;                         -- validity of transfer on master interface
      M_AXIS_TREADY  : in  std_logic := '1';                  -- acceptation of transfer on master interface

      -- MASTER AXI4-LITE

      -- -- ADDRESS WRITE (AR)
      M_AXIL_AWADDR  : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0); -- payload on master axi4lite write address
      M_AXIL_AWPROT  : out std_logic_vector(2 downto 0);
      M_AXIL_AWVALID : out std_logic;                         -- validity of transaction on master axi4lite write adress
      M_AXIL_AWREADY : in  std_logic;                         -- acceptation of transaction on master axi4lite write adress

      -- -- WRITE (W)
      M_AXIL_WDATA   : out std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0); -- payload on master axi4lite write data
      M_AXIL_WSTRB   : out std_logic_vector((G_AXI_DATA_WIDTH / 8) - 1 downto 0);
      M_AXIL_WVALID  : out std_logic;                         -- validity of transaction on master axi4lite write data
      M_AXIL_WREADY  : in  std_logic;                         -- acceptation of transaction on master axi4lite write data

      -- -- RESPONSE WRITE (B)
      M_AXIL_BRESP   : in  std_logic_vector(1 downto 0);
      M_AXIL_BVALID  : in  std_logic;                         -- validity of transaction on master axi4lite write response
      M_AXIL_BREADY  : out std_logic;                         -- acceptation of transaction on master axi4lite write response

      -- -- ADDRESS READ (AR)
      M_AXIL_ARADDR  : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0); -- payload on master axi4lite read address
      M_AXIL_ARPROT  : out std_logic_vector(2 downto 0);
      M_AXIL_ARVALID : out std_logic;                         -- validity of transaction on master axi4lite read adress
      M_AXIL_ARREADY : in  std_logic;                         -- acceptation of transaction on master axi4lite read adress

      -- -- READ (R)
      M_AXIL_RDATA   : in  std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0); -- payload on master axi4lite read data
      M_AXIL_RVALID  : in  std_logic;                         -- validity of transaction on master axi4lite read data / read response
      M_AXIL_RRESP   : in  std_logic_vector(1 downto 0);
      M_AXIL_RREADY  : out std_logic                          -- acceptation of transaction on master axi4lite read data / read response

    );
  end component bridge_ascii_to_axi4lite;

  ----------------------------------
  -- Simple Port RAM Controller
  ----------------------------------

  component axi4lite_sp_ram_ctrl is
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
      BRAM_WREN     : out std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0) := (others => '1');
      BRAM_ADDR     : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
      BRAM_DIN      : out std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
      BRAM_DOUT     : in  std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0)
    );
  end component axi4lite_sp_ram_ctrl;

  ----------------------------------
  -- Register
  ----------------------------------

  component axi4lite_register is
    generic(
      G_ACTIVE_RST   : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST    : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_DATA_WIDTH   : positive  := 32;   -- Width of the data vector of the axi4-lite
      G_ADDR_WIDTH   : positive  := 16;   -- Width of the address vector of the axi4-lite
      G_REG_MASTER   : boolean   := true; -- Whether to register the forward path (tdata, tvalid and others)
      G_REG_SLAVE    : boolean   := true  -- Whether to register the backward path (tready)
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
  end component axi4lite_register;

  ----------------------------------
  -- Switch
  ----------------------------------

  component axi4lite_switch is
    generic(
      G_ACTIVE_RST  : std_logic range '0' to '1' := '0';                         -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST   : boolean          := true;                                  -- Type of reset used (synchronous or asynchronous resets)
      G_DATA_WIDTH  : positive         := 32;                                    -- Width of the data vector of the axi4-lite
      G_ADDR_WIDTH  : positive         := 16;                                    -- Width of the address vector of the axi4-lite
      G_NB_SLAVE    : positive         := 1;                                     -- Number of Slave interfaces
      G_NB_MASTER   : positive         := 1;                                     -- Number of Master interfaces
      G_BASE_ADDR   : t_unsigned_array := to_unsigned_array(unsigned'(x"0000")); -- Base address for each master port
      G_ADDR_RANGE  : t_integer_array  := to_integer_array(16);                  -- Range in number of bits for each master port
      G_ROUND_ROBIN : boolean          := false                                  -- Whether to use a round_robin or fixed priorities
    );
    port (
      -- GLOBAL SIGNALS
      CLK       : in  std_logic;
      RST       : in  std_logic;

      --------------------------------------
      -- SLAVE AXI4-LITE
      --------------------------------------
      -- -- ADDRESS WRITE (AW)
      S_AWADDR  : in  std_logic_vector((G_NB_SLAVE * G_ADDR_WIDTH) - 1 downto 0);
      S_AWPROT  : in  std_logic_vector((G_NB_SLAVE * 3) - 1 downto 0);
      S_AWVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_AWREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- -- WRITE (W)
      S_WDATA   : in  std_logic_vector((G_NB_SLAVE * G_DATA_WIDTH) - 1 downto 0);
      S_WSTRB   : in  std_logic_vector((G_NB_SLAVE * (G_DATA_WIDTH / 8)) - 1 downto 0);
      S_WVALID  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_WREADY  : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- -- RESPONSE WRITE (B)
      S_BRESP   : out std_logic_vector((G_NB_SLAVE * 2) - 1 downto 0);
      S_BVALID  : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_BREADY  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- -- ADDRESS READ (AR)
      S_ARADDR  : in  std_logic_vector((G_NB_SLAVE * G_ADDR_WIDTH) - 1 downto 0);
      S_ARPROT  : in  std_logic_vector((G_NB_SLAVE * 3) - 1 downto 0);
      S_ARVALID : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_ARREADY : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      -- -- READ (R)
      S_RDATA   : out std_logic_vector((G_NB_SLAVE * G_DATA_WIDTH) - 1 downto 0);
      S_RVALID  : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
      S_RRESP   : out std_logic_vector((G_NB_SLAVE * 2) - 1 downto 0);
      S_RREADY  : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);

      --------------------------------------
      -- MASTER AXI4-LITE
      --------------------------------------
      -- -- ADDRESS WRITE (AW)
      M_AWADDR  : out std_logic_vector((G_NB_MASTER * G_ADDR_WIDTH) - 1 downto 0);
      M_AWPROT  : out std_logic_vector((G_NB_MASTER * 3) - 1 downto 0);
      M_AWVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_AWREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0);
      -- -- WRITE (W)
      M_WDATA   : out std_logic_vector((G_NB_MASTER * G_DATA_WIDTH) - 1 downto 0);
      M_WSTRB   : out std_logic_vector((G_NB_MASTER * (G_DATA_WIDTH / 8)) - 1 downto 0);
      M_WVALID  : out std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_WREADY  : in  std_logic_vector(G_NB_MASTER - 1 downto 0);
      -- -- RESPONSE WRITE (B)
      M_BRESP   : in  std_logic_vector((G_NB_MASTER * 2) - 1 downto 0);
      M_BVALID  : in  std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_BREADY  : out std_logic_vector(G_NB_MASTER - 1 downto 0);
      -- -- ADDRESS READ (AR)
      M_ARADDR  : out std_logic_vector((G_NB_MASTER * G_ADDR_WIDTH) - 1 downto 0);
      M_ARPROT  : out std_logic_vector((G_NB_MASTER * 3) - 1 downto 0);
      M_ARVALID : out std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_ARREADY : in  std_logic_vector(G_NB_MASTER - 1 downto 0);
      -- -- READ (R)
      M_RDATA   : in  std_logic_vector((G_NB_MASTER * G_DATA_WIDTH) - 1 downto 0);
      M_RVALID  : in  std_logic_vector(G_NB_MASTER - 1 downto 0);
      M_RRESP   : in  std_logic_vector((G_NB_MASTER * 2) - 1 downto 0);
      M_RREADY  : out std_logic_vector(G_NB_MASTER - 1 downto 0);

      --------------------------------------
      -- ERROR PULSES
      --------------------------------------
      ERR_RDDEC : out std_logic; -- Pulse when a read decode error has occured
      ERR_WRDEC : out std_logic  -- Pulse when a read decode error has occured
    );
  end component axi4lite_switch;

  ----------------------------------
  -- Clock Domain Crossing
  ----------------------------------
  component axi4lite_cdc
    generic(
      G_ACTIVE_RST : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_DATA_WIDTH : positive  := 32;   -- Width of the data vector of the axi4-lite
      G_ADDR_WIDTH : positive  := 16;   -- Width of the address vector of the axi4-lite
      -- REGISTER STAGES
      G_NB_STAGE   : integer range 2 to integer'high := 2 -- Number of synchronization stages (to increase MTBF)
    );
    port (
      --------------------------------------
      --
      -- SOURCE CLOCK DOMAIN
      --
      --------------------------------------
      S_CLK     : in  std_logic;
      S_RST     : in  std_logic;

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
      --
      -- DESTINATION CLOCK DOMAIN
      --
      --------------------------------------
      M_CLK     : in  std_logic;
      M_RST     : in  std_logic;

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
  end component axi4lite_cdc;

end axi4lite_utils_pkg;
