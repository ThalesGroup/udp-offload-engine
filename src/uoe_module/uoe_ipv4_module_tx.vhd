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
-- IPV4 MODULE TX
----------------------------------
--
-- This module is used to insert IPV4 Header in incoming frames
-- Moreover, it fragments the incoming frame if its size is greater than the maximum ethernet size. 
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_ipv4_module_tx is
  generic(
    G_ACTIVE_RST        : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST         : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH       : integer   := 64     -- Width of the data bus
  );
  port(
    -- Clocks and resets
    CLK           : in  std_logic;
    RST           : in  std_logic;
    -- From Transport Layer
    S_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID      : in  std_logic;
    S_TLAST       : in  std_logic;
    S_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID         : in  std_logic_vector(7 downto 0); -- Protocol Value
    S_TUSER       : in  std_logic_vector(47 downto 0); -- 31:0 -> Dest IP addr, 47:32 -> Size of transport datagram
    S_TREADY      : out std_logic;
    -- To Link Layer 
    M_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID      : out std_logic;
    M_TLAST       : out std_logic;
    M_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID         : out std_logic_vector(15 downto 0); -- Ethertype : IPv4
    M_TUSER       : out std_logic_vector(31 downto 0); -- Dest IP addr
    M_TREADY      : in  std_logic;
    -- Registers
    INIT_DONE     : in  std_logic;
    LOCAL_IP_ADDR : in  std_logic_vector(31 downto 0);
    TTL           : in  std_logic_vector(7 downto 0)
  );
end entity uoe_ipv4_module_tx;

