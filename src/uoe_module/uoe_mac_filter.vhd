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
use ieee.math_real.all;

----------------------------------
-- MAC FILTER
----------------------------------
--
-- Determine if Rx frames must be kept or eliminated by applying filtering rules
-- All frames which are neither broadcast nor IPv4 multicast are considered to be unicast
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_broadcast_custom;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_fifo;

use work.uoe_module_pkg.all;

entity uoe_mac_filter is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Number of bits used along AXi datapath of UOE
  );
  port(
    -- Global
    CLK                           : in  std_logic;
    RST                           : in  std_logic;
    -- Slave interface
    S_TDATA                       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID                      : in  std_logic;
    S_TLAST                       : in  std_logic;
    S_TKEEP                       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TREADY                      : out std_logic;
    -- Master interface
    M_TDATA                       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID                      : out std_logic;
    M_TLAST                       : out std_logic;
    M_TKEEP                       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TREADY                      : in  std_logic;
    -- Registers interface
    BROADCAST_FILTER_ENABLE       : in  std_logic;
    IPV4_MULTICAST_FILTER_ENABLE  : in  std_logic;
    IPV4_MULTICAST_MAC_ADDR_LSB_1 : in  std_logic_vector(23 downto 0); -- 3 lower bytes of Multicast MAC ADDR
    IPV4_MULTICAST_MAC_ADDR_LSB_2 : in  std_logic_vector(23 downto 0); -- 3 lower bytes of Multicast MAC ADDR
    IPV4_MULTICAST_MAC_ADDR_LSB_3 : in  std_logic_vector(23 downto 0); -- 3 lower bytes of Multicast MAC ADDR
    IPV4_MULTICAST_MAC_ADDR_LSB_4 : in  std_logic_vector(23 downto 0); -- 3 lower bytes of Multicast MAC ADDR
    IPV4_MULTICAST_ADDR_1_ENABLE  : in  std_logic;
    IPV4_MULTICAST_ADDR_2_ENABLE  : in  std_logic;
    IPV4_MULTICAST_ADDR_3_ENABLE  : in  std_logic;
    IPV4_MULTICAST_ADDR_4_ENABLE  : in  std_logic;
    UNICAST_FILTER_ENABLE         : in  std_logic;
    LOCAL_MAC_ADDR                : in  std_logic_vector(47 downto 0);
    -- Status
    FLAG_MAC_FILTER               : out std_logic
  );
end uoe_mac_filter;

architecture rtl of uoe_mac_filter is

  -------------------------------------
  -- Components declaration
  -------------------------------------
  
  component uoe_generic_filter is
    generic(
      G_ACTIVE_RST  : std_logic := '0';
      G_ASYNC_RST   : boolean   := true;
      G_TDATA_WIDTH : integer   := 64
    );
    port(
      CLK             : in  std_logic;
      RST             : in  std_logic;
      INIT_DONE       : in  std_logic;
      S_TDATA         : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      S_TVALID        : in  std_logic;
      S_TLAST         : in  std_logic;
      S_TKEEP         : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      S_TREADY        : out std_logic;
      S_STATUS_TDATA  : in  std_logic;
      S_STATUS_TVALID : in  std_logic;
      S_STATUS_TREADY : out std_logic;
      M_TDATA         : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
      M_TVALID        : out std_logic;
      M_TLAST         : out std_logic;
      M_TKEEP         : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
      M_TREADY        : in  std_logic;
      FLAG            : out std_logic
    );
  end component uoe_generic_filter;

  -------------------------------------
  -- Constants declaration
  -------------------------------------

  constant C_TKEEP_WIDTH : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_TUSER_WIDTH : integer := 7;
  
  constant C_CNT_MAX : integer := integer(ceil(real(6) / real(C_TKEEP_WIDTH)));

  constant C_IDX_IS_BROADCAST   : integer := 0;
  constant C_IDX_IS_MULTICAST   : integer := 1;
  constant C_IDX_IS_MULTICAST_1 : integer := 2;
  constant C_IDX_IS_MULTICAST_2 : integer := 3;
  constant C_IDX_IS_MULTICAST_3 : integer := 4;
  constant C_IDX_IS_MULTICAST_4 : integer := 5;
  constant C_IDX_IS_LOCAL       : integer := 6;

  -- Define size of buffer
  constant C_ADDR_WIDTH : integer := integer(ceil(log2((real(48) / real(G_TDATA_WIDTH)) + 4.0)));

  -------------------------------
  -- Signals declaration
  -------------------------------

  signal axis_bc_tdata  : std_logic_vector((2 * G_TDATA_WIDTH) - 1 downto 0);
  signal axis_bc_tvalid : std_logic_vector(1 downto 0);
  signal axis_bc_tlast  : std_logic_vector(1 downto 0);
  signal axis_bc_tkeep  : std_logic_vector((2 * C_TKEEP_WIDTH) - 1 downto 0);
  signal axis_bc_tready : std_logic_vector(1 downto 0);

  signal axis_fifo_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal axis_fifo_tvalid : std_logic;
  signal axis_fifo_tlast  : std_logic;
  signal axis_fifo_tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
  signal axis_fifo_tready : std_logic;

  -- Extraction MAC Destination
  signal cnt             : integer range 0 to C_CNT_MAX;
  signal axis_mac_tdata  : std_logic_vector(47 downto 0);
  signal axis_mac_tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_mac_tvalid : std_logic;
  signal axis_mac_tready : std_logic;

  signal axis_status_tuser         : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_status_tuser_combine : std_logic;
  signal axis_status_tvalid        : std_logic;
  signal axis_status_tready        : std_logic;

  -------------------------------
  -- Functions declaration
  -------------------------------

  -- Comparison of std_logic_vector
  function slv_compare(constant A, B : in std_logic_vector) return std_logic is
    variable res : std_logic;
  begin
    res := '0';
    if A = B then                       -- @suppress PR5 : by contruction
      res := '1';
    end if;
    return res;
  end function slv_compare;

