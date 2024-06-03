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

----------------------------------------------------------------------------------
-- Expected Protocol
----------------------------------------------------------------------------------
--
-- This component gets ASCII data from a stream and convert it to AXI4-lite accesses.
--
-- Typically this bridge is inserted after a UART interface and allow access to the
-- internal memory space with a human readable protocol. Depending on the system
-- specification, FIFOs may be added on the AXI-Stream side so as to buffer requests.
--
-- Numerals are written in a hexadecimal way, there are 2 types of access:
--  1. WRITE access. The components expects a string on this format
--     "Waaaa-dddddddd\r"
--     'W' is a fixed character denoting the WRITE request
--     'aaaa' is the address of the request in hexadecimal characters
--     '-' (hyphen) is the separation between address field and data field
--     'dddddddd' is the data word to write in hexadecimal characters
--     '\r' is the carriage return character expected at end of frame
--
--     The request is responded with the following string
--     "Waaaa-dddddddd\r"
--     which should be a copy of the input request if successfull
--     on a AXI4-lite error, the data value is replaced by 'X' characters
--
--  2. READ access. The components expects a string on this format
--     "Raaaa\r"
--     'R' is a fixed character denoting the READ request
--     'aaaa' is the address of the request in hexadecimal characters
--     '\r' is the carriage return character expected at end of frame
--
--     The request is responded with the following string
--     "Raaaa-dddddddd\r"
--     'R' is a fixed character denoting the READ request
--     'aaaa' is the address of the request (should be a copy of the input request)
--     '-' (hyphen) is the separation between address field and data field
--     'dddddddd' is the read data word in hexadecimal characters
--     '\r' is the carriage return character denoting the end of frame
--     As for the WRITE access, the data value is replaced by 'X' on an AXI4-lite
--     error.
--
-- As ADDRESS and DATA widths are generic parameters, the ASCII expected
-- size varies with them. So for G_AXI_ADDR_WIDTH=8, G_AXI_DATA_WIDTH=16, the expected
-- format becomes "Waa-dddd\r" and "Raa\r".
--
----------------------------------------------------------------------------------
-- Ill formatted requests management
----------------------------------------------------------------------------------
--
-- As for the implementation, the module waits for the Carriage Return (CR) character at
-- the end of each request. The module may stall if this character is never sent.
--
-- On the same basis, the module waits for a Hyphen ('-') between the address and data
-- field in a write request. The module may stall if this character is never sent.
--
-- The implementation expects only uppercase letters for the hexadecimal digits.
-- No verification about the validity of received characters is done. Any invalid
-- character is understood as 'F'.
--
-- The implementation doesn't check for the length of fields, it simply shifts the
-- address and data field into the internal registers. A shorter fied is
-- automatically filled with '0' at the front. A longer field sees his MSB shifted
-- away. The resulting value is the modulo of the requested value.
--
-- In any case, the response string gives the values as they where decoded and used.
--
-- If the request doesn't start by the 'W' or 'R' characters (the only 2 commands
-- supported) the character is discarded away silently. The next character is taken
-- in consideration, this allows the command to end in CR-LF if necessary, it's
-- also allows the module to get back on his feets if a bad characters was inserted
-- inadvertently.
--
-- On the same basis, if a read request contains an hyphen, or a write request is
-- missing one, the request is interrupted and discarded away silently.
--
----------------------------------------------------------------------------------
-- Examples with default values of generic
----------------------------------------------------------------------------------
--
--   -----------------------------------------------------------------------------------------------------------
--  | Brief          | Received on AXIS slave | Request on AXI4-lite bus  | RESP on bus | Return on AXIS master |
--   -----------------------------------------------------------------------------------------------------------
--  | normal write   | "W0AFD-DEADB0D1\r"     | write 0xDEADB0D1 @ 0x0AFD | OKAY        | "W0AFD-DEADB0D1\r"    |
--  |                |                        |                           |             |                       |
--  | normal read    | "R12AB\r"              | read  0xCAFEDECA @ 0x12AB | OKAY        | "R12AB-CAFEDECA\r"    |
--  |                |                        |                           |             |                       |
--  | error write    | "W0AFD-DEADB0D1\r"     | write 0xDEADB0D1 @ 0x0AFD | SLVERR      | "W0AFD-XXXXXXXX\r"    |
--  |                |                        |                           |             |                       |
--  | error read     | "R12AB\r"              | read  0xCAFEDECA @ 0x12AB | SLVERR      | "R12AB-XXXXXXXX\r"    |
--  |                |                        |                           |             |                       |
--  | long address   | "W50AFD-DEADB0D1\r"    | write 0xDEADB0D1 @ 0x0AFD | OKAY        | "W0AFD-DEADB0D1\r"    |
--  |                |                        |                           |             |                       |
--  | long data      | "W0AFD-5DEADB0D1\r"    | write 0xDEADB0D1 @ 0x0AFD | OKAY        | "W0AFD-DEADB0D1\r"    |
--  |                |                        |                           |             |                       |
--  | short address  | "WAFD-DEADB0D1\r"      | write 0xDEADB0D1 @ 0x0AFD | OKAY        | "W0AFD-DEADB0D1\r"    |
--  |                |                        |                           |             |                       |
--  | short data     | "W0AFD-B0D1\r"         | write 0x0000B0D1 @ 0x0AFD | OKAY        | "W0AFD-0000B0D1\r"    |
--  |                |                        |                           |             |                       |
--  | unvalid char   | "W0?Fd-DEiDB0S1\r"     | write 0xDEFDB0F1 @ 0x0FFF | OKAY        | "W0FFF-DEFDB0F1\r"    |
--  |                |                        |                           |             |                       |
--  | stuffed start  | "xCfW0AFD-DEADB0D1\r"  | write 0xDEADB0D1 @ 0x0AFD | OKAY        | "W0AFD-DEADB0D1\r"    |
--  |                |                        |                           |             |                       |
--  | hyphen in read | "R12AB-1234DBCD\r"     | nothing                   | nothing     | nothing               |
--  |                |                        |                           |             |                       |
--  | missing hyphen | "W0AFDDEADB0D1\r"      | nothing                   | nothing     | nothing               |
--   -----------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.dev_utils_pkg.all;
use common.axi4lite_utils_pkg.C_AXI_RESP_OKAY;

