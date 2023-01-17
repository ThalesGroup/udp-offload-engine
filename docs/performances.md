## Out of context implementations

The out of context implementation have been realized with a target frequency equal to 400 MHz

### Impact of data bus width on resources utilization

These implementation have been done for target Kintex Ultrascale : xcku060-ffva1156-1-i. The max frequencies are given as an indication and could be different depending of the design.

The internal data bus width is configured using the G_UOE_TDATA_WIDTH generic.
    
* Data Bus width => 8 bits

|                                      | LUTs | FF   | BRAM | Fmax |
|:-------------------------------------| :--: | :--: | :--: | :--: |
| uoe_core	                           | 3214 | 4858 | 9,5  | 298 MHz |
| &emsp;- link_layer                   | 1931 | 3106 | 5,5  | - |
| &emsp;&emsp;- frame_router           | 858  | 1202 | 3    | - |
| &emsp;&emsp;- arp_module             | 548  | 847  | 0    | - |
| &emsp;&emsp;- mac_shaping            | 473  | 970  | 2,5  | - |
| &emsp;&emsp;- raw_ethernet           | 53   | 87   | 0    | - |
| &emsp;- internet_layer               | 431  | 686  | 0    | - |
| &emsp;- transport_layer              | 141  | 295  | 0    | - |
| &emsp;- Divers (Registers, pkt drop) | 711  | 771  | 4    | - |

* Data Bus width => 32 bits

|                                      |  LUTs | FF   | BRAM | Fmax |
|:-------------------------------------|  :--: | :--: | :--: | :--: |
| uoe_core	                           |  4231 | 6448 | 12   | 321 MHz |
| &emsp;- link_layer                   |  2909 | 4273 | 5,5  | - |
| &emsp;&emsp;- frame_router           |  915  | 1584 | 3    | - |
| &emsp;&emsp;- arp_module             |  777  | 868  | 0    | - |
| &emsp;&emsp;- mac_shaping            |  741  | 1360 | 2,5  | - |
| &emsp;&emsp;- raw_ethernet           |  384  | 461  | 0    | - |
| &emsp;- internet_layer               |  453  | 997  | 0    | - |
| &emsp;- transport_layer              |  210  | 399  | 0    | - |
| &emsp;- Divers (Registers, pkt drop) |  659  | 779  | 6,5  | - |

* Data Bus width => 64 bits

|                                      | LUTs | FF   | BRAM | Fmax |
|:-------------------------------------| :--: | :--: | :--: | :--: |
| uoe_core	                           | 6120 | 8801 | 15   | 308 MHz |
| &emsp;- link_layer                   | 3967 | 5481 | 5,5  | - |
| &emsp;&emsp;- frame_router           | 1022 | 1973 | 3    | - |
| &emsp;&emsp;- arp_module             | 672  | 900  | 0    | - |
| &emsp;&emsp;- mac_shaping            | 1286 | 1785 | 2,5  | - |
| &emsp;&emsp;- raw_ethernet           | 948  | 823  | 0    | - |
| &emsp;- internet_layer               | 1304 | 2007 | 0    | - |
| &emsp;- transport_layer              | 237  | 542  | 0    | - |
| &emsp;- Divers (Registers, pkt drop) | 612  | 771  | 9,5  | - |

* Data Bus width => 128 bits

|                                      | LUTs  | FF    | BRAM | Fmax |
|:-------------------------------------| :--:  | :--:  | :--: | :--: |
| uoe_core	                           | 13525 | 14631 | 21   | 313 MHz |
| &emsp;- link_layer                   | 7438  | 8530  | 5,5  | - |
| &emsp;&emsp;- frame_router           | 1679  | 3345  | 3    | - |
| &emsp;&emsp;- arp_module             | 569   | 962   | 0    | - |
| &emsp;&emsp;- mac_shaping            | 2729  | 2653  | 2,5  | - |
| &emsp;&emsp;- raw_ethernet           | 2462  | 1570  | 0    | - |
| &emsp;- internet_layer               | 2834  | 3311  | 0    | - |
| &emsp;- transport_layer              | 2597  | 2000  | 0    | - |
| &emsp;- Divers (Registers, pkt drop) | 656   | 790   | 15,5 | - |