begin

  -- Broadcast
  inst_axis_broadcast_custom : component axis_broadcast_custom
    generic map(
      G_ACTIVE_RST           => G_ACTIVE_RST,
      G_ASYNC_RST            => G_ASYNC_RST,
      G_TDATA_WIDTH          => G_TDATA_WIDTH,
      G_NB_MASTER            => 2,
      G_REG_SLAVE_FORWARD    => true,
      G_REG_SLAVE_BACKWARD   => true,
      G_REG_MASTERS_FORWARD  => "00",
      G_REG_MASTERS_BACKWARD => "00"
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TKEEP  => S_TKEEP,
      S_TREADY => S_TREADY,
      M_TDATA  => axis_bc_tdata,
      M_TVALID => axis_bc_tvalid,
      M_TLAST  => axis_bc_tlast,
      M_TKEEP  => axis_bc_tkeep,
      M_TREADY => axis_bc_tready
    );

  ---------------------------------------------------------------------
  -- Data Path => Store data in fifo
  ---------------------------------------------------------------------

  -- Axis fifo data
  inst_axis_fifo_buffer : axis_fifo
    generic map(
      G_COMMON_CLK  => true,
      G_ADDR_WIDTH  => C_ADDR_WIDTH,
      G_TDATA_WIDTH => G_TDATA_WIDTH,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST
    )
    port map(
      S_CLK    => CLK,
      S_RST    => RST,
      S_TDATA  => axis_bc_tdata(G_TDATA_WIDTH - 1 downto 0),
      S_TVALID => axis_bc_tvalid(0),
      S_TLAST  => axis_bc_tlast(0),
      S_TKEEP  => axis_bc_tkeep(C_TKEEP_WIDTH - 1 downto 0),
      S_TREADY => axis_bc_tready(0),
      M_CLK    => CLK,
      M_TDATA  => axis_fifo_tdata,
      M_TVALID => axis_fifo_tvalid,
      M_TLAST  => axis_fifo_tlast,
      M_TKEEP  => axis_fifo_tkeep,
      M_TREADY => axis_fifo_tready
    );

  axis_bc_tready(1) <= axis_mac_tready or (not axis_mac_tvalid);

  -- Extract Destination MAC Address
  P_EXTRACT_DEST : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_mac_tdata  <= (others => '0');
      axis_mac_tvalid <= '0';
      cnt             <= 0;
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_mac_tdata  <= (others => '0');
        axis_mac_tvalid <= '0';
        cnt             <= 0;
      else

        -- register
        if axis_bc_tready(1) = '1' then

          -- may acquire new data
          if (axis_bc_tvalid(1) = '1') then

            -- Counter
            if (axis_bc_tlast(1) = '1') then
              cnt <= 0;
            elsif cnt < C_CNT_MAX then
              cnt <= cnt + 1;
            end if;

            --TVALID
            if cnt = (C_CNT_MAX - 1) then
              axis_mac_tvalid <= '1';
            else
              axis_mac_tvalid <= '0';
            end if;

            -- TDATA
            for i in 0 to C_TKEEP_WIDTH - 1 loop
              -- Little Endian
              case ((cnt * C_TKEEP_WIDTH) + i) is
                -- Big Endian
                --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                when 0 => axis_mac_tdata(47 downto 40) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 1 => axis_mac_tdata(39 downto 32) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 2 => axis_mac_tdata(31 downto 24) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 3 => axis_mac_tdata(23 downto 16) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 4 => axis_mac_tdata(15 downto 8)  <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 5 => axis_mac_tdata(7 downto 0)   <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when others =>
              end case;
            end loop;

          else
            -- change only valid state to avoid logic toggling (and save power)
            axis_mac_tvalid <= '0';
          end if;
        end if;

      end if;
    end if;
  end process P_EXTRACT_DEST;

  ------------------------------------------
  -- Compare MAC DESTINATION

  axis_mac_tuser(C_IDX_IS_BROADCAST)   <= not (slv_compare(C_BROADCAST_MAC_ADDR, axis_mac_tdata) and BROADCAST_FILTER_ENABLE);
  axis_mac_tuser(C_IDX_IS_MULTICAST)   <= slv_compare(C_MULTICAST_MAC_ADDR_MSB, axis_mac_tdata(47 downto 24)) and IPV4_MULTICAST_FILTER_ENABLE;
  axis_mac_tuser(C_IDX_IS_MULTICAST_1) <= slv_compare(IPV4_MULTICAST_MAC_ADDR_LSB_1, axis_mac_tdata(23 downto 0)) and IPV4_MULTICAST_ADDR_1_ENABLE;
  axis_mac_tuser(C_IDX_IS_MULTICAST_2) <= slv_compare(IPV4_MULTICAST_MAC_ADDR_LSB_2, axis_mac_tdata(23 downto 0)) and IPV4_MULTICAST_ADDR_2_ENABLE;
  axis_mac_tuser(C_IDX_IS_MULTICAST_3) <= slv_compare(IPV4_MULTICAST_MAC_ADDR_LSB_3, axis_mac_tdata(23 downto 0)) and IPV4_MULTICAST_ADDR_3_ENABLE;
  axis_mac_tuser(C_IDX_IS_MULTICAST_4) <= slv_compare(IPV4_MULTICAST_MAC_ADDR_LSB_4, axis_mac_tdata(23 downto 0)) and IPV4_MULTICAST_ADDR_4_ENABLE;
  axis_mac_tuser(C_IDX_IS_LOCAL)       <= slv_compare(LOCAL_MAC_ADDR, axis_mac_tdata) or (not UNICAST_FILTER_ENABLE);

  inst_axis_register_compare : component axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => 1,
      G_TUSER_WIDTH  => C_TUSER_WIDTH,
      G_REG_FORWARD  => true,
      G_REG_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TVALID => axis_mac_tvalid,
      S_TUSER  => axis_mac_tuser,
      S_TREADY => axis_mac_tready,
      M_TVALID => axis_status_tvalid,
      M_TUSER  => axis_status_tuser,
      M_TREADY => axis_status_tready
    );

  ------------------------------------------
  -- Filter ('0' => Valid, '1' => Invalid)
  axis_status_tuser_combine <= '1' when (axis_status_tuser(C_IDX_IS_BROADCAST) = '0') else
                               '1' when (axis_status_tuser(C_IDX_IS_MULTICAST) = '1') and (axis_mac_tuser(C_IDX_IS_MULTICAST_4 downto C_IDX_IS_MULTICAST_1) = "0000") else
                               '1' when (axis_status_tuser(C_IDX_IS_MULTICAST) = '0') and (axis_status_tuser(C_IDX_IS_LOCAL) = '0') else
                               '0';


  inst_uoe_generic_filter : uoe_generic_filter
    generic map(
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => G_ASYNC_RST,
      G_TDATA_WIDTH => G_TDATA_WIDTH
    )
    port map(
      CLK             => CLK,
      RST             => RST,
      INIT_DONE       => '1',
      S_TDATA         => axis_fifo_tdata,
      S_TVALID        => axis_fifo_tvalid,
      S_TLAST         => axis_fifo_tlast,
      S_TKEEP         => axis_fifo_tkeep,
      S_TREADY        => axis_fifo_tready,
      S_STATUS_TDATA  => axis_status_tuser_combine,
      S_STATUS_TVALID => axis_status_tvalid,
      S_STATUS_TREADY => axis_status_tready,
      M_TDATA         => M_TDATA,
      M_TVALID        => M_TVALID,
      M_TLAST         => M_TLAST,
      M_TKEEP         => M_TKEEP,
      M_TREADY        => M_TREADY,
      FLAG            => FLAG_MAC_FILTER
    );
  


end rtl;

