#This script packages the UOE core into a Vivado IP that can be easily integrated into Block Designs

set proj_name "udp_offload_engine_ip"
set ip_name "uoe_top"
set src_dir "../src"
set ip_xdc_dir "../examples/KCU105/constrs"
set out_dir "./ip_repo"

# Create project
create_project $proj_name ./$proj_name 

# Get project path
set proj_dir [get_property directory [current_project]]
############################################################################
# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# List of source code directory
set lib_list [list \
    "uoe_module" \
    "common" \
]

foreach lib $lib_list {
    # Get files list
    set files [glob -directory [file normalize $src_dir/$lib] *.vhd]

    # Add files
    add_files -norecurse -fileset $obj $files

    # Set Properties
    foreach f $files {
        set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$f"]]
        set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
        set_property -name "library" -value $lib -objects $file_obj
    }
}

#Vivado reports some warning regarding exporting an IP with an VHDL2008 top, 
#set top_uoe to VHDL just in case

set file_obj [get_files "top_uoe.vhd"]
if { $file_obj != "" } {
    set_property FILE_TYPE "VHDL" $file_obj
} else {
    # If not found, print an error message
    puts "ERROR: File  top_uoe.vhd not found in the project."
}

#Set top
set obj [get_filesets sources_1]
set_property -name "top" -value "top_uoe" -objects $obj

############################################################################
# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$ip_xdc_dir/cdc_bit_sync.xdc"]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file "cdc_bit_sync.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj
set_property -name "processing_order" -value "LATE" -objects $file_obj
set_property -name "scoped_to_ref" -value "cdc_bit_sync" -objects $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$ip_xdc_dir/cdc_gray_sync.xdc"]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file "cdc_gray_sync.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj
set_property -name "processing_order" -value "LATE" -objects $file_obj
set_property -name "scoped_to_ref" -value "cdc_gray_sync" -objects $file_obj
set_property -name "used_in" -value "implementation" -objects $file_obj

# Add/Import constrs file and set constrs file properties
set file "[file normalize "$ip_xdc_dir/cdc_reset_sync.xdc"]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file "cdc_reset_sync.xdc"
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj
set_property -name "processing_order" -value "LATE" -objects $file_obj
set_property -name "scoped_to_ref" -value "cdc_reset_sync" -objects $file_obj


############################################################################
#Package IP
ipx::package_project -root_dir $out_dir -vendor thales.org -library user -taxonomy /UserIP -import_files -force

#Set clocks
ipx::infer_bus_interface CLK_RX xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface CLK_TX xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface CLK_UOE xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]

#Set resets
ipx::infer_bus_interface RST_RX xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface RST_TX xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface RST_UOE xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

#Associate AXI Interfaces clocks
ipx::associate_bus_interfaces -busif S_AXI -clock CLK_UOE [ipx::current_core]
ipx::associate_bus_interfaces -busif S_UDP_TX -clock CLK_UOE [ipx::current_core]
ipx::associate_bus_interfaces -busif S_RAW_TX -clock CLK_UOE [ipx::current_core]
ipx::associate_bus_interfaces -busif S_EXT_TX -clock CLK_UOE [ipx::current_core]

ipx::associate_bus_interfaces -busif S_MAC_RX -clock CLK_RX [ipx::current_core]
ipx::associate_bus_interfaces -busif M_MAC_TX -clock CLK_TX [ipx::current_core]

ipx::associate_bus_interfaces -busif M_EXT_RX -clock CLK_UOE [ipx::current_core]
ipx::associate_bus_interfaces -busif M_RAW_RX -clock CLK_UOE [ipx::current_core]
ipx::associate_bus_interfaces -busif M_UDP_RX -clock CLK_UOE [ipx::current_core]

#properties
set_property core_revision 1 [ipx::current_core]
set_property name $ip_name [ipx::current_core]
set_property version 1.0 [ipx::current_core]
set_property display_name $ip_name [ipx::current_core]
set_property description "This IP is an UDP-IP stack accelerator and is able to send and receive data through Ethernet link." [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]


############################################################################

set absolute_path [file normalize $out_dir]
puts "=================================================================="
puts "SUCCESS: IP '$ip_name' packaged. Output directory $absolute_path."
puts "Add this path to the project IP repositories to use this IP."
puts "=================================================================="
