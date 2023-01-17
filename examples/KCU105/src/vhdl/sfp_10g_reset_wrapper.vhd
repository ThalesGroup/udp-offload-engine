-- ******************************************************************************************
-- * This program is the Confidential and Proprietary product of THALES.                    *
-- * Any unauthorized use, reproduction or transfer of this program is strictly prohibited. *
-- * Copyright (c) 2022 THALES SGF. All Rights Reserved.              *
-- ******************************************************************************************
-- -------------------------------------------------------------------------------
-- Company                : SGF
-- Authors                : Chiron Mathias
-- Content description    : VHDL translation of Verilog reset wrapper for shared logic 10G subsystem
-- Limitations            :
-- Coding & Design Std    : 87100217_DDQ_GRP_EN / 87206624_DDQ_GRP_EN
-- VHDL version           : VHDL-2008
-- -------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    -- CDC
    component cdc_reset_sync is
        generic(
            G_NB_STAGE    : integer range 2 to integer'high := 2;
            G_NB_CLOCK    : positive                        := 5;
            G_ACTIVE_ARST : std_logic                       := '1'
        );
        port(
            -- asynchronous domain
            ARST   : in  std_logic;
            -- synchronous domain
            CLK    : in  std_logic_vector(G_NB_CLOCK - 1 downto 0);
            SRST   : out std_logic_vector(G_NB_CLOCK - 1 downto 0);
            SRST_N : out std_logic_vector(G_NB_CLOCK - 1 downto 0)
        );
    end component cdc_reset_sync;

    component cdc_bit_sync is
        generic(
            G_NB_STAGE   : integer range 2 to integer'high := 2;
            G_ACTIVE_RST : std_logic                       := '1';
            G_ASYNC_RST  : boolean                         := false;
            G_RST_VALUE  : std_logic                       := '0'
        );
        port(
          -- asynchronous domain
          DATA_ASYNC : in  std_logic;
          -- synchronous domain
          CLK        : in  std_logic;
          RST        : in  std_logic;
          DATA_SYNC  : out std_logic
        );
    end component cdc_bit_sync;

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
