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

# Header MAC Description (14 Bytes)
# |------|------|------|------|------|------|------|------|------|------|------|------|------|------|
# |            Dest MAC Address             |             SRC MAC Address             |  EtherType  |
# |------|------|------|------|------|------|------|------|------|------|------|------|------|------|
# |  0   |                                                                                   |  13  |


# Ethertype
class ETHERTYPE_ENUM(IntEnum):
    """ Enumerate used to list the Ethertype handle by the EthFrame class """
    IPV4 = 0x0800
    ARP = 0x0806


@dataclass
class EthFrame(Payload):
    """ dataclass use to describe an Ethernet frame inherit from Payload"""
    dst_mac_addr: bytes
    src_mac_addr: bytes
    ethertype: int
    payload: Union[bytes, "Payload"] = b''

    # Class variable
    ethertype_dict: ClassVar[dict[int, "Payload"]] = {}

    def __bytes__(self) -> bytes:
        """ Convert the Payload to bytes """
        # print(bytes(self.payload).hex('_', 1))
        return self.dst_mac_addr + self.src_mac_addr + self.ethertype.to_bytes(2, 'big') + bytes(self.payload)

    @classmethod
    def from_bytes(cls, b: bytes) -> "Payload":
        """ Create an instance of Payload for bytes """
        dst_mac_addr = b[0:6]
        src_mac_addr = b[6:12]
        ethertype = int.from_bytes(b[12:14], 'big')
        payload = b[14:]

        payload_class = cls.ethertype_dict.get(ethertype)
        if payload_class:
            payload = payload_class.from_bytes(payload)

        return cls(dst_mac_addr, src_mac_addr, ethertype, payload)

    @classmethod
    def layer3(cls, ethertype: int):
        """ classmethod used to populate the list of known payload"""
        def wrap(cls_):
            cls.ethertype_dict[ethertype] = cls_
            return cls_
        return wrap
