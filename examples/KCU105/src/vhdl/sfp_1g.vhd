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

library unisim;
use unisim.vcomponents.all;

library common;
use common.cdc_utils_pkg.cdc_bit_sync;

entity sfp_1g is
    generic(
        G_DEBUG              : boolean := false;
        G_EXAMPLE_SIMULATION : integer := 0 --To select simulation for PCS/PMA Ip in 1G

    );
    port(
        -- Clocks
        GT_REFCLK          : in  std_logic; -- GT Refclk @156.25 MHz
        CLK_50_MHZ         : in  std_logic; -- Free running clock
        -- Resets
        SYS_RST            : in  std_logic; -- Global async reset active high
        SYS_RST_N          : in  std_logic; -- Global async reset active low
        RX_RST_N           : in  std_logic; -- Reset of Rx part
        TX_RST_N           : in  std_logic; -- Reset of Tx part
        -- SFP
        SFP_TX_N           : out std_logic;
        SFP_TX_P           : out std_logic;
        SFP_RX_N           : in  std_logic;
        SFP_RX_P           : in  std_logic;
        -- Rx interface
        M_RX_ACLK          : out std_logic;
        M_RX_RST           : out std_logic;
        M_RX_TDATA         : out std_logic_vector(7 downto 0);
        M_RX_TVALID        : out std_logic;
        M_RX_TUSER         : out std_logic_vector(0 downto 0); -- 1 when frame has an error
        M_RX_TLAST         : out std_logic;
        -- Pause
        PAUSE_REQ          : in  std_logic;
        PAUSE_VAL          : in  std_logic_vector(15 downto 0);
        -- TX interface
        S_TX_ACLK          : out std_logic;
        S_TX_RST           : out std_logic;
        S_TX_TDATA         : in  std_logic_vector(7 downto 0);
        S_TX_TVALID        : in  std_logic;
        S_TX_TLAST         : in  std_logic;
        S_TX_TUSER         : in  std_logic_vector(0 downto 0); -- 1 when frame has an error
        S_TX_TREADY        : out std_logic;
        -- Control and status signals
        MAC_ADDRESS        : in  std_logic_vector(47 downto 0);
        SFP_MOD_DEF0       : in  std_logic; -- '0' = module present   '1' = module not present
        SFP_RX_LOS         : in  std_logic;
        PHY_LAYER_READY    : out std_logic;
        STATUS_VECTOR_SFP  : out std_logic_vector(15 downto 0);
        -- DBG
        DBG_CLK_PHY_ACTIVE : out std_logic
    );
end sfp_1g;

