# 📘 User Guide

This user guide is designed to help you quickly get started with the project. It provides a high-level overview of the KCU105 example and its key components.

## 🛠️ Project Build Instructions

First, choose an appropriate directory to store the project, then clone the entire `udp-offload-engine` repository into that folder:

```bash
git clone https://github.com/ThalesGroup/udp-offload-engine.git
```

Next, open Vivado and, using the TCL console, navigate to the directory where the KCU105 project example is located:

``` bash
cd ~/path/to/udp-offload-engine/examples/KCU105
```

Finally, run the TCL script to build the project and wait for the process to complete:

``` bash
source top_demo_uoe.tcl
```

> ⚠️ **Attention:** Make sure your Vivado installation includes support for the KCU105 target part: `xcku040-ffva1156-2-e`.

## ⌛ Bitstream Generation

Now that everything is set up, it's time to generate the bitstream. In the **Flow Navigator**, click on **Generate Bitstream**. This step can take a few minutes.

> ⚠️ **Attention:** You may encounter issues depending on your **Vivado version** or available **licenses**.

### 📜 Licenses

As mentioned in the [architecture.md](https://github.com/ThalesGroup/udp-offload-engine/blob/master/docs/architecture.md), the `udp-offload-engine` does not implement the physical layer or the lower portion of the link layer. To enable these layers, Xilinx IP cores are required — and some of them may need additional licenses.

> 💡 **Tip:** You can check which IPs require a license by going to **Reports > Report IP Status** in Vivado and reviewing the **License** column.

To save you some time, the tables below list all the required licenses for the project.

#### 🆓 Included Xilinx IP Cores

The IP cores shown in the table below are provided by Xilinx at no extra cost. They are automatically available in the Vivado IP Catalog after installation.

| IP Core                          | Recommended Version |
|:--------------------------------:|:-------------------:|
| Clocking Wizard                  | 6.0 (Rev. 3)        |
| 1G/2.5G Ethernet PCS/PMA or SGMII| 16.1 (Rev. 6)       |
| JTAG to AXI Master               | 1.2 (Rev. 9)        |
| VIO (Virtual Input/Output)       | 3.0 (Rev. 20)       |

#### 💰 Licensed Xilinx IP Cores

| IP Core                          | Recommended Version |
|:--------------------------------:|:-------------------:|
| [10G/25G Ethernet Subsystem](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/ef-di-25gemac.html)       | 3.0                 |
| [Tri Mode Ethernet MAC](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/temac.html)            | 9.0 (Rev. 14)       |


> 💡 **Tip:** Even if you don’t currently have these licenses, you can request a **120-day free trial** on the Xilinx official website. Simply click on the IP names in the table above to be redirected to their respective pages. For more information on how to obtain and install the required licenses, please refer to [this guide](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Obtain-and-Manage-Licenses).

## 🔑 KCU105 Board Interface Overview

Before loading the bitstream into the FPGA, it's important to understand how to interact with the board. This project uses some debug **LEDs**, **control switches**, and a **pushbutton** for basic interaction and status monitoring. To help you get more familiar with the KCU105 board layout, the image below provides an overview of these interfaces.

![KCU105 Schematic](./images/KCU105.svg)

All GPIO ports are active-high. The ones used in this project are listed in the tables below, along with their corresponding configuration details. For more information about these interfaces, please refer to the [KCU105 Board User Guide](https://www.xilinx.com/support/documents/boards_and_kits/kcu105/ug917-kcu105-eval-bd.pdf).

> 📌 You can find the port assignments in the XDC files located at: `./constrs`.

### LEDs

| Top-Level Port  | FPGA Pin   | Schematic Net Name | I/O Standard |
|:---------------:|:----------:|:------------------:|:------------:|
| `GPIO_LED[0]`   | **AP8**    | `GPIO_LED_0`       | LVCMOS18     |
| `GPIO_LED[1]`   | **H23**    | `GPIO_LED_1`       | LVCMOS18     |
| `GPIO_LED[2]`   | **P20**    | `GPIO_LED_2`       | LVCMOS18     |
| `GPIO_LED[3]`   | **P21**    | `GPIO_LED_3`       | LVCMOS18     |
| `GPIO_LED[4]`   | **N22**    | `GPIO_LED_4`       | LVCMOS18     |
| `GPIO_LED[5]`   | **M22**    | `GPIO_LED_5`       | LVCMOS18     |
| `GPIO_LED[6]`   | **R23**    | `GPIO_LED_6`       | LVCMOS18     |
| `GPIO_LED[7]`   | **P23**    | `GPIO_LED_7`       | LVCMOS18     |

### Switches

| Top-Level Port       | FPGA Pin  | Schematic Net Name  | I/O Standard |
|:--------------------:|:---------:|:-------------------:|:------------:|
| `GPIO_DIP_SW[0]`     | **AN16**  | `GPIO_DIP_SW0`      | LVCMOS12     |
| `GPIO_DIP_SW[1]`     | **AN19**  | `GPIO_DIP_SW1`      | LVCMOS12     |
| `GPIO_DIP_SW[2]`     | **AP18**  | `GPIO_DIP_SW2`      | LVCMOS12     |
| `GPIO_DIP_SW[3]`     | **AN14**  | `GPIO_DIP_SW3`      | LVCMOS12     |


### Pushbutton

| Top-Level Port       | FPGA Pin  | Schematic Net Name  | I/O Standard |
|:--------------------:|:---------:|:-------------------:|:------------:|
| `CPU_RESET`          | **AE10**  | `GPIO_SW_C`         | LVCMOS18     |

> ❗ Pressing this button will reset the entire system, which means all configured register values will be lost! 

### SFP

| Top-Level Port          | FPGA Pin  | Schematic Net Name  | I/O Standard |
|:-----------------------:|:---------:|:-------------------:|:------------:|
| `SFP_REFCLK_N`          | **P5**    | `MGT_SI570_CLOCK_N` | —            |
| `SFP_REFCLK_P`          | **P6**    | `MGT_SI570_CLOCK_P` | —            |

> These SFP transceiver pins are routed to the FPGA's high-speed serial transceivers (GTX/GTY) and do not use traditional I/O standards like LVCMOS. Therefore, the "I/O Standard" column is marked as —.

#### SFP 10G

| Top-Level Port     | FPGA Pin | Schematic Net Name | I/O Standard |
|:------------------:|:--------:|:------------------:|:------------:|
| `SFP_TX_P[0]`      | **U4**   | `SFP0_TX_P`        | —            |
| `SFP_TX_N[0]`      | **U3**   | `SFP0_TX_N`        | —            |
| `SFP_RX_P[0]`      | **T2**   | `SFP0_RX_P`        | —            |
| `SFP_RX_N[0]`      | **T1**   | `SFP0_RX_N`        | —            |

#### SFP 1G

| Top-Level Port     | FPGA Pin | Schematic Net Name | I/O Standard |
|:------------------:|:--------:|:------------------:|:------------:|
| `SFP_TX_P[1]`      | **W4**   | `SFP1_TX_P`        | —            |
| `SFP_TX_N[1]`      | **W3**   | `SFP1_TX_N`        | —            |
| `SFP_RX_P[1]`      | **V2**   | `SFP1_RX_P`        | —            |
| `SFP_RX_N[1]`      | **V1**   | `SFP1_RX_N`        | —            |

### UART

| Top-Level Port | FPGA Pin | Schematic Net Name | I/O Standard |
|:--------------:|:--------:|:------------------:|:------------:|
| `UART_RX`      | **G25**  | `USB_UART_TX`      | LVCMOS18     |
| `UART_TX`      | **K26**  | `USB_UART_RX`      | LVCMOS18     |

### Clock

| Top-Level Port | FPGA Pin | Schematic Net Name | I/O Standard |
|:--------------:|:--------:|:------------------:|:------------:|
| `CLK_125_P`    | **G10**  | `CLK_125MHZ_P`     | LVDS         |
| `CLK_125_N`    | **F10**  | `CLK_125MHZ_N`     | LVDS         |

## 🔧 SFP Configuration

The project includes four Virtual Input/Output (VIO) modules for PHY configuration. Once the bitstream is loaded onto the board, these VIOs will be accessible through Vivado. Below, you’ll find a table with information about the control signals available via the VIO interface.

> ⚠️ **Warning: Typically, the initial configuration is sufficient for a first test, so no changes are necessary!**

### 10G Interface

#### RX Path (hw_vio_1)

##### VIO Outputs (Control Signals)

| Signal Name                     | Values                                 | Brief         |
|:------------------------------:|:--------------------------------------:|:-------------:|
| `ctl_rx_enable`                 | `'1' – Enable RX` <br>`'0' – Disable RX` | Enables RX data path. Set to 1 for normal operation; 0 disables reception after the current packet. No stats or AXI4-Stream output when disabled |
| `ctl_rx_check_preamble`         | `'1' – Check Preamble` <br>`'0' – Ignore Preamble` | Enables verification of the preamble in received frames when set to 1 |
| `ctl_rx_custom_preamble_enable` | `'1' – Enable Custom Preamble` <br>`'0' – Disable Custom Preamble` | When set to 1, includes the received preamble in the AXI4-Stream sideband |
| `ctl_rx_check_sfd`              | `'1' – Check SFD` <br>`'0' – Ignore SFD` | When set to 1, enables checking of the Start of Frame Delimiter (SFD) in received frames |
| `ctl_rx_force_resync`           | `'1' – Force Resync` <br>`'0' – Normal Sync` | Forces RX path to reset and resynchronize when pulsed high; should be normally low |
| `ctl_rx_delete_fcs`             | `'1' – Delete FCS` <br>`'0' – Keep FCS` | Enables RX core to remove FCS from incoming packets; ignored for packets ≤ 8 bytes |
| `ctl_rx_ignore_fcs`             | `'1' – Ignore FCS Errors` <br>`'0' – Check FCS` | Controls whether FCS errors are flagged on AXI4-Stream; when enabled, errors are hidden from `tuser`, but still counted |
| `ctl_rx_min_packet_len[7:0]`    | `Numeric Value` | Sets the minimum allowed frame length; smaller frames trigger `tuser` or are dropped if under 4 bytes |
| `ctl_rx_max_packet_len_0[13:0]` | `Numeric Value` | Sets the maximum allowed frame length; larger frames are truncated and flagged via `tuser` |
| `ctl_rx_process_lfi`            | `'1' – Process LFI` <br>`'0' – Ignore LFI` | Enables or disables processing of Local Fault (LF) control codes received from the transceiver |
| `ctl_rx_test_pattern_enable`    | `'1' – Enable Test Pattern` <br>`'0' – Disable Test Pattern` | Enables RX test pattern mode as per MDIO register 3.42.2 (Clause 45) |
| `ctl_rx_test_pattern`           | `'1' - Receive Scrambled Idle Pattern` <br>`'0' - Ignore Scrambled Idle Pattern` | Enables RX test pattern checking as defined in Clause 49; validates scrambled idle pattern |
| `ctl_rx_data_pattern_select`    | `Data Pattern Select` | Used to select the data pattern in test mode; corresponds to MDIO bit 3.42.0 (Clause 45) |

> 🔎 For detailed information, please refer to the following tables in the official documentation:  
> [AXI4-Stream Interface – RX Path Control/Status Signals](https://docs.amd.com/r/en-US/pg210-25g-ethernet/AXI4-Stream-Control-and-Status-Ports#:~:text=AXI4%2DStream%20Interface%20%E2%80%93%20RX%20Path%20Control/Status%20Signals)  
> [Miscellaneous Status/Control Ports](https://docs.amd.com/r/en-US/pg210-25g-ethernet/AXI4-Stream-Control-and-Status-Ports#:~:text=Miscellaneous%20Status/Control%20Ports)

##### VIO Inputs (Status Monitoring)

| Signal Name                     | Brief           |
|:-------------------------------:|:---------------:|
| `stat_rx_framing_err`           | Counts the number of bad sync header bits detected; valid only when `stat_rx_framing_err_valid` is asserted    |
| `stat_rx_framing_err_valid`     | Indicates when the `stat_rx_framing_err` value is valid during a clock cycle    |
| `stat_rx_bad_fcs[1:0]`          | Pulses on detection of CRC32 errors in received packets; marks packet as errored unless FCS is ignored    |
| `stat_rx_packet_bad_fcs`        | Counts packets sized between 64 bytes and max allowed length that have FCS errors    |
| `stat_rx_stomped_fcs[1:0]`      | Pulses high when packets are received with a stomped (bitwise-inverted) FCS; may pulse consecutively    |
| `stat_rx_bad_code`              | Counts 64B/66B code violations; indicates RX PCS in RX_E state    |
| `stat_rx_bad_sfd`               | Counts received packets with invalid Start of Frame Delimiter (SFD), flagged regardless of SFD check setting    |
| `stat_rx_bad_preamble`          | Counts received packets with invalid preamble, flagged regardless of preamble check setting    |
| `stat_rx_fragment`              | Counts packets shorter than min allowed with bad FCS    |
| `stat_rx_truncated`             | Pulses high when a received packet is truncated for exceeding max length; may pulse consecutively    |
| `stat_rx_oversize`              | Counts packets longer than max allowed with good FCS    |
| `stat_rx_undersize`             | Counts packets shorter than min allowed with good FCS    |
| `stat_rx_jabber`                | Counts packets longer than max length with bad FCS    |
| `stat_rx_hi_ber`                | Indicates high Bit Error Rate (BER) as defined by IEEE 802.3; level-sensitive signal    |
| `stat_rx_local_fault`           | Indicates the RX decoder is currently in the RX_INIT initialization state; level-sensitive output    |
| `stat_rx_internal_local_fault`  | Indicates an internal local fault condition; level-sensitive output    |
| `stat_rx_remote_fault`          | Indicates presence of a remote fault condition; level-sensitive signal    |
| `stat_rx_received_local_fault`  | Indicates a received local fault condition from link partner; level-sensitive output    |
| `stat_rx_block_lock`            | Indicates block lock status for each PCS lane; level-sensitive signal per Clause 49 and MDIO registers 3.50.7:0, 3.51.11:0    |
| `stat_rx_packet_64_bytes`       | Counts received packets of exactly 64 bytes    |
| `stat_rx_packet_65_127_bytes`   | Counts received packets between 65 and 127 bytes    |
| `stat_rx_packet_128_255_bytes`  | Counts received packets between 128 and 255 bytes    |
| `stat_rx_packet_256_511_bytes`  | Counts received packets between 256 and 511 bytes    |
| `stat_rx_packet_512_1023_bytes` | Counts received packets between 512 and 1023 bytes    |
| `stat_rx_packet_1024_1518_bytes`| Counts received packets between 1024 and 1518 bytes    |
| `stat_rx_packet_1519_1522_bytes`| Counts received packets between 1519 and 1522 bytes    |
| `stat_rx_packet_1523_1548_bytes`| Counts received packets between 1523 and 1548 bytes    |
| `stat_rx_packet_1549_2047_bytes`| Counts received packets between 1549 and 2047 bytes    |
| `stat_rx_packet_2048_4095_bytes`| Counts received packets between 2048 and 4095 bytes    |
| `stat_rx_packet_4096_8191_bytes`| Counts received packets between 4096 and 8191 bytes    |
| `stat_rx_packet_8192_9215_bytes`| Counts received packets between 8192 and 9215 bytes    |
| `stat_rx_packet_large`          | Counts packets larger than 9,215 bytes    |
| `stat_rx_packet_small`          | Counts packets smaller than 64 bytes; packets under 4 bytes are dropped    |
| `stat_rx_unicast`               | Counts valid unicast packets received    |
| `stat_rx_multicast`             | Counts valid multicast packets received    |
| `stat_rx_broadcast`             | Counts valid broadcast packets received    |
| `stat_rx_vlan`                  | Counts good 802.1Q VLAN tagged packets    |
| `stat_rx_total_packets[1:0]`    | Counts total packets received, including good and bad    |
| `stat_rx_total_good_packets`    | Counts packets received without errors, fully completed    |
| `stat_rx_total_good_bytes[13:0]`| Counts bytes from fully received error-free packets    |
| `stat_rx_total_bytes[3:0]`      | Counts total bytes received, including errored packets    |
| `stat_rx_status`                | Indicates current status of the link    |
| `stat_rx_test_pattern_mismatch` | Counts mismatches in RX test pattern; active only when test pattern mode is enabled, pulses one clock cycle per mismatch    |
| `stat_rx_got_signal_os`         | Indicates reception of an unexpected Signal OS word; should not occur in Ethernet networks    |
| `stat_rx_valid_ctrl_code`       | Counts received control frames with valid control codes |
| `stat_rx_inrangeerr`            | Counts packets with length field errors but valid FCS |
| `stat_rx_toolong`               | Counts packets exceeding max length, including both good and bad FCS |

> 🔎 For more information, please consult the official documentation of the [10G/25G High Speed Ethernet Subsystem](https://docs.amd.com/r/en-US/pg210-25g-ethernet/AXI4-Stream-Control-and-Status-Ports).

#### TX Path (hw_vio_2)

##### VIO Outputs (Control Signals)

| Signal Name                       | Values                                  | Brief             |
|:---------------------------------:|:---------------------------------------:|:-----------------:|
| `ctl_tx_enable`                   | `'1' – Enable TX` <br>`'0' – Disable TX`| Enables or disables data transmission; idles are sent when disabled |
| `ctl_tx_ipg_value[3:0]`           | `Numeric Value`                         | Sets the minimum Inter-Packet Gap (IPG) between transmitted packets; valid range is 8–12 |
| `ctl_tx_send_idle`                | `'1' – Enable Idle` <br>`'0' – Disable Idle`| Forces TX to send only Idle code words; used when partner sends RFI |
| `ctl_tx_send_lfi`                 | `'1' – Enable LFI` <br>`'0' – Disable LFI` | Sends Local Fault Indication (LFI) code word; overrides RFI when asserted |
| `ctl_tx_send_rfi`                 | `'1' – Enable RFI` <br>`'0' – Disable RFI` | Transmits Remote Fault Indication (RFI) code words until the RX path is fully synchronized |
| `ctl_tx_custom_preamble_enable`   | `'1' – Custom Preamble` <br>`'0' – Default Preamble`| Enables use of a custom preamble via `tx_preamblein` instead of the standard one when asserted |
| `ctl_tx_test_pattern_enable`      | `'1' – Enable Test` <br>`'0' – Disable Test`  | Enables test pattern generation mode in the TX core; corresponds to MDIO bit 3.42.3 (Clause 45) |
| `ctl_tx_test_pattern`             | `Defined in Clause 45`       | Enables scrambled idle test-pattern generation in the TX core; corresponds to MDIO bit 3.42.7 (Clause 45), as per Clause 49 |
| `ctl_tx_test_pattern_select`      | `Defined in Clause 45`    | Selects the test pattern type for TX core; corresponds to MDIO bit 3.42.1 as defined in Clause 45 |
| `ctl_tx_test_pattern_seed_a[57:0]`| `Numeric Value`                                 | Defines the seed A value for TX test pattern generation; corresponds to MDIO registers 3.34 to 3.37 as per Clause 45 |
| `ctl_tx_test_pattern_seed_b[57:0]`| `Numeric Value`                                 | Defines the seed B value for TX test pattern generation; corresponds to MDIO registers 3.38 to 3.41 as per Clause 45 |
| `ctl_tx_data_pattern_select`      | `Defined in Clause 45`  | Defines the data pattern selection for TX test mode; corresponds to MDIO register bit 3.42.0 as specified in Clause 45 |
| `ctl_tx_fcs_ins_enable`           | `'1' – Automatic FCS` <br>`'0' – Manual FCS` | Controls whether the TX core appends a Frame Check Sequence (FCS) to outgoing packets; cannot change during transmission |
| `ctl_tx_ignore_fcs`               | `'1' – Ignore FCS` <br>`'0' – Check FCS` | Controls whether the TX core flags bad FCS packets when FCS insertion is disabled; affects how errors are reported and logged |

> 🔎 For more information, please consult the official documentation of the [10G/25G High Speed Ethernet Subsystem](https://docs.amd.com/r/en-US/pg210-25g-ethernet/AXI4-Stream-Control-and-Status-Ports).

##### VIO Inputs (Status Monitoring)

| Signal Name                          | Brief                                    |
|:------------------------------------:|:----------------------------------------:|
| `stat_tx_enable`                     | Enables or disables transmission statistics counting     |
| `stat_tx_bad_fcs`                    | Increments when transmitted packets over 64 bytes have FCS errors               |
| `stat_tx_frame_error`                | Increments for aborted frames due to `tx_axis_tuser` EOP or `tvalid` de-asserted without `tlast`.               |
| `stat_tx_local_fault`                | Indicates the TX encoder is currently in the TX_INIT initialization state             |
| `stat_tx_broadcast`                  | Increments when a valid broadcast packet is transmitted successfully               |
| `stat_tx_multicast`                  | Increments when a valid multicast packet is transmitted successfully               |
| `stat_tx_unicast`                    | Increments when a valid unicast packet is transmitted successfully               |
| `stat_tx_vlan`                       | Increments when a valid 802.1Q VLAN-tagged packet is transmitted successfully               |
| `stat_tx_packet_small`               | Increments when a transmitted packet is shorter than 64 bytes, including both valid and invalid frames               |
| `stat_tx_packet_large`               | Increments when a transmitted packet exceeds 9,215 bytes in length, regardless of validity               |
| `stat_tx_packet_64_bytes`            | Increments when a transmitted packet has exactly 64 bytes, whether it is good or bad               |
| `stat_tx_packet_65_127_bytes`        | Increments when a transmitted packet has between 65 and 127 bytes, regardless of errors               |
| `stat_tx_packet_128_255_bytes`       | Increments when a transmitted packet has between 128 and 255 bytes, including both good and bad packets               |
| `stat_tx_packet_256_511_bytes`       | Increments when a transmitted packet has between 256 and 511 bytes, regardless of whether it is good or bad               |
| `stat_tx_packet_512_1023_bytes`      | Increments when a transmitted packet has between 512 and 1,023 bytes, whether successful or not               |
| `stat_tx_packet_1024_1518_bytes`     | Increments when a transmitted packet has between 1,024 and 1,518 bytes, regardless of transmission success               |
| `stat_tx_packet_1519_1522_bytes`     | Increments when a transmitted packet has between 1,519 and 1,522 bytes, regardless of success or error               |
| `stat_tx_packet_1523_1548_bytes`     | Increments when a transmitted packet has between 1,523 and 1,548 bytes, whether successful or not               |
| `stat_tx_packet_1549_2047_bytes`     | Increments when a transmitted packet has between 1,549 and 2,047 bytes, regardless of transmission success               |
| `stat_tx_packet_2048_4095_bytes`     | Increments when a transmitted packet has between 2,048 and 4,095 bytes, whether successful or not               |
| `stat_tx_packet_4096_8191_bytes`     | Increments when a transmitted packet has between 4,096 and 8,191 bytes, regardless of transmission success               |
| `stat_tx_packet_8192_9215_bytes`     | Increments when a transmitted packet has between 8,192 and 9,215 bytes, regardless of whether it was transmitted successfully or not               |
| `stat_tx_total_packets`              | Counts all packets transmitted, including good and bad frames                                |
| `stat_tx_total_good_packets`         | Counts all successfully transmitted (error-free) packets                                |
| `stat_tx_total_bytes[3:0]`           | Counts all bytes transmitted, including both valid and invalid packets                                |
| `stat_tx_total_good_bytes[13:0]`     | Counts total bytes from completely transmitted, error-free packets.                                |

> 🔎 For more information, please consult the official documentation of the [10G/25G High Speed Ethernet Subsystem](https://docs.amd.com/r/en-US/pg210-25g-ethernet/AXI4-Stream-Control-and-Status-Ports).

### 1G Interface

#### RX Path (hw_vio_3)

##### VIO Outputs (Control Signals)

| Signal Name | Description | Values | Brief |
|:-----------:|:-----------:|:------:|:-----:|
| `rx_configuration_vector_1[0:0]` | *Receiver Reset*    | `'1' – Reset RX` <br>`'0' – Normal RX`                                      | Holds the MAC receiver in reset when set to 1 |
| `rx_configuration_vector_2[1:1]` | *Receiver Enable*    | `'1' – Enable RX` <br>`'0' – Disable RX`                                   | Enables or disables the MAC receiver |
| `rx_configuration_vector_3[2:2]` | *Receiver VLAN Enable*    | `'1' – Enable VLAN` <br>`'0' – Disable VLAN`                          | Allows reception of VLAN-tagged frames up to 1522 bytes |
| `rx_configuration_vector_4[3:3]` | *Receiver In-Band FCS Enable*    | `'1' – Keep CRC` <br>`'0' – Remove CRC`                   | Controls whether the FCS field is passed to the user; always verified |
| `rx_configuration_vector_5[4:4]` | *Receiver Jumbo Frame Enable*    | `'1' – Enable Jumbo Frame` <br>`'0' – Disable Jumbo Frame`     |  Allows reception of oversized frames when jumbo mode is enabled |
| `rx_configuration_vector_6[5:5]` | *Receiver Flow Control Enable*    | `'1' – Reject Control Frame` <br>`'0' – Accept Control Frame`    |  Enables handling of flow control frames to pause transmission |
| `rx_configuration_vector_7[6:6]` | *Receiver Half-Duplex*    | `'1' – Enable Half-Duplex` <br>`'0' – Enable Full-Duplex`            | Sets receiver mode to half or full duplex |
| `rx_configuration_vector_8[8:8]` | *Receiver length/Type Error Check Disable*    | `'1' – Disable Check` <br>`'0' – Enable Check`       | Disables length/type field error checking when set |
| `rx_configuration_vector_9[9:9]` | *Receiver Control Frame Length Check Disable*    | `'1' – Disable Check` <br>`'0' – Enable Check` | Disables length checks for control frames |
| `rx_configuration_vector_10[11:11]` | *Promiscuous Mode*    | `'1' – Accept All Frames` <br>`'0' – Filtered Reception`        |  Enables promiscuous mode; all frames are accepted |
| `rx_configuration_vector_11[13:12]` | *Receiver Speed Configuration*    | `'00' – 10 Mbps` <br>`'01' – 100 Mbps` <br>`'10' - 1 Gbps`    | Sets receiver speed: 10 Mbps, 100 Mbps, or 1 Gbps |
| `rx_configuration_vector_12[14:14]` | *Receiver Max Frame Enable*    | `'1' - Enable Max Frame` <br>`'0' - Disable Max Frame`   | Allows oversized frames if within the Max Frame Length and jumbo mode is disabled |
| `rx_configuration_vector_13[31:16]` | *Receiver Max Frame Size*    | `Numeric Value`                                   | Defines the max frame size when jumbo is disabled and Max Frame Enable is set |
| `rx_configuration_vector[79:32]` | *Receiver Pause Frame Source Address*    | `48-bit MAC address`                                   | MAC address used to match incoming pause frames when no management interface is present |

> 🔎 For more information, refer to the [rx_configuration_vector Bit Definitions](https://docs.amd.com/r/en-US/pg051-tri-mode-eth-mac/Configuration-Vector?tocId=D341j7Aq~kxJyzb8eARG~g#:~:text=the%20transmitter%20block.-,rx_configuration_vector%20Bit%20Definitions,-Bits) table in the official AMD documentation.

##### VIO Inputs (Status Monitoring)

| Signal Name | Description | Brief  |
|:-----------:|:-----------:|:------:|
| `rx_statistics_vector_hold_1[0:0]`    | *GOOD_FRAME*                  | Asserted if the previous received frame was successfully received without errors |
| `rx_statistics_vector_hold_2[1:1]`    | *BAD_FRAME*                   | Asserted if the previous received frame contained one or more errors |
| `rx_statistics_vector_hold_3[2:2]`    | *FCS_ERROR*                   | Asserted if the last received frame had correct alignment but failed FCS check or had code errors |
| `rx_statistics_vector_hold_4[3:3]`    | *BROADCAST_FRAME*             | Asserted if the previous frame had a broadcast destination address |
| `rx_statistics_vector_hold_5[4:4]`    | *MULTICAST_FRAME*             | Asserted if the previous frame had a multicast destination address |
| `rx_statistics_vector_hold_6[18:5]`   | *FRAME_LENGTH_COUNT*          | Reports the byte length of the previous frame; jumbo frames above 16368 are capped |
| `rx_statistics_vector_hold_7[19:19]`  | *CONTROL_FRAME*               | Asserted if the previous frame had a control frame identifier in the length/type field |
| `rx_statistics_vector_hold_8[20:20]`  | *OUT_OF_BOUNDS*               | Asserted if the previous frame exceeded the maximum allowed length and jumbo frames were not enabled |
| `rx_statistics_vector_hold_9[21:21]`  | *VLAN_FRAME*                  | Asserted if the previous frame had a VLAN tag in the length/type field while VLAN mode was active |
| `rx_statistics_vector_hold_10[22:22]` | *BYTE_VALID*                  | Asserted during reception of a MAC frame; not intended as a data enable signal |
| `rx_statistics_vector_hold_11[23:23]` | *FLOW_CONTROL_FRAME*          | Asserted if the last error-free frame was a valid pause frame with correct type, address, and opcode, and was processed by the MAC |
| `rx_statistics_vector_hold_12[24:24]` | *BAD_OPCODE*                  | Asserted if the last error-free frame was a control frame with an unsupported opcode (not PAUSE) |
| `rx_statistics_vector_hold_13[25:25]` | *LENGTH/TYPE Out of Range*    | Indicates a length/type field mismatch or insufficient frame padding |
| `rx_statistics_vector_hold_14[26:26]` | *ALIGNMENT_ERROR*             | Indicates FCS error on frames with odd nibble count at sub-1G speeds |
| `rx_statistics_vector_hold[27:27]`    | *ADDRESS_MATCH*               | Asserted if the frame matches a filtered address; held High if address filtering is disabled or promiscuous mode is active |

> 🔎 For more detailed information, refer to the [Bit Definition for the Receiver Statistics Vector table](https://docs.amd.com/r/en-US/pg051-tri-mode-eth-mac/Receiver-Interface#:~:text=Bit%20Definition%20for%20the%20Receiver%20Statistics%20Vector) in the official AMD documentation.

#### TX Path (hw_vio_4)

##### VIO Outputs (Control Signals)

| Signal Name | Description | Values | Brief |
|:-----------:|:-----------:|:------:|:-----:|
| `tx_configuration_vector_1[0:0]` | *Transmitter Reset*    | `'1' – Reset TX` <br>`'0' – Normal TX`                                      | Controls the reset state of the MAC transmitter |
| `tx_configuration_vector_2[1:1]` | *Transmitter Enable*    | `'1' – Enable TX` <br>`'0' – Disable TX`                                   | Enables or disables the MAC transmitter |
| `tx_configuration_vector_3[2:2]` | *Transmitter VLAN Enable*    | `'1' – Enable VLAN` <br>`'0' – Disable VLAN`                          | Enables VLAN-tagged frame transmission (up to 1522 bytes) |
| `tx_configuration_vector_4[3:3]` | *Transmitter In-Band FCS Enable*    | `'1' – Manual CRC` <br>`'0' – Automatic CRC`                   | Selects between user-supplied or automatically generated FCS |
| `tx_configuration_vector_5[4:4]` | *Transmitter Jumbo Frame Enable*    | `'1' – Enable Jumbo Frame` <br>`'0' – Disable Jumbo Frame`     |  Allows transmission of frames larger than IEEE 802.3 limits |
| `tx_configuration_vector_6[5:5]` | *Transmitter Flow Control Enable*    | `'1' – Enable Pause Frame` <br>`'0' – Disable Pause Frame`    |  Allows the MAC to transmit pause frames when `pause_req` is asserted |
| `tx_configuration_vector_7[6:6]` | *Transmitter Half-Duplex*    | `'1' – Enable Half-Duplex` <br>`'0' – Disable Half-Duplex`            | Selects half- or full-duplex mode for the transmitter |
| `tx_configuration_vector_8[8:8]` | *Transmitter Interframe Gap Adjust Enable*    | `'1' – Custom Delay` <br>`'0' – Minimum Delay`       | Enables custom interframe gap via `tx_ifg_delay` in full-duplex mode |
| `tx_configuration_vector_9[13:12]` | *Transmitter Speed Configuration*    | `'00' – 10 Mbps` <br>`'01' – 100 Mbps` <br>`'10' - 1 Gbps`  | Selects transmission speed: 10/100/1000 Mbps depending on bit value |
| `tx_configuration_vector_10[14:14]` | *Transmitter Max Frame Enable*    | `'1' – Enable Max Frame` <br>`'0' – Disable Max Frame`        |  Allows frames above IEEE 802.3 size limit if jumbo is disabled and size fits Max Frame Length |
| `tx_configuration_vector_11[31:16]` | *Transmitter Max Frame Size*    | `Numeric value`                                                 | Defines the maximum allowed frame size when jumbo is off and Max Frame Enable is active |
| `tx_configuration_vector[79:32]` | *Transmitter Pause Frame Source Address*    | `48-bit MAC address`                                   | Defines the source MAC address for transmitted pause frames |

> 🔎 For more detailed information, refer to the [tx_configuration_vector Bit Definitions table](https://docs.amd.com/r/en-US/pg051-tri-mode-eth-mac/Configuration-Vector?tocId=D341j7Aq~kxJyzb8eARG~g&section=grj1694001490603__table_sy1_mw1_myb) in the official AMD documentation.

##### VIO Inputs (Status Monitoring)

| Signal Name | Description | Brief  |
|:-----------:|:-----------:|:------:|
| `tx_statistics_vector_hold_1[0:0]`    | *SUCCESSFUL_FRAME*           | Asserted when the last frame was sent without error |
| `tx_statistics_vector_hold_2[1:1]`    | *BROADCAST_FRAME*            | Asserted if the previous frame had a broadcast destination address |
| `tx_statistics_vector_hold_3[2:2]`    | *MULTICAST_FRAME*            | Asserted if the previous frame had a multicast destination address |
| `tx_statistics_vector_hold_4[3:3]`    | *UNDERRUN_FRAME*             | Asserted when the last frame had an underrun error |
| `tx_statistics_vector_hold_5[4:4]`    | *CONTROL_FRAME*              | Asserted if the previous frame had type field 0x8808 (MAC control frame) |
| `tx_statistics_vector_hold_6[18:5]`   | *FRAME_LENGTH_COUNT*         | Indicates the previous frame length in bytes; capped at 16368 for jumbo frames |
| `tx_statistics_vector_hold_7[19:19]`  | *VLAN_FRAME*                 | Asserted if the previous frame had a VLAN tag when VLAN mode is enabled |
| `tx_statistics_vector_hold_8[20:20]`  | *TX_DEFERRED*                | Asserted when the previous frame experienced deferred transmission |
| `tx_statistics_vector_hold_9[21:21]`  | *EXCESSIVE_DEFERRAL*         | Asserted if the previous frame exceeded the `maxDeferTime` limit defined by IEEE 802.3 |
| `tx_statistics_vector_hold_10[22:22]` | *LATE_COLLISION*             | Asserted when a late collision is detected during frame transmission |
| `tx_statistics_vector_hold_11[23:23]` | *EXCESSIVE_COLLISION*        | Asserted if collisions were detected on all 16 attempts to transmit the previous frame |
| `tx_statistics_vector_hold_12[28:25]` | *TX_ATTEMPTS*                | Indicates the number of transmission attempts for the last frame (0 = 1 attempt, ..., 15 = 16) |
| `tx_statistics_vector_hold_13[30:30]` | *BYTE_VALID*                 | Indicates an entire MAC frame is being transmitted |
| `tx_statistics_vector_hold[31:31]`    | *PAUSE_FRAME_TRANSMITTED*    | Indicates the MAC transmitted a pause frame due to `pause_req` |

> 🔎 For more information, refer to the [Bit Definition for the Transmitter Statistics Vector](https://docs.amd.com/r/en-US/pg051-tri-mode-eth-mac/Transmitter-Interface#:~:text=Bit%20Definition%20for%20the%20Transmitter%20Statistics%20Vector) table in the official AMD documentation.

## 💾 Register Configuration

Many aspects of this project can be configured through registers — for example, the MAC and IP addresses. These configurations are managed via the UART interface using a specific command grammar:

| Operation | AXIS Slave Input        | AXI4-Lite Bus Request         | AXIS Master Output        |
|:---------:|:-----------------------:|:-----------------------------:|:-------------------------:|
| `Write`   | `W0AFD-CAFEDECA\r`      | Write `0xCAFEDECA` to `0x0AFD`| `W0AFD-CAFEDECA\r`        |
| `Read`    | `R0AFD`                 | Read from `0x0AFD`            | `R0AFD-CAFEDECA\r`        |

> Remarks:
> Only uppercase hexadecimal characters are supported.  
> Invalid characters are interpreted as `F`.  
> Short fields are automatically zero-padded, while long fields are truncated from the most significant bits (MSBs).

> ⚠️ The table above is just an example — no data is actually written at these addresses.

> ❗ If something goes wrong, you may receive either **no response** or `XXXXXXXX` in the data field. For more details, you can refer to the `bridge_ascii_to_axi4lite.vhd` file located in the `./src/vhdl` directory.

Since the system includes two Ethernet interfaces (1G and 10G), we define **four base addresses** in the register map: two for **main registers** and two for **test registers**, one pair per interface.

| Interface       |   Register Type   | Base Address |
|:---------------:|:-----------------:|:------------:|
| `10G - SFP0`    | **Main**          | `0x0000`     |
| `10G - SFP0`    | **Test**          | `0x2000`     |
| `1G - SFP1`     | **Main**          | `0x4000`     |
| `1G - SFP1`     | **Test**          | `0x6000`     |

> Each Ethernet core has a dedicated region in the address map for configuration and monitoring.  
> For more details about the register addresses, refer to the `uoe_registers.xlsm` file located in the `/udp-offload-engine/docs/` folder.

### 🐍 Python Configuration Script

If you don't want to spend time configuring the registers manually one by one, you can use a Python script to do it for you. You can modify the `config_registers.py` script to suit your needs.

``` bash
python3 config_registers.py
```

In general, the configuration provided in the file is sufficient for a first test. However, make sure to update the IP address to match your **local network settings**!

## 🔌 Physical Hardware Connections

After configuring all the registers, you can connect your FPGA to the network. Be aware that some equipment, such as routers or switches, may filter raw UDP frames. If you're performing a point-to-point test, make sure to use a crossover Ethernet cable and compatible equipment that supports either **1G** or **10G**, depending on the interface you intend to use.

To start the UDP frame generator on the 1G interface, send the following command via UART:
    
    W6000-00000004

To stop it, use:

    W6000-00000008

If you have Wireshark open, you should see something like this:

![wireshark](./images/wireshark.png)

You can also use other tools such as `socat` or `tcpdump` to monitor incoming frames.