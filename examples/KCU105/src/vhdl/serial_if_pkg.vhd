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
-- Package serial_if_pkg
----------------------------------
--
-- Give the public modules of the library that could be used by other
-- projects. Modules not included in this package should not be used
-- by a library user
--
-- This package contains the declaration of the following component
-- * uart_if
-- * spi_master_phy
-- * spi_slave_phy
-- * i2c_master_phy
-- * i2c_master_prot
-- * mcbsp_master
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package serial_if_pkg is

  ---------------------------------------------------
  --
  -- constants declarations for the control of uart_if
  --
  ---------------------------------------------------

  -- Baudrate
  constant C_UART_75_BAUDS     : std_logic_vector(4 downto 0) := "00000";
  constant C_UART_150_BAUDS    : std_logic_vector(4 downto 0) := "00001";
  constant C_UART_300_BAUDS    : std_logic_vector(4 downto 0) := "00010";
  constant C_UART_600_BAUDS    : std_logic_vector(4 downto 0) := "00011";
  constant C_UART_1200_BAUDS   : std_logic_vector(4 downto 0) := "00100";
  constant C_UART_2400_BAUDS   : std_logic_vector(4 downto 0) := "00101";
  constant C_UART_4800_BAUDS   : std_logic_vector(4 downto 0) := "00110";
  constant C_UART_9600_BAUDS   : std_logic_vector(4 downto 0) := "00111";
  constant C_UART_19200_BAUDS  : std_logic_vector(4 downto 0) := "01000";
  constant C_UART_38400_BAUDS  : std_logic_vector(4 downto 0) := "01001";
  constant C_UART_57600_BAUDS  : std_logic_vector(4 downto 0) := "01010";
  constant C_UART_115200_BAUDS : std_logic_vector(4 downto 0) := "01011";

  -- Stop Bit
  constant C_UART_ONE_STOP_BIT : std_logic := '0';
  constant C_UART_TWO_STOP_BIT : std_logic := '1';

  -- Parity bit
  constant C_UART_PARITY_OFF : std_logic := '0';
  constant C_UART_PARITY_ON  : std_logic := '1';

  -- Pair / Impair
  constant C_UART_PARITY_EVEN : std_logic := '0';
  constant C_UART_PARITY_ODD  : std_logic := '1';

  -- Size
  constant C_UART_NB_BIT_EIGHT : std_logic := '0';
  constant C_UART_NB_BIT_SEVEN : std_logic := '1';

  ---------------------------------------------------
  --
  -- Constants declarations for timings of i2c_master_phy
  --
  ---------------------------------------------------
  
  -- Standard mode minimum value
  constant C_STD_MODE_TSU_START   : real := 4.7;    -- Set-up start time in us
  constant C_STD_MODE_THD_START   : real := 4.0;    -- Hold time (repeated) start condition in us
  constant C_STD_MODE_TSU_STOP    : real := 4.0;    -- Set-up stop time in us
  constant C_STD_MODE_TLOW_SCL    : real := 4.7;    -- Low period of the SCL clock in us
  constant C_STD_MODE_THD_DATA    : real := 0.1;    -- Data Hold time in us
  constant C_STD_MODE_TSU_DATA    : real := 0.25;   -- Data Set-up time in us
  
  -- Standard mode maximum value
  constant C_STD_MODE_TVD_DAT     : real := 3.45;   -- Data Valid Time
  constant C_STD_MODE_TVD_ACK     : real := 3.45;   -- Data Valid Acknowledge Time
  
  -- Fast mode minimum value
  constant C_FAST_MODE_TSU_START  : real := 0.6;    -- Set-up start time in us
  constant C_FAST_MODE_THD_START  : real := 0.6;    -- Hold time (repeated) start condition in us
  constant C_FAST_MODE_TSU_STOP   : real := 0.6;    -- Set-up stop time in us
  constant C_FAST_MODE_TLOW_SCL   : real := 1.3;    -- Low period of the SCL clock in us
  constant C_FAST_MODE_THD_DATA   : real := 0.1;    -- Data Hold time in us
  constant C_FAST_MODE_TSU_DATA   : real := 0.1;    -- Data Set-up time in us
  
  -- Standard mode maximum value
  constant C_FAST_MODE_TVD_DAT    : real := 0.9;   -- Data Valid Time
  constant C_FAST_MODE_TVD_ACK    : real := 0.9;   -- Data Valid Acknowledge Time
  
  ---------------------------------------------------
  --
  -- uart_if
  --
  ---------------------------------------------------

  component uart_if is
    generic(
      G_CLK_FREQ   : real      := 250.0; -- User clock Frequency in MHz
      G_ACTIVE_RST : std_logic := '0';  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
      G_SIMU       : boolean   := false -- Simu mode to reduce time of simulation by 10
    );
    port(
      -- Global
      RST                 : in  std_logic;
      CLK                 : in  std_logic;
      -- Control
      CFG_BAUDRATE        : in  std_logic_vector(4 downto 0); -- UART Baudrate              => See previous constants
      CFG_BIT_STOP        : in  std_logic; -- Number of Stop Bit         => '0': 1 bit, '1' : 2 bits
      CFG_PARITY_ON_OFF   : in  std_logic; -- Use of Parity Bit          => '0' : Off,  '1' : On
      CFG_PARITY_ODD_EVEN : in  std_logic; -- Polarity of Parity Bit     => '0' : even, '1' : odd
      CFG_USE_PROTOCOL    : in  std_logic; -- Use the flow ctrl protocol => '0' : None, '1' : Flow ctrl enable
      CFG_SIZE            : in  std_logic; -- Number of data bits        => '0': 8 bits, '1' : 7 bits
      -- User Domain
      DX_TDATA            : in  std_logic_vector(7 downto 0); -- Data to transmit
      DX_TVALID           : in  std_logic;
      DX_TREADY           : out std_logic;
      DR_TDATA            : out std_logic_vector(7 downto 0); -- Data received
      DR_TVALID           : out std_logic;
      DR_TREADY           : in  std_logic := '1';
      DR_TUSER            : out std_logic; -- Parity bit result
      ERROR_DATA_DROP     : out std_logic; -- Data Drop information
      -- Physical Interface
      TXD                 : out std_logic; -- TX Data
      RXD                 : in  std_logic := '1'; -- RX Data
      RTS                 : out std_logic; -- Request to Send/ acknowledgement of CTS
      CTS                 : in  std_logic := '0' -- Ready to send/received
    );
  end component uart_if;

  ---------------------------------------------------
  --
  -- spi_master_phy
  --
  ---------------------------------------------------

  component spi_master_phy is
    generic(
      G_ACTIVE_RST      : in std_logic := '0';                                          -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST       : in boolean   := false;                                        -- Type of reset signal
      G_SLAVES_NB       : in positive  := 1;                                            -- Number of spi slaves
      G_ACTIVE_CS       : in std_logic := '0';                                          -- Active high or low chip select/pulse
      G_CPOL            : in std_logic := '0';                                          -- Clock polarity defining the SPI mode
      G_CPHA            : in std_logic := '0';                                          -- Clock phase defining the SPI mode
      G_CLK_DIV         : in positive  := 2;                                            -- Value must be equal to 2 or even ! Clock SPI frequency corresponds to Freq_CLK / G_CLK_DIV
      G_CS_SETUP_DELAY  : in natural   := 0;                                            -- Chip select setup time
      G_CS_HOLD_DELAY   : in natural   := 0;                                            -- Chip select hold time
      G_AXIS_DATA_WIDTH : in positive  := 8                                             -- Data width of a word
    );
    port(
      -- Clock and reset
      CLK                : in  std_logic;                                               -- Reference clock of the system
      RST                : in  std_logic;                                               -- Reset of the system
      -- Spi interface
      SCK                : out std_logic;                                               -- Spi clock
      CS                 : out std_logic_vector(G_SLAVES_NB - 1 downto 0);              -- Spi chip select
      MOSI               : out std_logic;                                               -- Master Output Slave Input
      MISO               : in  std_logic;                                               -- Master Input Slave Output
      DIR                : out std_logic;                                               -- Used for data direction (provision)
      -- Axis mosi slave interface
      S_AXIS_MOSI_TDATA  : in  std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0);        -- Data to write on the MOSI link
      S_AXIS_MOSI_TLAST  : in  std_logic := '1';                                        -- Last bit (for non burst mode, need to be set to '1' in pkg or instantiation)
      S_AXIS_MOSI_TDEST  : in  std_logic_vector(maximum(integer(ceil(log2(real(G_SLAVES_NB)))) - 1, 0) downto 0); -- Slave sender
      S_AXIS_MOSI_TUSER  : in  std_logic_vector(0 downto 0);                            -- Read mode : "1" and write mode : "0"
      S_AXIS_MOSI_TVALID : in  std_logic;
      S_AXIS_MOSI_TREADY : out std_logic;
      -- Axis miso master interface
      M_AXIS_MISO_TDATA  : out std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0);
      M_AXIS_MISO_TVALID : out std_logic;
      M_AXIS_MISO_TREADY : in  std_logic;
      -- Error signals
      MISO_DATA_DROP_ERR : out std_logic;                                               -- Data dropped because slave was not ready while new data arrived
      BAD_MOSI_DEST_ERR  : out std_logic                                                -- TDEST changed during burst mode
    );
  end component spi_master_phy;

  ---------------------------------------------------
  --
  -- spi_slave_phy
  --
  ---------------------------------------------------

  component spi_slave_phy is
    generic(
      G_ACTIVE_RST      : std_logic        := '1'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST       : boolean          := false; -- Type of reset used (synchronous or asynchronous resets)
      G_AXIS_DATA_WIDTH : positive         := 8; -- Data width of a word
      G_ACTIVE_CS       : std_logic        := '0'; -- Active high or low chip select
      G_CPOL            : std_logic        := '0'; -- Clock polarity defining the SPI mode
      G_CPHA            : std_logic        := '0'; -- Clock phase defining the SPI mode
      G_NB_DATA_BITS    : positive         := 1; -- Number of bits of the interface
      G_NB_SYNC_STAGE   : positive         := 2; -- Number of resynchronisation stage
      G_DEFAULT_OUTPUT  : std_logic_vector := x"00" -- Defaut value sent if no word present
    );
    port(
      -- Global
      CLK                : in  std_logic;
      RST                : in  std_logic;
      --- SPI
      SCK                : in  std_logic;
      CS                 : in  std_logic;
      MOSI               : in  std_logic_vector(G_NB_DATA_BITS - 1 downto 0);
      MISO               : out std_logic_vector(G_NB_DATA_BITS - 1 downto 0);
      DIR                : out std_logic;
      -- AXI4-STREAM
      -- input to MISO
      S_AXIS_MISO_TDATA  : in  std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0);
      S_AXIS_MISO_TVALID : in  std_logic;
      S_AXIS_MISO_TREADY : out std_logic;
      -- output from MOSI
      M_AXIS_MOSI_TDATA  : out std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0);
      M_AXIS_MOSI_TVALID : out std_logic;
      M_AXIS_MOSI_TREADY : in  std_logic := '1';
      -- Error flag
      DATA_DROP_ERROR    : out std_logic
    );
  end component spi_slave_phy;

  ---------------------------------------------------
  --
  -- mcbsp_master
  --
  ---------------------------------------------------

  component mcbsp_master
    generic(
      G_ACTIVE_RST      : in std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST       : in boolean   := true; -- Type of reset signal (synchronous or asynchronous)
      G_CLK_DIV         : in positive  := 2; -- Clock MCBSP frequency division factor from CLK. Value must be or even
      G_AXIS_DATA_WIDTH : in integer range 2 to integer'high := 32 -- Data width of a word
    );
    port(
      -- Clock and reset
      CLK              : in  std_logic; -- Reference clock of the system
      RST              : in  std_logic; -- Reset of the system
      -- MCBSP interface
      CLKX             : out std_logic; -- MCBSP clock
      FSX              : out std_logic; -- Frame start
      DX               : out std_logic; -- Output Data
      DR               : in  std_logic := '0'; -- Input Data
      -- AXI-Stream dx slave interface
      S_AXIS_DX_TDATA  : in  std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0); -- Data to write on the DX link
      S_AXIS_DX_TVALID : in  std_logic;
      S_AXIS_DX_TREADY : out std_logic;
      -- AXI-Stream dr master interface
      M_AXIS_DR_TDATA  : out std_logic_vector(G_AXIS_DATA_WIDTH - 1 downto 0);
      M_AXIS_DR_TVALID : out std_logic;
      M_AXIS_DR_TREADY : in  std_logic := '1';
      -- Error signals
      RX_DROP_ERR      : out std_logic; -- Data dropped because slave was not ready while new data arrived
      TX_MISS_ERR      : out std_logic  -- A sending slot was not used because no data was present when the slot started
    );
  end component mcbsp_master;

  ---------------------------------------------------
  --
  -- i2c_master_phy
  --
  ---------------------------------------------------

  component i2c_master_phy is
    generic(
      G_CLK_FREQ   : real      := 250.0;                -- User clock Frequency in MHz
      G_SCL_FREQ   : real      := 100.0;                -- I2C clock Frequency in kHz (Standard mode)
      G_ACTIVE_RST : std_logic := '0';                  -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST  : boolean   := true;                 -- Type of reset used (synchronous or asynchronous resets)
      G_TSU_START  : real      := C_STD_MODE_TSU_START; -- Set-up start time in us
      G_THD_START  : real      := C_STD_MODE_THD_START; -- Hold time (repeated) start condition in us
      G_TSU_STOP   : real      := C_STD_MODE_TSU_STOP;  -- Set-up stop time in us
      G_TLOW_SCL   : real      := C_STD_MODE_TLOW_SCL;  -- Low period of the SCL clock in us
      G_THD_DATA   : real      := C_STD_MODE_THD_DATA   -- Data Hold time in us
    );
    port(
      CLK           : in  std_logic;
      RST           : in  std_logic;
      -- I2C interface
      SDA_IN        : in  std_logic;
      SDA_T         : out std_logic;
      SDA_OUT       : out std_logic;
      SCL_IN        : in  std_logic;
      SCL_T         : out std_logic;
      SCL_OUT       : out std_logic;
      -- Slave interface
      S_AXIS_TDATA  : in  std_logic_vector(7 downto 0);
      S_AXIS_TVALID : in  std_logic;
      S_AXIS_TLAST  : in  std_logic;
      S_AXIS_TREADY : out std_logic;
      -- Master interface
      M_AXIS_TDATA  : out std_logic_vector(7 downto 0);
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TLAST  : out std_logic;
      -- ACK error notifier
      ACK_ERR       : out std_logic
    );
  end component i2c_master_phy;

  ---------------------------------------------------
  --
  -- i2c_master_prot
  --
  ---------------------------------------------------
  
  component i2c_master_prot is
    generic(
      G_ACTIVE_RST    : std_logic              := '1';    -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST     : boolean                := false;   -- Type of reset used (synchronous or asynchronous resets)
      G_FIFO_WR_WIDTH : positive range 2 to 15 := 10;     -- FIFO WR address width (depth is 2**G_FIFO_WR_WIDTH)
      G_FIFO_RD_WIDTH : positive range 2 to 15 := 10;     -- FIFO RD address width (depth is 2**G_FIFO_RD_WIDTH)
      G_NB_IRQ_EXT    : positive range 1 to 16 := 1
    );
    port(
      CLK           : in  std_logic;
      RST           : in  std_logic;
      -- ADDRESS WRITE (AW)
      S_AXI_AWADDR  : in  std_logic_vector(5 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      -- WRITE (W)
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      -- RESPONSE WRITE (B)
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      -- ADDRESS READ (AR)
      S_AXI_ARADDR  : in  std_logic_vector(5 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      -- READ (R)
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RREADY  : in  std_logic;
      -- IRQ
      INTERRUPT     : out std_logic;
      IRQ_EXT       : in  std_logic_vector(G_NB_IRQ_EXT-1 downto 0) := (others => '0');
      -- From Physical Layer
      S_AXIS_TDATA  : in  std_logic_vector(7 downto 0);
      S_AXIS_TVALID : in  std_logic;
      S_AXIS_TLAST  : in  std_logic;
      S_AXIS_TREADY : out std_logic;
      -- To Physical Layer
      M_AXIS_TDATA  : out std_logic_vector(7 downto 0);
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TREADY : in  std_logic   := '1';
      -- Others
      ACK_ERR       : in std_logic    := '0'
    );
  end component i2c_master_prot;

end serial_if_pkg;

package body serial_if_pkg is

end package body serial_if_pkg;
