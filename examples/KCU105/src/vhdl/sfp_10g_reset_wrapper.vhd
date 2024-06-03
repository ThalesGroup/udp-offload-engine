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

library common;
use common.cdc_utils_pkg.cdc_reset_sync;
use common.cdc_utils_pkg.cdc_bit_sync;

entity sfp_10g_reset_wrapper is
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
end sfp_10g_reset_wrapper;

architecture rtl of sfp_10g_reset_wrapper is

    signal gt_tx_reset_in_sync     : std_logic;
    signal gt_tx_reset_in_sync_inv : std_logic;
    signal tx_reset_done_async     : std_logic;

    signal gt_rx_reset_in_sync     : std_logic;
    signal gt_rx_reset_in_sync_inv : std_logic;
    signal rx_reset_done_async     : std_logic;
    signal rx_serdes_reset_done    : std_logic;
    signal rx_reset_done_async_r   : std_logic;
    signal rx_reset_done           : std_logic;

begin

    GTWIZ_RESET_TX_DATAPATH_OUT <= '0';
    GTWIZ_RESET_RX_DATAPATH_OUT <= '0';

    GTWIZ_RESET_ALL <= SYS_RESET;

    inst_cdc_reset_sync_tx_reset : cdc_reset_sync
        generic map(
            G_NB_STAGE    => 3,
            G_NB_CLOCK    => 1,
            G_ACTIVE_ARST => '1'
        )
        port map(
            ARST    => GT_TX_RESET_IN,
            CLK(0)  => GT_TXUSRCLK2,
            SRST(0) => gt_tx_reset_in_sync,
            SRST_N  => open
        );

    gt_tx_reset_in_sync_inv <= not gt_tx_reset_in_sync;
    tx_reset_done_async     <= gt_tx_reset_in_sync_inv or TX_CORE_RESET_IN;

    USR_TX_RESET      <= tx_reset_done_async;
    TX_CORE_RESET_OUT <= tx_reset_done_async;

    inst_cdc_reset_sync_rx_reset : cdc_reset_sync
        generic map(
            G_NB_STAGE    => 3,
            G_NB_CLOCK    => 1,
            G_ACTIVE_ARST => '1'
        )
        port map(
            ARST    => GT_RX_RESET_IN,
            CLK(0)  => GT_TXUSRCLK2,
            SRST(0) => gt_rx_reset_in_sync,
            SRST_N  => open
        );

    gt_rx_reset_in_sync_inv <= not gt_rx_reset_in_sync;
    rx_reset_done_async     <= gt_rx_reset_in_sync_inv or RX_CORE_RESET_IN;

    p_delay_rx_reset_done : process(GT_TXUSRCLK2)
    begin
        if rising_edge(GT_TXUSRCLK2) then
            if gt_tx_reset_in_sync = '1' then
                rx_reset_done_async_r <= '0';
            else
                rx_reset_done_async_r <= rx_reset_done_async;
            end if;
        end if;
    end process p_delay_rx_reset_done;

    inst_cdc_bit_sync_rx_serdes_done : cdc_bit_sync
        generic map(
            G_NB_STAGE   => 3,
            G_ACTIVE_RST => '1',
            G_ASYNC_RST  => false,
            G_RST_VALUE  => '0'
        )
        port map(
            DATA_ASYNC => rx_reset_done_async_r,
            CLK        => GT_RXUSRCLK2,
            RST        => '0',
            DATA_SYNC  => rx_serdes_reset_done
        );

    inst_cdc_bit_sync_rx_reset_done : cdc_bit_sync
        generic map(
            G_NB_STAGE   => 3,
            G_ACTIVE_RST => '1',
            G_ASYNC_RST  => false,
            G_RST_VALUE  => '0'
        )
        port map(
            DATA_ASYNC => rx_reset_done_async_r,
            CLK        => RX_CORE_CLK,
            RST        => '0',
            DATA_SYNC  => rx_reset_done
        );

    RX_SERDES_RESET_OUT <= rx_serdes_reset_done;
    RX_CORE_RESET_OUT   <= rx_reset_done;
    USR_RX_RESET        <= rx_reset_done;

end rtl;
