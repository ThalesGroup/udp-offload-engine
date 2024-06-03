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
-- RAW ETHERNET TX
----------------------------------
--
-- This module is used to insert MAC Header in incoming frames
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_raw_ethernet_tx is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : integer   := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK            : in  std_logic;
    RST            : in  std_logic;
    INIT_DONE      : in  std_logic;
    -- From External interface
    S_TDATA        : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID       : in  std_logic;
    S_TLAST        : in  std_logic;
    S_TKEEP        : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID          : in  std_logic_vector(15 downto 0); -- Size of incoming frame = Ethertype in raw Ethernet
    S_TREADY       : out std_logic;
    -- To Internet Layer
    M_TDATA        : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID       : out std_logic;
    M_TLAST        : out std_logic;
    M_TKEEP        : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TREADY       : in  std_logic;
    -- Registers interface
    DEST_MAC_ADDR  : in  std_logic_vector(47 downto 0); -- Destination MAC
    LOCAL_MAC_ADDR : in  std_logic_vector(47 downto 0) -- Source MAC
  );
end uoe_raw_ethernet_tx;

architecture rtl of uoe_raw_ethernet_tx is

  -------------------------------
  -- Constants declaration
  -------------------------------

  constant C_TKEEP_WIDTH : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_TID_WIDTH   : integer := 16;
  constant C_CNT_MAX     : integer := integer(ceil(real(C_MAC_HEADER_SIZE) / real(C_TKEEP_WIDTH)));

  -------------------------------
  -- Functions declaration
  -------------------------------
  function get_alignment return integer is
    variable align : integer range 0 to C_TKEEP_WIDTH - 1;
  begin
    align := 0;
    if (C_MAC_HEADER_SIZE mod C_TKEEP_WIDTH) /= 0 then
      align := (C_TKEEP_WIDTH - (C_MAC_HEADER_SIZE mod C_TKEEP_WIDTH));
    end if;
    return align;
  end function get_alignment;

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
    tvalid : std_logic;
  end record t_forward_data;

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  -- constant for record initialization
  constant C_FORWARD_DATA_INIT : t_forward_data := (
    tdata  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast  => '0',                      -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  constant C_ALIGN : integer := get_alignment;
  
  ----------------------------
  -- Signals declaration
  ----------------------------

  -- axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tid    : std_logic_vector(C_TID_WIDTH-1 downto 0);
  signal mid_tready : std_logic;

  -- axis bus at output
  signal m_int        : t_forward_data;
  signal m_int_tready : std_logic;

  signal cnt                : integer range 0 to C_CNT_MAX;
  signal header_in_progress : std_logic;

begin

  -----------------------------------------------------
  --
  --   BACKWARD Register
  --
  -----------------------------------------------------
  inst_axis_register_backward : axis_register
    generic map(
      G_ACTIVE_RST     => G_ACTIVE_RST,
      G_ASYNC_RST      => G_ASYNC_RST,
      G_TDATA_WIDTH    => G_TDATA_WIDTH,
      G_TID_WIDTH      => C_TID_WIDTH,
      G_REG_FORWARD    => false,
      G_REG_BACKWARD   => true,
      G_FULL_BANDWIDTH => true
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => S_TDATA,
      S_TVALID => S_TVALID,
      S_TLAST  => S_TLAST,
      S_TKEEP  => S_TKEEP,
      S_TID    => S_TID,
      S_TREADY => S_TREADY,
      M_TDATA  => mid.tdata,
      M_TVALID => mid.tvalid,
      M_TLAST  => mid.tlast,
      M_TKEEP  => mid.tkeep,
      M_TID    => mid_tid,
      M_TREADY => mid_tready
    );

  -----------------------------------------------------
  --
  --  Header insertion (FORWARD Path)
  --
  -----------------------------------------------------

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= (m_int_tready or (not m_int.tvalid)) and (not header_in_progress);

  -------------------------------------------------
  -- Register the different signals on the forward path and handle the header deletion
  P_FORWARD_REG : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      m_int              <= C_FORWARD_DATA_INIT;
      cnt                <= 0;
      header_in_progress <= '1';
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        m_int              <= C_FORWARD_DATA_INIT;
        cnt                <= 0;
        header_in_progress <= '1';

      else

        if (m_int_tready = '1') or (m_int.tvalid /= '1') then
          -- Clear TVALID
          m_int.tvalid <= '0';

          if (INIT_DONE = '1') and (mid.tvalid = '1') then
            -- Valid output
            m_int.tvalid <= '1';
            m_int.tlast  <= '0';

            -- Header
            if cnt /= C_CNT_MAX then
              cnt <= cnt + 1;

              -- if last word of the header
              if cnt = (C_CNT_MAX - 1) then
                header_in_progress <= '0';
              end if;

              -- TDATA and TKEEP
              for i in 0 to C_TKEEP_WIDTH - 1 loop
                -- Little Endian
                case ((cnt * C_TKEEP_WIDTH) + i) is
                  -- Big Endian
                  --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                  when C_ALIGN + 0  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(47 downto 40);
                  when C_ALIGN + 1  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(39 downto 32);
                  when C_ALIGN + 2  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(31 downto 24);
                  when C_ALIGN + 3  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(23 downto 16);
                  when C_ALIGN + 4  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(15 downto 8);
                  when C_ALIGN + 5  => m_int.tdata((8 * i) + 7 downto 8 * i) <= DEST_MAC_ADDR(7 downto 0);
                  when C_ALIGN + 6  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(47 downto 40);
                  when C_ALIGN + 7  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(39 downto 32);
                  when C_ALIGN + 8  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(31 downto 24);
                  when C_ALIGN + 9  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(23 downto 16);
                  when C_ALIGN + 10 => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(15 downto 8);
                  when C_ALIGN + 11 => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(7 downto 0);
                  when C_ALIGN + 12 => m_int.tdata((8 * i) + 7 downto 8 * i) <= mid_tid(15 downto 8);
                  when C_ALIGN + 13 => m_int.tdata((8 * i) + 7 downto 8 * i) <= mid_tid(7 downto 0);
                  when others =>
                    m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                end case;

                -- Little Endian
                if ((cnt * C_TKEEP_WIDTH) + i) >= C_ALIGN then
                  -- Big Endian
                  --if ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) < 14 then
                  m_int.tkeep(i) <= '1';
                else
                  m_int.tkeep(i) <= '0';
                end if;
              end loop;

            -- Payload
            else
              m_int.tdata <= mid.tdata;
              m_int.tlast <= mid.tlast;
              m_int.tkeep <= mid.tkeep;

              if mid.tlast = '1' then
                cnt                <= 0;
                header_in_progress <= '1';
              end if;
            end if;

          else
            -- change only valid state to avoid logic toggling (and save power)
            m_int.tvalid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process P_FORWARD_REG;

    -- Header size is multiple of C_TKEEP_WIDTH
  GEN_NO_ALIGN : if C_ALIGN = 0 generate

    -- connecting output bus to the records
    M_TDATA      <= m_int.tdata;
    M_TLAST      <= m_int.tlast;
    M_TKEEP      <= m_int.tkeep;
    M_TVALID     <= m_int.tvalid;
    m_int_tready <= M_TREADY;

  end generate GEN_NO_ALIGN;

  -- Header size isn't multiple of C_TKEEP_WIDTH => need alignment
  GEN_ALIGN : if C_ALIGN /= 0 generate

    -- Realign frame on first bytes of the first transfer
    inst_axis_pkt_align : axis_pkt_align
      generic map(
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_ASYNC_RST   => G_ASYNC_RST,
        G_TDATA_WIDTH => G_TDATA_WIDTH
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => m_int.tdata,
        S_TVALID => m_int.tvalid,
        S_TLAST  => m_int.tlast,
        S_TKEEP  => m_int.tkeep,
        S_TREADY => m_int_tready,
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TKEEP  => M_TKEEP,
        M_TREADY => M_TREADY
      );

  end generate GEN_ALIGN;

end rtl;
