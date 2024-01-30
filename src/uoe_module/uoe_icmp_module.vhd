library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.ICMP_pkg.all;

library common;
use common.axis_utils_pkg.axis_register;
use common.axis_utils_pkg.axis_fifo;

--------------------------------------------------------------------
-- ICMP Echo module
--------------------------------------------------------------------
--
-- This module respond to a ping echo request with the ICMP protocol
--
--------------------------------------------------------------------

entity uoe_icmp_module is
    generic(
        G_ACTIVE_RST    : std_logic := '1';     -- State at which the reset signal is asserted (active low or active high)
        G_ASYNC_RST     : boolean   := TRUE;    -- Type of reset used (synchronous or asynchronous resets)
        G_LE            : boolean   := TRUE;   -- Idicates if the incoming data is Little endian or big endian
        G_PING_SIZE     : integer   := 32;      -- Ping payload size in bytes
        G_FIFO_DEPTH    : positive  := 1536;    -- Depth of FIFO in bytes
        G_DATA_SIZE     : integer   := 16;      -- Width of the data bus in bits

        G_TUSER_WIDTH   : positive  := 1;       -- Width of the tuser vector of the stream
        G_TID_WIDTH     : positive  := 1;       -- Width of the tid vector of the stream
        G_TDEST_WIDTH   : positive  := 1        -- Width of the tdest vector of the stream
    );
    port(
        CLK             : in  std_logic;
        RST             : in  std_logic;
        ERROR_REG       : out std_logic_vector(1 downto 0);

        -- Echo request : data in
        REQUEST_TDATA    : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
        REQUEST_TVALID   : in  std_logic;
        REQUEST_TLAST    : in  std_logic;
        REQUEST_TUSER    : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
        REQUEST_TSTRB    : in  std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
        REQUEST_TKEEP    : in  std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
        REQUEST_TID      : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
        REQUEST_TDEST    : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
        REQUEST_TREADY   : out std_logic;

        -- Echo reply : data out
        ECHO_TDATA       : out std_logic_vector(G_DATA_SIZE-1 downto 0);
        ECHO_TVALID      : out std_logic;
        ECHO_TLAST       : out std_logic;
        ECHO_TUSER       : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
        ECHO_TSTRB       : out std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
        ECHO_TKEEP       : out std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
        ECHO_TID         : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
        ECHO_TDEST       : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
        ECHO_TREADY      : in  std_logic
    );
end uoe_icmp_module;


architecture rtl of uoe_icmp_module is

-- FIFO Component
component axis_fifo is
  generic(
    G_COMMON_CLK  : boolean;
    G_ADDR_WIDTH  : positive;
    G_TDATA_WIDTH : positive;
    G_TUSER_WIDTH : positive;
    G_TID_WIDTH   : positive;
    G_TDEST_WIDTH : positive;
    G_PKT_WIDTH   : natural;
    G_RAM_STYLE   : string;
    G_ACTIVE_RST  : std_logic;
    G_ASYNC_RST   : boolean;
    G_SYNC_STAGE  : integer range 2 to integer'high
  );
  port(
    -- Axi4-stream slave
    S_CLK         : in  std_logic;
    S_RST         : in  std_logic;
    S_TDATA       : in  std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    S_TVALID      : in  std_logic;
    S_TLAST       : in  std_logic;
    S_TUSER       : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    S_TSTRB       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TKEEP       : in  std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    S_TID         : in  std_logic_vector(G_TID_WIDTH - 1 downto 0);
    S_TDEST       : in  std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    S_TREADY      : out std_logic;
    -- Axi4-stream master
    M_CLK         : in  std_logic;
    M_RST         : in  std_logic;
    M_TDATA       : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TVALID      : out std_logic;
    M_TLAST       : out std_logic;
    M_TUSER       : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    M_TSTRB       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TKEEP       : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TID         : out std_logic_vector(G_TID_WIDTH - 1 downto 0);
    M_TDEST       : out std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
    M_TREADY      : in  std_logic;
    -- Status
    WR_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);
    WR_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0);
    RD_DATA_COUNT : out std_logic_vector(G_ADDR_WIDTH downto 0);
    RD_PKT_COUNT  : out std_logic_vector(maximum(0,G_PKT_WIDTH - 1) downto 0)
  );
end component;

