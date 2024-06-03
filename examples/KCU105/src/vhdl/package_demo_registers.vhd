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


package package_demo_registers is

  component interruptions is
    generic (
      G_STATUS_WIDTH  : natural   := 1;                   -- Number of IRQs
      G_ACTIVE_RST    : std_logic := '1';               -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST     : boolean   := false              -- Type of reset used (synchronous or asynchronous resets)
    );
    port (
      CLK             : in  std_logic;
      RST             : in  std_logic;
      IRQ_SOURCES     : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt sources vector
      IRQ_STATUS_RO   : out std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt status vector
      IRQ_ENABLE_RW   : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Interrupt enable vector
      IRQ_CLEAR_WO    : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Clear interrupt status vector
      IRQ_CLEAR_WRITE : in  std_logic;                                    -- Clear interrupt status
      IRQ_SET_WO      : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0);  -- Set interrupt status vector
      IRQ_SET_WRITE   : in  std_logic;                                    -- Set interrupt status
      IRQ             : out std_logic
    );
  end component interruptions;


  -- Main 

  component main_demo_registers is
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

    );
  end component main_demo_registers;

  -- Itf Main 

  component main_demo_registers_itf is
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
  end component main_demo_registers_itf;


  constant C_MAIN_REG_VERSION                              : std_logic_vector(7 downto 0):="00000000";
  constant C_MAIN_REG_UOE_10G_TARGET_IP                    : std_logic_vector(7 downto 0):="00000100";
  constant C_MAIN_REG_UOE_10G_UDP_PORT                     : std_logic_vector(7 downto 0):="00001000";
  constant C_MAIN_REG_UOE_1G_TARGET_IP                     : std_logic_vector(7 downto 0):="00001100";
  constant C_MAIN_REG_UOE_1G_UDP_PORT                      : std_logic_vector(7 downto 0):="00010000";


end package_demo_registers;


-------------------------------------------
-- Package Body
-------------------------------------------
package body package_demo_registers is

end package_demo_registers;
