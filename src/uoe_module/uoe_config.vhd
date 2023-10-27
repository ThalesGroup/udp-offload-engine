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
use work.package_uoe_registers.all;

entity uoe_config is
  generic(
    G_ACTIVE_RST              : std_logic                     := '0';                                   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST               : boolean                       := false;                                 -- Type of reset used (synchronous or asynchronous resets)
    G_ARP_TIMEOUT_MS          : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(2, 12));  -- Max. time to wait an ARP answer before assert ARP_ERROR (in ms)
    G_ARP_TRYINGS             : std_logic_vector(3 downto 0)  := std_logic_vector(to_unsigned(3, 4));   -- Number of Query Retries
    G_ARP_RX_TARGET_IP_FILTER : std_logic_vector(1 downto 0)  := "00"                                   -- 0 => Unicast, 1 => + Broadcast, 2 => No filter, 3 => Static Table
  );
  port(
    -- Internal clock domain
    CLK               : in  std_logic;
    RST               : in  std_logic;
    -- Control / Status
    START             : in  std_logic;
    LOCAL_MAC_ADDR    : in  std_logic_vector(47 downto 0);
    LOCAL_IP_ADDR     : in  std_logic_vector(31 downto 0);
    DONE              : out std_logic;
    ARP_ERROR         : out std_logic;
    ARP_IP_CONFLICT   : out std_logic;
    ARP_MAC_CONFLICT  : out std_logic;
    -- Interruption
    INTERRUPT         : in  std_logic;
    -- AXI4-Lite interface
    M_AXI_AWADDR      : out std_logic_vector(13 downto 0);
    M_AXI_AWVALID     : out std_logic;
    M_AXI_AWREADY     : in  std_logic;
    M_AXI_WDATA       : out std_logic_vector(31 downto 0);
    M_AXI_WVALID      : out std_logic;
    M_AXI_WSTRB       : out std_logic_vector(3 downto 0);
    M_AXI_WREADY      : in  std_logic;
    M_AXI_BRESP       : in  std_logic_vector(1 downto 0); -- Not used
    M_AXI_BVALID      : in  std_logic;
    M_AXI_BREADY      : out std_logic;
    M_AXI_ARADDR      : out std_logic_vector(13 downto 0);
    M_AXI_ARVALID     : out std_logic;
    M_AXI_ARREADY     : in  std_logic;
    M_AXI_RDATA       : in  std_logic_vector(31 downto 0);
    M_AXI_RRESP       : in  std_logic_vector(1 downto 0); -- Not used
    M_AXI_RVALID      : in  std_logic;
    M_AXI_RREADY      : out std_logic
  );
end uoe_config;

architecture rtl of uoe_config is
  
  --------------------------
  -- Type declaration
  --------------------------
  
  -- Record for FSM
  type t_state is (ST_IDLE, ST_CONFIG, ST_STATUS, ST_CLEAR);
  
  -- Type for address and data list
  type t_array_addr is array (natural range <>) of std_logic_vector(13 downto 0);
  type t_array_data is array (natural range <>) of std_logic_vector(31 downto 0);
  
  --------------------------
  -- Constants declaration
  --------------------------
  
  constant C_BASE_ADDR_MAIN_REGS : std_logic_vector(1 downto 0) := "00";
  --constant C_BASE_ADDR_ARP_TABLE : std_logic_vector(1 downto 0) := "01";
  --constant C_BASE_ADDR_TEST_REGS : std_logic_vector(1 downto 0) := "10";
  
  constant C_UOE_CFG_ADDR : t_array_addr(5 downto 0) := (
    -- MAC Address
    0 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_LOCAL_MAC_ADDR_LSB,
    1 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_LOCAL_MAC_ADDR_MSB,
    -- IP Address
    2 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_LOCAL_IP_ADDR,
    -- ARP
    3 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_ARP_CONFIGURATION,
    -- Interruption Enable
    4 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_INTERRUPT_ENABLE,
    -- Config done
    5 => C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_CONFIG_DONE
  );
  
  constant C_ARP_CONFIG : std_logic_vector(31 downto 0) := (11 downto 0  => G_ARP_TIMEOUT_MS,
                                                            15 downto 12 => G_ARP_TRYINGS,
                                                            18 downto 17 => G_ARP_RX_TARGET_IP_FILTER,
                                                            others => '0');
  
  --------------------------
  -- Signals declaration
  --------------------------
  
  signal state        : t_state;
  signal cnt          : integer range 0 to 6;
  signal uoe_cfg_data : t_array_data(5 downto 0);
  
