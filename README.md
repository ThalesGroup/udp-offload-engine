# udp-offload-engine

This repository is actually in construction

## Get started

The UDP Offload Engine is an IP VHDL used for FPGA hardware programming.

This IP is an UDP-IP stack accelerator and is able to send and receive data through Ethernet link.
This stack is highly configurable to be used with Ethernet rates up to 40Gb/s thanks to its configurable bus size.
Moreover it is modular. It implements different protocols and integrated testing tools that can be deactivated in order to save resources.

This IP is based on Building Blocks following the Thales Strategy in engineering. They perform basic functions and allow to be independent from the platform/target.
No manufacturer primitive are used on this design, all are inferred.

## Documentation

![uoe](https://github.com/ThalesGroup/udp-offload-engine/blob/master/docs/schematics/UOE_functinnal_scheme.png)

This figure describe the internal architecture of the IP which can be decomposed as follow :

* Functionnal part

  * Link layer : Lower layer of the IP, it allows the connection with the MAC layer. It handle the Ethernet protocol, directs incoming packets and can filter them.
  * Internet layer : It is the intermediate layer which handle the IPv4 Protocol and a part of ICMP Protocol (Ping)
  * Transport layer : This layer is dedicated to the UDP protocol
  
* Built-In-Test part (Optional)

  * On the main interfaces of the stack (MAC and UDP), two LoopBack fifos have been implemented
  * On the UDP Side, a generator/checker has been integrated for debugging.

Full documentation of the stack will be coming soon...

## Key points

* Configurable bus size

* Handle the following protocols

  * User Datagram Protocol (UDP)
  * Internet Protocol version 4 (IPv4)
    * Fragmentation support
    
* Address Resolution Protocol (ARP)

  * Handle of ARP Table
  * IP/MAC address conflict detection

* Internet Control Message Procotol (ICMP)

  * Echo Request/Reply (PING) (Coming soon...)
  
* Take into account buffers on the MAC interface and clock domain crossing

* Filtering option for incoming traffic

* Use of standard bus

  * Data link in AXI4-Stream 
  * Control link in AXI4-Lite 32 bits
  
## Design example

This repo integrate the following design example :

* AMD-Xilinx FPGA: on KCU105 EvalBoard
  
## Contributing

If you are interested in contributing to this project, start by reading the [Contributing guide](/CONTRIBUTING.md).

## License

* [Apache License, Version 2.0](https://github.com/ThalesGroup/udp-offload-engine/blob/master/LICENSE) 