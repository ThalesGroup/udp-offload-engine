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
-- This design was created in collaboration for an academic project at Polytech Nantes by
--**************************************************************
-- Student        : B.LO, lo.babacar@outlook.com
--**************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
----------------------------------
-- DHCP MODULE Rx
----------------------------------
--
-- This module is used to receive DHCP Header and payload
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_dhcp_module_rx is
  generic(
    G_ACTIVE_RST          : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST           : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH         : positive  := 32     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                   : in  std_logic;
    RST                   : in  std_logic;
    INIT_DONE             : in  std_logic;

    DHCP_XID              : in  std_logic_vector(31 downto 0);
    DHCP_STATE            : in  t_dhcp_state;
    DHCP_NETWORK_CONFIG   : out t_dhcp_network_config;           -- DHCP parameters extracted from options in the received DHCP frame(assigned IP, Subnetmask, Router and Server IP)
    DHCP_OFFER_SEL        : out std_logic;
    DHCP_ACK              : out std_logic;
    DHCP_NACK             : out std_logic;
    DHCP_RX_ERROR         : out std_logic;
    
    -- From UDP Transport Layer
    S_TDATA               : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID              : in  std_logic;
    S_TLAST               : in  std_logic;
    S_TKEEP               : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TUSER               : in  std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    S_TREADY              : out std_logic

  );
end uoe_dhcp_module_rx;

architecture rtl of uoe_dhcp_module_rx is

----------------------------
  -- Constants declaration
  ----------------------------

  constant C_TKEEP_WIDTH             : positive := ((G_TDATA_WIDTH + 7) / 8);  
  constant C_HEADER_WORDS            : integer := integer(floor(real(C_DHCP_HEADER_SIZE) / real(C_TKEEP_WIDTH))); 
  constant C_HEADER_REMAINDER        : integer := C_DHCP_HEADER_SIZE mod C_TKEEP_WIDTH;

  constant C_DHCP_MSG_HEADER         : std_logic_vector(31 downto 0) := x"02010600"; -- first field on dhcp protocol (op /BOOTREPLY(02); htype /MAC(01); hlen /6 bytes for the MAC addr; hops /00)
  constant C_DHCP_PAD_TAG            : std_logic_vector( 7 downto 0) := x"00";       -- Option Tag of DHCP PAD
  constant C_DHCP_MSG_TYPE_TAG       : std_logic_vector( 7 downto 0) := x"35";       -- Option Tag of DHCP message type 
  constant C_DHCP_OFFER_TYPE         : std_logic_vector( 7 downto 0) := x"02";       -- OFFER message type
  constant C_DHCP_ACK_TYPE           : std_logic_vector( 7 downto 0) := x"05";       -- ACK  message type 
  constant C_DHCP_NACK_TYPE          : std_logic_vector( 7 downto 0) := x"06";       -- NACK  message type
  constant C_DHCP_SERVER_IP_TAG      : std_logic_vector( 7 downto 0) := x"36";       -- Option Tag of SERVER IP address
  constant C_DHCP_SUBNET_MASK_TAG    : std_logic_vector( 7 downto 0) := x"01";       -- Option Tag of subnetmask  
  constant C_DHCP_ROUTER_TAG         : std_logic_vector( 7 downto 0) := x"03";       -- Option Tag of router
  constant C_DHCP_LEASE_TIME_TAG     : std_logic_vector( 7 downto 0) := x"33";       -- Option Tag of lease time
  constant C_DHCP_END_TAG            : std_logic_vector( 7 downto 0) := x"FF";       -- Option Tag for DHCP END message 

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  type t_rx_state is (IDLE, DHCP_RX_HEADER, SKIP, DHCP_RX_OPTIONS);
  type t_option_state is (TAG, LENGTH, VALUE);

  -- record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(79 downto 0);
    tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);  
    tvalid : std_logic;
  end record t_forward_data;

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  -- constant for record initialization
  constant C_FORWARD_DATA_INIT : t_forward_data := (
    tdata                    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast                    => '0',                      -- could be anything because the tvalid signal is 0
    tuser                    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tkeep                    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid                   => '0'                       -- data are not valid at initialization
  );  

  constant C_DHCP_CONFIG_INIT : t_dhcp_network_config := (
    OFFER_IP                 => (others => '0'),
    SUBNET_MASK              => (others => '0'),
    SERVER_IP                => (others => '1'),
    ROUTER_IP                => (others => '0')
  );
  ----------------------------
  -- Signals declaration
  ----------------------------

  -- axis bus at intermediate layer
  signal mid                 : t_forward_data;
  signal mid_tready          : std_logic;

  signal cnt                 : integer range 0 to C_HEADER_WORDS + 1;  
  signal cnt_options         : integer range 0 to C_HEADER_WORDS + 1;

  signal network_config      : t_dhcp_network_config;         -- DHCP parameters extracted from options in the received DHCP frame
  signal rx_state            : t_rx_state;                    -- the dhcp rx state 
  signal frame_size          : std_logic_vector(15 downto 0); -- size of the incoming frame
  signal dhcp_giaddr         : std_logic_vector(31 downto 0); -- Relay agent IP address, used in booting via a relay agent.
  signal dhcp_yiaddr         : std_logic_vector(31 downto 0); -- (client) IP address offered by the server extracted during DHCP_RX_HEADER
  signal dhcp_siaddr         : std_logic_vector(31 downto 0); -- server identifier estracted from option
  signal dhcp_router         : std_logic_vector(31 downto 0); -- router IP address estracted from option if there is one
  signal dhcp_subnetmask     : std_logic_vector(31 downto 0); -- subnetmask extracted from option if there is one
  signal dhcp_lease_time     : std_logic_vector(31 downto 0); -- lease time extracted from option
  signal dhcp_offer_selected : std_logic;                     -- signal for accepted offer
  signal dhcp_n_acknowledge  : std_logic;                     -- flag for nack message                
  signal dhcp_acknowledge    : std_logic;                     -- flag for ack message (configuration is successfull)
  signal dhcp_type_msg       : std_logic_vector( 7 downto 0); -- signal for the type of dhcp message
  signal in_progress         : std_logic;                     -- control signal for receiveing frame
  signal dhcp_skip_mode      : std_logic;                     -- flag to indicate that the dhcp receiver is in skip mode(whether the message is not for DHCP or there is an error in the incoming frame)