entity bridge_ascii_to_axi4lite is
  generic(
    G_ACTIVE_RST     : std_logic               := '0';      -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST      : boolean                 := true;     -- Type of reset used (synchronous or asynchronous resets)
    G_AXI_DATA_WIDTH : integer range 8 to 1024 := 32;       -- Width of the data vector of the axi4-lite
    G_AXI_ADDR_WIDTH : integer range 4 to 64   := 16        -- Width of the address vector of the axi4-lite
  );
  port(
    -- GLOBAL SIGNALS
    CLK            : in  std_logic;
    RST            : in  std_logic;
    -- SLAVE AXIS
    S_AXIS_TDATA   : in  std_logic_vector(7 downto 0);
    S_AXIS_TVALID  : in  std_logic;
    S_AXIS_TREADY  : out std_logic;
    -- MASTER AXIS
    M_AXIS_TDATA   : out std_logic_vector(7 downto 0);
    M_AXIS_TVALID  : out std_logic;
    M_AXIS_TREADY  : in  std_logic;
    -- MASTER AXI4-LITE
    -- -- ADDRESS WRITE (AW)
    M_AXIL_AWADDR  : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
    M_AXIL_AWPROT  : out std_logic_vector(2 downto 0);
    M_AXIL_AWVALID : out std_logic;
    M_AXIL_AWREADY : in  std_logic;
    -- -- WRITE (W)
    M_AXIL_WDATA   : out std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
    M_AXIL_WSTRB   : out std_logic_vector(((G_AXI_DATA_WIDTH / 8) - 1) downto 0);
    M_AXIL_WVALID  : out std_logic;
    M_AXIL_WREADY  : in  std_logic;
    -- -- RESPONSE WRITE (B)
    M_AXIL_BRESP   : in  std_logic_vector(1 downto 0);
    M_AXIL_BVALID  : in  std_logic;
    M_AXIL_BREADY  : out std_logic;
    -- -- ADDRESS READ (AR)
    M_AXIL_ARADDR  : out std_logic_vector(G_AXI_ADDR_WIDTH - 1 downto 0);
    M_AXIL_ARPROT  : out std_logic_vector(2 downto 0);
    M_AXIL_ARVALID : out std_logic;
    M_AXIL_ARREADY : in  std_logic;
    -- -- READ (R)
    M_AXIL_RDATA   : in  std_logic_vector(G_AXI_DATA_WIDTH - 1 downto 0);
    M_AXIL_RVALID  : in  std_logic;
    M_AXIL_RRESP   : in  std_logic_vector(1 downto 0);
    M_AXIL_RREADY  : out std_logic
  );
