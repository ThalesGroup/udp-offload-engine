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

----------------------------------
-- ARP TABLE
----------------------------------
--
-- This module aims at check if the required MAC address is available in memory 
-- If is not, the request is transmitted to the ARP Module, otherwise, the MAC address is directly returned
-- When MAC address is coming from ARP Module, the address is stored in table if valid, and transmit to ARP Cache.
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_mux_custom;

use work.uoe_module_pkg.all;

------------------------------------------------------------------------
-- Entity ARP_TABLE
------------------------------------------------------------------------
entity uoe_arp_table is
  generic(
    G_ACTIVE_RST : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true    -- Type of reset used (synchronous or asynchronous resets)
  );
  port(
    -- Clocks and resets
    CLK                      : in  std_logic;
    RST                      : in  std_logic;
    -- IP ADDR interface from cache
    S_CACHE_IP_ADDR_TDATA    : in  std_logic_vector(31 downto 0);
    S_CACHE_IP_ADDR_TVALID   : in  std_logic;
    S_CACHE_IP_ADDR_TREADY   : out std_logic;
    -- MAC ADDR interface to cache
    M_CACHE_MAC_ADDR_TDATA   : out std_logic_vector(47 downto 0);
    M_CACHE_MAC_ADDR_TVALID  : out std_logic;
    M_CACHE_MAC_ADDR_TUSER   : out std_logic_vector(0 downto 0); -- Validity of the MAC Addr : 0 --> OK, 1 --> KO
    M_CACHE_MAC_ADDR_TREADY  : in  std_logic;
    -- IP ADDR interface to ARP module
    M_ARP_IP_ADDR_TDATA      : out std_logic_vector(31 downto 0);
    M_ARP_IP_ADDR_TVALID     : out std_logic;
    M_ARP_IP_ADDR_TREADY     : in  std_logic;
    -- IP/MAC ADDR interface from ARP module
    S_ARP_IP_MAC_ADDR_TDATA  : in  std_logic_vector(79 downto 0); -- (79..32) --> MAC, (31..0) --> IP
    S_ARP_IP_MAC_ADDR_TVALID : in  std_logic;
    S_ARP_IP_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0); -- Validity of the REQ/ACK : 0 --> OK, 1 --> KO
    S_ARP_IP_MAC_ADDR_TREADY : out std_logic;
    -- Registers interface
    CLEAR_ARP                : in  std_logic; -- Clear ARP process and go to init
    CLEAR_ARP_DONE           : out std_logic; -- Clear ARP system
    FORCE_IP_ADDR_DEST       : in  std_logic_vector(31 downto 0);
    FORCE_ARP_REQUEST        : in  std_logic;
    -- AXI4-Lite interface to ARP Table (used for debug)
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
end uoe_arp_table;

