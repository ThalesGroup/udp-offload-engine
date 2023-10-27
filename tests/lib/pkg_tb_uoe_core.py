# Copyright (c) 2022-2023 THALES. All Rights Reserved

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import random
from random import randbytes
from random import Random

import cocotb
from cocotb.binary import BinaryValue
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame)

from lib.ethframe import EthFrame
from lib.arpframe import ArpFrame
from lib.udpframe import UdpFrame
from lib.ipv4frame import Ipv4Frame

BROADCAST_IP_ADDR = 0xFF_FF_FF_FF
BROADCAST_MAC_ADDR = 0xFF_FF_FF_FF_FF_FF
ZERO_IP_ADDR = 0x00_00_00_00
ZERO_MAC_ADDR = 0x00_00_00_00_00_00

MULTICAST_MAC_ADDR_MSB = 0x01_00_5E

ETH_MAC_ADDR_1 = 0x11_12_13_14_15_16
ETH_MAC_ADDR_2 = 0x21_22_23_24_25_26
ETH_MAC_ADDR_3 = 0x31_32_33_34_35_36
ETH_MAC_ADDR_4 = 0x41_42_43_44_45_46
ETH_MAC_ADDR_5 = 0x51_52_53_54_55_56

ETH_MAC_LIST = [ETH_MAC_ADDR_1, ETH_MAC_ADDR_2, ETH_MAC_ADDR_3, ETH_MAC_ADDR_4]

ETH_IP_ADDR_1 = 0xC0_A8_01_0A
ETH_IP_ADDR_2 = 0xC0_A8_01_0F
ETH_IP_ADDR_3 = 0xC0_A8_01_14
ETH_IP_ADDR_4 = 0xC0_A8_01_19
ETH_IP_ADDR_5 = 0xC0_A8_01_1E

ETH_IP_LIST = [ETH_IP_ADDR_1, ETH_IP_ADDR_2, ETH_IP_ADDR_3, ETH_IP_ADDR_4]

ETH_PORT_ADDR_1 = 0x1234
ETH_PORT_ADDR_2 = 0x5678
ETH_PORT_ADDR_3 = 0x9ABC
ETH_PORT_ADDR_4 = 0xDEF0

ETH_PORT_LIST = [ETH_PORT_ADDR_1, ETH_PORT_ADDR_2, ETH_PORT_ADDR_3, ETH_PORT_ADDR_4]

ETHERTYPE_ARP = 0x0806
ETHERTYPE_IPV4 = 0x0800
ETHERTYPE_RAW_MAX = 0x05DC
ETHERTYPE_RAW = 0x0111
ETHERTYPE_UNKNOWN = 0xFFFF

ETHERTYPE_1 = 0x1234
ETHERTYPE_2 = 0xABCD
ETHERTYPE_3 = 0xA55A
ETHERTYPE_4 = 0xBEAF
ETHERTYPE_LIST = [ETHERTYPE_1, ETHERTYPE_2, ETHERTYPE_3, ETHERTYPE_4]

ETH_SIZE_MIN = 1
ETH_SIZE_MAX = 50
ETH_SIZE_RATE = 1024

PROTOCOL_UDP = 0x11
PROTOCOL_TCP = 0x06
PROTOCOL_ICMPV4 = 0x01
PROTOCOL_IGMP = 0x02
PROTOCOL_UNKNOWN = 0xFF

STANDARD_PORT_MAX = 0x03FF
HTTP_PORT = 0x0050
DHCP_PORT = 0x0043
DNS_PORT = 0x0035
NBNS_NS_PORT = 0x0089
NBNS_DGM_PORT = 0x008A
NBNS_SSN_PORT = 0x008B

TDEST_RAW = BinaryValue('000')
TDEST_ARP = BinaryValue('001')
TDEST_MAC_SHAPING = BinaryValue('010')
TDEST_EXT = BinaryValue('011')
TDEST_TRASH = BinaryValue('100')

ARP_REQUEST = 0
ARP_REPLY = 1

ARP_OPCODE_REQUEST = 0x0001
ARP_OPCODE_REPLY = 0x0002
ARP_OPCODE_UNKNOWN = 0x0003

ARP_FILTER_UNICAST = BinaryValue('00')
ARP_FILTER_BROADCAST_UNICAST = BinaryValue('01')
ARP_FILTER_NO_FILTER = BinaryValue('10')
ARP_FILTER_STATIC_TABLE = BinaryValue('11')

ARP_HW_TYPE = 0x0001
ARP_HW_ADDR_LENGTH = 0x06
ARP_PROTOCOL_ADDR_LENGTH = 0x04
ARP_TX_PADDING = BinaryValue('1' * 144)

ARP_BROADCAST_MAC = BROADCAST_MAC_ADDR
ARP_BROADCAST_TARGET = 0x00_00_00_00_00_00

ARP_TIMEOUT_MS = 2  # 0->4065
ARP_TRYINGS = 3  # 0->7
ARP_RX_TARGET_IP_FILTER = 0  # 0->3
ARP_CONFIGURATION = ((ARP_RX_TARGET_IP_FILTER & 0b11) << 17) + ((ARP_TRYINGS & 0xF) << 12) + (ARP_TIMEOUT_MS & 0xFFF)
ARP_CONFIGURATION = ARP_CONFIGURATION.to_bytes(4, 'little')

MAC_HEADER_SIZE = 14

IPV4_MAX_PACKET_SIZE = 1500
IPV4_MIN_HEADER_SIZE = 20
IPV4_MAX_PAYLOAD_SIZE = IPV4_MAX_PACKET_SIZE - IPV4_MIN_HEADER_SIZE

