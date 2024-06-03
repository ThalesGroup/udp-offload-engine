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
-- FRAME SWITCH TDEST
----------------------------------
--
-- Analyse Header to define the destination of the current frame (RAW, ARP, MAC or EXT)
-- according to Ethertype and IPV4 Protocol fields values
--
-- Functional until 128 bits data width
--
-- Header MAC (14 Bytes)
--  |------|------|------|------|------|------|------|------|------|------|------|------|------|------|
--  |            Dest MAC Address             |             SRC MAC Address             |  EtherType  |
--  |------|------|------|------|------|------|------|------|------|------|------|------|------|------|
-- Checksum is done by the TEMAC IP
--
--
-- Header IPV4 (20 Bytes)
--  |-------------|-------------|-------------|-------------|
--  | Vers.  IHL  |     ToS     |        Total Length       |
--  |-------------|-------------|-------------|-------------|
--  |         Frame Id          |Ind|    Frag offset        |
--  |-------------|-------------|-------------|-------------|
--  |     TTL     |   Protocol  |     Header Checksum       |
--  |-------------|-------------|-------------|-------------|
--  |                       IP Source                       |
--  |-------------|-------------|-------------|-------------|
--  |                     IP Destination                    |
--  |-------------|-------------|-------------|-------------|
--  |     Options + Padding (Not handle by this module)     |
--  |-------------|-------------|-------------|-------------|
-- IHL : Internet Header Length
-- ToS : Type of Service
-- TTL : Time To Live
--
--
-- Header UDP (8 bytes)
--  |-------------|-------------|-------------|-------------|
--  |        Port Source        |        Port Dest          |
--  |-------------|-------------|-------------|-------------|
--  | Size of UDP Head. + Payl. |    Checksum (Optional)    |
--  |-------------|-------------|-------------|-------------|
--
-- Header TCP (20 bytes)
--  |-------------|-------------|-------------|-------------|
--  |        Port Source        |        Port Dest          |
--  |-------------|-------------|-------------|-------------|
--  |                    Sequence Number                    |
--  |-------------|-------------|-------------|-------------|
--  |                Acknowledgement Number                 |
--  |-------------|-------------|-------------|-------------|
--  |  DO  | RSV  |    flags    |       Window size         |
--  |-------------|-------------|-------------|-------------|
--  |   Header + Data Checksum  |      Urgent Pointer       |
--  |-------------|-------------|-------------|-------------|
--  |            Options + Padding (Facultative)            |
--  |-------------|-------------|-------------|-------------|
----------------------------------

library common;
use common.axis_utils_pkg.axis_broadcast_custom;
use common.axis_utils_pkg.axis_combine;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_fifo;

use work.uoe_module_pkg.all;


entity uoe_frame_switch_tdest is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 32     -- Width of the tdata vector of the stream
  );
  port(
    -- GLOBAL
    CLK      : in  std_logic;
    RST      : in  std_logic;
    -- SLAVE INTERFACE
    S_TDATA  : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID : in  std_logic;
    S_TLAST  : in  std_logic;
    S_TKEEP  : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TREADY : out std_logic;
    -- MASTER INTERFACE
    M_TDATA  : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID : out std_logic;
    M_TLAST  : out std_logic;
    M_TKEEP  : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TDEST  : out std_logic_vector(2 downto 0);
    M_TREADY : in  std_logic
  );
end uoe_frame_switch_tdest;

