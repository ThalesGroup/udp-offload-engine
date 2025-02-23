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

# Header DHCP Description (240 bytes)
#  0               1               2               3
#  0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
#  +===============================+===============================+
#  |     op (1)    |   htype (1)   |   hlen (1)    |   hops (1)    |
#  +---------------+---------------+---------------+---------------+
#  |                            xid (4)                            |
#  +-------------------------------+-------------------------------+
#  |           secs (2)            |           flags (2)           |
#  +-------------------------------+-------------------------------+
#  |                          ciaddr  (4)                          |
#  +---------------------------------------------------------------+
#  |                          yiaddr  (4)                          |
#  +---------------------------------------------------------------+
#  |                          siaddr  (4)                          |
#  +---------------------------------------------------------------+
#  |                          giaddr  (4)                          |
#  +---------------------------------------------------------------+
#  |                                                               |
#  |                          chaddr  (16)                         |
#  |                                                               |
#  |                                                               |
#  +---------------------------------------------------------------+
#  |                                                               |
#  |                          sname   (64)                         |
#  +---------------------------------------------------------------+
#  |                                                               |
#  |                          file    (128)                        |
#  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
#  |                          MAGIC_COOKIE                         |
#  +-+---+-+---+-+---+-+---+-+---+-+---+-+---+-+---+-+---+-+---+-+-+
#  |                   (more) options (variable)                   |
#  +---------------------------------------------------------------+

# DHCP Constants
DHCP_HEADER_LENGTH = 240  # Size in bytes
MAGIC_COOKIE       = 0x63825363

    
@dataclass
class DhcpFrame(Payload):
    """ dataclass use to describe an DHCP frame inherit from Payload"""
    op     : int
    htype  : int
    hlen   : int
    hops   : int
    xid    : int
    secs   : int
    flags  : int
    ciaddr : int
    yiaddr : int
    siaddr : int
    giaddr : int
    chaddr : int
    options: bytes

    def __bytes__(self) -> bytes:
        """Convert the Payload to bytes"""
        return self.op.to_bytes(1, 'big') + self.htype.to_bytes(1, 'big') + \
            self.hlen.to_bytes(1, 'big') + self.hops.to_bytes(1, 'big') + \
            self.xid.to_bytes(4, 'big') + self.secs.to_bytes(2, 'big') + \
            self.flags.to_bytes(2, 'big') + self.ciaddr.to_bytes(4, 'big') + \
            self.yiaddr.to_bytes(4, 'big') + self.siaddr.to_bytes(4, 'big') + \
            self.giaddr.to_bytes(4, 'big') + self.chaddr.to_bytes(6, 'big') + \
            bytes(202)  + MAGIC_COOKIE.to_bytes(4, 'big') + \
            bytes(self.options)

    @classmethod
    def from_bytes(cls, b: bytes) -> "Payload":
        op      = int.from_bytes(b[0:1], 'big')
        htype   = int.from_bytes(b[1:2], 'big')
        hlen    = int.from_bytes(b[2:3], 'big')
        hops    = int.from_bytes(b[3:4], 'big')
        xid     = int.from_bytes(b[4:8], 'big')
        secs    = int.from_bytes(b[8:10], 'big')
        flags   = int.from_bytes(b[10:12], 'big')
        ciaddr  = int.from_bytes(b[12:16], 'big')
        yiaddr  = int.from_bytes(b[16:20], 'big')
        siaddr  = int.from_bytes(b[20:24], 'big')
        giaddr  = int.from_bytes(b[24:28], 'big')
        chaddr  = int.from_bytes(b[28:44], 'big')
        options = b[240:]
        return cls(op, htype, hlen, hops, xid, secs, flags, ciaddr, yiaddr, siaddr, giaddr, chaddr, options)


