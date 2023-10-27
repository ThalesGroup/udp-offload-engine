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

# ClassVar for ethertype_dict, Union for fields that can be several types
from typing import ClassVar, Union
# Dataclasses are uses to represent Frames
from dataclasses import dataclass
# For Enumerate
from enum import IntEnum
# For Payload
from lib.payload import Payload
from lib.ethframe import EthFrame, ETHERTYPE_ENUM

# Header IPV4 Description (20 Bytes)
# |-------------|-------------|-------------|-------------|
# | Vers.  IHL  |     ToS     |        Total Length       |
# |-------------|-------------|-------------|-------------|
# |         Frame Id          |Ind|    Frag offset        |
# |-------------|-------------|-------------|-------------|
# |     TTL     |   Protocol  |     Header Checksum       |
# |-------------|-------------|-------------|-------------|
# |                       IP Source                       |
# |-------------|-------------|-------------|-------------|
# |                     IP Destination                    |
# |-------------|-------------|-------------|-------------|
# |     Options + Padding (Not handle by this module)     |
# |-------------|-------------|-------------|-------------|
# IHL : Internet Header Length
# ToS : Type of Service
# TTL : Time To Live

# IPv4 Constants
IPV4_HEADER_VERSION = 4
IPV4_HEADER_LENGTH = 5    # Header Length in 32-bit word
IPV4_HEADER_SERVICES = 0  # Not used

IPV4_TTL_DEFAULT = 100    # Time To Leave


# Enumerate Subprotocol
class IPV4_PROTOCOL_ENUM(IntEnum):
    """ Enumerate used to list the sub protocol handle by the Ipv4Frame class"""
    TCP = 0x06
    UDP = 0x11
    ICMPv4 = 0x01
    IGMP = 0x02


@EthFrame.layer3(ETHERTYPE_ENUM.IPV4)
@dataclass
class Ipv4Frame(Payload):
    """ dataclass use to describe an IPv4 frame inherit from Payload"""
    frame_id: int
    sub_protocol: IPV4_PROTOCOL_ENUM
    ip_src: bytes
    ip_dest: bytes
    payload: Union[bytes, "Payload"] = b''
    ttl: int = IPV4_TTL_DEFAULT
    frag_flags: int = 0
    frag_offset: int = 0

    # Classe variable
    ipv4_protocol_dict: ClassVar[dict[int, "Payload"]] = {}

    def __header_with_null_crc(self):
        """Convert the object header fields to bytes for checksum computation"""
        return ((IPV4_HEADER_VERSION << 4) + IPV4_HEADER_LENGTH).to_bytes(1, 'big') + \
            IPV4_HEADER_SERVICES.to_bytes(1, 'big') + ((4 * IPV4_HEADER_LENGTH) + len(bytes(self.payload))).to_bytes(2, 'big') + \
            self.frame_id.to_bytes(2, 'big') + \
            (((self.frag_flags & 0x7) << 13) + (self.frag_offset & 0x1FFF)).to_bytes(2, 'big') + \
            self.ttl.to_bytes(1, 'big') + \
            self.sub_protocol.to_bytes(1, 'big') + bytes(2) + \
            self.ip_src + self.ip_dest

    @staticmethod
    def compute_checksum(data: bytes):
        """ Compute checksum on the given data """
        # Set CRC
        data_null_checksum = data[:10] + bytes(2) + data[12:]

        # Compute crc
        crc = 0
        for i in range(10):
            crc = (crc & 0xFFFF) + ((crc >> 16) & 0x1) + int.from_bytes(bytes=data_null_checksum[(2 * i):(2 * (i + 1))], byteorder='big')

        # Complement and convert to bytes
        return (0xFFFF - crc).to_bytes(2, 'big')

    def checksum(self):
        """ Return checksum of the current Header """
        # Get header in bytes
        header = self.__header_with_null_crc()

        return self.compute_checksum(header)

    def __bytes__(self) -> bytes:
        """ Convert the Payload to bytes """
        header = self.__header_with_null_crc()
        return header[:10] + self.checksum() + header[12:] + bytes(self.payload)

    @classmethod
    def from_bytes(cls, b: bytes) -> "Payload":
        """ Create an instance of Payload for bytes """
        frame_id = int.from_bytes(b[4:6], 'big')
        frag_flags = (int.from_bytes(b[6:8], 'big') >> 13) & 0x7
        frag_offset = int.from_bytes(b[6:8], 'big') & 0x1FFF
        ttl = int.from_bytes(b[8:9], 'big')
        sub_protocol = int.from_bytes(b[9:10], 'big')
        ip_src = b[12:16]
        ip_dest = b[16:20]
        payload = b[20:]

        # Checksum
        assert b[10:12] == cls.compute_checksum(b[:20]), "Checksum error"

        payload_class = cls.ipv4_protocol_dict.get(sub_protocol)
        if payload_class:
            payload = payload_class.from_bytes(payload)

        return cls(frame_id, sub_protocol, ip_src, ip_dest, payload, ttl, frag_flags, frag_offset)

        # TODO: Check of constant parameters

    @classmethod
    def layer4(cls, prot: int):
        """ classmethod used to populate the list of known payload """
        def wrap(cls_):
            cls.ipv4_protocol_dict[prot] = cls_
            return cls_
        return wrap