architecture rtl of uoe_arp_table is

  ---------------------------------------------------------------------
  -- Component declaration
  ---------------------------------------------------------------------
  component uoe_arp_table_memory is
    generic(
      G_ACTIVE_RST : std_logic := '0';
      G_ASYNC_RST  : boolean   := true
    );
    port(
      CLK                    : in  std_logic;
      RST                    : in  std_logic;
      S_MEM_RD_IP_TDATA      : in  std_logic_vector(31 downto 0);
      S_MEM_RD_IP_TVALID     : in  std_logic;
      S_MEM_RD_IP_TREADY     : out std_logic;
      M_MEM_RD_MAC_TDATA     : out std_logic_vector(47 downto 0);
      M_MEM_RD_MAC_TUSER     : out std_logic_vector(0 downto 0);
      M_MEM_RD_MAC_TVALID    : out std_logic;
      M_MEM_RD_MAC_TREADY    : in  std_logic;
      S_MEM_WR_IP_MAC_TDATA  : in  std_logic_vector(79 downto 0);
      S_MEM_WR_IP_MAC_TVALID : in  std_logic;
      S_MEM_WR_IP_MAC_TREADY : out std_logic;
      CLEAR_ARP              : in  std_logic;
      CLEAR_ARP_DONE         : out std_logic;
      S_AXI_AWADDR           : in  std_logic_vector(11 downto 0);
      S_AXI_AWVALID          : in  std_logic;
      S_AXI_AWREADY          : out std_logic;
      S_AXI_WDATA            : in  std_logic_vector(31 downto 0);
      S_AXI_WVALID           : in  std_logic;
      S_AXI_WREADY           : out std_logic;
      S_AXI_BRESP            : out std_logic_vector(1 downto 0);
      S_AXI_BVALID           : out std_logic;
      S_AXI_BREADY           : in  std_logic;
      S_AXI_ARADDR           : in  std_logic_vector(11 downto 0);
      S_AXI_ARVALID          : in  std_logic;
      S_AXI_ARREADY          : out std_logic;
      S_AXI_RDATA            : out std_logic_vector(31 downto 0);
      S_AXI_RRESP            : out std_logic_vector(1 downto 0);
      S_AXI_RVALID           : out std_logic;
      S_AXI_RREADY           : in  std_logic
    );
  end component uoe_arp_table_memory;

  ---------------------------------------------------------------------
  -- Constants declaration
  ---------------------------------------------------------------------

  constant C_CACHE_REQUEST : std_logic := '0';
  constant C_USER_REQUEST  : std_logic := '1';

  ---------------------------------------------------------------------
  -- Signals declaration
  ---------------------------------------------------------------------

  -- From/to table memory
  signal mem_rd_ip_tdata  : std_logic_vector(31 downto 0); -- Addr. IP received from controller
  signal mem_rd_ip_tvalid : std_logic;
  signal mem_rd_ip_tready : std_logic;

  signal mem_rd_mac_tdata  : std_logic_vector(47 downto 0); -- Addr. IP received from controller
  signal mem_rd_mac_tuser  : std_logic_vector(0 downto 0);
  signal mem_rd_mac_tvalid : std_logic;
  signal mem_rd_mac_tready : std_logic;

  signal mem_wr_ip_mac_tdata  : std_logic_vector(79 downto 0); -- 79..32 MAC Addr. and 31..0 IP Addr.
  signal mem_wr_ip_mac_tvalid : std_logic;
  signal mem_wr_ip_mac_tready : std_logic;

  -- From table to cache
  signal axis_mem_to_cache_mac_tdata  : std_logic_vector(47 downto 0);
  --signal axis_mem_to_cache_mac_tuser  : std_logic_vector(0 downto 0); -- if mac addr come from memory, tuser is always status valid (0)
  signal axis_mem_to_cache_mac_tvalid : std_logic;
  signal axis_mem_to_cache_mac_tready : std_logic;

  -- From arp to cache
  signal axis_arp_to_cache_mac_tdata  : std_logic_vector(47 downto 0);
  signal axis_arp_to_cache_mac_tuser  : std_logic_vector(0 downto 0);
  signal axis_arp_to_cache_mac_tvalid : std_logic;
  signal axis_arp_to_cache_mac_tready : std_logic;

  -- From cache to arp
  signal axis_to_arp_ip_tdata  : std_logic_vector(31 downto 0); -- Addr. IP received from controller
  signal axis_to_arp_ip_tvalid : std_logic;
  signal axis_to_arp_ip_tready : std_logic;

  -- From user request to arp
  signal axis_to_arp_ip_user_tdata  : std_logic_vector(31 downto 0); -- Addr. IP received from controller
  signal axis_to_arp_ip_user_tvalid : std_logic;
  signal axis_to_arp_ip_user_tready : std_logic;

  signal s_cache_ip_addr_tready_i  : std_logic;
  signal m_cache_mac_addr_tvalid_i : std_logic;
  signal m_arp_ip_addr_tvalid_i    : std_logic;
  signal m_arp_ip_addr_tid         : std_logic_vector(0 downto 0);

  signal axis_from_arp_ip_mac_tdata  : std_logic_vector(79 downto 0); -- IP/MAC sent by ARP Module : (79..32) --> MAC, (31..0) --> IP
  signal axis_from_arp_ip_mac_tuser  : std_logic_vector(0 downto 0); -- Validity of the REQ/ACK : 0 --> OK, 1 --> KO
  signal axis_from_arp_ip_mac_tvalid : std_logic;
  signal axis_from_arp_ip_mac_tready : std_logic;

  signal cache_ip_addr   : std_logic_vector(31 downto 0);
  signal cache_axis_init : std_logic;

  signal req_source     : std_logic;
  signal req_processing : std_logic;

