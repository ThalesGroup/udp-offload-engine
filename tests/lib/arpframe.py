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

# Dataclasses are uses to represent Frames
from dataclasses import dataclass
# For Enumerate
from enum import IntEnum
# For Payload
from lib.payload import Payload
from lib.ethframe import EthFrame, ETHERTYPE_ENUM


# ARP Constants
ARP_HW_TYPE = 1
ARP_HW_ADDR_LENGTH = 6
ARP_PROTOCOL_ADDR_LENGTH = 4


# ARP Operation
class ARP_OPCODE_ENUM(IntEnum):
    """ Enumerate used to list the Opcode handle by the ArpFrame class"""
    REQ = 1
    REPLY = 2


@EthFrame.layer3(ETHERTYPE_ENUM.ARP)
@dataclass
class ArpFrame(Payload):
    """ dataclass use to describe an ARP frame inherit from Payload"""
    opcode: ARP_OPCODE_ENUM
    sender_hw_addr: bytes
    sender_protocol_addr: bytes
    target_hw_addr: bytes
    target_protocol_addr: bytes

    def __bytes__(self) -> bytes:
        """ Convert the Payload to bytes """
        return ARP_HW_TYPE.to_bytes(2, 'big') + ETHERTYPE_ENUM.IPV4.to_bytes(2, 'big') + \
            ARP_HW_ADDR_LENGTH.to_bytes(1, 'big') + ARP_PROTOCOL_ADDR_LENGTH.to_bytes(1, 'big') + self.opcode.to_bytes(2, 'big') + \
            self.sender_hw_addr + self.sender_protocol_addr + \
            self.target_hw_addr + self.target_protocol_addr

    @classmethod
    def from_bytes(cls, b: bytes) -> "Payload":
        """ Create an instance of Payload for bytes """
        opcode = int.from_bytes(b[6:8], 'big')
        sender_hw_addr = b[8:14]
        sender_protocol_addr = b[14:18]
        target_hw_addr = b[18:24]
        target_protocol_addr = b[24:28]

        return cls(opcode, sender_hw_addr, sender_protocol_addr, target_hw_addr, target_protocol_addr)

        # TODO: Add check of constant parameters
