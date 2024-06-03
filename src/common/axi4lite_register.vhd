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
-- AXI4LITE_REGISTER
--
----------------------------------------------------------------------------------
-- This component introduces a register slice on a AXI4-Lite data bus so as to break
-- timing dependencies
----------
-- The entity is generic in data and address width.
--
-- It is based on the AXIS_REGISTER component that inserts a register slice on an
-- AXI-Stream Bus. Both Forward and Backward paths can be registered independently.
--
-- To register outputs, we process differently forward channels (AR, AW, W) and
-- backward channels (R, B). We connect the generic parameters depending on the
-- following table
--
--  +-------------------+-----------------+----------------+
--  | Type of channel   | G_REG_FORWARD   | G_REG_BACKWARD |
--  +-------------------+-----------------+----------------+
--  | forward           | G_REG_MASTER    | G_REG_SLAVE    |
--  +-------------------+-----------------+----------------+
--  | backward          | G_REG_SLAVE     | G_REG_MASTER   |
--  +-------------------+-----------------+----------------+
--
-- To register the forward path, a simple register is introduced. This mode implements a
-- number of flip flops equal to the width of the input data (as a normal register would do)
--
-- To register the backward path we use the lightweight architecture which is not able to
-- reach the full bandwidth, which is acceptable for AXI4-Lite.
--------------------------------



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.axis_utils_pkg.axis_register;

entity axi4lite_register is
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
end axi4lite_register;

architecture rtl of axi4lite_register is

begin

  -- Global mapping from AXI4-Lite to AXI-Stream
  -- AxADDR -> TDEST
  -- AxPROT -> TUSER
  -- xDATA  -> TDATA
  -- WSTRB  -> TSTRB
  -- xRESP  -> TUSER
  -- xVALID -> TVALID
  -- xREADY -> TREADY

  -- AW channel -> forward
  inst_axis_register_aw : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDEST_WIDTH    => G_ADDR_WIDTH,
      G_TUSER_WIDTH    => 3,
      G_REG_FORWARD    => G_REG_MASTER,
      G_REG_BACKWARD   => G_REG_SLAVE,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,

      S_TVALID => S_AWVALID,
      S_TDEST  => S_AWADDR,
      S_TUSER  => S_AWPROT,
      S_TREADY => S_AWREADY,

      M_TVALID => M_AWVALID,
      M_TDEST  => M_AWADDR,
      M_TUSER  => M_AWPROT,
      M_TREADY => M_AWREADY
    );

  -- W channel -> forward
  inst_axis_register_w : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_DATA_WIDTH,
      G_REG_FORWARD    => G_REG_MASTER,
      G_REG_BACKWARD   => G_REG_SLAVE,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,

      S_TDATA  => S_WDATA,
      S_TVALID => S_WVALID,
      S_TSTRB  => S_WSTRB,
      S_TREADY => S_WREADY,

      M_TDATA  => M_WDATA,
      M_TVALID => M_WVALID,
      M_TSTRB  => M_WSTRB,
      M_TREADY => M_WREADY
    );

  -- B channel -> backward (swap for register)
  inst_axis_register_b : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TUSER_WIDTH    => 2,
      G_REG_FORWARD    => G_REG_SLAVE,
      G_REG_BACKWARD   => G_REG_MASTER,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,

      S_TUSER  => M_BRESP,
      S_TVALID => M_BVALID,
      S_TREADY => M_BREADY,

      M_TUSER  => S_BRESP,
      M_TVALID => S_BVALID,
      M_TREADY => S_BREADY
    );


  -- AR channel -> forward
  inst_axis_register_ar : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDEST_WIDTH    => G_ADDR_WIDTH,
      G_TUSER_WIDTH    => 3,
      G_REG_FORWARD    => G_REG_MASTER,
      G_REG_BACKWARD   => G_REG_SLAVE,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,

      S_TVALID => S_ARVALID,
      S_TDEST  => S_ARADDR,
      S_TUSER  => S_ARPROT,
      S_TREADY => S_ARREADY,

      M_TVALID => M_ARVALID,
      M_TDEST  => M_ARADDR,
      M_TUSER  => M_ARPROT,
      M_TREADY => M_ARREADY
    );

  -- R channel -> backward (swap for register)
  inst_axis_register_r : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_DATA_WIDTH,
      G_TUSER_WIDTH    => 2,
      G_REG_FORWARD    => G_REG_SLAVE,
      G_REG_BACKWARD   => G_REG_MASTER,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,

      S_TDATA  => M_RDATA,
      S_TUSER  => M_RRESP,
      S_TVALID => M_RVALID,
      S_TREADY => M_RREADY,

      M_TDATA  => S_RDATA,
      M_TUSER  => S_RRESP,
      M_TVALID => S_RVALID,
      M_TREADY => S_RREADY
    );

end rtl;
