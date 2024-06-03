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

----------------------------------------------------
-- MAC SHAPING
----------------------------------------------------
--
-- This module insert Ethernet Header on TX frames or extract Ethernet Header on RX Frames
-- for frame using protocol handle in the internet layer 
--
----------------------------------------------------

entity uoe_mac_shaping is
  generic(
    G_ENABLE_ARP_TABLE : boolean   := false; -- Use of ARP Table
    G_ACTIVE_RST       : std_logic := '0'; -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST        : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH      : positive  := 64 -- Number of bits used along AXI datapath of UOE
  );
  port(
    CLK                  : in  std_logic;
    RST                  : in  std_logic;
    -------- TX Flow --------
    -- From internet layer
    S_TX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TX_TVALID          : in  std_logic;
    S_TX_TLAST           : in  std_logic;
    S_TX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TX_TID             : in  std_logic_vector(15 downto 0); -- Ethertype value
    S_TX_TUSER           : in  std_logic_vector(31 downto 0); -- DEST IP Address
    S_TX_TREADY          : out std_logic;
    -- To Ethernet frame router
    M_TX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TX_TVALID          : out std_logic;
    M_TX_TLAST           : out std_logic;
    M_TX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TX_TREADY          : in  std_logic;
    -------- RX Flow --------
    -- From Ethernet frame router
    S_RX_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_RX_TVALID          : in  std_logic;
    S_RX_TLAST           : in  std_logic;
    S_RX_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_RX_TREADY          : out std_logic;
    -- To internet layer
    M_RX_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_RX_TVALID          : out std_logic;
    M_RX_TLAST           : out std_logic;
    M_RX_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_RX_TID             : out std_logic_vector(15 downto 0);
    M_RX_TREADY          : in  std_logic;
    -- ARP interface
    M_ARP_IP_TDATA       : out std_logic_vector(31 downto 0);
    M_ARP_IP_TVALID      : out std_logic;
    M_ARP_IP_TREADY      : in  std_logic;
    S_ARP_IP_MAC_TDATA   : in  std_logic_vector(79 downto 0); -- MAC : 79 downto 32, IP : 31 downto 0
    S_ARP_IP_MAC_TVALID  : in  std_logic;
    S_ARP_IP_MAC_TUSER   : in  std_logic_vector(0 downto 0); -- Validity of the couple IP/MAC Address
    S_ARP_IP_MAC_TREADY  : out std_logic;
    -- Registers interface
    FORCE_IP_ADDR_DEST   : in  std_logic_vector(31 downto 0);
    FORCE_ARP_REQUEST    : in  std_logic;
    LOCAL_MAC_ADDR       : in  std_logic_vector(47 downto 0);
    LOCAL_IP_ADDR        : in  std_logic_vector(31 downto 0);
    CLEAR_ARP_TABLE      : in  std_logic;
    CLEAR_ARP_TABLE_DONE : out std_logic;
    -- AXI4-Lite interface to ARP Table (used for debug)
    S_AXI_AWADDR         : in  std_logic_vector(11 downto 0);
    S_AXI_AWVALID        : in  std_logic;
    S_AXI_AWREADY        : out std_logic;
    S_AXI_WDATA          : in  std_logic_vector(31 downto 0);
    S_AXI_WVALID         : in  std_logic;
    S_AXI_WREADY         : out std_logic;
    S_AXI_BRESP          : out std_logic_vector(1 downto 0);
    S_AXI_BVALID         : out std_logic;
    S_AXI_BREADY         : in  std_logic;
    S_AXI_ARADDR         : in  std_logic_vector(11 downto 0);
    S_AXI_ARVALID        : in  std_logic;
    S_AXI_ARREADY        : out std_logic;
    S_AXI_RDATA          : out std_logic_vector(31 downto 0);
    S_AXI_RRESP          : out std_logic_vector(1 downto 0);
    S_AXI_RVALID         : out std_logic;
    S_AXI_RREADY         : in  std_logic
  );
end uoe_mac_shaping;

