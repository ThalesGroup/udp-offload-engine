# ***UOE Module CocoTB Simulation***

*Presentation of the simulation tree structure and the python simulation environment. Simulation launch documentation is also available with the use of Makefile*

## **Tree structure**
___
<pre>
doc/  
examples/  
src/  
  └> common/
    └> files.vhd
    └> common.mk
  └> uoe_module/
    └> file.vhd
    └> uoe_module.mk
tests/
  └> lib/
    └> python_library.py
    └> modelsim.ini
  └> simulation_folder/
    └> workspace/
    └> testbanch.py
    └> Makefile
  └> install_python_venv.sh
  └> requirements.txt
</pre>

## **Virtual environment**
___
The install_python_venv.sh and requirements.txt files is necessary to installing correctly the virtual envrionment with python librarys. Indeed, for the PYTHPATH variable was correctly initalizing when the envrionment was launched, code lines are rewriting is launch file.  
\
To install the virutal envrionment, use this command in *tests/* folder :
> `./install_python.venv.sh`

To launch the virtual environment, use this command :  
>`source my_directory/projet_uoe_opensource/tests/.venv/bin/activate`  

To stop the virtual environment, use this command :  
>`desactivate`

More information on Development Envrionment : [https://docs.cocotb.org/en/stable/install_devel.html](https://docs.cocotb.org/en/stable/install_devel.html)

## **Makefile**
___
The Makefiles allow us to launch simulation with cocotb and to choose the simulator we want to use
### **Directory initialization**

First, It initializes the directory by creating workspace folder. This is where the files required for simulation and log files will be saving. Then, if the value of SIM variable is `questa`, it copies `modelsim.ini` from *lib/* folder into this directory to use the simulator.  

### **Simulation initalization**
To Initlize simulation, cocotb uses sevral variables:
 - COCOTB_HDL_TIMEUNIT = 1ns *(Simulation time unit)*
 - COCOTB_HDL_TIMEPRECISION = 1ps *(Time precision)*
 - COCOTB_REDUCED_LOG_FMT = 0 *(Logs reduction)*
 - COCOTB_LOG_LEVEL = DEBUG *(Fix Level in logs)*
 - COCOTB_RESULTS_FILE = workspace/results.xml *(Folder where result.xml is saving)*  

More information : [https://docs.cocotb.org/en/stable/building.html](https://docs.cocotb.org/en/stable/building.html)

### **VHDL Libraries**
To import VHDL libraries correctly, the Makefile uses `.mk` files. In the Makefile, they are called up with the code lines : 
> `-include $(PWD)/../../src/uoe_module/uoe_module.mk`  
> `-include $(PWD)/../../src/common/common.mk`  

### **Langage version**
Langage version is specified with **VCOM_ARGS** variable. Here, it is 2008 VHDL.  

More information : [https://www.microsemi.com/document-portal/doc_view/131617-modelsim-reference-manual](https://www.microsemi.com/document-portal/doc_view/131617-modelsim-reference-manual) Page 275


### **Simulator**

*- Questa*  
To use Questa simulator, put :
>`SIM = questa  `

The chronograms backup file is a `.do` file into *workspace/* folder.
le fichier de sauvegarde des chronogrammes est un fichier .do situé par defaut dans le fichier workspace.  
***/!\ When saving `.do` file in Questa, the default folder is simulation_folder/ folder, not workspace folder.***  

*- GHDL*  
To use GHDL simulator and GTKWave, put :
>`SIM = ghdl ` 

Here, the chronograms backup file is a `.gtkw` file.

More information : [https://docs.cocotb.org/en/stable/simulator_support.html](https://docs.cocotb.org/en/stable/simulator_support.html)  
For GHDL : [https://ghdl.github.io/ghdl/getting.html](https://ghdl.github.io/ghdl/getting.html)  
For GTKWave : [https://gtkwave.sourceforge.net/](https://gtkwave.sourceforge.net/)

### **Activate chronograms loading**
To active chronograms loading saved, put :
>`WAVE=1`

### **Run simulation**
To run simulation correctly , do :
>`make start`

This will allow Makefile to excute commands séquentially to simplify the simulation startup.
***/!\ Don't just do `make`, it won't clean caches properly and won't run GTKWave when GHDL is used.***

### **Terminal Information**
the information is displayed in blue in the terminal. If there is an error during execution of `make start`, it is displayed in red in the terminal.  
- The `make start` logs are available in *workspace/log_make* file.  
- Simulation logs are available in *workspace/log_sim* file.

## **Automatic verification system**
___
Simulations feature an automatic verification system. In fact, to check that what we receive is correct, we compare the data received with that expected and send an error message if there is one. Error messages are made up of all the parts of an Ethernet frame. For example, in the case of an IPV4 frame, in the event of an error, we display the mac header with the mac and ip address and the ethertype, then we display the ipv4 header with its various components.