begin

  -----------------------------------------------------
  --
  --   BACKWARD Register
  --
  -----------------------------------------------------
  inst_axis_register_backward : axis_register
    generic map(
      G_ACTIVE_RST          => G_ACTIVE_RST,
      G_ASYNC_RST           => G_ASYNC_RST,
      G_TDATA_WIDTH         => G_TDATA_WIDTH,
      G_TUSER_WIDTH         => S_TUSER'length,
      G_REG_FORWARD         => false,
      G_REG_BACKWARD        => true,
      G_FULL_BANDWIDTH      => true
    )
    port map(
      CLK                   => CLK,
      RST                   => RST,
      S_TDATA               => S_TDATA,
      S_TVALID              => S_TVALID,
      S_TLAST               => S_TLAST,
      S_TKEEP               => S_TKEEP,
      S_TUSER               => S_TUSER,
      S_TREADY              => S_TREADY,
      M_TDATA               => mid.tdata,
      M_TVALID              => mid.tvalid,
      M_TLAST               => mid.tlast,
      M_TKEEP               => mid.tkeep,
      M_TUSER               => mid.tuser,
      M_TREADY              => mid_tready
    ); 

  -----------------------------------------------------
  --
  --   FORWARD
  --
  -----------------------------------------------------

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready                <= '1' when (((DHCP_STATE = OFFER) or  (DHCP_STATE = ACK)) and (in_progress = '0')) else '0';
 
  DHCP_NETWORK_CONFIG       <= network_config;
  DHCP_OFFER_SEL            <= dhcp_offer_selected;
  DHCP_ACK                  <= dhcp_acknowledge;
  DHCP_NACK                 <= dhcp_n_acknowledge;  
  DHCP_RX_ERROR             <= dhcp_skip_mode;
  -------------------------------------------------
  -- Register the different signals on the forward path and handle the header deletion
  P_FORWARD_REG : process(CLK, RST)
    variable dhcp_server_v  : std_logic_vector(31 downto 0);
    variable lengt_v        : integer;
    variable option_state   : t_option_state;
    variable type_message   : std_logic_vector(2 downto 0);  
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      cnt                   <= 0;
      cnt_options           <= 0; 
      rx_state              <= DHCP_RX_HEADER;      
      network_config        <= C_DHCP_CONFIG_INIT;
      frame_size            <= (others => '0');
      dhcp_type_msg         <= (others => '0');
      dhcp_router           <= (others => '0');
      dhcp_yiaddr           <= (others => '0');
      dhcp_siaddr           <= (others => '0');
      dhcp_giaddr           <= (others => '0');
      dhcp_lease_time       <= (others => '0');
      dhcp_subnetmask       <= (others => '0'); 
             
      dhcp_offer_selected   <= '0';
      dhcp_n_acknowledge    <= '0';
      dhcp_acknowledge      <= '0';
      in_progress           <= '0';
      dhcp_skip_mode        <= '0';
      lengt_v               :=  0;
      option_state          := TAG;
      type_message          := (others => '0');
      dhcp_server_v         := (others => '0');
      
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        cnt                 <= 0;
        cnt_options         <= 0;
        rx_state            <= DHCP_RX_HEADER;
        network_config      <= C_DHCP_CONFIG_INIT;
        frame_size          <= (others => '0');
        dhcp_type_msg       <= (others => '0');
        dhcp_router         <= (others => '0');
        dhcp_giaddr         <= (others => '0');
        dhcp_yiaddr         <= (others => '0');
        dhcp_siaddr         <= (others => '0');
        dhcp_lease_time     <= (others => '0');
        dhcp_subnetmask     <= (others => '0');
          
        dhcp_offer_selected <= '0';
        dhcp_n_acknowledge  <= '0';
        dhcp_acknowledge    <= '0';
        in_progress         <= '0';
        dhcp_skip_mode      <= '0';
        lengt_v             :=  0;
        option_state        := TAG;
        type_message        := (others => '0');
        dhcp_server_v       := (others => '0');
        
      else

        if cnt = 0 then 
          in_progress         <= '0'; 
        end if;  
        -- storing the configuration parameters 
        if dhcp_offer_selected = '1' then 
          --network_config.SERVER_IP <= dhcp_siaddr;

        elsif dhcp_acknowledge = '1' then
          network_config.ROUTER_IP   <= dhcp_router;
          network_config.SUBNET_MASK <= dhcp_subnetmask;
          --network_config.LEASE_TIME  <= dhcp_lease_time; not used
        end if;
        
        if mid_tready = '1' then

          if mid.tvalid = '1' then
            
            --check wether the frame is for the DHCP client
            if ((S_TUSER(79 downto 64) /= C_DHCP_PORT_CLIENT) or (S_TUSER(63 downto 48) /= C_DHCP_PORT_SERVER)) then
              rx_state            <= SKIP;
              dhcp_skip_mode      <= '1';
            end if;
            frame_size <= S_TUSER(47 downto 32);  -- the incoming frame size

            -- reset counter when tlast
            if (mid.tlast = '1') then
              cnt <= 0;
            elsif cnt < (C_HEADER_WORDS) then
              cnt <= cnt + 1;
            end if;

            case rx_state is
              
              when DHCP_RX_HEADER =>
                dhcp_offer_selected <= '0'; 
                dhcp_acknowledge <= '0';
                dhcp_n_acknowledge <= '0'; 
                if (cnt = C_HEADER_WORDS - 1) then
                  rx_state   <= DHCP_RX_OPTIONS;  
                  
                end if;
                
                -- Search field in flow
                for i in 0 to C_TKEEP_WIDTH - 1 loop
                  -- Little Endian
                  case (cnt * C_TKEEP_WIDTH) + i is
                    -- Big Endian
                    --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH-1) - i)) is

                    when 0 =>  --check op ;
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_DHCP_MSG_HEADER(31 downto 24) then --check if op is a BOOTREPLY
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;                  
                    when 1 =>  --check htype;  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_DHCP_MSG_HEADER(23 downto 16) then -- check if htype is MAC
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;  
                    when 2 =>  --check hlen;  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_DHCP_MSG_HEADER(15 downto  8) then -- check if hardware length addr is 6 bytes
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if; 

                      --3 not tested; it's the hops always equal to zero 
                    when 4 =>  --check xid;  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= DHCP_XID(31 downto 24) then -- xid from previous DISCOVER 
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if; 
                    when 5 =>  --check xid;  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= DHCP_XID(23 downto 16) then -- xid from previous DISCOVER
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 6 =>  --check xid;  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= DHCP_XID(15 downto  8) then -- xid from previous DISCOVER
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 7 =>    
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= DHCP_XID( 7 downto  0) then -- xid from previous DISCOVER
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if; 
                    --8, 9, 10, 11, 12,13,14,15  flags secs and ciaddr are not needed to be extracted
                    
                    --extract offered_yiaddr;
                    when 16 => dhcp_yiaddr(31 downto 24) <= mid.tdata((8 * i) + 7 downto 8 * i);                 
                    when 17 => dhcp_yiaddr(23 downto 16) <= mid.tdata((8 * i) + 7 downto 8 * i);                
                    when 18 => dhcp_yiaddr(15 downto  8) <= mid.tdata((8 * i) + 7 downto 8 * i);                         
                    when 19 => dhcp_yiaddr( 7 downto  0) <= mid.tdata((8 * i) + 7 downto 8 * i);   
                      
                    --20,21,22,23 server Id can be extracted from option 
                    --extract giaddr;
                    when 24 => dhcp_giaddr(31 downto 24) <= mid.tdata((8 * i) + 7 downto 8 * i);   
                    when 25 => dhcp_giaddr(23 downto 16) <= mid.tdata((8 * i) + 7 downto 8 * i);    
                    when 26 => dhcp_giaddr(15 downto  8) <= mid.tdata((8 * i) + 7 downto 8 * i);   
                    when 27 => dhcp_giaddr( 7 downto  0) <= mid.tdata((8 * i) + 7 downto 8 * i);   
                       
                    --check client Mac addr 
                    when 28 =>  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(47 downto 40) then
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 29 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(39 downto 32) then 
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 30 =>  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(31 downto 24) then
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 31 =>  
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(23 downto 16) then
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 32 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(15 downto 8) then
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 33 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_CHADDR(7 downto 0) then 
                        rx_state <= SKIP;
                      end if;
                    --check magic cookie
                    when 236 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_MAGIC_COOKIE(31 downto 24) then 
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 237 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_MAGIC_COOKIE(23 downto 16) then
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 238 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_MAGIC_COOKIE(15 downto 8) then 
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when 239 =>   
                      if mid.tdata((8 * i) + 7 downto 8 * i) /= C_MAGIC_COOKIE(7 downto 0) then 
                        rx_state            <= SKIP;
                        dhcp_skip_mode      <= '1';
                      end if;
                    when others =>
                  end case;
                end loop;
              
              when DHCP_RX_OPTIONS =>  
                
                -- Analyse des options DHCP
                for i in 0 to C_TKEEP_WIDTH - 1 loop
                  case (cnt_options * C_TKEEP_WIDTH) + i is
                    when others =>
                      
                      if (option_state = TAG) then 
                        case (mid.tdata((8 * i) + 7 downto 8 * i)) is 
                          when  C_DHCP_PAD_TAG         => type_message := "000"; -- 0  : pad do nothing keep type_message @ "000"
                          when  C_DHCP_END_TAG         => type_message := "001"; -- 1  : end do nothing keep type_message @ "000"                        
                          when  C_DHCP_MSG_TYPE_TAG    => type_message := "010"; -- 2  : dhcp message type option   
                          when  C_DHCP_SUBNET_MASK_TAG => type_message := "011"; -- 3  : netmask option                       
                          when  C_DHCP_LEASE_TIME_TAG  => type_message := "100"; -- 4  : lease time option                           
                          when  C_DHCP_SERVER_IP_TAG   => type_message := "101"; -- 5  : server_ip option
                          when  C_DHCP_ROUTER_TAG      => type_message := "110"; -- 6  : router_ip optiobn
                          --Add here any others options you want to treat                            
                          when others                  => type_message := "111"; -- 7  : default value for other option
                        end case;
                      
                      elsif (option_state = LENGTH) then
                          lengt_v := to_integer(unsigned(mid.tdata((8 * i) + 7 downto 8 * i))); --extraction of message length in option 
                        
                       --extract value in the options
                      elsif(option_state = VALUE) then 
                        if lengt_v > 4 then
                          -- do nothing for now
                        else
                          if (type_message = "010") then -- extraction of dhcp_message_type(OFFER, ACK, NACK)
                            dhcp_type_msg  <= mid.tdata((8 * i) + 7 downto 8 * i);

                          elsif (type_message = "011") then --extraction of netmask 
                            dhcp_subnetmask((8 * lengt_v - 1)  downto 8 * lengt_v -8)  <= mid.tdata((8 * i) + 7 downto 8 * i);
                       
                          elsif (type_message = "100") then --extraction of lease time 
                            dhcp_lease_time((8 * lengt_v - 1)  downto 8 * lengt_v -8)  <= mid.tdata((8 * i) + 7 downto 8 * i);                        
                          
                          elsif (type_message = "101") then --extraction of server_ip
                            --dhcp_siaddr((8 * lengt_v - 1)  downto 8 * lengt_v -8)      <= mid.tdata((8 * i) + 7 downto 8 * i);
                            dhcp_server_v((8 * lengt_v - 1)  downto 8 * lengt_v -8)    := mid.tdata((8 * i) + 7 downto 8 * i);
                       
                          elsif(type_message = "110") then -- extraction of router_ip
                            dhcp_router((8 * lengt_v - 1)  downto 8 * lengt_v -8)      <= mid.tdata((8 * i) + 7 downto 8 * i);
                          end if;
                        end if;
                      end if;
                      
                      if (option_state = TAG) then
                        
                        if(type_message = "000" or type_message = "001") then
                          type_message    := "000";
                          option_state    := option_state;
                        else
                          option_state    := LENGTH;
                        end if;

                      elsif(option_state = LENGTH) then
                        option_state      := VALUE;

                      elsif(option_state = VALUE) then
                        lengt_v           := lengt_v - 1;
                        
                        if (lengt_v = 0 ) then
                          option_state    := TAG;
                        else 
                          option_state    := option_state;
                        end if;
                      end if;
                  end case;
                end loop;

                -- reset counter when tlast and transistion to DHCP_RX_HEADER
                if (mid.tlast = '1') then
                  in_progress         <= '1';
                  
                  case dhcp_type_msg is 
                   
                    when C_DHCP_OFFER_TYPE =>  --OFFER message
                      if DHCP_STATE = OFFER then
                        dhcp_offer_selected    <= '1';
                        -- also set the options we need to include in the request
                        network_config.OFFER_IP  <= dhcp_yiaddr;
                        network_config.SERVER_IP <= dhcp_server_v; 
                        dhcp_siaddr              <= dhcp_server_v;
                      end if;
                    when C_DHCP_ACK_TYPE =>  -- ACK message
                      if DHCP_STATE = ACK then
                        if network_config.OFFER_IP = dhcp_yiaddr then
                      -- we have an acknowledge from the server
                          dhcp_acknowledge     <= '1';
                        end if;
                      end if;
                      
                    when C_DHCP_NACK_TYPE => -- NACK message
                      dhcp_n_acknowledge    <= '1';
                      network_config        <= C_DHCP_CONFIG_INIT;
                    when others =>
                  end case;
                  
                  rx_state <= DHCP_RX_HEADER;
                  cnt_options <= 0;                 
                else
                  cnt_options <= cnt_options + 1;
                end if;                              
              when SKIP => --the receiveing frames are not destinated to the DHCP or there is an error with incoming frame
                if (mid.tlast = '1') then
                  dhcp_skip_mode      <= '0';
                  rx_state <= DHCP_RX_HEADER;
                end if;
             
              when others =>
            end case;
          else
          end if;
        end if;
      end if;
    end if;
  end process P_FORWARD_REG;
end rtl;
