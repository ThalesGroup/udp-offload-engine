-- Copyright (c) 2022-2024 THALES. All Rights Reserved
--
-- Licensed under the SolderPad Hardware License v 2.1 (the "License");
-- you may not use this file except in compliance with the License, or,
-- at your option. You may obtain a copy of the License at
--
-- https://solderpad.org/licenses/SHL-2.1/
--
-- Unless required by applicable law or agreed to in writing, any
-- work distributed under the License is distributed on an "AS IS"
-- BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
-- either express or implied. See the License for the specific
-- language governing permissions and limitations under the
-- License.
--
-- File subject to timestamp TSP22X5365 Thales, in the name of Thales SIX GTS France, made on 10/06/2022.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sfp_10g is
    generic(
        G_DEBUG : boolean := false
    );
    port(
        -- Clocks
        GT_REFCLK          : in  std_logic; -- GT Refclk @156.25 MHz
        CLK_100_MHZ        : in  std_logic; -- Free running clock

        -- Resets
        SYS_RST            : in  std_logic; -- Global async reset active high
        RX_RST             : in  std_logic; -- Reset of Rx part
        TX_RST             : in  std_logic; -- Reset of Tx part

        -- SFP
        SFP_TX_N           : out std_logic;
        SFP_TX_P           : out std_logic;
        SFP_RX_N           : in  std_logic;
        SFP_RX_P           : in  std_logic;
        -- Rx interface
        M_RX_ACLK          : out std_logic;
        M_RX_RST           : out std_logic;
        M_RX_TDATA         : out std_logic_vector(63 downto 0);
        M_RX_TKEEP         : out std_logic_vector(7 downto 0);
        M_RX_TVALID        : out std_logic;
        M_RX_TUSER         : out std_logic_vector(0 downto 0); -- 1 when frame has error
        M_RX_TLAST         : out std_logic;
        -- Pause
        --PAUSE_REQ          : in  std_logic;
        --PAUSE_VAL          : in  std_logic_vector(15 downto 0);
        -- TX interface
        S_TX_ACLK          : out std_logic;
        S_TX_RST           : out std_logic;
        S_TX_TDATA         : in  std_logic_vector(63 downto 0);
        S_TX_TKEEP         : in  std_logic_vector(7 downto 0);
        S_TX_TVALID        : in  std_logic;
        S_TX_TLAST         : in  std_logic;
        S_TX_TUSER         : in  std_logic_vector(0 downto 0); -- 1 when frame has an error
        S_TX_TREADY        : out std_logic;
        -- Control and status signals
        PHY_LAYER_READY    : out std_logic;
        STATUS_VECTOR_SFP  : out std_logic_vector(7 downto 0);
        -- DBG
        DBG_CLK_PHY_ACTIVE : out std_logic
    );
end sfp_10g;