architecture rtl of sfp_1g is

    ---------------------------------------------------------------------------------------------------
    --      Components
    ---------------------------------------------------------------------------------------------------
    component tri_mode_ethernet_mac_1g
        port(
            gtx_clk                 : in  STD_LOGIC;
            glbl_rstn               : in  STD_LOGIC;
            rx_axi_rstn             : in  STD_LOGIC;
            tx_axi_rstn             : in  STD_LOGIC;
            rx_statistics_vector    : out STD_LOGIC_VECTOR(27 downto 0);
            rx_statistics_valid     : out STD_LOGIC;
            rx_mac_aclk             : out STD_LOGIC;
            rx_reset                : out STD_LOGIC;
            rx_axis_mac_tdata       : out STD_LOGIC_VECTOR(7 downto 0);
            rx_axis_mac_tvalid      : out STD_LOGIC;
            rx_axis_mac_tlast       : out STD_LOGIC;
            rx_axis_mac_tuser       : out STD_LOGIC;
            tx_ifg_delay            : in  STD_LOGIC_VECTOR(7 downto 0);
            tx_statistics_vector    : out STD_LOGIC_VECTOR(31 downto 0);
            tx_statistics_valid     : out STD_LOGIC;
            tx_mac_aclk             : out STD_LOGIC;
            tx_reset                : out STD_LOGIC;
            tx_axis_mac_tdata       : in  STD_LOGIC_VECTOR(7 downto 0);
            tx_axis_mac_tvalid      : in  STD_LOGIC;
            tx_axis_mac_tlast       : in  STD_LOGIC;
            tx_axis_mac_tuser       : in  STD_LOGIC_VECTOR(0 downto 0);
            tx_axis_mac_tready      : out STD_LOGIC;
            pause_req               : in  STD_LOGIC;
            pause_val               : in  STD_LOGIC_VECTOR(15 downto 0);
            clk_enable              : in  STD_LOGIC;
            speedis100              : out STD_LOGIC;
            speedis10100            : out STD_LOGIC;
            gmii_txd                : out STD_LOGIC_VECTOR(7 downto 0);
            gmii_tx_en              : out STD_LOGIC;
            gmii_tx_er              : out STD_LOGIC;
            gmii_rxd                : in  STD_LOGIC_VECTOR(7 downto 0);
            gmii_rx_dv              : in  STD_LOGIC;
            gmii_rx_er              : in  STD_LOGIC;
            rx_configuration_vector : in  STD_LOGIC_VECTOR(79 downto 0);
            tx_configuration_vector : in  STD_LOGIC_VECTOR(79 downto 0)
        );
    end component tri_mode_ethernet_mac_1g;

    component gig_ethernet_pcs_pma_sfp_ch2 -- @suppress "Component declaration is not equal to its matching entity : generic not known"
        generic(EXAMPLE_SIMULATION : integer := 0);
        port(
            gtrefclk               : in  STD_LOGIC;
            txp                    : out STD_LOGIC;
            txn                    : out STD_LOGIC;
            rxp                    : in  STD_LOGIC;
            rxn                    : in  STD_LOGIC;
            resetdone              : out STD_LOGIC;
            cplllock               : out STD_LOGIC;
            mmcm_reset             : out STD_LOGIC;
            txoutclk               : out STD_LOGIC;
            rxoutclk               : out STD_LOGIC;
            userclk                : in  STD_LOGIC;
            userclk2               : in  STD_LOGIC;
            rxuserclk              : in  STD_LOGIC;
            rxuserclk2             : in  STD_LOGIC;
            pma_reset              : in  STD_LOGIC;
            mmcm_locked            : in  STD_LOGIC;
            independent_clock_bufg : in  STD_LOGIC;
            gmii_txd               : in  STD_LOGIC_VECTOR(7 downto 0);
            gmii_tx_en             : in  STD_LOGIC;
            gmii_tx_er             : in  STD_LOGIC;
            gmii_rxd               : out STD_LOGIC_VECTOR(7 downto 0);
            gmii_rx_dv             : out STD_LOGIC;
            gmii_rx_er             : out STD_LOGIC;
            gmii_isolate           : out STD_LOGIC;
            configuration_vector   : in  STD_LOGIC_VECTOR(4 downto 0);
            an_interrupt           : out STD_LOGIC;
            an_adv_config_vector   : in  STD_LOGIC_VECTOR(15 downto 0);
            an_restart_config      : in  STD_LOGIC;
            status_vector          : out STD_LOGIC_VECTOR(15 downto 0);
            reset                  : in  STD_LOGIC;
            gtpowergood            : out STD_LOGIC;
            signal_detect          : in  STD_LOGIC
        );
    end component gig_ethernet_pcs_pma_sfp_ch2;

    component gig_ethernet_pcs_pma_sfp_resets is
        port(
            reset                  : in  std_logic; -- Asynchronous reset for entire core.
            independent_clock_bufg : in  std_logic; -- System clock
            pma_reset              : out std_logic -- Synchronous transcevier PMA reset
        );
    end component gig_ethernet_pcs_pma_sfp_resets;

    ---------------------------------------------------------------------------------------------------
    --      Signals
    ---------------------------------------------------------------------------------------------------

    -- PCS/PMA clocking
    signal pcs_pma_txoutclk : std_logic;
    signal pcs_pma_rxoutclk : std_logic;
    signal pcs_pma_reset    : std_logic;
    signal userclk          : std_logic;
    signal userclk2         : std_logic;
    signal rxuserclk        : std_logic;

    -- Status
    signal signal_detect_sfp : std_logic;

    -- GMII
    signal pcs_pma_gmii_txd   : std_logic_vector(7 downto 0);
    signal pcs_pma_gmii_tx_en : std_logic;
    signal pcs_pma_gmii_tx_er : std_logic;
    signal pcs_pma_gmii_rxd   : std_logic_vector(7 downto 0);
    signal pcs_pma_gmii_rx_dv : std_logic;
    signal pcs_pma_gmii_rx_er : std_logic;

    -- Configuation vectors

    signal rx_configuration_vector  : std_logic_vector(79 downto 0);
    signal tx_configuration_vector  : std_logic_vector(79 downto 0);
    signal config_vector_sfp        : std_logic_vector(4 downto 0);
    signal an_adv_config_vector_sfp : std_logic_vector(15 downto 0);

    --For debug
    constant C_FREQ_CLK_PHY : integer := 125000000;
    signal cnt_clk_phy      : integer range 0 to C_FREQ_CLK_PHY - 1;

    signal transmitter_reset                           : std_logic;
    signal transmitter_enable                          : std_logic;
    signal transmitter_vlan_enable                     : std_logic;
    signal transmitter_inband_fcs_enable               : std_logic;
    signal transmitter_jumbo_frame_enable              : std_logic;
    signal transmitter_flow_control_enable             : std_logic;
    signal transmitter_half_duplex_mode                : std_logic;
    signal transmitter_gap_adjust_enable               : std_logic;
    signal transmitter_speed_configuration             : std_logic_vector(1 downto 0);
    signal transmitter_max_frame_enable                : std_logic;
    signal transmitter_max_frame_size                  : std_logic_vector(15 downto 0);
    signal transmitter_pause_frame_mac_address         : std_logic_vector(47 downto 0);
    signal receiver_reset                              : std_logic;
    signal receiver_enable                             : std_logic;
    signal receiver_vlan_enable                        : std_logic;
    signal receiver_inband_fcs_enable                  : std_logic;
    signal receiver_jumbo_frame_enable                 : std_logic;
    signal receiver_flow_control_enable                : std_logic;
    signal receiver_half_duplex_mode                   : std_logic;
    signal receiver_length_type_error_check_disable    : std_logic;
    signal receiver_control_frame_length_check_disable : std_logic;
    signal receiver_promiscuous_mode                   : std_logic;
    signal receiver_speed_configuration                : std_logic_vector(1 downto 0);
    signal receiver_max_frame_enable                   : std_logic;
    signal receiver_max_frame_size                     : std_logic_vector(15 downto 0);
    signal receiver_pause_frame_mac_address            : std_logic_vector(47 downto 0);

    signal tx_statistics_vector      : std_logic_vector(31 downto 0);
    signal tx_statistics_vector_hold : std_logic_vector(31 downto 0);
    signal tx_statistics_valid       : std_logic;

    signal rx_statistics_vector      : std_logic_vector(27 downto 0);
    signal rx_statistics_vector_hold : std_logic_vector(27 downto 0);
    signal rx_statistics_valid       : std_logic;

