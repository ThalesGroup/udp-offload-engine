/////////////////////////////////////////////////////////////////////////////////
///------------------------------------------------------------------------------
/// Company:    THALES Communications & Security France
///
/// Copyright  2022 - Cholet - THALES Communications & Security France
///
/// All rights especially the right for copying and distribution as
/// well as translation reserved.
/// No part of the product shall be reproduced or stored, processed
/// copied or distributed with electronic tools or by paper copy or
/// microfiche or any other process without written authorization of
/// THALES Communications & Security France
///------------------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////////////////

#ifndef _MAIN
#define _MAIN


typedef struct {

  union {
    unsigned int regValue;
    struct {
      unsigned int version : 8;
      unsigned int revision : 8;
      unsigned int debug : 16;

    } field;
  } reg_version;
  union {
    unsigned int regValue;
    struct {
      unsigned int local_mac_addr_lsb : 32;

    } field;
  } reg_local_mac_addr_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int local_mac_addr_msb : 16;
      unsigned int padding1 : 16;

    } field;
  } reg_local_mac_addr_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int local_ip_addr : 32;

    } field;
  } reg_local_ip_addr;
  union {
    unsigned int regValue;
    struct {
      unsigned int raw_dest_mac_addr_lsb : 32;

    } field;
  } reg_raw_dest_mac_addr_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int raw_dest_mac_addr_msb : 16;
      unsigned int padding1 : 16;

    } field;
  } reg_raw_dest_mac_addr_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int ttl : 8;
      unsigned int padding1 : 24;

    } field;
  } reg_ipv4_time_to_leave;
  union {
    unsigned int regValue;
    struct {
      unsigned int broadcast_filter_enable : 1;
      unsigned int ipv4_multicast_filter_enable : 1;
      unsigned int unicast_filter_enable : 1;
      unsigned int padding3 : 29;

    } field;
  } reg_filtering_control;
  union {
    unsigned int regValue;
    struct {
      unsigned int multicast_ip_addr_1 : 28;
      unsigned int multicast_ip_addr_1_enable : 1;
      unsigned int padding2 : 3;

    } field;
  } reg_ipv4_multicast_ip_addr_1;
  union {
    unsigned int regValue;
    struct {
      unsigned int multicast_ip_addr_2 : 28;
      unsigned int multicast_ip_addr_2_enable : 1;
      unsigned int padding2 : 3;

    } field;
  } reg_ipv4_multicast_ip_addr_2;
  union {
    unsigned int regValue;
    struct {
      unsigned int multicast_ip_addr_3 : 28;
      unsigned int multicast_ip_addr_3_enable : 1;
      unsigned int padding2 : 3;

    } field;
  } reg_ipv4_multicast_ip_addr_3;
  union {
    unsigned int regValue;
    struct {
      unsigned int multicast_ip_addr_4 : 28;
      unsigned int multicast_ip_addr_4_enable : 1;
      unsigned int padding2 : 3;

    } field;
  } reg_ipv4_multicast_ip_addr_4;
  union {
    unsigned int regValue;
    struct {
      unsigned int arp_timeout_ms : 12;
      unsigned int arp_tryings : 4;
      unsigned int arp_gratuitous_req : 1;
      unsigned int arp_rx_target_ip_filter : 2;
      unsigned int arp_rx_test_local_ip_conflict : 1;
      unsigned int arp_table_clear : 1;
      unsigned int padding6 : 11;

    } field;
  } reg_arp_configuration;
  union {
    unsigned int regValue;
    struct {
      unsigned int arp_sw_req_dest_ip_addr : 32;

    } field;
  } reg_arp_sw_req;
  union {
    unsigned int regValue;
    struct {
      unsigned int config_done : 1;
      unsigned int padding1 : 31;

    } field;
  } reg_config_done;  unsigned int padding15;

  union {
    unsigned int regValue;
    struct {
      unsigned int crc_filter_counter : 32;

    } field;
  } reg_monitoring_crc_filter;
  union {
    unsigned int regValue;
    struct {
      unsigned int mac_filter_counter : 32;

    } field;
  } reg_monitoring_mac_filter;
  union {
    unsigned int regValue;
    struct {
      unsigned int ext_drop_counter : 32;

    } field;
  } reg_monitoring_ext_drop;
  union {
    unsigned int regValue;
    struct {
      unsigned int raw_drop_counter : 32;

    } field;
  } reg_monitoring_raw_drop;
  union {
    unsigned int regValue;
    struct {
      unsigned int udp_drop_counter : 32;

    } field;
  } reg_monitoring_udp_drop;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_init_done_status : 1;
      unsigned int irq_arp_table_clear_done_status : 1;
      unsigned int irq_arp_ip_conflict_status : 1;
      unsigned int irq_arp_mac_conflict_status : 1;
      unsigned int irq_arp_error_status : 1;
      unsigned int irq_arp_rx_fifo_overflow_status : 1;
      unsigned int irq_router_data_rx_fifo_overflow_status : 1;
      unsigned int irq_router_crc_rx_fifo_overflow_status : 1;
      unsigned int irq_ipv4_rx_frag_offset_error_status : 1;
      unsigned int padding9 : 23;

    } field;
  } reg_interrupt_status;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_init_done_enable : 1;
      unsigned int irq_arp_table_clear_done_enable : 1;
      unsigned int irq_arp_ip_conflict_enable : 1;
      unsigned int irq_arp_mac_conflict_enable : 1;
      unsigned int irq_arp_error_enable : 1;
      unsigned int irq_arp_rx_fifo_overflow_enable : 1;
      unsigned int irq_router_data_rx_fifo_overflow_enable : 1;
      unsigned int irq_router_crc_rx_fifo_overflow_enable : 1;
      unsigned int irq_ipv4_rx_frag_offset_error_enable : 1;
      unsigned int padding9 : 23;

    } field;
  } reg_interrupt_enable;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_init_done_clear : 1;
      unsigned int irq_arp_table_clear_done_clear : 1;
      unsigned int irq_arp_ip_conflict_clear : 1;
      unsigned int irq_arp_mac_conflict_clear : 1;
      unsigned int irq_arp_error_clear : 1;
      unsigned int irq_arp_rx_fifo_overflow_clear : 1;
      unsigned int irq_router_data_rx_fifo_overflow_clear : 1;
      unsigned int irq_router_crc_rx_fifo_overflow_clear : 1;
      unsigned int irq_ipv4_rx_frag_offset_error_clear : 1;
      unsigned int padding9 : 23;

    } field;
  } reg_interrupt_clear;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_init_done_set : 1;
      unsigned int irq_arp_table_clear_done_set : 1;
      unsigned int irq_arp_ip_conflict_set : 1;
      unsigned int irq_arp_mac_conflict_set : 1;
      unsigned int irq_arp_error_set : 1;
      unsigned int irq_arp_rx_fifo_overflow_set : 1;
      unsigned int irq_router_data_rx_fifo_overflow_set : 1;
      unsigned int irq_router_crc_rx_fifo_overflow_set : 1;
      unsigned int irq_ipv4_rx_frag_offset_error_set : 1;
      unsigned int padding9 : 23;

    } field;
  } reg_interrupt_set;
} main_uoe_registers;

#endif
