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
use work.package_uoe_registers.all;


------------------------------------------------------------------------
-- Entity declaration
------------------------------------------------------------------------
entity main_uoe_registers is
  port(
    ----------------------
    -- AXI4-Lite bus
    ----------------------
    S_AXI_ACLK                                        : in  std_logic;                                             -- Global clock signal
    S_AXI_ARESET                                      : in  std_logic;                                             -- Global reset signal synchronous to clock S_AXI_ACLK
    S_AXI_AWADDR                                      : in  std_logic_vector(7 downto 0);                          -- Write address (issued by master, accepted by Slave)
    S_AXI_AWVALID                                     : in  std_logic_vector(0 downto 0);                          -- Write address valid: this signal indicates that the master is signalling valid write address and control information.
    S_AXI_AWREADY                                     : out std_logic_vector(0 downto 0);                          -- Write address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_WDATA                                       : in  std_logic_vector(31 downto 0);                         -- Write data (issued by master, accepted by slave)
    S_AXI_WVALID                                      : in  std_logic_vector(0 downto 0);                          -- Write valid: this signal indicates that valid write data and strobes are available.
    S_AXI_WSTRB                                       : in  std_logic_vector(3 downto 0);                          -- Write strobes: WSTRB[n:0] signals when HIGH, specify the byte lanes of the data bus that contain valid information
    S_AXI_WREADY                                      : out std_logic_vector(0 downto 0);                          -- Write ready: this signal indicates that the slave can accept the write data.
    S_AXI_BRESP                                       : out std_logic_vector(1 downto 0);                          -- Write response: this signal indicates the status of the write transaction.
    S_AXI_BVALID                                      : out std_logic_vector(0 downto 0);                          -- Write response valid: this signal indicates that the channel is signalling a valid write response.
    S_AXI_BREADY                                      : in  std_logic_vector(0 downto 0);                          -- Response ready: this signal indicates that the master can accept a write response.
    S_AXI_ARADDR                                      : in  std_logic_vector(7 downto 0);                          -- Read address (issued by master, accepted by Slave)
    S_AXI_ARVALID                                     : in  std_logic_vector(0 downto 0);                          -- Read address valid: this signal indicates that the channel is signalling valid read address and control information.
    S_AXI_ARREADY                                     : out std_logic_vector(0 downto 0);                          -- Read address ready: this signal indicates that the slave is ready to accept an address and associated control signals.
    S_AXI_RDATA                                       : out std_logic_vector(31 downto 0);                         -- Read data (issued by slave)
    S_AXI_RRESP                                       : out std_logic_vector(1 downto 0);                          -- Read response: this signal indicates the status of the read transfer.
    S_AXI_RVALID                                      : out std_logic_vector(0 downto 0);                          -- Read valid: this signal indicates that the channel is signalling the required read data.
    S_AXI_RREADY                                      : in  std_logic_vector(0 downto 0);                          -- Read ready: this signal indicates that the master can accept the read data and response information.

    ----------------------
    -- Input data for registers
    ----------------------
    -- RO Registers
    VERSION                                           : in  std_logic_vector(7 downto 0);                          -- Version number
    REVISION                                          : in  std_logic_vector(7 downto 0);                          -- Revision number
    DEBUG                                             : in  std_logic_vector(15 downto 0);                         -- Debug number
    -- RZ Registers
    CRC_FILTER_COUNTER                                : in  std_logic_vector(31 downto 0);                         -- Number of frames filtered because of bad CRC
    MAC_FILTER_COUNTER                                : in  std_logic_vector(31 downto 0);                         -- Number of frames filtered following MAC configuration
    EXT_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on externe interface
    RAW_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on raw interface
    UDP_DROP_COUNTER                                  : in  std_logic_vector(31 downto 0);                         -- Number of frames dropped on udp interface
    -- WO Registers
    ARP_SW_REQ_DEST_IP_ADDR_IN                        : in  std_logic_vector(31 downto 0);                         -- Destination IP Address use to generate software request ARP
    -- Irq WO Registers
    IRQ_INIT_DONE_CLEAR_IN                            : in  std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_IN                 : in  std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_CLEAR_IN                      : in  std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_CLEAR_IN                     : in  std_logic;                                             -- Field description
    IRQ_ARP_ERROR_CLEAR_IN                            : in  std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_IN                 : in  std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_IN         : in  std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_IN          : in  std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_IN            : in  std_logic;                                             -- Field description
    IRQ_INIT_DONE_SET_IN                              : in  std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_SET_IN                   : in  std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_SET_IN                        : in  std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_SET_IN                       : in  std_logic;                                             -- Field description
    IRQ_ARP_ERROR_SET_IN                              : in  std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_SET_IN                   : in  std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_IN           : in  std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_IN            : in  std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_IN              : in  std_logic;                                             -- Field description
    -- Irq RO Registers
    IRQ_INIT_DONE_STATUS                              : in  std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_STATUS                   : in  std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_STATUS                        : in  std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_STATUS                       : in  std_logic;                                             -- Field description
    IRQ_ARP_ERROR_STATUS                              : in  std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_STATUS                   : in  std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_STATUS           : in  std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_STATUS            : in  std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_STATUS              : in  std_logic;                                             -- Field description

    ----------------------
    -- Registers output data
    ----------------------
    -- RW Registers
    LOCAL_MAC_ADDR_LSB                                : out std_logic_vector(31 downto 0);                         -- Local MAC Address LSB
    LOCAL_MAC_ADDR_MSB                                : out std_logic_vector(15 downto 0);                         -- Local MAC Address MSB
    LOCAL_IP_ADDR                                     : out std_logic_vector(31 downto 0);                         -- Local IP Address
    RAW_DEST_MAC_ADDR_LSB                             : out std_logic_vector(31 downto 0);                         -- Destination MAC Address use for RAW Ethernet (LSB)
    RAW_DEST_MAC_ADDR_MSB                             : out std_logic_vector(15 downto 0);                         -- Destination MAC Address use for RAW Ethernet (MSB)
    TTL                                               : out std_logic_vector(7 downto 0);                          -- Time To Leave value insert in IPV4 Header
    BROADCAST_FILTER_ENABLE                           : out std_logic;                                             -- Broadcast frames filtering enabling
    IPV4_MULTICAST_FILTER_ENABLE                      : out std_logic;                                             -- IPv4 multicast frames filtering enabling
    UNICAST_FILTER_ENABLE                             : out std_logic;                                             -- Unicast frames filtering enabling (neither IPv4 multicast nor broadcast)
    MULTICAST_IP_ADDR_1                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 1 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_1_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 1 enabling
    MULTICAST_IP_ADDR_2                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 2 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_2_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 2 enabling
    MULTICAST_IP_ADDR_3                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 3 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_3_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 3 enabling
    MULTICAST_IP_ADDR_4                               : out std_logic_vector(27 downto 0);                         -- 28 low significant bits of IPv4 multicast address 4 accepted if multicast filtering is enabled
    MULTICAST_IP_ADDR_4_ENABLE                        : out std_logic;                                             -- IPv4 Multicast address 4 enabling
    ARP_TIMEOUT_MS                                    : out std_logic_vector(11 downto 0);                         -- Timeout for ARP request (milliseconds)
    ARP_TRYINGS                                       : out std_logic_vector(3 downto 0);                          -- Number of ARP requests tryings
    ARP_GRATUITOUS_REQ                                : out std_logic;                                             -- Request sending "Gratuitous ARP"
    ARP_RX_TARGET_IP_FILTER                           : out std_logic_vector(1 downto 0);                          -- Set ARP Rx Frame filter (0 : unicast, 1 : unicast + broadcast, 2 : all, 3 : none)
    ARP_RX_TEST_LOCAL_IP_CONFLICT                     : out std_logic;                                             -- Enable test "Local IP ADDR conflict"
    ARP_TABLE_CLEAR                                   : out std_logic;                                             -- Clear ARP Table (Should be drive like a pulse : '0' => '1' => '0')
    CONFIG_DONE                                       : out std_logic;                                             -- Flag Configuration Done
    -- WO Registers
    ARP_SW_REQ_DEST_IP_ADDR_OUT                       : out std_logic_vector(31 downto 0);                         -- Destination IP Address use to generate software request ARP
    -- WO Pulses Registers
    REG_ARP_SW_REQ_WRITE                              : out std_logic;
    -- RZ Pulses Registers
    REG_MONITORING_CRC_FILTER_READ                    : out std_logic;
    REG_MONITORING_MAC_FILTER_READ                    : out std_logic;
    REG_MONITORING_EXT_DROP_READ                      : out std_logic;
    REG_MONITORING_RAW_DROP_READ                      : out std_logic;
    REG_MONITORING_UDP_DROP_READ                      : out std_logic;
    -- Irq RW Registers
    IRQ_INIT_DONE_ENABLE                              : out std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_ENABLE                   : out std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_ENABLE                        : out std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_ENABLE                       : out std_logic;                                             -- Field description
    IRQ_ARP_ERROR_ENABLE                              : out std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_ENABLE                   : out std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_ENABLE           : out std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_ENABLE            : out std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_ENABLE              : out std_logic;                                             -- Field description
    -- Irq WO Registers
    IRQ_INIT_DONE_CLEAR_OUT                           : out std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_OUT                : out std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_CLEAR_OUT                     : out std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_CLEAR_OUT                    : out std_logic;                                             -- Field description
    IRQ_ARP_ERROR_CLEAR_OUT                           : out std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_OUT                : out std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_OUT        : out std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_OUT         : out std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_OUT           : out std_logic;                                             -- Field description
    IRQ_INIT_DONE_SET_OUT                             : out std_logic;                                             -- Field description
    IRQ_ARP_TABLE_CLEAR_DONE_SET_OUT                  : out std_logic;                                             -- Field description
    IRQ_ARP_IP_CONFLICT_SET_OUT                       : out std_logic;                                             -- Field description
    IRQ_ARP_MAC_CONFLICT_SET_OUT                      : out std_logic;                                             -- Field description
    IRQ_ARP_ERROR_SET_OUT                             : out std_logic;                                             -- Field description
    IRQ_ARP_RX_FIFO_OVERFLOW_SET_OUT                  : out std_logic;                                             -- Field description
    IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_OUT          : out std_logic;                                             -- Field description
    IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_OUT           : out std_logic;                                             -- Field description
    IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_OUT             : out std_logic;                                             -- Field description
    -- Irq WO Pulses Registers
    REG_INTERRUPT_CLEAR_WRITE                         : out std_logic;
    REG_INTERRUPT_SET_WRITE                           : out std_logic

  );