-- Constants
constant C_NBR_BITS       : integer   := 64+G_PING_SIZE*8;
constant C_FIFO_ADDR_SIZE : positive  := integer(ceil(log2(real(G_FIFO_DEPTH) / real((G_DATA_SIZE + 7) / 8))));

-- Start signal
signal start : std_logic;

-- Data status
signal store_status : store_state;

-- FIFO signals
signal wr_rst   : std_logic;
signal wr_en    : std_logic;
signal wr_data  : std_logic_vector(G_DATA_SIZE-1 downto 0);
signal wr_valid : std_logic;
signal wr_last  : std_logic;
signal wr_user  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
signal wr_strb  : std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
signal wr_keep  : std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
signal wr_id    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
signal wr_dest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
signal wr_ready : std_logic;
signal wr_count : std_logic_vector(C_FIFO_ADDR_SIZE downto 0);

signal rd_rst   : std_logic;
signal rd_en    : std_logic;
signal rd_data  : std_logic_vector(G_DATA_SIZE-1 downto 0);
signal rd_valid : std_logic;
signal rd_last  : std_logic;
signal rd_user  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
signal rd_strb  : std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
signal rd_keep  : std_logic_vector((G_DATA_SIZE / 8) - 1 downto 0);
signal rd_id    : std_logic_vector(G_TID_WIDTH - 1 downto 0);
signal rd_dest  : std_logic_vector(G_TDEST_WIDTH - 1 downto 0);
signal rd_ready : std_logic;
signal rd_count : std_logic_vector(C_FIFO_ADDR_SIZE downto 0);

-- Define Header
signal header_recv : std_logic_vector(63 downto 0);
signal header_snd : std_logic_vector(63 downto 0);

-- --------------------------------------------------------- ICMP Header ----------------------------------------------------------
-- 0             7               15                              31                              47                              63
-- +-------------+---------------+-------------------------------+-------------------------------+-------------------------------+
-- |    Type     |     Code      |          Checksum             |          Identifier           |       Sequence_number         |
-- +------------------------------------------------------------------------------------------------------------------------------

-- Checksum
signal sum              : std_logic_vector(23 downto 0);
signal checksum_recv    : std_logic_vector(15 downto 0);
signal checksum_snd     : std_logic_vector(15 downto 0);
signal chksm_en         : std_logic;
signal chksm_rst        : std_logic;

-- Count word received
signal nbit_recv : integer range 0 to 64+G_PING_SIZE*8 + G_DATA_SIZE;
-- Count word send
signal nbit_snd : integer range 0 to 64+G_PING_SIZE*8 + G_DATA_SIZE;

-- Save temporarly register
signal save_reg : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

-- Implement FIFO
inst_fifo_gen: component axis_fifo
    generic map(
      G_COMMON_CLK  => TRUE,
      G_ADDR_WIDTH  => C_FIFO_ADDR_SIZE,
      G_TDATA_WIDTH => G_DATA_SIZE,
      G_TUSER_WIDTH => G_TUSER_WIDTH,
      G_TID_WIDTH   => G_TID_WIDTH  ,
      G_TDEST_WIDTH => G_TDEST_WIDTH,
      G_PKT_WIDTH   => 0,
      G_RAM_STYLE   => "AUTO",
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_ASYNC_RST   => TRUE,
      G_SYNC_STAGE  => 2
    )
    port map(
      -- Axi4-stream slave
      S_CLK         => CLK,
      S_RST         => wr_rst,
      S_TDATA       => wr_data,
      S_TVALID      => wr_valid,
      S_TLAST       => wr_last,
      S_TUSER       => wr_user,
      S_TSTRB       => wr_strb,
      S_TKEEP       => wr_keep,
      S_TID         => wr_id,
      S_TDEST       => wr_dest,
      S_TREADY      => wr_ready,
      -- Axi4-stream master
      M_CLK         => CLK,
      M_RST         => rd_rst,
      M_TDATA       => rd_data,
      M_TVALID      => rd_valid,
      M_TLAST       => rd_last,
      M_TUSER       => rd_user,
      M_TSTRB       => rd_strb,
      M_TKEEP       => rd_keep,
      M_TID         => rd_id,
      M_TDEST       => rd_dest,
      M_TREADY      => rd_ready,
      -- status
      WR_DATA_COUNT => wr_count,
      WR_PKT_COUNT  => open,
      RD_DATA_COUNT => rd_count,
      RD_PKT_COUNT  => open
    );