begin
  
  -- Assignement
  uoe_cfg_data(0) <= LOCAL_MAC_ADDR(31 downto 0);
  uoe_cfg_data(1) <= x"0000" & LOCAL_MAC_ADDR(47 downto 32);
  uoe_cfg_data(2) <= LOCAL_IP_ADDR;
  uoe_cfg_data(3) <= C_ARP_CONFIG;
  uoe_cfg_data(4) <= (0 => '1', 4 downto 2 => "111", others => '0');
  uoe_cfg_data(5) <= (0 => '1', others => '0');
  
  -- Not used
  M_AXI_WSTRB <= (others => '1');
  
  -- Configuration Handler
  P_CONFIG : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      state            <= ST_IDLE;
      cnt              <= 0;
      DONE             <= '0';
      ARP_ERROR        <= '0';
      ARP_IP_CONFLICT  <= '0';
      ARP_MAC_CONFLICT <= '0';
      M_AXI_AWADDR     <= (others => '0');
      M_AXI_AWVALID    <= '0';
      M_AXI_WDATA      <= (others => '0');
      M_AXI_WVALID     <= '0';
      M_AXI_ARADDR     <= (others => '0');
      M_AXI_ARVALID    <= '0';
      M_AXI_BREADY     <= '0';
      M_AXI_RREADY     <= '0';
      
    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        state            <= ST_IDLE;
        cnt              <= 0;
        DONE             <= '0';
        ARP_ERROR        <= '0';
        ARP_IP_CONFLICT  <= '0';
        ARP_MAC_CONFLICT <= '0';
        M_AXI_AWADDR     <= (others => '0');
        M_AXI_AWVALID    <= '0';
        M_AXI_WDATA      <= (others => '0');
        M_AXI_WVALID     <= '0';
        M_AXI_ARADDR     <= (others => '0');
        M_AXI_ARVALID    <= '0';
        M_AXI_BREADY     <= '0';
        M_AXI_RREADY     <= '0';
        
      else
        
        -- Handshake
        if M_AXI_AWREADY = '1' then
          M_AXI_AWVALID <= '0';
        end if;
        
        if M_AXI_WREADY = '1' then
          M_AXI_WVALID <= '0';
        end if;
        
        if M_AXI_ARREADY = '1' then
          M_AXI_ARVALID <= '0';
        end if;
        
        -- FSM
        case state is
          
        ----------------------------
        -- Initial State : Wait Configuration request
        --                 or Wake up on interrupt
        ----------------------------
        
        when ST_IDLE =>
        
          if START = '1' then
            state         <= ST_CONFIG;
            cnt           <= cnt + 1;
            M_AXI_AWADDR  <= C_UOE_CFG_ADDR(cnt);
            M_AXI_AWVALID <= '1';
            M_AXI_WDATA   <= uoe_cfg_data(cnt);
            M_AXI_WVALID  <= '1';
            
          elsif INTERRUPT = '1' then
            state         <= ST_STATUS;
            M_AXI_ARADDR  <= C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_INTERRUPT_STATUS;
            M_AXI_ARVALID <= '1';
          end if;
          
        ----------------------------
        -- Configuration State : Write sequence of registers
        ----------------------------
        
        when ST_CONFIG =>
          M_AXI_BREADY <= '1';
          if M_AXI_BVALID = '1' then
            if cnt < C_UOE_CFG_ADDR'length then
              cnt           <= cnt + 1;
              M_AXI_AWADDR  <= C_UOE_CFG_ADDR(cnt);
              M_AXI_AWVALID <= '1';
              M_AXI_WDATA   <= uoe_cfg_data(cnt);
              M_AXI_WVALID  <= '1';
            else
              state         <= ST_IDLE;
              cnt           <= 0;
              M_AXI_BREADY  <= '0';
            end if;
          end if;
          
        ----------------------------
        -- Read Interrupt Status 
        ----------------------------
        when ST_STATUS =>
          M_AXI_RREADY <= '1';
          if M_AXI_RVALID = '1' then
            state            <= ST_CLEAR;
            -- Do not rewrite DONE if already occured
            if (DONE /= '1') then
              DONE             <= M_AXI_RDATA(0);
            end if;
            ARP_IP_CONFLICT  <= M_AXI_RDATA(2);
            ARP_MAC_CONFLICT <= M_AXI_RDATA(3);
            ARP_ERROR        <= M_AXI_RDATA(4);
            M_AXI_RREADY     <= '0';
            M_AXI_AWADDR     <= C_BASE_ADDR_MAIN_REGS & x"0" & C_MAIN_REG_INTERRUPT_CLEAR;
            M_AXI_AWVALID    <= '1';
            M_AXI_WDATA      <= M_AXI_RDATA;
            M_AXI_WVALID     <= '1';
          end if;
          
        ----------------------------
        -- Clear Interrupt
        ----------------------------
        when ST_CLEAR =>
          M_AXI_BREADY <= '1';
          if M_AXI_BVALID = '1' then
            state <= ST_IDLE;
          end if;
        end case;
      end if;
    end if;
  end process P_CONFIG;
       
end rtl;
