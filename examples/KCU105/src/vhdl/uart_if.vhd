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

------------------------------------------------
--
--        UART_IF
--
------------------------------------------------
-- This module is used to convert an Uart interface to AXI4-Stream interface
--
-- Generic Parameters :
-- * G_CLK_FREQ   : Used to compute number of clock cycle according to the BITRATE (MHz)
-- * G_ACTIVE_RST : Reset polarity (active 1 or active 0)
-- * G_ASYNC_RST  : Reset Mode (synchronous/asynchronous)
--
------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

use work.serial_if_pkg.all;

entity uart_if is
  generic(
    G_CLK_FREQ          : real      := 250.0;                 -- User clock Frequency in MHz
    G_ACTIVE_RST        : std_logic := '0';                   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST         : boolean   := true;                  -- Type of reset used (synchronous or asynchronous resets)
    G_SIMU              : boolean   := false                  -- Simu mode to reduce time of simulation by 10
  );
  port(
    -- Global
    RST                 : in  std_logic;
    CLK                 : in  std_logic;
    -- Control
    CFG_BAUDRATE        : in  std_logic_vector (4 downto 0);  -- UART Baudrate              => See constants in package
    CFG_BIT_STOP        : in  std_logic;                      -- Number of Stop Bit         => '0': 1 bit, '1' : 2 bits
    CFG_PARITY_ON_OFF   : in  std_logic;                      -- Use of Parity Bit          => '0' : Off,  '1' : On
    CFG_PARITY_ODD_EVEN : in  std_logic;                      -- Polarity of Parity Bit     => '0' : even, '1' : odd
    CFG_USE_PROTOCOL    : in  std_logic;                      -- Use the flow ctrl protocol => '0' : None, '1' : Flow ctrl enable
    CFG_SIZE            : in  std_logic;                      -- Number of data bits        => '0': 8 bits, '1' : 7 bits
    -- User Domain
    DX_TDATA            : in  std_logic_vector(7 downto 0);   -- Data to transmit
    DX_TVALID           : in  std_logic;
    DX_TREADY           : out std_logic;
    DR_TDATA            : out std_logic_vector(7 downto 0);   -- Data received
    DR_TVALID           : out std_logic;
    DR_TREADY           : in  std_logic;
    DR_TUSER            : out std_logic;                      -- Parity bit result
    ERROR_DATA_DROP     : out std_logic;                      -- Data Drop information
    -- Physical Interface
    TXD                 : out std_logic;                      -- TX Data
    RXD                 : in  std_logic;                      -- RX Data
    RTS                 : out std_logic;                      -- Request to Send/ acknowledgement of CTS
    CTS                 : in  std_logic                       -- Ready to send/received
  );
end entity uart_if;

architecture rtl of uart_if is

  -- Function to compute number of cycles of the current clock for matching with the bitrate
  function calc_period(constant baud_rate : in integer; constant clock_frequency : in real) return integer is
    variable result: integer range 0 to integer'high;
  begin
    if G_SIMU then
      result :=integer(round((clock_frequency*100000.0)/real(baud_rate)));
    else
      result:= integer(round((clock_frequency*1000000.0)/real(baud_rate)));
    end if;
    return result;
  end  function calc_period;

  ------------------------------
  -- Constants declaration
  constant C_MAX_BIT_LENGTH : integer := calc_period(75, G_CLK_FREQ);
  constant C_NB_BITS        : integer := integer(ceil(log2(real(C_MAX_BIT_LENGTH))));

  ------------------------------
  -- Type declaration
  type t_state is (IDLE, START_BIT, DATA_BIT, PARITY_BIT, STOP_BIT);

  ------------------------------
  -- Signals declaration

  signal state_emitter      : t_state;                          -- tx fsm
  signal state_receiver     : t_state;                          -- rx fsm

  signal bit_length         : unsigned(C_NB_BITS-1 downto 0);   -- size of bit in number of clock period
  signal bit_number         : unsigned(3 downto 0);             -- number of data bits in a frame

  signal tx_bit_timer       : unsigned(C_NB_BITS-1 downto 0);   -- tx time bit counter
  signal tx_bit_counter     : unsigned(3 downto 0);             -- tx counter of bits

  signal rx_bit_timer       : unsigned(C_NB_BITS-1 downto 0);   -- rx time bit counter
  signal rx_bit_counter     : unsigned(3 downto 0);             -- rx counter of bits

  signal tx_data_r          : std_logic_vector(7 downto 0);     -- reg to store data to send
  signal tx_parity_r        : std_logic;                        -- reg to compute tx parity bit

  signal rx_data_r          : std_logic_vector(7 downto 0);     -- register to store received data
  signal rx_parity_r        : std_logic;                        -- reg to compute rx parity bit

  -- others
  signal dr_tvalid_i        : std_logic;
  signal dx_tready_i        : std_logic;

  signal rts_i              : std_logic;
  signal rxd_r              : std_logic;

