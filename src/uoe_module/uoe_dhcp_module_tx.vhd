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
-- Student        : BLO, lo.babacar@outlook.com
--**************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
----------------------------------
-- DHCP MODULE TX
----------------------------------
--
-- This module is used to insert DHCP Header and payload
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_dhcp_module_tx is
  generic(
    G_ACTIVE_RST         : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST          : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH        : positive  := 32     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK                  : in  std_logic;
    RST                  : in  std_logic;
    INIT_DONE            : in  std_logic;
    
    DHCP_SEND_DISCOVER   : in  std_logic;
    DHCP_SEND_REQUEST    : in  std_logic;
    DHCP_STATE           : in  t_dhcp_state;
    DHCP_NETWORK_CONFIG  : in  t_dhcp_network_config;
    DHCP_XID             : in  std_logic_vector(31 downto 0);
    --difference from the first increment
    DHCP_USE_IP          : in  std_logic;
    DHCP_USER_IP_ADDR    : in  std_logic_vector(31 downto 0);
    DHCP_USER_MAC_ADDR   : in  std_logic_vector(47 downto 0);
    DHCP_MESSAGE_SENT    : out std_logic;
    
    -- To UDP Transport Layer
    M_TDATA              : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID             : out std_logic;
    M_TLAST              : out std_logic;
    M_TKEEP              : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TUSER              : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
    M_TREADY             : in  std_logic

  );
end uoe_dhcp_module_tx;

architecture rtl of uoe_dhcp_module_tx is

  -------------------------------
  -- Constants declaration
  -------------------------------

  constant C_TKEEP_WIDTH : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_CNT_MAX     : integer := integer(ceil(real(C_DHCP_HEADER_SIZE) / real(C_TKEEP_WIDTH)));
  constant C_CNT_OPT_MAX : integer := integer(ceil(real(24) / real(C_TKEEP_WIDTH)));
  constant C_DHCP_SIZE   : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned((24 + C_DHCP_HEADER_SIZE),16)); --fixed dhcp message size

  constant C_DHCP_LOCAL_REQ_IP       : std_logic_vector(31 downto 0) := x"C0A80A04"; -- Local requested IP addr 192.168.10.4
  constant C_DHCP_MSG_HEADER         : std_logic_vector(31 downto 0) := x"01010600"; -- first field on dhcp protocol (op /bootrequest(01); htype /MAC(01); hlen /6 bytes for the MAC addr; hops /00)
  constant C_DHCP_FLAG               : std_logic_vector(15 downto 0) := x"8000";     -- x"8000" when the DHCP message is broadcasted else x"0000"(see RFC2131 page 11 figure 2)
  
  --DHCP options format (see RFC 1533)
  -- +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  -- |        TAG        |  LEN      |    data       |
  -- +-------------------+-----------+---------------+
  -- |        fix        |  variable |    value      |
  -- +===================+===========+===============+

  constant C_DHCP_PAD_TAG            : std_logic_vector( 7 downto 0) := x"00";       -- Option Tag of DHCP PAD
  constant C_DHCP_MSG_TYPE_TAG       : std_logic_vector( 7 downto 0) := x"35";       -- Option Tag of DHCP message type
  constant C_DHCP_MSG_TYPE_LEN       : std_logic_vector( 7 downto 0) := x"01";       -- Length of DHCP message type (1 byte)  
  constant C_DHCP_DISCOVER_TYPE      : std_logic_vector( 7 downto 0) := x"01";       -- DISCOVER message type
  constant C_DHCP_REQUEST_TYPE       : std_logic_vector( 7 downto 0) := x"03";       -- REQUEST  message type 
  constant C_DHCP_REQUESTED_IP_TAG   : std_logic_vector( 7 downto 0) := x"32";       -- Option Tag of requested IP address
  constant C_DHCP_REQUESTED_IP_LEN   : std_logic_vector( 7 downto 0) := x"04";       -- Length of requested IP (4 bytes)   
  constant C_DHCP_SERVER_IP_TAG      : std_logic_vector( 7 downto 0) := x"36";       -- Option Tag of SERVER IP address
  constant C_DHCP_SERVER_IP_LEN      : std_logic_vector( 7 downto 0) := x"04";       -- Length of SERVER IP (4 bytes) 
  constant C_DHCP_REQ_PARAM_LIST_TAG : std_logic_vector( 7 downto 0) := x"37";       -- Option Tag of requested parameters list
  constant C_DHCP_REQ_PARAM_LIST_LEN : std_logic_vector( 7 downto 0) := x"02";       -- Length of requested parameters list
  constant C_DHCP_SUBNET_MASK_TAG    : std_logic_vector( 7 downto 0) := x"01";       -- Option Tag of subnetmask  
  constant C_DHCP_ROUTER_TAG         : std_logic_vector( 7 downto 0) := x"03";       -- Option Tag of router tag
  constant C_DHCP_END_TAG            : std_logic_vector( 7 downto 0) := x"FF";       -- Option Tag for DHCP END message

  -------------------------------
  -- Functions declaration
  -------------------------------
  function get_alignment return integer is
    variable align : integer range 0 to C_TKEEP_WIDTH - 1;
  begin
    align := 0;
    if (C_DHCP_HEADER_SIZE mod C_TKEEP_WIDTH) /= 0 then
      align := (C_TKEEP_WIDTH - (C_DHCP_HEADER_SIZE mod C_TKEEP_WIDTH));
    end if;
    return align;
  end function get_alignment;

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

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
    tdata  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast  => '0',                      -- could be anything because the tvalid signal is 0
    tuser  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  constant C_ALIGN : integer := get_alignment;

  ----------------------------
  -- Signals declaration
  ----------------------------

  -- internal signal to launch a dhcp message building
  signal mid_valid     : std_logic;
  -- internal signal to save the type of message to send 
  signal dhcp_msg_type : std_logic_vector(7 downto 0);

  -- axis bus at output
  signal m_int         : t_forward_data;
  signal m_int_tready  : std_logic;
  signal cnt           : integer range 0 to C_CNT_MAX;
  signal cnt_option    : integer range 0 to C_CNT_MAX;

