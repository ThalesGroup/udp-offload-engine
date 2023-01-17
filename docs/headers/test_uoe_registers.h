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

#ifndef _TEST
#define _TEST


typedef struct {

  union {
    unsigned int regValue;
    struct {
      unsigned int loopback_mac_en : 1;
      unsigned int loopback_udp_en : 1;
      unsigned int gen_start : 1;
      unsigned int gen_stop : 1;
      unsigned int chk_start : 1;
      unsigned int chk_stop : 1;
      unsigned int padding6 : 26;

    } field;
  } reg_gen_chk_control;
  union {
    unsigned int regValue;
    struct {
      unsigned int gen_frame_size_type : 1;
      unsigned int padding1 : 16;
      unsigned int gen_frame_size_static : 16;
      unsigned int gen_rate_limitation : 8;

    } field;
  } reg_gen_config;
  union {
    unsigned int regValue;
    struct {
      unsigned int gen_nb_bytes_lsb : 32;

    } field;
  } reg_gen_nb_bytes_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int gen_nb_bytes_msb : 32;

    } field;
  } reg_gen_nb_bytes_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int gen_test_duration_lsb : 32;

    } field;
  } reg_gen_test_duration_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int gen_test_duration_msb : 32;

    } field;
  } reg_gen_test_duration_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_frame_size_type : 1;
      unsigned int padding1 : 16;
      unsigned int chk_frame_size_static : 16;
      unsigned int chk_rate_limitation : 8;

    } field;
  } reg_chk_config;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_nb_bytes_lsb : 32;

    } field;
  } reg_chk_nb_bytes_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_nb_bytes_msb : 32;

    } field;
  } reg_chk_nb_bytes_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_test_duration_lsb : 32;

    } field;
  } reg_chk_test_duration_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_test_duration_msb : 32;

    } field;
  } reg_chk_test_duration_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int lb_gen_dest_port : 16;
      unsigned int lb_gen_src_port : 16;

    } field;
  } reg_lb_gen_udp_port;
  union {
    unsigned int regValue;
    struct {
      unsigned int lb_gen_dest_ip_addr : 32;

    } field;
  } reg_lb_gen_dest_ip_addr;
  union {
    unsigned int regValue;
    struct {
      unsigned int chk_listening_port : 16;
      unsigned int padding1 : 16;

    } field;
  } reg_chk_udp_port;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_gen_done_status : 1;
      unsigned int irq_gen_err_timeout_status : 1;
      unsigned int irq_chk_done_status : 1;
      unsigned int irq_chk_err_frame_size_status : 1;
      unsigned int irq_chk_err_data_status : 1;
      unsigned int irq_chk_err_timeout_status : 1;
      unsigned int irq_rate_meter_tx_done_status : 1;
      unsigned int irq_rate_meter_tx_overflow_status : 1;
      unsigned int irq_rate_meter_rx_done_status : 1;
      unsigned int irq_rate_meter_rx_overflow_status : 1;
      unsigned int padding10 : 22;

    } field;
  } reg_interrupt_status;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_gen_done_enable : 1;
      unsigned int irq_gen_err_timeout_enable : 1;
      unsigned int irq_chk_done_enable : 1;
      unsigned int irq_chk_err_frame_size_enable : 1;
      unsigned int irq_chk_err_data_enable : 1;
      unsigned int irq_chk_err_timeout_enable : 1;
      unsigned int irq_rate_meter_tx_done_enable : 1;
      unsigned int irq_rate_meter_tx_overflow_enable : 1;
      unsigned int irq_rate_meter_rx_done_enable : 1;
      unsigned int irq_rate_meter_rx_overflow_enable : 1;
      unsigned int padding10 : 22;

    } field;
  } reg_interrupt_enable;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_gen_done_clear : 1;
      unsigned int irq_gen_err_timeout_clear : 1;
      unsigned int irq_chk_done_clear : 1;
      unsigned int irq_chk_err_frame_size_clear : 1;
      unsigned int irq_chk_err_data_clear : 1;
      unsigned int irq_chk_err_timeout_clear : 1;
      unsigned int irq_rate_meter_tx_done_clear : 1;
      unsigned int irq_rate_meter_tx_overflow_clear : 1;
      unsigned int irq_rate_meter_rx_done_clear : 1;
      unsigned int irq_rate_meter_rx_overflow_clear : 1;
      unsigned int padding10 : 22;

    } field;
  } reg_interrupt_clear;
  union {
    unsigned int regValue;
    struct {
      unsigned int irq_gen_done_set : 1;
      unsigned int irq_gen_err_timeout_set : 1;
      unsigned int irq_chk_done_set : 1;
      unsigned int irq_chk_err_frame_size_set : 1;
      unsigned int irq_chk_err_data_set : 1;
      unsigned int irq_chk_err_timeout_set : 1;
      unsigned int irq_rate_meter_tx_done_set : 1;
      unsigned int irq_rate_meter_tx_overflow_set : 1;
      unsigned int irq_rate_meter_rx_done_set : 1;
      unsigned int irq_rate_meter_rx_overflow_set : 1;
      unsigned int padding10 : 22;

    } field;
  } reg_interrupt_set;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_init_counter : 1;
      unsigned int padding1 : 31;

    } field;
  } reg_tx_rate_meter_ctrl;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_bytes_expt_lsb : 32;

    } field;
  } reg_tx_rm_bytes_expt_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_bytes_expt_msb : 32;

    } field;
  } reg_tx_rm_bytes_expt_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_cnt_bytes_lsb : 32;

    } field;
  } reg_tx_rm_cnt_bytes_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_cnt_bytes_msb : 32;

    } field;
  } reg_tx_rm_cnt_bytes_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_cnt_cycles_lsb : 32;

    } field;
  } reg_tx_rm_cnt_cycles_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int tx_rm_cnt_cycles_msb : 32;

    } field;
  } reg_tx_rm_cnt_cycles_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_init_counter : 1;
      unsigned int padding1 : 31;

    } field;
  } reg_rx_rate_meter_ctrl;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_bytes_expt_lsb : 32;

    } field;
  } reg_rx_fm_bytes_expt_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_bytes_expt_msb : 32;

    } field;
  } reg_rx_rm_bytes_expt_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_cnt_bytes_lsb : 32;

    } field;
  } reg_rx_rm_cnt_bytes_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_cnt_bytes_msb : 32;

    } field;
  } reg_rx_rm_cnt_bytes_msb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_cnt_cycles_lsb : 32;

    } field;
  } reg_rx_rm_cnt_cycles_lsb;
  union {
    unsigned int regValue;
    struct {
      unsigned int rx_rm_cnt_cycles_msb : 32;

    } field;
  } reg_rx_rm_cnt_cycles_msb;
} test_uoe_registers;

#endif
