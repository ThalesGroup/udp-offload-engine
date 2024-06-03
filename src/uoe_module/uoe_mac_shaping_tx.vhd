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
-- MAC SHAPING TX
----------------------------------
--
-- This module is used to insert MAC Header in incoming frames
--
----------------------------------

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_pkt_align;

use work.uoe_module_pkg.all;

entity uoe_mac_shaping_tx is
  generic(
    G_ACTIVE_RST  : std_logic := '0';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST   : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_TDATA_WIDTH : positive  := 64     -- Number of bits used along AXI datapath of UOE
  );
  port(
    CLK               : in  std_logic;
    RST               : in  std_logic;
    -- Data input
    S_TDATA           : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID          : in  std_logic;
    S_TLAST           : in  std_logic;
    S_TKEEP           : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID             : in  std_logic_vector(15 downto 0); -- Ethertype value
    S_TUSER           : in  std_logic_vector(31 downto 0); -- Dest IP Address
    S_TREADY          : out std_logic;
    -- Data output
    M_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID          : out std_logic;
    M_TLAST           : out std_logic;
    M_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TREADY          : in  std_logic;
    -- To Cache
    M_IP_ADDR_TDATA   : out std_logic_vector(31 downto 0);
    M_IP_ADDR_TVALID  : out std_logic;
    M_IP_ADDR_TREADY  : in  std_logic;
    -- From cache
    S_MAC_ADDR_TDATA  : in  std_logic_vector(47 downto 0);
    S_MAC_ADDR_TVALID : in  std_logic;
    S_MAC_ADDR_TUSER  : in  std_logic_vector(0 downto 0);
    S_MAC_ADDR_TREADY : out std_logic;
    -- Registers
    LOCAL_MAC_ADDR    : in  std_logic_vector(47 downto 0)
  );
end uoe_mac_shaping_tx;

architecture rtl of uoe_mac_shaping_tx is

  -------------------------------
  -- Constants declaration
  -------------------------------

  constant C_TKEEP_WIDTH    : integer  := ((G_TDATA_WIDTH + 7) / 8);
  constant C_HEADER_CNT_MAX : integer  := integer(ceil(real(C_MAC_HEADER_SIZE) / real(C_TKEEP_WIDTH)));
  constant C_NB_REGS        : positive := 2;

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
  type t_axis_forward is record
    tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    tlast  : std_logic;
    tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
    tid    : std_logic_vector(15 downto 0);
    tvalid : std_logic;
  end record t_axis_forward;

  type t_axis_forward_arr is array (natural range <>) of t_axis_forward;

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------

  -- constant for record initialization
  constant C_FORWARD_DATA_INIT : t_axis_forward := (
    tdata  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tlast  => '0',                      -- could be anything because the tvalid signal is 0
    tkeep  => (others => '0'),          -- could be anything because the tvalid signal is 0
    tid    => (others => '0'),          -- could be anything because the tvalid signal is 0
    tvalid => '0'                       -- data are not valid at initialization
  );

  constant C_ALIGN : integer := get_alignment;

  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------

  -- axis bus at input
  signal s_int        : t_axis_forward_arr(C_NB_REGS downto 0); -- @suppress array of record of allowed types
  signal s_int_tready : std_logic_vector(C_NB_REGS downto 0);

  -- axis bus at intermediate layer
  signal mid        : t_axis_forward;
  signal mid_tready : std_logic;

  signal buff : t_axis_forward;

  -- axis bus at output
  signal m_int        : t_axis_forward;
  signal m_int_tready : std_logic;

  -- start of frame
  signal sof : std_logic;

  -- Counter
  signal cnt_header : integer range 0 to C_HEADER_CNT_MAX;

  -- Flag
  signal header_in_progress : std_logic;
  signal flush              : std_logic;