architecture rtl of uoe_ipv4_module_tx is

  -------------------------------
  -- Constants declaration
  -------------------------------

  -- size of TKEEP
  constant C_TKEEP_WIDTH : positive := (G_TDATA_WIDTH + 7) / 8;

  -------------------------------
  -- Functions declaration
  -------------------------------
  function get_alignment return integer is
    variable align : integer range 0 to C_TKEEP_WIDTH - 1;
  begin
    align := 0;
    if (C_IPV4_MIN_HEADER_SIZE mod C_TKEEP_WIDTH) /= 0 then
      align := (C_TKEEP_WIDTH - (C_IPV4_MIN_HEADER_SIZE mod C_TKEEP_WIDTH));
    end if;
    return align;
  end function get_alignment;

  -------------------------------
  -- Types declaration
  -------------------------------
  type t_cfg is record
    id           : std_logic_vector(15 downto 0);
    protocol     : std_logic_vector(7 downto 0);
    length       : std_logic_vector(15 downto 0);
    src_ip_addr  : std_logic_vector(31 downto 0);
    dest_ip_addr : std_logic_vector(31 downto 0);
    fragment     : std_logic_vector(12 downto 0);
    flags        : std_logic_vector(2 downto 0);
    crc          : std_logic_vector(15 downto 0);
  end record t_cfg;

  type t_states is (ST_INIT, ST_WAIT_NEW_FRAME, ST_CRC_TTL_PROTOCOL_ID, ST_CRC_FLAG_FRAG_LENGTH, ST_CRC_RESIZE, ST_CRC_DONE, ST_WAIT_FOR_ACK);

  type t_axis_forward is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tvalid : std_logic;
    tlast  : std_logic;
    tkeep  : std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
  end record t_axis_forward;

  type t_axis_forward_arr is array (natural range <>) of t_axis_forward;

  -------------------------------
  -- Constants declaration
  -------------------------------

  -- Header constant
  constant C_HEADER_LENGTH_FIELD : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned((C_IPV4_MIN_HEADER_SIZE / 4), 4)); -- In 32bit-words
  constant C_HEADER_CNT_MAX      : integer                      := integer(ceil(real(C_IPV4_MIN_HEADER_SIZE) / real(C_TKEEP_WIDTH)));

  constant C_VERSION_FIELD         : std_logic_vector(3 downto 0) := x"4"; -- IPv4 protocol
  constant C_TYPE_OF_SERVICE_FIELD : std_logic_vector(7 downto 0) := (others => '0');
  constant C_FRAG_FLAG_INT         : std_logic_vector(2 downto 0) := "001"; --More fragements
  constant C_FRAG_FLAG_LAST        : std_logic_vector(2 downto 0) := "000"; --Last fragement

  constant C_PAYLOAD_SIZE_WORDS  : positive := integer(floor(real(C_IPV4_MAX_PAYLOAD_SIZE) / real(C_TKEEP_WIDTH)));
  constant C_PAYLOAD_SIZE_BYTES  : positive := C_PAYLOAD_SIZE_WORDS * C_TKEEP_WIDTH;
  constant C_FRAGMENT_OFFSET_INC : positive := C_PAYLOAD_SIZE_BYTES / 8; --Multiple of 8 bytes (1480/8=185), defined by protocol
  constant C_CNT_WORD_WIDTH      : positive := integer(ceil(log2(real(C_PAYLOAD_SIZE_WORDS))));

  -- others constant
  constant C_NB_REGS : positive := 8;
  constant C_ALIGN   : integer  := get_alignment;

  -- constant for record initialization
  constant C_CFG_INIT : t_cfg := (
    id           => (others => '0'),
    protocol     => (others => '0'),
    length       => (others => '0'),
    src_ip_addr  => (others => '0'),
    dest_ip_addr => (others => '0'),
    fragment     => (others => '0'),
    flags        => (others => '0'),
    crc          => (others => '0')
  );

  constant C_FORWARD_DATA_INIT : t_axis_forward := (
    tdata  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast  => '0',                      -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  -------------------------------
  -- Signals declaration
  -------------------------------

  -- Registers chain internal axis
  signal s_int        : t_axis_forward_arr(C_NB_REGS downto 0); -- @suppress array of record of allowed types
  signal s_int_tready : std_logic_vector(C_NB_REGS downto 0);

  -- axis bus at intermediate layer
  signal mid        : t_axis_forward;
  signal mid_tready : std_logic;

  signal buff : t_axis_forward;

  -- axis bus at output
  signal m_int        : t_axis_forward;
  signal m_int_tuser  : std_logic_vector(31 downto 0);
  signal m_int_tready : std_logic;

  -- Extraction control on the first transfer
  signal axis_ctrl_tid    : std_logic_vector(7 downto 0); -- Sub Protocol
  signal axis_ctrl_tuser  : std_logic_vector(47 downto 0); -- 31:0 -> Dest IP addr, 47:32 -> Size of transport datagram
  signal axis_ctrl_tvalid : std_logic;
  signal axis_ctrl_tready : std_logic;

  signal axis_ctrl_reg_tid    : std_logic_vector(7 downto 0); -- Sub Protocol
  signal axis_ctrl_reg_tuser  : std_logic_vector(47 downto 0); -- 31:0 -> Dest IP addr, 47:32 -> Size of transport datagram
  signal axis_ctrl_reg_tvalid : std_logic;
  signal axis_ctrl_reg_tready : std_logic;

  -- Fragmentation of the frame
  signal sof          : std_logic;
  signal cnt          : unsigned(C_CNT_WORD_WIDTH - 1 downto 0);
  signal s_tlast_int  : std_logic;
  signal s_tlast_frag : std_logic;

  -- FSM use to define header and compute CRC
  signal state : t_states;

  -- Counters for Header configuration
  signal cnt_id        : unsigned(15 downto 0); -- identification value indicator
  signal cnt_fragments : unsigned(12 downto 0); -- fragment offset counter
  signal cnt_remaining : unsigned(15 downto 0); -- Number of data bytes that still must be sent for the current frame (used to know if a new fragment is necessary)

  -- Checksum computation (cf RFC 1071)
  signal crc_static      : unsigned(32 downto 0); -- 1 carry + 32 bits
  signal crc_calc        : unsigned(32 downto 0); -- 1 carry + 32 bits
  signal crc_calc_resize : unsigned(16 downto 0); -- 1 carry + 16 bits*

  -- Config header
  signal axis_cfg_tdata  : t_cfg;
  signal axis_cfg_tvalid : std_logic;
  signal axis_cfg_tready : std_logic;

  -- Header generation
  signal cnt_header         : integer range 0 to C_HEADER_CNT_MAX;
  signal header_in_progress : std_logic;

begin

  --------------------------------------------------
  -- Process used to extract control and fragment frame in several packet (if required) 
  P_CTRL : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_ctrl_tuser  <= (others => '0');
      axis_ctrl_tid    <= (others => '0');
      axis_ctrl_tvalid <= '0';
      sof              <= '1';
      cnt              <= (others => '0');
      s_tlast_int      <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_ctrl_tuser  <= (others => '0');
        axis_ctrl_tid    <= (others => '0');
        axis_ctrl_tvalid <= '0';
        sof              <= '1';
        cnt              <= (others => '0');
        s_tlast_int      <= '0';

      else

        -- clear flag
        if axis_ctrl_tready = '1' then
          axis_ctrl_tvalid <= '0';
        end if;

        -- Extract TID and TUSER on the first transaction of the frame
        if (S_TVALID = '1') and (s_int_tready(0) = '1') then

          -- On start of frame 
          if sof = '1' then
            sof              <= '0';
            axis_ctrl_tuser  <= S_TUSER;
            axis_ctrl_tid    <= S_TID;
            axis_ctrl_tvalid <= '1';
          end if;

          -- Re-assert Start of frame on TLAST
          if (S_TLAST = '1') then
            sof <= '1';
          end if;

          -- Count transfer
          cnt <= cnt + 1;

          if (cnt = (C_PAYLOAD_SIZE_WORDS - 1)) or (S_TLAST = '1') then
            s_tlast_int <= '0';
            cnt         <= (others => '0');
          elsif cnt = (C_PAYLOAD_SIZE_WORDS - 2) then
            s_tlast_int <= '1';
          end if;
        end if;

      end if;
    end if;
  end process P_CTRL;

  s_tlast_frag <= S_TLAST or s_tlast_int;

  s_int(0).tdata  <= S_TDATA;
  s_int(0).tvalid <= S_TVALID;
  s_int(0).tlast  <= s_tlast_frag;
  s_int(0).tkeep  <= S_TKEEP;
  S_TREADY        <= s_int_tready(0);

  -- Chain Registers
  GEN_REGISTERS_CHAIN : for i in 0 to C_NB_REGS - 1 generate
  begin

    inst_axis_register : axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_TDATA_WIDTH,
        G_REG_FORWARD  => true,
        G_REG_BACKWARD => false
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => s_int(i).tdata,
        S_TVALID => s_int(i).tvalid,
        S_TLAST  => s_int(i).tlast,
        S_TKEEP  => s_int(i).tkeep,
        S_TREADY => s_int_tready(i),
        M_TDATA  => s_int(i + 1).tdata,
        M_TVALID => s_int(i + 1).tvalid,
        M_TLAST  => s_int(i + 1).tlast,
        M_TKEEP  => s_int(i + 1).tkeep,
        M_TREADY => s_int_tready(i + 1)
      );

  end generate GEN_REGISTERS_CHAIN;

  -- Add register to bufferize control
  inst_axis_register_ctrl : axis_register
    generic map(
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_TUSER_WIDTH  => 48,
      G_TID_WIDTH    => 8,
      G_REG_FORWARD  => true,
      G_REG_BACKWARD => true
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TUSER  => axis_ctrl_tuser,
      S_TID    => axis_ctrl_tid,
      S_TVALID => axis_ctrl_tvalid,
      S_TREADY => axis_ctrl_tready,
      M_TUSER  => axis_ctrl_reg_tuser,
      M_TID    => axis_ctrl_reg_tid,
      M_TVALID => axis_ctrl_reg_tvalid,
      M_TREADY => axis_ctrl_reg_tready
    );
  -- TODO : Replace this buffer by a fifo if succession of small msg(1 word) the first transfer of a frame could be missed

  -----------------------------------------------------
  ------------- Header Params Computation -------------
  -----------------------------------------------------

  -- Compute parameters for each header fragments
  P_CFG_FRAGS_HEADER : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      state                <= ST_INIT;
      axis_ctrl_reg_tready <= '0';
      axis_cfg_tdata       <= C_CFG_INIT;
      axis_cfg_tvalid      <= '0';
      cnt_id               <= (others => '0');
      cnt_fragments        <= (others => '0');
      cnt_remaining        <= (others => '0');
      crc_static           <= (others => '0');
      crc_calc             <= (others => '0');
      crc_calc_resize      <= (others => '0');
    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        state                <= ST_INIT;
        axis_ctrl_reg_tready <= '0';
        axis_cfg_tdata       <= C_CFG_INIT;
        axis_cfg_tvalid      <= '0';
        cnt_id               <= (others => '0');
        cnt_fragments        <= (others => '0');
        cnt_remaining        <= (others => '0');
        crc_static           <= (others => '0');
        crc_calc             <= (others => '0');
        crc_calc_resize      <= (others => '0');

      else

        -- Compute static part of the checksum with the addition of constant values and source IP addr
        crc_static <= unsigned("0" & C_VERSION_FIELD & C_HEADER_LENGTH_FIELD & C_TYPE_OF_SERVICE_FIELD & x"0000") + unsigned("0" & LOCAL_IP_ADDR);

        case state is
          when ST_INIT =>
            if INIT_DONE = '1' then
              state                <= ST_WAIT_NEW_FRAME;
              axis_ctrl_reg_tready <= '1';
            end if;

          -- Wait new control information and generate first config transfer
          when ST_WAIT_NEW_FRAME =>

            if (axis_ctrl_reg_tvalid = '1') and (axis_ctrl_reg_tready = '1') then
              state                <= ST_CRC_TTL_PROTOCOL_ID;
              axis_ctrl_reg_tready <= '0';

              cnt_id        <= cnt_id + 1;
              cnt_fragments <= to_unsigned(C_FRAGMENT_OFFSET_INC, 13);

              axis_cfg_tdata.id           <= std_logic_vector(cnt_id);
              axis_cfg_tdata.protocol     <= axis_ctrl_reg_tid;
              axis_cfg_tdata.dest_ip_addr <= axis_ctrl_reg_tuser(31 downto 0);
              axis_cfg_tdata.src_ip_addr  <= LOCAL_IP_ADDR;
              axis_cfg_tdata.fragment     <= (others => '0');

              if unsigned(axis_ctrl_reg_tuser(47 downto 32)) > C_PAYLOAD_SIZE_BYTES then
                axis_cfg_tdata.length <= std_logic_vector(to_unsigned(C_PAYLOAD_SIZE_BYTES, 16) + to_unsigned(C_IPV4_MIN_HEADER_SIZE, 16));
                axis_cfg_tdata.flags  <= C_FRAG_FLAG_INT;
                cnt_remaining         <= unsigned(axis_ctrl_tuser(47 downto 32)) - to_unsigned(C_PAYLOAD_SIZE_BYTES, 16);
              else
                axis_cfg_tdata.length <= std_logic_vector(unsigned(axis_ctrl_reg_tuser(47 downto 32)) + to_unsigned(C_IPV4_MIN_HEADER_SIZE, 16));
                axis_cfg_tdata.flags  <= C_FRAG_FLAG_LAST;
                cnt_remaining         <= (others => '0');
              end if;

              -- Start Computing CRC : Use static crc + DEST IP Address
              crc_calc <= (crc_static(31 downto 0)) + (x"00000000" & crc_static(32)) + (unsigned("0" & axis_ctrl_reg_tuser(31 downto 0)));
            end if;

          when ST_CRC_TTL_PROTOCOL_ID =>
            -- Add TTL / PROTOCOL and ID 
            crc_calc <= (crc_calc(31 downto 0)) + (x"00000000" & crc_calc(32)) + (unsigned("0" & TTL & axis_cfg_tdata.protocol & axis_cfg_tdata.id));
            state    <= ST_CRC_FLAG_FRAG_LENGTH;

          when ST_CRC_FLAG_FRAG_LENGTH =>
            -- Add Fragments flags and offset
            crc_calc <= (crc_calc(31 downto 0)) + (x"00000000" & crc_calc(32)) + (unsigned("0" & axis_cfg_tdata.length & axis_cfg_tdata.flags & axis_cfg_tdata.fragment));
            state    <= ST_CRC_RESIZE;

          when ST_CRC_RESIZE =>
            -- Create 16 bit checksum from 32 bit result
            crc_calc_resize <= ("0" & crc_calc(31 downto 16)) + ("0" & crc_calc(15 downto 0)) + (x"0000" & crc_calc(32));
            state           <= ST_CRC_DONE;

          when ST_CRC_DONE =>
            -- Complete checksum calculation
            axis_cfg_tdata.crc <= not (std_logic_vector(crc_calc_resize(15 downto 0) + ("000" & x"000" & crc_calc_resize(16))));
            axis_cfg_tvalid    <= '1';
            state              <= ST_WAIT_FOR_ACK;

          -- Wait until checksum value is used
          when ST_WAIT_FOR_ACK =>
            if axis_cfg_tready = '1' then
              axis_cfg_tvalid <= '0';

              -- Start Computing CRC : Use static crc + DEST IP Address
              crc_calc <= (crc_static(31 downto 0)) + (x"00000000" & crc_static(32)) + (unsigned("0" & axis_cfg_tdata.dest_ip_addr(31 downto 0)));

              -- No more fragment
              if cnt_remaining = 0 then
                axis_ctrl_reg_tready <= '1';
                state                <= ST_WAIT_NEW_FRAME;

              -- Next fragment
              else
                state                   <= ST_CRC_TTL_PROTOCOL_ID;
                cnt_fragments           <= cnt_fragments + to_unsigned(C_FRAGMENT_OFFSET_INC, 13);
                axis_cfg_tdata.fragment <= std_logic_vector(cnt_fragments);
                if cnt_remaining > C_PAYLOAD_SIZE_BYTES then
                  cnt_remaining <= cnt_remaining - C_PAYLOAD_SIZE_BYTES;
                else
                  axis_cfg_tdata.length <= std_logic_vector(cnt_remaining + to_unsigned(C_IPV4_MIN_HEADER_SIZE, 16));
                  axis_cfg_tdata.flags  <= C_FRAG_FLAG_LAST;
                  cnt_remaining         <= (others => '0');
                end if;

              end if;

            end if;
        end case;

      end if;
    end if;
  end process P_CFG_FRAGS_HEADER;

  -------------------------------------------------
  -- Synchronous process to buffer forward data
  -- and register the backward path
  P_BACKWARD_REG : process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      buff                    <= C_FORWARD_DATA_INIT;
      s_int_tready(C_NB_REGS) <= '0';

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        buff                    <= C_FORWARD_DATA_INIT;
        s_int_tready(C_NB_REGS) <= '0';

      else

        -- bufferize data (skid register)
        if s_int_tready(C_NB_REGS) = '1' then
          -- may acquire new data
          if s_int(C_NB_REGS).tvalid = '1' then
            -- bufferize the bus when data are valid
            buff <= s_int(C_NB_REGS);
          else
            -- change only the valid state to avoid logic toggling (and save power)
            buff.tvalid <= '0';
          end if;
        end if;

        -- register: ready when downstream is ready or no data are valid
        s_int_tready(C_NB_REGS) <= mid_tready or (not mid.tvalid);

      end if;
    end if;
  end process P_BACKWARD_REG;

  -- assign the middle layer with a mux
  mid <= s_int(C_NB_REGS) when s_int_tready(C_NB_REGS) = '1' else buff;

  -- asynchonous: ready when downstream is ready or no data are valid
  mid_tready <= (m_int_tready or (not m_int.tvalid)) and (not header_in_progress);

  ------------------------------------------------------
  ----------------- Header generation ------------------
  ------------------------------------------------------
  P_IPV4_HEADER : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      axis_cfg_tready    <= '0';
      cnt_header         <= 0;
      header_in_progress <= '1';
      m_int              <= C_FORWARD_DATA_INIT;
      m_int_tuser        <= (others => '0');

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        axis_cfg_tready    <= '0';
        cnt_header         <= 0;
        header_in_progress <= '1';
        m_int              <= C_FORWARD_DATA_INIT;
        m_int_tuser        <= (others => '0');

      else

        -- Clear pulse
        axis_cfg_tready <= '0';

        if (m_int_tready = '1') or (m_int.tvalid /= '1') then

          -- Wait new header information
          if (axis_cfg_tvalid = '1') or (header_in_progress /= '1') then
            
            if (mid.tvalid = '1') then
              -- Valid output
              m_int.tvalid <= '1';
              m_int.tlast  <= '0';
              
              if cnt_header = 0 then
                m_int_tuser <= axis_cfg_tdata.dest_ip_addr;
              end if;
              
              -- Header
              if cnt_header /= C_HEADER_CNT_MAX then
                cnt_header <= cnt_header + 1;

                -- if last word of the header
                if cnt_header = (C_HEADER_CNT_MAX - 1) then
                  header_in_progress  <= '0';
                  axis_cfg_tready     <= '1';
                end if;

                -- TDATA and TKEEP
                for i in 0 to C_TKEEP_WIDTH - 1 loop
                  -- Little Endian
                  case ((cnt_header * C_TKEEP_WIDTH) + i) is
                    -- Big Endian
                    --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                    when C_ALIGN + 0 => m_int.tdata((8 * i) + 7 downto (8 * i) + 4) <= C_VERSION_FIELD;
                      m_int.tdata((8 * i) + 3 downto (8 * i) + 0) <= C_HEADER_LENGTH_FIELD;
                    when C_ALIGN + 1  => m_int.tdata((8 * i) + 7 downto 8 * i) <= C_TYPE_OF_SERVICE_FIELD;
                    when C_ALIGN + 2  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.length(15 downto 8);
                    when C_ALIGN + 3  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.length(7 downto 0);
                    when C_ALIGN + 4  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.id(15 downto 8);
                    when C_ALIGN + 5  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.id(7 downto 0);
                    when C_ALIGN + 6 => m_int.tdata((8 * i) + 7 downto (8 * i) + 5) <= axis_cfg_tdata.flags;
                      m_int.tdata((8 * i) + 4 downto (8 * i) + 0) <= axis_cfg_tdata.fragment(12 downto 8);
                    when C_ALIGN + 7  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.fragment(7 downto 0);
                    when C_ALIGN + 8  => m_int.tdata((8 * i) + 7 downto 8 * i) <= TTL;
                    when C_ALIGN + 9  => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.protocol;
                    when C_ALIGN + 10 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.crc(15 downto 8);
                    when C_ALIGN + 11 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.crc(7 downto 0);
                    when C_ALIGN + 12 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.src_ip_addr(31 downto 24);
                    when C_ALIGN + 13 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.src_ip_addr(23 downto 16);
                    when C_ALIGN + 14 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.src_ip_addr(15 downto 8);
                    when C_ALIGN + 15 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.src_ip_addr(7 downto 0);
                    when C_ALIGN + 16 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.dest_ip_addr(31 downto 24);
                    when C_ALIGN + 17 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.dest_ip_addr(23 downto 16);
                    when C_ALIGN + 18 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.dest_ip_addr(15 downto 8);
                    when C_ALIGN + 19 => m_int.tdata((8 * i) + 7 downto 8 * i) <= axis_cfg_tdata.dest_ip_addr(7 downto 0);
                    when others =>
                      m_int.tdata((8 * i) + 7 downto 8 * i) <= (others => '0');
                  end case;
      
                  -- Little Endian
                  if ((cnt_header * C_TKEEP_WIDTH) + i) >= C_ALIGN then
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
                  cnt_header          <= 0;
                  header_in_progress  <= '1';
                end if;
              end if;
              
            else
              -- change only valid state to avoid logic toggling (and save power)
              m_int.tvalid <= '0';
            end if;
          else
            -- change only valid state to avoid logic toggling (and save power)
            m_int.tvalid <= '0';
          end if;
        end if;

      end if;
    end if;
  end process P_IPV4_HEADER;

  -- Protocol is a constant
  M_TID <= C_ETHERTYPE_IPV4;

  -- Header size is multiple of C_TKEEP_WIDTH
  GEN_NO_ALIGN : if C_ALIGN = 0 generate

    -- connecting output bus to the records
    M_TDATA      <= m_int.tdata;
    M_TLAST      <= m_int.tlast;
    M_TUSER      <= m_int_tuser;
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
        G_TDATA_WIDTH => G_TDATA_WIDTH,
        G_TUSER_WIDTH => 32
      )
      port map(
        CLK      => CLK,
        RST      => RST,
        S_TDATA  => m_int.tdata,
        S_TVALID => m_int.tvalid,
        S_TLAST  => m_int.tlast,
        S_TUSER  => m_int_tuser,
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
