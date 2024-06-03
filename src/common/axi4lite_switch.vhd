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
-- AXI4LITE_SWITCH
--
----------------------------------------------------------------------------------
-- This component interconnects several AXI4-Lite slave ports to several AXI4-Lite
-- master ports
----------
-- The entity is generic in data and address width.
--
-- It uses an Shared Address Shared Data (SASD) architecture
--
-- Channels are treated internally as AXI-Stream channels with the following mapping:
--  * AxADDR -> TUSER (G_ADDR_WIDTH + 2 downto 3)
--  * AxPROT -> TUSER (2 downto 0)
--  * xDATA  -> TDATA
--  * WSTRB  -> TSTRB
--  * xRESP  -> TUSER
--  * xVALID -> TVALID
--  * xREADY -> TREADY
--
-- Response routing is done thanks to ID fields that are constructed as follows
--  * bit 0        -> '0' for write and '1' for read
--  * bit x .. 1   -> position of the slave interface doing the requests
--
-- To shorten signals denommination, we use the following aliases for components:
--   * axis_mux_custom   -> mux
--   * axis_demux        -> demux
--   * axis_combine      -> comb
--   * axis_broadcast    -> bc
--   * axi4lite_onereq   -> onereq
--   * axi4lite_register -> reg
--   * axis_register     -> reg
--
--------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.dev_utils_pkg.all;
use common.dev_utils_2008_pkg.all;

-- Architecture based on AXI-Stream library
use common.axis_utils_pkg.axis_combine;
use common.axis_utils_pkg.axis_mux_custom;
use common.axis_utils_pkg.axis_demux;
use common.axis_utils_pkg.axis_broadcast;
use common.axis_utils_pkg.axis_register;

-- Use internal components and constants
use common.axi4lite_utils_pkg.axi4lite_register;
use common.axi4lite_utils_pkg.C_AXI_RESP_DECERR;
use common.axi4lite_utils_pkg.C_AXI_PROT_WIDTH;
use common.axi4lite_utils_pkg.C_AXI_RESP_WIDTH;


entity axi4lite_switch is
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
end axi4lite_switch;

architecture rtl of axi4lite_switch is


  -------------------------------------------------------------------
  -- Constants for signal width in AXI4-Lite or AXI-Stream
  -------------------------------------------------------------------

  -- Size of bus coming from the package
  constant C_PROT_WIDTH : positive := C_AXI_PROT_WIDTH;
  -- Size of bus coming from the package
  constant C_RESP_WIDTH : positive := C_AXI_RESP_WIDTH;
  -- One strobe bit for each data byte
  constant C_STRB_WIDTH : positive := G_DATA_WIDTH / 8;
  -- One bit for read or write, other bits for source interface
  constant C_ID_WIDTH   : positive := log2_ceil(G_NB_SLAVE) + 1;
  -- One bit for read or write, one more destination for errors
  constant C_DEST_WIDTH : positive := log2_ceil(G_NB_MASTER + 1) + 1;
  -- Size for TUSER field on the requests part is ADDR and PROT
  constant C_USER_WIDTH : positive := G_ADDR_WIDTH + C_PROT_WIDTH;

  -------------------------------------------------------------------
  -- Constants for requests routing
  -------------------------------------------------------------------
  constant C_WRITE_ID_LSB : std_logic := '0';
  constant C_READ_ID_LSB  : std_logic := '1';

  -------------------------------------------------------------------
  -- Components instantiated internally
  -------------------------------------------------------------------

  -- Internal component to limit to 1 the number of requests made by each slave port
  -- and ensure that responses are given in order even though several master interfaces
  -- are addressed. Write and read channels are considered independently
  component axi4lite_onereq is
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
  end component axi4lite_onereq;


  -------------------------------------------------------------------
  -- Types for internal buses
  -------------------------------------------------------------------

  -- Internal AXI4-Lite bus
  type t_axil is record
    -- AW
    awaddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    awprot  : std_logic_vector(C_PROT_WIDTH - 1 downto 0);
    awvalid : std_logic;
    awready : std_logic;
    -- W
    wdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    wstrb   : std_logic_vector((G_DATA_WIDTH / 8) - 1 downto 0);
    wvalid  : std_logic;
    wready  : std_logic;
    -- B
    bresp   : std_logic_vector(C_RESP_WIDTH - 1 downto 0);
    bvalid  : std_logic;
    bready  : std_logic;
    -- AR
    araddr  : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    arprot  : std_logic_vector(C_PROT_WIDTH - 1 downto 0);
    arvalid : std_logic;
    arready : std_logic;
    -- R
    rdata   : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    rvalid  : std_logic;
    rresp   : std_logic_vector(C_RESP_WIDTH - 1 downto 0);
    rready  : std_logic;
  end record t_axil;

  --------------------------------
  -- Signals
  --------------------------------

  -- From combine for write requests to register
  -- G_NB_SLAVE streams in parallel
  signal axis_combaw_muxaw_tdata  : std_logic_vector((G_NB_SLAVE * G_DATA_WIDTH) - 1 downto 0);
  signal axis_combaw_muxaw_tuser  : std_logic_vector((G_NB_SLAVE * C_USER_WIDTH) - 1 downto 0);
  signal axis_combaw_muxaw_tid    : std_logic_vector((G_NB_SLAVE * C_ID_WIDTH) - 1 downto 0);
  signal axis_combaw_muxaw_tstrb  : std_logic_vector((G_NB_SLAVE * C_STRB_WIDTH) - 1 downto 0);
  signal axis_combaw_muxaw_tvalid : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal axis_combaw_muxaw_tready : std_logic_vector(G_NB_SLAVE - 1 downto 0);

  -- From reg to mux for read requests (G_NB_SLAVE streams)
  -- G_NB_SLAVE streams in parallel
  signal axis_onereq_muxar_tuser  : std_logic_vector((G_NB_SLAVE * C_USER_WIDTH) - 1 downto 0);
  signal axis_onereq_muxar_tid    : std_logic_vector((G_NB_SLAVE * C_ID_WIDTH) - 1 downto 0);
  signal axis_onereq_muxar_tvalid : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal axis_onereq_muxar_tready : std_logic_vector(G_NB_SLAVE - 1 downto 0);

  -- From mux for write requests to mux for all requests (read and write)
  -- 1 stream only
  signal axis_regaw_muxreq_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- WDATA
  signal axis_regaw_muxreq_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0); -- AWADDR & AWPROT
  signal axis_regaw_muxreq_tstrb  : std_logic_vector(C_STRB_WIDTH - 1 downto 0); -- WSTRB
  signal axis_regaw_muxreq_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
  signal axis_regaw_muxreq_tvalid : std_logic;                                   -- AWVALID & WVALID
  signal axis_regaw_muxreq_tready : std_logic;                                   -- AWREADY & WREADY

  -- From mux for read requests to mux for all requests (read and write)
  -- 1 stream only
  signal axis_regar_muxreq_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0); -- ARADDR & ARPROT
  signal axis_regar_muxreq_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
  signal axis_regar_muxreq_tvalid : std_logic;                                   -- ARVALID
  signal axis_regar_muxreq_tready : std_logic;                                   -- ARREADY

  -- From demux of write requests to broadcast of write requests
  -- (G_NB_MASTER + 1) streams in parallel (1 stream is for DECERR)
  signal axis_demuxreq_bcaw_tdata  : std_logic_vector(((G_NB_MASTER + 1) * G_DATA_WIDTH) - 1 downto 0); -- WDATA
  signal axis_demuxreq_bcaw_tuser  : std_logic_vector(((G_NB_MASTER + 1) * C_USER_WIDTH) - 1 downto 0); -- AWADDR & AWPROT
  signal axis_demuxreq_bcaw_tid    : std_logic_vector(((G_NB_MASTER + 1) * C_ID_WIDTH) - 1 downto 0);   -- WSTRB
  signal axis_demuxreq_bcaw_tstrb  : std_logic_vector(((G_NB_MASTER + 1) * C_STRB_WIDTH) - 1 downto 0); -- ID for response routing
  signal axis_demuxreq_bcaw_tvalid : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- AWVALID & WVALID combined
  signal axis_demuxreq_bcaw_tready : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- AWREADY & WREADY combined

  -- From demux of read requests to broadcast of read requests
  -- (G_NB_MASTER + 1) streams in parallel (1 stream is for DECERR)
  signal axis_demuxreq_bcar_tuser  : std_logic_vector(((G_NB_MASTER + 1) * C_USER_WIDTH) - 1 downto 0); -- ARADDR & ARPROT
  signal axis_demuxreq_bcar_tid    : std_logic_vector(((G_NB_MASTER + 1) * C_ID_WIDTH) - 1 downto 0);   -- ID for response routing
  signal axis_demuxreq_bcar_tvalid : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- ARVALID
  signal axis_demuxreq_bcar_tready : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- ARREADY

  -- From combine of write responses to mux of write responses
  -- (G_NB_MASTER + 1) streams in parallel (1 stream is for DECERR)
  signal axis_combb_muxb_tuser  : std_logic_vector(((G_NB_MASTER + 1) * C_RESP_WIDTH) - 1 downto 0); -- BRESP                   
  signal axis_combb_muxb_tid    : std_logic_vector(((G_NB_MASTER + 1) * C_ID_WIDTH) - 1 downto 0);   -- ID for response routing 
  signal axis_combb_muxb_tvalid : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- BVALID                  
  signal axis_combb_muxb_tready : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- BREADY                  

  -- From combine of read responses to mux of read responses
  -- (G_NB_MASTER + 1) streams in parallel (1 stream is for DECERR)
  signal axis_combr_muxr_tdata  : std_logic_vector(((G_NB_MASTER + 1) * G_DATA_WIDTH) - 1 downto 0); -- RDATA                  
  signal axis_combr_muxr_tuser  : std_logic_vector(((G_NB_MASTER + 1) * C_RESP_WIDTH) - 1 downto 0); -- RRESP                  
  signal axis_combr_muxr_tid    : std_logic_vector(((G_NB_MASTER + 1) * C_ID_WIDTH) - 1 downto 0);   -- ID for response routing
  signal axis_combr_muxr_tvalid : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- RVALID                 
  signal axis_combr_muxr_tready : std_logic_vector((G_NB_MASTER + 1) - 1 downto 0);                  -- RREADY                 

  -- From mux of write responses to demux of write responses
  -- 1 stream only
  signal axis_muxb_regb_tuser  : std_logic_vector(C_RESP_WIDTH - 1 downto 0);     -- BRESP
  signal axis_muxb_regb_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);       -- ID for response routing
  signal axis_muxb_regb_tvalid : std_logic;                                       -- BVALID
  signal axis_muxb_regb_tready : std_logic;                                       -- BREADY

  -- From mux of read responses to demux of read responses
  -- 1 stream only
  signal axis_muxr_regr_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0);     -- RDATA
  signal axis_muxr_regr_tuser  : std_logic_vector(C_RESP_WIDTH - 1 downto 0);     -- RRESP
  signal axis_muxr_regr_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);       -- ID for response routing
  signal axis_muxr_regr_tvalid : std_logic;                                       -- RVALID
  signal axis_muxr_regr_tready : std_logic;                                       -- RREADY

  -- From demux for write responses to onereq
  -- G_NB_SLAVE streams in parallel
  signal axis_demuxb_onereq_tuser  : std_logic_vector((G_NB_SLAVE * C_RESP_WIDTH) - 1 downto 0);  -- BRESP
  signal axis_demuxb_onereq_tvalid : std_logic_vector(G_NB_SLAVE - 1 downto 0);                   -- BVALID
  signal axis_demuxb_onereq_tready : std_logic_vector(G_NB_SLAVE - 1 downto 0);                   -- BREADY

  -- From demux for read responses to onereq
  -- G_NB_SLAVE streams in parallel
  signal axis_demuxr_onereq_tdata  : std_logic_vector((G_NB_SLAVE * G_DATA_WIDTH) - 1 downto 0);  -- RDATA
  signal axis_demuxr_onereq_tuser  : std_logic_vector((G_NB_SLAVE * C_RESP_WIDTH) - 1 downto 0);  -- RRESP
  signal axis_demuxr_onereq_tvalid : std_logic_vector(G_NB_SLAVE - 1 downto 0);                   -- RVALID
  signal axis_demuxr_onereq_tready : std_logic_vector(G_NB_SLAVE - 1 downto 0);                   -- RREADY


