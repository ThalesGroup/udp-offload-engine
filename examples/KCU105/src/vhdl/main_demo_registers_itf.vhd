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
use work.package_demo_registers.all;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity main_demo_registers_itf is
  port(
    ----------------------
    -- AXI4-Lite bus
    ----------------------
    S_AXI_ACLK                      : in  std_logic;                           -- Global clock signal
    S_AXI_ARESET                    : in  std_logic;                           -- Global reset signal synchronous to clock S_AXI_ACLK
    S_AXI_AWADDR                    : in  std_logic_vector(7 downto 0);        -- Write address (issued by master, accepted by Slave)
    S_AXI_AWVALID                   : in  std_logic_vector(0 downto 0);        -- Write address valid: this signal indicates that the master is signalling valid write address and control information.
    S_AXI_AWREADY                   : out std_logic_vector(0 downto 0);        -- Write address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_WDATA                     : in  std_logic_vector(31 downto 0);       -- Write data (issued by master, accepted by slave)
    S_AXI_WVALID                    : in  std_logic_vector(0 downto 0);        -- Write valid: this signal indicates that valid write data and strobes are available.
    S_AXI_WSTRB                     : in  std_logic_vector(3 downto 0);        -- Write strobes: WSTRB[n:0] signals when HIGH, specify the byte lanes of the data bus that contain valid information
    S_AXI_WREADY                    : out std_logic_vector(0 downto 0);        -- Write ready: this signal indicates that the slave can accept the write data.
    S_AXI_BRESP                     : out std_logic_vector(1 downto 0);        -- Write response: this signal indicates the status of the write transaction.
    S_AXI_BVALID                    : out std_logic_vector(0 downto 0);        -- Write response valid: this signal indicates that the channel is signalling a valid write response.
    S_AXI_BREADY                    : in  std_logic_vector(0 downto 0);        -- Response ready: this signal indicates that the master can accept a write response.
    S_AXI_ARADDR                    : in  std_logic_vector(7 downto 0);        -- Read address (issued by master, accepted by Slave)
    S_AXI_ARVALID                   : in  std_logic_vector(0 downto 0);        -- Read address valid: this signal indicates that the channel is signalling valid read address and control information.
    S_AXI_ARREADY                   : out std_logic_vector(0 downto 0);        -- Read address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_RDATA                     : out std_logic_vector(31 downto 0);       -- Read data (issued by slave)
    S_AXI_RRESP                     : out std_logic_vector(1 downto 0);        -- Read response: this signal indicates the status of the read transfer.
    S_AXI_RVALID                    : out std_logic_vector(0 downto 0);        -- Read valid: this signal indicates that the channel is signalling the required read data.
    S_AXI_RREADY                    : in  std_logic_vector(0 downto 0);        -- Read ready: this signal indicates that the master can accept the read data and response information.

    ----------------------
    -- Input data for registers
    ----------------------
    -- RO Registers 
    VERSION                         : in  std_logic_vector(7 downto 0);        -- Version number
    REVISION                        : in  std_logic_vector(7 downto 0);        -- Revision number
    DEBUG                           : in  std_logic_vector(11 downto 0);       -- Revision number
    BOARD_ID                        : in  std_logic_vector(3 downto 0);        -- Debug number

    ----------------------
    -- Registers output data
    ----------------------
    -- RW Registers 
    UOE_10G_TARGET_IP               : out std_logic_vector(31 downto 0);       -- UOE 10G Targer IP
    UOE_10G_PORT_SRC                : out std_logic_vector(15 downto 0);       -- UOE 10G frames souce port
    UOE_1G_TARGET_IP                : out std_logic_vector(31 downto 0);       -- UOE 1G Targer IP
    UOE_1G_PORT_SRC                 : out std_logic_vector(15 downto 0)        -- UOE 10G frames souce port

    ----------------------
    -- IRQ
    ---------------------

    -- output


  );
end main_demo_registers_itf;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of main_demo_registers_itf is




begin

  ------------------------------------------------------------------------
  -- registers instanciation
  ------------------------------------------------------------------------
  inst_main_demo_registers : main_demo_registers
    port map(
      ----------------------
      -- AXI4-Lite bus
      ----------------------
      S_AXI_ACLK                 => S_AXI_ACLK,
      S_AXI_ARESET               => S_AXI_ARESET,
      S_AXI_AWADDR               => S_AXI_AWADDR,
      S_AXI_AWVALID              => S_AXI_AWVALID,
      S_AXI_AWREADY              => S_AXI_AWREADY,
      S_AXI_WDATA                => S_AXI_WDATA,
      S_AXI_WVALID               => S_AXI_WVALID,
      S_AXI_WSTRB                => S_AXI_WSTRB,
      S_AXI_WREADY               => S_AXI_WREADY,
      S_AXI_BRESP                => S_AXI_BRESP,
      S_AXI_BVALID               => S_AXI_BVALID,
      S_AXI_BREADY               => S_AXI_BREADY,
      S_AXI_ARADDR               => S_AXI_ARADDR,
      S_AXI_ARVALID              => S_AXI_ARVALID,
      S_AXI_ARREADY              => S_AXI_ARREADY,
      S_AXI_RDATA                => S_AXI_RDATA,
      S_AXI_RRESP                => S_AXI_RRESP,
      S_AXI_RVALID               => S_AXI_RVALID,
      S_AXI_RREADY               => S_AXI_RREADY,
      ----------------------
      -- Input data for registers
      ----------------------

      VERSION                         => VERSION, 
      REVISION                        => REVISION, 
      DEBUG                           => DEBUG, 
      BOARD_ID                        => BOARD_ID, 

      ----------------------
      -- Registers output data
      ----------------------

      UOE_10G_TARGET_IP               => UOE_10G_TARGET_IP, 
      UOE_10G_PORT_SRC                => UOE_10G_PORT_SRC, 
      UOE_1G_TARGET_IP                => UOE_1G_TARGET_IP, 
      UOE_1G_PORT_SRC                 => UOE_1G_PORT_SRC 



    );





end rtl;
