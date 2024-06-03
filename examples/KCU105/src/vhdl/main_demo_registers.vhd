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
entity main_demo_registers is
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
end main_demo_registers;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of main_demo_registers is


  --------------------------------------------
  -- FUNCTIONS
  --------------------------------------------
  -- Set new value on register according to strobe, old data and mask
  function set_reg_val (signal   old_reg   : in std_logic_vector(31 downto 0);
                        signal   wr_strobe : in std_logic_vector(31 downto 0);
                        signal   wr_data   : in std_logic_vector(31 downto 0);
                        constant reg_mask  : in std_logic_vector(31 downto 0)) return std_logic_vector is
    variable new_reg: std_logic_vector(31 downto 0) := old_reg;
  begin

    -- Loop on all bits of register
    for i in 31 downto 0 loop
      if (wr_strobe(i) = '1') and (reg_mask(i) = '1') then
        new_reg(i) := wr_data(i);
      end if;
    end loop;

    return new_reg;
  end function set_reg_val;


  --------------------------------------------
  -- CONSTANTS
  --------------------------------------------
  -- Define the size of each register by masking all unused bits
  constant C_REG_UOE_10G_TARGET_IP   : std_logic_vector(31 downto 0):="11111111111111111111111111111111"; 
  constant C_REG_UOE_10G_UDP_PORT    : std_logic_vector(31 downto 0):="00000000000000001111111111111111"; 
  constant C_REG_UOE_1G_TARGET_IP    : std_logic_vector(31 downto 0):="11111111111111111111111111111111"; 
  constant C_REG_UOE_1G_UDP_PORT     : std_logic_vector(31 downto 0):="00000000000000001111111111111111"; 



  --------------------------------------------
  -- SIGNALS
  --------------------------------------------
  -- AXI4-Lite signals
  signal axi_wr_init                 : std_logic;
  signal axi_rd_init                 : std_logic;
  signal axi_awvalid                 : std_logic;
  signal axi_wvalid                  : std_logic;

  signal s_axi_bvalid_i              : std_logic_vector(0 downto 0);
  signal s_axi_awready_i             : std_logic_vector(0 downto 0);
  signal s_axi_wready_i              : std_logic_vector(0 downto 0);

  signal s_axi_rvalid_i              : std_logic_vector(0 downto 0);
  signal s_axi_arready_i             : std_logic_vector(0 downto 0);

  -- Internal write transactions
  signal wr_req                      : std_logic;
  signal wr_req_r                    : std_logic;
  signal wr_addr                     : std_logic_vector(7 downto 0);
  signal wr_data                     : std_logic_vector(31 downto 0);
  signal wr_strobe                   : std_logic_vector(31 downto 0);
  signal bad_wr_addr                 : std_logic;

  -- Internal read transactions
  signal rd_req                      : std_logic;
  signal rd_req_r                    : std_logic;
  signal rd_addr                     : std_logic_vector(7 downto 0);
  signal rd_data                     : std_logic_vector(31 downto 0);
  signal bad_rd_addr                 : std_logic;

  -- Write registers
  signal reg_uoe_10g_target_ip_int  : std_logic_vector(31 downto 0); 
  signal reg_uoe_10g_udp_port_int   : std_logic_vector(31 downto 0); 
  signal reg_uoe_1g_target_ip_int   : std_logic_vector(31 downto 0); 
  signal reg_uoe_1g_udp_port_int    : std_logic_vector(31 downto 0); 