begin

  -- combinational

  mid_valid <= '1' when ((DHCP_STATE = DISCOVER) or  (DHCP_STATE = REQUEST)) else '0';
  
  -------------------------------------------------
  -- Register the different signals on the forward path and handle the header deletion
  P_FORWARD_REG : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      m_int                <= C_FORWARD_DATA_INIT;
      dhcp_msg_type        <= (others => '0');
      cnt                  <= 0;
      cnt_option           <= 0;
      DHCP_MESSAGE_SENT    <='0';
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        m_int              <= C_FORWARD_DATA_INIT;
        dhcp_msg_type      <= (others => '0');
        cnt                <= 0;
        cnt_option         <= 0;
        DHCP_MESSAGE_SENT  <='0';

      else
        
        if (m_int_tready = '1') or (m_int.tvalid /= '1') then
          -- Clear TVALID
          m_int.tvalid <= '0';

          if (INIT_DONE = '1') and (mid_valid = '1') then
            -- Valid output
            m_int.tvalid <= '1';  
            m_int.tlast  <= '0';
            DHCP_MESSAGE_SENT <= '0';

            if (DHCP_STATE = DISCOVER and DHCP_SEND_DISCOVER = '1') then
              dhcp_msg_type      <= C_DHCP_DISCOVER_TYPE;
            elsif (DHCP_STATE = REQUEST and DHCP_SEND_REQUEST = '1') then 
              dhcp_msg_type      <= C_DHCP_REQUEST_TYPE;
            else 
              dhcp_msg_type      <= C_DHCP_DISCOVER_TYPE;
            end if;

            -- Header
            if cnt /= C_CNT_MAX then
              cnt <= cnt + 1;

              -- TDATA and TKEEP
              for i in 0 to C_TKEEP_WIDTH - 1 loop
                -- Little Endian
                case ((cnt * C_TKEEP_WIDTH) + i) is
                  -- Big Endian
                  --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                  when C_ALIGN +   0 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_HEADER(31 downto 24); -- op /bootrequest
                  when C_ALIGN +   1 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_HEADER(23 downto 16); -- htype MAC 
                  when C_ALIGN +   2 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_HEADER(15 downto  8); -- hlen
                  when C_ALIGN +   3 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_HEADER( 7 downto  0); -- hops

                  --setting xid filed which change only during DISCOVER or request during rebooting
                  when C_ALIGN +   4 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_XID(31 downto 24);      -- XID
                  when C_ALIGN +   5 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_XID(23 downto 16);
                  when C_ALIGN +   6 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_XID(15 downto  8);
                  when C_ALIGN +   7 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_XID( 7 downto  0);
                  
                  ----setting flags filed 
                  when C_ALIGN +  10 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_FLAG(15 downto 8);    --Flag set to broadcast
                  when C_ALIGN +  11 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_FLAG( 7 downto 0);    --see figure 2 of RFC2131 pdf file

                  -- ciaddr, yiaddr, siaddr, giaadr are set to zero for the moment
                  
                  --setting client Mac addr 
                  when C_ALIGN +  28 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR(47 downto 40);      --client hardware addr
                  when C_ALIGN +  29 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR(39 downto 32);
                  when C_ALIGN +  30 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR(31 downto 24);
                  when C_ALIGN +  31 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR(23 downto 16);
                  when C_ALIGN +  32 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR(15 downto  8);
                  when C_ALIGN +  33 => m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_MAC_ADDR( 7 downto  0);

                  --set the magic cookie
                  when C_ALIGN + 236 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_MAGIC_COOKIE(31 downto 24);
                  when C_ALIGN + 237 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_MAGIC_COOKIE(23 downto 16);
                  when C_ALIGN + 238 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_MAGIC_COOKIE(15 downto  8);
                  when C_ALIGN + 239 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_MAGIC_COOKIE( 7 downto  0);

                  when others =>
                    m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                end case;

                -- Little Endian
                if ((cnt * C_TKEEP_WIDTH) + i) >= C_ALIGN then
                  -- Big Endian
                  --if ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) < 14 then
                  m_int.tkeep(i) <= '1';
                else
                  m_int.tkeep(i) <= '0';
                end if;
              end loop;

            -- Payload
            else
             
              if cnt_option /= C_CNT_OPT_MAX then
                cnt_option <= cnt_option + 1;
                
                --DHCP discover or REQUEST message options
                for i in 0 to C_TKEEP_WIDTH - 1 loop
                  -- Little Endian
                  case ((cnt_option * C_TKEEP_WIDTH) + i) is
                    --type of message
                    when C_ALIGN + 0 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_TYPE_TAG; -- tag of the type of DHCP message
                    when C_ALIGN + 1 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_MSG_TYPE_LEN; -- size(byte) of dhcp_msg_type
                    when C_ALIGN + 2 => m_int.tdata((8 * i) + 7 downto 8 * i) <= dhcp_msg_type;       -- ethier a DISCOVER or a REQUEST message 
                      
                    --requested IP (in Discover the user can choose an specific IP address in Request IP address extracted from the previous offer message is used)
                    when C_ALIGN + 4 => 
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQUESTED_IP_TAG;
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQUESTED_IP_TAG;
                      end if;
                    when C_ALIGN + 5 => 
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQUESTED_IP_LEN;
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQUESTED_IP_LEN;
                      end if;

                      
                    when C_ALIGN + 6 => 
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_IP_ADDR(31 downto 24);  
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.OFFER_IP(31 downto 24);
                      end if;
                      
                    when C_ALIGN + 7 =>
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_IP_ADDR(23 downto 16);  
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.OFFER_IP(23 downto 16);
                      end if;
                    when C_ALIGN + 8 => 
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_IP_ADDR(15 downto  8);  
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.OFFER_IP(15 downto 8);
                      end if;
                    when C_ALIGN + 9 => 
                      if (DHCP_SEND_DISCOVER ='1' and DHCP_STATE = DISCOVER) then
                        if DHCP_USE_IP = '1' then
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_USER_IP_ADDR( 7 downto  0);  
                        else
                          m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                        end if;
                      elsif (DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST)then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.OFFER_IP(7 downto 0);
                      end if;
                        
                    --10 and 11 are set to pad value 
                    --server identifier is extracted from the previous offer message    
                    when C_ALIGN + 12 => 
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_SERVER_IP_TAG;  -- tag of server identifier only used in Request; in Discover this filed is "00"
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;
                      
                    when C_ALIGN + 13 => 
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_SERVER_IP_LEN; -- length of server identifier option message
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;                       
                    when C_ALIGN + 14 => 
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.SERVER_IP(31 downto 24);
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;
                    when C_ALIGN + 15 =>
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.SERVER_IP(23 downto 16);
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;
                    when C_ALIGN + 16 =>
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.SERVER_IP(15 downto 8);
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;
                    when C_ALIGN + 17 =>
                      if DHCP_SEND_REQUEST ='1' and DHCP_STATE = REQUEST then
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= DHCP_NETWORK_CONFIG.SERVER_IP(7 downto 0);
                      else
                        m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                      end if;
                    -- 18 is set to pad value 
                    --requested parameter List 
                    when C_ALIGN + 19 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQ_PARAM_LIST_TAG;  -- tag of requested parameters list
                    when C_ALIGN + 20 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_REQ_PARAM_LIST_LEN;  -- length of requested parameters list
                    when C_ALIGN + 21 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_SUBNET_MASK_TAG;     -- Subnetmask
                    when C_ALIGN + 22 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_ROUTER_TAG;          -- Router IP
                    -- user may add here other option in the  request parameter list
                    
                    when C_ALIGN + 23 => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_END_TAG;             -- end option message
                    when others =>
                      m_int.tdata((8 * i) + 7 downto 8 * i) <= C_DHCP_PAD_TAG;
                  end case;
                end loop;               
              end if;

              if cnt_option = C_CNT_OPT_MAX -1 then
                m_int.tlast <= '1';
                DHCP_MESSAGE_SENT <= '1';

              elsif cnt_option = C_CNT_OPT_MAX then
                cnt                <= 0;
                cnt_option         <= 0;
                -- change only valid state to avoid logic toggling (and save power)
                m_int.tvalid       <= '0';
              end if;
            end if;

            -- TUSER
            if (cnt = 0) then
              -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of incoming frame, 31:0 -> Dest IP addr
              m_int.tuser <= C_DHCP_PORT_SERVER & C_DHCP_PORT_CLIENT & C_DHCP_SIZE & DHCP_NETWORK_CONFIG.SERVER_IP;
            --else
            --  m_int.tuser <= (others => '0');
            end if;
            
          end if;
        end if;
      end if;
    end if;
  end process P_FORWARD_REG;


  -- Header size is multiple of C_TKEEP_WIDTH
  GEN_NO_ALIGN : if C_ALIGN = 0 generate

    -- connecting output bus to the records
    M_TDATA      <= m_int.tdata;
    M_TLAST      <= m_int.tlast;
    M_TUSER      <= m_int.tuser;
    M_TKEEP      <= m_int.tkeep;
    M_TVALID     <= m_int.tvalid;
    m_int_tready <= M_TREADY;

  end generate GEN_NO_ALIGN;

  -- Header size isn't multiple of C_TKEEP_WIDTH => need alignment
  GEN_ALIGN : if C_ALIGN /= 0 generate

    -- Realign frame on first bytes of the first transfer
    inst_axis_pkt_align : axis_pkt_align
      generic map(
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_ASYNC_RST   => G_ASYNC_RST,
        G_TDATA_WIDTH => G_TDATA_WIDTH,
        G_TUSER_WIDTH => 80
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => m_int.tdata,
        S_TVALID => m_int.tvalid,
        S_TLAST  => m_int.tlast,
        S_TUSER  => m_int.tuser,
        S_TKEEP  => m_int.tkeep,
        S_TREADY => m_int_tready,
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TUSER  => M_TUSER,
        M_TKEEP  => M_TKEEP,
        M_TREADY => M_TREADY
      );

  end generate GEN_ALIGN;
end rtl;