-- Assign valid and ready signals
rd_ready <= rd_en and ECHO_TREADY;
wr_valid <= wr_en;

-- Create new header
header_snd(63 downto 48) <= x"0000";                        -- Type + Code
header_snd(47 downto 32) <= checksum_snd;                   -- Checksum
header_snd(31 downto 0) <= header_recv(31 downto 0);        -- Identifier + sequence_number

-- Start when data is valid
start <= REQUEST_TVALID;

-- Compute Checksum
compute_checksum : process (CLK, RST, chksm_en, nbit_recv)
variable sum_tmp : std_logic_vector(23 downto 0);
variable count_recv : integer range 0 to 64+G_PING_SIZE*8;
variable i : integer range 0 to G_DATA_SIZE/8;
begin
    if ((RST = G_ACTIVE_RST and G_ASYNC_RST) or chksm_rst = G_ACTIVE_RST) then
        -- Async reset
        checksum_recv <= (others => '0');
        checksum_snd <= (others => '0');
        sum <= (others => '0');
        sum_tmp := (others => '0');
        count_recv := 0;
        nbit_recv <= 0;
        i := 0;
    elsif (rising_edge(CLK)) then
        if (RST = G_ACTIVE_RST and not G_ASYNC_RST) then
            -- Sync reset
            checksum_recv <= (others => '0');
            checksum_snd <= (others => '0');
            sum <= (others => '0');
            sum_tmp := (others => '0');
            count_recv := 0;
            nbit_recv <= 0;
            i := 0;
        -- Compute sum
        elsif (chksm_en = '1') then
            if (nbit_recv < C_NBR_BITS) then
                sum_tmp := (others => '0');
                i := 0;
                while i < G_DATA_SIZE/8 and count_recv < C_NBR_BITS loop
                    if (count_recv/8 mod 2 = 0) then
                        -- Even bytes
                        if G_LE then
                            -- Little endian
                            sum_tmp := std_logic_vector(unsigned(sum_tmp) + unsigned(REQUEST_TDATA(8*(i+1)-1 downto 8*i) & x"00"));
                        else
                            -- Big endian
                            sum_tmp := std_logic_vector(unsigned(sum_tmp) + unsigned(REQUEST_TDATA(G_DATA_SIZE-8*i-1 downto G_DATA_SIZE-8*(i+1)) & x"00"));
                        end if;
                    else
                        -- Odd bytes
                        if G_LE then
                            -- Little endian
                            sum_tmp := std_logic_vector(unsigned(sum_tmp) + unsigned(REQUEST_TDATA(8*(i+1)-1 downto 8*i)));
                        else
                            -- Big endian
                            sum_tmp := std_logic_vector(unsigned(sum_tmp) + unsigned(REQUEST_TDATA(G_DATA_SIZE-8*i-1 downto G_DATA_SIZE-8*(i+1))));
                        end if;
                    end if;
                    count_recv := count_recv + 8;
                    i := i + 1;
                end loop;
                sum <= std_logic_vector(unsigned(sum) + unsigned(sum_tmp));
                nbit_recv <= count_recv;
            else
                -- Sum finished
                if (sum(23 downto 16) = x"00") then
                -- Compute one's complement
                    checksum_recv <= compute_C1(input => std_logic_vector(unsigned(sum(15 downto 0)) - unsigned(header_recv(47 downto 32))));
                    checksum_snd <= compute_C1(input => std_logic_vector(unsigned(sum(15 downto 0)) + unsigned(header_snd(15 downto 0)) + unsigned(header_snd(63 downto 48)) + unsigned(header_snd(31 downto 16)) - unsigned(header_recv(15 downto 0)) - unsigned(header_recv(31 downto 16)) - unsigned(header_recv(63 downto 48)) - unsigned(header_recv(47 downto 32))));
                else
                -- Add retenue
                    sum <= std_logic_vector(unsigned(x"00" & sum(15 downto 0)) + unsigned(sum(19 downto 16)));
                end if;
            end if;
        end if;
    end if;
end process compute_checksum;