begin


  --------------------------------------------
  --    AXI WRITE PROCESS
  --------------------------------------------
  -- Process: P_AXI_WR
  -- Description:
  -- Management of write channels
  -- AXI4-Lite slave will be ready to accept new write transactions
  -- only when previous transaction response has been accepted
  --------------------------------------------
  P_AXI_WR : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_awready_i <= "0";
        s_axi_wready_i  <= "0";

        axi_awvalid     <= '0';
        axi_wvalid      <= '0';

        axi_wr_init     <= '1';

        wr_req          <= '0';
        wr_addr         <= (others => '0');
        wr_data         <= (others => '0');
        wr_strobe       <= (others => '1');

      else
        -- Default
        wr_req <= '0';

        -- AXI4-Lite slave will be ready to accept new write transactions
        -- only when previous transaction response has been accepted
        if (s_axi_bvalid_i = "1") and (S_AXI_BREADY = "1") then
          s_axi_awready_i <= "1";
          s_axi_wready_i  <= "1";

        -- AXI4 write channels are ready after reset
        elsif axi_wr_init = '1' then
          s_axi_awready_i <= "1";
          s_axi_wready_i  <= "1";
          axi_wr_init     <= '0';

        end if;

        --
        -- Manage internal write requests
        --

        -- Write address request
        if (S_AXI_AWVALID = "1") and (s_axi_awready_i = "1") then
          axi_awvalid     <= '1';
          wr_addr         <= S_AXI_AWADDR;
          s_axi_awready_i <= "0";
        end if;

        -- Write data request
        if (S_AXI_WVALID = "1") and (s_axi_wready_i = "1") then
          axi_wvalid     <= '1';
          wr_data        <= S_AXI_WDATA;
          s_axi_wready_i <= "0";

          -- Convert strobe to data size
          for i in S_AXI_WSTRB'high downto 0 loop
            if (S_AXI_WSTRB(i) = '1') then
              wr_strobe(i*8 +7 downto i*8) <= (others => '1');
            else
              wr_strobe(i*8 +7 downto i*8) <= (others => '0');
            end if;
          end loop;

        end if;

        -- Write request complete
        if (axi_awvalid = '1') and (axi_wvalid = '1') then
          wr_req      <= '1';
          axi_awvalid <= '0';
          axi_wvalid  <= '0';
        end if;

      end if;
    end if;
  end process P_AXI_WR;

  -- Output assignment
  S_AXI_AWREADY <= s_axi_awready_i;
  S_AXI_WREADY  <= s_axi_wready_i;


  --------------------------------------------
  --    AXI WRITE RESPONSE PROCESS
  --------------------------------------------
  -- Process: P_AXI_WR_RESP
  -- Description:
  -- Implement write response logic generation
  -- The write response and response valid signals are asserted by the slave
  -- when wr_req_r is asserted.
  -- This marks the acceptance of address and indicates the status of
  -- write transaction.
  --------------------------------------------
  P_AXI_WR_RESP : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_bvalid_i <= "0";
        S_AXI_BRESP    <= "00";

        wr_req_r       <= '0';

      else
        -- Register
        wr_req_r <= wr_req;

        -- Set response when write command has been processed
        if wr_req_r = '1' then
          s_axi_bvalid_i <= "1";
          S_AXI_BRESP    <= bad_wr_addr & "0"; -- OKAY or SLVERR response
        elsif S_AXI_BREADY = "1" then -- check if bready is asserted while bvalid is high)
          s_axi_bvalid_i <= "0";
        end if;
      end if;
    end if;
  end process P_AXI_WR_RESP;

  -- Output assignment
  S_AXI_BVALID <= s_axi_bvalid_i;


  --------------------------------------------
  -- Process: P_REG_WRITE
  -- Description: Manage input data to write to
  -- registers
  --------------------------------------------
  P_REG_WRITE : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        bad_wr_addr               <= '0';

        reg_uoe_10g_target_ip_int(31 downto 0) <= "00000000000000000000000000000000"; 
        reg_uoe_10g_udp_port_int(15 downto 0) <= "0000000000000000"; 
        reg_uoe_1g_target_ip_int(31 downto 0) <= "00000000000000000000000000000000"; 
        reg_uoe_1g_udp_port_int(15 downto 0) <= "0000000000000000"; 


      else

        -- Default
        bad_wr_addr <= '0';



        if (wr_req = '1') then
          -- Decode register address to write
          case wr_addr is

            when C_MAIN_REG_UOE_10G_TARGET_IP => 
              reg_uoe_10g_target_ip_int   <= set_reg_val(reg_uoe_10g_target_ip_int, wr_strobe, wr_data, C_REG_UOE_10G_TARGET_IP);
            when C_MAIN_REG_UOE_10G_UDP_PORT => 
              reg_uoe_10g_udp_port_int    <= set_reg_val(reg_uoe_10g_udp_port_int, wr_strobe, wr_data, C_REG_UOE_10G_UDP_PORT);
            when C_MAIN_REG_UOE_1G_TARGET_IP => 
              reg_uoe_1g_target_ip_int    <= set_reg_val(reg_uoe_1g_target_ip_int, wr_strobe, wr_data, C_REG_UOE_1G_TARGET_IP);
            when C_MAIN_REG_UOE_1G_UDP_PORT => 
              reg_uoe_1g_udp_port_int     <= set_reg_val(reg_uoe_1g_udp_port_int, wr_strobe, wr_data, C_REG_UOE_1G_UDP_PORT);

            when others =>
              bad_wr_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_WRITE;

  -- Output assignments
  UOE_10G_TARGET_IP           <= reg_uoe_10g_target_ip_int(31 downto 0);
  UOE_10G_PORT_SRC            <= reg_uoe_10g_udp_port_int(15 downto 0);
  UOE_1G_TARGET_IP            <= reg_uoe_1g_target_ip_int(31 downto 0);
  UOE_1G_PORT_SRC             <= reg_uoe_1g_udp_port_int(15 downto 0);



  --------------------------------------------
  --    AXI READ PROCESS
  --------------------------------------------
  -- Process: P_AXI_RD
  -- Description:
  -- Management of read channels
  -- AXI4-Lite slave will be ready to accept new read transactions
  -- only when previous transaction response has been accepted
  --------------------------------------------
  P_AXI_RD : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_arready_i <= "0";

        axi_rd_init     <= '1';

        rd_req          <= '0';
        rd_addr         <= (others => '0');

      else
        -- Default
        rd_req <= '0';

        -- AXI4-Lite slave will be ready to accept new read transactions
        -- only when previous transaction response has been accepted
        if (s_axi_rvalid_i = "1") and (S_AXI_RREADY = "1") then
          s_axi_arready_i <= "1";

        -- AXI4 write channels are ready after reset
        elsif axi_rd_init = '1' then
          s_axi_arready_i <= "1";
          axi_rd_init     <= '0';

        end if;

        -- Manage internal read requests
        if (S_AXI_ARVALID = "1") and (s_axi_arready_i = "1") then
          rd_addr         <= S_AXI_ARADDR;
          s_axi_arready_i <= "0";
          rd_req          <= '1';
        end if;

      end if;
    end if;
  end process P_AXI_RD;

  -- Output assignment
  S_AXI_ARREADY <= s_axi_arready_i;


  --------------------------------------------
  -- AXI READ RESPONSE PROCESS
  --------------------------------------------
  -- Process: P_AXI_RD_RESP
  -- Description:
  -- Implement axi_arvalid generation
  -- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both
  -- S_AXI_ARVALID and axi_arready are asserted. The slave registers
  -- data are available on the axi_rdata bus at this instance. The
  -- assertion of axi_rvalid marks the validity of read data on the
  -- bus and axi_rresp indicates the status of read transaction.axi_rvalid
  -- is de-asserted on reset (active low). axi_rresp and axi_rdata are
  -- cleared to zero on reset (active low).
  --------------------------------------------
  P_AXI_RD_RESP : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        s_axi_rvalid_i <= "0";
        S_AXI_RRESP    <= "00";
        S_AXI_RDATA    <= (others => '0');

        rd_req_r       <= '0';

      else
        -- Register
        rd_req_r <= rd_req;

        -- Set response when read command has been processed
        if rd_req_r = '1' then
          -- Valid read data is available at the read data bus
          s_axi_rvalid_i <= "1";
          S_AXI_RRESP    <= bad_rd_addr & "0";   -- OKAY or SLVERR response
          S_AXI_RDATA    <= rd_data;
        elsif S_AXI_RREADY = "1" then
          -- Read data is accepted by the master
          s_axi_rvalid_i <= "0";
        end if;
      end if;
    end if;
  end process P_AXI_RD_RESP;

  -- Output assignment
  S_AXI_RVALID <= s_axi_rvalid_i;


  --------------------------------------------
  -- Process: P_REG_READ
  -- Description: Manage output data read from
  -- registers
  --------------------------------------------
  P_REG_READ : process(S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then

      -- Synchronous reset
      if (S_AXI_ARESET = '1') then
        bad_rd_addr <= '0';
        rd_data     <= (others => '0');



      else
        -- Default
        bad_rd_addr <= '0';
        rd_data     <= (others => '0');



        if (rd_req = '1') then
          -- Decode register address to read
          case rd_addr is

            when C_MAIN_REG_VERSION => 
              rd_data(7 downto 0)         <= VERSION;
              rd_data(15 downto 8)        <= REVISION;
              rd_data(27 downto 16)       <= DEBUG;
              rd_data(31 downto 28)       <= BOARD_ID;
            when C_MAIN_REG_UOE_10G_TARGET_IP => 
              rd_data(31 downto 0)        <= reg_uoe_10g_target_ip_int(31 downto 0);
            when C_MAIN_REG_UOE_10G_UDP_PORT => 
              rd_data(15 downto 0)        <= reg_uoe_10g_udp_port_int(15 downto 0);
            when C_MAIN_REG_UOE_1G_TARGET_IP => 
              rd_data(31 downto 0)        <= reg_uoe_1g_target_ip_int(31 downto 0);
            when C_MAIN_REG_UOE_1G_UDP_PORT => 
              rd_data(15 downto 0)        <= reg_uoe_1g_udp_port_int(15 downto 0);

            when others =>
              bad_rd_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_READ;


end rtl;