begin

  ---------------------------------------------------------------------
  -- Affectations
  ---------------------------------------------------------------------
  S_CACHE_IP_ADDR_TREADY  <= s_cache_ip_addr_tready_i;
  M_ARP_IP_ADDR_TVALID    <= m_arp_ip_addr_tvalid_i;
  M_CACHE_MAC_ADDR_TVALID <= m_cache_mac_addr_tvalid_i;

  

  ---------------------------------------------------------------------
  -- Input register
  ---------------------------------------------------------------------
  inst_axis_register_from_arp : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => 80,
      G_TUSER_WIDTH  => 1,
      G_REG_FORWARD  => false,    -- Disable Register
      G_REG_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_ARP_IP_MAC_ADDR_TDATA,
      S_TVALID => S_ARP_IP_MAC_ADDR_TVALID,
      S_TUSER  => S_ARP_IP_MAC_ADDR_TUSER,
      S_TREADY => S_ARP_IP_MAC_ADDR_TREADY,
      M_TDATA  => axis_from_arp_ip_mac_tdata,
      M_TVALID => axis_from_arp_ip_mac_tvalid,
      M_TUSER  => axis_from_arp_ip_mac_tuser,
      M_TREADY => axis_from_arp_ip_mac_tready
    );

  ---------------------------------------------------------------------
  -- User request
  ---------------------------------------------------------------------
  PROC_USER_ARP_REQ : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_to_arp_ip_user_tvalid <= '0';
      axis_to_arp_ip_user_tdata  <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_to_arp_ip_user_tvalid <= '0';
        axis_to_arp_ip_user_tdata  <= (others => '0');

      else
        -- Launch ARP Request by register
        if (FORCE_ARP_REQUEST = '1') then
          axis_to_arp_ip_user_tdata  <= FORCE_IP_ADDR_DEST;
          axis_to_arp_ip_user_tvalid <= '1';
        -- acknowledge
        elsif (axis_to_arp_ip_user_tvalid = '1') and (axis_to_arp_ip_user_tready = '1') then
          axis_to_arp_ip_user_tvalid <= '0';
        end if;

      end if;
    end if;
  end process PROC_USER_ARP_REQ;

  -- Process use to handle request from cache
  p_cache_request : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      s_cache_ip_addr_tready_i     <= '0';
      mem_rd_ip_tdata              <= (others => '0');
      mem_rd_ip_tvalid             <= '0';
      mem_rd_mac_tready            <= '0';
      axis_to_arp_ip_tdata         <= (others => '0');
      axis_to_arp_ip_tvalid        <= '0';
      axis_mem_to_cache_mac_tdata  <= (others => '0');
      axis_mem_to_cache_mac_tvalid <= '0';
      cache_ip_addr                <= (others => '0');
      cache_axis_init              <= '1';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        s_cache_ip_addr_tready_i     <= '0';
        mem_rd_ip_tdata              <= (others => '0');
        mem_rd_ip_tvalid             <= '0';
        mem_rd_mac_tready            <= '0';
        axis_to_arp_ip_tdata         <= (others => '0');
        axis_to_arp_ip_tvalid        <= '0';
        axis_mem_to_cache_mac_tdata  <= (others => '0');
        axis_mem_to_cache_mac_tvalid <= '0';
        cache_ip_addr                <= (others => '0');
        cache_axis_init              <= '1';

      else

        -- clear tvalid
        if mem_rd_ip_tready = '1' then
          mem_rd_ip_tvalid <= '0';
        end if;

        if axis_mem_to_cache_mac_tready = '1' then
          axis_mem_to_cache_mac_tvalid <= '0';
        end if;

        if axis_to_arp_ip_tready = '1' then
          axis_to_arp_ip_tvalid <= '0';
        end if;

        -- assert input tready
        if (m_cache_mac_addr_tvalid_i = '1') and (M_CACHE_MAC_ADDR_TREADY = '1') then
          s_cache_ip_addr_tready_i <= '1';
        elsif (cache_axis_init = '1') then
          s_cache_ip_addr_tready_i <= '1';
          cache_axis_init          <= '0';
        end if;

        -- Received request from arp_cache
        if (S_CACHE_IP_ADDR_TVALID = '1') and (s_cache_ip_addr_tready_i = '1') then
          s_cache_ip_addr_tready_i <= '0';
          mem_rd_mac_tready        <= '1';
          cache_ip_addr            <= S_CACHE_IP_ADDR_TDATA;
          mem_rd_ip_tdata          <= S_CACHE_IP_ADDR_TDATA;
          mem_rd_ip_tvalid         <= '1';
        end if;

        -- wait result from memory
        if (mem_rd_mac_tvalid = '1') and (mem_rd_mac_tready = '1') then
          mem_rd_mac_tready <= '0';
          -- Address was not found
          if mem_rd_mac_tuser = "1" then
            axis_to_arp_ip_tdata  <= cache_ip_addr;
            axis_to_arp_ip_tvalid <= '1';
          else
            axis_mem_to_cache_mac_tdata  <= mem_rd_mac_tdata;
            axis_mem_to_cache_mac_tvalid <= '1';
          end if;
        end if;

      end if;
    end if;
  end process p_cache_request;

  -- Process use to handle data from arp_controller
  p_arp_return : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      req_source                   <= '0';
      req_processing               <= '0';
      mem_wr_ip_mac_tdata          <= (others => '0');
      mem_wr_ip_mac_tvalid         <= '0';
      axis_arp_to_cache_mac_tdata  <= (others => '0');
      axis_arp_to_cache_mac_tuser  <= (others => '0');
      axis_arp_to_cache_mac_tvalid <= '0';
      axis_from_arp_ip_mac_tready  <= '0';
      
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        req_source                   <= '0';
        req_processing               <= '0';
        mem_wr_ip_mac_tdata          <= (others => '0');
        mem_wr_ip_mac_tvalid         <= '0';
        axis_arp_to_cache_mac_tdata  <= (others => '0');
        axis_arp_to_cache_mac_tuser  <= (others => '0');
        axis_arp_to_cache_mac_tvalid <= '0';
        axis_from_arp_ip_mac_tready  <= '0';
        
      else

        -- Clear Tvalid
        if (mem_wr_ip_mac_tready = '1') then
          mem_wr_ip_mac_tvalid <= '0';
        end if;

        if (axis_arp_to_cache_mac_tready = '1') then
          axis_arp_to_cache_mac_tvalid <= '0';
        end if;

        -- Memorize the source of the last request 
        if (m_arp_ip_addr_tvalid_i = '1') and (M_ARP_IP_ADDR_TREADY = '1') then
          req_source     <= m_arp_ip_addr_tid(0);
          req_processing <= '1';
        end if;
        
        
        -- assert input tready
        if ((not (mem_wr_ip_mac_tvalid = '1')) or (mem_wr_ip_mac_tready = '1')) and 
           ((not (axis_arp_to_cache_mac_tvalid = '1')) or (axis_arp_to_cache_mac_tready = '1')) then
          axis_from_arp_ip_mac_tready <= '1';
        end if;

        -- Received data from arp controller
        if (axis_from_arp_ip_mac_tvalid = '1') and (axis_from_arp_ip_mac_tready = '1') then
          axis_from_arp_ip_mac_tready <= '0';
          
          -- No Reponse (Timeout in arp_controler) following a previous request => ACK KO
          if (axis_from_arp_ip_mac_tuser = "1") then
            req_processing <= '0';

            -- Following source request
            if (req_source = C_CACHE_REQUEST) then -- send invalid response
              axis_arp_to_cache_mac_tdata  <= (others => '0'); -- Data are invalidate by tuser
              axis_arp_to_cache_mac_tuser  <= (others => '1'); -- Invalid contents
              axis_arp_to_cache_mac_tvalid <= '1';
              -- elsif (source_request = C_USER_REQUEST) then => Nothing to do 
            end if;

          else
            -- Save couple in memory (from request or / gratuitous ARP)
            mem_wr_ip_mac_tdata  <= axis_from_arp_ip_mac_tdata;
            mem_wr_ip_mac_tvalid <= '1';

            if (req_processing = '1') then
              req_processing <= '0';
              if (axis_from_arp_ip_mac_tdata(31 downto 0) = cache_ip_addr) then
                axis_arp_to_cache_mac_tdata  <= axis_from_arp_ip_mac_tdata(79 downto 32);
                axis_arp_to_cache_mac_tuser  <= (others => '0'); -- Valid contents
                axis_arp_to_cache_mac_tvalid <= '1';
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process p_arp_return;

  ---------------------------------------------------------------------
  -- ARP Table memory
  ---------------------------------------------------------------------
  inst_uoe_arp_table_memory : uoe_arp_table_memory
    generic map(
      G_ACTIVE_RST => G_ACTIVE_RST,
      G_ASYNC_RST  => G_ASYNC_RST
    )
    port map(
      CLK                    => CLK,
      RST                    => RST,
      S_MEM_RD_IP_TDATA      => mem_rd_ip_tdata,
      S_MEM_RD_IP_TVALID     => mem_rd_ip_tvalid,
      S_MEM_RD_IP_TREADY     => mem_rd_ip_tready,
      M_MEM_RD_MAC_TDATA     => mem_rd_mac_tdata,
      M_MEM_RD_MAC_TUSER     => mem_rd_mac_tuser,
      M_MEM_RD_MAC_TVALID    => mem_rd_mac_tvalid,
      M_MEM_RD_MAC_TREADY    => mem_rd_mac_tready,
      S_MEM_WR_IP_MAC_TDATA  => mem_wr_ip_mac_tdata,
      S_MEM_WR_IP_MAC_TVALID => mem_wr_ip_mac_tvalid,
      S_MEM_WR_IP_MAC_TREADY => mem_wr_ip_mac_tready,
      CLEAR_ARP              => CLEAR_ARP,
      CLEAR_ARP_DONE         => CLEAR_ARP_DONE,
      S_AXI_AWADDR           => S_AXI_AWADDR,
      S_AXI_AWVALID          => S_AXI_AWVALID,
      S_AXI_AWREADY          => S_AXI_AWREADY,
      S_AXI_WDATA            => S_AXI_WDATA,
      S_AXI_WVALID           => S_AXI_WVALID,
      S_AXI_WREADY           => S_AXI_WREADY,
      S_AXI_BRESP            => S_AXI_BRESP,
      S_AXI_BVALID           => S_AXI_BVALID,
      S_AXI_BREADY           => S_AXI_BREADY,
      S_AXI_ARADDR           => S_AXI_ARADDR,
      S_AXI_ARVALID          => S_AXI_ARVALID,
      S_AXI_ARREADY          => S_AXI_ARREADY,
      S_AXI_RDATA            => S_AXI_RDATA,
      S_AXI_RRESP            => S_AXI_RRESP,
      S_AXI_RVALID           => S_AXI_RVALID,
      S_AXI_RREADY           => S_AXI_RREADY
    );

  -- Multiplexer to arp module
  inst_axis_mux_custom_to_arp : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => 32,
      G_TID_WIDTH           => 1,
      G_NB_SLAVE            => 2,
      G_REG_SLAVES_FORWARD  => "00",
      G_REG_SLAVES_BACKWARD => "00",
      G_REG_MASTER_FORWARD  => true,  -- Only register FW path
      G_REG_MASTER_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA(63 downto 32) => axis_to_arp_ip_user_tdata,
      S_TDATA(31 downto 0)  => axis_to_arp_ip_tdata,
      S_TVALID(1)           => axis_to_arp_ip_user_tvalid,
      S_TVALID(0)           => axis_to_arp_ip_tvalid,
      S_TID(1)              => C_USER_REQUEST,
      S_TID(0)              => C_CACHE_REQUEST,
      S_TREADY(1)           => axis_to_arp_ip_user_tready,
      S_TREADY(0)           => axis_to_arp_ip_tready,
      M_TDATA               => M_ARP_IP_ADDR_TDATA,
      M_TVALID              => m_arp_ip_addr_tvalid_i,
      M_TID                 => m_arp_ip_addr_tid,
      M_TREADY              => M_ARP_IP_ADDR_TREADY
    );

  -- Multiplexer to cache
  inst_axis_mux_custom_to_cache : axis_mux_custom
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => 48,
      G_TUSER_WIDTH         => 1,
      G_NB_SLAVE            => 2,
      G_REG_SLAVES_FORWARD  => "00",
      G_REG_SLAVES_BACKWARD => "00",
      G_REG_MASTER_FORWARD  => true,  -- Only register FW path
      G_REG_MASTER_BACKWARD => false
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      S_TDATA(95 downto 48) => axis_arp_to_cache_mac_tdata,
      S_TDATA(47 downto 0)  => axis_mem_to_cache_mac_tdata,
      S_TVALID(1)           => axis_arp_to_cache_mac_tvalid,
      S_TVALID(0)           => axis_mem_to_cache_mac_tvalid,
      S_TUSER(1 downto 1)   => axis_arp_to_cache_mac_tuser,
      S_TUSER(0 downto 0)   => "0",
      S_TREADY(1)           => axis_arp_to_cache_mac_tready,
      S_TREADY(0)           => axis_mem_to_cache_mac_tready,
      M_TDATA               => M_CACHE_MAC_ADDR_TDATA,
      M_TVALID              => m_cache_mac_addr_tvalid_i,
      M_TUSER               => M_CACHE_MAC_ADDR_TUSER,
      M_TREADY              => M_CACHE_MAC_ADDR_TREADY
    );

end rtl;