-- Store process for a data size of 64 bits or less
generate_max_64 : if (G_DATA_SIZE < 64 or G_DATA_SIZE = 64) generate
    -- Store Data in FIFO and build the echo
    store_data : process (CLK, RST)
    variable count_snd : integer range 0 to 64+G_PING_SIZE*8 + G_DATA_SIZE;
    variable j : integer range 0 to G_DATA_SIZE/8;
    begin
        if (RST = G_ACTIVE_RST and G_ASYNC_RST) then
            -- Async reset
            -- wr reset
            wr_rst          <= G_ACTIVE_RST;
            wr_data         <= (others => '0');
            wr_last         <= '0';
            wr_user         <= (others => '0');
            wr_strb         <= (others => '0');
            wr_keep         <= (others => '0');
            wr_id           <= (others => '0');
            wr_dest         <= (others => '0');
            REQUEST_TREADY   <= '0';
            -- Echo reset
            ECHO_TDATA   <= (others => 'Z');
            ECHO_TVALID  <= '0';
            ECHO_TLAST   <= '0';
            ECHO_TUSER   <= (others => '0');
            ECHO_TSTRB   <= (others => '0');
            ECHO_TKEEP   <= (others => '0');
            ECHO_TID     <= (others => '0');
            ECHO_TDEST   <= (others => '0');
            rd_rst      <= G_ACTIVE_RST;
            -- signal rest
            header_recv <= (others => '0');
            save_reg <= (others => '0');
            nbit_snd <= 0;
            count_snd := 0;
            wr_en <= '0';
            rd_en <= '0';
            chksm_en <= '0';
            store_status <= IDLE;
            ERROR_REG <= C_NO_ERROR;
        elsif (rising_edge(CLK)) then
            if (RST = G_ACTIVE_RST and not G_ASYNC_RST) then
                -- Sync reset
                -- wr reset
                wr_rst          <= G_ACTIVE_RST;
                wr_data         <= (others => '0');
                wr_last         <= '0';
                wr_user         <= (others => '0');
                wr_strb         <= (others => '0');
                wr_keep         <= (others => '0');
                wr_id           <= (others => '0');
                wr_dest         <= (others => '0');
                REQUEST_TREADY   <= '0';
                -- Echo reset
                ECHO_TDATA   <= (others => 'Z');
                ECHO_TVALID  <= '0';
                ECHO_TLAST   <= '0';
                ECHO_TUSER   <= (others => '0');
                ECHO_TSTRB   <= (others => '0');
                ECHO_TKEEP   <= (others => '0');
                ECHO_TID     <= (others => '0');
                ECHO_TDEST   <= (others => '0');
                rd_rst      <= G_ACTIVE_RST;
                -- signal rest
                header_recv <= (others => '0');
                save_reg <= (others => '0');
                nbit_snd <= 0;
                count_snd := 0;
                wr_en <= '0';
                rd_en <= '0';
                chksm_en <= '0';
                store_status <= IDLE;
                ERROR_REG <= C_NO_ERROR;
            else
                -- Defualt signal values
                wr_rst <= not G_ACTIVE_RST;
                rd_rst <= not G_ACTIVE_RST;
                wr_en <= '0';
                rd_en <= '0';
                chksm_en <= '0';
                chksm_rst <= not G_ACTIVE_RST;
                nbit_snd <= count_snd;
                ECHO_TDATA <= (others => 'Z');
                ECHO_TVALID  <= '0';
                ECHO_TLAST   <= '0';
                ECHO_TUSER   <= (others => '0');
                ECHO_TSTRB   <= (others => '0');
                ECHO_TKEEP   <= (others => '0');
                ECHO_TID     <= (others => '0');
                ECHO_TDEST   <= (others => '0');
                REQUEST_TREADY   <= '0';

                -- State machine
                case store_status is
                    when IDLE =>
                        count_snd := 0;
                        nbit_snd <= 0;
                        header_recv <= (others => '0');
                        wr_data <= (others => '0');
                        ECHO_TDATA <= (others => 'Z');
                        ERROR_REG <= C_NO_ERROR;
                        if(start = '1') then
                            chksm_en <= '1';
                            REQUEST_TREADY   <= '1';
                            store_status <= RECEIVE_HEADER;
                        end if;
                    when RECEIVE_HEADER =>

                        chksm_en <= '1';
                        j := 0;

                        -- Save data into the header
                        while j < G_DATA_SIZE/8 and nbit_recv < 64 - G_DATA_SIZE*(G_DATA_SIZE mod 16)/8 loop
                            if G_LE then
                                -- Little endian
                                header_recv(64-8*j-1-nbit_recv downto 64-8*(j+1)-nbit_recv) <= REQUEST_TDATA(8*(j+1)-1 downto 8*j);
                            else
                                -- Big endian
                                header_recv(64-8*j-1-nbit_recv downto 64-8*(j+1)-nbit_recv) <= REQUEST_TDATA(G_DATA_SIZE-8*j-1 downto G_DATA_SIZE-8*(j+1));
                            end if;
                            j := j + 1;
                        end loop;

                        -- Correct the header
                        if (nbit_recv < 64 and G_DATA_SIZE mod 16 /= 0 and (nbit_recv > 64 - G_DATA_SIZE or nbit_recv = 64 - G_DATA_SIZE)) then
                            save_reg <= REQUEST_TDATA;
                            if G_LE then
                                -- Little endian
                                for k in 0 to ((64-nbit_recv)/8) - 1 loop
                                    header_recv((k+1)*8-1 downto k*8) <= REQUEST_TDATA(64-nbit_recv-k*8-1 downto 64-nbit_recv-(k+1)*8);
                                end loop;
                            else
                                -- Big endian
                                header_recv(G_DATA_SIZE-8-1 downto 0) <= REQUEST_TDATA(G_DATA_SIZE-1 downto 8);
                            end if;
                        end if;

                        -- Change state
                        if (nbit_recv > 63) then
                            store_status <= RECEIVE_PAYLOAD;
                        end if;

                        wr_en <= '1';
                        wr_data         <= REQUEST_TDATA;
                        wr_last         <= REQUEST_TLAST;
                        wr_user         <= REQUEST_TUSER;
                        wr_strb         <= REQUEST_TSTRB;
                        wr_keep         <= REQUEST_TKEEP;
                        wr_id           <= REQUEST_TID;
                        wr_dest         <= REQUEST_TDEST;
                        REQUEST_TREADY   <= wr_ready;

                    when RECEIVE_PAYLOAD =>
                        chksm_en <= '1';
                        -- Write data in FIFO
                        if(nbit_recv < C_NBR_BITS) then

                            wr_en <= '1';
                            wr_data         <= REQUEST_TDATA;
                            wr_last         <= REQUEST_TLAST;
                            wr_user         <= REQUEST_TUSER;
                            wr_strb         <= REQUEST_TSTRB;
                            wr_keep         <= REQUEST_TKEEP;
                            wr_id           <= REQUEST_TID;
                            wr_dest         <= REQUEST_TDEST;
                            REQUEST_TREADY   <= wr_ready;

                        elsif (sum(19 downto 16) = x"0") then
                            store_status <= CHECK_ERROR;
                        end if;
                    when CHECK_ERROR =>
                        -- Checksum verification
                        if (header_recv(47 downto 32) /= checksum_recv) then
                            -- Wrong Checksum
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ERROR_REG <= C_CHECKSUM_ERROR;
                            store_status <= IDLE;
                        elsif (rd_valid = '0') then
                            -- FIFO full
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ERROR_REG <= C_FIFO_FULL;
                            store_status <= IDLE;
                        else
                            rd_en <= '1';
                            store_status <= SEND_HEADER;
                        end if;
                    when SEND_HEADER =>
                        -- Send the new header
                        if (nbit_snd < 64 - G_DATA_SIZE) then

                            if G_LE then
                                -- Little endian
                                if (G_DATA_SIZE mod 16 /= 0 and count_snd > 64 - G_DATA_SIZE - 1) then
                                    -- Correct last word if nesserary
                                    ECHO_TDATA <= save_reg;
                                else
                                    for k in 0 to G_DATA_SIZE/8 - 1 loop
                                        ECHO_TDATA(G_DATA_SIZE-8*k-1 downto G_DATA_SIZE-8*(k+1)) <= header_snd(64-count_snd-G_DATA_SIZE+8*(k+1)-1 downto 64-count_snd-G_DATA_SIZE+8*k);
                                    end loop;
                                end if;
                            else
                                -- Big endian
                                if (G_DATA_SIZE mod 16 /= 0 and count_snd > 64 - G_DATA_SIZE - 1) then
                                    -- Correct last word if nesserary
                                    ECHO_TDATA <= save_reg;
                                else
                                    ECHO_TDATA <= header_snd(64-count_snd-1 downto 64-count_snd-G_DATA_SIZE);
                                end if;
                            end if;
                            count_snd := count_snd + G_DATA_SIZE;

                        else
                            ECHO_TDATA <= rd_data;
                            count_snd := count_snd + G_DATA_SIZE;
                            store_status <= SEND_PAYLOAD;
                        end if;

                        ECHO_TVALID  <= rd_valid;
                        ECHO_TLAST   <= rd_last;
                        ECHO_TUSER   <= rd_user;
                        ECHO_TSTRB   <= rd_strb;
                        ECHO_TKEEP   <= rd_keep;
                        ECHO_TID     <= rd_id;
                        ECHO_TDEST   <= rd_dest;

                        -- Read axis signals
                        rd_en <= '1';

                    when SEND_PAYLOAD =>
                        -- Read FIFO
                        if (nbit_snd < C_NBR_BITS - G_DATA_SIZE) then
                            rd_en <= '1';
                            ECHO_TDATA   <= rd_data;
                            ECHO_TVALID  <= rd_valid;
                            ECHO_TLAST   <= rd_last;
                            ECHO_TUSER   <= rd_user;
                            ECHO_TSTRB   <= rd_strb;
                            ECHO_TKEEP   <= rd_keep;
                            ECHO_TID     <= rd_id;
                            ECHO_TDEST   <= rd_dest;
                            -- Count bits received
                            if (count_snd + G_DATA_SIZE > C_NBR_BITS and G_DATA_SIZE mod 16 /= 0) then
                                count_snd := count_snd + C_NBR_BITS-nbit_snd-G_DATA_SIZE;
                            else
                                count_snd := count_snd + G_DATA_SIZE;
                            end if;

                        else
                            -- Go to IDLE
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ERROR_REG <= C_NO_ERROR;
                            store_status <= IDLE;
                        end if;
                    when others =>
                        -- Go to IDLE
                        chksm_rst <= G_ACTIVE_RST;
                        wr_rst <= G_ACTIVE_RST;
                        rd_rst <= G_ACTIVE_RST;
                        ERROR_REG <= C_NO_ERROR;
                        store_status <= IDLE;
                end case;
            end if;
        end if;
    end process store_data;
