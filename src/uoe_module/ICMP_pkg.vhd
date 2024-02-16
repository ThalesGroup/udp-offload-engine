library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- ICMP Package
--------------------------------------------------------------------
--
-- Package types and functions for the ICMP Echo module
--
--------------------------------------------------------------------

package ICMP_pkg is

-- Define types
type store_state is (IDLE, RECEIVE_HEADER, RECEIVE_PAYLOAD, CHECK_ERROR, SEND_HEADER, SEND_PAYLOAD);

-- Define functions
function compute_C1 (input : std_logic_vector(15 downto 0)) return std_logic_vector;
function convert_LE (input : std_logic_vector(63 downto 0)) return std_logic_vector;

-- Error register address
constant C_MAIN_REG_ICMP_ERROR  : std_logic_vector(7 downto 0) := x"64";
-- Echo reply erros
constant C_NO_ERROR         : std_logic_vector(1 downto 0) := "00";  -- No error detected
constant C_CHECKSUM_ERROR   : std_logic_vector(1 downto 0) := "01";  -- Wrong checksum
constant C_FIFO_FULL        : std_logic_vector(1 downto 0) := "10";  -- FIFO is full
constant C_TYPE_ERROR       : std_logic_vector(1 downto 0) := "11";  -- Type and code recieved does not correspond to ICMP request

end ICMP_pkg;

package body ICMP_pkg is

    -- Compute one's complement
    function compute_C1 (input : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable output : std_logic_vector(15 downto 0);
    begin
        for i in 0 to 15 loop
            output(i) := not input(i);
        end loop;
        return output;
    end function;

    -- Convert the header to deal with the LE mode
    function convert_LE (input : std_logic_vector(63 downto 0)) return std_logic_vector is
        variable output : std_logic_vector(63 downto 0) ;
    begin
        output(63 downto 56) := input(7 downto 0);
        output(55 downto 48) := input(15 downto 8);
        output(47 downto 40) := input(23 downto 16);
        output(39 downto 32) := input(31 downto 24);
        output(31 downto 24) := input(39 downto 32);
        output(23 downto 16) := input(47 downto 40);
        output(15 downto 8)  := input(55 downto 48);
        output(7 downto 0)   := input(63 downto 56);
        return output;
    end function;

end package body ICMP_pkg;
