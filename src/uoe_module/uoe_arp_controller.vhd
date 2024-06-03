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
-- ARP CONTROLLER
----------------------------------
--
-- This module define the controller of the ARP MODULE
-- It handle the sending and the reception of ARP (request or reply)
--
----------------------------------

use work.uoe_module_pkg.all;

entity uoe_arp_controller is
  generic(
    G_ACTIVE_RST : std_logic := '0';    -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST  : boolean   := true;   -- Type of reset used (synchronous or asynchronous resets)
    G_FREQ_KHZ   : integer   := 156250  -- System Frequency use to reference timeout
  );
  port(
    -- Clock & reset
    CLK                     : in  std_logic;
    RST                     : in  std_logic;
    -- From/to MAC Shaping (ARP Table/Cache)
    S_IP_ADDR_TDATA         : in  std_logic_vector(31 downto 0);
    S_IP_ADDR_TVALID        : in  std_logic;
    S_IP_ADDR_TREADY        : out std_logic;
    M_IP_MAC_ADDR_TDATA     : out std_logic_vector(79 downto 0); -- 79..32 => Targeted MAC, 31..0 => Targeted IP
    M_IP_MAC_ADDR_TVALID    : out std_logic;
    M_IP_MAC_ADDR_TUSER     : out std_logic_vector(0 downto 0); -- Validity of the IP/MAC couple
    M_IP_MAC_ADDR_TREADY    : in  std_logic;
    -- To ARP TX
    M_ARP_TX_TDATA          : out std_logic_vector(79 downto 0); -- 79..32 => Targeted MAC, 31..0 => Targeted IP
    M_ARP_TX_TVALID         : out std_logic;
    M_ARP_TX_TUSER          : out std_logic_vector(0 downto 0); -- 0 => Request, 1 => Reply
    M_ARP_TX_TREADY         : in  std_logic;
    -- From ARP RX (through FIFO)
    S_ARP_RX_TDATA          : in  std_logic_vector(79 downto 0); -- 79..32 => Targeted MAC, 31..0 => Targeted IP 
    S_ARP_RX_TVALID         : in  std_logic;
    S_ARP_RX_TUSER          : in  std_logic_vector(0 downto 0); -- 0 => Request, 1 => Reply
    S_ARP_RX_TREADY         : out std_logic;
    -- Registers
    INIT_DONE               : in  std_logic; -- Initialization of parameters (LOCAL_IP_ADDR,...) is done  
    LOCAL_IP_ADDR           : in  std_logic_vector(31 downto 0);
    ARP_TIMEOUT_MS          : in  std_logic_vector(11 downto 0); -- Max. time to wait an ARP answer before assert ARP_ERROR (in ms)
    ARP_TRYINGS             : in  std_logic_vector(3 downto 0); -- Number of Query Retries
    ARP_GRATUITOUS_REQ      : in  std_logic; -- User request to g�n�rate a gratuitous ARP (ex : following a (re)connection)
    ARP_RX_TARGET_IP_FILTER : in  std_logic_vector(1 downto 0); -- Filter mode selection
    -- Status
    ARP_PROBE_DONE          : out std_logic;
    ARP_IP_CONFLICT         : out std_logic; -- Detect an IP Conflict
    ARP_ERROR               : out std_logic -- Indicates no response to a request
  );
end uoe_arp_controller;

architecture rtl of uoe_arp_controller is

  ---------------------------------------------------------------------
  -- Constants declaration
  ---------------------------------------------------------------------

  constant C_CNT_ONE_MS_WIDTH : integer                                   := integer(ceil(log2(real(G_FREQ_KHZ))));
  constant C_MILLISECOND      : unsigned(C_CNT_ONE_MS_WIDTH - 1 downto 0) := to_unsigned(G_FREQ_KHZ, C_CNT_ONE_MS_WIDTH); -- Number of ticks at FREQUENCY_UOE_kHz kHz for 1 ms

  ---------------------------------------------------------------------
  -- Signals declaration
  ---------------------------------------------------------------------

  -- AXI4-Stream internal signals
  signal s_ip_addr_tready_i     : std_logic;
  signal m_arp_tx_tvalid_i      : std_logic;
  signal m_arp_tx_tuser_i       : std_logic_vector(0 downto 0); -- 0 => Request, 1 => Reply
  signal s_arp_rx_tready_i      : std_logic;
  signal m_ip_mac_addr_tvalid_i : std_logic;

  -- Probe
  signal arp_probe_init   : std_logic;
  signal arp_probe_retry  : std_logic;
  signal arp_probe_done_i : std_logic;

  -- buffer
  signal ip_addr_searched     : std_logic_vector(31 downto 0);
  signal ip_addr_searched_en  : std_logic;
  signal ip_mac_addr_received : std_logic_vector(79 downto 0);

  -- flag
  signal flag_arp_tx_req         : std_logic;
  signal flag_arp_tx_repeat      : std_logic;
  signal flag_arp_tx_reply       : std_logic;
  signal flag_mac_shaping_reply  : std_logic;
  signal flag_timer_done         : std_logic;
  signal flag_arp_gratuitous_req : std_logic;

  -- Timer
  signal timer_init    : std_logic;     -- init timer (pulse)
  signal timer_running : std_logic;     -- timer running
  signal timer_done    : std_logic;     -- pulse when timer over
  signal timer_stop    : std_logic;     -- stop and reset timer before end if arp answer received

  signal cnt_one_ms  : unsigned(C_CNT_ONE_MS_WIDTH - 1 downto 0); -- counts 1 ms
  signal cnt_ms      : unsigned(11 downto 0); -- counts the number of ms specified by ARP_TIMEOUT
  signal cnt_tryings : unsigned(3 downto 0); -- Counts the number of requests to ARP module for a given request to the table

