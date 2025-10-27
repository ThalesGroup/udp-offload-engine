## IP Package instructions

To package the UOE core into a Vivado IP, first clone the repository:

```
git clone https://github.com/ThalesGroup/udp-offload-engine.git
```

Next, move to the `ip/` directory inside the cloned repo:

```
cd udp-offload-engine/ip
```

Finally, run the following command to package the IP using Vivado:

```
vivado -mode batch -notrace -source package_uoe_ip.tcl
```

After this, the IP is available under the `<uoe_dir>/ip/ip_repo` directory. The directory can be added to the Vivado IP repository to make the UOE core available in the IP Catalog. 

