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
-- Package uoe_module_pkg
----------------------------------
--
-- Declare the common constants of the IP
--
----------------------------------

package uoe_module_pkg is

  -----------------------------------------------------------------------------------------------
  -- VERSION / REVISION / DEBUG -----------------------------------------------------------------
  -----------------------------------------------------------------------------------------------

  -- UOE version
  constant C_VERSION  : std_logic_vector(7 downto 0)  := x"01";
  constant C_REVISION : std_logic_vector(7 downto 0)  := x"00";
  constant C_DEBUG    : std_logic_vector(15 downto 0) := x"0000";

  -----------------------------------------------------------------------------------------------
  -- GLOBAL CONSTANTS ---------------------------------------------------------------------------
  -----------------------------------------------------------------------------------------------

  -- Broadcast Addr.
  constant C_BROADCAST_IP_ADDR  : std_logic_vector(31 downto 0) := x"FF_FF_FF_FF";
  constant C_BROADCAST_MAC_ADDR : std_logic_vector(47 downto 0) := x"FF_FF_FF_FF_FF_FF";
  constant C_ZERO_IP_ADDR       : std_logic_vector(31 downto 0) := x"00_00_00_00";
  constant C_ZERO_MAC_ADDR      : std_logic_vector(47 downto 0) := x"00_00_00_00_00_00";

  -- Multicast Addr
  constant C_MULTICAST_MAC_ADDR_MSB : std_logic_vector(23 downto 0) := x"01_00_5E";

  -- EtherType values
  constant C_ETHERTYPE_ARP     : std_logic_vector(15 downto 0) := x"0806";
  constant C_ETHERTYPE_IPV4    : std_logic_vector(15 downto 0) := x"0800";
  constant C_ETHERTYPE_RAW_MAX : std_logic_vector(15 downto 0) := x"05DC"; -- 1500 : if ethertype below this value -> RAW. Values between 1500 and 1536 are not defined
  constant C_ETHERTYPE_UNKNOWN : std_logic_vector(15 downto 0) := x"FFFF"; -- Unknown Ethertype (> 1500)

  -- IPV4 Protocol values
  constant C_PROTOCOL_UDP     : std_logic_vector(7 downto 0) := x"11";
  constant C_PROTOCOL_TCP     : std_logic_vector(7 downto 0) := x"06";
  constant C_PROTOCOL_ICMPV4  : std_logic_vector(7 downto 0) := x"01";
  constant C_PROTOCOL_IGMP    : std_logic_vector(7 downto 0) := x"02";
  constant C_PROTOCOL_UNKNOWN : std_logic_vector(7 downto 0) := x"FF"; -- For simulation only

  -- TCP/UDP ports values
  constant C_STANDARD_PORT_MAX : std_logic_vector(15 downto 0) := x"03FF"; -- 1023 : ports up to 1023 are assigned by IANA to standard protocols
  constant C_HTTP_PORT         : std_logic_vector(15 downto 0) := x"0050"; -- port 80
  constant C_DHCP_PORT         : std_logic_vector(15 downto 0) := x"0043"; -- port 67
  constant C_DNS_PORT          : std_logic_vector(15 downto 0) := x"0035"; -- port 53
  constant C_NBNS_NS_PORT      : std_logic_vector(15 downto 0) := x"0089"; -- port 137
  constant C_NBNS_DGM_PORT     : std_logic_vector(15 downto 0) := x"008A"; -- port 138
  constant C_NBNS_SSN_PORT     : std_logic_vector(15 downto 0) := x"008B"; -- port 139

  -- Protocol <=> Interconnect ports
  constant C_TDEST_RAW         : std_logic_vector(2 downto 0) := "000";
  constant C_TDEST_ARP         : std_logic_vector(2 downto 0) := "001";
  constant C_TDEST_MAC_SHAPING : std_logic_vector(2 downto 0) := "010";
  constant C_TDEST_EXT         : std_logic_vector(2 downto 0) := "011";
  constant C_TDEST_TRASH       : std_logic_vector(2 downto 0) := "100";

  -- ARP Operation
  constant C_ARP_REQUEST : std_logic := '0';
  constant C_ARP_REPLY   : std_logic := '1';

  constant C_ARP_OPCODE_REQUEST : std_logic_vector(15 downto 0) := x"0001";
  constant C_ARP_OPCODE_REPLY   : std_logic_vector(15 downto 0) := x"0002";
  constant C_ARP_OPCODE_UNKNOWN : std_logic_vector(15 downto 0) := x"0003"; -- For simulation only

  -- ARP RX Filter
  constant C_ARP_FILTER_UNICAST           : std_logic_vector(1 downto 0) := "00";
  constant C_ARP_FILTER_BROADCAST_UNICAST : std_logic_vector(1 downto 0) := "01";
  constant C_ARP_FILTER_NO_FILTER         : std_logic_vector(1 downto 0) := "10";
  constant C_ARP_FILTER_STATIC_TABLE      : std_logic_vector(1 downto 0) := "11";

  -- ARP Parameters
  constant C_ARP_HW_TYPE              : std_logic_vector(15 downto 0)  := x"0001"; -- ARP Header : Ethernet
  constant C_ARP_HW_ADDR_LENGTH       : std_logic_vector(7 downto 0)   := x"06"; -- ARP Header : Hw. address length
  constant C_ARP_PROTOCOL_ADDR_LENGTH : std_logic_vector(7 downto 0)   := x"04"; -- ARP Header : Protocol address length
  constant C_ARP_TX_PADDING           : std_logic_vector(143 downto 0) := (others => '0'); -- Padding bytes required for a frame (18 bytes)

  -- ARP Broadcast
  constant C_ARP_BROADCAST_MAC    : std_logic_vector(47 downto 0) := C_BROADCAST_MAC_ADDR;
  constant C_ARP_BROADCAST_TARGET : std_logic_vector(47 downto 0) := x"00_00_00_00_00_00";

  -- MAC Parameters
  constant C_MAC_HEADER_SIZE : positive := 14;

  -- IPv4 Parameters
  constant C_IPV4_MAX_PACKET_SIZE  : positive := 1500;
  constant C_IPV4_MIN_HEADER_SIZE  : positive := 20;
  constant C_IPV4_MAX_PAYLOAD_SIZE : positive := C_IPV4_MAX_PACKET_SIZE - C_IPV4_MIN_HEADER_SIZE; --1480

  -- UDP Parameters
  constant C_UDP_HEADER_SIZE : positive := 8;

  -- TCP Parameters
  constant C_TCP_HEADER_SIZE : positive := 20;

  -- Status
  constant C_STATUS_VALID   : std_logic := '0';
  constant C_STATUS_INVALID : std_logic := '1';

end package uoe_module_pkg;