begin

  RTS             <= rts_i;

  DX_TREADY       <= dx_tready_i;
  DR_TVALID       <= dr_tvalid_i;

  ------------------------------
  -- Process used to manage TX serial link
  ------------------------------
  p_emitter : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      state_emitter     <= IDLE;
      dx_tready_i       <= '0';
      TXD               <= '1';
      tx_bit_timer      <= (others => '0');
      tx_bit_counter    <= (others => '0');
      tx_data_r         <= (others => '0');
      tx_parity_r       <= '0';

    elsif rising_edge(CLK) then

      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        state_emitter   <= IDLE;
        dx_tready_i     <= '0';
        TXD             <= '1';
        tx_bit_timer    <= (others => '0');
        tx_bit_counter  <= (others => '0');
        tx_data_r       <= (others => '0');
        tx_parity_r     <= '0';

      else

        -- bit timer Management
        if (tx_bit_timer = 0) then
          tx_bit_timer <= bit_length - 1;
        else
          tx_bit_timer <= tx_bit_timer - 1;
        end if;

        case state_emitter is
          -- wait new data to transmit
          when IDLE =>

            -- manage ready signal
            dx_tready_i <= not(CFG_USE_PROTOCOL and CTS);

            -- new data to transmit
            if (DX_TVALID = '1') and (dx_tready_i = '1') then
              state_emitter     <= START_BIT;
              dx_tready_i       <= '0';
              TXD               <= '0';
              tx_bit_timer      <= bit_length - 1;  -- reset timer
              tx_data_r         <= DX_TDATA;
              tx_parity_r       <= CFG_PARITY_ODD_EVEN;
            end if;

          -- manage start bit
          when START_BIT =>

            -- end of start bit
            if (tx_bit_timer = 0) then
              state_emitter     <= DATA_BIT;
              TXD               <= tx_data_r(0);
              tx_bit_counter    <= (others=>'0');
              tx_parity_r       <= CFG_PARITY_ODD_EVEN xor tx_data_r(0);
            end if;

          -- manage sending of data bits
          when DATA_BIT =>

            -- end of current data bit
            if (tx_bit_timer = 0) then

              if (tx_bit_counter = (bit_number-1)) then
                tx_bit_counter  <= (others=>'0');
                if (CFG_PARITY_ON_OFF = '1') then
                  state_emitter <= PARITY_BIT;
                  TXD           <= tx_parity_r;
                else
                  state_emitter <= STOP_BIT;
                  TXD           <= '1';
                end if;
              else
                TXD             <= tx_data_r(to_integer(tx_bit_counter) + 1);
                tx_bit_counter  <= tx_bit_counter + 1;
                tx_parity_r     <= tx_parity_r xor tx_data_r(to_integer(tx_bit_counter) + 1);
              end if;

            end if;

          -- manage sending of computed parity bit
          when PARITY_BIT =>

            -- end of parity bit
            if (tx_bit_timer = 0) then
              state_emitter     <= STOP_BIT;
              TXD               <= '1';
            end if;

          -- manage stop bit(s)
          when STOP_BIT =>
            if (tx_bit_timer = 0) then
              -- 2 Stop Bit
              if (CFG_BIT_STOP = '1') and (tx_bit_counter = 0) then
                tx_bit_counter  <= tx_bit_counter + 1;
              -- end of stop bits
              else
                state_emitter   <= IDLE;
                dx_tready_i     <= '1';
              end if;
            end if;
        end case;
      end if;
    end if;
  end process p_emitter;



  ------------------------------
  -- Process to handle RX serial link
  ------------------------------
  p_receiver : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      state_receiver  <= IDLE;
      rx_bit_timer    <= (others => '0');
      rx_bit_counter  <= (others => '0');
      rx_data_r       <= (others => '0');
      rx_parity_r     <= '0';
      DR_TDATA        <= (others => '0');
      dr_tvalid_i     <= '0';
      DR_TUSER        <= '0';
      ERROR_DATA_DROP <= '0';
      rxd_r           <= '0';

    elsif rising_edge(CLK) then

      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        state_receiver  <= IDLE;
        rx_bit_timer    <= (others => '0');
        rx_bit_counter  <= (others => '0');
        rx_data_r       <= (others => '0');
        rx_parity_r     <= '0';
        DR_TDATA        <= (others => '0');
        dr_tvalid_i     <= '0';
        DR_TUSER        <= '0';
        ERROR_DATA_DROP <= '0';
        rxd_r           <= '0';

      else
        -- clear drop frame error
        ERROR_DATA_DROP <= '0';
        -- register RXD for edge detection
        rxd_r           <= RXD;
        -- clear tvalid
        if (DR_TREADY = '1') then
          dr_tvalid_i     <= '0';
        end if;

        -- timer Management
        if (rx_bit_timer = 0) then
          rx_bit_timer  <= bit_length - 1;
        else
          rx_bit_timer  <= rx_bit_timer - 1;
        end if;

        case state_receiver is
        -- wait reception of data
        when IDLE =>
          -- start of frame is detected on falling edge of RXD
          if (rts_i = '0') and ((RXD = '0') and (rxd_r ='1')) then
            state_receiver  <= START_BIT;
            rx_parity_r     <= CFG_PARITY_ODD_EVEN;
          end if;

          -- reset timer at the middle of a bit_length
          rx_bit_timer  <= shift_right(bit_length, 1) - 1;

        -- move to the theoric middle of start bit
        when START_BIT =>
          if (rx_bit_timer = 0) then
            state_receiver  <= DATA_BIT;
          end if;

        -- get data bit and compute parity bit
        when DATA_BIT =>
          -- middle of current Data bit
          if (rx_bit_timer = 0) then
            rx_data_r(to_integer(rx_bit_counter)) <= RXD;
            rx_parity_r                           <= rx_parity_r xor RXD;

            -- last bit of the word
            if (rx_bit_counter = (bit_number - 1)) then
              rx_bit_counter    <= (others => '0');

              -- use of Parity bit
              if (CFG_PARITY_ON_OFF = '1') then
                state_receiver  <= PARITY_BIT;
              else
                state_receiver  <= STOP_BIT;
                DR_TUSER        <= '0';
              end if;

            else
              rx_bit_counter    <= rx_bit_counter + 1;
            end if;

          end if;

        -- compare received and computed parity bits
        when PARITY_BIT =>
          -- middle of current Data bit
          if (rx_bit_timer = 0) then
            state_receiver  <= STOP_BIT;
            DR_TUSER        <= RXD xor rx_parity_r; -- Checking parity bit
          end if;

        -- wait middle of first stop bit to output the received data
        when STOP_BIT =>
          if (bit_number = 7) then
            rx_data_r(7)    <= '0';
          end if;

          if (rx_bit_timer = 0) and (RXD ='1') then
            state_receiver  <= IDLE;
            if (dr_tvalid_i = '1') and (DR_TREADY = '0') then
              ERROR_DATA_DROP <= '1';
            else
              DR_TDATA        <= rx_data_r;
            end if;
            dr_tvalid_i       <= '1';

          -- no data are transmitted if STOP bit is not detected
          elsif rx_bit_timer = 0 then
            state_receiver  <= IDLE;
          end if;

        end case;
      end if;
    end if;
  end process p_receiver;

  ------------------------------
  -- Process to handle configuration of serial link
  ------------------------------
  p_config : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      bit_length   <= to_unsigned(C_MAX_BIT_LENGTH, C_NB_BITS);
      bit_number   <= "1000";

    elsif rising_edge(CLK) then

      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        bit_length   <= to_unsigned(C_MAX_BIT_LENGTH, C_NB_BITS);
        bit_number   <= "1000";
      else

        -- convert baudrate constant to time for a bit in number of clock period
        case CFG_BAUDRATE is
          when C_UART_75_BAUDS =>
            bit_length <= to_unsigned(calc_period(75, G_CLK_FREQ), C_NB_BITS);
          when C_UART_150_BAUDS =>
            bit_length  <= to_unsigned(calc_period(150, G_CLK_FREQ), C_NB_BITS);
          when C_UART_300_BAUDS =>
            bit_length <= to_unsigned(calc_period(300, G_CLK_FREQ), C_NB_BITS);
          when C_UART_600_BAUDS =>
            bit_length <= to_unsigned(calc_period(600, G_CLK_FREQ), C_NB_BITS);
          when C_UART_1200_BAUDS =>
            bit_length <= to_unsigned(calc_period(1200, G_CLK_FREQ), C_NB_BITS);
          when C_UART_2400_BAUDS =>
            bit_length <= to_unsigned(calc_period(2400, G_CLK_FREQ), C_NB_BITS);
          when C_UART_4800_BAUDS =>
            bit_length  <= to_unsigned(calc_period(4800, G_CLK_FREQ), C_NB_BITS);
          when C_UART_9600_BAUDS =>
            bit_length  <= to_unsigned(calc_period(9600, G_CLK_FREQ), C_NB_BITS);
          when C_UART_19200_BAUDS =>
            bit_length  <= to_unsigned(calc_period(19200, G_CLK_FREQ), C_NB_BITS);
          when C_UART_38400_BAUDS =>
            bit_length  <= to_unsigned(calc_period(38400, G_CLK_FREQ), C_NB_BITS);
          when C_UART_57600_BAUDS =>
            bit_length  <= to_unsigned(calc_period(57600, G_CLK_FREQ), C_NB_BITS);
          when C_UART_115200_BAUDS =>
            bit_length  <= to_unsigned(calc_period(115200, G_CLK_FREQ), C_NB_BITS);
          when others =>
            -- C_UART_9600_BAUDS
            bit_length <= to_unsigned(calc_period(9600, G_CLK_FREQ), C_NB_BITS);
        end case;

        -- Configure data size
        if (CFG_SIZE = '0') then
          bit_number <= "1000"; --8 data bits
        else
          bit_number <= "0111"; --7 data bits
        end if;
      end if;

    end if;
  end process p_config;


  ------------------------------------
  --- process that generate RTS signal
  ------------------------------------
  p_rts : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      rts_i <= '0';

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        rts_i <= '0';
      else
        -- update rts signals only in rx state IDLE or STOP_BIT
        if (state_receiver = IDLE) or (state_receiver = STOP_BIT) then
          rts_i <= (not DR_TREADY) and CFG_USE_PROTOCOL;
        end if;
      end if;
    end if;
  end process p_rts;

end rtl;