begin

  -- connecting input bus to the records
  s_int(0).tdata  <= S_TDATA;
  s_int(0).tlast  <= S_TLAST;
  s_int(0).tkeep  <= S_TKEEP;
  s_int(0).tid    <= S_TID;
  s_int(0).tvalid <= S_TVALID;
  S_TREADY        <= s_int_tready(0);   -- @suppress Case is not matching but rule is OK

  ----------------------------------------------
  -- Synchronous process to Handle extraction of TUSER 
  -- and generate request to cache
  P_IP_CACHE : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      sof              <= '1';
      M_IP_ADDR_TDATA  <= (others => '0');
      M_IP_ADDR_TVALID <= '0';

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        sof              <= '1';
        M_IP_ADDR_TDATA  <= (others => '0');
        M_IP_ADDR_TVALID <= '0';

      else

        -- clear flag
        if M_IP_ADDR_TREADY = '1' then
          M_IP_ADDR_TVALID <= '0';
        end if;

        -- Extract TUSER on the first transaction of the frame
        if (s_int(0).tvalid = '1') and (s_int_tready(0) = '1') then
          -- On start of frame 
          if sof = '1' then
            sof              <= '0';
            M_IP_ADDR_TDATA  <= S_TUSER;
            M_IP_ADDR_TVALID <= '1';
          end if;

          -- Re-assert Start of frame on TLAST
          if (s_int(0).tlast = '1') then
            sof <= '1';
          end if;
        end if;
      end if;
    end if;
  end process P_IP_CACHE;

  -- Chain Registers while waiting for the ARP Cache answer 
  GEN_REGISTERS_CHAIN : for i in 0 to C_NB_REGS - 1 generate
  begin

    inst_axis_register : axis_register
      generic map(
        G_ACTIVE_RST   => G_ACTIVE_RST,
        G_ASYNC_RST    => G_ASYNC_RST,
        G_TDATA_WIDTH  => G_TDATA_WIDTH,
        G_TID_WIDTH    => 16,
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
        S_TID    => s_int(i).tid,
        S_TREADY => s_int_tready(i),
        M_TDATA  => s_int(i + 1).tdata,
        M_TVALID => s_int(i + 1).tvalid,
        M_TLAST  => s_int(i + 1).tlast,
        M_TKEEP  => s_int(i + 1).tkeep,
        M_TID    => s_int(i + 1).tid,
        M_TREADY => s_int_tready(i + 1)
      );

  end generate GEN_REGISTERS_CHAIN;

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

  -------------------------------------------------
  -- Register the different signals on the forward path and handle the header insertion
  P_FORWARD_REG : process(CLK, RST)
  begin
    -- Asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      S_MAC_ADDR_TREADY  <= '0';
      cnt_header         <= 0;
      header_in_progress <= '1';
      flush              <= '0';
      m_int              <= C_FORWARD_DATA_INIT;

    elsif rising_edge(CLK) then
      -- Synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        S_MAC_ADDR_TREADY  <= '0';
        cnt_header         <= 0;
        header_in_progress <= '1';
        flush              <= '0';
        m_int              <= C_FORWARD_DATA_INIT;

      else

        -- clear pulse
        S_MAC_ADDR_TREADY <= '0';

        if (m_int_tready = '1') or (m_int.tvalid /= '1') then
          -- Clear TVALID
          m_int.tvalid <= '0';

          -- Wait response of ARP Cache
          if (S_MAC_ADDR_TVALID = '1') or (header_in_progress /= '1') then

            if (mid.tvalid = '1') then
              -- Valid output
              if header_in_progress = '1' then
                m_int.tvalid <= not S_MAC_ADDR_TUSER(0);
                flush        <= S_MAC_ADDR_TUSER(0);
              else
                m_int.tvalid <= not flush;
              end if;
              m_int.tlast <= '0';

              -- Header
              if cnt_header /= C_HEADER_CNT_MAX then
                cnt_header <= cnt_header + 1;

                -- if last word of the header
                if cnt_header = (C_HEADER_CNT_MAX - 1) then
                  header_in_progress <= '0';
                  S_MAC_ADDR_TREADY  <= '1';
                end if;

                -- TDATA and TKEEP
                for i in 0 to C_TKEEP_WIDTH - 1 loop
                  -- Little Endian
                  case ((cnt_header * C_TKEEP_WIDTH) + i) is
                    -- Big Endian
                    --case ((cnt * C_TKEEP_WIDTH) + ((C_TKEEP_WIDTH - 1) - i)) is
                    when C_ALIGN + 0  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(47 downto 40);
                    when C_ALIGN + 1  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(39 downto 32);
                    when C_ALIGN + 2  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(31 downto 24);
                    when C_ALIGN + 3  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(23 downto 16);
                    when C_ALIGN + 4  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(15 downto 8);
                    when C_ALIGN + 5  => m_int.tdata((8 * i) + 7 downto 8 * i) <= S_MAC_ADDR_TDATA(7 downto 0);
                    when C_ALIGN + 6  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(47 downto 40);
                    when C_ALIGN + 7  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(39 downto 32);
                    when C_ALIGN + 8  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(31 downto 24);
                    when C_ALIGN + 9  => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(23 downto 16);
                    when C_ALIGN + 10 => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(15 downto 8);
                    when C_ALIGN + 11 => m_int.tdata((8 * i) + 7 downto 8 * i) <= LOCAL_MAC_ADDR(7 downto 0);
                    when C_ALIGN + 12 => m_int.tdata((8 * i) + 7 downto 8 * i) <= mid.tid(15 downto 8);
                    when C_ALIGN + 13 => m_int.tdata((8 * i) + 7 downto 8 * i) <= mid.tid(7 downto 0);
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
                  cnt_header         <= 0;
                  header_in_progress <= '1';
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
