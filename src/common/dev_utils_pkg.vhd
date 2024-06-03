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

-------------------------------------------------------------------------------

package dev_utils_pkg is

  ---------------------------------------------------------------------
  --       TYPES
  ---------------------------------------------------------------------

  -- /!\ WARNING: The T_REAL_ARRAY should only be used either in simulations, or on constants as an
  --              intermediate result before Fixed Point casting using the appropriate functions

  type t_integer_array  is array(natural range <>) of integer;
  type t_real_array     is array(natural range <>) of real;

  -- converts a real array to an integer array using math_real.integer() built-in method
  function to_integer_array(constant data : in t_real_array) return t_integer_array;

  -- rounds a real array using math_real.round() built-in method
  function round(constant data : in t_real_array) return t_real_array;

  -- computes the sum of all the elements of the input vector
  function sum(constant data : in t_integer_array) return integer;
  -- computes the sum of all the elements of the input vector
  function sum(constant data : in t_real_array) return real;

  -- computes the cumulative sum of all the elements of the input vector, returning a vector of same type and size
  function cumsum(constant data : in t_integer_array) return t_integer_array;
  -- computes the cumulative sum of all the elements of the input vector, returning a vector of same type and size
  function cumsum(constant data : in t_real_array) return t_real_array;

  -- computes the element-wise sum of two input vectors, returning a vector of same type and size
  function add(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise sum of two input vectors, returning a vector of same type and size
  function add(constant a : in t_real_array; constant b : in t_real_array) return t_real_array;
  -- computes the element-wise sum, returning a vector of same type and size
  function add(constant a : in t_integer_array; constant b : in integer) return t_integer_array;
  -- computes the element-wise sum, returning a vector of same type and size
  function add(constant a : in integer; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise sum, returning a vector of same type and size
  function add(constant a : in t_real_array; constant b : in real) return t_real_array;
  -- computes the element-wise sum, returning a vector of same type and size
  function add(constant a : in real; constant b : in t_real_array) return t_real_array;

  -- computes the element-wise difference of two input vectors, returning a vector of same type and size
  function sub(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise difference of two input vectors, returning a vector of same type and size
  function sub(constant a : in t_real_array; constant b : in t_real_array) return t_real_array;
  -- computes the element-wise difference, returning a vector of same type and size
  function sub(constant a : in t_integer_array; constant b : in integer) return t_integer_array;
  -- computes the element-wise difference, returning a vector of same type and size
  function sub(constant a : in integer; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise difference, returning a vector of same type and size
  function sub(constant a : in t_real_array; constant b : in real) return t_real_array;
  -- computes the element-wise difference, returning a vector of same type and size
  function sub(constant a : in real; constant b : in t_real_array) return t_real_array;

  -- computes the element-wise multiplication of two input vectors, returning a vector of same type and size
  function mul(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise multiplication of two input vectors, returning a vector of same type and size
  function mul(constant a : in t_real_array; constant b : in t_real_array) return t_real_array;
  -- computes the element-wise multiplication, returning a vector of same type and size
  function mul(constant a : in t_integer_array; constant b : in integer) return t_integer_array;
  -- computes the element-wise multiplication, returning a vector of same type and size
  function mul(constant a : in integer; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise multiplication, returning a vector of same type and size
  function mul(constant a : in t_real_array; constant b : in real) return t_real_array;
  -- computes the element-wise multiplication, returning a vector of same type and size
  function mul(constant a : in real; constant b : in t_real_array) return t_real_array;

  -- computes the element-wise division of two input vectors, returning a vector of same type and size
  function div(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise division of two input vectors, returning a vector of same type and size
  function div(constant a : in t_real_array; constant b : in t_real_array) return t_real_array;
  -- computes the element-wise division, returning a vector of same type and size
  function div(constant a : in t_integer_array; constant b : in integer) return t_integer_array;
  -- computes the element-wise division, returning a vector of same type and size
  function div(constant a : in integer; constant b : in t_integer_array) return t_integer_array;
  -- computes the element-wise division, returning a vector of same type and size
  function div(constant a : in t_real_array; constant b : in real) return t_real_array;
  -- computes the element-wise division, returning a vector of same type and size
  function div(constant a : in real; constant b : in t_real_array) return t_real_array;

  ---------------------------------------------------------------------
  --      COMPARISON
  ---------------------------------------------------------------------

  -- Note: the following functions can be used on all sorts of inputs

  -- returns the minimum value of the two inputs
  function amin(constant a : in integer; constant b : in integer) return integer;
  -- returns the minimum value of the two inputs
  function amin(constant a : in real; constant b : in real) return real;
  -- returns the minimum value of the two inputs
  function amin(constant a : in signed; constant b : in signed) return signed;
  -- returns the minimum value of the two inputs
  function amin(constant a : in unsigned; constant b : in unsigned) return unsigned;
  -- returns the minimum value of the input vector
  function amin(constant a : in t_integer_array) return integer;
  -- returns the minimum value of the input vector
  function amin(constant a : in t_real_array) return real;

  -- returns the index of the minimum value of the input vector
  function argmin(constant a : in t_integer_array; constant start_low : in boolean := True) return integer;
  -- returns the index of the minimum value of the input vector
  function argmin(constant a : in t_real_array; constant start_low : in boolean := True) return integer;

  -- returns the maximum value of the two inputs
  function amax(constant a : in integer; constant b : in integer) return integer;
  -- returns the maximum value of the two inputs
  function amax(constant a : in real; constant b : in real) return real;
  -- returns the maximum value of the two inputs
  function amax(constant a : in signed; constant b : in signed) return signed;
  -- returns the maximum value of the two inputs
  function amax(constant a : in unsigned; constant b : in unsigned) return unsigned;
  -- returns the maximum value of the input vector
  function amax(constant a : in t_integer_array) return integer;
  -- returns the maximum value of the input vector
  function amax(constant a : in t_real_array) return real;

  -- returns the index of the maximum value of the input vector
  function argmax(constant a : in t_integer_array; constant start_low : in boolean := True) return integer;
  -- returns the index of the maximum value of the input vector
  function argmax(constant a : in t_real_array; constant start_low : in boolean := True) return integer;

  ---------------------------------------------------------------------
  --       CONVERSION
  ---------------------------------------------------------------------

  -- converts an integer to an std_logic as '0' if data = 0 and '1' otherwise
  function to_std_logic(constant data : in integer) return std_logic;
  -- converts a boolean to an std_logic as '1' if data = True and '0' otherwise
  function to_std_logic(constant data : in boolean) return std_logic;

  -- converts an std_logic to an integer as 1 if to_X01(data) = '1' and 0 otherwise
  function to_integer(constant data : in std_logic) return integer;
  -- converts a boolean to an integer as 1 if data is True and '0' otherwise
  function to_integer(constant data : in boolean) return integer;

  -- converts an integer to a boolean as False if data = 0 and True otherwise
  function to_boolean(constant data : in integer) return boolean;
  -- converts an std_logic to a boolean as True if to_X01(data) and False otherwise
  function to_boolean(constant data : in std_logic) return boolean;

  -- converts an std_logic to an std_logic_vector of size 1
  function to_std_logic_vector(constant data : in std_logic) return std_logic_vector;
  -- converts a real to a t_real_array of size 1
  function to_real_array(constant data : in real) return t_real_array;
  -- converts an integer to a t_integer_array of size 1
  function to_integer_array(constant data : in integer) return t_integer_array;

  -- converts an std_logic_vector to a string using Latin-1 ASCII encoding on 8 bits
  function to_ascii(constant data : in std_logic_vector) return string;
  -- converts a string to an std_logic_vector using Latin-1 ASCII encoding on 8 bits
  function from_ascii(constant data : in string) return std_logic_vector;

  ---------------------------------------------------------------------
  --      ENUMERATION/COUNT
  ---------------------------------------------------------------------

  -- /!\ WARNING: the following functions should only be used on constants/generic parameters!

  -- div_floor(a,b) returns r = floor(a/b), so that r*b <= a
  function div_floor(constant a : in real; constant b : in real) return real;
  -- div_ceil(a,b) returns r = ceil(a/b), so that r*b >= a
  function div_ceil(constant a : in real; constant b : in real) return real;

  -- div_floor(a,b) returns r = floor(a/b), so that r*b <= a
  function div_floor(constant a : in integer; constant b : in integer) return integer;
  -- div_ceil(a,b) returns r = ceil(a/b), so that r*b >= a
  function div_ceil(constant a : in integer; constant b : in integer) return integer;

  -- logb_floor(a,b) returns r = floor(ln(a)/ln(b)), so that b**r <= a
  function logb_floor(constant a : in real range 0.0 to real'high; constant b : in real range 1.0 to real'high) return real;
  -- logb_ceil(a,b) returns r = ceil(ln(a)/ln(b)), so that b**r >= a
  function logb_ceil(constant a : in real range 0.0 to real'high; constant b : in real range 1.0 to real'high) return real;

  -- logb_floor(a,b) returns r = floor(ln(a)/ln(b)), so that b**r <= a
  function logb_floor(constant a : in positive; constant b : in integer range 2 to integer'high) return integer;
  -- logb_ceil(a,b) returns r = ceil(ln(a)/ln(b)), so that b**r >= a
  function logb_ceil(constant a : in positive; constant b : in integer range 2 to integer'high) return integer;

  -- log2_floor(a) returns r = floor(log2(a)), so that 2**r <= a
  function log2_floor(constant a : in real range 0.0 to real'high) return real;
  -- log2_ceil(a) returns r = ceil(log2(a)), so that 2**r >= a
  function log2_ceil(constant a : in real range 0.0 to real'high) return real;

  -- log2_floor(a) returns r = floor(log2(a)), so that 2**r <= a
  function log2_floor(constant a : in positive) return integer;
  -- log2_ceil(a) returns r = ceil(log2(a)), so that 2**r >= a
  function log2_ceil(constant a : in positive) return integer;

  -- log10_floor(a) returns r = floor(log10(a)), so that 10**r <= a
  function log10_floor(constant a : in real range 0.0 to real'high) return real;
  -- log10_ceil(a) returns r = ceil(log10(a)), so that 10**r >= a
  function log10_ceil(constant a : in real range 0.0 to real'high) return real;

  -- log10_floor(a) returns r = floor(log10(a)), so that 10**r <= a
  function log10_floor(constant a : in positive) return integer;
  -- log10_ceil(a) returns r = ceil(log10(a)), so that 10**r >= a
  function log10_ceil(constant a : in positive) return integer;

  ---------------------------------------------------------------------
  --       MISCELLANEOUS
  ---------------------------------------------------------------------

  -- Note: the following functions can be used on all sorts of inputs

  -- swap_words reverses the words order in a concatenated data bus, returning an std_logic_vector of same range
  function swap_words(constant data : in std_logic_vector; constant wordSize : in positive := 8) return std_logic_vector;
  -- swap_bits reverses the bits order of each word in a concatenated data bus, returning an std_logic_vector of same range
  function swap_bits(constant data : in std_logic_vector; constant wordSize : in positive := 8) return std_logic_vector;
  -- swap reverses the order of all the bits in a concatenated data bus, returning an std_logic_vector of same range
  function swap(constant data : in std_logic_vector) return std_logic_vector;

  -- counts the number of bits equal to val in the input vector
  function count_bits(constant data : in std_logic_vector; constant val : in std_logic := '1') return integer;
  -- returns the index of the first bit equal to val in the input vector, starting from its high or low index
  function find_first(constant data : in std_logic_vector; constant val : in std_logic := '1'; constant start_high : in boolean := True) return integer;

  ---------------------------------------------------------------------
  --       COMPONENTS
  ---------------------------------------------------------------------

  -- divide an internal clock for a FPGA or ASIC clock generation on output
  component clock_divider is
    generic(
      G_ACTIVE_RST     : std_logic range '0' to '1' := '1';   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST      : boolean                    := true;  -- Type of reset used (synchronous or asynchronous resets)
      G_RST_VALUE_DCLK : std_logic range '0' to '1' := '0';   -- State to which the DCLK output resets
      G_HALF_PERIOD    : positive                   := 1      -- Half period of the DCLK output (expressed in ticks number of CLK input)
    );
    port(
      CLK     : in  std_logic;                     -- Clock to divide
      RST     : in  std_logic := not G_ACTIVE_RST; -- Reset
      EN      : in  std_logic := '1';              -- Enable of the DCLK output
      DCLK    : out std_logic                      -- Divided clock
    );
  end component clock_divider;


  -- Debounce an input signal
  component debounce is
    generic(
      G_ACTIVE_RST        : std_logic        := '1';                   -- State at which the reset signal is asserted (active low or active high)
      G_ASYNC_RST         : boolean          := false;                 -- Type of reset used (synchronous or asynchronous resets)
      G_DATA_WIDTH        : positive         := 1;                     -- Width of the multi-bit vector
      G_NB_CYCLES         : positive         := 1;                     -- Number of CLK cycles for the debounce
      G_ANTI_GLITCH       : boolean          := true                   -- Anti-glitch mode of the debounce (true : anti-glitch, false : debounce)
    );
    port (
      -- CLK and RST
      RST             : in  std_logic;                                 -- Reset
      CLK             : in  std_logic;                                 -- Clock
      -- Data ports
      DATA_IN         : in  std_logic_vector(G_DATA_WIDTH-1 downto 0); -- Data to debounce
      DATA_OUT        : out std_logic_vector(G_DATA_WIDTH-1 downto 0)  -- Debounced data
    );
  end component debounce;

end dev_utils_pkg;

--========================== PACKAGE BODY ===========================--

package body dev_utils_pkg is

  -- converts a real array to an integer array using math_real.integer() built-in method
  -- You can round the vector beforehand using the round() function
  --
  -- Inputs: data    - input vector
  --
  -- Example: to_integer_array(      (3.14159, 2, 0.707106))  = (3, 2, 0)
  --          to_integer_array(round((3.14159, 2, 0.707106))) = (3, 2, 1)
  function to_integer_array(constant data : in t_real_array) return t_integer_array is
    variable v_res_tointarr : t_integer_array(data'range);
  begin
    for i in data'range loop
      v_res_tointarr(i) := integer(data(i));
    end loop;
    return v_res_tointarr;
  end function to_integer_array;

  -- rounds a real array using math_real.round() built-in method
  --
  -- Inputs: data    - input vector
  --
  -- Example: round(3.14159, 2, 0.707106) = (3.0, 2.0, 1.0)
  function round(constant data : in t_real_array) return t_real_array is
    variable v_res_round : t_real_array(data'range);
  begin
    for i in data'range loop
      v_res_round(i) := round(data(i));
    end loop;
    return v_res_round;
  end function round;

  -- sum(data: t_integer_array) simply returns the sum of all the elements of input data.
  --
  -- Inputs: a         - input vector
  --
  -- Example:  sum((1, 2, 3)) = 1 + 2 + 3 = 6
  function sum(constant data : in t_integer_array) return integer is
    variable v_res_sumint : integer range integer'low to integer'high;
  begin
    v_res_sumint := data(data'low);
    for i in data'low + 1 to data'high loop
      v_res_sumint := v_res_sumint + data(i);
    end loop;
    return v_res_sumint;
  end function sum;

  -- alias for t_real_array inputs
  function sum(constant data : in t_real_array) return real is
    variable v_res_sumreal : real;
  begin
    v_res_sumreal := data(data'low);
    for i in data'low + 1 to data'high loop
      v_res_sumreal := v_res_sumreal + data(i);
    end loop;
    return v_res_sumreal;
  end function sum;

  -- cumsum(data: t_integer_array) simply returns the cumulative sum of all the elements of input data.
  --
  -- Inputs: a         - input vector
  --
  -- Example:  cumsum((1, 2, 3)) = (1, 1 + 2, 1 + 2 + 3) = (1, 3, 6)
  function cumsum(constant data : in t_integer_array) return t_integer_array is
    variable v_res_cumsumint : t_integer_array(data'range);
  begin
    v_res_cumsumint(data'low) := data(data'low);
    for i in data'low + 1 to data'high loop
      v_res_cumsumint(i) := v_res_cumsumint(i - 1) + data(i);
    end loop;
    return v_res_cumsumint;
  end function cumsum;

  -- alias for t_real_array inputs
  function cumsum(constant data : in t_real_array) return t_real_array is
    variable v_res_cumsumreal : t_real_array(data'range);
  begin
    v_res_cumsumreal(data'low) := data(data'low);
    for i in data'low + 1 to data'high loop
      v_res_cumsumreal(i) := v_res_cumsumreal(i - 1) + data(i);
    end loop;
    return v_res_cumsumreal;
  end function cumsum;

  -- add(a: t_integer_array; b: t_integer_array) simply returns the element-wise sum of the two input vectors.
  --
  -- Inputs: a         - first input vector
  --         b         - second input vector
  --
  -- Example:  add((1, 2, 3), (4, 5, 6)) = (1 + 4, 2 + 5, 3 + 6) = (5, 7, 9)
  function add(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array is
    variable v_res_addint : t_integer_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_addint(i) := a(i) + b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_addint;
  end function add;

  -- alias for t_real_array inputs
  function add(constant a : in t_real_array; constant b : in t_real_array) return t_real_array is
    variable v_res_addreal : t_real_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_addreal(i) := a(i) + b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_addreal;
  end function add;

  -- alias for mixed integer inputs
  function add(constant a : in t_integer_array; constant b : in integer) return t_integer_array is
  begin
    return add(a, to_integer_array(b));
  end function add;

  -- alias for mixed integer inputs
  function add(constant a : in integer; constant b : in t_integer_array) return t_integer_array is
  begin
    return add(to_integer_array(a), b);
  end function add;

  -- alias for mixed real inputs
  function add(constant a : in t_real_array; constant b : in real) return t_real_array is
  begin
    return add(a, to_real_array(b));
  end function add;

  -- alias for mixed integer inputs
  function add(constant a : in real; constant b : in t_real_array) return t_real_array is
  begin
    return add(to_real_array(a), b);
  end function add;

  -- sub(a: t_integer_array; b: t_integer_array) simply returns the element-wise difference of the two input vectors.
  --
  -- Inputs: a         - first input vector
  --         b         - second input vector
  --
  -- Example:  sub((1, 7, 3), (2, 5, 4)) = (1 - 2, 7 - 5, 3 - 4) = (-1, 2, -1)
  function sub(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array is
    variable v_res_subint : t_integer_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_subint(i) := a(i) - b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_subint;
  end function sub;

  -- alias for t_real_array inputs
  function sub(constant a : in t_real_array; constant b : in t_real_array) return t_real_array is
    variable v_res_subreal : t_real_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_subreal(i) := a(i) - b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_subreal;
  end function sub;

  -- alias for mixed integer inputs
  function sub(constant a : in t_integer_array; constant b : in integer) return t_integer_array is
  begin
    return sub(a, to_integer_array(b));
  end function sub;

  -- alias for mixed integer inputs
  function sub(constant a : in integer; constant b : in t_integer_array) return t_integer_array is
  begin
    return sub(to_integer_array(a), b);
  end function sub;

  -- alias for mixed real inputs
  function sub(constant a : in t_real_array; constant b : in real) return t_real_array is
  begin
    return sub(a, to_real_array(b));
  end function sub;

  -- alias for mixed integer inputs
  function sub(constant a : in real; constant b : in t_real_array) return t_real_array is
  begin
    return sub(to_real_array(a), b);
  end function sub;

  -- mul(a: t_integer_array; b: t_integer_array) simply returns the element-wise multiplication of the two input vectors.
  --
  -- Inputs: a         - first input vector
  --         b         - second input vector
  --
  -- Example:  mul((1, 2, 3), (4, 5, 6)) = (1*4, 2*5, 3*6) = (4, 10, 18)
  --           sum(mul(a, b))     computes the scalar product <a|b>
  --           mul(a, 1.0/sum(a)) normalizes the vector a by the value of its sum
  function mul(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array is
    variable v_res_mulint : t_integer_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_mulint(i) := a(i) * b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_mulint;
  end function mul;

  -- alias for t_real_array inputs
  function mul(constant a : in t_real_array; constant b : in t_real_array) return t_real_array is
    variable v_res_mulreal : t_real_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_mulreal(i) := a(i) * b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_mulreal;
  end function mul;

  -- alias for mixed integer inputs
  function mul(constant a : in t_integer_array; constant b : in integer) return t_integer_array is
  begin
    return mul(a, to_integer_array(b));
  end function mul;

  -- alias for mixed integer inputs
  function mul(constant a : in integer; constant b : in t_integer_array) return t_integer_array is
  begin
    return mul(to_integer_array(a), b);
  end function mul;

  -- alias for mixed real inputs
  function mul(constant a : in t_real_array; constant b : in real) return t_real_array is
  begin
    return mul(a, to_real_array(b));
  end function mul;

  -- alias for mixed integer inputs
  function mul(constant a : in real; constant b : in t_real_array) return t_real_array is
  begin
    return mul(to_real_array(a), b);
  end function mul;

  -- div(a: t_integer_array; b: t_integer_array) simply returns the element-wise division of the two input vectors.
  --
  -- Inputs: a         - first input vector
  --         b         - second input vector
  --
  -- Example:  div((4, 5, 6), (1, 2, 3)) = (4/1, 5/2, 6/3) = (4, 2, 2)
  function div(constant a : in t_integer_array; constant b : in t_integer_array) return t_integer_array is
    variable v_res_divint : t_integer_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_divint(i) := a(i)/b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_divint;
  end function div;

  -- alias for t_real_array inputs
  function div(constant a : in t_real_array; constant b : in t_real_array) return t_real_array is
    variable v_res_divreal : t_real_array(a'range);
  begin
    assert ((a'low = b'low) and (a'high = b'high)) or (b'length = 1) report "Inconsistent input parameters: a and b do not share the same indexing range" severity failure;
    for i in a'range loop
      v_res_divreal(i) := a(i)/b(amin(amax(i, b'low), b'high));
    end loop;
    return v_res_divreal;
  end function div;

  -- alias for mixed integer inputs
  function div(constant a : in t_integer_array; constant b : in integer) return t_integer_array is
  begin
    return div(a, to_integer_array(b));
  end function div;

  -- alias for mixed integer inputs
  function div(constant a : in integer; constant b : in t_integer_array) return t_integer_array is
  begin
    return div(to_integer_array(a), b);
  end function div;

  -- alias for mixed real inputs
  function div(constant a : in t_real_array; constant b : in real) return t_real_array is
  begin
    return div(a, to_real_array(b));
  end function div;

  -- alias for mixed real inputs
  function div(constant a : in real; constant b : in t_real_array) return t_real_array is
  begin
    return div(to_real_array(a), b);
  end function div;

  ---------------------------------------------------------------------
  --      COMPARISON
  ---------------------------------------------------------------------

  -- amin(a: integer; b: integer) simply returns the minimum value of its two inputs.
  --
  -- Inputs: a         - first data to compare
  --         b         - second data to compare
  --
  -- Example:  amin(29, -3) = amin(-3, 29) = -3
  function amin(constant a : in integer; constant b : in integer) return integer is
    variable v_res_minint : integer range integer'low to integer'high;
  begin
    if a < b then
      v_res_minint := a;
    else
      v_res_minint := b;
    end if;
    return v_res_minint;
  end function amin;

  -- alias for signed inputs
  function amin(constant a : in signed; constant b : in signed) return signed is
  begin
    if a < b then
      return a;
    else
      return b;
    end if;
  end function amin;

  -- alias for unsigned inputs
  function amin(constant a : in unsigned; constant b : in unsigned) return unsigned is
  begin
    if a < b then
      return a;
    else
      return b;
    end if;
  end function amin;

  -- alias for t_integer_array inputs
  function amin(constant a : in t_integer_array) return integer is
    variable v_min_int : integer range integer'low to integer'high;
  begin
    v_min_int := a(a'low);
    for i in a'low + 1 to a'high loop
      v_min_int := amin(v_min_int, a(i));
    end loop;
    return v_min_int;
  end function amin;

  -- alias for real inputs
  function amin(constant a : in real; constant b : in real) return real is
    variable v_res_real : real;
  begin
    if a < b then
      v_res_real := a;
    else
      v_res_real := b;
    end if;
    return v_res_real;
  end function amin;

  -- alias for t_real_array inputs
  function amin(constant a : in t_real_array) return real is
    variable v_min_real : real;
  begin
    v_min_real := a(a'low);
    for i in a'low + 1 to a'high loop
      v_min_real := amin(v_min_real, a(i));
    end loop;
    return v_min_real;
  end function amin;

  -- argmin(a: t_integer_array; find_first: boolean := True) simply returns the index of the minimum value in the input array.
  --
  -- Inputs: a         - array of data to compare
  --         start_low - returns the lowest index of the minimum value if True, or highest otherwise
  --
  -- Example:  argamin((29, -3), True) = 1
  function argmin(constant a : in t_integer_array; constant start_low : in boolean := True) return integer is
    variable v_min_argminint : integer range integer'low to integer'high;
    variable v_idx_argminint : integer range a'low to a'high;
  begin
    v_min_argminint := a(a'low);
    v_idx_argminint := a'low;
    for i in a'low + 1 to a'high loop
      if (a(i) < v_min_argminint) or ((a(i) = v_min_argminint) and (not start_low)) then
        v_idx_argminint := i;
        v_min_argminint := a(i);
      end if;
    end loop;
    return v_idx_argminint;
  end function argmin;

  -- alias for t_real_array inputs
  function argmin(constant a : in t_real_array; constant start_low : in boolean := True) return integer is
    variable v_min_argminreal : real;
    variable v_idx_argminreal : integer range a'low to a'high;
  begin
    v_min_argminreal := a(a'low);
    v_idx_argminreal := a'low;
    for i in a'low + 1 to a'high loop
      if (a(i) < v_min_argminreal) or ((a(i) = v_min_argminreal) and (not start_low)) then
        v_min_argminreal := a(i);
        v_idx_argminreal := i;
      end if;
    end loop;
    return v_idx_argminreal;
  end function argmin;

  -------------------------------------------------------------------------------

  -- amax(a: integer; b: integer) simply returns the maximum value of its two inputs.
  --
  -- Inputs: a         - first data to compare
  --         b         - second data to compare
  --
  -- Example:  amax(29, -3) = amax(-3, 29) = 29
  function amax(constant a : in integer; constant b : in integer) return integer is
    variable v_res_maxint : integer range integer'low to integer'high;
  begin
    if a > b then
      v_res_maxint := a;
    else
      v_res_maxint := b;
    end if;
    return v_res_maxint;
  end function amax;

  -- alias for signed inputs
  function amax(constant a : in signed; constant b : in signed) return signed is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function amax;

  -- alias for unsigned inputs
  function amax(constant a : in unsigned; constant b : in unsigned) return unsigned is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function amax;

  -- alias for t_integer_array inputs
  function amax(constant a : in t_integer_array) return integer is
    variable v_max_int : integer range integer'low to integer'high;
  begin
    v_max_int := a(a'low);
    for i in a'low + 1 to a'high loop
      v_max_int := amax(v_max_int, a(i));
    end loop;
    return v_max_int;
  end function amax;

  -- alias for real inputs
  function amax(constant a : in real; constant b : in real) return real is
    variable v_res_maxreal : real;
  begin
    if a > b then
      v_res_maxreal := a;
    else
      v_res_maxreal := b;
    end if;
    return v_res_maxreal;
  end function amax;

  -- alias for t_real_array inputs
  function amax(constant a : in t_real_array) return real is
    variable v_max_real : real;
  begin
    v_max_real := a(a'low);
    for i in a'low + 1 to a'high loop
      v_max_real := amax(v_max_real, a(i));
    end loop;
    return v_max_real;
  end function amax;

  -- argmax(a: t_integer_array; find_first: boolean := True) simply returns the index of the maximum value in the input array.
  --
  -- Inputs: a         - array of data to compare
  --         start_low - returns the lowest index of the maximum value if True, or highest otherwise
  --
  -- Example:  argmax((29, -3), True) = 0
  function argmax(constant a : in t_integer_array; constant start_low : in boolean := True) return integer is
    variable v_max_argmaxint : integer range integer'low to integer'high;
    variable v_idx_argmaxint : integer range a'low to a'high;
  begin
    v_max_argmaxint := a(a'low);
    v_idx_argmaxint := a'low;
    for i in a'low + 1 to a'high loop
      if (a(i) > v_max_argmaxint) or ((a(i) = v_max_argmaxint) and (not start_low)) then
        v_idx_argmaxint := i;
        v_max_argmaxint := a(i);
      end if;
    end loop;
    return v_idx_argmaxint;
  end function argmax;

  -- alias for t_real_array inputs
  function argmax(constant a : in t_real_array; constant start_low : in boolean := True) return integer is
    variable v_max_argmaxreal : real;
    variable v_idx_argmaxreal : integer range a'low to a'high;
  begin
    v_max_argmaxreal := a(a'low);
    v_idx_argmaxreal := a'low;
    for i in a'low + 1 to a'high loop
      if (a(i) > v_max_argmaxreal) or ((a(i) = v_max_argmaxreal) and (not start_low)) then
        v_max_argmaxreal := a(i);
        v_idx_argmaxreal := i;
      end if;
    end loop;
    return v_idx_argmaxreal;
  end function argmax;

  ---------------------------------------------------------------------
  --       CONVERSION
  ---------------------------------------------------------------------

  -- to_std_logic(data: integer) simply converts an integer value to an std_logic.
  -- It returns '0' if data = 0, and '1' otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_std_logic(0)  = '0'
  --           to_std_logic(-1) = to_std_logic(3)  = '1'
  function to_std_logic(constant data : in integer) return std_logic is
    variable v_res_toslint : std_logic;
  begin
    if data = 0 then
      v_res_toslint := '0';
    else
      v_res_toslint := '1';
    end if;
    return v_res_toslint;
  end function to_std_logic;

  -- to_std_logic(data: boolean) simply converts a boolean value to an std_logic.
  -- It returns '1' if data = True, and '0' otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_std_logic(False) = '0'
  --           to_std_logic(True)  = '1'
  function to_std_logic(constant data : in boolean) return std_logic is
    variable v_res_toslbool : std_logic;
  begin
    if data then
      v_res_toslbool := '1';
    else
      v_res_toslbool := '0';
    end if;
    return v_res_toslbool;
  end function to_std_logic;

  -- to_integer(data: std_logic) simply converts an std_logic value to an integer.
  -- It returns 1 if to_X01(data) = '1', and 0 otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_integer('1') = 1
  --           to_integer('0') = to_integer('X') = 0
  function to_integer(constant data : in std_logic) return integer is
    variable v_res_tointsl : integer range 0 to 1;
  begin
    if to_X01(data) = '1' then
      v_res_tointsl := 1;
    else
      v_res_tointsl := 0;
    end if;
    return v_res_tointsl;
  end function to_integer;

  -- to_integer(data: boolean) simply converts a boolean value to an integer.
  -- It returns 1 if data is True, and 0 otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_integer(True)  = 1
  --           to_integer(False) = 0
  function to_integer(constant data : in boolean) return integer is
    variable v_res_tointbool : integer range 0 to 1;
  begin
    if data then
      v_res_tointbool := 1;
    else
      v_res_tointbool := 0;
    end if;
    return v_res_tointbool;
  end function to_integer;

  -- to_boolean(data: integer) simply converts an integer value to a boolean.
  -- It returns False if data = 0, and True otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_boolean(0)  = False
  --           to_boolean(-1) = to_boolean(3)  = True
  function to_boolean(constant data : in integer) return boolean is
    variable v_res_toboolint : boolean;
  begin
    if data = 0 then
      v_res_toboolint := False;
    else
      v_res_toboolint := True;
    end if;
    return v_res_toboolint;
  end function to_boolean;

  -- to_boolean(data: std_logic) simply converts an std_logic value to a boolean.
  -- It returns True if to_X01(data) = '1', and False otherwise
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_boolean('0') = to_boolean('X') = False
  --           to_boolean('1') = True
  function to_boolean(constant data : in std_logic) return boolean is
  begin
    return to_X01(data) = '1';
  end function to_boolean;

  -- to_std_logic_vector(data: std_logic) simply converts an std_logic value to its std_logic_vector of size 1 counterpart.
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_std_logic_vector('1') = "1"
  --           to_std_logic_vector('0') = "0"
  function to_std_logic_vector(constant data : in std_logic) return std_logic_vector is
    variable v_res_toslv : std_logic_vector(0 downto 0);
  begin
    v_res_toslv(0) := data;
    return v_res_toslv;
  end function to_std_logic_vector;

  -- to_real_array(data: real) simply converts a real to its t_real_array counterpart of size 1
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_real_array(3.2) = (3.2)
  function to_real_array(constant data : in real) return t_real_array is
    variable v_res_torealarr : t_real_array(0 downto 0);
  begin
    v_res_torealarr(0) := data;
    return v_res_torealarr;
  end function to_real_array;

  -- to_integer_array(data: integer) simply converts a real to its t_integer_array counterpart of size 1
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_integer_array(3) = (3)
  function to_integer_array(constant data : in integer) return t_integer_array is
    variable v_res_tointarrint : t_integer_array(0 downto 0);
  begin
    v_res_tointarrint(0) := data;
    return v_res_tointarrint;
  end function to_integer_array;

  -- converts an std_logic_vector to a string using Latin-1 ASCII encoding on 8 bits
  --
  -- Inputs: data     - binary vector representing a string in the corresponding encoding
  --
  -- Example: to_ascii(x"534958"&x"20"&x"475453") = "SIX GTS"
  --
  -- Note: to_string() may interfere with the VHDL 2008 version of ieee.std_logic_1164 that also defines a to_string() method
  function to_ascii(constant data : in std_logic_vector) return string is
    constant C_CHAR_LEN_TO : integer := 8;
    constant C_NB_CHAR_TO  : integer := data'length / C_CHAR_LEN_TO;
    variable v_string_to   : string(1 to C_NB_CHAR_TO); --@suppress PID3 ascending range for string is ok
  begin
    assert (C_NB_CHAR_TO * C_CHAR_LEN_TO) = data'length report "Inconsistent input parameters: total length should be a multiple of 8" severity failure;
    for c in 1 to C_NB_CHAR_TO loop
      if data'ascending then
        v_string_to(c) := character'val(to_integer(unsigned(data(data'left + (c - 1) * C_CHAR_LEN_TO to data'left + (c * C_CHAR_LEN_TO) - 1))));
      else
        v_string_to(c) := character'val(to_integer(unsigned(data(data'left - (c - 1) * C_CHAR_LEN_TO downto data'left - (c * C_CHAR_LEN_TO) + 1))));
      end if;
    end loop;
    return v_string_to;
  end function to_ascii;

  -- converts a string to an std_logic_vector using Latin-1 ASCII encoding on 8 bits
  --
  -- Inputs: data     - string (character vector)
  --
  -- Example: from_ascii("SIX GTS") = x"534958"&x"20"&x"475453"
  --
  -- Note: named after to_string() for symetry reasons
  function from_ascii(constant data : in string) return std_logic_vector is
    constant C_CHAR_LEN_FR : integer := 8;
    constant C_NB_CHAR_FR  : integer := data'length;
    constant C_NB_BITS_FR  : integer := C_NB_CHAR_FR * C_CHAR_LEN_FR;
    variable v_slv_fr      : std_logic_vector(C_NB_BITS_FR - 1 downto 0);
  begin
    for c in 1 to C_NB_CHAR_FR loop
      v_slv_fr((C_NB_CHAR_FR - c + 1) * C_CHAR_LEN_FR - 1 downto (C_NB_CHAR_FR - c) * C_CHAR_LEN_FR) := std_logic_vector(to_unsigned(character'pos(data(c)), C_CHAR_LEN_FR));
    end loop;
    return v_slv_fr;
  end function from_ascii;

  ---------------------------------------------------------------------
  --      ENUMERATION/COUNT
  ---------------------------------------------------------------------

  -- WARNING: the following functions should only be used on constants/generic parameters!

  -- div_floor(a: real; b:real) returns r = floor(a/b)
  --
  -- Inputs: a         - numerator
  --         b         - dividend
  --
  -- Example:  div_floor(15.2, 4.0) = 3.0 since 4*3 = 12 <= 15.2 < 4*4
  function div_floor(constant a : in real; constant b : in real) return real is
    variable v_res_divfl    : real range real'low to real'high;
    variable v_sign_a_divfl : real range -1.0 to 1.0;
    variable v_sign_b_divfl : real range -1.0 to 1.0;
  begin
    assert b /= 0.0 report "Divide by zero in div_floor" severity failure;
    -- Euclidean division: select the quotient for which the remainder is the lowest magnitude with the sign of the denominator
    -- First, we use the absolute division as a first guess, knowing we may underestimate the result by 1 due to floating-point computing noise
    v_sign_a_divfl  := real((2*to_integer(a >= 0.0)) - 1);
    v_sign_b_divfl  := real((2*to_integer(b >= 0.0)) - 1);
    v_res_divfl     := floor((abs(a))/(abs(b)));
    -- using a robust algorithm to ensure this is correct
    if (((abs(a)) - (v_res_divfl*(abs(b)))) >= (abs(b))) then
      v_res_divfl   := v_res_divfl + 1.0;
    end if;
    -- then we perform sign restoration & final casting adjustments
    if v_sign_a_divfl /= v_sign_b_divfl then
      v_res_divfl   := -v_res_divfl;
      if (v_res_divfl*b) /= a then
        v_res_divfl := v_res_divfl - 1.0;
      end if;
    end if;
    return v_res_divfl;
  end function div_floor;

  -- alias for integers
  function div_floor(constant a : in integer; constant b : in integer) return integer is
  begin
    return integer(div_floor(real(a), real(b)));
  end function div_floor;

  -- div_ceil(a: real; b:real) returns r = ceil(a/b)
  --
  -- Inputs: a         - numerator
  --         b         - dividend
  --
  -- Example:  div_ceil(15.2, 4.0) = 4.0 since 4*4 = 16 >= 15.2 > 4*3
  function div_ceil(constant a : in real; constant b : in real) return real is
    variable v_res_divceil : real range real'low to real'high;
  begin
    assert b /= 0.0 report "Divide by zero in div_ceil" severity failure;
    v_res_divceil := div_floor(a, b);
    if (v_res_divceil * b) /= a then
      v_res_divceil := v_res_divceil + 1.0;
    end if;
    return v_res_divceil;
  end function div_ceil;

  -- alias for integers
  function div_ceil(constant a : in integer; constant b : in integer) return integer is
  begin
    return integer(div_ceil(real(a), real(b)));
  end function div_ceil;

  -------------------------------------------------------------------------------


  -- pow(pow(b: real; p: integer) return x = b**p
  -- This function only works for integer powers, enabling its definition as iterative multiplications
  -- instead of the more generic exp(p*ln(b)) which is more prone to floating-point noise / computation errors
  --
  -- Note: This functions is solely intended for internal use and is not made available to the user
  --
  -- Inputs: b    - basis
  --         p    - power
  --
  -- Example:  3.2**2 = 10.24
  function pow(constant b: in real; constant p: in integer) return real is
    variable v_res : real    := 1.0;
  begin
    for i in 0 to abs(p)-1 loop
      if p >= 0 then
        v_res := v_res*b;
      else
        v_res := v_res/b;
      end if;
    end loop;
    return v_res;
  end function pow;


  -- logb_floor(a: integer; b:integer) returns r = floor(log(a)/log(b))
  --
  -- Inputs: a         - main argument
  --         b         - logarithm basis
  --
  -- Example:  logb_floor(15, 4) = 2 since 4**1 = 4
  function logb_floor(constant a : in real range 0.0 to real'high; constant b : in real range 1.0 to real'high) return real is
    variable v_res_logfl : real range real'low to real'high;
    variable v_tmp_logfl : real range real'low to real'high;
  begin
    assert a > 0.0 report "Divide by zero in logb_floor" severity Failure;
    assert b > 1.0 report "Divide by zero in logb_floor" severity Failure;
    -- ieee.math_real is used as a first guess, knowing we may underestimate the real value by 1 due to floating-point computation noise
    v_res_logfl := floor(log(a)/log(b));
    if pow(b, integer(v_res_logfl + 1.0)) <= a then
      v_res_logfl := v_res_logfl + 1.0;
    end if;
    return v_res_logfl;
  end function logb_floor;

  -- alias for integers
  function logb_floor(constant a : in positive; constant b : in integer range 2 to integer'high) return integer is
  begin
    return integer(logb_floor(real(a), real(b)));
  end function logb_floor;

  -- logb_ceil(a: integer; b:integer) returns r = ceil(log(a)/log(b))
  --
  -- Inputs: a         - main argument
  --         b         - logarithm basis
  --
  -- Example:  logb_ceil(15, 4) = 2 since 4**2 = 16
  function logb_ceil(constant a : in real range 0.0 to real'high; constant b : in real range 1.0 to real'high) return real is
    variable v_res_logceil : real range real'low to real'high;
  begin
    assert a > 0.0 report "Divide by zero in logb_ceil" severity Failure;
    assert b > 1.0 report "Divide by zero in logb_ceil" severity Failure;
    v_res_logceil := logb_floor(a, b);
    -- as a first guess, we probably underestimate the real value by 1 due to floor quantization (unless b**v_res_logb_floor = a)
    if pow(b, integer(v_res_logceil)) < a then
      v_res_logceil := v_res_logceil + 1.0;
    end if;
    return v_res_logceil;
  end function logb_ceil;

  -- alias for integers
  function logb_ceil(constant a : in positive; constant b : in integer range 2 to integer'high) return integer is
  begin
    return integer(logb_ceil(real(a), real(b)));
  end function logb_ceil;


  -------------------------------------------------------------------------------

  -- alias for logb_floor(a, 2)
  function log2_floor(constant a : in real range 0.0 to real'high) return real is
  begin
    return logb_floor(a, 2.0);
  end function log2_floor;

  -- alias for logb_floor(a, 2)
  function log2_floor(constant a : in positive) return integer is
  begin
    return logb_floor(a, 2);
  end function log2_floor;

  -- alias for logb_ceil(a, 2)
  function log2_ceil(constant a : in real range 0.0 to real'high) return real is
  begin
    return logb_ceil(a, 2.0);
  end function log2_ceil;

  -- alias for logb_ceil(a, 2)
  function log2_ceil(constant a : in positive) return integer is
  begin
    return logb_ceil(a, 2);
  end function log2_ceil;

  -------------------------------------------------------------------------------

  -- alias for logb_floor(a, 10)
  function log10_floor(constant a : in real range 0.0 to real'high) return real is
  begin
    return logb_floor(a, 10.0);
  end function log10_floor;

  -- alias for logb_floor(a, 10)
  function log10_floor(constant a : in positive) return integer is
  begin
    return logb_floor(a, 10);
  end function log10_floor;

  -- alias for logb_ceil(a, 10)
  function log10_ceil(constant a : in real range 0.0 to real'high) return real is
  begin
    return logb_ceil(a, 10.0);
  end function log10_ceil;

  -- alias for logb_ceil(a, 10)
  function log10_ceil(constant a : in positive) return integer is
  begin
    return logb_ceil(a, 10);
  end function log10_ceil;

  ---------------------------------------------------------------------
  --       MISCELLANEOUS
  ---------------------------------------------------------------------

  -- swap_bits reverses the bits order of each word in a concatenated data bus, returning an std_logic_vector of same range
  --
  -- Inputs: data     - data bus of several concatenated words of same length
  --         wordSize - number of bits foreach word
  --
  -- Examples: swap_bits("0010"&"0111"&"0001", 4) = "0100"&"1110"&"1000"
  --           swap_bits("0001", 4)               = "1000"
  --           swap_bits("0001", 1)               = "0001"
  function swap_bits(constant data : in std_logic_vector; constant wordSize : in positive := 8) return std_logic_vector is
    variable v_res_swap      : std_logic_vector(data'range);
    constant C_NB_WORDS_SWAP : integer := data'length / wordSize;
  begin
    assert (C_NB_WORDS_SWAP * wordSize) = data'length report "Inconsistent input parameters: total length should be a multiple of wordSize" severity failure;
    for w in 0 to C_NB_WORDS_SWAP - 1 loop                                    -- for all words
      for b in 0 to wordSize - 1 loop                                    -- we flip the bits' order one by one
        v_res_swap(data'low + ((w + 1) * wordSize) - 1 - b) := data(data'low + (w * wordSize) + b);
      end loop;
    end loop;
    return v_res_swap;
  end function swap_bits;

  -------------------------------------------------------------------------------

  -- swap_words reverses the words order in a concatenated data bus, returning an std_logic_vector of same range
  --
  -- Inputs: data     - data bus of several concatenated words of same length
  --         wordSize - number of bits foreach word
  --
  -- Examples: swap_words("0010"&"0111"&"0001", 4) = "0001"&"0111"&"0010"
  --           swap_words("0001", 4)               = "0001"
  --           swap_words("0001", 1)               = "1000"
  function swap_words(constant data : in std_logic_vector; constant wordSize : in positive := 8) return std_logic_vector is
  begin
    -- Swaping all the bits reverses both the order of the words and the order of theirs bits, and
    -- swaping again the order of the bits restores their original order, while maintaining the words'order reversed
    -- Of course the oder of operations does not matter. This definition makes for more reuse of code and less potential bugs
    return swap_bits(swap(data), wordSize);
  end function swap_words;

  -------------------------------------------------------------------------------

  -- swap reverses the order of all the bits of the input vector, returning an std_logic_vector of same range.
  --
  -- Inputs: data     - vector of bits
  --
  -- Example: swap("01011") = "11010"
  function swap(constant data : in std_logic_vector) return std_logic_vector is
  begin
    return swap_bits(data, data'length);
  end function swap;

  -------------------------------------------------------------------------------

  -- counts the number of bits equal to val in the input vector
  --
  -- Inputs: data     - vector of bits
  --         val      - value of the bits to count (default is '1')
  --
  -- Example: count_bits("01011") = 3
  --          count_bits("01011", '0') = 2
  function count_bits(constant data : in std_logic_vector; constant val : in std_logic := '1') return integer is
    variable v_count : integer range 0 to data'length;
  begin
    v_count := 0;
    for i in data'range loop
      if data(i) = val then
        v_count := v_count + 1;
      end if;
    end loop;
    return v_count;
  end function count_bits;

  -- returns the index of the first bit equal to val in the input vector, starting from its high or low index
  -- If val is not found, it returns -1 and raises an error.
  --
  -- Inputs: data       - vector of bits
  --         val        - value of the bit to find (default is '1')
  --         start_high - starts at the highest index towards the lowest if true, or the other way around otherwise (default is True)
  --
  -- Example: find_first("01011") = 3   with the conventional endianess
  --          find_first("00000") = -1  the value '1' was not found, so we returned an error code
  function find_first(constant data : in std_logic_vector; constant val : in std_logic := '1'; constant start_high : in boolean := True) return integer is
    variable v_idx : integer range -1 to data'high;                      -- std_logic_vector is defined using a natural index range
  begin
    v_idx := -1;                                                         -- default value if not found (std_logic_vector is only defined with a natural indexing)
    if start_high then
      for i in data'high downto data'low loop
        if data(i) = val then
          v_idx := i;
          exit;
        end if;
      end loop;
    else
      for i in data'low to data'high loop
        if data(i) = val then
          v_idx := i;
          exit;
        end if;
      end loop;
    end if;
    assert v_idx > (-1) report "Bit value not found" severity error;
    return v_idx;
  end function find_first;

end dev_utils_pkg;

--================================== END ====================================--