begin


  -------------------------------------------------------------------
  --
  -- Slave interfaces side logic
  --
  -------------------------------------------------------------------

  -- Loop for each slave port:
  --   * Instantiate a onereq or register depending on the number of master port
  --   * Instantiate a combine on AW and W channels
  --   * Instantiate a register on AR channel
  --   * Compute IDs for responses routing
  --   * Connect directly B and R channels
  GEN_SLAVE: for slave in 0 to G_NB_SLAVE-1 generate

    -- AXI4-Lite bus from slave port
    signal axil_onereq : t_axil;

    -- Concatenation of AW and W channels for comb input
    -- 2 streams :
    --   * 0 -> AW
    --   * 1 -> W
    signal axis_onereq_combaw_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- WDATA
    signal axis_onereq_combaw_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0); -- AWADDR & AWPROT
    signal axis_onereq_combaw_tstrb  : std_logic_vector(C_STRB_WIDTH - 1 downto 0); -- WSTRB
    signal axis_onereq_combaw_tvalid : std_logic_vector(1 downto 0);                -- AWVALID & WVALID
    signal axis_onereq_combaw_tready : std_logic_vector(1 downto 0);                -- AWREADY & WREADY

  begin

    -- Instantiate ONE REQUEST at a time flow control to ensure
    -- the order of response and avoid deadlock possibilities
    -- only when more than one master is addressable
    GEN_SLAVE_ONEREQ: if G_NB_MASTER > 1 generate

      -- One request at a time
      inst_axi4lite_onereq : component axi4lite_onereq
        generic map(
          G_ACTIVE_RST => G_ACTIVE_RST,
          G_ASYNC_RST  => G_ASYNC_RST,
          G_DATA_WIDTH => G_DATA_WIDTH,
          G_ADDR_WIDTH => G_ADDR_WIDTH,
          G_REG_MASTER => false,
          G_REG_SLAVE  => true
        )
        port map(
          CLK       => CLK,
          RST       => RST,
          -- Select the slave interface
          S_AWADDR  => S_AWADDR(((slave + 1) * G_ADDR_WIDTH) - 1 downto (slave * G_ADDR_WIDTH)),
          S_AWPROT  => S_AWPROT(((slave + 1) * C_PROT_WIDTH) - 1 downto (slave * C_PROT_WIDTH)),
          S_AWVALID => S_AWVALID(slave),
          S_AWREADY => S_AWREADY(slave),
          S_WDATA   => S_WDATA(((slave + 1) * G_DATA_WIDTH) - 1 downto (slave * G_DATA_WIDTH)),
          S_WSTRB   => S_WSTRB(((slave + 1) * C_STRB_WIDTH) - 1 downto (slave * C_STRB_WIDTH)),
          S_WVALID  => S_WVALID(slave),
          S_WREADY  => S_WREADY(slave),
          S_BRESP   => S_BRESP(((slave + 1) * C_RESP_WIDTH) - 1 downto (slave * C_RESP_WIDTH)),
          S_BVALID  => S_BVALID(slave),
          S_BREADY  => S_BREADY(slave),
          S_ARADDR  => S_ARADDR(((slave + 1) * G_ADDR_WIDTH) - 1 downto (slave * G_ADDR_WIDTH)),
          S_ARPROT  => S_ARPROT(((slave + 1) * C_PROT_WIDTH) - 1 downto (slave * C_PROT_WIDTH)),
          S_ARVALID => S_ARVALID(slave),
          S_ARREADY => S_ARREADY(slave),
          S_RDATA   => S_RDATA(((slave + 1) * G_DATA_WIDTH) - 1 downto (slave * G_DATA_WIDTH)),
          S_RVALID  => S_RVALID(slave),
          S_RRESP   => S_RRESP(((slave + 1) * C_RESP_WIDTH) - 1 downto (slave * C_RESP_WIDTH)),
          S_RREADY  => S_RREADY(slave),
          M_AWADDR  => axil_onereq.awaddr,
          M_AWPROT  => axil_onereq.awprot,
          M_AWVALID => axil_onereq.awvalid,
          M_AWREADY => axil_onereq.awready,
          M_WDATA   => axil_onereq.wdata,
          M_WSTRB   => axil_onereq.wstrb,
          M_WVALID  => axil_onereq.wvalid,
          M_WREADY  => axil_onereq.wready,
          M_BRESP   => axil_onereq.bresp,
          M_BVALID  => axil_onereq.bvalid,
          M_BREADY  => axil_onereq.bready,
          M_ARADDR  => axil_onereq.araddr,
          M_ARPROT  => axil_onereq.arprot,
          M_ARVALID => axil_onereq.arvalid,
          M_ARREADY => axil_onereq.arready,
          M_RDATA   => axil_onereq.rdata,
          M_RVALID  => axil_onereq.rvalid,
          M_RRESP   => axil_onereq.rresp,
          M_RREADY  => axil_onereq.rready
        );
    end generate GEN_SLAVE_ONEREQ;

    -- Instantiate a simple REGISTER
    -- only when one master is addressable
    GEN_SLAVE_REGISTER: if G_NB_MASTER = 1 generate

      -- One request at a time
      inst_axi4lite_register_slave : component axi4lite_register
        generic map(
          G_ACTIVE_RST => G_ACTIVE_RST,
          G_ASYNC_RST  => G_ASYNC_RST,
          G_DATA_WIDTH => G_DATA_WIDTH,
          G_ADDR_WIDTH => G_ADDR_WIDTH,
          G_REG_MASTER => false,
          G_REG_SLAVE  => true
        )
        port map(
          CLK       => CLK,
          RST       => RST,
          -- Select the slave interface
          S_AWADDR  => S_AWADDR(((slave + 1) * G_ADDR_WIDTH) - 1 downto (slave * G_ADDR_WIDTH)),
          S_AWPROT  => S_AWPROT(((slave + 1) * C_PROT_WIDTH) - 1 downto (slave * C_PROT_WIDTH)),
          S_AWVALID => S_AWVALID(slave),
          S_AWREADY => S_AWREADY(slave),
          S_WDATA   => S_WDATA(((slave + 1) * G_DATA_WIDTH) - 1 downto (slave * G_DATA_WIDTH)),
          S_WSTRB   => S_WSTRB(((slave + 1) * C_STRB_WIDTH) - 1 downto (slave * C_STRB_WIDTH)),
          S_WVALID  => S_WVALID(slave),
          S_WREADY  => S_WREADY(slave),
          S_BRESP   => S_BRESP(((slave + 1) * C_RESP_WIDTH) - 1 downto (slave * C_RESP_WIDTH)),
          S_BVALID  => S_BVALID(slave),
          S_BREADY  => S_BREADY(slave),
          S_ARADDR  => S_ARADDR(((slave + 1) * G_ADDR_WIDTH) - 1 downto (slave * G_ADDR_WIDTH)),
          S_ARPROT  => S_ARPROT(((slave + 1) * C_PROT_WIDTH) - 1 downto (slave * C_PROT_WIDTH)),
          S_ARVALID => S_ARVALID(slave),
          S_ARREADY => S_ARREADY(slave),
          S_RDATA   => S_RDATA(((slave + 1) * G_DATA_WIDTH) - 1 downto (slave * G_DATA_WIDTH)),
          S_RVALID  => S_RVALID(slave),
          S_RRESP   => S_RRESP(((slave + 1) * C_RESP_WIDTH) - 1 downto (slave * C_RESP_WIDTH)),
          S_RREADY  => S_RREADY(slave),
          M_AWADDR  => axil_onereq.awaddr,
          M_AWPROT  => axil_onereq.awprot,
          M_AWVALID => axil_onereq.awvalid,
          M_AWREADY => axil_onereq.awready,
          M_WDATA   => axil_onereq.wdata,
          M_WSTRB   => axil_onereq.wstrb,
          M_WVALID  => axil_onereq.wvalid,
          M_WREADY  => axil_onereq.wready,
          M_BRESP   => axil_onereq.bresp,
          M_BVALID  => axil_onereq.bvalid,
          M_BREADY  => axil_onereq.bready,
          M_ARADDR  => axil_onereq.araddr,
          M_ARPROT  => axil_onereq.arprot,
          M_ARVALID => axil_onereq.arvalid,
          M_ARREADY => axil_onereq.arready,
          M_RDATA   => axil_onereq.rdata,
          M_RVALID  => axil_onereq.rvalid,
          M_RRESP   => axil_onereq.rresp,
          M_RREADY  => axil_onereq.rready
        );
    end generate GEN_SLAVE_REGISTER;

    -- Concatenate AW and W channels for combine input
    axis_onereq_combaw_tdata  <= axil_onereq.wdata;
    axis_onereq_combaw_tuser  <= axil_onereq.awaddr & axil_onereq.awprot;
    axis_onereq_combaw_tstrb  <= axil_onereq.wstrb;
    axis_onereq_combaw_tvalid <= axil_onereq.wvalid & axil_onereq.awvalid;
    axil_onereq.wready        <= axis_onereq_combaw_tready(1);
    axil_onereq.awready       <= axis_onereq_combaw_tready(0);

    -- Combine AW and W before mux
    -- to enforce arbitration only when both channels have data
    inst_axis_combine_aw : component axis_combine
      generic map(
        G_ACTIVE_RST       => G_ACTIVE_RST,
        G_ASYNC_RST        => G_ASYNC_RST,
        G_TDATA_WIDTH      => G_DATA_WIDTH,
        G_TUSER_WIDTH      => C_USER_WIDTH,
        G_NB_SLAVE         => 2,
        G_REG_OUT_FORWARD  => false,
        G_REG_OUT_BACKWARD => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        -- Combine AW and W
        S_TDATA  => axis_onereq_combaw_tdata,
        S_TVALID => axis_onereq_combaw_tvalid,
        S_TUSER  => axis_onereq_combaw_tuser,
        S_TSTRB  => axis_onereq_combaw_tstrb,
        S_TREADY => axis_onereq_combaw_tready,
        -- Slice the bus for the slave
        M_TDATA  => axis_combaw_muxaw_tdata(((slave + 1) * G_DATA_WIDTH) - 1 downto slave * G_DATA_WIDTH),
        M_TVALID => axis_combaw_muxaw_tvalid(slave),
        M_TUSER  => axis_combaw_muxaw_tuser(((slave + 1) * C_USER_WIDTH) - 1 downto slave * C_USER_WIDTH),
        M_TSTRB  => axis_combaw_muxaw_tstrb(((slave + 1) * C_STRB_WIDTH) - 1 downto slave * C_STRB_WIDTH),
        M_TREADY => axis_combaw_muxaw_tready(slave)
      );

    -- Compute ID for write responses routing
    axis_combaw_muxaw_tid(((slave + 1) * C_ID_WIDTH) - 1 downto slave * C_ID_WIDTH)
      <= std_logic_vector(to_unsigned(slave, C_ID_WIDTH - 1)) & C_WRITE_ID_LSB;


    -- Extract R channel for mux input
    axis_onereq_muxar_tuser(((slave + 1) * C_USER_WIDTH) - 1 downto slave * C_USER_WIDTH)
      <= axil_onereq.araddr & axil_onereq.arprot;
    axis_onereq_muxar_tvalid(slave)
      <= axil_onereq.arvalid;
    axil_onereq.arready
      <= axis_onereq_muxar_tready(slave);
    -- Compute ID for read responses routing
    axis_onereq_muxar_tid(((slave + 1) * C_ID_WIDTH) - 1 downto slave * C_ID_WIDTH)
      <= std_logic_vector(to_unsigned(slave, C_ID_WIDTH - 1)) & C_READ_ID_LSB;


    -- Connect AXI4-Lite bus for channel B
    axil_onereq.bresp  <= axis_demuxb_onereq_tuser(((slave + 1) * C_RESP_WIDTH) - 1 downto slave * C_RESP_WIDTH);
    axil_onereq.bvalid <= axis_demuxb_onereq_tvalid(slave);
    -- Connect backward path
    axis_demuxb_onereq_tready(slave) <= axil_onereq.bready;

    -- Connect AXI4-Lite bus for channel R
    axil_onereq.rdata  <= axis_demuxr_onereq_tdata(((slave + 1) * G_DATA_WIDTH) - 1 downto slave * G_DATA_WIDTH);
    axil_onereq.rresp  <= axis_demuxr_onereq_tuser(((slave + 1) * C_RESP_WIDTH) - 1 downto slave * C_RESP_WIDTH);
    axil_onereq.rvalid <= axis_demuxr_onereq_tvalid(slave);
    -- Connect backward path
    axis_demuxr_onereq_tready(slave) <= axil_onereq.rready;

  end generate GEN_SLAVE;


  -------------------------------------------------------------------
  --
  -- Mux requests of the same type logic
  --
  -------------------------------------------------------------------

  -- If more than 1 slave interface:
  --   * Instantiate a mux for write requests
  --   * Instantiate a mux for read requests
  --   * Instantiate a demux for write responses
  --   * Instantiate a demux for read responses
  GEN_REQ_MUX: if G_NB_SLAVE > 1 generate
    -- Zeros of size of slave interfaces for register parameter on mux and demux
    constant C_ZERO_SLAVES : std_logic_vector(G_NB_SLAVE - 1 downto 0) := (others => '0');

    -- From mux for write requests to register of write requests
    -- 1 stream only
    signal axis_muxaw_regaw_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- WDATA
    signal axis_muxaw_regaw_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0); -- AWADDR & AWPROT
    signal axis_muxaw_regaw_tstrb  : std_logic_vector(C_STRB_WIDTH - 1 downto 0); -- WSTRB
    signal axis_muxaw_regaw_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
    signal axis_muxaw_regaw_tvalid : std_logic;                                   -- AWVALID & WVALID combined
    signal axis_muxaw_regaw_tready : std_logic;                                   -- AWREADY & WREADY combined

    -- From mux for read requests to register of read requests
    -- 1 stream only
    signal axis_muxar_regar_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0); -- ARADDR & ARPROT
    signal axis_muxar_regar_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
    signal axis_muxar_regar_tvalid : std_logic;                                   -- ARVALID
    signal axis_muxar_regar_tready : std_logic;                                   -- ARREADY

    -- From regster for write reponses to demux of write reponses
    -- 1 stream only
    signal axis_regb_demuxb_tuser  : std_logic_vector(C_RESP_WIDTH - 1 downto 0); -- BRESP
    signal axis_regb_demuxb_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
    signal axis_regb_demuxb_tvalid : std_logic;                                   -- BVALID
    signal axis_regb_demuxb_tready : std_logic;                                   -- BREADY

    -- From mux for read requests to register of read requests
    -- 1 stream only
    signal axis_regr_demuxr_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0); -- RDATA
    signal axis_regr_demuxr_tuser  : std_logic_vector(C_RESP_WIDTH - 1 downto 0); -- RRESP
    signal axis_regr_demuxr_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);   -- ID for response routing
    signal axis_regr_demuxr_tvalid : std_logic;                                   -- RVALID
    signal axis_regr_demuxr_tready : std_logic;                                   -- RREADY

  begin

    -- Mux for write requests
    inst_axis_mux_custom_aw : component axis_mux_custom
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TDATA_WIDTH         => G_DATA_WIDTH,
        G_TUSER_WIDTH         => C_USER_WIDTH,
        G_TID_WIDTH           => C_ID_WIDTH,
        G_NB_SLAVE            => G_NB_SLAVE,
        -- Register on master side only
        G_REG_SLAVES_FORWARD  => C_ZERO_SLAVES,
        G_REG_SLAVES_BACKWARD => C_ZERO_SLAVES,
        G_REG_MASTER_FORWARD  => false,
        G_REG_MASTER_BACKWARD => false,
        G_REG_ARB_FORWARD     => true,
        G_REG_ARB_BACKWARD    => false,
        G_PACKET_MODE         => false,
        G_ROUND_ROBIN         => G_ROUND_ROBIN,
        G_FAST_ARCH           => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_combaw_muxaw_tdata,
        S_TVALID => axis_combaw_muxaw_tvalid,
        S_TUSER  => axis_combaw_muxaw_tuser,
        S_TSTRB  => axis_combaw_muxaw_tstrb,
        S_TID    => axis_combaw_muxaw_tid,
        S_TREADY => axis_combaw_muxaw_tready,
        M_TDATA  => axis_muxaw_regaw_tdata,
        M_TVALID => axis_muxaw_regaw_tvalid,
        M_TUSER  => axis_muxaw_regaw_tuser,
        M_TSTRB  => axis_muxaw_regaw_tstrb,
        M_TID    => axis_muxaw_regaw_tid,
        M_TREADY => axis_muxaw_regaw_tready
      );

    -- Register AW and W combined channels at mux output
    inst_axis_register_aw : component axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TDATA_WIDTH    => G_DATA_WIDTH,
        G_TUSER_WIDTH    => C_USER_WIDTH,
        G_TID_WIDTH      => C_ID_WIDTH,
        G_REG_FORWARD    => true,
        G_REG_BACKWARD   => true,
        G_FULL_BANDWIDTH => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_muxaw_regaw_tdata,
        S_TVALID => axis_muxaw_regaw_tvalid,
        S_TUSER  => axis_muxaw_regaw_tuser,
        S_TSTRB  => axis_muxaw_regaw_tstrb,
        S_TID    => axis_muxaw_regaw_tid,
        S_TREADY => axis_muxaw_regaw_tready,
        M_TDATA  => axis_regaw_muxreq_tdata,
        M_TVALID => axis_regaw_muxreq_tvalid,
        M_TUSER  => axis_regaw_muxreq_tuser,
        M_TSTRB  => axis_regaw_muxreq_tstrb,
        M_TID    => axis_regaw_muxreq_tid,
        M_TREADY => axis_regaw_muxreq_tready
      );

    -- Mux for read requests
    inst_axis_mux_custom_ar : component axis_mux_custom
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TUSER_WIDTH         => C_USER_WIDTH,
        G_TID_WIDTH           => C_ID_WIDTH,
        G_NB_SLAVE            => G_NB_SLAVE,
        -- Register on master side only
        G_REG_SLAVES_FORWARD  => C_ZERO_SLAVES,
        G_REG_SLAVES_BACKWARD => C_ZERO_SLAVES,
        G_REG_MASTER_FORWARD  => false,
        G_REG_MASTER_BACKWARD => false,
        G_REG_ARB_FORWARD     => true,
        G_REG_ARB_BACKWARD    => false,
        G_PACKET_MODE         => false,
        G_ROUND_ROBIN         => G_ROUND_ROBIN,
        G_FAST_ARCH           => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TVALID => axis_onereq_muxar_tvalid,
        S_TUSER  => axis_onereq_muxar_tuser,
        S_TID    => axis_onereq_muxar_tid,
        S_TREADY => axis_onereq_muxar_tready,
        M_TVALID => axis_muxar_regar_tvalid,
        M_TUSER  => axis_muxar_regar_tuser,
        M_TID    => axis_muxar_regar_tid,
        M_TREADY => axis_muxar_regar_tready
      );

    -- Register AR channel at mux output
    inst_axis_register_ar : component axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TDATA_WIDTH    => G_DATA_WIDTH,
        G_TUSER_WIDTH    => C_USER_WIDTH,
        G_TID_WIDTH      => C_ID_WIDTH,
        G_REG_FORWARD    => true,
        G_REG_BACKWARD   => true,
        G_FULL_BANDWIDTH => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TVALID => axis_muxar_regar_tvalid,
        S_TUSER  => axis_muxar_regar_tuser,
        S_TID    => axis_muxar_regar_tid,
        S_TREADY => axis_muxar_regar_tready,
        M_TVALID => axis_regar_muxreq_tvalid,
        M_TUSER  => axis_regar_muxreq_tuser,
        M_TID    => axis_regar_muxreq_tid,
        M_TREADY => axis_regar_muxreq_tready
      );


    -- Register B channel at demux input
    inst_axis_register_b : component axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TUSER_WIDTH    => C_RESP_WIDTH,
        G_TID_WIDTH      => C_ID_WIDTH,
        G_REG_FORWARD    => true,
        G_REG_BACKWARD   => true,
        G_FULL_BANDWIDTH => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TVALID => axis_muxb_regb_tvalid,
        S_TUSER  => axis_muxb_regb_tuser,
        S_TID    => axis_muxb_regb_tid,
        S_TREADY => axis_muxb_regb_tready,
        M_TVALID => axis_regb_demuxb_tvalid,
        M_TUSER  => axis_regb_demuxb_tuser,
        M_TID    => axis_regb_demuxb_tid,
        M_TREADY => axis_regb_demuxb_tready
      );

    -- Demux to route write responses to request source
    -- Use the TID signal as destination
    inst_axis_demux_custom_b : component axis_demux
      generic map(
        G_ACTIVE_RST           => G_ACTIVE_RST,
        G_ASYNC_RST            => G_ASYNC_RST,
        G_TUSER_WIDTH          => C_RESP_WIDTH,
        G_TDEST_WIDTH          => C_ID_WIDTH - 1,
        G_NB_MASTER            => G_NB_SLAVE,
        G_PIPELINE             => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TVALID => axis_regb_demuxb_tvalid,
        S_TUSER  => axis_regb_demuxb_tuser,
        S_TDEST  => axis_regb_demuxb_tid(C_ID_WIDTH - 1 downto 1), -- destination is source of request
        S_TREADY => axis_regb_demuxb_tready,
        M_TVALID => axis_demuxb_onereq_tvalid,
        M_TUSER  => axis_demuxb_onereq_tuser,
        M_TREADY => axis_demuxb_onereq_tready
      );
    
    -- Register R channel at demux input
    inst_axis_register_r : component axis_register
      generic map(
        G_ACTIVE_RST     => G_ACTIVE_RST,
        G_ASYNC_RST      => G_ASYNC_RST,
        G_TDATA_WIDTH    => G_DATA_WIDTH,
        G_TUSER_WIDTH    => C_RESP_WIDTH,
        G_TID_WIDTH      => C_ID_WIDTH,
        G_REG_FORWARD    => true,
        G_REG_BACKWARD   => true,
        G_FULL_BANDWIDTH => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_muxr_regr_tdata,
        S_TVALID => axis_muxr_regr_tvalid,
        S_TUSER  => axis_muxr_regr_tuser,
        S_TID    => axis_muxr_regr_tid,
        S_TREADY => axis_muxr_regr_tready,
        M_TDATA  => axis_regr_demuxr_tdata,
        M_TVALID => axis_regr_demuxr_tvalid,
        M_TUSER  => axis_regr_demuxr_tuser,
        M_TID    => axis_regr_demuxr_tid,
        M_TREADY => axis_regr_demuxr_tready
      );

    -- Demux to route read responses to request source
    -- Use the TID signal as destination
    inst_axis_demux_custom_r : component axis_demux
      generic map(
        G_ACTIVE_RST           => G_ACTIVE_RST,
        G_ASYNC_RST            => G_ASYNC_RST,
        G_TDATA_WIDTH          => G_DATA_WIDTH,
        G_TUSER_WIDTH          => C_RESP_WIDTH,
        G_TDEST_WIDTH          => C_ID_WIDTH - 1,
        G_NB_MASTER            => G_NB_SLAVE,
        G_PIPELINE             => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_regr_demuxr_tdata,
        S_TVALID => axis_regr_demuxr_tvalid,
        S_TUSER  => axis_regr_demuxr_tuser,
        S_TDEST  => axis_regr_demuxr_tid(C_ID_WIDTH - 1 downto 1), -- destination is source of request
        S_TREADY => axis_regr_demuxr_tready,
        M_TDATA  => axis_demuxr_onereq_tdata,
        M_TVALID => axis_demuxr_onereq_tvalid,
        M_TUSER  => axis_demuxr_onereq_tuser,
        M_TREADY => axis_demuxr_onereq_tready
      );

  end generate GEN_REQ_MUX;


  -- If only 1 slave interface: direct connections for write requests,
  -- read requests, write responses and read responses
  GEN_REQ_NOMUX: if G_NB_SLAVE = 1 generate

    -- Connection of AW and W channels
    axis_regaw_muxreq_tdata    <= axis_combaw_muxaw_tdata;
    axis_regaw_muxreq_tvalid   <= axis_combaw_muxaw_tvalid(0);
    axis_regaw_muxreq_tuser    <= axis_combaw_muxaw_tuser;
    axis_regaw_muxreq_tstrb    <= axis_combaw_muxaw_tstrb;
    axis_regaw_muxreq_tid      <= axis_combaw_muxaw_tid;
    axis_combaw_muxaw_tready(0) <= axis_regaw_muxreq_tready;

    -- Connection of AR channel
    axis_regar_muxreq_tvalid   <= axis_onereq_muxar_tvalid(0);
    axis_regar_muxreq_tuser    <= axis_onereq_muxar_tuser;
    axis_regar_muxreq_tid      <= axis_onereq_muxar_tid;
    axis_onereq_muxar_tready(0) <= axis_regar_muxreq_tready;

    -- Connection of B channel
    axis_demuxb_onereq_tvalid(0) <= axis_muxb_regb_tvalid;
    axis_demuxb_onereq_tuser     <= axis_muxb_regb_tuser;
    axis_muxb_regb_tready        <= axis_demuxb_onereq_tready(0);

    -- Connection of R channel
    axis_demuxr_onereq_tdata     <= axis_muxr_regr_tdata;
    axis_demuxr_onereq_tvalid(0) <= axis_muxr_regr_tvalid;
    axis_demuxr_onereq_tuser     <= axis_muxr_regr_tuser;
    axis_muxr_regr_tready        <= axis_demuxr_onereq_tready(0);

  end generate GEN_REQ_NOMUX;


  -------------------------------------------------------------------
  --
  -- Address decoding logic
  --
  -------------------------------------------------------------------

  -- If more than 1 master interface:
  --   * Instantiate one mux between read and write requests
  --   * Process the address of the request to determine the master interface of destination
  --   * Instantiate a demux to route the request to the determined destination
  --   * Split the demux output into a write and read requests channel
  --   * Instantiate a mux for write responses
  --   * Instantiate a mux for read responses
  GEN_ADDR_MAP: if G_NB_MASTER > 1 generate

    -- Constant of (G_NB_MASTER + 1) for the register parameter of mux and demux
    constant C_ZERO_MASTERS : std_logic_vector(G_NB_MASTER downto 0) := (others => '0');

    -- Concatenation of read requests bus and write requests bus for mux input
    -- 2 streams :
    --   * 0 -> write requests
    --   * 1 -> read requests
    signal axis_concat_muxreq_tdata  : std_logic_vector((2 * G_DATA_WIDTH) - 1 downto 0);
    signal axis_concat_muxreq_tuser  : std_logic_vector((2 * C_USER_WIDTH) - 1 downto 0);
    signal axis_concat_muxreq_tstrb  : std_logic_vector((2 * C_STRB_WIDTH) - 1 downto 0);
    signal axis_concat_muxreq_tid    : std_logic_vector((2 * C_ID_WIDTH) - 1 downto 0);
    signal axis_concat_muxreq_tvalid : std_logic_vector(1 downto 0);
    signal axis_concat_muxreq_tready : std_logic_vector(1 downto 0);

    -- From mux of read and write requests to address mapping
    -- 1 stream only
    signal axis_muxreq_addrmap_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    signal axis_muxreq_addrmap_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0);
    signal axis_muxreq_addrmap_tstrb  : std_logic_vector(C_STRB_WIDTH - 1 downto 0);
    signal axis_muxreq_addrmap_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);
    signal axis_muxreq_addrmap_tvalid : std_logic;
    signal axis_muxreq_addrmap_tready : std_logic;

    -- From address mapping to demultiplexer of read and write requests
    -- 1 stream only
    signal axis_addrmap_demuxreq_tdata  : std_logic_vector(G_DATA_WIDTH - 1 downto 0);
    signal axis_addrmap_demuxreq_tuser  : std_logic_vector(C_USER_WIDTH - 1 downto 0);
    signal axis_addrmap_demuxreq_tstrb  : std_logic_vector(C_STRB_WIDTH - 1 downto 0);
    signal axis_addrmap_demuxreq_tid    : std_logic_vector(C_ID_WIDTH - 1 downto 0);
    signal axis_addrmap_demuxreq_tdest  : std_logic_vector(C_DEST_WIDTH - 1 downto 0);
    signal axis_addrmap_demuxreq_tvalid : std_logic;
    signal axis_addrmap_demuxreq_tready : std_logic;

    -- From demux of read and write requests to split of read requests and write requests
    -- (G_NB_MASTER + 1) * 2 streams :
    --   * G_NB_MASTER streams for write requests
    --   * 1 stream for write DECERR
    --   * G_NB_MASTER_streams for read requests
    --   * 1 stream for read DECERR
    signal axis_demuxreq_split_tdata  : std_logic_vector(((2 * (G_NB_MASTER + 1)) * G_DATA_WIDTH) - 1 downto 0);
    signal axis_demuxreq_split_tuser  : std_logic_vector(((2 * (G_NB_MASTER + 1)) * C_USER_WIDTH) - 1 downto 0);
    signal axis_demuxreq_split_tstrb  : std_logic_vector(((2 * (G_NB_MASTER + 1)) * C_STRB_WIDTH) - 1 downto 0);
    signal axis_demuxreq_split_tid    : std_logic_vector(((2 * (G_NB_MASTER + 1)) * C_ID_WIDTH) - 1 downto 0);
    signal axis_demuxreq_split_tvalid : std_logic_vector((2 * (G_NB_MASTER + 1)) - 1 downto 0);
    signal axis_demuxreq_split_tready : std_logic_vector((2 * (G_NB_MASTER + 1)) - 1 downto 0);

  begin
    
    -- Concatenate write requests and read request bus to map to mux
    -- No data and strobe for read requests
    axis_concat_muxreq_tdata  <= (G_DATA_WIDTH - 1 downto 0 => '-') & axis_regaw_muxreq_tdata;
    axis_concat_muxreq_tuser  <= axis_regar_muxreq_tuser            & axis_regaw_muxreq_tuser;
    axis_concat_muxreq_tstrb  <= (C_STRB_WIDTH - 1 downto 0 => '-') & axis_regaw_muxreq_tstrb;
    axis_concat_muxreq_tid    <= axis_regar_muxreq_tid              & axis_regaw_muxreq_tid;
    axis_concat_muxreq_tvalid <= axis_regar_muxreq_tvalid           & axis_regaw_muxreq_tvalid;
    axis_regar_muxreq_tready  <= axis_concat_muxreq_tready(1);
    axis_regaw_muxreq_tready  <= axis_concat_muxreq_tready(0);

    -- Mux read and write requests
    inst_axis_mux_custom_req : component axis_mux_custom
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TDATA_WIDTH         => G_DATA_WIDTH,
        G_TUSER_WIDTH         => C_USER_WIDTH,
        G_TID_WIDTH           => C_ID_WIDTH,
        G_NB_SLAVE            => 2,
        G_REG_SLAVES_FORWARD  => "00",
        G_REG_SLAVES_BACKWARD => "00",
        -- No register here
        G_REG_MASTER_FORWARD  => false,
        G_REG_MASTER_BACKWARD => false,
        G_REG_ARB_FORWARD     => false,
        G_REG_ARB_BACKWARD    => false,
        G_PACKET_MODE         => false,
        G_ROUND_ROBIN         => G_ROUND_ROBIN,
        G_FAST_ARCH           => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_concat_muxreq_tdata,
        S_TVALID => axis_concat_muxreq_tvalid,
        S_TUSER  => axis_concat_muxreq_tuser,
        S_TSTRB  => axis_concat_muxreq_tstrb,
        S_TID    => axis_concat_muxreq_tid,
        S_TREADY => axis_concat_muxreq_tready,
        M_TDATA  => axis_muxreq_addrmap_tdata,
        M_TVALID => axis_muxreq_addrmap_tvalid,
        M_TUSER  => axis_muxreq_addrmap_tuser,
        M_TSTRB  => axis_muxreq_addrmap_tstrb,
        M_TID    => axis_muxreq_addrmap_tid,
        M_TREADY => axis_muxreq_addrmap_tready
      );

    -- Map the address to a destination
    SYNC_ADDR_MAP: process(CLK, RST) is
      -- Number of the channel to send the request if no matching address is found
      constant C_DECERR_CHAN : std_logic_vector := std_logic_vector(to_unsigned(G_NB_MASTER, C_DEST_WIDTH - 1));
      -- Mask for address comparison
      variable v_addr_mask   : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
      -- Address value extracted from TUSER
      variable v_addr_val    : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    begin
      if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
        -- Asynchronous reset
        axis_addrmap_demuxreq_tdata  <= (others => '0');
        axis_addrmap_demuxreq_tuser  <= (others => '0');
        axis_addrmap_demuxreq_tstrb  <= (others => '0');
        axis_addrmap_demuxreq_tid    <= (others => '0');
        axis_addrmap_demuxreq_tdest  <= (others => '0');
        axis_addrmap_demuxreq_tvalid <= '0';
        axis_muxreq_addrmap_tready   <= '0';

      elsif rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          -- Synchronous reset
          axis_addrmap_demuxreq_tdata  <= (others => '0');
          axis_addrmap_demuxreq_tuser  <= (others => '0');
          axis_addrmap_demuxreq_tstrb  <= (others => '0');
          axis_addrmap_demuxreq_tid    <= (others => '0');
          axis_addrmap_demuxreq_tdest  <= (others => '0');
          axis_addrmap_demuxreq_tvalid <= '0';
          axis_muxreq_addrmap_tready   <= '0';

        else

          -- Manage AXI-Stream handshake
          if axis_addrmap_demuxreq_tready = '1' then
            axis_addrmap_demuxreq_tvalid <= '0';
          end if;

          -- Not ready before a valid request
          axis_muxreq_addrmap_tready <= '0';

          -- Check if output is ready for next data
          if (axis_addrmap_demuxreq_tready = '1') or (axis_addrmap_demuxreq_tvalid /= '1') then

            -- Wait for a new data incoming (not consuming old data)
            if (axis_muxreq_addrmap_tvalid = '1') and (axis_muxreq_addrmap_tready /= '1') then

              -- Consume the request
              axis_muxreq_addrmap_tready   <= '1';

              -- Copy requests to output
              axis_addrmap_demuxreq_tdata  <= axis_muxreq_addrmap_tdata;
              axis_addrmap_demuxreq_tuser  <= axis_muxreq_addrmap_tuser;
              axis_addrmap_demuxreq_tstrb  <= axis_muxreq_addrmap_tstrb;
              axis_addrmap_demuxreq_tid    <= axis_muxreq_addrmap_tid;
              axis_addrmap_demuxreq_tvalid <= '1';

              -- Destination depends on type of requests (read or write)
              axis_addrmap_demuxreq_tdest(0) <= axis_muxreq_addrmap_tid(0);

              -- Extract the address from TUSER
              v_addr_val := axis_muxreq_addrmap_tuser(C_USER_WIDTH - 1 downto C_PROT_WIDTH);

              -- Default value for DECERR
              axis_addrmap_demuxreq_tdest(C_DEST_WIDTH - 1 downto 1) <= C_DECERR_CHAN;

              -- Find the matching address
              for i in 0 to G_NB_MASTER - 1 loop

                -- Compute address mask based on range parameter
                for j in v_addr_mask'range loop
                  if j < G_ADDR_RANGE(i) then
                    v_addr_mask(j) := '0';
                  else
                    v_addr_mask(j) := '1';
                  end if;
                end loop; 

                -- Check if the address matches
                if G_BASE_ADDR(i) = unsigned(v_addr_val and v_addr_mask) then
                  
                  -- Assign the destination
                  axis_addrmap_demuxreq_tdest(C_DEST_WIDTH - 1 downto 1)
                    <= std_logic_vector(to_unsigned(i, C_DEST_WIDTH - 1));

                  -- Stop on first find
                  exit;

                end if;
              end loop;
            end if;
          end if;
        end if;
      end if;
    end process SYNC_ADDR_MAP;

    -- Demuxing requests to the proper slave
    inst_axis_demux_custom_req : component axis_demux
      generic map(
        G_ACTIVE_RST           => G_ACTIVE_RST,
        G_ASYNC_RST            => G_ASYNC_RST,
        G_TDATA_WIDTH          => G_DATA_WIDTH,
        G_TUSER_WIDTH          => C_USER_WIDTH,
        G_TID_WIDTH            => C_ID_WIDTH,
        G_TDEST_WIDTH          => C_DEST_WIDTH,
        G_NB_MASTER            => (2 * (G_NB_MASTER + 1)),
        G_PIPELINE             => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_addrmap_demuxreq_tdata,
        S_TVALID => axis_addrmap_demuxreq_tvalid,
        S_TUSER  => axis_addrmap_demuxreq_tuser,
        S_TSTRB  => axis_addrmap_demuxreq_tstrb,
        S_TID    => axis_addrmap_demuxreq_tid,
        S_TDEST  => axis_addrmap_demuxreq_tdest,
        S_TREADY => axis_addrmap_demuxreq_tready,
        M_TDATA  => axis_demuxreq_split_tdata,
        M_TVALID => axis_demuxreq_split_tvalid,
        M_TUSER  => axis_demuxreq_split_tuser,
        M_TSTRB  => axis_demuxreq_split_tstrb,
        M_TID    => axis_demuxreq_split_tid,
        M_TREADY => axis_demuxreq_split_tready
      );

    -- Split the vector read and write
    -- Read and write channels are interleaved because of the ID structure
    GEN_SPLIT: for dest in 0 to G_NB_MASTER generate

      -- Connection for write
      -- dest <= 2 * dest
      axis_demuxreq_bcaw_tdata(((dest + 1) * G_DATA_WIDTH) - 1 downto dest * G_DATA_WIDTH)
        <= axis_demuxreq_split_tdata((((2 * dest) + 1) * G_DATA_WIDTH) - 1 downto (2 * dest) * G_DATA_WIDTH);
      axis_demuxreq_bcaw_tuser(((dest + 1) * C_USER_WIDTH) - 1 downto dest * C_USER_WIDTH)
        <= axis_demuxreq_split_tuser((((2 * dest) + 1) * C_USER_WIDTH) - 1 downto (2 * dest) * C_USER_WIDTH);
      axis_demuxreq_bcaw_tstrb(((dest + 1) * C_STRB_WIDTH) - 1 downto dest * C_STRB_WIDTH)
        <= axis_demuxreq_split_tstrb((((2 * dest) + 1) * C_STRB_WIDTH) - 1 downto (2 * dest) * C_STRB_WIDTH);
      axis_demuxreq_bcaw_tid(((dest + 1) * C_ID_WIDTH) - 1 downto dest * C_ID_WIDTH)
        <= axis_demuxreq_split_tid((((2 * dest) + 1) * C_ID_WIDTH) - 1 downto (2 * dest) * C_ID_WIDTH);
      axis_demuxreq_bcaw_tvalid(dest)
        <= axis_demuxreq_split_tvalid(2 * dest);
      axis_demuxreq_split_tready(2 * dest)
        <= axis_demuxreq_bcaw_tready(dest);

      -- Connection for read
      -- dest <= (2 * dest) + 1
      axis_demuxreq_bcar_tuser(((dest + 1) * C_USER_WIDTH) - 1 downto dest * C_USER_WIDTH)
        <= axis_demuxreq_split_tuser((((2 * dest) + 2) * C_USER_WIDTH) - 1 downto ((2 * dest) + 1) * C_USER_WIDTH);
      axis_demuxreq_bcar_tid(((dest + 1) * C_ID_WIDTH) - 1 downto dest * C_ID_WIDTH)
        <= axis_demuxreq_split_tid((((2 * dest) + 2) * C_ID_WIDTH) - 1 downto ((2 * dest) + 1) * C_ID_WIDTH);
      axis_demuxreq_bcar_tvalid(dest)
        <= axis_demuxreq_split_tvalid((2 * dest) + 1);
      axis_demuxreq_split_tready((2 * dest) + 1)
        <= axis_demuxreq_bcar_tready(dest);

    end generate GEN_SPLIT;

    -- Mux for write responses
    inst_axis_mux_custom_b : component axis_mux_custom
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TUSER_WIDTH         => C_RESP_WIDTH,
        G_TID_WIDTH           => C_ID_WIDTH,
        G_NB_SLAVE            => G_NB_MASTER + 1,
        G_REG_SLAVES_FORWARD  => C_ZERO_MASTERS,
        G_REG_SLAVES_BACKWARD => C_ZERO_MASTERS,
        G_REG_MASTER_FORWARD  => false,
        G_REG_MASTER_BACKWARD => false,
        G_REG_ARB_FORWARD     => true,
        G_REG_ARB_BACKWARD    => false,
        G_PACKET_MODE         => false,
        G_ROUND_ROBIN         => G_ROUND_ROBIN,
        G_FAST_ARCH           => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TVALID => axis_combb_muxb_tvalid,
        S_TUSER  => axis_combb_muxb_tuser,
        S_TID    => axis_combb_muxb_tid,
        S_TREADY => axis_combb_muxb_tready,
        M_TVALID => axis_muxb_regb_tvalid,
        M_TUSER  => axis_muxb_regb_tuser,
        M_TID    => axis_muxb_regb_tid,
        M_TREADY => axis_muxb_regb_tready
      );
      
    -- Mux for read responses
    inst_axis_mux_custom_r : component axis_mux_custom
      generic map(
        G_ACTIVE_RST          => G_ACTIVE_RST,
        G_ASYNC_RST           => G_ASYNC_RST,
        G_TDATA_WIDTH         => G_DATA_WIDTH,
        G_TUSER_WIDTH         => C_RESP_WIDTH,
        G_TID_WIDTH           => C_ID_WIDTH,
        G_NB_SLAVE            => G_NB_MASTER + 1,
        G_REG_SLAVES_FORWARD  => C_ZERO_MASTERS,
        G_REG_SLAVES_BACKWARD => C_ZERO_MASTERS,
        G_REG_MASTER_FORWARD  => false,
        G_REG_MASTER_BACKWARD => false,
        G_REG_ARB_FORWARD     => true,
        G_REG_ARB_BACKWARD    => false,
        G_PACKET_MODE         => false,
        G_ROUND_ROBIN         => G_ROUND_ROBIN,
        G_FAST_ARCH           => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => axis_combr_muxr_tdata,
        S_TVALID => axis_combr_muxr_tvalid,
        S_TUSER  => axis_combr_muxr_tuser,
        S_TID    => axis_combr_muxr_tid,
        S_TREADY => axis_combr_muxr_tready,
        M_TDATA  => axis_muxr_regr_tdata,
        M_TVALID => axis_muxr_regr_tvalid,
        M_TUSER  => axis_muxr_regr_tuser,
        M_TID    => axis_muxr_regr_tid,
        M_TREADY => axis_muxr_regr_tready
      );

  end generate GEN_ADDR_MAP;


  -- If only one addressable master :
  --   * Connect directly write requests
  --   * Connect directly read requests
  --   * Do not use the stream for DECERR
  --   * Connect directly write responses
  --   * Connect directly read responses
  GEN_NO_ADDR_MAP: if G_NB_MASTER = 1 generate

    -- Connect write requests directly
    -- Second channel is for DECERR and is never used
    axis_demuxreq_bcaw_tdata  <= (G_DATA_WIDTH - 1 downto 0 => '-') & axis_regaw_muxreq_tdata;
    axis_demuxreq_bcaw_tuser  <= (C_USER_WIDTH - 1 downto 0 => '-') & axis_regaw_muxreq_tuser;
    axis_demuxreq_bcaw_tstrb  <= (C_STRB_WIDTH - 1 downto 0 => '-') & axis_regaw_muxreq_tstrb;
    axis_demuxreq_bcaw_tid    <= (C_ID_WIDTH - 1 downto 0 => '-')   & axis_regaw_muxreq_tid;
    axis_demuxreq_bcaw_tvalid <= '0'                                & axis_regaw_muxreq_tvalid;
    axis_regaw_muxreq_tready  <= axis_demuxreq_bcaw_tready(0);

    -- Connect read requests directly
    -- Second channel is for DECERR and is never used
    axis_demuxreq_bcar_tuser  <= (C_USER_WIDTH - 1 downto 0 => '-') & axis_regar_muxreq_tuser;
    axis_demuxreq_bcar_tid    <= (C_ID_WIDTH - 1 downto 0 => '-')   & axis_regar_muxreq_tid;
    axis_demuxreq_bcar_tvalid <= '0'                                & axis_regar_muxreq_tvalid;
    axis_regar_muxreq_tready  <= axis_demuxreq_bcar_tready(0);


    -- Connect write responses directly
    -- Connect the first channel only
    axis_muxb_regb_tuser      <= axis_combb_muxb_tuser(C_RESP_WIDTH - 1 downto 0);
    axis_muxb_regb_tid        <= axis_combb_muxb_tid(C_ID_WIDTH - 1 downto 0);
    axis_muxb_regb_tvalid     <= axis_combb_muxb_tvalid(0);
    axis_combb_muxb_tready(0) <= axis_muxb_regb_tready;
    axis_combb_muxb_tready(1) <= '1';  -- Flush DECERR channel

    -- Connect read responses directly
    -- Connect the first channel only
    axis_muxr_regr_tdata      <= axis_combr_muxr_tdata(G_DATA_WIDTH - 1 downto 0);
    axis_muxr_regr_tuser      <= axis_combr_muxr_tuser(C_RESP_WIDTH - 1 downto 0);
    axis_muxr_regr_tid        <= axis_combr_muxr_tid(C_ID_WIDTH - 1 downto 0);
    axis_muxr_regr_tvalid     <= axis_combr_muxr_tvalid(0);
    axis_combr_muxr_tready(0) <= axis_muxr_regr_tready;
    axis_combr_muxr_tready(1) <= '1';  -- Flush DECERR channel

  end generate GEN_NO_ADDR_MAP;


  -------------------------------------------------------------------
  --
  -- Decoding Error logic
  --
  -------------------------------------------------------------------

  -- Connect DECERR for write responses
  -- The DECERR channel is number G_NB_MASTER
  inst_axis_register_decerr_wr : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TID_WIDTH      => C_ID_WIDTH,
      G_REG_FORWARD    => true,
      G_REG_BACKWARD   => true,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TVALID => axis_demuxreq_bcaw_tvalid(G_NB_MASTER),
      S_TID    => axis_demuxreq_bcaw_tid(((G_NB_MASTER + 1) * C_ID_WIDTH) -1 downto G_NB_MASTER * C_ID_WIDTH),
      S_TREADY => axis_demuxreq_bcaw_tready(G_NB_MASTER),
      M_TVALID => axis_combb_muxb_tvalid(G_NB_MASTER),
      M_TID    => axis_combb_muxb_tid(((G_NB_MASTER + 1) * C_ID_WIDTH) -1 downto G_NB_MASTER * C_ID_WIDTH),
      M_TREADY => axis_combb_muxb_tready(G_NB_MASTER)
    );

  -- Response is always DECERR
  axis_combb_muxb_tuser(((G_NB_MASTER + 1) * C_RESP_WIDTH) - 1 downto G_NB_MASTER * C_RESP_WIDTH)
    <= C_AXI_RESP_DECERR; 

  -- Connect DECERR for read responses
  -- The DECERR channel is number G_NB_MASTER
  inst_axis_register_decerr_rd : component axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TID_WIDTH      => C_ID_WIDTH,
      G_REG_FORWARD    => true,
      G_REG_BACKWARD   => true,
      G_FULL_BANDWIDTH => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TVALID => axis_demuxreq_bcar_tvalid(G_NB_MASTER),
      S_TID    => axis_demuxreq_bcar_tid(((G_NB_MASTER + 1) * C_ID_WIDTH) -1 downto G_NB_MASTER * C_ID_WIDTH),
      S_TREADY => axis_demuxreq_bcar_tready(G_NB_MASTER),
      M_TVALID => axis_combr_muxr_tvalid(G_NB_MASTER),
      M_TID    => axis_combr_muxr_tid(((G_NB_MASTER + 1) * C_ID_WIDTH) -1 downto G_NB_MASTER * C_ID_WIDTH),
      M_TREADY => axis_combr_muxr_tready(G_NB_MASTER)
    );

  -- Response data is not representative on a DECERR
  axis_combr_muxr_tdata(((G_NB_MASTER + 1) * G_DATA_WIDTH) -1 downto G_NB_MASTER * G_DATA_WIDTH)
    <= (others => '0');
  -- Response is always DECERR
  axis_combr_muxr_tuser(((G_NB_MASTER + 1) * C_RESP_WIDTH) -1 downto G_NB_MASTER * C_RESP_WIDTH)
    <= C_AXI_RESP_DECERR;

  -- Detect DECERR and generate a pulse on detection
  SYNC_ERR_DETECT: process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- Asynchronous reset
      ERR_WRDEC <= '0';
      ERR_RDDEC <= '0';
    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        ERR_WRDEC <= '0';
        ERR_RDDEC <= '0';

      else
        -- Error is detected when a transfer is done on DECERR channel
        ERR_WRDEC <= axis_combb_muxb_tready(G_NB_MASTER) and axis_combb_muxb_tvalid(G_NB_MASTER);
        ERR_RDDEC <= axis_combr_muxr_tready(G_NB_MASTER) and axis_combr_muxr_tvalid(G_NB_MASTER);

      end if;
    end if;
  end process SYNC_ERR_DETECT;


  -------------------------------------------------------------------
  --
  -- Master interface side logic
  --
  -------------------------------------------------------------------

  -- Generate logic for each master interface, two cases depending on if the ID reflection is necessary :
  --   * Broadcast and combine if ID reflection is necessary
  --   * Direct connection otherwise
  --   * Instantiate a register for AXI4-Lite interface
  GEN_MASTER: for master in 0 to G_NB_MASTER - 1 generate

    signal axil_reg : t_axil;

  begin

    -- If more than 1 slave, ID reflection is necessary to route responses:
    --   * Instantiate a broadcast for write requests (AW, W, ID)
    --   * Instantiate a broacast for read requests (AR, ID)
    --   * Instantiate a combine for write responses (B, ID)
    --   * Instantiate a combine for read responses (R, ID)
    GEN_ID_REFLECT: if G_NB_SLAVE > 1 generate

      -- From broadcast output of write requests to register
      -- 3 streams
      --   * stream number 0 for AW
      --   * stream number 1 for W
      --   * stream number 2 for ID reflection
      signal axis_bc3aw_splitaw_tdata  : std_logic_vector((3 * G_DATA_WIDTH) -1 downto 0);
      signal axis_bc3aw_splitaw_tuser  : std_logic_vector((3 * C_USER_WIDTH) -1 downto 0);
      signal axis_bc3aw_splitaw_tstrb  : std_logic_vector((3 * C_STRB_WIDTH) -1 downto 0);
      signal axis_bc3aw_splitaw_tid    : std_logic_vector((3 * C_ID_WIDTH) -1 downto 0);
      signal axis_bc3aw_splitaw_tvalid : std_logic_vector(2 downto 0);
      signal axis_bc3aw_splitaw_tready : std_logic_vector(2 downto 0);

      -- From broadcast output of read requests to register
      -- 2 streams
      --   * stream number 0 for AR
      --   * stream number 1 for ID reflection
      signal axis_bc2ar_splitar_tuser  : std_logic_vector((2 * C_USER_WIDTH) -1 downto 0);
      signal axis_bc2ar_splitar_tid    : std_logic_vector((2 * C_ID_WIDTH) -1 downto 0);
      signal axis_bc2ar_splitar_tvalid : std_logic_vector(1 downto 0);
      signal axis_bc2ar_splitar_tready : std_logic_vector(1 downto 0);

      -- From register of write ID to combine of write responses
      -- 1 stream only
      signal axis_regid_combb_tid    : std_logic_vector(C_ID_WIDTH -1 downto 0);
      signal axis_regid_combb_tvalid : std_logic;
      signal axis_regid_combb_tready : std_logic;

      -- From register of read ID to combine of read responses
      -- 1 stream only
      signal axis_regid_combr_tid    : std_logic_vector(C_ID_WIDTH -1 downto 0);
      signal axis_regid_combr_tvalid : std_logic;
      signal axis_regid_combr_tready : std_logic;

    begin

      -- Broadcast instantiation for Write requests
      inst_axis_broadcast_3aw : component axis_broadcast
        generic map(
          G_ACTIVE_RST           => G_ACTIVE_RST,
          G_ASYNC_RST            => G_ASYNC_RST,
          G_TDATA_WIDTH          => G_DATA_WIDTH,
          G_TUSER_WIDTH          => C_USER_WIDTH,
          G_TID_WIDTH            => C_ID_WIDTH,
          G_NB_MASTER            => 3,
          G_PIPELINE             => false
        )
        port map(
          CLK      => CLK,
          RST      => RST,
          S_TDATA  => axis_demuxreq_bcaw_tdata(((master + 1) * G_DATA_WIDTH) -1 downto master * G_DATA_WIDTH),
          S_TVALID => axis_demuxreq_bcaw_tvalid(master),
          S_TUSER  => axis_demuxreq_bcaw_tuser(((master + 1) * C_USER_WIDTH) -1 downto master * C_USER_WIDTH),
          S_TSTRB  => axis_demuxreq_bcaw_tstrb(((master + 1) * C_STRB_WIDTH) -1 downto master * C_STRB_WIDTH),
          S_TID    => axis_demuxreq_bcaw_tid(((master + 1) * C_ID_WIDTH) -1 downto master * C_ID_WIDTH),
          S_TREADY => axis_demuxreq_bcaw_tready(master),
          M_TDATA  => axis_bc3aw_splitaw_tdata,
          M_TVALID => axis_bc3aw_splitaw_tvalid,
          M_TUSER  => axis_bc3aw_splitaw_tuser,
          M_TSTRB  => axis_bc3aw_splitaw_tstrb,
          M_TID    => axis_bc3aw_splitaw_tid,
          M_TREADY => axis_bc3aw_splitaw_tready
        );

      -- Broadcast instantiation for Write requests
      inst_axis_broadcast_2ar : component axis_broadcast
        generic map(
          G_ACTIVE_RST           => G_ACTIVE_RST,
          G_ASYNC_RST            => G_ASYNC_RST,
          G_TUSER_WIDTH          => C_USER_WIDTH,
          G_TID_WIDTH            => C_ID_WIDTH,
          G_NB_MASTER            => 2,
          G_PIPELINE             => false
        )
        port map(
          CLK      => CLK,
          RST      => RST,
          S_TVALID => axis_demuxreq_bcar_tvalid(master),
          S_TUSER  => axis_demuxreq_bcar_tuser(((master + 1) * C_USER_WIDTH) -1 downto master * C_USER_WIDTH),
          S_TID    => axis_demuxreq_bcar_tid(((master + 1) * C_ID_WIDTH) -1 downto master * C_ID_WIDTH),
          S_TREADY => axis_demuxreq_bcar_tready(master),
          M_TVALID => axis_bc2ar_splitar_tvalid,
          M_TUSER  => axis_bc2ar_splitar_tuser,
          M_TID    => axis_bc2ar_splitar_tid,
          M_TREADY => axis_bc2ar_splitar_tready
        );

      -- Split the broadcast to AXI4-Lite bus to register
      -- AW is on channel 0 after broadcast
      axil_reg.awaddr        <= axis_bc3aw_splitaw_tuser(C_USER_WIDTH - 1 downto C_PROT_WIDTH);
      axil_reg.awprot        <= axis_bc3aw_splitaw_tuser(C_PROT_WIDTH - 1 downto 0);
      axil_reg.awvalid       <= axis_bc3aw_splitaw_tvalid(0);
      axis_bc3aw_splitaw_tready(0) <= axil_reg.awready;
      -- W is on channel 1 after broadcast
      axil_reg.wdata               <= axis_bc3aw_splitaw_tdata((2 * G_DATA_WIDTH) -1 downto G_DATA_WIDTH);
      axil_reg.wstrb               <= axis_bc3aw_splitaw_tstrb((2 * C_STRB_WIDTH) -1 downto C_STRB_WIDTH);
      axil_reg.wvalid              <= axis_bc3aw_splitaw_tvalid(1);
      axis_bc3aw_splitaw_tready(1) <= axil_reg.wready;

      -- AR is on channel 0 after broadcast
      axil_reg.araddr        <= axis_bc2ar_splitar_tuser(C_USER_WIDTH - 1 downto C_PROT_WIDTH);
      axil_reg.arprot        <= axis_bc2ar_splitar_tuser(C_PROT_WIDTH - 1 downto 0);
      axil_reg.arvalid       <= axis_bc2ar_splitar_tvalid(0);
      axis_bc2ar_splitar_tready(0) <= axil_reg.arready;

      -- Register write ID
      -- ID is on channel 2 after broadcast
      inst_axis_register_awid : component axis_register
        generic map(
          G_ACTIVE_RST     => G_ACTIVE_RST,
          G_ASYNC_RST      => G_ASYNC_RST,
          G_TID_WIDTH      => C_ID_WIDTH,
          G_REG_FORWARD    => true,
          G_REG_BACKWARD   => true,
          G_FULL_BANDWIDTH => false
        )
        port map(
          CLK      => CLK,
          RST      => RST,
          S_TVALID => axis_bc3aw_splitaw_tvalid(2),
          S_TID    => axis_bc3aw_splitaw_tid((3 * C_ID_WIDTH) - 1 downto 2 * C_ID_WIDTH),
          S_TREADY => axis_bc3aw_splitaw_tready(2),
          M_TVALID => axis_regid_combb_tvalid,
          M_TID    => axis_regid_combb_tid,
          M_TREADY => axis_regid_combb_tready
        );

      -- Register read ID
      -- ID is on channel 1 after broadcast
      inst_axis_register_arid : component axis_register
        generic map(
          G_ACTIVE_RST     => G_ACTIVE_RST,
          G_ASYNC_RST      => G_ASYNC_RST,
          G_TID_WIDTH      => C_ID_WIDTH,
          G_REG_FORWARD    => true,
          G_REG_BACKWARD   => true,
          G_FULL_BANDWIDTH => false
        )
        port map(
          CLK      => CLK,
          RST      => RST,
          S_TVALID => axis_bc2ar_splitar_tvalid(1),
          S_TID    => axis_bc2ar_splitar_tid((2 * C_ID_WIDTH) - 1 downto 1 * C_ID_WIDTH),
          S_TREADY => axis_bc2ar_splitar_tready(1),
          M_TVALID => axis_regid_combr_tvalid,
          M_TID    => axis_regid_combr_tid,
          M_TREADY => axis_regid_combr_tready
        );

      -- Combine ID and B channel
      inst_axis_combine_b : component axis_combine
        generic map(
          G_ACTIVE_RST       => G_ACTIVE_RST,
          G_ASYNC_RST        => G_ASYNC_RST,
          G_TUSER_WIDTH      => C_RESP_WIDTH,
          G_TID_WIDTH        => C_ID_WIDTH,
          G_NB_SLAVE         => 2,
          G_REG_OUT_FORWARD  => true,
          G_REG_OUT_BACKWARD => false
        )
        port map(
          CLK         => CLK,
          RST         => RST,
          S_TVALID(0) => axis_regid_combb_tvalid,
          S_TVALID(1) => axil_reg.bvalid,
          S_TUSER     => axil_reg.bresp,
          S_TID       => axis_regid_combb_tid,
          S_TREADY(0) => axis_regid_combb_tready,
          S_TREADY(1) => axil_reg.bready,
          M_TVALID    => axis_combb_muxb_tvalid(master),
          M_TUSER     => axis_combb_muxb_tuser(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH),
          M_TID       => axis_combb_muxb_tid(((master + 1) * C_ID_WIDTH) - 1 downto master * C_ID_WIDTH),
          M_TREADY    => axis_combb_muxb_tready(master)
        );


      -- Combine ID and R channel
      inst_axis_combine_r : component axis_combine
        generic map(
          G_ACTIVE_RST       => G_ACTIVE_RST,
          G_ASYNC_RST        => G_ASYNC_RST,
          G_TDATA_WIDTH      => G_DATA_WIDTH,
          G_TUSER_WIDTH      => C_RESP_WIDTH,
          G_TID_WIDTH        => C_ID_WIDTH,
          G_NB_SLAVE         => 2,
          G_REG_OUT_FORWARD  => true,
          G_REG_OUT_BACKWARD => false
        )
        port map(
          CLK         => CLK,
          RST         => RST,
          S_TDATA     => axil_reg.rdata,
          S_TVALID(0) => axis_regid_combr_tvalid,
          S_TVALID(1) => axil_reg.rvalid,
          S_TUSER     => axil_reg.rresp,
          S_TID       => axis_regid_combr_tid,
          S_TREADY(0) => axis_regid_combr_tready,
          S_TREADY(1) => axil_reg.rready,
          M_TDATA     => axis_combr_muxr_tdata(((master + 1) * G_DATA_WIDTH) - 1 downto master * G_DATA_WIDTH),
          M_TVALID    => axis_combr_muxr_tvalid(master),
          M_TUSER     => axis_combr_muxr_tuser(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH),
          M_TID       => axis_combr_muxr_tid(((master + 1) * C_ID_WIDTH) - 1 downto master * C_ID_WIDTH),
          M_TREADY    => axis_combr_muxr_tready(master)
        );

    end generate GEN_ID_REFLECT;


    -- If only 1 slave, ID reflection is not necessary to route responses:
    --   * Instantiate a broadcast for write requests (AW, W)
    --   * Direct connection for read requests
    --   * Direct connection for write responses
    --   * Direct connection for read responses
    GEN_NO_ID_REFLECT: if G_NB_SLAVE = 1 generate
      -- From broadcast output of write requests to register
      -- 2 streams
      --   * stream number 0 for AW
      --   * stream number 1 for W
      signal axis_bc2aw_splitaw_tdata  : std_logic_vector((2 * G_DATA_WIDTH) -1 downto 0);
      signal axis_bc2aw_splitaw_tuser  : std_logic_vector((2 * C_USER_WIDTH) -1 downto 0);
      signal axis_bc2aw_splitaw_tstrb  : std_logic_vector((2 * C_STRB_WIDTH) -1 downto 0);
      signal axis_bc2aw_splitaw_tvalid : std_logic_vector(1 downto 0);
      signal axis_bc2aw_splitaw_tready : std_logic_vector(1 downto 0);

    begin

      -- Broadcast instantiation for Write requests
      inst_axis_broadcast_2aw : component axis_broadcast
        generic map(
          G_ACTIVE_RST           => G_ACTIVE_RST,
          G_ASYNC_RST            => G_ASYNC_RST,
          G_TDATA_WIDTH          => G_DATA_WIDTH,
          G_TUSER_WIDTH          => C_USER_WIDTH,
          G_NB_MASTER            => 2,
          G_PIPELINE             => false
        )
        port map(
          CLK      => CLK,
          RST      => RST,
          S_TDATA  => axis_demuxreq_bcaw_tdata(((master + 1) * G_DATA_WIDTH) -1 downto master * G_DATA_WIDTH),
          S_TVALID => axis_demuxreq_bcaw_tvalid(master),
          S_TUSER  => axis_demuxreq_bcaw_tuser(((master + 1) * C_USER_WIDTH) -1 downto master * C_USER_WIDTH),
          S_TSTRB  => axis_demuxreq_bcaw_tstrb(((master + 1) * C_STRB_WIDTH) -1 downto master * C_STRB_WIDTH),
          S_TREADY => axis_demuxreq_bcaw_tready(master),
          M_TDATA  => axis_bc2aw_splitaw_tdata,
          M_TVALID => axis_bc2aw_splitaw_tvalid,
          M_TUSER  => axis_bc2aw_splitaw_tuser,
          M_TSTRB  => axis_bc2aw_splitaw_tstrb,
          M_TREADY => axis_bc2aw_splitaw_tready
        );

      -- Split the broadcast to AXI4-Lite bus to register
      -- AW is on channel 0 after broadcast
      axil_reg.awaddr              <= axis_bc2aw_splitaw_tuser(C_USER_WIDTH - 1 downto C_PROT_WIDTH);
      axil_reg.awprot              <= axis_bc2aw_splitaw_tuser(C_PROT_WIDTH - 1 downto 0);
      axil_reg.awvalid             <= axis_bc2aw_splitaw_tvalid(0);
      axis_bc2aw_splitaw_tready(0) <= axil_reg.awready;
      -- W is on channel 1 after broadcast
      axil_reg.wdata               <= axis_bc2aw_splitaw_tdata((2 * G_DATA_WIDTH) -1 downto G_DATA_WIDTH);
      axil_reg.wstrb               <= axis_bc2aw_splitaw_tstrb((2 * C_STRB_WIDTH) -1 downto C_STRB_WIDTH);
      axil_reg.wvalid              <= axis_bc2aw_splitaw_tvalid(1);
      axis_bc2aw_splitaw_tready(1) <= axil_reg.wready;

      -- Direct connection for AR at index master
      -- forward
      axil_reg.araddr
        <= axis_demuxreq_bcar_tuser(((master + 1) * C_USER_WIDTH) - 1 downto (master * C_USER_WIDTH) + C_PROT_WIDTH);
      axil_reg.arprot
        <= axis_demuxreq_bcar_tuser(((master * C_USER_WIDTH) + C_PROT_WIDTH) - 1 downto master * C_USER_WIDTH);
      axil_reg.arvalid
        <= axis_demuxreq_bcar_tvalid(master);
      axis_demuxreq_bcar_tready(master)
        <= axil_reg.arready;
      
      -- Direct connection for B
      -- ID is not used in this case
      axis_combb_muxb_tuser(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH) <= axil_reg.bresp;
      axis_combb_muxb_tid(((master + 1) * C_ID_WIDTH) - 1 downto master * C_ID_WIDTH)       <= (others => '-');
      axis_combb_muxb_tvalid(master)                                                        <= axil_reg.bvalid;
      -- backward
      axil_reg.bready  <= axis_combb_muxb_tready(master);

      -- Direct connection for R
      -- ID is not used in this case
      axis_combr_muxr_tdata(((master + 1) * G_DATA_WIDTH) - 1 downto master * G_DATA_WIDTH) <= axil_reg.rdata;
      axis_combr_muxr_tuser(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH) <= axil_reg.rresp;
      axis_combr_muxr_tid(((master + 1) * C_ID_WIDTH) - 1 downto master * C_ID_WIDTH)       <= (others => '-');
      axis_combr_muxr_tvalid(master)                                                        <= axil_reg.rvalid;
      -- backward
      axil_reg.rready  <= axis_combr_muxr_tready(master);

    end generate GEN_NO_ID_REFLECT;


    -- Register M interface
    inst_axi4lite_register_master : component axi4lite_register
      generic map(
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST,
        G_DATA_WIDTH => G_DATA_WIDTH,
        G_ADDR_WIDTH => G_ADDR_WIDTH,
        G_REG_MASTER => true,
        G_REG_SLAVE  => false
      )
      port map(
        CLK       => CLK,
        RST       => RST,
        S_AWADDR  => axil_reg.awaddr,
        S_AWPROT  => axil_reg.awprot,
        S_AWVALID => axil_reg.awvalid,
        S_AWREADY => axil_reg.awready,
        S_WDATA   => axil_reg.wdata,
        S_WSTRB   => axil_reg.wstrb,
        S_WVALID  => axil_reg.wvalid,
        S_WREADY  => axil_reg.wready,
        S_BRESP   => axil_reg.bresp,
        S_BVALID  => axil_reg.bvalid,
        S_BREADY  => axil_reg.bready,
        S_ARADDR  => axil_reg.araddr,
        S_ARPROT  => axil_reg.arprot,
        S_ARVALID => axil_reg.arvalid,
        S_ARREADY => axil_reg.arready,
        S_RDATA   => axil_reg.rdata,
        S_RVALID  => axil_reg.rvalid,
        S_RRESP   => axil_reg.rresp,
        S_RREADY  => axil_reg.rready,
        M_AWADDR  => M_AWADDR(((master + 1) * G_ADDR_WIDTH) - 1 downto master * G_ADDR_WIDTH),
        M_AWPROT  => M_AWPROT(((master + 1) * C_PROT_WIDTH) - 1 downto master * C_PROT_WIDTH),
        M_AWVALID => M_AWVALID(master),
        M_AWREADY => M_AWREADY(master),
        M_WDATA   => M_WDATA(((master + 1) * G_DATA_WIDTH) - 1 downto master * G_DATA_WIDTH),
        M_WSTRB   => M_WSTRB(((master + 1) * C_STRB_WIDTH) - 1 downto master * C_STRB_WIDTH),
        M_WVALID  => M_WVALID(master),
        M_WREADY  => M_WREADY(master),
        M_BRESP   => M_BRESP(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH),
        M_BVALID  => M_BVALID(master),
        M_BREADY  => M_BREADY(master),
        M_ARADDR  => M_ARADDR(((master + 1) * G_ADDR_WIDTH) - 1 downto master * G_ADDR_WIDTH),
        M_ARPROT  => M_ARPROT(((master + 1) * C_PROT_WIDTH) - 1 downto master * C_PROT_WIDTH),
        M_ARVALID => M_ARVALID(master),
        M_ARREADY => M_ARREADY(master),
        M_RDATA   => M_RDATA(((master + 1) * G_DATA_WIDTH) - 1 downto master * G_DATA_WIDTH),
        M_RVALID  => M_RVALID(master),
        M_RRESP   => M_RRESP(((master + 1) * C_RESP_WIDTH) - 1 downto master * C_RESP_WIDTH),
        M_RREADY  => M_RREADY(master)
      );
    
  end generate GEN_MASTER;

end rtl;