end entity bridge_ascii_to_axi4lite;

architecture rtl of bridge_ascii_to_axi4lite is

  --
  -- CONSTANTS
  --

  -- number of address characters
  constant C_ASCII_ADDR_WIDTH : integer := div_ceil(G_AXI_ADDR_WIDTH, 4);
  -- number of data characters
  constant C_ASCII_DATA_WIDTH : integer := div_ceil(G_AXI_DATA_WIDTH, 4);

  -- width of counter, depends on the greatest number of characters to count
  constant C_CNT_WIDTH : integer := log2_ceil(amax(C_ASCII_ADDR_WIDTH, C_ASCII_DATA_WIDTH));

  --
  -- FUNCTIONS
  --

  -- Convert ASCII character (in std_logic_vector) to value (in unsigned)
  function from_ascii_to_value(constant char : in std_logic_vector(7 downto 0)) return unsigned is
    -- type for table
    type conv_table is array (character) of unsigned(3 downto 0);
    -- ROM for lookup
    constant C_ASCII_TO_VALUE_LUT : conv_table := (
      '0'    => x"0",
      '1'    => x"1",
      '2'    => x"2",
      '3'    => x"3",
      '4'    => x"4",
      '5'    => x"5",
      '6'    => x"6",
      '7'    => x"7",
      '8'    => x"8",
      '9'    => x"9",
      'A'    => x"A",
      'B'    => x"B",
      'C'    => x"C",
      'D'    => x"D",
      'E'    => x"E",
      'F'    => x"F",
      others => x"F"                                        -- default is set to F
    );
  begin
    -- look up in the table
    return C_ASCII_TO_VALUE_LUT(character'val(to_integer(unsigned(char))));
  end function from_ascii_to_value;

  -- Convert value (in unsigned) to ASCII character (in std_logic_vector)
  function from_value_to_ascii(constant val : in unsigned(3 downto 0)) return std_logic_vector is
    -- type for table
    type ascii_vector is array (natural range <>) of std_logic_vector(7 downto 0);
    -- ROM for lookup
    constant C_VALUE_TO_ASCII_LUT : ascii_vector(15 downto 0) := (
      0  => std_logic_vector(to_unsigned(character'pos('0'), 8)),
      1  => std_logic_vector(to_unsigned(character'pos('1'), 8)),
      2  => std_logic_vector(to_unsigned(character'pos('2'), 8)),
      3  => std_logic_vector(to_unsigned(character'pos('3'), 8)),
      4  => std_logic_vector(to_unsigned(character'pos('4'), 8)),
      5  => std_logic_vector(to_unsigned(character'pos('5'), 8)),
      6  => std_logic_vector(to_unsigned(character'pos('6'), 8)),
      7  => std_logic_vector(to_unsigned(character'pos('7'), 8)),
      8  => std_logic_vector(to_unsigned(character'pos('8'), 8)),
      9  => std_logic_vector(to_unsigned(character'pos('9'), 8)),
      10 => std_logic_vector(to_unsigned(character'pos('A'), 8)),
      11 => std_logic_vector(to_unsigned(character'pos('B'), 8)),
      12 => std_logic_vector(to_unsigned(character'pos('C'), 8)),
      13 => std_logic_vector(to_unsigned(character'pos('D'), 8)),
      14 => std_logic_vector(to_unsigned(character'pos('E'), 8)),
      15 => std_logic_vector(to_unsigned(character'pos('F'), 8))
    );
  begin
    -- look up in table
    return C_VALUE_TO_ASCII_LUT(to_integer(val));
  end function from_value_to_ascii;

  -- INTERNAL SIGNAL
  -- -- AXIS SLAVE
  signal s_axis_tready_int  : std_logic;
  -- -- AXIS MASTER
  signal m_axis_tvalid_int  : std_logic;
  -- -- AXI4LITE MASTER
  -- -- -- ADDR WRITE (AW)
  signal m_axil_awvalid_int : std_logic;
  -- -- -- WRITE (R)
  signal m_axil_wvalid_int  : std_logic;
  -- -- -- RESPONSE WRITE (B)
  signal m_axil_bready_int  : std_logic;
  -- -- -- ADDR READ (AR)
  signal m_axil_arvalid_int : std_logic;
  -- -- -- READ (R)
  signal m_axil_rready_int  : std_logic;

  -- register for read ('1') or write ('0') access
  signal rd_not_wr : std_logic;

  -- register for address, shared between read and write channel for simplicity
  signal addr_r    : unsigned(G_AXI_ADDR_WIDTH - 1 downto 0);
  -- resized to a 4 bits multiple
  signal addr_resp : unsigned((C_ASCII_ADDR_WIDTH * 4) - 1 downto 0);

  -- register for data
  signal data_r    : unsigned(G_AXI_DATA_WIDTH - 1 downto 0);
  -- resized to a 4 bits multiple
  signal data_resp : unsigned((C_ASCII_DATA_WIDTH * 4) - 1 downto 0);

  -- counter
  signal cnt : unsigned(C_CNT_WIDTH - 1 downto 0);

  -- state machine
  type t_states is (
    IDLE,
    GET_ADDR, GET_DATA,
    WAIT_RESP,
    SEND_ADDR, SEND_HYPHEN, SEND_DATA, SEND_CR
  );
  signal current_state : t_states;

begin

  -- assignment of readback signals
  S_AXIS_TREADY  <= s_axis_tready_int;
  M_AXIS_TVALID  <= m_axis_tvalid_int;
  M_AXIL_AWVALID <= m_axil_awvalid_int;
  M_AXIL_WVALID  <= m_axil_wvalid_int;
  M_AXIL_BREADY  <= m_axil_bready_int;
  M_AXIL_ARVALID <= m_axil_arvalid_int;
  M_AXIL_RREADY  <= m_axil_rready_int;

  -- assignement of addresses and data
  M_AXIL_AWADDR <= std_logic_vector(addr_r);
  M_AXIL_ARADDR <= std_logic_vector(addr_r);
  M_AXIL_WDATA  <= std_logic_vector(data_r);

  -- assignment of signals that are constants
  M_AXIL_AWPROT <= (others => '0');
  M_AXIL_WSTRB  <= (others => '1');
  M_AXIL_ARPROT <= (others => '0');

  -- resizing the address registers
  addr_resp <= resize(addr_r, addr_resp'length);

  -- resizing and muxing data register
  data_resp <= resize(unsigned(M_AXIL_RDATA), data_resp'length) when rd_not_wr = '1' else
               resize(data_r, data_resp'length);

  --
  --
  -- FSM
  --

  -- define the state machine
  FSM : process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- asynchronous reset
      -- ports
      s_axis_tready_int  <= '0';
      m_axis_tvalid_int  <= '0';
      M_AXIS_TDATA       <= (others => '0');
      m_axil_awvalid_int <= '0';
      m_axil_wvalid_int  <= '0';
      m_axil_arvalid_int <= '0';
      m_axil_bready_int  <= '0';
      m_axil_rready_int  <= '0';

      -- internals
      rd_not_wr     <= '0';
      addr_r        <= (others => '0');
      data_r        <= (others => '0');
      current_state <= IDLE;
      cnt           <= (others => '0');

    elsif rising_edge(CLK) then

      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- synchronous reset
        -- ports
        s_axis_tready_int  <= '0';
        m_axis_tvalid_int  <= '0';
        M_AXIS_TDATA       <= (others => '0');
        m_axil_awvalid_int <= '0';
        m_axil_wvalid_int  <= '0';
        m_axil_arvalid_int <= '0';
        m_axil_bready_int  <= '0';
        m_axil_rready_int  <= '0';

        -- internals
        rd_not_wr     <= '0';
        addr_r        <= (others => '0');
        data_r        <= (others => '0');
        current_state <= IDLE;
        cnt           <= (others => '0');

      else

        ----------------------------------
        -- Handshakes
        ----------------------------------

        if M_AXIL_AWREADY = '1' then
          m_axil_awvalid_int <= '0';
        end if;

        if M_AXIL_WREADY = '1' then
          m_axil_wvalid_int <= '0';
        end if;

        if M_AXIL_ARREADY = '1' then
          m_axil_arvalid_int <= '0';
        end if;

        if M_AXIS_TREADY = '1' then
          m_axis_tvalid_int <= '0';
        end if;

        ----------------------------------
        -- Pulses
        ----------------------------------
        m_axil_bready_int <= '0';
        m_axil_rready_int <= '0';

        ----------------------------------
        -- Main FSM
        ----------------------------------

        case current_state is

          -- wait for a character to start a request
          when IDLE =>

            -- check if all previous transactions where sent on AXI4-lite bus
            if (m_axil_awvalid_int /= '1') and (m_axil_wvalid_int /= '1') and (m_axil_arvalid_int /= '1') then
              -- ready to receive the next character when
              s_axis_tready_int <= '1';

              -- reset internal registers
              addr_r            <= (others => '0');
              data_r            <= (others => '0');

            end if;

            -- get the first character of the command
            if (s_axis_tready_int = '1') and (S_AXIS_TVALID = '1') then

              case character'val(to_integer(unsigned(S_AXIS_TDATA))) is

                -- read request
                when 'R' =>
                  rd_not_wr     <= '1';
                  current_state <= GET_ADDR;

                -- write request
                when 'W' =>
                  rd_not_wr     <= '0';
                  current_state <= GET_ADDR;

                -- not supported operations
                when others =>
                  -- discard the character and do nothing
                  null;

              end case;

            end if;

          -- collect address until the hyphen character
          when GET_ADDR =>

            -- get the next character
            if (s_axis_tready_int = '1') and (S_AXIS_TVALID = '1') then

              -- check if received character is hyphen
              if S_AXIS_TDATA = std_logic_vector(to_unsigned(character'pos('-'), 8)) then

                -- check if request was a write
                if rd_not_wr = '0' then
                  -- get the data field
                  current_state <= GET_DATA;
                else
                  -- error on command, back to IDLE doing nothing
                  current_state <= IDLE;
                end if;

              -- check if received character is CARRIAGE RETURN
              elsif S_AXIS_TDATA = std_logic_vector(to_unsigned(character'pos(CR), 8)) then

                -- check if request was a READ
                if rd_not_wr = '1' then
                  -- validate the address field
                  m_axil_arvalid_int <= '1';
                  -- wait for the response
                  current_state      <= WAIT_RESP;
                  -- not ready anymore for another request
                  s_axis_tready_int  <= '0';
                else
                  -- error on command, back to IDLE doing nothing
                  current_state <= IDLE;
                end if;

              -- for other characters, use them as hexadecimal digit
              else

                -- shift and convert address
                addr_r <= addr_r(addr_r'high - 4 downto 0) & from_ascii_to_value(S_AXIS_TDATA);

              end if;

            end if;

          -- collect data until the CR character
          when GET_DATA =>
            -- only on a WRITE request

            -- get the next character
            if (s_axis_tready_int = '1') and (S_AXIS_TVALID = '1') then

              -- check if carriage return character was received
              if S_AXIS_TDATA = std_logic_vector(to_unsigned(character'pos(CR), 8)) then

                -- validate write address and data fields
                m_axil_awvalid_int <= '1';
                m_axil_wvalid_int  <= '1';
                -- wait for response
                current_state      <= WAIT_RESP;
                -- not ready anymore
                s_axis_tready_int  <= '0';

              else
                -- use character as data
                -- shift and convert data
                data_r <= data_r(data_r'high - 4 downto 0) & from_ascii_to_value(S_AXIS_TDATA);
              end if;

            end if;

          -- wait for response and send the first character
          when WAIT_RESP =>

            -- send next character only if bus is available
            if (M_AXIS_TREADY = '1') or (m_axis_tvalid_int = '0') then

              -- check the type of access
              if rd_not_wr = '0' then
                -- WRITE access

                -- wait for response
                if M_AXIL_BVALID = '1' then
                  M_AXIS_TDATA      <= std_logic_vector(to_unsigned(character'pos('W'), 8));
                  m_axis_tvalid_int <= '1';

                  -- set counter for address
                  cnt           <= to_unsigned(C_ASCII_ADDR_WIDTH - 1, C_CNT_WIDTH);
                  current_state <= SEND_ADDR;
                end if;
              else
                -- READ access

                -- wait for response
                if M_AXIL_RVALID = '1' then
                  M_AXIS_TDATA      <= std_logic_vector(to_unsigned(character'pos('R'), 8));
                  m_axis_tvalid_int <= '1';

                  -- set counter for address
                  cnt           <= to_unsigned(C_ASCII_ADDR_WIDTH - 1, C_CNT_WIDTH);
                  current_state <= SEND_ADDR;
                end if;
              end if;
            end if;

          -- send the address
          when SEND_ADDR =>

            -- send next character only if bus is available
            if (M_AXIS_TREADY = '1') or (m_axis_tvalid_int = '0') then

              M_AXIS_TDATA      <= from_value_to_ascii(addr_resp((4 * to_integer(cnt)) + 3 downto 4 * to_integer(cnt)));
              m_axis_tvalid_int <= '1';

              -- check for counter
              if cnt > 0 then
                -- keep decrementing
                cnt <= cnt - 1;

              else
                -- send the hyphen
                current_state <= SEND_HYPHEN;
              end if;
            end if;

          -- send the HYPHEN character
          when SEND_HYPHEN =>

            -- send next character only if bus is available
            if (M_AXIS_TREADY = '1') or (m_axis_tvalid_int = '0') then

              M_AXIS_TDATA      <= std_logic_vector(to_unsigned(character'pos('-'), 8));
              m_axis_tvalid_int <= '1';

              -- set counter for data
              cnt           <= to_unsigned(C_ASCII_DATA_WIDTH - 1, C_CNT_WIDTH);
              current_state <= SEND_DATA;

            end if;

          -- send the DATA
          when SEND_DATA =>

            -- send next character only if bus is available
            if (M_AXIS_TREADY = '1') or (m_axis_tvalid_int = '0') then

              -- send data from mux
              M_AXIS_TDATA      <= from_value_to_ascii(data_resp((4 * to_integer(cnt)) + 3 downto 4 * to_integer(cnt)));
              m_axis_tvalid_int <= '1';

              -- check if the access has an error
              if ((rd_not_wr = '0') and (M_AXIL_BRESP /= C_AXI_RESP_OKAY)) or ((rd_not_wr = '1') and (M_AXIL_RRESP /= C_AXI_RESP_OKAY)) then
                -- send 'X'
                M_AXIS_TDATA <= std_logic_vector(to_unsigned(character'pos('X'), 8));
              end if;

              -- check for counter
              if cnt > 0 then
                -- keep decrementing
                cnt <= cnt - 1;

              else
                -- send the carriage return
                current_state <= SEND_CR;

                -- consumme the RESP channel
                if rd_not_wr = '0' then
                  m_axil_bready_int <= '1';
                else
                  m_axil_rready_int <= '1';
                end if;

              end if;
            end if;

          -- send the CARRIAGE RETURN character
          when SEND_CR =>

            -- send next character only if bus is available
            if (M_AXIS_TREADY = '1') or (m_axis_tvalid_int = '0') then

              M_AXIS_TDATA      <= std_logic_vector(to_unsigned(character'pos(CR), 8));
              m_axis_tvalid_int <= '1';

              -- end of request
              current_state <= IDLE;

            end if;

        end case;
      end if;
    end if;
  end process FSM;

end architecture rtl;
