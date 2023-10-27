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
# For Payload
from lib.payload import Payload
from lib.ipv4frame import Ipv4Frame, IPV4_PROTOCOL_ENUM

# Header UDP Description (8 bytes)
#  |-------------|-------------|-------------|-------------|
#  |          Port SRC         |        Port DEST          |
#  |-------------|-------------|-------------|-------------|
#  |       Size of frame       |    Checksum (optionnal)   |
#  |-------------|-------------|-------------|-------------|

# UDP Constants
UDP_HEADER_LENGTH = 8  # Size in bytes


@Ipv4Frame.layer4(IPV4_PROTOCOL_ENUM.UDP)
@dataclass
class UdpFrame(Payload):
    """ dataclass use to describe an UDP frame inherit from Payload"""
    src_port: int
    dst_port: int
    payload: bytes

    def __bytes__(self) -> bytes:
        """Convert the Payload to bytes"""
        return self.src_port.to_bytes(2, 'big') + self.dst_port.to_bytes(2, 'big') + \
            (UDP_HEADER_LENGTH + len(bytes(self.payload))).to_bytes(2, 'big') + bytes(2) + \
            bytes(self.payload)

    @classmethod
    def from_bytes(cls, b: bytes) -> "Payload":
        """Create an instance of Payload for bytes"""
        src_port = int.from_bytes(b[0:2], 'big')
        dst_port = int.from_bytes(b[2:4], 'big')
        payload = b[8:]

        return cls(src_port, dst_port, payload)