architecture rtl of sfp_10g is

    component ethernet_subsystem_10g_ch1
        port(
            gt_rxp_in_0                      : in  std_logic;
            gt_rxn_in_0                      : in  std_logic;
            gt_txp_out_0                     : out std_logic;
            gt_txn_out_0                     : out std_logic;
            tx_clk_out_0                     : out std_logic;
            rx_core_clk_0                    : in  std_logic;
            rx_clk_out_0                     : out std_logic;
            gt_loopback_in_0                 : in  std_logic_vector(2 downto 0);
            rx_reset_0                       : in  std_logic;
            rxrecclkout_0                    : out std_logic;
            rx_axis_tvalid_0                 : out std_logic;
            rx_axis_tdata_0                  : out std_logic_vector(63 downto 0);
            rx_axis_tlast_0                  : out std_logic;
            rx_axis_tkeep_0                  : out std_logic_vector(7 downto 0);
            rx_axis_tuser_0                  : out std_logic;
            rx_preambleout_0                 : out std_logic_vector(55 downto 0);
            ctl_rx_test_pattern_0            : in  std_logic;
            ctl_rx_test_pattern_enable_0     : in  std_logic;
            ctl_rx_data_pattern_select_0     : in  std_logic;
            ctl_rx_enable_0                  : in  std_logic;
            ctl_rx_delete_fcs_0              : in  std_logic;
            ctl_rx_ignore_fcs_0              : in  std_logic;
            ctl_rx_max_packet_len_0          : in  std_logic_vector(14 downto 0);
            ctl_rx_min_packet_len_0          : in  std_logic_vector(7 downto 0);
            ctl_rx_custom_preamble_enable_0  : in  std_logic;
            ctl_rx_check_sfd_0               : in  std_logic;
            ctl_rx_check_preamble_0          : in  std_logic;
            ctl_rx_process_lfi_0             : in  std_logic;
            ctl_rx_force_resync_0            : in  std_logic;
            stat_rx_block_lock_0             : out std_logic;
            stat_rx_framing_err_valid_0      : out std_logic;
            stat_rx_framing_err_0            : out std_logic;
            stat_rx_hi_ber_0                 : out std_logic;
            stat_rx_valid_ctrl_code_0        : out std_logic;
            stat_rx_bad_code_0               : out std_logic;
            stat_rx_total_packets_0          : out std_logic_vector(1 downto 0);
            stat_rx_total_good_packets_0     : out std_logic;
            stat_rx_total_bytes_0            : out std_logic_vector(3 downto 0);
            stat_rx_total_good_bytes_0       : out std_logic_vector(13 downto 0);
            stat_rx_packet_small_0           : out std_logic;
            stat_rx_jabber_0                 : out std_logic;
            stat_rx_packet_large_0           : out std_logic;
            stat_rx_oversize_0               : out std_logic;
            stat_rx_undersize_0              : out std_logic;
            stat_rx_toolong_0                : out std_logic;
            stat_rx_fragment_0               : out std_logic;
            stat_rx_packet_64_bytes_0        : out std_logic;
            stat_rx_packet_65_127_bytes_0    : out std_logic;
            stat_rx_packet_128_255_bytes_0   : out std_logic;
            stat_rx_packet_256_511_bytes_0   : out std_logic;
            stat_rx_packet_512_1023_bytes_0  : out std_logic;
            stat_rx_packet_1024_1518_bytes_0 : out std_logic;
            stat_rx_packet_1519_1522_bytes_0 : out std_logic;
            stat_rx_packet_1523_1548_bytes_0 : out std_logic;
            stat_rx_bad_fcs_0                : out std_logic_vector(1 downto 0);
            stat_rx_packet_bad_fcs_0         : out std_logic;
            stat_rx_stomped_fcs_0            : out std_logic_vector(1 downto 0);
            stat_rx_packet_1549_2047_bytes_0 : out std_logic;
            stat_rx_packet_2048_4095_bytes_0 : out std_logic;
            stat_rx_packet_4096_8191_bytes_0 : out std_logic;
            stat_rx_packet_8192_9215_bytes_0 : out std_logic;
            stat_rx_unicast_0                : out std_logic;
            stat_rx_multicast_0              : out std_logic;
            stat_rx_broadcast_0              : out std_logic;
            stat_rx_vlan_0                   : out std_logic;
            stat_rx_inrangeerr_0             : out std_logic;
            stat_rx_bad_preamble_0           : out std_logic;
            stat_rx_bad_sfd_0                : out std_logic;
            stat_rx_got_signal_os_0          : out std_logic;
            stat_rx_test_pattern_mismatch_0  : out std_logic;
            stat_rx_truncated_0              : out std_logic;
            stat_rx_local_fault_0            : out std_logic;
            stat_rx_remote_fault_0           : out std_logic;
            stat_rx_internal_local_fault_0   : out std_logic;
            stat_rx_received_local_fault_0   : out std_logic;
            stat_rx_status_0                 : out std_logic;
            tx_reset_0                       : in  std_logic;
            tx_axis_tready_0                 : out std_logic;
            tx_axis_tvalid_0                 : in  std_logic;
            tx_axis_tdata_0                  : in  std_logic_vector(63 downto 0);
            tx_axis_tlast_0                  : in  std_logic;
            tx_axis_tkeep_0                  : in  std_logic_vector(7 downto 0);
            tx_axis_tuser_0                  : in  std_logic;
            tx_unfout_0                      : out std_logic;
            tx_preamblein_0                  : in  std_logic_vector(55 downto 0);
            ctl_tx_test_pattern_0            : in  std_logic;
            ctl_tx_test_pattern_enable_0     : in  std_logic;
            ctl_tx_test_pattern_select_0     : in  std_logic;
            ctl_tx_data_pattern_select_0     : in  std_logic;
            ctl_tx_test_pattern_seed_a_0     : in  std_logic_vector(57 downto 0);
            ctl_tx_test_pattern_seed_b_0     : in  std_logic_vector(57 downto 0);
            ctl_tx_enable_0                  : in  std_logic;
            ctl_tx_fcs_ins_enable_0          : in  std_logic;
            ctl_tx_ipg_value_0               : in  std_logic_vector(3 downto 0);
            ctl_tx_send_lfi_0                : in  std_logic;
            ctl_tx_send_rfi_0                : in  std_logic;
            ctl_tx_send_idle_0               : in  std_logic;
            ctl_tx_custom_preamble_enable_0  : in  std_logic;
            ctl_tx_ignore_fcs_0              : in  std_logic;
            stat_tx_total_packets_0          : out std_logic;
            stat_tx_total_bytes_0            : out std_logic_vector(3 downto 0);
            stat_tx_total_good_packets_0     : out std_logic;
            stat_tx_total_good_bytes_0       : out std_logic_vector(13 downto 0);
            stat_tx_packet_64_bytes_0        : out std_logic;
            stat_tx_packet_65_127_bytes_0    : out std_logic;
            stat_tx_packet_128_255_bytes_0   : out std_logic;
            stat_tx_packet_256_511_bytes_0   : out std_logic;
            stat_tx_packet_512_1023_bytes_0  : out std_logic;
            stat_tx_packet_1024_1518_bytes_0 : out std_logic;
            stat_tx_packet_1519_1522_bytes_0 : out std_logic;
            stat_tx_packet_1523_1548_bytes_0 : out std_logic;
            stat_tx_packet_small_0           : out std_logic;
            stat_tx_packet_large_0           : out std_logic;
            stat_tx_packet_1549_2047_bytes_0 : out std_logic;
            stat_tx_packet_2048_4095_bytes_0 : out std_logic;
            stat_tx_packet_4096_8191_bytes_0 : out std_logic;
            stat_tx_packet_8192_9215_bytes_0 : out std_logic;
            stat_tx_unicast_0                : out std_logic;
            stat_tx_multicast_0              : out std_logic;
            stat_tx_broadcast_0              : out std_logic;
            stat_tx_vlan_0                   : out std_logic;
            stat_tx_bad_fcs_0                : out std_logic;
            stat_tx_frame_error_0            : out std_logic;
            stat_tx_local_fault_0            : out std_logic;
            gtpowergood_out_0                : out std_logic;
            txoutclksel_in_0                 : in  std_logic_vector(2 downto 0);
            rxoutclksel_in_0                 : in  std_logic_vector(2 downto 0);
            rx_serdes_reset_0                : in  std_logic;
            gt_reset_all_in_0                : in  std_logic;
            gt_tx_reset_in_0                 : in  std_logic;
            gt_rx_reset_in_0                 : in  std_logic;
            gt_reset_tx_done_out_0           : out std_logic;
            gt_reset_rx_done_out_0           : out std_logic;
            qpll0clk_in                      : in  std_logic_vector(0 downto 0);
            qpll0refclk_in                   : in  std_logic_vector(0 downto 0);
            qpll1clk_in                      : in  std_logic_vector(0 downto 0);
            qpll1refclk_in                   : in  std_logic_vector(0 downto 0);
            gtwiz_reset_qpll0lock_in         : in  std_logic_vector(0 downto 0);
            gtwiz_reset_qpll1lock_in         : in  std_logic_vector(0 downto 0);
            gtwiz_reset_qpll0reset_out       : out std_logic_vector(0 downto 0);
            gtwiz_reset_qpll1reset_out       : out std_logic_vector(0 downto 0);
            sys_reset                        : in  std_logic;
            dclk                             : in  std_logic
        );
    end component ethernet_subsystem_10g_ch1;

    component sfp_10g_gt_common_wrapper
        port(
            refclk         : in  std_logic;
            qpll0reset     : in  std_logic_vector(0 downto 0);
            qpll0lock      : out std_logic_vector(0 downto 0);
            qpll0outclk    : out std_logic_vector(0 downto 0);
            qpll0outrefclk : out std_logic_vector(0 downto 0);
            qpll1reset     : in  std_logic_vector(0 downto 0);
            qpll1lock      : out std_logic_vector(0 downto 0);
            qpll1outclk    : out std_logic_vector(0 downto 0);
            qpll1outrefclk : out std_logic_vector(0 downto 0)
        );
    end component sfp_10g_gt_common_wrapper;

    component sfp_10g_reset_wrapper
        port(
            SYS_RESET                   : in  std_logic;
            GT_TXUSRCLK2                : in  std_logic;
            GT_RXUSRCLK2                : in  std_logic;
            RX_CORE_CLK                 : in  std_logic;
            GT_TX_RESET_IN              : in  std_logic;
            GT_RX_RESET_IN              : in  std_logic;
            TX_CORE_RESET_IN            : in  std_logic;
            RX_CORE_RESET_IN            : in  std_logic;
            TX_CORE_RESET_OUT           : out std_logic;
            RX_CORE_RESET_OUT           : out std_logic;
            RX_SERDES_RESET_OUT         : out std_logic;
            USR_TX_RESET                : out std_logic;
            USR_RX_RESET                : out std_logic;
            GTWIZ_RESET_ALL             : out std_logic;
            GTWIZ_RESET_TX_DATAPATH_OUT : out std_logic;
            GTWIZ_RESET_RX_DATAPATH_OUT : out std_logic
        );
    end component sfp_10g_reset_wrapper;

    -- Core resets
    signal rx_core_reset   : std_logic;
    signal tx_core_reset   : std_logic;
    signal rx_serdes_reset : std_logic;

    -- GT resets
    signal gtwiz_reset_all         : std_logic;
    signal gtwiz_reset_tx_datapath : std_logic;
    signal gtwiz_reset_rx_datapath : std_logic;
    signal gt_reset_tx_done        : std_logic;
    signal gt_reset_rx_done        : std_logic;

    -- control rx
    signal ctl_rx_test_pattern           : std_logic;
    signal ctl_rx_test_pattern_enable    : std_logic;
    signal ctl_rx_data_pattern_select    : std_logic;
    signal ctl_rx_enable                 : std_logic;
    signal ctl_rx_delete_fcs             : std_logic;
    signal ctl_rx_ignore_fcs             : std_logic;
    signal ctl_rx_max_packet_len         : std_logic_vector(14 downto 0);
    signal ctl_rx_min_packet_len         : std_logic_vector(7 downto 0);
    signal ctl_rx_custom_preamble_enable : std_logic;
    signal ctl_rx_check_sfd              : std_logic;
    signal ctl_rx_check_preamble         : std_logic;
    signal ctl_rx_process_lfi            : std_logic;
    signal ctl_rx_force_resync           : std_logic;

    -- control tx
    signal ctl_tx_test_pattern           : std_logic;
    signal ctl_tx_test_pattern_enable    : std_logic;
    signal ctl_tx_test_pattern_select    : std_logic;
    signal ctl_tx_data_pattern_select    : std_logic;
    signal ctl_tx_test_pattern_seed_a    : std_logic_vector(57 downto 0);
    signal ctl_tx_test_pattern_seed_b    : std_logic_vector(57 downto 0);
    signal ctl_tx_enable                 : std_logic;
    signal ctl_tx_fcs_ins_enable         : std_logic;
    signal ctl_tx_ipg_value              : std_logic_vector(3 downto 0);
    signal ctl_tx_send_lfi               : std_logic;
    signal ctl_tx_send_rfi               : std_logic;
    signal ctl_tx_send_idle              : std_logic;
    signal ctl_tx_custom_preamble_enable : std_logic;
    signal ctl_tx_ignore_fcs             : std_logic;

    -- GT Common qpll 
    signal qpll0clk    : STD_LOGIC_VECTOR(0 downto 0);
    signal qpll0reset  : std_logic_vector(0 downto 0);
    signal qpll0refclk : STD_LOGIC_VECTOR(0 downto 0);
    signal qpll0lock   : std_logic_vector(0 downto 0);
    signal qpll1clk    : STD_LOGIC_VECTOR(0 downto 0);
    signal qpll1reset  : STD_LOGIC_VECTOR(0 downto 0);
    signal qpll1refclk : STD_LOGIC_VECTOR(0 downto 0);
    signal qpll1lock   : std_logic_vector(0 downto 0);

    -- Stat Rx
    signal stat_rx_block_lock             : std_logic;
    signal stat_rx_framing_err_valid      : std_logic;
    signal stat_rx_framing_err            : std_logic;
    signal stat_rx_hi_ber                 : std_logic;
    signal stat_rx_valid_ctrl_code        : std_logic;
    signal stat_rx_bad_code               : std_logic;
    signal stat_rx_total_packets          : std_logic_vector(1 downto 0);
    signal stat_rx_total_good_packets     : std_logic;
    signal stat_rx_total_bytes            : std_logic_vector(3 downto 0);
    signal stat_rx_total_good_bytes       : std_logic_vector(13 downto 0);
    signal stat_rx_packet_small           : std_logic;
    signal stat_rx_jabber                 : std_logic;
    signal stat_rx_packet_large           : std_logic;
    signal stat_rx_oversize               : std_logic;
    signal stat_rx_undersize              : std_logic;
    signal stat_rx_toolong                : std_logic;
    signal stat_rx_fragment               : std_logic;
    signal stat_rx_packet_64_bytes        : std_logic;
    signal stat_rx_packet_65_127_bytes    : std_logic;
    signal stat_rx_packet_128_255_bytes   : std_logic;
    signal stat_rx_packet_256_511_bytes   : std_logic;
    signal stat_rx_packet_512_1023_bytes  : std_logic;
    signal stat_rx_packet_1024_1518_bytes : std_logic;
    signal stat_rx_packet_1519_1522_bytes : std_logic;
    signal stat_rx_packet_1523_1548_bytes : std_logic;
    signal stat_rx_bad_fcs                : std_logic_vector(1 downto 0);
    signal stat_rx_packet_bad_fcs         : std_logic;
    signal stat_rx_stomped_fcs            : std_logic_vector(1 downto 0);
    signal stat_rx_packet_1549_2047_bytes : std_logic;
    signal stat_rx_packet_2048_4095_bytes : std_logic;
    signal stat_rx_packet_4096_8191_bytes : std_logic;
    signal stat_rx_packet_8192_9215_bytes : std_logic;
    signal stat_rx_unicast                : std_logic;
    signal stat_rx_multicast              : std_logic;
    signal stat_rx_broadcast              : std_logic;
    signal stat_rx_vlan                   : std_logic;
    signal stat_rx_inrangeerr             : std_logic;
    signal stat_rx_bad_preamble           : std_logic;
    signal stat_rx_bad_sfd                : std_logic;
    signal stat_rx_got_signal_os          : std_logic;
    signal stat_rx_test_pattern_mismatch  : std_logic;
    signal stat_rx_truncated              : std_logic;
    signal stat_rx_local_fault            : std_logic;
    signal stat_rx_remote_fault           : std_logic;
    signal stat_rx_internal_local_fault   : std_logic;
    signal stat_rx_received_local_fault   : std_logic;
    signal stat_rx_status                 : std_logic;

    -- Stat Tx
    signal stat_tx_total_packets          : std_logic;
    signal stat_tx_total_bytes            : std_logic_vector(3 downto 0);
    signal stat_tx_total_good_packets     : std_logic;
    signal stat_tx_total_good_bytes       : std_logic_vector(13 downto 0);
    signal stat_tx_packet_64_bytes        : std_logic;
    signal stat_tx_packet_65_127_bytes    : std_logic;
    signal stat_tx_packet_128_255_bytes   : std_logic;
    signal stat_tx_packet_256_511_bytes   : std_logic;
    signal stat_tx_packet_512_1023_bytes  : std_logic;
    signal stat_tx_packet_1024_1518_bytes : std_logic;
    signal stat_tx_packet_1519_1522_bytes : std_logic;
    signal stat_tx_packet_1523_1548_bytes : std_logic;
    signal stat_tx_packet_small           : std_logic;
    signal stat_tx_packet_large           : std_logic;
    signal stat_tx_packet_1549_2047_bytes : std_logic;
    signal stat_tx_packet_2048_4095_bytes : std_logic;
    signal stat_tx_packet_4096_8191_bytes : std_logic;
    signal stat_tx_packet_8192_9215_bytes : std_logic;
    signal stat_tx_unicast                : std_logic;
    signal stat_tx_multicast              : std_logic;
    signal stat_tx_broadcast              : std_logic;
    signal stat_tx_vlan                   : std_logic;
    signal stat_tx_bad_fcs                : std_logic;
    signal stat_tx_frame_error            : std_logic;
    signal stat_tx_local_fault            : std_logic;
    signal tx_underflow                   : std_logic;

    --For debug
    constant C_FREQ_CLK_PHY : integer := 156250000;
    signal cnt_clk_phy      : integer range 0 to C_FREQ_CLK_PHY - 1;