UDP_HEADER_SIZE = 8
TCP_HEADER_SIZE = 20

STATUS_VALID = 0
STATUS_INVALID = 1

MAIN_REG_LOCAL_MAC_ADDR_LSB = 0x04
MAIN_REG_LOCAL_MAC_ADDR_MSB = 0x08
MAIN_REG_LOCAL_IP_ADDR = 0x0C
MAIN_REG_ARP_CONFIGURATION = 0x30
MAIN_REG_INTERRUPT_ENABLE = 0x58
MAIN_REG_CONFIG_DONE = 0x38
MAIN_REG_INTERRUPT_CLEAR = 0x5C
MAIN_REG_VERSION = 0x00

ETH_PAYLOAD_MAX_SIZE = IPV4_MAX_PACKET_SIZE - (IPV4_MIN_HEADER_SIZE + TCP_HEADER_SIZE)

IP_HEADER_VERSION = 0x4
IP_HEADER_LENGTH = 0x5
IP_HEADER_SERVICES = 0x0

TB_ETH_PKT_MIN_SIZE = 60
ETH_PAYLOAD_ARP_SIZE = 28


def add_padding(packet, nb_bytes_min):
    if len(packet) < nb_bytes_min:
        packet += bytes([0x00]) * (nb_bytes_min - len(packet))
    return packet


def generateFrame_UDP_TX(random_gen, size, dest, src, ip):
    # Generate tdata with dest_mac and src_mac

    tdata = random_gen.randbytes(size)
    tuser = int.from_bytes(dest.to_bytes(2, 'big') + src.to_bytes(2, 'big') + size.to_bytes(2, 'big') + ip.to_bytes(4, 'big'), 'big')
    tkeep = [1] * len(tdata)
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=tuser)
    return frame


def generateFrame_ARP_v2(opcode, mac_src, mac_dest, ip_src, ip_dest, padding_en=False):

    if mac_dest == ARP_BROADCAST_MAC:
        dest = ZERO_MAC_ADDR
    else:
        dest = mac_dest

    arp_part = ArpFrame(opcode,
                        mac_src.to_bytes(6, 'big'),
                        ip_src.to_bytes(4, 'big'),
                        dest.to_bytes(6, 'big'),
                        ip_dest.to_bytes(4, 'big'))
    data = EthFrame(mac_dest.to_bytes(6, 'big'),
                    mac_src.to_bytes(6, 'big'),
                    ETHERTYPE_ARP,
                    arp_part)
    data = EthFrame.__bytes__(data)

    if padding_en:
        tdata = add_padding(data, TB_ETH_PKT_MIN_SIZE)

    tkeep = [1] * len(tdata)
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
    return frame


def generateFrame_IPV4(random_gen, mac_src, ip_src, mac_dest, ip_dest, protocole, frame_id, port_src, port_dest, nb_bytes=0, ttl=0, padding_en=False, frag_more=0, frag_offset=0):

    if nb_bytes == 0:
        eth_nb_bytes = random_gen.randint(1, ETH_PAYLOAD_MAX_SIZE)
    else:
        eth_nb_bytes = nb_bytes

    udp_part = UdpFrame(port_src,
                        port_dest,
                        random_gen.randbytes(eth_nb_bytes))

    ipv4_part = Ipv4Frame(frame_id,
                          protocole,
                          ip_src.to_bytes(4, 'big'),
                          ip_dest.to_bytes(4, 'big'),
                          udp_part)

    data = EthFrame(mac_dest.to_bytes(6, 'big'),
                    mac_src.to_bytes(6, 'big'),
                    ETHERTYPE_IPV4,
                    ipv4_part)

    tdata = EthFrame.__bytes__(data)

    if padding_en:
        tdata = add_padding(data, TB_ETH_PKT_MIN_SIZE)

    tkeep = [1] * len(tdata)
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
    return frame


def generateFrame_RAW_TX(random_gen, min_size, max_size):
    """Generation of RAW frame with pseudo-random way"""
    while True:
        size = random_gen.randint(min_size, max_size)  # Generate random size
        tdata = random_gen.randbytes(size)  # Generate tdata with random bytes
        tkeep = [1] * len(tdata)  # Generate tkeep
        tuser = ETHERTYPE_RAW  # Generate tid with random ethertype
        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=tuser)
        yield frame


def generateFrame_RAW_RX(random_gen, min_size, max_size, dest, src):
    """Generation of RAW frame with pseudo-random way"""
    size = random_gen.randint(min_size, max_size)  # Generate random size
    # Building axis frame with ethernet protocole
    tdata = EthFrame(dest.to_bytes(6, 'big'), src.to_bytes(6, 'big'), ETHERTYPE_RAW, random_gen.randbytes(size))
    tdata = tdata.__bytes__()
    tkeep = [1] * len(tdata)  # Generate tkeep
    frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
    return frame


def generateFrame_ETH_RX(random_gen, min_size, max_size, dest, src):
    """Generation of RAW frame with pseudo-random way"""
    while True:
        size = random_gen.randint(min_size, max_size)  # Generate random size
        # Building axis frame with ethernet protocole
        tdata = EthFrame(dest.to_bytes(6, 'big'), src.to_bytes(6, 'big'), ETHERTYPE_UNKNOWN, random_gen.randbytes(size))
        tdata = tdata.__bytes__()
        tkeep = [1] * len(tdata)  # Generate tkeep
        frame = AxiStreamFrame(tdata=tdata, tkeep=tkeep, tid=None, tdest=None, tuser=None)
        return frame