end main_uoe_registers;


------------------------------------------------------------------------
-- Architecture declaration
------------------------------------------------------------------------
architecture rtl of main_uoe_registers is


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
  constant C_REG_LOCAL_MAC_ADDR_LSB                    : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_LOCAL_MAC_ADDR_MSB                    : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_LOCAL_IP_ADDR                         : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_RAW_DEST_MAC_ADDR_LSB                 : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_RAW_DEST_MAC_ADDR_MSB                 : std_logic_vector(31 downto 0):="00000000000000001111111111111111";
  constant C_REG_IPV4_TIME_TO_LEAVE                    : std_logic_vector(31 downto 0):="00000000000000000000000011111111";
  constant C_REG_FILTERING_CONTROL                     : std_logic_vector(31 downto 0):="00000000000000000000000000000111";
  constant C_REG_IPV4_MULTICAST_IP_ADDR_1              : std_logic_vector(31 downto 0):="00011111111111111111111111111111";
  constant C_REG_IPV4_MULTICAST_IP_ADDR_2              : std_logic_vector(31 downto 0):="00011111111111111111111111111111";
  constant C_REG_IPV4_MULTICAST_IP_ADDR_3              : std_logic_vector(31 downto 0):="00011111111111111111111111111111";
  constant C_REG_IPV4_MULTICAST_IP_ADDR_4              : std_logic_vector(31 downto 0):="00011111111111111111111111111111";
  constant C_REG_ARP_CONFIGURATION                     : std_logic_vector(31 downto 0):="00000000000111111111111111111111";
  constant C_REG_CONFIG_DONE                           : std_logic_vector(31 downto 0):="00000000000000000000000000000001";
  constant C_REG_INTERRUPT_ENABLE                      : std_logic_vector(31 downto 0):="00000000000000000000000111111111";
  constant C_REG_ARP_SW_REQ                            : std_logic_vector(31 downto 0):="11111111111111111111111111111111";
  constant C_REG_INTERRUPT_CLEAR                       : std_logic_vector(31 downto 0):="00000000000000000000000111111111";
  constant C_REG_INTERRUPT_SET                         : std_logic_vector(31 downto 0):="00000000000000000000000111111111";



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
  signal reg_local_mac_addr_lsb_int                   : std_logic_vector(31 downto 0);
  signal reg_local_mac_addr_msb_int                   : std_logic_vector(31 downto 0);
  signal reg_local_ip_addr_int                        : std_logic_vector(31 downto 0);
  signal reg_raw_dest_mac_addr_lsb_int                : std_logic_vector(31 downto 0);
  signal reg_raw_dest_mac_addr_msb_int                : std_logic_vector(31 downto 0);
  signal reg_ipv4_time_to_leave_int                   : std_logic_vector(31 downto 0);
  signal reg_filtering_control_int                    : std_logic_vector(31 downto 0);
  signal reg_ipv4_multicast_ip_addr_1_int             : std_logic_vector(31 downto 0);
  signal reg_ipv4_multicast_ip_addr_2_int             : std_logic_vector(31 downto 0);
  signal reg_ipv4_multicast_ip_addr_3_int             : std_logic_vector(31 downto 0);
  signal reg_ipv4_multicast_ip_addr_4_int             : std_logic_vector(31 downto 0);
  signal reg_arp_configuration_int                    : std_logic_vector(31 downto 0);
  signal reg_config_done_int                          : std_logic_vector(31 downto 0);
  signal reg_interrupt_enable_int                     : std_logic_vector(31 downto 0);
  signal reg_arp_sw_req_int                           : std_logic_vector(31 downto 0);
  signal reg_interrupt_clear_int                      : std_logic_vector(31 downto 0);
  signal reg_interrupt_set_int                        : std_logic_vector(31 downto 0);



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

        reg_local_mac_addr_lsb_int(31 downto 0)               <= "00000000000000000000000000000000";
        reg_local_mac_addr_msb_int(15 downto 0)               <= "0000000000000000";
        reg_local_ip_addr_int(31 downto 0)                    <= "00000000000000000000000000000000";
        reg_raw_dest_mac_addr_lsb_int(31 downto 0)            <= "11111111111111111111111111111111";
        reg_raw_dest_mac_addr_msb_int(15 downto 0)            <= "1111111111111111";
        reg_ipv4_time_to_leave_int(7 downto 0)                <= "01100100";
        reg_filtering_control_int(0)                          <= '0';
        reg_filtering_control_int(1)                          <= '0';
        reg_filtering_control_int(2)                          <= '0';
        reg_ipv4_multicast_ip_addr_1_int(27 downto 0)         <= "0000000000000000000000000000";
        reg_ipv4_multicast_ip_addr_1_int(28)                  <= '0';
        reg_ipv4_multicast_ip_addr_2_int(27 downto 0)         <= "0000000000000000000000000000";
        reg_ipv4_multicast_ip_addr_2_int(28)                  <= '0';
        reg_ipv4_multicast_ip_addr_3_int(27 downto 0)         <= "0000000000000000000000000000";
        reg_ipv4_multicast_ip_addr_3_int(28)                  <= '0';
        reg_ipv4_multicast_ip_addr_4_int(27 downto 0)         <= "0000000000000000000000000000";
        reg_ipv4_multicast_ip_addr_4_int(28)                  <= '0';
        reg_arp_configuration_int(11 downto 0)                <= "001111101000";
        reg_arp_configuration_int(15 downto 12)               <= "0011";
        reg_arp_configuration_int(16)                         <= '0';
        reg_arp_configuration_int(18 downto 17)               <= "00";
        reg_arp_configuration_int(19)                         <= '0';
        reg_arp_configuration_int(20)                         <= '0';
        reg_config_done_int(0)                                <= '0';
        reg_interrupt_enable_int(0)                           <= '0';
        reg_interrupt_enable_int(1)                           <= '0';
        reg_interrupt_enable_int(2)                           <= '0';
        reg_interrupt_enable_int(3)                           <= '0';
        reg_interrupt_enable_int(4)                           <= '0';
        reg_interrupt_enable_int(5)                           <= '0';
        reg_interrupt_enable_int(6)                           <= '0';
        reg_interrupt_enable_int(7)                           <= '0';
        reg_interrupt_enable_int(8)                           <= '0';
        reg_arp_sw_req_int                                    <= (others => '0');
        reg_interrupt_clear_int                               <= (others => '0');
        reg_interrupt_set_int                                 <= (others => '0');
        REG_ARP_SW_REQ_WRITE                                  <= '0';
        REG_INTERRUPT_CLEAR_WRITE                             <= '0';
        REG_INTERRUPT_SET_WRITE                               <= '0';


      else

        -- Default
        bad_wr_addr <= '0';

        REG_ARP_SW_REQ_WRITE                          <= '0';
        REG_INTERRUPT_CLEAR_WRITE                     <= '0';
        REG_INTERRUPT_SET_WRITE                       <= '0';


        if (wr_req = '1') then
          -- Decode register address to write
          case wr_addr is

            when C_MAIN_REG_LOCAL_MAC_ADDR_LSB => 
              reg_local_mac_addr_lsb_int                    <= set_reg_val(reg_local_mac_addr_lsb_int, wr_strobe, wr_data, C_REG_LOCAL_MAC_ADDR_LSB);
            when C_MAIN_REG_LOCAL_MAC_ADDR_MSB => 
              reg_local_mac_addr_msb_int                    <= set_reg_val(reg_local_mac_addr_msb_int, wr_strobe, wr_data, C_REG_LOCAL_MAC_ADDR_MSB);
            when C_MAIN_REG_LOCAL_IP_ADDR => 
              reg_local_ip_addr_int                         <= set_reg_val(reg_local_ip_addr_int, wr_strobe, wr_data, C_REG_LOCAL_IP_ADDR);
            when C_MAIN_REG_RAW_DEST_MAC_ADDR_LSB => 
              reg_raw_dest_mac_addr_lsb_int                 <= set_reg_val(reg_raw_dest_mac_addr_lsb_int, wr_strobe, wr_data, C_REG_RAW_DEST_MAC_ADDR_LSB);
            when C_MAIN_REG_RAW_DEST_MAC_ADDR_MSB => 
              reg_raw_dest_mac_addr_msb_int                 <= set_reg_val(reg_raw_dest_mac_addr_msb_int, wr_strobe, wr_data, C_REG_RAW_DEST_MAC_ADDR_MSB);
            when C_MAIN_REG_IPV4_TIME_TO_LEAVE => 
              reg_ipv4_time_to_leave_int                    <= set_reg_val(reg_ipv4_time_to_leave_int, wr_strobe, wr_data, C_REG_IPV4_TIME_TO_LEAVE);
            when C_MAIN_REG_FILTERING_CONTROL => 
              reg_filtering_control_int                     <= set_reg_val(reg_filtering_control_int, wr_strobe, wr_data, C_REG_FILTERING_CONTROL);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_1 => 
              reg_ipv4_multicast_ip_addr_1_int              <= set_reg_val(reg_ipv4_multicast_ip_addr_1_int, wr_strobe, wr_data, C_REG_IPV4_MULTICAST_IP_ADDR_1);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_2 => 
              reg_ipv4_multicast_ip_addr_2_int              <= set_reg_val(reg_ipv4_multicast_ip_addr_2_int, wr_strobe, wr_data, C_REG_IPV4_MULTICAST_IP_ADDR_2);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_3 => 
              reg_ipv4_multicast_ip_addr_3_int              <= set_reg_val(reg_ipv4_multicast_ip_addr_3_int, wr_strobe, wr_data, C_REG_IPV4_MULTICAST_IP_ADDR_3);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_4 => 
              reg_ipv4_multicast_ip_addr_4_int              <= set_reg_val(reg_ipv4_multicast_ip_addr_4_int, wr_strobe, wr_data, C_REG_IPV4_MULTICAST_IP_ADDR_4);
            when C_MAIN_REG_ARP_CONFIGURATION => 
              reg_arp_configuration_int                     <= set_reg_val(reg_arp_configuration_int, wr_strobe, wr_data, C_REG_ARP_CONFIGURATION);
            when C_MAIN_REG_CONFIG_DONE => 
              reg_config_done_int                           <= set_reg_val(reg_config_done_int, wr_strobe, wr_data, C_REG_CONFIG_DONE);
            when C_MAIN_REG_INTERRUPT_ENABLE => 
              reg_interrupt_enable_int                      <= set_reg_val(reg_interrupt_enable_int, wr_strobe, wr_data, C_REG_INTERRUPT_ENABLE);
            when C_MAIN_REG_ARP_SW_REQ => 
              reg_arp_sw_req_int                            <= set_reg_val(reg_arp_sw_req_int, wr_strobe, wr_data, C_REG_ARP_SW_REQ);
              REG_ARP_SW_REQ_WRITE                          <= '1';
            when C_MAIN_REG_INTERRUPT_CLEAR => 
              reg_interrupt_clear_int                       <= set_reg_val(reg_interrupt_clear_int, wr_strobe, wr_data, C_REG_INTERRUPT_CLEAR);
              REG_INTERRUPT_CLEAR_WRITE                     <= '1';
            when C_MAIN_REG_INTERRUPT_SET => 
              reg_interrupt_set_int                         <= set_reg_val(reg_interrupt_set_int, wr_strobe, wr_data, C_REG_INTERRUPT_SET);
              REG_INTERRUPT_SET_WRITE                       <= '1';

            when others =>
              bad_wr_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_WRITE;

  -- Output assignments
  LOCAL_MAC_ADDR_LSB                            <= reg_local_mac_addr_lsb_int(31 downto 0);
  LOCAL_MAC_ADDR_MSB                            <= reg_local_mac_addr_msb_int(15 downto 0);
  LOCAL_IP_ADDR                                 <= reg_local_ip_addr_int(31 downto 0);
  RAW_DEST_MAC_ADDR_LSB                         <= reg_raw_dest_mac_addr_lsb_int(31 downto 0);
  RAW_DEST_MAC_ADDR_MSB                         <= reg_raw_dest_mac_addr_msb_int(15 downto 0);
  TTL                                           <= reg_ipv4_time_to_leave_int(7 downto 0);
  BROADCAST_FILTER_ENABLE                       <= reg_filtering_control_int(0);
  IPV4_MULTICAST_FILTER_ENABLE                  <= reg_filtering_control_int(1);
  UNICAST_FILTER_ENABLE                         <= reg_filtering_control_int(2);
  MULTICAST_IP_ADDR_1                           <= reg_ipv4_multicast_ip_addr_1_int(27 downto 0);
  MULTICAST_IP_ADDR_1_ENABLE                    <= reg_ipv4_multicast_ip_addr_1_int(28);
  MULTICAST_IP_ADDR_2                           <= reg_ipv4_multicast_ip_addr_2_int(27 downto 0);
  MULTICAST_IP_ADDR_2_ENABLE                    <= reg_ipv4_multicast_ip_addr_2_int(28);
  MULTICAST_IP_ADDR_3                           <= reg_ipv4_multicast_ip_addr_3_int(27 downto 0);
  MULTICAST_IP_ADDR_3_ENABLE                    <= reg_ipv4_multicast_ip_addr_3_int(28);
  MULTICAST_IP_ADDR_4                           <= reg_ipv4_multicast_ip_addr_4_int(27 downto 0);
  MULTICAST_IP_ADDR_4_ENABLE                    <= reg_ipv4_multicast_ip_addr_4_int(28);
  ARP_TIMEOUT_MS                                <= reg_arp_configuration_int(11 downto 0);
  ARP_TRYINGS                                   <= reg_arp_configuration_int(15 downto 12);
  ARP_GRATUITOUS_REQ                            <= reg_arp_configuration_int(16);
  ARP_RX_TARGET_IP_FILTER                       <= reg_arp_configuration_int(18 downto 17);
  ARP_RX_TEST_LOCAL_IP_CONFLICT                 <= reg_arp_configuration_int(19);
  ARP_TABLE_CLEAR                               <= reg_arp_configuration_int(20);
  CONFIG_DONE                                   <= reg_config_done_int(0);
  IRQ_INIT_DONE_ENABLE                          <= reg_interrupt_enable_int(0);
  IRQ_ARP_TABLE_CLEAR_DONE_ENABLE               <= reg_interrupt_enable_int(1);
  IRQ_ARP_IP_CONFLICT_ENABLE                    <= reg_interrupt_enable_int(2);
  IRQ_ARP_MAC_CONFLICT_ENABLE                   <= reg_interrupt_enable_int(3);
  IRQ_ARP_ERROR_ENABLE                          <= reg_interrupt_enable_int(4);
  IRQ_ARP_RX_FIFO_OVERFLOW_ENABLE               <= reg_interrupt_enable_int(5);
  IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_ENABLE       <= reg_interrupt_enable_int(6);
  IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_ENABLE        <= reg_interrupt_enable_int(7);
  IRQ_IPV4_RX_FRAG_OFFSET_ERROR_ENABLE          <= reg_interrupt_enable_int(8);
  ARP_SW_REQ_DEST_IP_ADDR_OUT                   <= reg_arp_sw_req_int(31 downto 0);
  IRQ_INIT_DONE_CLEAR_OUT                       <= reg_interrupt_clear_int(0);
  IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_OUT            <= reg_interrupt_clear_int(1);
  IRQ_ARP_IP_CONFLICT_CLEAR_OUT                 <= reg_interrupt_clear_int(2);
  IRQ_ARP_MAC_CONFLICT_CLEAR_OUT                <= reg_interrupt_clear_int(3);
  IRQ_ARP_ERROR_CLEAR_OUT                       <= reg_interrupt_clear_int(4);
  IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_OUT            <= reg_interrupt_clear_int(5);
  IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_OUT    <= reg_interrupt_clear_int(6);
  IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_OUT     <= reg_interrupt_clear_int(7);
  IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_OUT       <= reg_interrupt_clear_int(8);
  IRQ_INIT_DONE_SET_OUT                         <= reg_interrupt_set_int(0);
  IRQ_ARP_TABLE_CLEAR_DONE_SET_OUT              <= reg_interrupt_set_int(1);
  IRQ_ARP_IP_CONFLICT_SET_OUT                   <= reg_interrupt_set_int(2);
  IRQ_ARP_MAC_CONFLICT_SET_OUT                  <= reg_interrupt_set_int(3);
  IRQ_ARP_ERROR_SET_OUT                         <= reg_interrupt_set_int(4);
  IRQ_ARP_RX_FIFO_OVERFLOW_SET_OUT              <= reg_interrupt_set_int(5);
  IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_OUT      <= reg_interrupt_set_int(6);
  IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_OUT       <= reg_interrupt_set_int(7);
  IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_OUT         <= reg_interrupt_set_int(8);



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

        REG_MONITORING_CRC_FILTER_READ                        <= '0';
        REG_MONITORING_MAC_FILTER_READ                        <= '0';
        REG_MONITORING_EXT_DROP_READ                          <= '0';
        REG_MONITORING_RAW_DROP_READ                          <= '0';
        REG_MONITORING_UDP_DROP_READ                          <= '0';


      else
        -- Default
        bad_rd_addr <= '0';
        rd_data     <= (others => '0');

        REG_MONITORING_CRC_FILTER_READ                <= '0';
        REG_MONITORING_MAC_FILTER_READ                <= '0';
        REG_MONITORING_EXT_DROP_READ                  <= '0';
        REG_MONITORING_RAW_DROP_READ                  <= '0';
        REG_MONITORING_UDP_DROP_READ                  <= '0';


        if (rd_req = '1') then
          -- Decode register address to read
          case rd_addr is

            when C_MAIN_REG_VERSION => 
              rd_data(7 downto 0)                           <= VERSION;
              rd_data(15 downto 8)                          <= REVISION;
              rd_data(31 downto 16)                         <= DEBUG;
            when C_MAIN_REG_INTERRUPT_STATUS => 
              rd_data(0)                                    <= IRQ_INIT_DONE_STATUS;
              rd_data(1)                                    <= IRQ_ARP_TABLE_CLEAR_DONE_STATUS;
              rd_data(2)                                    <= IRQ_ARP_IP_CONFLICT_STATUS;
              rd_data(3)                                    <= IRQ_ARP_MAC_CONFLICT_STATUS;
              rd_data(4)                                    <= IRQ_ARP_ERROR_STATUS;
              rd_data(5)                                    <= IRQ_ARP_RX_FIFO_OVERFLOW_STATUS;
              rd_data(6)                                    <= IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_STATUS;
              rd_data(7)                                    <= IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_STATUS;
              rd_data(8)                                    <= IRQ_IPV4_RX_FRAG_OFFSET_ERROR_STATUS;
            when C_MAIN_REG_LOCAL_MAC_ADDR_LSB => 
              rd_data(31 downto 0)                          <= reg_local_mac_addr_lsb_int(31 downto 0);
            when C_MAIN_REG_LOCAL_MAC_ADDR_MSB => 
              rd_data(15 downto 0)                          <= reg_local_mac_addr_msb_int(15 downto 0);
            when C_MAIN_REG_LOCAL_IP_ADDR => 
              rd_data(31 downto 0)                          <= reg_local_ip_addr_int(31 downto 0);
            when C_MAIN_REG_RAW_DEST_MAC_ADDR_LSB => 
              rd_data(31 downto 0)                          <= reg_raw_dest_mac_addr_lsb_int(31 downto 0);
            when C_MAIN_REG_RAW_DEST_MAC_ADDR_MSB => 
              rd_data(15 downto 0)                          <= reg_raw_dest_mac_addr_msb_int(15 downto 0);
            when C_MAIN_REG_IPV4_TIME_TO_LEAVE => 
              rd_data(7 downto 0)                           <= reg_ipv4_time_to_leave_int(7 downto 0);
            when C_MAIN_REG_FILTERING_CONTROL => 
              rd_data(0)                                    <= reg_filtering_control_int(0);
              rd_data(1)                                    <= reg_filtering_control_int(1);
              rd_data(2)                                    <= reg_filtering_control_int(2);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_1 => 
              rd_data(27 downto 0)                          <= reg_ipv4_multicast_ip_addr_1_int(27 downto 0);
              rd_data(28)                                   <= reg_ipv4_multicast_ip_addr_1_int(28);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_2 => 
              rd_data(27 downto 0)                          <= reg_ipv4_multicast_ip_addr_2_int(27 downto 0);
              rd_data(28)                                   <= reg_ipv4_multicast_ip_addr_2_int(28);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_3 => 
              rd_data(27 downto 0)                          <= reg_ipv4_multicast_ip_addr_3_int(27 downto 0);
              rd_data(28)                                   <= reg_ipv4_multicast_ip_addr_3_int(28);
            when C_MAIN_REG_IPV4_MULTICAST_IP_ADDR_4 => 
              rd_data(27 downto 0)                          <= reg_ipv4_multicast_ip_addr_4_int(27 downto 0);
              rd_data(28)                                   <= reg_ipv4_multicast_ip_addr_4_int(28);
            when C_MAIN_REG_ARP_CONFIGURATION => 
              rd_data(11 downto 0)                          <= reg_arp_configuration_int(11 downto 0);
              rd_data(15 downto 12)                         <= reg_arp_configuration_int(15 downto 12);
              rd_data(16)                                   <= reg_arp_configuration_int(16);
              rd_data(18 downto 17)                         <= reg_arp_configuration_int(18 downto 17);
              rd_data(19)                                   <= reg_arp_configuration_int(19);
              rd_data(20)                                   <= reg_arp_configuration_int(20);
            when C_MAIN_REG_CONFIG_DONE => 
              rd_data(0)                                    <= reg_config_done_int(0);
            when C_MAIN_REG_INTERRUPT_ENABLE => 
              rd_data(0)                                    <= reg_interrupt_enable_int(0);
              rd_data(1)                                    <= reg_interrupt_enable_int(1);
              rd_data(2)                                    <= reg_interrupt_enable_int(2);
              rd_data(3)                                    <= reg_interrupt_enable_int(3);
              rd_data(4)                                    <= reg_interrupt_enable_int(4);
              rd_data(5)                                    <= reg_interrupt_enable_int(5);
              rd_data(6)                                    <= reg_interrupt_enable_int(6);
              rd_data(7)                                    <= reg_interrupt_enable_int(7);
              rd_data(8)                                    <= reg_interrupt_enable_int(8);
            when C_MAIN_REG_ARP_SW_REQ => 
              rd_data(31 downto 0)                          <= ARP_SW_REQ_DEST_IP_ADDR_IN;
            when C_MAIN_REG_INTERRUPT_CLEAR => 
              rd_data(0)                                    <= IRQ_INIT_DONE_CLEAR_IN;
              rd_data(1)                                    <= IRQ_ARP_TABLE_CLEAR_DONE_CLEAR_IN;
              rd_data(2)                                    <= IRQ_ARP_IP_CONFLICT_CLEAR_IN;
              rd_data(3)                                    <= IRQ_ARP_MAC_CONFLICT_CLEAR_IN;
              rd_data(4)                                    <= IRQ_ARP_ERROR_CLEAR_IN;
              rd_data(5)                                    <= IRQ_ARP_RX_FIFO_OVERFLOW_CLEAR_IN;
              rd_data(6)                                    <= IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_CLEAR_IN;
              rd_data(7)                                    <= IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_CLEAR_IN;
              rd_data(8)                                    <= IRQ_IPV4_RX_FRAG_OFFSET_ERROR_CLEAR_IN;
            when C_MAIN_REG_INTERRUPT_SET => 
              rd_data(0)                                    <= IRQ_INIT_DONE_SET_IN;
              rd_data(1)                                    <= IRQ_ARP_TABLE_CLEAR_DONE_SET_IN;
              rd_data(2)                                    <= IRQ_ARP_IP_CONFLICT_SET_IN;
              rd_data(3)                                    <= IRQ_ARP_MAC_CONFLICT_SET_IN;
              rd_data(4)                                    <= IRQ_ARP_ERROR_SET_IN;
              rd_data(5)                                    <= IRQ_ARP_RX_FIFO_OVERFLOW_SET_IN;
              rd_data(6)                                    <= IRQ_ROUTER_DATA_RX_FIFO_OVERFLOW_SET_IN;
              rd_data(7)                                    <= IRQ_ROUTER_CRC_RX_FIFO_OVERFLOW_SET_IN;
              rd_data(8)                                    <= IRQ_IPV4_RX_FRAG_OFFSET_ERROR_SET_IN;
            when C_MAIN_REG_MONITORING_CRC_FILTER => 
              rd_data(31 downto 0)                          <= CRC_FILTER_COUNTER;
              REG_MONITORING_CRC_FILTER_READ                <= '1';
            when C_MAIN_REG_MONITORING_MAC_FILTER => 
              rd_data(31 downto 0)                          <= MAC_FILTER_COUNTER;
              REG_MONITORING_MAC_FILTER_READ                <= '1';
            when C_MAIN_REG_MONITORING_EXT_DROP => 
              rd_data(31 downto 0)                          <= EXT_DROP_COUNTER;
              REG_MONITORING_EXT_DROP_READ                  <= '1';
            when C_MAIN_REG_MONITORING_RAW_DROP => 
              rd_data(31 downto 0)                          <= RAW_DROP_COUNTER;
              REG_MONITORING_RAW_DROP_READ                  <= '1';
            when C_MAIN_REG_MONITORING_UDP_DROP => 
              rd_data(31 downto 0)                          <= UDP_DROP_COUNTER;
              REG_MONITORING_UDP_DROP_READ                  <= '1';

            when others =>
              bad_rd_addr <= '1';

          end case;

        end if;
      end if;
    end if;
  end process P_REG_READ;


end rtl;