architecture rtl of uoe_mac_shaping is

  -------------------------------
  -- Component declaration
  -------------------------------

  -- ARP Cache
  component uoe_arp_cache is
    generic(
      G_ACTIVE_RST : std_logic := '0';
      G_ASYNC_RST  : boolean   := true
    );
    port(
      CLK                   : in  std_logic;
      RST                   : in  std_logic;
      S_IP_ADDR_TDATA       : in  std_logic_vector(31 downto 0);
      S_IP_ADDR_TVALID      : in  std_logic;
      S_IP_ADDR_TREADY      : out std_logic;
      M_MAC_ADDR_TDATA      : out std_logic_vector(47 downto 0);
      M_MAC_ADDR_TVALID     : out std_logic;
      M_MAC_ADDR_TUSER      : out std_logic_vector(0 downto 0);
      M_MAC_ADDR_TREADY     : in  std_logic;
      M_ARP_IP_ADDR_TDATA   : out std_logic_vector(31 downto 0);
      M_ARP_IP_ADDR_TVALID  : out std_logic;
      M_ARP_IP_ADDR_TREADY  : in  std_logic;
      S_ARP_MAC_ADDR_TDATA  : in  std_logic_vector(47 downto 0);
      S_ARP_MAC_ADDR_TVALID : in  std_logic;
      S_ARP_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0);
      S_ARP_MAC_ADDR_TREADY : out std_logic;
      LOCAL_IP_ADDR         : in  std_logic_vector(31 downto 0);
      LOCAL_MAC_ADDR        : in  std_logic_vector(47 downto 0)
    );
  end component uoe_arp_cache;

  -- MAC Shaping TX
  component uoe_mac_shaping_tx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : positive  := 64
    );
    port(
      CLK               : in  std_logic;
      RST               : in  std_logic;
      S_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID          : in  std_logic;
      S_TLAST           : in  std_logic;
      S_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TID             : in  std_logic_vector(15 downto 0);
      S_TUSER           : in  std_logic_vector(31 downto 0);
      S_TREADY          : out std_logic;
      M_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID          : out std_logic;
      M_TLAST           : out std_logic;
      M_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY          : in  std_logic;
      M_IP_ADDR_TDATA   : out std_logic_vector(31 downto 0);
      M_IP_ADDR_TVALID  : out std_logic;
      M_IP_ADDR_TREADY  : in  std_logic;
      S_MAC_ADDR_TDATA  : in  std_logic_vector(47 downto 0);
      S_MAC_ADDR_TVALID : in  std_logic;
      S_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0);
      S_MAC_ADDR_TREADY : out std_logic;
      LOCAL_MAC_ADDR    : in  std_logic_vector(47 downto 0)
    );
  end component uoe_mac_shaping_tx;

  -- MAC Shaping RX
  component uoe_mac_shaping_rx is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : positive  := 64
    );
    port(
      CLK      : in  std_logic;
      RST      : in  std_logic;
      S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID : in  std_logic;
      S_TLAST  : in  std_logic;
      S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY : out std_logic;
      M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID : out std_logic;
      M_TLAST  : out std_logic;
      M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TID    : out std_logic_vector(15 downto 0);
      M_TREADY : in  std_logic
    );
  end component uoe_mac_shaping_rx;

  -------------------------------
  -- Signals declaration
  -------------------------------

  -- AXIS ARP Cache to ARP Table
  signal axis_c_to_t_tdata  : std_logic_vector(31 downto 0); -- ip addr
  signal axis_c_to_t_tvalid : std_logic;
  signal axis_c_to_t_tready : std_logic;

  -- AXIS ARP Table to ARP Cache
  signal axis_t_to_c_tdata  : std_logic_vector(47 downto 0); -- mac addr
  signal axis_t_to_c_tvalid : std_logic;
  signal axis_t_to_c_tuser  : std_logic_vector(0 downto 0);
  signal axis_t_to_c_tready : std_logic;

  -- AXIS MAC Shaping TX to ARP Cache
  signal axis_ip_addr_tdata  : std_logic_vector(31 downto 0); -- ip addr
  signal axis_ip_addr_tvalid : std_logic;
  signal axis_ip_addr_tready : std_logic;

  -- AXIS ARP Cache to MAC Shaping TX 
  signal axis_mac_addr_tdata  : std_logic_vector(47 downto 0); -- mac addr
  signal axis_mac_addr_tvalid : std_logic;
  signal axis_mac_addr_tuser  : std_logic_vector(0 downto 0);
  signal axis_mac_addr_tready : std_logic;

