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
-- UDP MODULE RX
----------------------------------
--
-- This module is used to remove UDP Header from incoming frame 
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_udp_module_rx is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true; -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK      : in  std_logic;
    RST      : in  std_logic;
    -- From Transport Layer
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TUSER  : in  std_logic_vector(31 downto 0); -- Sender IP Address
    S_TREADY : out std_logic;
    -- To External interface
    M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID : out std_logic;
    M_TLAST  : out std_logic;
    M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TUSER  : out std_logic_vector(79 downto 0); -- 79:64 -> Dest port, 63:48 -> Src port, 47:32 -> Size of transport datagram, 31:0 -> Src IP addr
    M_TREADY : in  std_logic
  );
end uoe_udp_module_rx;

architecture rtl of uoe_udp_module_rx is

  ----------------------------
  -- Constants declaration
  ----------------------------

  constant C_TKEEP_WIDTH : positive := ((G_TDATA_WIDTH + 7) / 8);

  constant C_HEADER_WORDS     : integer := integer(floor(real(C_UDP_HEADER_SIZE) / real(C_TKEEP_WIDTH)));
  constant C_HEADER_REMAINDER : integer := C_UDP_HEADER_SIZE mod C_TKEEP_WIDTH;

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------

  -- record for forward data
  type t_forward_data is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tuser  : std_logic_vector(31 downto 0);
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
    tuser  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  ----------------------------
  -- Signals declaration
  ----------------------------

  -- axis bus at intermediate layer
  signal mid        : t_forward_data;
  signal mid_tready : std_logic;

  -- axis bus at output
  signal m_int        : t_forward_data;
  signal m_int_tready : std_logic;

  signal cnt : integer range 0 to C_HEADER_WORDS + 1;

  signal port_dest  : std_logic_vector(15 downto 0);
  signal port_src   : std_logic_vector(15 downto 0);
  signal frame_size : std_logic_vector(15 downto 0);

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
      G_TUSER_WIDTH    => S_TUSER'length,
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
      S_TUSER  => S_TUSER,
      S_TREADY => S_TREADY,
      M_TDATA  => mid.tdata,
      M_TVALID => mid.tvalid,
      M_TLAST  => mid.tlast,
      M_TKEEP  => mid.tkeep,
      M_TUSER  => mid.tuser,
      M_TREADY => mid_tready
    );

  -----------------------------------------------------
  --
  --   FORWARD
  --
  -----------------------------------------------------

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= m_int_tready or (not m_int.tvalid);

  -------------------------------------------------
  -- Register the different signals on the forward path and handle the header deletion
  P_FORWARD_REG : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      m_int      <= C_FORWARD_DATA_INIT;
      cnt        <= 0;
      port_dest  <= (others => '0');
      port_src   <= (others => '0');
      frame_size <= (others => '0');
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        m_int      <= C_FORWARD_DATA_INIT;
        cnt        <= 0;
        port_dest  <= (others => '0');
        port_src   <= (others => '0');
        frame_size <= (others => '0');
      else

        -- Clear TVALID
        if mid_tready = '1' then
          m_int.tvalid <= '0';

          if mid.tvalid = '1' then

            m_int.tdata <= mid.tdata;
            m_int.tuser <= mid.tuser;
            m_int.tlast <= mid.tlast;

            -- reset counter when tlast
            if (mid.tlast = '1') then
              cnt <= 0;
            elsif cnt < (C_HEADER_WORDS + 1) then
              cnt <= cnt + 1;
            end if;

            -- Search field in flow
            for i in 0 to C_TKEEP_WIDTH - 1 loop
              -- Little Endian
              case (cnt * C_TKEEP_WIDTH) + i is
                -- Big Endian
                --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH-1) - i)) is
                when 0 => port_src(15 downto 8)   <= mid.tdata((8 * i) + 7 downto 8 * i); -- Port Src
                when 1 => port_src(7 downto 0)    <= mid.tdata((8 * i) + 7 downto 8 * i);
                when 2 => port_dest(15 downto 8)  <= mid.tdata((8 * i) + 7 downto 8 * i); -- Dest Src
                when 3 => port_dest(7 downto 0)   <= mid.tdata((8 * i) + 7 downto 8 * i);
                when 4 => frame_size(15 downto 8) <= mid.tdata((8 * i) + 7 downto 8 * i); -- Size Header + Payload
                when 5 => frame_size(7 downto 0)  <= mid.tdata((8 * i) + 7 downto 8 * i);
                when others =>
              end case;
            end loop;

            ------------------------------
            -- TVALID / TKEEP
            ------------------------------

            m_int.tkeep  <= mid.tkeep;
            m_int.tvalid <= '1';

            -- Remove Header
            if cnt < C_HEADER_WORDS then
              m_int.tkeep  <= (others => '0');
              m_int.tvalid <= '0';
            end if;

            -- Transition Header / Payload and Header length is not a multiple of C_TKEEP_WIDTH 
            if (cnt = C_HEADER_WORDS) and (C_HEADER_REMAINDER /= 0) then
              for i in 0 to C_TKEEP_WIDTH - 1 loop
                if i < C_HEADER_REMAINDER then
                  m_int.tkeep(i) <= '0';
                end if;
              end loop;
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
  GEN_NO_ALIGN : if C_HEADER_REMAINDER = 0 generate

    -- connecting output bus to the records
    M_TDATA               <= m_int.tdata;
    M_TLAST               <= m_int.tlast;
    M_TUSER(79 downto 48) <= port_dest & port_src;
    M_TUSER(47 downto 32) <= std_logic_vector(unsigned(frame_size) - C_UDP_HEADER_SIZE);
    M_TUSER(31 downto 0)  <= m_int.tuser;
    M_TKEEP               <= m_int.tkeep;
    M_TVALID              <= m_int.tvalid;
    m_int_tready          <= M_TREADY;

  end generate GEN_NO_ALIGN;

  -- Header size isn't multiple of C_TKEEP_WIDTH => need alignment
  GEN_ALIGN : if C_HEADER_REMAINDER /= 0 generate
    signal tuser_i : std_logic_vector(79 downto 0);

  begin

    tuser_i(79 downto 48) <= port_dest & port_src;                                      
    tuser_i(47 downto 32) <= std_logic_vector(unsigned(frame_size) - C_UDP_HEADER_SIZE);
    tuser_i(31 downto 0)  <= m_int.tuser;                                               

    -- Realign frame on first bytes of the first transfer
    inst_axis_pkt_align : axis_pkt_align
      generic map(
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_ASYNC_RST   => G_ASYNC_RST,
        G_TDATA_WIDTH => G_TDATA_WIDTH,
        G_TUSER_WIDTH => 80
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => m_int.tdata,
        S_TVALID => m_int.tvalid,
        S_TLAST  => m_int.tlast,
        S_TUSER  => tuser_i,
        S_TKEEP  => m_int.tkeep,
        S_TREADY => m_int_tready,
        M_TDATA  => M_TDATA,
        M_TVALID => M_TVALID,
        M_TLAST  => M_TLAST,
        M_TUSER  => M_TUSER,
        M_TKEEP  => M_TKEEP,
        M_TREADY => M_TREADY
      );

  end generate GEN_ALIGN;

end rtl;

