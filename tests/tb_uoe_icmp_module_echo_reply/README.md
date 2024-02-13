# README for the PTECH polytech , about the icmp module

This readme is about the 2023-2024 Polytech Ptech, which was about the implementation of an ICMP module inside the internet layer. Below is the schematics of the module inside the IP.

![logo](docs/shcematics/internet_layer.png)

This project was realized by :

CANTIN Antoine
antoine.cantin@etu.univ-nantes.fr

GROSVALET--CHUPIN Alexandre
alexandre.grosvalet--chupin@etu.univ-nantes.fr

## Get Started

**************
ToC

	1. Setup/Installation
	2. Functionnal implementation
	3. Simulation
	
**********


<div id='Setup/Installation'/> 

## Setup/Installation

As the project was done from Polytech, acces to Thales software and tools was not possible. Hence a funcitonnal setup for development and simulation has to be realized first. 

The working setup was as described below : 

* Code development

For code development, usual editing tools such as Vivado vhdl editor, Notepad++, or nano from a terminal were used. Not particular constraint existed for this part.

* Simulation

For Simulation, the IP offers two main possible solutions : Questa and GHDL. Both solution were tested during the project in order to simulate the module, and it was seen that GHDL does not fully incorporate VHDL 2008, thus making it impossible to compile files such as the axis_utils_pkg.vhd.

This solution had to be left aside, and Questa had to be used, more precisely Questa* Intel FPAGE Starter Edition, version 23.1. In order to install it on a linux distribution (in our case ubuntu 20.04), multiple steps must be followed, resumed below :

	* Go to the [https://www.intel.com/content/www/us/en/software-kit/795215/questa-intel-fpgas-standard-edition-software-version-23-1.html](intel website) and download .run file.
	* Run the file (the file might have to be granted with executing rights, 'chmod +x'), and folllow the steps of the installer.
	* Once the software is installed, two elements must be sourced on your system :  the vsim executable path, and the licence for Questa starter
	* For the first, add to your PATH the the following directory : questa_installation_dir/23.1std/questa_fse/bin .
	* For the second, the license for Questa *starter* must be dowloaded from the [https://licensing.intel.com/psg/s/?language=en_US](Intel Self Service Licensing center), or SSLC. Once download, the folllowing envrionment variable must be setup : LM_LICENSE_FILE=/path/to/your/license/file.dat
	
After this process, the environment is well set and the other documentation files from this IP can be followed.
	
* Synthetization and hardware testing 

WiP, via vivado 2019.1.

## Functionnal implementation  (WIP, schematics have to be updated)

The architecture of the IP was imagined as shown on the figure below :

![logo](docs/shcematics/icmp_module.png)

In black are the component already implemented, related to the reponse to the reception of an Echo request. The Axi Interface deciphers on the go the header of the frame, then receives the payload entirely to verify its checksum in the Echo Frame Building. 
In case it is valid, it sends back the EchoFrame response via the Interface. In red are the compenents related to sending an Echo request to a specific IP address, and are not yet implemented.

A more detailed view of the Echo FrameBuidling block can be seen below :

![logo](docs/shcematics/icmp_module_echo_response.png)

The information aare stored inside an axi FIFO, and sent back along with the nex header containting the response once the checksum has been verified.


## Simulation

WiP