begin

  -------------------------------
  -- ARP TABLE
  -------------------------------

  GEN_ARP_TABLE : if G_ENABLE_ARP_TABLE generate

    -- Component declaration
    component uoe_arp_table is
      generic(
        G_ACTIVE_RST : std_logic := '0';
        G_ASYNC_RST  : boolean   := true
      );
      port(
        CLK                      : in  std_logic;
        RST                      : in  std_logic;
        S_CACHE_IP_ADDR_TDATA    : in  std_logic_vector(31 downto 0);
        S_CACHE_IP_ADDR_TVALID   : in  std_logic;
        S_CACHE_IP_ADDR_TREADY   : out std_logic;
        M_CACHE_MAC_ADDR_TDATA   : out std_logic_vector(47 downto 0);
        M_CACHE_MAC_ADDR_TVALID  : out std_logic;
        M_CACHE_MAC_ADDR_TUSER   : out std_logic_vector(0 downto 0);
        M_CACHE_MAC_ADDR_TREADY  : in  std_logic;
        M_ARP_IP_ADDR_TDATA      : out std_logic_vector(31 downto 0);
        M_ARP_IP_ADDR_TVALID     : out std_logic;
        M_ARP_IP_ADDR_TREADY     : in  std_logic;
        S_ARP_IP_MAC_ADDR_TDATA  : in  std_logic_vector(79 downto 0);
        S_ARP_IP_MAC_ADDR_TVALID : in  std_logic;
        S_ARP_IP_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0);
        S_ARP_IP_MAC_ADDR_TREADY : out std_logic;
        CLEAR_ARP                : in  std_logic;
        CLEAR_ARP_DONE           : out std_logic;
        FORCE_IP_ADDR_DEST       : in  std_logic_vector(31 downto 0);
        FORCE_ARP_REQUEST        : in  std_logic;
        S_AXI_AWADDR             : in  std_logic_vector(11 downto 0);
        S_AXI_AWVALID            : in  std_logic;
        S_AXI_AWREADY            : out std_logic;
        S_AXI_WDATA              : in  std_logic_vector(31 downto 0);
        S_AXI_WVALID             : in  std_logic;
        S_AXI_WREADY             : out std_logic;
        S_AXI_BRESP              : out std_logic_vector(1 downto 0);
        S_AXI_BVALID             : out std_logic;
        S_AXI_BREADY             : in  std_logic;
        S_AXI_ARADDR             : in  std_logic_vector(11 downto 0);
        S_AXI_ARVALID            : in  std_logic;
        S_AXI_ARREADY            : out std_logic;
        S_AXI_RDATA              : out std_logic_vector(31 downto 0);
        S_AXI_RRESP              : out std_logic_vector(1 downto 0);
        S_AXI_RVALID             : out std_logic;
        S_AXI_RREADY             : in  std_logic
      );
    end component uoe_arp_table;

  begin

    inst_uoe_arp_table : uoe_arp_table
      generic map(
        G_ACTIVE_RST => G_ACTIVE_RST,
        G_ASYNC_RST  => G_ASYNC_RST
      )
      port map(
        CLK                      => CLK,
        RST                      => RST,
        S_CACHE_IP_ADDR_TDATA    => axis_c_to_t_tdata,
        S_CACHE_IP_ADDR_TVALID   => axis_c_to_t_tvalid,
        S_CACHE_IP_ADDR_TREADY   => axis_c_to_t_tready,
        M_CACHE_MAC_ADDR_TDATA   => axis_t_to_c_tdata,
        M_CACHE_MAC_ADDR_TVALID  => axis_t_to_c_tvalid,
        M_CACHE_MAC_ADDR_TUSER   => axis_t_to_c_tuser,
        M_CACHE_MAC_ADDR_TREADY  => axis_t_to_c_tready,
        M_ARP_IP_ADDR_TDATA      => M_ARP_IP_TDATA,
        M_ARP_IP_ADDR_TVALID     => M_ARP_IP_TVALID,
        M_ARP_IP_ADDR_TREADY     => M_ARP_IP_TREADY,
        S_ARP_IP_MAC_ADDR_TDATA  => S_ARP_IP_MAC_TDATA,
        S_ARP_IP_MAC_ADDR_TVALID => S_ARP_IP_MAC_TVALID,
        S_ARP_IP_MAC_ADDR_TUSER  => S_ARP_IP_MAC_TUSER,
        S_ARP_IP_MAC_ADDR_TREADY => S_ARP_IP_MAC_TREADY,
        CLEAR_ARP                => CLEAR_ARP_TABLE,
        CLEAR_ARP_DONE           => CLEAR_ARP_TABLE_DONE,
        FORCE_IP_ADDR_DEST       => FORCE_IP_ADDR_DEST,
        FORCE_ARP_REQUEST        => FORCE_ARP_REQUEST,
        S_AXI_AWADDR             => S_AXI_AWADDR,
        S_AXI_AWVALID            => S_AXI_AWVALID,
        S_AXI_AWREADY            => S_AXI_AWREADY,
        S_AXI_WDATA              => S_AXI_WDATA,
        S_AXI_WVALID             => S_AXI_WVALID,
        S_AXI_WREADY             => S_AXI_WREADY,
        S_AXI_BRESP              => S_AXI_BRESP,
        S_AXI_BVALID             => S_AXI_BVALID,
        S_AXI_BREADY             => S_AXI_BREADY,
        S_AXI_ARADDR             => S_AXI_ARADDR,
        S_AXI_ARVALID            => S_AXI_ARVALID,
        S_AXI_ARREADY            => S_AXI_ARREADY,
        S_AXI_RDATA              => S_AXI_RDATA,
        S_AXI_RRESP              => S_AXI_RRESP,
        S_AXI_RVALID             => S_AXI_RVALID,
        S_AXI_RREADY             => S_AXI_RREADY
      );

  end generate GEN_ARP_TABLE;

  -- When generic G_ENABLE_ARP_TABLE is false, axis cache bus are directly connected to ARP MODULE (Externe)
  GEN_NO_ARP_TABLE : if G_ENABLE_ARP_TABLE = false generate

    M_ARP_IP_TDATA     <= axis_c_to_t_tdata;
    M_ARP_IP_TVALID    <= axis_c_to_t_tvalid;
    axis_c_to_t_tready <= M_ARP_IP_TREADY;

    axis_t_to_c_tdata   <= S_ARP_IP_MAC_TDATA(79 downto 32);
    axis_t_to_c_tvalid  <= S_ARP_IP_MAC_TVALID;
    axis_t_to_c_tuser   <= S_ARP_IP_MAC_TUSER;
    S_ARP_IP_MAC_TREADY <= axis_t_to_c_tready;

    -- TODO: Reply on AXI to avoid bus locked

  end generate GEN_NO_ARP_TABLE;

  -------------------------------
  -- ARP CACHE
  -------------------------------

  inst_uoe_arp_cache : uoe_arp_cache
    generic map(
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      S_IP_ADDR_TDATA       => axis_ip_addr_tdata,
      S_IP_ADDR_TVALID      => axis_ip_addr_tvalid,
      S_IP_ADDR_TREADY      => axis_ip_addr_tready,
      M_MAC_ADDR_TDATA      => axis_mac_addr_tdata,
      M_MAC_ADDR_TVALID     => axis_mac_addr_tvalid,
      M_MAC_ADDR_TUSER      => axis_mac_addr_tuser,
      M_MAC_ADDR_TREADY     => axis_mac_addr_tready,
      M_ARP_IP_ADDR_TDATA   => axis_c_to_t_tdata,
      M_ARP_IP_ADDR_TVALID  => axis_c_to_t_tvalid,
      M_ARP_IP_ADDR_TREADY  => axis_c_to_t_tready,
      S_ARP_MAC_ADDR_TDATA  => axis_t_to_c_tdata,
      S_ARP_MAC_ADDR_TVALID => axis_t_to_c_tvalid,
      S_ARP_MAC_ADDR_TUSER  => axis_t_to_c_tuser,
      S_ARP_MAC_ADDR_TREADY => axis_t_to_c_tready,
      LOCAL_IP_ADDR         => LOCAL_IP_ADDR,
      LOCAL_MAC_ADDR        => LOCAL_MAC_ADDR
    );

  -------------------------------
  -- TX PATH
  -------------------------------

  inst_uoe_mac_shaping_tx : uoe_mac_shaping_tx
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK               => CLK,
      RST               => RST,
      S_TDATA           => S_TX_TDATA,
      S_TVALID          => S_TX_TVALID,
      S_TLAST           => S_TX_TLAST,
      S_TKEEP           => S_TX_TKEEP,
      S_TID             => S_TX_TID,
      S_TUSER           => S_TX_TUSER,
      S_TREADY          => S_TX_TREADY,
      M_TDATA           => M_TX_TDATA,
      M_TVALID          => M_TX_TVALID,
      M_TLAST           => M_TX_TLAST,
      M_TKEEP           => M_TX_TKEEP,
      M_TREADY          => M_TX_TREADY,
      M_IP_ADDR_TDATA   => axis_ip_addr_tdata,
      M_IP_ADDR_TVALID  => axis_ip_addr_tvalid,
      M_IP_ADDR_TREADY  => axis_ip_addr_tready,
      S_MAC_ADDR_TDATA  => axis_mac_addr_tdata,
      S_MAC_ADDR_TVALID => axis_mac_addr_tvalid,
      S_MAC_ADDR_TUSER  => axis_mac_addr_tuser,
      S_MAC_ADDR_TREADY => axis_mac_addr_tready,
      LOCAL_MAC_ADDR    => LOCAL_MAC_ADDR
    );

  -------------------------------
  -- RX PATH
  -------------------------------

  inst_uoe_mac_shaping_rx : component uoe_mac_shaping_rx
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_RX_TDATA,
      S_TVALID => S_RX_TVALID,
      S_TLAST  => S_RX_TLAST,
      S_TKEEP  => S_RX_TKEEP,
      S_TREADY => S_RX_TREADY,
      M_TDATA  => M_RX_TDATA,
      M_TVALID => M_RX_TVALID,
      M_TLAST  => M_RX_TLAST,
      M_TKEEP  => M_RX_TKEEP,
      M_TID    => M_RX_TID,
      M_TREADY => M_RX_TREADY
    );

end rtl;