begin

    ---------------------------------------------------------------------------------------------------
    --      MAC Rx configuration vector
    ---------------------------------------------------------------------------------------------------

    GEN_RX_DEFAULT_CFG : if not G_DEBUG generate

        --+==========+==============================================================================+
        --| [0]      | Receiver reset                                                            |
        receiver_reset                              <= SYS_RST;
        --|----------+------------------------------------------------------------------------------+
        --| [1]      | Receiver enable                                                           |
        receiver_enable                             <= '1';
        --|----------+------------------------------------------------------------------------------+
        --| [2]      | Receiver Vlan Enable                                                      |
        receiver_vlan_enable                        <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [3]      | Receiver In-band FCS enable                                               |
        receiver_inband_fcs_enable                  <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [4]      | Jumbo frame enable                                                           |
        receiver_jumbo_frame_enable                 <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [5]      | Flow Control enable                                                          |
        receiver_flow_control_enable                <= '1';
        --|----------+------------------------------------------------------------------------------+
        --| [6]      | half duplex mode                                                             |
        receiver_half_duplex_mode                   <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [7]    | Reserved                                                                       |
        --|----------+------------------------------------------------------------------------------+
        --| [8]      | Receiver length/type error check disable                                     |
        receiver_length_type_error_check_disable    <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [9]      | Receiver control frame length check disable                                  |
        receiver_control_frame_length_check_disable <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [10]     | Reserved                                                                     |
        --|----------+------------------------------------------------------------------------------+
        --| [11]      | Receiver promiscuous mode                                     |
        receiver_promiscuous_mode                   <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [13:12]  | Receiver Speed Configuration                                              |
        --|          | 00 - 10 Mb/s
        --|          | 01 - 100 Mb/s
        --|          | 10 - 1 Gb/s
        receiver_speed_configuration                <= "10";
        --+==========+==============================================================================+
        --| [14]      | Max frame enable                                                            |
        receiver_max_frame_enable                   <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [15]    | Reserved                                                                      |
        --|----------+------------------------------------------------------------------------------+
        --| [31:16]  | Receiver max frame size                                                   |
        receiver_max_frame_size                     <= std_logic_vector(to_unsigned(1518, 16));
        --|----------+------------------------------------------------------------------------------+
        --| [79:32]  | Pause frame source address                                                   |
        receiver_pause_frame_mac_address            <= MAC_ADDRESS;
        --+==========+==============================================================================+

    end generate GEN_RX_DEFAULT_CFG;

    GEN_RX_VIO_CFG : if G_DEBUG generate
        component vio_rx_1G_cfg
            port(
                clk         : in  std_logic;
                probe_in0   : in  std_logic_vector(0 downto 0);
                probe_in1   : in  std_logic_vector(0 downto 0);
                probe_in2   : in  std_logic_vector(0 downto 0);
                probe_in3   : in  std_logic_vector(0 downto 0);
                probe_in4   : in  std_logic_vector(0 downto 0);
                probe_in5   : in  std_logic_vector(13 downto 0);
                probe_in6   : in  std_logic_vector(0 downto 0);
                probe_in7   : in  std_logic_vector(0 downto 0);
                probe_in8   : in  std_logic_vector(0 downto 0);
                probe_in9   : in  std_logic_vector(0 downto 0);
                probe_in10  : in  std_logic_vector(0 downto 0);
                probe_in11  : in  std_logic_vector(0 downto 0);
                probe_in12  : in  std_logic_vector(0 downto 0);
                probe_in13  : in  std_logic_vector(0 downto 0);
                probe_in14  : in  std_logic_vector(0 downto 0);
                probe_out0  : out std_logic_vector(0 downto 0);
                probe_out1  : out std_logic_vector(0 downto 0);
                probe_out2  : out std_logic_vector(0 downto 0);
                probe_out3  : out std_logic_vector(0 downto 0);
                probe_out4  : out std_logic_vector(0 downto 0);
                probe_out5  : out std_logic_vector(0 downto 0);
                probe_out6  : out std_logic_vector(0 downto 0);
                probe_out7  : out std_logic_vector(0 downto 0);
                probe_out8  : out std_logic_vector(0 downto 0);
                probe_out9  : out std_logic_vector(0 downto 0);
                probe_out10 : out std_logic_vector(1 downto 0);
                probe_out11 : out std_logic_vector(0 downto 0);
                probe_out12 : out std_logic_vector(15 downto 0);
                probe_out13 : out std_logic_vector(47 downto 0)
            );
        end component vio_rx_1G_cfg;

    begin
        inst_vio_rx_1G_cfg : vio_rx_1G_cfg
            port map(
                clk            => rxuserclk,
                probe_in0      => rx_statistics_vector_hold(0 downto 0),
                probe_in1      => rx_statistics_vector_hold(1 downto 1),
                probe_in2      => rx_statistics_vector_hold(2 downto 2),
                probe_in3      => rx_statistics_vector_hold(3 downto 3),
                probe_in4      => rx_statistics_vector_hold(4 downto 4),
                probe_in5      => rx_statistics_vector_hold(18 downto 5),
                probe_in6      => rx_statistics_vector_hold(19 downto 19),
                probe_in7      => rx_statistics_vector_hold(20 downto 20),
                probe_in8      => rx_statistics_vector_hold(21 downto 21),
                probe_in9      => rx_statistics_vector_hold(22 downto 22),
                probe_in10     => rx_statistics_vector_hold(23 downto 23),
                probe_in11     => rx_statistics_vector_hold(24 downto 24),
                probe_in12     => rx_statistics_vector_hold(25 downto 25),
                probe_in13     => rx_statistics_vector_hold(26 downto 26),
                probe_in14     => rx_statistics_vector_hold(27 downto 27),
                probe_out0(0)  => receiver_reset,
                probe_out1(0)  => receiver_enable,
                probe_out2(0)  => receiver_vlan_enable,
                probe_out3(0)  => receiver_inband_fcs_enable,
                probe_out4(0)  => receiver_jumbo_frame_enable,
                probe_out5(0)  => receiver_flow_control_enable,
                probe_out6(0)  => receiver_half_duplex_mode,
                probe_out7(0)  => receiver_length_type_error_check_disable,
                probe_out8(0)  => receiver_control_frame_length_check_disable,
                probe_out9(0)  => receiver_promiscuous_mode,
                probe_out10    => receiver_speed_configuration,
                probe_out11(0) => receiver_max_frame_enable,
                probe_out12    => receiver_max_frame_size,
                probe_out13    => receiver_pause_frame_mac_address
            );

        -- Latch value of rx_statistics on valid
        p_hold_rx_stat : process(M_RX_ACLK)
        begin
            if rising_edge(M_RX_ACLK) then
                if M_RX_RST then
                    rx_statistics_vector_hold <= (others => '0');
                else
                    if rx_statistics_valid = '1' then
                        rx_statistics_vector_hold <= rx_statistics_vector;
                    end if;
                end if;
            end if;
        end process p_hold_rx_stat;

    end generate GEN_RX_VIO_CFG;

    rx_configuration_vector(0)            <= receiver_reset;
    rx_configuration_vector(1)            <= receiver_enable;
    rx_configuration_vector(2)            <= receiver_vlan_enable;
    rx_configuration_vector(3)            <= receiver_inband_fcs_enable;
    rx_configuration_vector(4)            <= receiver_jumbo_frame_enable;
    rx_configuration_vector(5)            <= receiver_flow_control_enable;
    rx_configuration_vector(6)            <= receiver_half_duplex_mode;
    rx_configuration_vector(7)            <= '0';
    rx_configuration_vector(8)            <= receiver_length_type_error_check_disable;
    rx_configuration_vector(9)            <= receiver_control_frame_length_check_disable;
    rx_configuration_vector(10)           <= '0';
    rx_configuration_vector(11)           <= receiver_promiscuous_mode;
    rx_configuration_vector(13 downto 12) <= receiver_speed_configuration;
    rx_configuration_vector(14)           <= receiver_max_frame_enable;
    rx_configuration_vector(15)           <= '0';
    rx_configuration_vector(31 downto 16) <= receiver_max_frame_size;
    rx_configuration_vector(79 downto 32) <= receiver_pause_frame_mac_address;

    ---------------------------------------------------------------------------------------------------
    --      MAC Tx configuration vector
    ---------------------------------------------------------------------------------------------------

    GEN_TX_DEFAULT_CFG : if not G_DEBUG generate

        --+==========+==============================================================================+
        --| [0]      | Transmitter reset                                                            |
        transmitter_reset                   <= SYS_RST;
        --|----------+------------------------------------------------------------------------------+
        --| [1]      | Transmitter enable                                                           |
        transmitter_enable                  <= '1';
        --|----------+------------------------------------------------------------------------------+
        --| [2]      | Transmitter Vlan Enable                                                      |
        transmitter_vlan_enable             <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [3]      | Transmitter In-band FCS enable                                               |
        transmitter_inband_fcs_enable       <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [4]      | Jumbo frame enable                                                           |
        transmitter_jumbo_frame_enable      <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [5]      | Flow Control enable                                                          |
        transmitter_flow_control_enable     <= '1';
        --|----------+------------------------------------------------------------------------------+
        --| [6]      | half duplex mode                                                             |
        transmitter_half_duplex_mode        <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [7]    | Reserved                                                                       |
        --|----------+------------------------------------------------------------------------------+
        --| [8]      | Gap adjust enable                                                            |
        transmitter_gap_adjust_enable       <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [9:11]   | Reserved                                                                     |
        --|----------+------------------------------------------------------------------------------+
        --| [13:12]  | Transmitter Speed Configuration                                              |
        --|          | 00 - 10 Mb/s
        --|          | 01 - 100 Mb/s
        --|          | 10 - 1 Gb/s
        transmitter_speed_configuration     <= "10";
        --+==========+==============================================================================+
        --| [14]      | Max frame enable                                                            |
        transmitter_max_frame_enable        <= '0';
        --|----------+------------------------------------------------------------------------------+
        --| [15]    | Reserved                                                                      |
        --|----------+------------------------------------------------------------------------------+
        --| [31:16]  | Transmitter max frame size                                                   |
        transmitter_max_frame_size          <= std_logic_vector(to_unsigned(1518, 16));
        --|----------+------------------------------------------------------------------------------+
        --| [79:32]  | Pause frame source address                                                   |
        transmitter_pause_frame_mac_address <= MAC_ADDRESS;
        --+==========+==============================================================================+

    end generate GEN_TX_DEFAULT_CFG;

    GEN_TX_VIO_CFG : if G_DEBUG generate
        component vio_tx_1G_cfg
            port(
                clk         : in  std_logic;
                probe_in0   : in  std_logic_vector(0 downto 0);
                probe_in1   : in  std_logic_vector(0 downto 0);
                probe_in2   : in  std_logic_vector(0 downto 0);
                probe_in3   : in  std_logic_vector(0 downto 0);
                probe_in4   : in  std_logic_vector(0 downto 0);
                probe_in5   : in  std_logic_vector(13 downto 0);
                probe_in6   : in  std_logic_vector(0 downto 0);
                probe_in7   : in  std_logic_vector(0 downto 0);
                probe_in8   : in  std_logic_vector(0 downto 0);
                probe_in9   : in  std_logic_vector(0 downto 0);
                probe_in10  : in  std_logic_vector(0 downto 0);
                probe_in11  : in  std_logic_vector(3 downto 0);
                probe_in12  : in  std_logic_vector(0 downto 0);
                probe_in13  : in  std_logic_vector(0 downto 0);
                probe_out0  : out std_logic_vector(0 downto 0);
                probe_out1  : out std_logic_vector(0 downto 0);
                probe_out2  : out std_logic_vector(0 downto 0);
                probe_out3  : out std_logic_vector(0 downto 0);
                probe_out4  : out std_logic_vector(0 downto 0);
                probe_out5  : out std_logic_vector(0 downto 0);
                probe_out6  : out std_logic_vector(0 downto 0);
                probe_out7  : out std_logic_vector(0 downto 0);
                probe_out8  : out std_logic_vector(1 downto 0);
                probe_out9  : out std_logic_vector(0 downto 0);
                probe_out10 : out std_logic_vector(15 downto 0);
                probe_out11 : out std_logic_vector(47 downto 0)
            );
        end component vio_tx_1G_cfg;

    begin
        inst_vio_tx_1G_cfg : vio_tx_1G_cfg
            port map(
                clk           => userclk2,
                probe_in0     => tx_statistics_vector_hold(0 downto 0),
                probe_in1     => tx_statistics_vector_hold(1 downto 1),
                probe_in2     => tx_statistics_vector_hold(2 downto 2),
                probe_in3     => tx_statistics_vector_hold(3 downto 3),
                probe_in4     => tx_statistics_vector_hold(4 downto 4),
                probe_in5     => tx_statistics_vector_hold(18 downto 5),
                probe_in6     => tx_statistics_vector_hold(19 downto 19),
                probe_in7     => tx_statistics_vector_hold(20 downto 20),
                probe_in8     => tx_statistics_vector_hold(21 downto 21),
                probe_in9     => tx_statistics_vector_hold(22 downto 22),
                probe_in10    => tx_statistics_vector_hold(23 downto 23),
                probe_in11    => tx_statistics_vector_hold(28 downto 25),
                probe_in12    => tx_statistics_vector_hold(30 downto 30),
                probe_in13    => tx_statistics_vector_hold(31 downto 31),
                probe_out0(0) => transmitter_reset,
                probe_out1(0) => transmitter_enable,
                probe_out2(0) => transmitter_vlan_enable,
                probe_out3(0) => transmitter_inband_fcs_enable,
                probe_out4(0) => transmitter_jumbo_frame_enable,
                probe_out5(0) => transmitter_flow_control_enable,
                probe_out6(0) => transmitter_half_duplex_mode,
                probe_out7(0) => transmitter_gap_adjust_enable,
                probe_out8    => transmitter_speed_configuration,
                probe_out9(0) => transmitter_max_frame_enable,
                probe_out10   => transmitter_max_frame_size,
                probe_out11   => transmitter_pause_frame_mac_address
            );

        -- Latch value of tx_statistics on valid
        p_hold_tx_stat : process(S_TX_ACLK)
        begin
            if rising_edge(S_TX_ACLK) then
                if S_TX_RST then
                    tx_statistics_vector_hold <= (others => '0');
                else
                    if tx_statistics_valid = '1' then
                        tx_statistics_vector_hold <= tx_statistics_vector;
                    end if;
                end if;
            end if;
        end process p_hold_tx_stat;

    end generate GEN_TX_VIO_CFG;

    tx_configuration_vector(0)            <= transmitter_reset;
    tx_configuration_vector(1)            <= transmitter_enable;
    tx_configuration_vector(2)            <= transmitter_vlan_enable;
    tx_configuration_vector(3)            <= transmitter_inband_fcs_enable;
    tx_configuration_vector(4)            <= transmitter_jumbo_frame_enable;
    tx_configuration_vector(5)            <= transmitter_flow_control_enable;
    tx_configuration_vector(6)            <= transmitter_half_duplex_mode;
    tx_configuration_vector(7)            <= '0';
    tx_configuration_vector(8)            <= transmitter_gap_adjust_enable;
    tx_configuration_vector(11 downto 9)  <= (others => '0');
    tx_configuration_vector(13 downto 12) <= transmitter_speed_configuration;
    tx_configuration_vector(14)           <= transmitter_max_frame_enable;
    tx_configuration_vector(15)           <= '0';
    tx_configuration_vector(31 downto 16) <= transmitter_max_frame_size;
    tx_configuration_vector(79 downto 32) <= transmitter_pause_frame_mac_address;

    ---------------------------------------------------------------------------------------------------
    --      MAC
    ---------------------------------------------------------------------------------------------------
    inst_tri_mode_ethernet_mac_1g : tri_mode_ethernet_mac_1g
        port map(
            gtx_clk                 => userclk2,
            -- others reset
            glbl_rstn               => SYS_RST_N,
            rx_axi_rstn             => RX_RST_N,
            tx_axi_rstn             => TX_RST_N,
            rx_statistics_vector    => rx_statistics_vector,
            rx_statistics_valid     => rx_statistics_valid,
            rx_mac_aclk             => M_RX_ACLK, -- output
            rx_reset                => M_RX_RST, -- output
            -- rx axi stream adaptor
            rx_axis_mac_tdata       => M_RX_TDATA,
            rx_axis_mac_tvalid      => M_RX_TVALID,
            rx_axis_mac_tlast       => M_RX_TLAST,
            rx_axis_mac_tuser       => M_RX_TUSER(0), -- 1 when frame has an error
            tx_ifg_delay            => (others => '0'),
            tx_statistics_vector    => tx_statistics_vector,
            tx_statistics_valid     => tx_statistics_valid,
            tx_mac_aclk             => S_TX_ACLK, -- output
            tx_reset                => S_TX_RST, -- output
            -- tx axi stream adaptor
            tx_axis_mac_tdata       => S_TX_TDATA,
            tx_axis_mac_tvalid      => S_TX_TVALID,
            tx_axis_mac_tlast       => S_TX_TLAST,
            tx_axis_mac_tuser       => S_TX_TUSER, -- 1 when frame has an error
            tx_axis_mac_tready      => S_TX_TREADY,
            -- from the uoe
            pause_req               => PAUSE_REQ,
            pause_val               => PAUSE_VAL,
            -- constant
            clk_enable              => '1',
            speedis100              => open,
            speedis10100            => open,
            -- gmii for pcs/pma
            gmii_txd                => pcs_pma_gmii_txd,
            gmii_tx_en              => pcs_pma_gmii_tx_en,
            gmii_tx_er              => pcs_pma_gmii_tx_er,
            gmii_rxd                => pcs_pma_gmii_rxd,
            gmii_rx_dv              => pcs_pma_gmii_rx_dv,
            gmii_rx_er              => pcs_pma_gmii_rx_er,
            -- pcs/pma
            rx_configuration_vector => rx_configuration_vector,
            tx_configuration_vector => tx_configuration_vector
        );

    ---------------------------------------------------------------------------------------------------
    --      Clocks PCS/PMA
    ---------------------------------------------------------------------------------------------------

    -- BUFG_GT DIV input (Xilinx UG974 page 27) :
    -- Specifies the value to divide the clock. Divide value is value
    -- provided plus 1. For instance, setting 3’b000 will provide a divide
    -- value of 1 and 3’b111 will be a divide value of 8.

    -- 125 MHz Divided by 1 ===> 125 MHz
    INST_BUFG_GT_USERCLK2 : component BUFG_GT
        port map(
            O       => userclk2,
            CE      => '1',
            CEMASK  => '1',
            CLR     => '0',
            CLRMASK => '1',
            DIV     => "000",
            I       => pcs_pma_txoutclk
        );

    -- 125 MHz Divided by 2 ===> 62.5 MHz
    INST_BUFG_GT_USERCLK : component BUFG_GT
        port map(
            O       => userclk,
            CE      => '1',
            CEMASK  => '1',
            CLR     => '0',
            CLRMASK => '1',
            DIV     => "001",
            I       => pcs_pma_txoutclk
        );

    -- RX User clock
    INST_BUFG_GT_RXUSERCLK : component BUFG_GT
        port map(
            O       => rxuserclk,       -- rxuserclk2
            CE      => '1',
            CEMASK  => '1',
            CLR     => '0',
            CLRMASK => '1',
            DIV     => "000",
            I       => pcs_pma_rxoutclk
        );

    ---------------------------------------------------------------------------------------------------
    --      Clocks PCS/PMA
    ---------------------------------------------------------------------------------------------------
    inst_gig_ethernet_pcs_pma_sfp_resets : component gig_ethernet_pcs_pma_sfp_resets
        port map(
            reset                  => SYS_RST,
            independent_clock_bufg => CLK_50_MHZ,
            pma_reset              => pcs_pma_reset
        );

    ---------------------------------------------------------------------------------------------------
    --      Auto-Negotiation Vector
    ---------------------------------------------------------------------------------------------------

    --+==========+==============================================================================+
    --| [0]      | For 1000BASE-X or 2500BASE-X-Reserved.                                       |
    --|          | For SGMII- Always 1                                                          |
    --|----------+------------------------------------------------------------------------------+
    --| [4:1]    | Reserved                                                                     |
    --|----------+------------------------------------------------------------------------------+
    --| [5]      | For 1000BASE-X or 2500BASE-X- Full Duplex                                    |
    --|          |  1 = Full Duplex Mode is advertised                                          |
    --|          |  0 = Full Duplex Mode is not advertised                                      |
    --|          | For SGMII: Reserved                                                          |
    --|----------+------------------------------------------------------------------------------+
    --| [6]      | Reserved                                                                     |
    --|----------+------------------------------------------------------------------------------+
    --| [8:7]    | For 1000BASE-X or 2500BASE-X- Pause                                          |
    --|          |  0 0 = No Pause                                                              |
    --|          |  0 1 = Symmetric Pause                                                       |
    --|          |  1 0 = Asymmetric Pause towards link partner                                 |
    --|          |  1 1 = Both Symmetric Pause and Asymmetric Pause towards link partner        |
    --|          | For SGMII - Reserved                                                         |
    --|----------+------------------------------------------------------------------------------+
    --| [9]      | Reserved                                                                     |
    --|----------+------------------------------------------------------------------------------+
    --| [11:10]  | For 1000BASE-X or 2500BASE-X- Reserved                                       |
    --|          | For SGMII- Speed                                                             |
    --|          |  1 1 = Reserved                                                              |
    --|          |  1 0 = 1000 Mb/s                                                             |
    --|          |  0 1 = 100 Mb/s                                                              |
    --|          |  0 0 = 10 Mb/s                                                               |
    --|----------+------------------------------------------------------------------------------+
    --| [13:12]  | For 1000BASE-X or 2500BASE-X- Remote Fault                                   |
    --|          |  0 0 = No Error                                                              |
    --|          |  0 1 = Offline                                                               |
    --|          |  1 0 = Link Failure                                                          |
    --|          |  1 1 = Auto-Negotiation Error                                                |
    --|          | For SGMII- Bit[13]: Reserved                                                 |
    --|          | Bit[12]: Duplex Mode                                                         |
    --|          |  1 = Full Duplex                                                             |
    --|          |  0 = Half Duplex                                                             |
    --|----------+------------------------------------------------------------------------------+
    --| [14]     | For 1000BASE-X or 2500BASE-X- Reserved                                       |
    --|          | For SGMII- Acknowledge                                                       |
    -------------+------------------------------------------------------------------------------+
    --| [15]     | For 1000BASE-X or 2500BASE-X- Reserved                                       |
    --|          | For SGMII- PHY Link Status                                                   |
    --|          |  1 = Link Up                                                                 |
    --|          |  0 = Link Down                                                               |
    --+==========+==============================================================================+

    an_adv_config_vector_sfp(0)            <= '0'; -- Reserved in 1000BASE-X
    an_adv_config_vector_sfp(4 downto 1)   <= (others => '0'); -- Reserved
    an_adv_config_vector_sfp(5)            <= '1'; -- Full Duplex
    an_adv_config_vector_sfp(6)            <= '0'; -- Reserved
    an_adv_config_vector_sfp(8 downto 7)   <= "11"; -- Both Symetric Pause and Asymmetric Pause toward link partner
    an_adv_config_vector_sfp(9)            <= '0'; -- Reserved
    an_adv_config_vector_sfp(11 downto 10) <= "00"; -- Reserved
    an_adv_config_vector_sfp(13 downto 12) <= "00"; -- No Error
    an_adv_config_vector_sfp(14)           <= '0'; -- Reserved
    an_adv_config_vector_sfp(15)           <= '0'; -- Reserved

    ---------------------------------------------------------------------------------------------------
    --      Auto-Negotiation Vector
    ---------------------------------------------------------------------------------------------------

    --+==========+==============================================================================+
    --| [0]      | Unidirectional Enable. When set to 1, Enable Transmit irrespective           |
    --|          | of state of RX (802.3ah). When set to 0, Normal operation                    |
    --|----------+------------------------------------------------------------------------------+
    --| [1]      | Loopback Control. When the core with a device-specific transceiver is used,  |
    --|          | this places the core into internal loopback mode. In TBI mode bit 1 is       |
    --|          | connected to ewrap. When set to 1, this signal indicates to the external PMA |
    --|          | module to enter loopback mode.                                               |
    --|----------+------------------------------------------------------------------------------+
    --| [2]      | Power Down, When the Zynq-7000, Virtex-7, Kintex-7, and Artix-7device        |
    --|          | transceivers are used and set to 1, the device-specific transceiver is       |
    --|          | placed in a low-power state. A reset must be applied to clear. In TBI mode   |
    --|          | this bit is unused.                                                          |
    --|----------+------------------------------------------------------------------------------+
    --| [3]      | Isolate. When set to 1, the GMII should be electrically isolated. When set   |
    --|          | to 0, normal operation is enabled.                                           |
    --|----------+------------------------------------------------------------------------------+
    --| [4]      | Auto-Negotiation Enable. This signal is valid only if the AN module is       |
    --|          | enabled through the IP catalog. When set to 1, the signal enables the AN     |
    --|          | feature. When set to 0, AN is disabled.                                      |
    --+==========+==============================================================================+

    config_vector_sfp(0) <= '0';        -- Normal operation
    config_vector_sfp(1) <= '0';        -- Disable Loopback
    config_vector_sfp(2) <= '0';        -- Disable POWERDOWN
    config_vector_sfp(3) <= '0';        -- Disable ISOLATE
    config_vector_sfp(4) <= '1';        -- Enable  AN

    ---------------------------------------------------------------------------------------------------
    --      PCS/PMA
    ---------------------------------------------------------------------------------------------------

    -- Instance for channel 1 and channel 2 are differents because of Transceiver location is
    -- included in .xcix files. Otherwise Core configuration is identical for both instances.
    -- An other solution to avoid two different IP instances is to generate only one core (with
    -- default Transceiver location) and use .xdc file to provide location of each core.

    --TODO Channel 1 is disable

    --    GEN_SELECT_GT_1G_CHAN_1 : if G_SELECT_CHANNEL_PHY = 1 generate
    --        inst_gig_ethernet_pcs_pma_sfp_ch1 : gig_ethernet_pcs_pma_sfp_ch1
    --            generic map(
    --                EXAMPLE_SIMULATION => G_EXAMPLE_SIMULATION
    --            )
    --            port map(
    --                gtrefclk               => gt_refclk,
    --                txp                    => SFP_TX_P,
    --                txn                    => SFP_TX_N,
    --                rxp                    => SFP_RX_P,
    --                rxn                    => SFP_RX_N,
    --                resetdone              => open,
    --                cplllock               => open,
    --                mmcm_reset             => pcs_pma_mmcm_reset,
    --                txoutclk               => pcs_pma_txoutclk,
    --                rxoutclk               => pcs_pma_rxoutclk,
    --                userclk                => pcs_pma_userclk,
    --                userclk2               => pcs_pma_userclk2,
    --                rxuserclk              => pcs_pma_rxuserclk,
    --                rxuserclk2             => pcs_pma_rxuserclk2,
    --                pma_reset              => pcs_pma_reset,
    --                mmcm_locked            => pcs_pma_mmcm_locked,
    --                independent_clock_bufg => CLK_50_MHZ,
    --                gmii_txd               => pcs_pma_gmii_txd,
    --                gmii_tx_en             => pcs_pma_gmii_tx_en,
    --                gmii_tx_er             => pcs_pma_gmii_tx_er,
    --                gmii_rxd               => pcs_pma_gmii_rxd,
    --                gmii_rx_dv             => pcs_pma_gmii_rx_dv,
    --                gmii_rx_er             => pcs_pma_gmii_rx_er,
    --                gmii_isolate           => open,
    --                configuration_vector   => config_vector_sfp(4 downto 0),
    --                an_interrupt           => open,
    --                an_adv_config_vector   => an_adv_config_vector_sfp,
    --                an_restart_config      => '0',
    --                status_vector          => status_vector_sfp(15 downto 0),
    --                reset                  => pcs_pma_reset,
    --                gtpowergood            => open,
    --                signal_detect          => signal_detect_sfp
    --            );
    --    end generate GEN_SELECT_GT_1G_CHAN_1;

    --GEN_SELECT_GT_1G_CHAN_2 : if G_SELECT_CHANNEL_PHY = 2 generate
    inst_gig_ethernet_pcs_pma_sfp_ch2 : gig_ethernet_pcs_pma_sfp_ch2
        generic map(
            EXAMPLE_SIMULATION => G_EXAMPLE_SIMULATION
        )
        port map(
            gtrefclk               => GT_REFCLK,
            txp                    => SFP_TX_P,
            txn                    => SFP_TX_N,
            rxp                    => SFP_RX_P,
            rxn                    => SFP_RX_N,
            resetdone              => open,
            cplllock               => open,
            mmcm_reset             => open,
            txoutclk               => pcs_pma_txoutclk,
            rxoutclk               => pcs_pma_rxoutclk,
            userclk                => userclk,
            userclk2               => userclk2,
            rxuserclk              => rxuserclk,
            rxuserclk2             => rxuserclk,
            pma_reset              => pcs_pma_reset,
            mmcm_locked            => '1',
            independent_clock_bufg => CLK_50_MHZ,
            gmii_txd               => pcs_pma_gmii_txd,
            gmii_tx_en             => pcs_pma_gmii_tx_en,
            gmii_tx_er             => pcs_pma_gmii_tx_er,
            gmii_rxd               => pcs_pma_gmii_rxd,
            gmii_rx_dv             => pcs_pma_gmii_rx_dv,
            gmii_rx_er             => pcs_pma_gmii_rx_er,
            gmii_isolate           => open,
            configuration_vector   => config_vector_sfp(4 downto 0),
            an_interrupt           => open,
            an_adv_config_vector   => an_adv_config_vector_sfp,
            an_restart_config      => '0',
            status_vector          => STATUS_VECTOR_SFP(15 downto 0),
            reset                  => SYS_RST,
            gtpowergood            => open,
            signal_detect          => signal_detect_sfp
        );
    -- end generate GEN_SELECT_GT_1G_CHAN_2;

    -- Meaning of STATUS_VECTOR_SFP :

    --+==========+==============================================================================+
    --| [0]      | Link Status. This signal indicates the status of the link. When High, the    |
    --|          | link is valid: synchronization of the link has been obtained and             |
    --|          | Auto-Negotiation (if present and enabled) has successfully completed and the |
    --|          | reset sequence of the transceiver (if present) has completed.            |
    --|          |                                                                              |
    --|          | When Low, a valid link has not been established. Either link synchronization |
    --|          | has failed or Auto-Negotiation (if present and enabled) has failed to        |
    --|          | complete.                                                                    |
    --|          |                                                                              |
    --|          | When auto-negotiation is enabled, this signal is identical to Status         |
    --|          | register Bit 1.2: Link Status.                                               |
    --|          |                                                                              |
    --|          | When auto-negotiation is disabled, this signal is identical to status_vector |
    --|          | Bit[1]. In this case, either of the bits can be used.                        |
    --|----------+------------------------------------------------------------------------------+
    --| [1]      | Link Synchronization. This signal indicates the state of the synchronization |
    --|          | state machine (IEEE802.3 figure 36-9) which is based on the reception of     |
    --|          | valid 8B/10B code groups. This signal is similar to Bit[0] (Link Status),    |
    --|          | but is not qualified with Auto-Negotiation.                                  |
    --|          | When High, link synchronization has been obtained and in the synchronization |
    --|          | state machine, sync_status=OK.                                               |
    --|          | When Low, synchronization has failed.                                        |
    --|----------+------------------------------------------------------------------------------+
    --| [2]      | RUDI(/C/). The core is receiving /C/ ordered sets (Auto-Negotiation          |
    --|          | Configuration sequences) as defined in IEEE 802.3-2008 clause 36.2.4.10.     |
    --|----------+------------------------------------------------------------------------------+
    --| [3]      | RUDI(/I/). The core is receiving /I/ ordered sets (Idles) as defined in IEEE |
    --|          | 802.3-2008 clause 36.2.4.12.                                                 |
    --|----------+------------------------------------------------------------------------------+
    --| [4]      | RUDI(INVALID). The core has received invalid data while receiving/C/ or /I/  |
    --|          | ordered set as defined in IEEE 802.3-2008 clause 36.2.5.1.6. This can be     |
    --|          | caused, for example, by bit errors occurring in any clock cycle of the /C/   |
    --|          | or /I/ ordered set.                                                          |
    --|----------+------------------------------------------------------------------------------+
    --| [5]      | RXDISPERR. The core has received a running disparity error during the 8B/10B |
    --|          | decoding function.                                                           |
    --|----------+------------------------------------------------------------------------------+
    --| [6]      | RXNOTINTABLE. The core has received a code group which is not recognized     |
    --|          | from the 8B/10B coding tables.                                               |
    --|----------+------------------------------------------------------------------------------+
    --| [7]      | PHY Link Status (SGMII mode only). When operating in SGMII mode, this bit    |
    --|          | represents the link status of the external PHY device attached to the other  |
    --|          | end of the SGMII link (High indicates that the PHY has obtained a link with  |
    --|          | its link partner; Low indicates that is has not linked with its link         |
    --|          | partner). The value reflected is Link Partner Base AN Register 5 bit 15 in   |
    --|          | SGMII MAC mode and the Advertisement Ability register 4 bit 15 in PHY mode.  |
    --|          | However, this bit is only valid after successful completion of               |
    --|          | auto-negotiation across the SGMII link. If SGMII auto-negotiation is         |
    --|          | disabled, then the status of this bit should be ignored.                     |
    --|          | When operating in 1000BASE-X mode, this bit remains Low and should be        |
    --|          | ignored.                                                                     |
    --|----------+------------------------------------------------------------------------------+
    --| [9:8]    | Remote Fault Encoding. This signal indicates the remote fault encoding       |
    --|          | (IEEE802.3 table 37-3). This signal is validated by bit 13 of status_vector  |
    --|          | and is only valid when Auto-Negotiation is enabled. In 1000BASE-X mode these |
    --|          | values reflected Link Partner Base AN Register 5 bits [13:12].               |
    --|          | This signal has no significance when the core is in SGMII mode with PHY side |
    --|          | implementation and indicates 00. In MAC side implementation of the core the  |
    --|          | signal takes the value 10 to indicate the remote fault (Link Partner Base AN |
    --|          | Register 5 bit 15 (Link bit) is 0).                                          |
    --|----------+------------------------------------------------------------------------------+
    --| [11:10]  | SPEED. This signal indicates the speed negotiated and is only valid when     |
    --|          | Auto-Negotiation is enabled. In 1000BASE-X or 2500BASE-X mode these bits are |
    --|          | hard wired to 10 but in SGMII mode the signals encoding is as shown below.   |
    --|          | The value reflected is Link Partner Base AN Register 5 bits [11:10] in MAC   |
    --|          | mode and the Advertisement Ability register 4 bits [11:10] in PHY mode.      |
    --|          |  1 1 = Reserved                                                              |
    --|          |  1 0 = 1000 Mb/s; 2500 Mb/s in 2.5G mode                                     |
    --|          |  0 1 = 100 Mb/s; reserved in 2.5G mode                                       |
    --|          |  0 0 = 10 Mb/s; reserved in 2.5G mode                                        |
    --|----------+------------------------------------------------------------------------------+
    --| [12]     | Duplex Mode. This bit indicates the Duplex mode negotiated with the link     |
    --|          | partner. Indicates bit 5 of Link Partner Base AN register 5 in 1000BASE-X or |
    --|          | 2500BASE-X mode; otherwise bit 12 in SGMII mode. (In SGMII MAC and PHY mode  |
    --|          | it is register bit 5.12.)                                                    |
    --|          |  1 = Full Duplex                                                             |
    --|          |  0 = Half Duplex                                                             |
    --|----------+------------------------------------------------------------------------------+
    --| [13]     | Remote Fault. When this bit is logic one, it indicates that a remote fault   |
    --|          | is detected and the type of remote fault is indicated by                     |
    --|          | status_vector bits[9:8]. This bit reflects MDIO register bit 1.4.            |
    --|          | Note: This bit is only deasserted when a MDIO read is made to status         |
    --|          | register (register1). This signal has no significance in SGMII PHY mode or   |
    --|          | when MDIO is disabled.                                                       |
    --|----------+------------------------------------------------------------------------------+
    --| [15:14]  | Pause. These bits reflect the bits [8:7] of Register 5 (Link Partner Base AN |
    --|          | register). These bits are valid only in 1000BASE-X or 2500BASE-X mode and    |
    --|          | have no significance in SGMII mode.                                          |
    --|          |  0 0 = No Pause                                                              |
    --|          |  0 1 = Symmetric Pause                                                       |
    --|          |  1 0 = Asymmetric Pause towards Link partner                                 |
    --|          |  1 1 = Both Symmetric Pause and Asymmetric Pause towards link partner        |
    --+==========+==============================================================================+

    ---------------------------------------------------------------------------------------------------
    --      Internal signals / outputs
    ---------------------------------------------------------------------------------------------------
    signal_detect_sfp <= (not SFP_MOD_DEF0) and (not SFP_RX_LOS);

    PHY_LAYER_READY <= STATUS_VECTOR_SFP(0);

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
