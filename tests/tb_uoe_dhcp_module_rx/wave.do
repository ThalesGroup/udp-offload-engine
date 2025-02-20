onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /uoe_dhcp_module_rx/G_ACTIVE_RST
add wave -noupdate /uoe_dhcp_module_rx/G_ASYNC_RST
add wave -noupdate /uoe_dhcp_module_rx/G_TDATA_WIDTH
add wave -noupdate /uoe_dhcp_module_rx/CLK
add wave -noupdate /uoe_dhcp_module_rx/RST
add wave -noupdate /uoe_dhcp_module_rx/S_TDATA
add wave -noupdate /uoe_dhcp_module_rx/S_TVALID
add wave -noupdate /uoe_dhcp_module_rx/S_TLAST
add wave -noupdate /uoe_dhcp_module_rx/S_TKEEP
add wave -noupdate /uoe_dhcp_module_rx/S_TUSER
add wave -noupdate /uoe_dhcp_module_rx/S_TREADY
add wave -noupdate /uoe_dhcp_module_rx/rx_state
add wave -noupdate /uoe_dhcp_module_rx/mid
add wave -noupdate /uoe_dhcp_module_rx/mid_tready
add wave -noupdate /uoe_dhcp_module_rx/m_int
add wave -noupdate /uoe_dhcp_module_rx/m_int_tready
add wave -noupdate /uoe_dhcp_module_rx/cnt
add wave -noupdate /uoe_dhcp_module_rx/cnt_options
add wave -noupdate /uoe_dhcp_module_rx/opt_size
add wave -noupdate /uoe_dhcp_module_rx/frame_size
add wave -noupdate /uoe_dhcp_module_rx/xid
add wave -noupdate /uoe_dhcp_module_rx/yiaddr
add wave -noupdate /uoe_dhcp_module_rx/siaddr
add wave -noupdate /uoe_dhcp_module_rx/giaddr
add wave -noupdate /uoe_dhcp_module_rx/offer_sel
add wave -noupdate /uoe_dhcp_module_rx/dhcp_nack
add wave -noupdate /uoe_dhcp_module_rx/dhcp_ack
add wave -noupdate /uoe_dhcp_module_rx/lease_s
add wave -noupdate /uoe_dhcp_module_rx/netmask_s
add wave -noupdate /uoe_dhcp_module_rx/C_TKEEP_WIDTH
add wave -noupdate /uoe_dhcp_module_rx/C_DHCP_HEADER_SIZE
add wave -noupdate /uoe_dhcp_module_rx/C_HEADER_WORDS
add wave -noupdate /uoe_dhcp_module_rx/C_HEADER_REMAINDER
add wave -noupdate /uoe_dhcp_module_rx/DHCP_PORT_DEST
add wave -noupdate /uoe_dhcp_module_rx/DHCP_PORT_SRC
add wave -noupdate /uoe_dhcp_module_rx/CHADDR
add wave -noupdate /uoe_dhcp_module_rx/MAGIC
add wave -noupdate /uoe_dhcp_module_rx/C_FORWARD_DATA_INIT
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1 us}