end generate generate_max_64;



-- Store process for a data size of more than 64 bits
generate_min_64 : if (G_DATA_SIZE > 64) generate
    -- Store Data in FIFO and build the echo
    store_data : process (CLK, RST)
    variable count_snd : integer range 0 to 64+G_PING_SIZE*8 + G_DATA_SIZE;
    begin
        if (RST = G_ACTIVE_RST and G_ASYNC_RST) then
            -- Async reset
            -- wr reset
            wr_rst          <= G_ACTIVE_RST;
            wr_data         <= (others => '0');
            wr_last         <= '0';
            wr_user         <= (others => '0');
            wr_strb         <= (others => '0');
            wr_keep         <= (others => '0');
            wr_id           <= (others => '0');
            wr_dest         <= (others => '0');
            REQUEST_TREADY   <= '0';
            -- Echo reset
            ECHO_TDATA   <= (others => 'Z');
            ECHO_TVALID  <= '0';
            ECHO_TLAST   <= '0';
            ECHO_TUSER   <= (others => '0');
            ECHO_TSTRB   <= (others => '0');
            ECHO_TKEEP   <= (others => '0');
            ECHO_TID     <= (others => '0');
            ECHO_TDEST   <= (others => '0');
            rd_rst      <= G_ACTIVE_RST;
            -- signal rest
            header_recv <= (others => '0');
            save_reg <= (others => '0');
            nbit_snd <= 0;
            count_snd := 0;
            wr_en <= '0';
            rd_en <= '0';
            chksm_en <= '0';
            store_status <= IDLE;
            ERROR_REG <= C_NO_ERROR;
        elsif (rising_edge(CLK)) then
            if (RST = G_ACTIVE_RST and not G_ASYNC_RST) then
                -- Sync reset
                -- wr reset
                wr_rst          <= G_ACTIVE_RST;
                wr_data         <= (others => '0');
                wr_last         <= '0';
                wr_user         <= (others => '0');
                wr_strb         <= (others => '0');
                wr_keep         <= (others => '0');
                wr_id           <= (others => '0');
                wr_dest         <= (others => '0');
                REQUEST_TREADY   <= '0';
                -- Echo reset
                ECHO_TDATA   <= (others => 'Z');
                ECHO_TVALID  <= '0';
                ECHO_TLAST   <= '0';
                ECHO_TUSER   <= (others => '0');
                ECHO_TSTRB   <= (others => '0');
                ECHO_TKEEP   <= (others => '0');
                ECHO_TID     <= (others => '0');
                ECHO_TDEST   <= (others => '0');
                rd_rst      <= G_ACTIVE_RST;
                -- signal rest
                header_recv <= (others => '0');
                save_reg <= (others => '0');
                nbit_snd <= 0;
                count_snd := 0;
                wr_en <= '0';
                rd_en <= '0';
                chksm_en <= '0';
                store_status <= IDLE;
                ERROR_REG <= C_NO_ERROR;
            else
                -- Defualt signal values
                wr_rst <= not G_ACTIVE_RST;
                rd_rst <= not G_ACTIVE_RST;
                wr_en <= '0';
                rd_en <= '0';
                chksm_en <= '0';
                chksm_rst <= not G_ACTIVE_RST;
                nbit_snd <= count_snd;
                ECHO_TDATA <= (others => 'Z');
                ECHO_TVALID  <= '0';
                ECHO_TLAST   <= '0';
                ECHO_TUSER   <= (others => '0');
                ECHO_TSTRB   <= (others => '0');
                ECHO_TKEEP   <= (others => '0');
                ECHO_TID     <= (others => '0');
                ECHO_TDEST   <= (others => '0');
                REQUEST_TREADY   <= '0';

                -- State machine
                case store_status is
                    when IDLE =>
                        count_snd := 0;
                        nbit_snd <= 0;
                        header_recv <= (others => '0');
                        wr_data <= (others => '0');
                        ECHO_TDATA <= (others => 'Z');
                        ERROR_REG <= C_NO_ERROR;

                        if(start = '1') then
                            chksm_en <= '1';
                            REQUEST_TREADY   <= '1';
                            store_status <= RECEIVE_HEADER;
                        end if;
                    when RECEIVE_HEADER =>
                        -- Save the header
                        if G_LE then
                            -- Little endian
                            for k in 0 to 7 loop
                                header_recv(64-8*k-1 downto 64-8*(k+1)) <= REQUEST_TDATA(8*(k+1)-1 downto 8*k);
                            end loop;
                        else
                            -- Big endian
                            header_recv <= REQUEST_TDATA(G_DATA_SIZE-1 downto G_DATA_SIZE-64);
                        end if;

                        -- Register first word and header in the FIFO
                        wr_en <= '1';
                        wr_data         <= REQUEST_TDATA;
                        wr_last         <= REQUEST_TLAST;
                        wr_user         <= REQUEST_TUSER;
                        wr_strb         <= REQUEST_TSTRB;
                        wr_keep         <= REQUEST_TKEEP;
                        wr_id           <= REQUEST_TID;
                        wr_dest         <= REQUEST_TDEST;
                        REQUEST_TREADY   <= wr_ready;

                        -- Save word in a register instead of FIFO if the data fits in one word
                        if (G_DATA_SIZE > C_NBR_BITS or G_DATA_SIZE = C_NBR_BITS) then
                            save_reg <= REQUEST_TDATA;
                        end if;

                        chksm_en <= '1';
                        store_status <= RECEIVE_PAYLOAD;

                    when RECEIVE_PAYLOAD =>

                        -- Write data in FIFO
                        if(nbit_recv < C_NBR_BITS) then
                            wr_en <= '1';
                            wr_data         <= REQUEST_TDATA;
                            wr_last         <= REQUEST_TLAST;
                            wr_user         <= REQUEST_TUSER;
                            wr_strb         <= REQUEST_TSTRB;
                            wr_keep         <= REQUEST_TKEEP;
                            wr_id           <= REQUEST_TID;
                            wr_dest         <= REQUEST_TDEST;
                            REQUEST_TREADY   <= wr_ready;

                        elsif (sum(19 downto 16) = x"0") then
                            store_status <= CHECK_ERROR;
                        end if;
                        chksm_en <= '1';

                    when CHECK_ERROR =>
                        -- Error verification
                        if (header_recv(47 downto 32) /= checksum_recv) then
                            -- Wrong Checksum
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ERROR_REG <= C_CHECKSUM_ERROR;
                            store_status <= IDLE;
                        elsif (rd_valid = '0' and G_DATA_SIZE < C_NBR_BITS) then
                            -- FIFO full, don't check if the data fits in one word
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ERROR_REG <= C_FIFO_FULL;
                            store_status <= IDLE;
                        else
                            rd_en <= '1';
                            store_status <= SEND_HEADER;
                        end if;
                    when SEND_HEADER =>
                        -- Send header
                        rd_en <= '1';
                        if (G_DATA_SIZE < C_NBR_BITS) then
                            -- Send the header and the start of the payload
                            if G_LE then
                                -- Little endian
                                ECHO_TDATA(63 downto 0) <= convert_LE(input => header_snd);
                                ECHO_TDATA(G_DATA_SIZE-1 downto 64) <= rd_data(G_DATA_SIZE-1 downto 64);
                            else
                                -- Big endian
                                ECHO_TDATA(G_DATA_SIZE - 65 downto 0) <= rd_data(G_DATA_SIZE - 65 downto 0);
                                ECHO_TDATA(G_DATA_SIZE-1 downto G_DATA_SIZE - 64) <= header_snd;
                            end if;
                            store_status <= SEND_PAYLOAD;
                        else
                            -- Send word saved if the data fits in one word
                            if G_LE then
                                -- Little endian
                                ECHO_TDATA(63 downto 0) <= convert_LE(input => header_snd);
                                ECHO_TDATA(G_DATA_SIZE-1 downto 64) <= save_reg(G_DATA_SIZE-1 downto 64);
                            else
                                -- Big endian
                                ECHO_TDATA(G_DATA_SIZE - 65 downto 0) <= save_reg(G_DATA_SIZE - 65 downto 0);
                                ECHO_TDATA(G_DATA_SIZE-1 downto G_DATA_SIZE - 64) <= header_snd;
                            end if;
                            store_status <= IDLE;
                        end if;
                        count_snd := count_snd + G_DATA_SIZE;

                        ECHO_TVALID  <= rd_valid;
                        ECHO_TLAST   <= rd_last;
                        ECHO_TUSER   <= rd_user;
                        ECHO_TSTRB   <= rd_strb;
                        ECHO_TKEEP   <= rd_keep;
                        ECHO_TID     <= rd_id;
                        ECHO_TDEST   <= rd_dest;

                    when SEND_PAYLOAD =>
                        if (nbit_snd < C_NBR_BITS - G_DATA_SIZE) then
                            -- Read FIFO
                            rd_en <= '1';
                            ECHO_TDATA   <= rd_data;
                            ECHO_TVALID  <= rd_valid;
                            ECHO_TLAST   <= rd_last;
                            ECHO_TUSER   <= rd_user;
                            ECHO_TSTRB   <= rd_strb;
                            ECHO_TKEEP   <= rd_keep;
                            ECHO_TID     <= rd_id;
                            ECHO_TDEST   <= rd_dest;

                            -- Count bits received
                            if (count_snd + G_DATA_SIZE > C_NBR_BITS and G_DATA_SIZE mod 16 /= 0) then
                                count_snd := count_snd + C_NBR_BITS-nbit_snd-G_DATA_SIZE;
                            else
                                count_snd := count_snd + G_DATA_SIZE;
                            end if;
                        else
                            -- Go to IDLE
                            chksm_rst <= G_ACTIVE_RST;
                            wr_rst <= G_ACTIVE_RST;
                            rd_rst <= G_ACTIVE_RST;
                            ECHO_TDATA <= (others => 'Z');
                            ERROR_REG <= C_NO_ERROR;
                            store_status <= IDLE;
                        end if;

                    when others =>
                        -- Go to IDLE
                        chksm_rst <= G_ACTIVE_RST;
                        wr_rst <= G_ACTIVE_RST;
                        rd_rst <= G_ACTIVE_RST;
                        ERROR_REG <= C_NO_ERROR;
                        store_status <= IDLE;
                end case;
            end if;
        end if;
    end process store_data;
end generate generate_min_64;

end rtl;