begin

  -- assignement
  ARP_PROBE_DONE <= arp_probe_done_i;   -- @suppress Case is not matching but rule is OK

  S_ARP_RX_TREADY <= s_arp_rx_tready_i; -- @suppress Case is not matching but rule is OK
  M_ARP_TX_TVALID <= m_arp_tx_tvalid_i; -- @suppress Case is not matching but rule is OK
  M_ARP_TX_TUSER  <= m_arp_tx_tuser_i;  -- @suppress Case is not matching but rule is OK

  S_IP_ADDR_TREADY     <= s_ip_addr_tready_i; -- @suppress Case is not matching but rule is OK
  M_IP_MAC_ADDR_TVALID <= m_ip_mac_addr_tvalid_i; -- @suppress Case is not matching but rule is OK

  -- ARP decoding
  P_ARP_CONTROLLER : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      s_ip_addr_tready_i      <= '0';
      m_arp_tx_tvalid_i       <= '0';
      m_arp_tx_tuser_i(0)     <= C_ARP_REQUEST;
      s_arp_rx_tready_i       <= '0';
      m_ip_mac_addr_tvalid_i  <= '0';
      arp_probe_init          <= '1';
      arp_probe_retry         <= '0';
      arp_probe_done_i        <= '0';
      flag_arp_tx_req         <= '0';
      flag_arp_tx_repeat      <= '0';
      flag_arp_tx_reply       <= '0';
      flag_mac_shaping_reply  <= '0';
      flag_timer_done         <= '0';
      flag_arp_gratuitous_req <= '0';
      ip_addr_searched        <= (others => '0');
      ip_addr_searched_en     <= '0';
      ip_mac_addr_received    <= (others => '0');
      M_ARP_TX_TDATA          <= (others => '0');
      m_arp_tx_tvalid_i       <= '0';
      M_IP_MAC_ADDR_TDATA     <= (others => '0');
      M_IP_MAC_ADDR_TUSER(0)  <= C_STATUS_VALID;
      m_ip_mac_addr_tvalid_i  <= '0';
      timer_init              <= '0';
      timer_stop              <= '0';
      cnt_tryings             <= (others => '0');
      ARP_IP_CONFLICT         <= '0';
      ARP_ERROR               <= '0';

    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        s_ip_addr_tready_i      <= '0';
        m_arp_tx_tvalid_i       <= '0';
        m_arp_tx_tuser_i(0)     <= C_ARP_REQUEST;
        s_arp_rx_tready_i       <= '0';
        m_ip_mac_addr_tvalid_i  <= '0';
        arp_probe_init          <= '1';
        arp_probe_retry         <= '0';
        arp_probe_done_i        <= '0';
        flag_arp_tx_req         <= '0';
        flag_arp_tx_repeat      <= '0';
        flag_arp_tx_reply       <= '0';
        flag_mac_shaping_reply  <= '0';
        flag_timer_done         <= '0';
        flag_arp_gratuitous_req <= '0';
        ip_addr_searched        <= (others => '0');
        ip_addr_searched_en     <= '0';
        ip_mac_addr_received    <= (others => '0');
        M_ARP_TX_TDATA          <= (others => '0');
        m_arp_tx_tvalid_i       <= '0';
        M_IP_MAC_ADDR_TDATA     <= (others => '0');
        M_IP_MAC_ADDR_TUSER(0)  <= C_STATUS_VALID;
        m_ip_mac_addr_tvalid_i  <= '0';
        timer_init              <= '0';
        timer_stop              <= '0';
        cnt_tryings             <= (others => '0');
        ARP_IP_CONFLICT         <= '0';
        ARP_ERROR               <= '0';
      else

        -- Clear pulse
        timer_init <= '0';
        timer_stop <= '0';
        ARP_ERROR  <= '0';

        -- Clear TVALID
        if M_ARP_TX_TREADY = '1' then
          m_arp_tx_tvalid_i <= '0';
        end if;

        if M_IP_MAC_ADDR_TREADY = '1' then
          m_ip_mac_addr_tvalid_i <= '0';
        end if;

        -----------------------------------
        -- Probe mode => Send Gratuitous ARP and check no answers
        -----------------------------------

        if arp_probe_done_i /= '1' then

          -- Wait until init done will be asserted after reset
          if (INIT_DONE = '1') and ((arp_probe_init = '1') or (arp_probe_retry = '1')) then
            -- Clear flag
            arp_probe_init               <= '0';
            arp_probe_retry              <= '0';
            -- Send Gratuitous ARP Request
            M_ARP_TX_TDATA(79 downto 32) <= C_BROADCAST_MAC_ADDR;
            M_ARP_TX_TDATA(31 downto 0)  <= LOCAL_IP_ADDR;
            m_arp_tx_tuser_i(0)          <= C_ARP_REQUEST;
            m_arp_tx_tvalid_i            <= '1';
            -- Initialize timer
            timer_init                   <= '1';
            -- Assert ARP_RX_TREADY
            s_arp_rx_tready_i            <= '1';
          end if;

          -- if no ARP answer before timeout => ok 
          if (timer_done = '1') then
            timer_stop <= '1';

            -- Reach number of tries => End of ARP Probe
            if cnt_tryings = (unsigned(ARP_TRYINGS) - 1) then
              cnt_tryings        <= (others => '0');
              arp_probe_done_i   <= '1';
              s_ip_addr_tready_i <= '1';

            else
              cnt_tryings <= unsigned(cnt_tryings) + 1;

              if (m_arp_tx_tvalid_i /= '1') then
                arp_probe_retry <= '1';
                --else -- TODO error case => Is it necessary to handle it? because it shouldn't append
              end if;
            end if;

          end if;

          -- A corresponding answer has been received => IP CONFLICT detect
          if (S_ARP_RX_TVALID = '1') and (s_arp_rx_tready_i = '1') and (S_ARP_RX_TUSER(0) = C_ARP_REPLY) and (S_ARP_RX_TDATA(31 downto 0) = LOCAL_IP_ADDR) then
            timer_stop        <= '1';
            s_arp_rx_tready_i <= '0';
            ARP_IP_CONFLICT   <= '1';
          end if;

        end if;

        -----------------------------------
        -- Operation mode => Wait for ARP frames or timeout
        -----------------------------------

        if arp_probe_done_i = '1' then

          -- memorize gratuitous ARP request
          if (ARP_GRATUITOUS_REQ = '1') then
            flag_arp_gratuitous_req <= '1';
          end if;

          ---------------------------------
          -- MAC Shaping request

          if (s_ip_addr_tready_i /= '1') and (flag_arp_tx_req /= '1') then
            s_ip_addr_tready_i <= '1';
          elsif (S_IP_ADDR_TVALID = '1') and (s_ip_addr_tready_i = '1') then
            s_ip_addr_tready_i  <= '0';
            flag_arp_tx_req     <= '1';
            ip_addr_searched    <= S_IP_ADDR_TDATA;
            ip_addr_searched_en <= '1';
          end if;

          ---------------------------------
          -- ARP TX Management

          if (M_ARP_TX_TREADY = '1') or (m_arp_tx_tvalid_i /= '1') then

            -- Request from MAC Shaping
            if (flag_arp_tx_req = '1') or (flag_arp_tx_repeat = '1') then
              flag_arp_tx_req              <= '0';
              flag_arp_tx_repeat           <= '0';
              M_ARP_TX_TDATA(79 downto 32) <= C_BROADCAST_MAC_ADDR;
              M_ARP_TX_TDATA(31 downto 0)  <= ip_addr_searched;
              m_arp_tx_tuser_i(0)          <= C_ARP_REQUEST;
              m_arp_tx_tvalid_i            <= '1';
              -- Initialize timer
              timer_init                   <= '1';

            -- Send a response 
            elsif flag_arp_tx_reply = '1' then
              M_ARP_TX_TDATA      <= ip_mac_addr_received;
              m_arp_tx_tuser_i(0) <= C_ARP_REPLY;
              m_arp_tx_tvalid_i   <= '1';
              flag_arp_tx_reply   <= '0';

            -- Request generation of gratuitous ARP by user
            elsif (ARP_GRATUITOUS_REQ = '1') or (flag_arp_gratuitous_req = '1') then
              flag_arp_gratuitous_req      <= '0';
              M_ARP_TX_TDATA(79 downto 32) <= C_BROADCAST_MAC_ADDR;
              M_ARP_TX_TDATA(31 downto 0)  <= LOCAL_IP_ADDR;
              m_arp_tx_tuser_i(0)          <= C_ARP_REQUEST;
              m_arp_tx_tvalid_i            <= '1';
              -- no expected answers so timer is not initialize in this case;
            end if;
          end if;

          ---------------------------------
          -- ARP RX Management

          if (s_arp_rx_tready_i /= '1') and (flag_arp_tx_reply /= '1') and (flag_mac_shaping_reply /= '1') then
            s_arp_rx_tready_i <= '1';

          elsif (S_ARP_RX_TVALID = '1') and (s_arp_rx_tready_i = '1') then
            s_arp_rx_tready_i    <= '0';
            ip_mac_addr_received <= S_ARP_RX_TDATA;

            -- Request
            if S_ARP_RX_TUSER(0) = C_ARP_REQUEST then
              flag_arp_tx_reply <= '1';

              -- Case static ARP table => No IP/MAC couple are send to ARP Table
              if ARP_RX_TARGET_IP_FILTER /= "11" then
                flag_mac_shaping_reply <= '1';
              end if;

            -- Reply
            else
              flag_mac_shaping_reply <= '1';
              -- If IP address received equals with the one searched => stop timer 
              if (ip_addr_searched_en = '1') and (S_ARP_RX_TDATA(31 downto 0) = ip_addr_searched) then
                timer_stop          <= '1';
                ip_addr_searched_en <= '0';
              end if;
            end if;
          end if;

          ---------------------------------
          -- MAC Shaping answers

          if (timer_done = '1') then
            timer_stop      <= '1';
            flag_timer_done <= '1';
          end if;

          if (M_IP_MAC_ADDR_TREADY = '1') or (m_ip_mac_addr_tvalid_i /= '1') then

            if (timer_done = '1') or (flag_timer_done = '1') then
              flag_timer_done <= '0';

              -- Reach number of tries => End of ARP Probe
              if cnt_tryings = (unsigned(ARP_TRYINGS) - 1) then
                cnt_tryings <= (others => '0');

                ARP_ERROR <= '1';

                -- Return error status to ARP Table
                M_IP_MAC_ADDR_TDATA(79 downto 32) <= (others => '0');
                M_IP_MAC_ADDR_TDATA(31 downto 0)  <= ip_addr_searched;
                M_IP_MAC_ADDR_TUSER(0)            <= C_STATUS_INVALID;
                m_ip_mac_addr_tvalid_i            <= '1';

              else
                cnt_tryings        <= unsigned(cnt_tryings) + 1;
                flag_arp_tx_repeat <= '1'; -- Repeat sending ARP REQUEST
              end if;

            elsif (flag_mac_shaping_reply = '1') then
              flag_mac_shaping_reply <= '0';
              --s_arp_rx_tready_i      <= '1';
              M_IP_MAC_ADDR_TDATA    <= ip_mac_addr_received;
              M_IP_MAC_ADDR_TUSER(0) <= C_STATUS_VALID;
              m_ip_mac_addr_tvalid_i <= '1';

            end if;
          end if;

        end if;

      end if;
    end if;
  end process P_ARP_CONTROLLER;

  -- Handle timer
  P_TIMER_MS : process(CLK, RST)
  begin
    -- asynchronous reset
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      timer_running <= '0';
      timer_done    <= '0';
      cnt_one_ms    <= (others => '0');
      cnt_ms        <= (others => '0');

    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        timer_running <= '0';
        timer_done    <= '0';
        cnt_one_ms    <= (others => '0');
        cnt_ms        <= (others => '0');

      else

        timer_done <= '0';

        -- Start timer
        if timer_init = '1' then
          timer_running <= '1';
          cnt_one_ms    <= (others => '0');
          cnt_ms        <= (others => '0');
        end if;

        -- Timer is running
        if timer_running = '1' then
          if timer_stop = '1' then
            timer_running <= '0';

          elsif cnt_one_ms = (C_MILLISECOND - 1) then
            if cnt_ms = (unsigned(ARP_TIMEOUT_MS) - 1) then
              timer_running <= '0';
              timer_done    <= '1';
            else
              cnt_ms     <= cnt_ms + 1;
              cnt_one_ms <= (others => '0');
            end if;
          else
            cnt_one_ms <= cnt_one_ms + 1;
          end if;
        end if;

      end if;
    end if;
  end process P_TIMER_MS;

end rtl;