architecture rtl of uoe_frame_switch_tdest is

  ----------------------------
  -- Constants declaration
  ----------------------------

  constant C_TKEEP_WIDTH : integer := ((G_TDATA_WIDTH + 7) / 8);
  constant C_TUSER_WIDTH : integer := 11;

  constant C_IDX_ETHERTYPE_IS_ARP        : integer := 0;
  constant C_IDX_ETHERTYPE_IS_RAW        : integer := 1;
  constant C_IDX_ETHERTYPE_IS_IPV4       : integer := 2;
  constant C_IDX_IPV4_PROTOCOL_IS_UDP    : integer := 3;
  constant C_IDX_IPV4_PROTOCOL_IS_TCP    : integer := 4;
  constant C_IDX_IPV4_PROTOCOL_IS_ICMPV4 : integer := 5;
  constant C_IDX_IPV4_PROTOCOL_IS_IGMP   : integer := 6;
  constant C_IDX_DEST_PORT_IS_STANDARD   : integer := 7;
  constant C_IDX_DEST_PORT_IS_NBSN       : integer := 8;
  constant C_IDX_IPV4_FRAG_IS_FIRST      : integer := 9;
  constant C_IDX_IPV4_FRAG_MORE          : integer := 10;

  -- Minimum Ethernet frame size => 60 bytes 
  -- Size of MAC Header  => 14 bytes
  -- Size of IPV4 Header => 20 bytes
  -- Size of UDP Header  => 8 bytes   -|__ Only the fourth bytes are needed in this module
  -- Size of TCP Header  => 20 bytes  -|
  constant C_ETH_HEADER_SIZE : integer := (14 + 20) + 4;  --38
  constant C_CNT_MAX         : integer := integer(ceil(real(C_ETH_HEADER_SIZE) / real(C_TKEEP_WIDTH)));

  constant C_ADDR_WIDTH : integer := integer(ceil(log2((real(C_ETH_HEADER_SIZE) / real(C_TKEEP_WIDTH)) + 4.0)));
  -- Add 4 space in the data fifo to compensate latency of the decoding path
  -- Ex : TDATA : 64 Bits (8 bytes) => ceil(log2(38/8 + 4)) = ceil(log2(8.75)) = 4

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

  signal cnt : integer range 0 to C_CNT_MAX;

  signal ethertype         : std_logic_vector(15 downto 0);
  signal protocol          : std_logic_vector(7 downto 0);
  signal udp_tcp_dest_port : std_logic_vector(15 downto 0);
  signal frag_more         : std_logic;
  signal frag_offset       : std_logic_vector(12 downto 0);

  signal axis_header_tid    : std_logic_vector(15 downto 0); -- Frame Identification
  signal axis_header_tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_header_tvalid : std_logic;
  signal axis_header_tready : std_logic;

  signal axis_header_reg_tuser  : std_logic_vector(C_TUSER_WIDTH - 1 downto 0);
  signal axis_header_reg_tid    : std_logic_vector(15 downto 0);
  signal axis_header_reg_tvalid : std_logic;
  signal axis_header_reg_tready : std_logic;

  signal axis_decode_tdest  : std_logic_vector(2 downto 0);
  signal axis_decode_tvalid : std_logic;
  signal axis_decode_tready : std_logic;

  signal frame_id_reg          : std_logic_vector(15 downto 0);
  signal frag_frame_in_process : std_logic;
  signal frag_tdest            : std_logic_vector(2 downto 0);

  -- we can't use open when signal output is split
  signal dummy : std_logic;

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

  ---------------------------------------------------------------------
  -- Input Broadcast
  ---------------------------------------------------------------------
  inst_axis_broadcast_custom : axis_broadcast_custom
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

  ---------------------------------------------------------------------
  -- Decoding header and define TDEST
  ---------------------------------------------------------------------

  axis_bc_tready(1) <= axis_header_tready or (not axis_header_tvalid);

  -- Extract useful field from the header
  P_HEADER_EXTRACT : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      cnt                <= 0;
      axis_header_tvalid <= '0';
      axis_header_tid    <= (others => '0');
      ethertype          <= (others => '0');
      frag_more          <= '0';
      frag_offset        <= (others => '0');
      protocol           <= (others => '0');
      udp_tcp_dest_port  <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        cnt                <= 0;
        axis_header_tvalid <= '0';
        axis_header_tid    <= (others => '0');
        ethertype          <= (others => '0');
        frag_more          <= '0';
        frag_offset        <= (others => '0');
        protocol           <= (others => '0');
        udp_tcp_dest_port  <= (others => '0');

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
              axis_header_tvalid <= '1';
            else
              axis_header_tvalid <= '0';
            end if;

            -- TDATA
            for i in 0 to C_TKEEP_WIDTH - 1 loop
              -- Little Endian
              case ((cnt * C_TKEEP_WIDTH) + i) is
                -- Big Endian
                --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                -- Header MAC => EtherType (Bytes 13 and 14)
                when 12 => ethertype(15 downto 8) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 13 => ethertype(7 downto 0) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                -- Header IPV4 => Fragments Identification (Bytes 19 and 20)
                when 18 => axis_header_tid(15 downto 8) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 19 => axis_header_tid(7 downto 0) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                -- Header IPV4 => Fragments Indicateur and Offsets(Bytes 21 and 22)
                when 20 =>
                  frag_more                <= axis_bc_tdata((8 * i) + (5 + G_TDATA_WIDTH));
                  frag_offset(12 downto 8) <= axis_bc_tdata((8 * i) + (4 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 21 => frag_offset(7 downto 0) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                -- Header IPV4 => Protocol  (Bytes 24)
                when 23 => protocol <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                -- Header UDP/TCP => Destination port(Bytes 37 and 38)
                when 36 => udp_tcp_dest_port(15 downto 8) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when 37 => udp_tcp_dest_port(7 downto 0) <= axis_bc_tdata((8 * i) + (7 + G_TDATA_WIDTH) downto (8 * i) + G_TDATA_WIDTH);
                when others =>
              end case;
            end loop;

          else
            -- change only valid state to avoid logic toggling (and save power)
            axis_header_tvalid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process P_HEADER_EXTRACT;

  ------------------------------------------
  -- Compare Fields
  axis_header_tuser(C_IDX_ETHERTYPE_IS_ARP)        <= slv_compare(ethertype, C_ETHERTYPE_ARP);
  axis_header_tuser(C_IDX_ETHERTYPE_IS_RAW)        <= '1' when unsigned(ethertype) <= unsigned(C_ETHERTYPE_RAW_MAX) else '0';
  axis_header_tuser(C_IDX_ETHERTYPE_IS_IPV4)       <= slv_compare(ethertype, C_ETHERTYPE_IPV4);
  axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_UDP)    <= slv_compare(protocol, C_PROTOCOL_UDP);
  axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_TCP)    <= slv_compare(protocol, C_PROTOCOL_TCP);
  axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_ICMPV4) <= slv_compare(protocol, C_PROTOCOL_ICMPV4);
  axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_IGMP)   <= slv_compare(protocol, C_PROTOCOL_IGMP);
  axis_header_tuser(C_IDX_DEST_PORT_IS_STANDARD)   <= '1' when unsigned(udp_tcp_dest_port) <= unsigned(C_STANDARD_PORT_MAX) else '0';
  axis_header_tuser(C_IDX_DEST_PORT_IS_NBSN)       <= slv_compare(udp_tcp_dest_port, C_NBNS_NS_PORT) or slv_compare(udp_tcp_dest_port, C_NBNS_DGM_PORT) or slv_compare(udp_tcp_dest_port, C_NBNS_SSN_PORT);
  axis_header_tuser(C_IDX_IPV4_FRAG_IS_FIRST)      <= slv_compare(frag_offset, std_logic_vector(to_unsigned(0, 13)));
  axis_header_tuser(C_IDX_IPV4_FRAG_MORE)          <= frag_more;

  -- Add register to improve timings
  inst_axis_register_header : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TDATA_WIDTH  => 1,
      G_TUSER_WIDTH  => C_TUSER_WIDTH,
      G_TID_WIDTH    => 16,
      G_REG_FORWARD  => true,
      G_REG_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TVALID => axis_header_tvalid,
      S_TUSER  => axis_header_tuser,
      S_TID    => axis_header_tid,
      S_TREADY => axis_header_tready,
      M_TVALID => axis_header_reg_tvalid,
      M_TUSER  => axis_header_reg_tuser,
      M_TID    => axis_header_reg_tid,
      M_TREADY => axis_header_reg_tready
    );

  axis_header_reg_tready <= axis_decode_tready or (not axis_decode_tvalid);

  -- Control
  P_DECODE : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_decode_tdest     <= (others => '0');
      axis_decode_tvalid    <= '0';
      frame_id_reg          <= (others => '0');
      frag_frame_in_process <= '0';
      frag_tdest            <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_decode_tdest     <= (others => '0');
        axis_decode_tvalid    <= '0';
        frame_id_reg          <= (others => '0');
        frag_frame_in_process <= '0';
        frag_tdest            <= (others => '0');

      else

        -- Register Data bus
        if axis_header_reg_tready = '1' then
          
          -- may acquire new data
          if axis_header_reg_tvalid = '1' then

            axis_decode_tvalid <= '1';

            -- From MAC HEADER
            if axis_header_reg_tuser(C_IDX_ETHERTYPE_IS_ARP) = '1' then
              axis_decode_tdest <= C_TDEST_ARP;

            elsif axis_header_reg_tuser(C_IDX_ETHERTYPE_IS_RAW) = '1' then
              axis_decode_tdest <= C_TDEST_RAW;

            elsif not (axis_header_reg_tuser(C_IDX_ETHERTYPE_IS_IPV4) = '1') then
              axis_decode_tdest <= C_TDEST_TRASH;

            else

              -- From IPV4 header
              -- If this frame is the first of a fragmented packet (more fragments with frag offset=0)
              -- Or if this frame is a non-fragmented packet (no more frag and offset = 0)
              if axis_header_reg_tuser(C_IDX_IPV4_FRAG_IS_FIRST) = '1' then

                -- Memorize frame ID if new frame
                if (axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1') and (not (frag_frame_in_process = '1')) then
                  frame_id_reg          <= axis_header_reg_tid;
                  frag_frame_in_process <= '1';
                end if;

                -- First, determine the appropriate tdest
                -- Special case : we receive the first frame of a fragmented packet while we are already processing a fragmented packet
                if (axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1') and (frag_frame_in_process = '1') then
                  axis_decode_tdest <= C_TDEST_TRASH;

                -- If we recognize UDP or TCP, tdest cannot be determined here
                elsif axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_UDP) = '1' then

                  -- Specific case : eliminate NBNS because it is sends frequent requests (Windows PC) that we cannot handle in hardware and we do not need in software
                  if axis_header_tuser(C_IDX_DEST_PORT_IS_NBSN) = '1' then
                    axis_decode_tdest <= C_TDEST_TRASH;
                    if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                      frag_tdest <= C_TDEST_TRASH;
                    end if;

                  -- Standard protocols use ports between 0 and 1023 (included) and was not handle in UOE
                  elsif axis_header_tuser(C_IDX_DEST_PORT_IS_STANDARD) = '1' then
                    axis_decode_tdest <= C_TDEST_EXT;
                    if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                      frag_tdest <= C_TDEST_EXT;
                    end if;

                  -- if this frame does not contain a standard protocol, direct it to UDP offload engine
                  else
                    axis_decode_tdest <= C_TDEST_MAC_SHAPING;
                    if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                      frag_tdest <= C_TDEST_MAC_SHAPING;
                    end if;

                  end if;

                -- TCP Protocol
                elsif axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_TCP) = '1' then

                  -- Standard protocols use ports between 0 and 1023 (included). Includes TCP/80 for HTTP, TCP/67 for DHCP
                  -- if this frame contains a known (standard) protocol, direct it to external interface
                  if axis_header_tuser(C_IDX_DEST_PORT_IS_STANDARD) = '1' then
                    axis_decode_tdest <= C_TDEST_EXT;
                    
                    if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                      frag_tdest <= C_TDEST_EXT;
                    end if;

                  -- if this frame does not contain a standard protocol, trash it
                  else
                    axis_decode_tdest <= C_TDEST_TRASH;
                    
                    if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                      frag_tdest <= C_TDEST_TRASH;
                    end if;
                  end if;

                -- ICMPv4 and IGMP could be handle by software => External interface
                elsif (axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_ICMPV4) = '1') or (axis_header_tuser(C_IDX_IPV4_PROTOCOL_IS_IGMP) = '1') then
                  axis_decode_tdest <= C_TDEST_EXT;
                  
                  if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                    frag_tdest <= C_TDEST_EXT;
                  end if;

                -- Other protocol are not handle
                else
                  axis_decode_tdest <= C_TDEST_TRASH;
                  
                  if axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1' then
                    frag_tdest <= C_TDEST_TRASH;
                  end if;

                end if;

              else

                -- This packet is not the first of a fragmented frame

                -- Check if the frame id of the current fragment corresponds to the previous
                if ((frag_frame_in_process = '1') and (axis_header_reg_tid = frame_id_reg)) then

                  -- use memorize destination
                  axis_decode_tdest <= frag_tdest;

                  -- If this is the last fragment, clear the flag
                  if not (axis_header_reg_tuser(C_IDX_IPV4_FRAG_MORE) = '1') then
                    frag_frame_in_process <= '0';
                  end if;

                else
                  axis_decode_tdest <= C_TDEST_TRASH;
                end if;

              end if;
            end if;
          else
            -- change only valid state to avoid logic toggling (and save power)
            axis_decode_tvalid <= '0';
          end if;
        end if;

      end if;
    end if;
  end process P_DECODE;

  axis_decode_tready <= axis_fifo_tvalid and axis_fifo_tready and axis_fifo_tlast;

  ---------------------------------------------------------------------
  -- Combine Data and TDEST
  ---------------------------------------------------------------------
  inst_axis_combine : axis_combine
    generic map(
      G_ACTIVE_RST       => G_ACTIVE_RST,
      G_ASYNC_RST        => G_ASYNC_RST,
      G_TDATA_WIDTH      => G_TDATA_WIDTH,
      G_TDEST_WIDTH      => 3,
      G_NB_SLAVE         => 2,
      G_REG_OUT_FORWARD  => true,
      G_REG_OUT_BACKWARD => true
    )
    port map(
      --GLOBAL
      CLK         => CLK,
      RST         => RST,
      --SLAVE INTERFACE
      S_TDATA     => axis_fifo_tdata,
      S_TVALID(0) => axis_fifo_tvalid,
      S_TVALID(1) => axis_decode_tvalid,
      S_TLAST     => axis_fifo_tlast,
      S_TKEEP     => axis_fifo_tkeep,
      S_TDEST     => axis_decode_tdest,
      S_TREADY(0) => axis_fifo_tready,
      S_TREADY(1) => dummy,             -- not used, we can't use open when signal output is split
      --MASTER INTERFACE
      M_TDATA     => M_TDATA,
      M_TVALID    => M_TVALID,
      M_TLAST     => M_TLAST,
      M_TKEEP     => M_TKEEP,
      M_TDEST     => M_TDEST,
      M_TREADY    => M_TREADY
    );


end rtl;