begin

    ---------------------------------------------------------------------------------------------------
    --      Rx configuration
    ---------------------------------------------------------------------------------------------------
    GEN_RX_DEFAULT_CFG : if not G_DEBUG generate
        ctl_rx_test_pattern           <= '0'; -- Test pattern enable for the RX core to receive scrambled idle pattern.
        ctl_rx_test_pattern_enable    <= '0'; -- Test pattern enable for the RX core. A value of 1 enables test mode.
        ctl_rx_data_pattern_select    <= '0'; -- Corresponds to MDIO register bit 3.42.0 as defined in Clause 45.
        ctl_rx_enable                 <= '1'; -- Rx enable
        ctl_rx_delete_fcs             <= '1'; -- Enable FCS removal by the RX core.
        ctl_rx_ignore_fcs             <= '0'; -- Disable FCS error checking at the AXI4-Stream interface by the RX core.
        ctl_rx_max_packet_len         <= "0" & std_logic_vector(to_unsigned(9600, 14)); -- Any packet longer than this value is considered to be oversized
        ctl_rx_min_packet_len         <= std_logic_vector(to_unsigned(64, 8)); -- Any packet shorter than this value is considered to be undersized
        ctl_rx_custom_preamble_enable <= '0'; -- Causes the side band of a packet presented on the AXI4-Stream to be the preamble as it appears on the line.
        ctl_rx_check_sfd              <= '1'; -- Causes the MAC to check the Start of Frame Delimiter of the received frame
        ctl_rx_check_preamble         <= '1'; -- Causes the MAC to check the preamble of the received frame
        ctl_rx_process_lfi            <= '0'; -- The RX core expects and processes LF control codes coming in from the transceiver
        ctl_rx_force_resync           <= '0'; -- This signal is used to force the RX path to reset and re-synchronize.
    end generate GEN_RX_DEFAULT_CFG;

    GEN_RX_VIO_CFG : if G_DEBUG generate
        component vio_rx_10G_cfg
            port(
                clk         : in  std_logic;
                probe_in0   : in  std_logic_vector(0 downto 0);
                probe_in1   : in  std_logic_vector(0 downto 0);
                probe_in2   : in  std_logic_vector(0 downto 0);
                probe_in3   : in  std_logic_vector(0 downto 0);
                probe_in4   : in  std_logic_vector(0 downto 0);
                probe_in5   : in  std_logic_vector(0 downto 0);
                probe_in6   : in  std_logic_vector(1 downto 0);
                probe_in7   : in  std_logic_vector(0 downto 0);
                probe_in8   : in  std_logic_vector(3 downto 0);
                probe_in9   : in  std_logic_vector(13 downto 0);
                probe_in10  : in  std_logic_vector(0 downto 0);
                probe_in11  : in  std_logic_vector(0 downto 0);
                probe_in12  : in  std_logic_vector(0 downto 0);
                probe_in13  : in  std_logic_vector(0 downto 0);
                probe_in14  : in  std_logic_vector(0 downto 0);
                probe_in15  : in  std_logic_vector(0 downto 0);
                probe_in16  : in  std_logic_vector(0 downto 0);
                probe_in17  : in  std_logic_vector(0 downto 0);
                probe_in18  : in  std_logic_vector(0 downto 0);
                probe_in19  : in  std_logic_vector(0 downto 0);
                probe_in20  : in  std_logic_vector(0 downto 0);
                probe_in21  : in  std_logic_vector(0 downto 0);
                probe_in22  : in  std_logic_vector(0 downto 0);
                probe_in23  : in  std_logic_vector(0 downto 0);
                probe_in24  : in  std_logic_vector(0 downto 0);
                probe_in25  : in  std_logic_vector(1 downto 0);
                probe_in26  : in  std_logic_vector(0 downto 0);
                probe_in27  : in  std_logic_vector(1 downto 0);
                probe_in28  : in  std_logic_vector(0 downto 0);
                probe_in29  : in  std_logic_vector(0 downto 0);
                probe_in30  : in  std_logic_vector(0 downto 0);
                probe_in31  : in  std_logic_vector(0 downto 0);
                probe_in32  : in  std_logic_vector(0 downto 0);
                probe_in33  : in  std_logic_vector(0 downto 0);
                probe_in34  : in  std_logic_vector(0 downto 0);
                probe_in35  : in  std_logic_vector(0 downto 0);
                probe_in36  : in  std_logic_vector(0 downto 0);
                probe_in37  : in  std_logic_vector(0 downto 0);
                probe_in38  : in  std_logic_vector(0 downto 0);
                probe_in39  : in  std_logic_vector(0 downto 0);
                probe_in40  : in  std_logic_vector(0 downto 0);
                probe_in41  : in  std_logic_vector(0 downto 0);
                probe_in42  : in  std_logic_vector(0 downto 0);
                probe_in43  : in  std_logic_vector(0 downto 0);
                probe_in44  : in  std_logic_vector(0 downto 0);
                probe_in45  : in  std_logic_vector(0 downto 0);
                probe_in46  : in  std_logic_vector(0 downto 0);
                probe_out0  : out std_logic_vector(0 downto 0);
                probe_out1  : out std_logic_vector(0 downto 0);
                probe_out2  : out std_logic_vector(0 downto 0);
                probe_out3  : out std_logic_vector(0 downto 0);
                probe_out4  : out std_logic_vector(0 downto 0);
                probe_out5  : out std_logic_vector(0 downto 0);
                probe_out6  : out std_logic_vector(13 downto 0);
                probe_out7  : out std_logic_vector(7 downto 0);
                probe_out8  : out std_logic_vector(0 downto 0);
                probe_out9  : out std_logic_vector(0 downto 0);
                probe_out10 : out std_logic_vector(0 downto 0);
                probe_out11 : out std_logic_vector(0 downto 0);
                probe_out12 : out std_logic_vector(0 downto 0)
            );
        end component vio_rx_10G_cfg;

    begin
        inst_vio_rx_10G_cfg : vio_rx_10G_cfg
            port map(
                clk            => M_RX_ACLK,
                probe_in0(0)   => stat_rx_block_lock,
                probe_in1(0)   => stat_rx_framing_err_valid,
                probe_in2(0)   => stat_rx_framing_err,
                probe_in3(0)   => stat_rx_hi_ber,
                probe_in4(0)   => stat_rx_valid_ctrl_code,
                probe_in5(0)   => stat_rx_bad_code,
                probe_in6      => stat_rx_total_packets,
                probe_in7(0)   => stat_rx_total_good_packets,
                probe_in8      => stat_rx_total_bytes,
                probe_in9      => stat_rx_total_good_bytes,
                probe_in10(0)  => stat_rx_packet_small,
                probe_in11(0)  => stat_rx_jabber,
                probe_in12(0)  => stat_rx_packet_large,
                probe_in13(0)  => stat_rx_oversize,
                probe_in14(0)  => stat_rx_undersize,
                probe_in15(0)  => stat_rx_toolong,
                probe_in16(0)  => stat_rx_fragment,
                probe_in17(0)  => stat_rx_packet_64_bytes,
                probe_in18(0)  => stat_rx_packet_65_127_bytes,
                probe_in19(0)  => stat_rx_packet_128_255_bytes,
                probe_in20(0)  => stat_rx_packet_256_511_bytes,
                probe_in21(0)  => stat_rx_packet_512_1023_bytes,
                probe_in22(0)  => stat_rx_packet_1024_1518_bytes,
                probe_in23(0)  => stat_rx_packet_1519_1522_bytes,
                probe_in24(0)  => stat_rx_packet_1523_1548_bytes,
                probe_in25     => stat_rx_bad_fcs,
                probe_in26(0)  => stat_rx_packet_bad_fcs,
                probe_in27     => stat_rx_stomped_fcs,
                probe_in28(0)  => stat_rx_packet_1549_2047_bytes,
                probe_in29(0)  => stat_rx_packet_2048_4095_bytes,
                probe_in30(0)  => stat_rx_packet_4096_8191_bytes,
                probe_in31(0)  => stat_rx_packet_8192_9215_bytes,
                probe_in32(0)  => stat_rx_unicast,
                probe_in33(0)  => stat_rx_multicast,
                probe_in34(0)  => stat_rx_broadcast,
                probe_in35(0)  => stat_rx_vlan,
                probe_in36(0)  => stat_rx_inrangeerr,
                probe_in37(0)  => stat_rx_bad_preamble,
                probe_in38(0)  => stat_rx_bad_sfd,
                probe_in39(0)  => stat_rx_got_signal_os,
                probe_in40(0)  => stat_rx_test_pattern_mismatch,
                probe_in41(0)  => stat_rx_truncated,
                probe_in42(0)  => stat_rx_local_fault,
                probe_in43(0)  => stat_rx_remote_fault,
                probe_in44(0)  => stat_rx_internal_local_fault,
                probe_in45(0)  => stat_rx_received_local_fault,
                probe_in46(0)  => stat_rx_status,
                probe_out0(0)  => ctl_rx_test_pattern,
                probe_out1(0)  => ctl_rx_test_pattern_enable,
                probe_out2(0)  => ctl_rx_data_pattern_select,
                probe_out3(0)  => ctl_rx_enable,
                probe_out4(0)  => ctl_rx_delete_fcs,
                probe_out5(0)  => ctl_rx_ignore_fcs,
                probe_out6     => ctl_rx_max_packet_len(13 downto 0),
                probe_out7     => ctl_rx_min_packet_len,
                probe_out8(0)  => ctl_rx_custom_preamble_enable,
                probe_out9(0)  => ctl_rx_check_sfd,
                probe_out10(0) => ctl_rx_check_preamble,
                probe_out11(0) => ctl_rx_process_lfi,
                probe_out12(0) => ctl_rx_force_resync
            );

        ctl_rx_max_packet_len(14) <= '0';
    end generate GEN_RX_VIO_CFG;

    ---------------------------------------------------------------------------------------------------
    --      Tx configuration
    ---------------------------------------------------------------------------------------------------
    GEN_TX_DEFAULT_CFG : if not G_DEBUG generate
        ctl_tx_test_pattern           <= '0'; -- Scrambled idle Test pattern generation enable for the TX core
        ctl_tx_test_pattern_enable    <= '0'; -- Test pattern generation enable for the TX core.
        ctl_tx_test_pattern_select    <= '0'; -- Corresponds to MDIO register bit 3.42.1 as defined in Clause 45.
        ctl_tx_data_pattern_select    <= '0'; -- Corresponds to MDIO register bit 3.42.0 as defined in Clause 45.
        ctl_tx_test_pattern_seed_a    <= 58x"0"; -- Corresponds to MDIO registers 3.34 through to 3.37 as defined in Clause 45.
        ctl_tx_test_pattern_seed_b    <= 58x"1"; -- Corresponds to MDIO registers 3.38 through to 3.41 as defined in Clause 45
        ctl_tx_enable                 <= '1'; -- Tx Enable. Must be set to '1' when receiver is ready
        ctl_tx_fcs_ins_enable         <= '1'; -- Enable FCS insertion by the TX core
        ctl_tx_ipg_value              <= std_logic_vector(to_unsigned(8, 4)); -- target average minimum Inter Packet Gap (IPG, in bytes) inserted between AXI4-Stream packets
        ctl_tx_send_lfi               <= '0'; -- Transmit Local Fault Indication (LFI) code word.
        ctl_tx_send_rfi               <= '0'; -- Transmit Remote Fault Indication (RFI) code word. If this input is sampled as a 1, the TX path only transmits Remote Fault code words. This
        ctl_tx_send_idle              <= '0'; -- Transmit Idle code words
        ctl_tx_custom_preamble_enable <= '0'; -- Enables the use of tx_preamblein as a custom preamble instead of inserting a standard preamble.
        ctl_tx_ignore_fcs             <= '0'; -- Enable FCS error checking at the AXI4-Stream interface by the TX core.

    end generate GEN_TX_DEFAULT_CFG;

    GEN_TX_VIO_CFG : if G_DEBUG generate
        component vio_tx_10G_cfg
            port(
                clk         : in  std_logic;
                probe_in0   : in  std_logic_vector(0 downto 0);
                probe_in1   : in  std_logic_vector(3 downto 0);
                probe_in2   : in  std_logic_vector(0 downto 0);
                probe_in3   : in  std_logic_vector(13 downto 0);
                probe_in4   : in  std_logic_vector(0 downto 0);
                probe_in5   : in  std_logic_vector(0 downto 0);
                probe_in6   : in  std_logic_vector(0 downto 0);
                probe_in7   : in  std_logic_vector(0 downto 0);
                probe_in8   : in  std_logic_vector(0 downto 0);
                probe_in9   : in  std_logic_vector(0 downto 0);
                probe_in10  : in  std_logic_vector(0 downto 0);
                probe_in11  : in  std_logic_vector(0 downto 0);
                probe_in12  : in  std_logic_vector(0 downto 0);
                probe_in13  : in  std_logic_vector(0 downto 0);
                probe_in14  : in  std_logic_vector(0 downto 0);
                probe_in15  : in  std_logic_vector(0 downto 0);
                probe_in16  : in  std_logic_vector(0 downto 0);
                probe_in17  : in  std_logic_vector(0 downto 0);
                probe_in18  : in  std_logic_vector(0 downto 0);
                probe_in19  : in  std_logic_vector(0 downto 0);
                probe_in20  : in  std_logic_vector(0 downto 0);
                probe_in21  : in  std_logic_vector(0 downto 0);
                probe_in22  : in  std_logic_vector(0 downto 0);
                probe_in23  : in  std_logic_vector(0 downto 0);
                probe_in24  : in  std_logic_vector(0 downto 0);
                probe_out0  : out std_logic_vector(0 downto 0);
                probe_out1  : out std_logic_vector(0 downto 0);
                probe_out2  : out std_logic_vector(0 downto 0);
                probe_out3  : out std_logic_vector(0 downto 0);
                probe_out4  : out std_logic_vector(57 downto 0);
                probe_out5  : out std_logic_vector(57 downto 0);
                probe_out6  : out std_logic_vector(0 downto 0);
                probe_out7  : out std_logic_vector(0 downto 0);
                probe_out8  : out std_logic_vector(3 downto 0);
                probe_out9  : out std_logic_vector(0 downto 0);
                probe_out10 : out std_logic_vector(0 downto 0);
                probe_out11 : out std_logic_vector(0 downto 0);
                probe_out12 : out std_logic_vector(0 downto 0);
                probe_out13 : out std_logic_vector(0 downto 0)
            );
        end component vio_tx_10G_cfg;

    begin
        inst_vio_tx_10G_cfg : vio_tx_10G_cfg
            port map(
                clk            => S_TX_ACLK,
                probe_in0(0)   => stat_tx_total_packets,
                probe_in1      => stat_tx_total_bytes,
                probe_in2(0)   => stat_tx_total_good_packets,
                probe_in3      => stat_tx_total_good_bytes,
                probe_in4(0)   => stat_tx_packet_64_bytes,
                probe_in5(0)   => stat_tx_packet_65_127_bytes,
                probe_in6(0)   => stat_tx_packet_128_255_bytes,
                probe_in7(0)   => stat_tx_packet_256_511_bytes,
                probe_in8(0)   => stat_tx_packet_512_1023_bytes,
                probe_in9(0)   => stat_tx_packet_1024_1518_bytes,
                probe_in10(0)  => stat_tx_packet_1519_1522_bytes,
                probe_in11(0)  => stat_tx_packet_1523_1548_bytes,
                probe_in12(0)  => stat_tx_packet_small,
                probe_in13(0)  => stat_tx_packet_large,
                probe_in14(0)  => stat_tx_packet_1549_2047_bytes,
                probe_in15(0)  => stat_tx_packet_2048_4095_bytes,
                probe_in16(0)  => stat_tx_packet_4096_8191_bytes,
                probe_in17(0)  => stat_tx_packet_8192_9215_bytes,
                probe_in18(0)  => stat_tx_unicast,
                probe_in19(0)  => stat_tx_multicast,
                probe_in20(0)  => stat_tx_broadcast,
                probe_in21(0)  => stat_tx_vlan,
                probe_in22(0)  => stat_tx_bad_fcs,
                probe_in23(0)  => stat_tx_frame_error,
                probe_in24(0)  => stat_tx_local_fault,
                probe_out0(0)  => ctl_tx_test_pattern,
                probe_out1(0)  => ctl_tx_test_pattern_enable,
                probe_out2(0)  => ctl_tx_test_pattern_select,
                probe_out3(0)  => ctl_tx_data_pattern_select,
                probe_out4     => ctl_tx_test_pattern_seed_a,
                probe_out5     => ctl_tx_test_pattern_seed_b,
                probe_out6(0)  => ctl_tx_enable,
                probe_out7(0)  => ctl_tx_fcs_ins_enable,
                probe_out8     => ctl_tx_ipg_value,
                probe_out9(0)  => ctl_tx_send_lfi,
                probe_out10(0) => ctl_tx_send_rfi,
                probe_out11(0) => ctl_tx_send_idle,
                probe_out12(0) => ctl_tx_custom_preamble_enable,
                probe_out13(0) => ctl_tx_ignore_fcs
            );

    end generate GEN_TX_VIO_CFG;
    ---------------------------------------------------------------------------------------------------
    --      GT Common wrapper
    ---------------------------------------------------------------------------------------------------
    inst_sfp_10g_gt_common_wrapper : sfp_10g_gt_common_wrapper
        port map(
            refclk         => GT_REFCLK,
            qpll0reset     => qpll0reset,
            qpll0lock      => qpll0lock,
            qpll0outclk    => qpll0clk,
            qpll0outrefclk => qpll0refclk,
            qpll1reset     => qpll1reset,
            qpll1lock      => qpll1lock,
            qpll1outclk    => qpll1clk,
            qpll1outrefclk => qpll1refclk
        );

    ---------------------------------------------------------------------------------------------------
    --      Reset wrapper
    ---------------------------------------------------------------------------------------------------
    inst_sfp_10g_reset_wrapper : sfp_10g_reset_wrapper
        port map(
            SYS_RESET                   => SYS_RST,
            GT_TXUSRCLK2                => S_TX_ACLK,
            GT_RXUSRCLK2                => M_RX_ACLK,
            RX_CORE_CLK                 => M_RX_ACLK,
            GT_TX_RESET_IN              => gt_reset_tx_done,
            GT_RX_RESET_IN              => gt_reset_rx_done,
            TX_CORE_RESET_IN            => TX_RST,
            RX_CORE_RESET_IN            => RX_RST,
            TX_CORE_RESET_OUT           => tx_core_reset,
            RX_CORE_RESET_OUT           => rx_core_reset,
            RX_SERDES_RESET_OUT         => rx_serdes_reset,
            USR_TX_RESET                => S_TX_RST,
            USR_RX_RESET                => M_RX_RST,
            GTWIZ_RESET_ALL             => gtwiz_reset_all,
            GTWIZ_RESET_TX_DATAPATH_OUT => gtwiz_reset_tx_datapath,
            GTWIZ_RESET_RX_DATAPATH_OUT => gtwiz_reset_rx_datapath
        );

    ---------------------------------------------------------------------------------------------------
    --      Subsystem 10G
    ---------------------------------------------------------------------------------------------------
    inst_ethernet_subsystem_10g_ch1 : ethernet_subsystem_10g_ch1
        port map(
            -- SFP
            gt_rxp_in_0                      => SFP_RX_P,
            gt_rxn_in_0                      => SFP_RX_N,
            gt_txp_out_0                     => SFP_TX_P,
            gt_txn_out_0                     => SFP_TX_N,
            -- Clocking
            tx_clk_out_0                     => S_TX_ACLK,
            rx_core_clk_0                    => M_RX_ACLK,
            rx_clk_out_0                     => M_RX_ACLK,
            -- Loopback
            gt_loopback_in_0                 => "000",
            -- Rx reset
            rx_reset_0                       => rx_core_reset,
            rxrecclkout_0                    => open,
            -- Rx data interface
            rx_axis_tvalid_0                 => M_RX_TVALID,
            rx_axis_tdata_0                  => M_RX_TDATA,
            rx_axis_tlast_0                  => M_RX_TLAST,
            rx_axis_tkeep_0                  => M_RX_TKEEP,
            rx_axis_tuser_0                  => M_RX_TUSER(0), -- '1' when bad packet
            rx_preambleout_0                 => open,
            -- Rx control
            ctl_rx_test_pattern_0            => ctl_rx_test_pattern,
            ctl_rx_test_pattern_enable_0     => ctl_rx_test_pattern_enable,
            ctl_rx_data_pattern_select_0     => ctl_rx_data_pattern_select,
            ctl_rx_enable_0                  => ctl_rx_enable,
            ctl_rx_delete_fcs_0              => ctl_rx_delete_fcs,
            ctl_rx_ignore_fcs_0              => ctl_rx_ignore_fcs,
            ctl_rx_max_packet_len_0          => ctl_rx_max_packet_len,
            ctl_rx_min_packet_len_0          => ctl_rx_min_packet_len,
            ctl_rx_custom_preamble_enable_0  => ctl_rx_custom_preamble_enable,
            ctl_rx_check_sfd_0               => ctl_rx_check_sfd,
            ctl_rx_check_preamble_0          => ctl_rx_check_preamble,
            ctl_rx_process_lfi_0             => ctl_rx_process_lfi,
            ctl_rx_force_resync_0            => ctl_rx_force_resync,
            -- Rx stats
            stat_rx_block_lock_0             => stat_rx_block_lock,
            stat_rx_framing_err_valid_0      => stat_rx_framing_err_valid,
            stat_rx_framing_err_0            => stat_rx_framing_err,
            stat_rx_hi_ber_0                 => stat_rx_hi_ber,
            stat_rx_valid_ctrl_code_0        => stat_rx_valid_ctrl_code,
            stat_rx_bad_code_0               => stat_rx_bad_code,
            stat_rx_total_packets_0          => stat_rx_total_packets,
            stat_rx_total_good_packets_0     => stat_rx_total_good_packets,
            stat_rx_total_bytes_0            => stat_rx_total_bytes,
            stat_rx_total_good_bytes_0       => stat_rx_total_good_bytes,
            stat_rx_packet_small_0           => stat_rx_packet_small,
            stat_rx_jabber_0                 => stat_rx_jabber,
            stat_rx_packet_large_0           => stat_rx_packet_large,
            stat_rx_oversize_0               => stat_rx_oversize,
            stat_rx_undersize_0              => stat_rx_undersize,
            stat_rx_toolong_0                => stat_rx_toolong,
            stat_rx_fragment_0               => stat_rx_fragment,
            stat_rx_packet_64_bytes_0        => stat_rx_packet_64_bytes,
            stat_rx_packet_65_127_bytes_0    => stat_rx_packet_65_127_bytes,
            stat_rx_packet_128_255_bytes_0   => stat_rx_packet_128_255_bytes,
            stat_rx_packet_256_511_bytes_0   => stat_rx_packet_256_511_bytes,
            stat_rx_packet_512_1023_bytes_0  => stat_rx_packet_512_1023_bytes,
            stat_rx_packet_1024_1518_bytes_0 => stat_rx_packet_1024_1518_bytes,
            stat_rx_packet_1519_1522_bytes_0 => stat_rx_packet_1519_1522_bytes,
            stat_rx_packet_1523_1548_bytes_0 => stat_rx_packet_1523_1548_bytes,
            stat_rx_bad_fcs_0                => stat_rx_bad_fcs,
            stat_rx_packet_bad_fcs_0         => stat_rx_packet_bad_fcs,
            stat_rx_stomped_fcs_0            => stat_rx_stomped_fcs,
            stat_rx_packet_1549_2047_bytes_0 => stat_rx_packet_1549_2047_bytes,
            stat_rx_packet_2048_4095_bytes_0 => stat_rx_packet_2048_4095_bytes,
            stat_rx_packet_4096_8191_bytes_0 => stat_rx_packet_4096_8191_bytes,
            stat_rx_packet_8192_9215_bytes_0 => stat_rx_packet_8192_9215_bytes,
            stat_rx_unicast_0                => stat_rx_unicast,
            stat_rx_multicast_0              => stat_rx_multicast,
            stat_rx_broadcast_0              => stat_rx_broadcast,
            stat_rx_vlan_0                   => stat_rx_vlan,
            stat_rx_inrangeerr_0             => stat_rx_inrangeerr,
            stat_rx_bad_preamble_0           => stat_rx_bad_preamble,
            stat_rx_bad_sfd_0                => stat_rx_bad_sfd,
            stat_rx_got_signal_os_0          => stat_rx_got_signal_os,
            stat_rx_test_pattern_mismatch_0  => stat_rx_test_pattern_mismatch,
            stat_rx_truncated_0              => stat_rx_truncated,
            stat_rx_local_fault_0            => stat_rx_local_fault,
            stat_rx_remote_fault_0           => stat_rx_remote_fault,
            stat_rx_internal_local_fault_0   => stat_rx_internal_local_fault,
            stat_rx_received_local_fault_0   => stat_rx_received_local_fault,
            stat_rx_status_0                 => stat_rx_status,
            -- Tx reset
            tx_reset_0                       => tx_core_reset,
            -- Tx data itnerface
            tx_axis_tready_0                 => S_TX_TREADY,
            tx_axis_tvalid_0                 => S_TX_TVALID,
            tx_axis_tdata_0                  => S_TX_TDATA,
            tx_axis_tlast_0                  => S_TX_TLAST,
            tx_axis_tkeep_0                  => S_TX_TKEEP,
            tx_axis_tuser_0                  => S_TX_TUSER(0), -- '1' when bad packet
            tx_unfout_0                      => tx_underflow,
            tx_preamblein_0                  => (others => '0'),
            -- Tx control
            ctl_tx_test_pattern_0            => ctl_tx_test_pattern,
            ctl_tx_test_pattern_enable_0     => ctl_tx_test_pattern_enable,
            ctl_tx_test_pattern_select_0     => ctl_tx_test_pattern_select,
            ctl_tx_data_pattern_select_0     => ctl_tx_data_pattern_select,
            ctl_tx_test_pattern_seed_a_0     => ctl_tx_test_pattern_seed_a,
            ctl_tx_test_pattern_seed_b_0     => ctl_tx_test_pattern_seed_b,
            ctl_tx_enable_0                  => ctl_tx_enable,
            ctl_tx_fcs_ins_enable_0          => ctl_tx_fcs_ins_enable,
            ctl_tx_ipg_value_0               => ctl_tx_ipg_value,
            ctl_tx_send_lfi_0                => ctl_tx_send_lfi,
            ctl_tx_send_rfi_0                => ctl_tx_send_rfi,
            ctl_tx_send_idle_0               => ctl_tx_send_idle,
            ctl_tx_custom_preamble_enable_0  => ctl_tx_custom_preamble_enable,
            ctl_tx_ignore_fcs_0              => ctl_tx_ignore_fcs,
            -- Tx stat
            stat_tx_total_packets_0          => stat_tx_total_packets,
            stat_tx_total_bytes_0            => stat_tx_total_bytes,
            stat_tx_total_good_packets_0     => stat_tx_total_good_packets,
            stat_tx_total_good_bytes_0       => stat_tx_total_good_bytes,
            stat_tx_packet_64_bytes_0        => stat_tx_packet_64_bytes,
            stat_tx_packet_65_127_bytes_0    => stat_tx_packet_65_127_bytes,
            stat_tx_packet_128_255_bytes_0   => stat_tx_packet_128_255_bytes,
            stat_tx_packet_256_511_bytes_0   => stat_tx_packet_256_511_bytes,
            stat_tx_packet_512_1023_bytes_0  => stat_tx_packet_512_1023_bytes,
            stat_tx_packet_1024_1518_bytes_0 => stat_tx_packet_1024_1518_bytes,
            stat_tx_packet_1519_1522_bytes_0 => stat_tx_packet_1519_1522_bytes,
            stat_tx_packet_1523_1548_bytes_0 => stat_tx_packet_1523_1548_bytes,
            stat_tx_packet_small_0           => stat_tx_packet_small,
            stat_tx_packet_large_0           => stat_tx_packet_large,
            stat_tx_packet_1549_2047_bytes_0 => stat_tx_packet_1549_2047_bytes,
            stat_tx_packet_2048_4095_bytes_0 => stat_tx_packet_2048_4095_bytes,
            stat_tx_packet_4096_8191_bytes_0 => stat_tx_packet_4096_8191_bytes,
            stat_tx_packet_8192_9215_bytes_0 => stat_tx_packet_8192_9215_bytes,
            stat_tx_unicast_0                => stat_tx_unicast,
            stat_tx_multicast_0              => stat_tx_multicast,
            stat_tx_broadcast_0              => stat_tx_broadcast,
            stat_tx_vlan_0                   => stat_tx_vlan,
            stat_tx_bad_fcs_0                => stat_tx_bad_fcs,
            stat_tx_frame_error_0            => stat_tx_frame_error,
            stat_tx_local_fault_0            => stat_tx_local_fault,
            -- Transceiver
            gtpowergood_out_0                => open,
            txoutclksel_in_0                 => "101",
            rxoutclksel_in_0                 => "101",
            rx_serdes_reset_0                => rx_serdes_reset,
            gt_reset_all_in_0                => gtwiz_reset_all,
            gt_tx_reset_in_0                 => gtwiz_reset_tx_datapath,
            gt_rx_reset_in_0                 => gtwiz_reset_rx_datapath,
            gt_reset_tx_done_out_0           => gt_reset_tx_done,
            gt_reset_rx_done_out_0           => gt_reset_rx_done,
            qpll0clk_in                      => qpll0clk,
            qpll0refclk_in                   => qpll0refclk,
            qpll1clk_in                      => qpll1clk,
            qpll1refclk_in                   => qpll1refclk,
            gtwiz_reset_qpll0lock_in         => qpll0lock,
            gtwiz_reset_qpll1lock_in         => qpll1lock,
            gtwiz_reset_qpll0reset_out       => qpll0reset,
            gtwiz_reset_qpll1reset_out       => qpll1reset,
            sys_reset                        => SYS_RST,
            dclk                             => CLK_100_MHZ
        );

    PHY_LAYER_READY <= stat_rx_status;  --@suppress

    STATUS_VECTOR_SFP(0) <= stat_rx_status;
    STATUS_VECTOR_SFP(1) <= stat_rx_local_fault;
    STATUS_VECTOR_SFP(2) <= stat_rx_remote_fault;
    STATUS_VECTOR_SFP(3) <= stat_rx_internal_local_fault;
    STATUS_VECTOR_SFP(4) <= stat_rx_received_local_fault;

    STATUS_VECTOR_SFP(5) <= stat_tx_frame_error;
    STATUS_VECTOR_SFP(6) <= stat_tx_local_fault;
    STATUS_VECTOR_SFP(7) <= tx_underflow;

    ---------------------------------------------------------------------------------------------------
    --      Debug
    ---------------------------------------------------------------------------------------------------
    -- Debug LED to valid clock is active
    P_CLK_PHY_CHECK : process(S_TX_ACLK)
    begin
        if rising_edge(S_TX_ACLK) then
            if (S_TX_RST = '1') then
                cnt_clk_phy        <= 0;
                DBG_CLK_PHY_ACTIVE <= '0';
            else
                if cnt_clk_phy = (C_FREQ_CLK_PHY - 1) then
                    DBG_CLK_PHY_ACTIVE <= not DBG_CLK_PHY_ACTIVE;
                    cnt_clk_phy        <= 0;
                else
                    cnt_clk_phy <= cnt_clk_phy + 1;
                end if;
            end if;
        end if;
    end process P_CLK_PHY_CHECK;
end rtl;
