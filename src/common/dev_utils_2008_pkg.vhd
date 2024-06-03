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


-- =========================================================================================
-- USAGE
-- =========================================================================================
-- Requires partial VHDL 2008 support.
--
-- When using VHDL 2008, importing the content of both packages dev_utils can be done
-- in one single line using a context definition:
--
--   context dev_utils_2008_ctx is  -- context is defined
--     library dev_utils;
--       use dev_utils.dev_utils_pkg.all;
--       use dev_utils.dev_utils_pkg_2008.all;
--   end context dev_utils_2008_ctx;
--
--   library dev_utils;
--     context dev_utils_2008_ctx;   -- loads both dev_utils_pkg and dev_utils_2008_pkg
--
-- This could also be used to load potential entity declaration packages, or the IEEE std packages.
-- =========================================================================================



library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common;
use common.dev_utils_pkg.all;

-------------------------------------------------------------------------------

package dev_utils_2008_pkg is

  ---------------------------------------------------------------------
  --       TYPES
  ---------------------------------------------------------------------

  -- /!\ WARNING: The use of T_SIGNED_ARRAY, T_UNSIGNED_ARRAY, T_SLV_ARRAY and T_TREE
  --              is only possible using VHDL 2008 as there are doubly unconstrained data types

  type t_signed_array   is array(natural range <>) of signed;            -- Requires partial VHDL 2008 support
  type t_unsigned_array is array(natural range <>) of unsigned;          -- Requires partial VHDL 2008 support
  type t_slv_array      is array(natural range <>) of std_logic_vector;  -- Requires partial VHDL 2008 support

  type t_tree is record -- Requires partial VHDL 2008 support ; can be initiated using the create_tree() function
    nbCompNodes : t_integer_array; -- Number of computation nodes per layer
    nbSyncNodes : t_integer_array; -- Number of synchronization nodes per layer
    baseIdx     : t_integer_array; -- Memory offset base index (cumulative sum of all the elements)
  end record t_tree;

  ---------------------------------------------------------------------
  --       CONVERSION
  ---------------------------------------------------------------------

  -- converts an std_logic_vector to a t_slv_array of size 1
  function to_slv_array(constant data : in std_logic_vector) return t_slv_array;
  -- converts a t_signed_array to a t_slv_array of same range
  function to_slv_array(constant data : in t_signed_array) return t_slv_array;
  -- converts a t_unsigned_array to a t_slv_array of same range
  function to_slv_array(constant data : in t_unsigned_array) return t_slv_array;

  -- converts a signed to a t_signed_array of size 1
  function to_signed_array(constant data : in signed) return t_signed_array;
  -- converts a t_slv_array to a t_signed_array of same range
  function to_signed_array(constant data : in t_slv_array) return t_signed_array;
  -- converts a t_unsigned_array to a t_signed_array of same range
  function to_signed_array(constant data : in t_unsigned_array) return t_signed_array;
  -- converts a t_integer to a t_signed_array of same range with each word of the specified bitwidth
  function to_signed_array(constant data : in t_integer_array; constant nbBits : in positive) return t_signed_array;

  -- converts an unsigned to a t_unsigned_array of size 1
  function to_unsigned_array(constant data : in unsigned) return t_unsigned_array;
  -- converts a t_slv_array to a t_unsigned_array of same range
  function to_unsigned_array(constant data : in t_slv_array) return t_unsigned_array;
  -- converts a t_signed_array to a t_unsigned_array of same range
  function to_unsigned_array(constant data : in t_signed_array) return t_unsigned_array;
  -- converts a t_integer to a t_unsigned_array of same range with each word of the specified bitwidth
  function to_unsigned_array(constant data : in t_integer_array; constant nbBits : in positive) return t_unsigned_array;

  -- converts a t_signed_array to a t_integer_array of same range
  function to_integer_array(constant data : in t_signed_array) return t_integer_array;
  -- converts a t_unsigned_array to a t_integer_array of same range
  function to_integer_array(constant data : in t_unsigned_array) return t_integer_array;

  ---------------------------------------------------------------------
  --      ENUMERATION/COUNT
  ---------------------------------------------------------------------

  -- /!\ WARNING: the following functions should only be used on constants/generic parameters!

  -- derives the optimum (nbWords:1) data reduction tree to perform associative operations such as additions, multiplications, comparisons, etc ; returns a t_tree object
  function create_tree(constant nbWords : in integer; constant radix : in integer; constant cnCplx : in real := 1.0; constant snCplx : in real := 0.0) return t_tree;

  ---------------------------------------------------------------------
  --       MISCELLANEOUS
  ---------------------------------------------------------------------

  -- Note: the following functions can be used on all sorts of inputs

  -- resizes each words of a t_signed_array from its original bitwidth to newWordSize using the default ieee.numeric_std.resize() method
  function resize(constant data : in t_signed_array; constant newWordSize : in positive) return t_signed_array;
  -- resizes each words of a t_unsigned_array from its original bitwidth to newWordSize using the default ieee.numeric_std.resize() method
  function resize(constant data : in t_unsigned_array; constant newWordSize : in positive) return t_unsigned_array;

  -- concatenates an array of std_logic_vector into a single std_logic_vector
  function cat(constant data : in t_slv_array) return std_logic_vector;
  -- splits a single std_logic_vector into an array of std_logic_vector
  function split(constant data : in std_logic_vector; constant wordSize : in positive := 8) return t_slv_array;

  -- swap_words reverses the words order, returning a t_slv_array of same range
  function swap_words(constant data : in t_slv_array) return t_slv_array;
  -- swap_bits reverses the bits order of each word, returning a t_slv_array of same range
  function swap_bits(constant data : in t_slv_array) return t_slv_array;
  -- swap reverses the order of all the bits, returning a t_slv_array of same range
  function swap(constant data : in t_slv_array) return t_slv_array;

  ---------------------------------------------------------------------
  --       COMPONENTS
  ---------------------------------------------------------------------

  -- replicates an input signal into multiple copies, inserting registers whenever necessary
  component replication_tree is
    generic(G_NB_WORDS     : integer   := 16;    -- Number of output replications
            G_RADIX        : integer   := 8;     -- Local maximum fan-out
            G_DATA_WIDTH   : natural   := 16;    -- Input data bitwidth
            G_ACTIVE_RST   : std_logic := '1';   -- Reset's activation value
            G_ASYNC_RST    : boolean   := False  -- Asynchronous reset if True, Synchronous otherwise
            );
    port(CLK      : in  std_logic;                                                      -- Clock
         RST      : in  std_logic                                 := not(G_ACTIVE_RST); -- Reset
         S_TVALID : in  std_logic                                 := '1';               -- Input valid
         S_TDATA  : in  std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');   -- Input data
         M_TVALID : out std_logic_vector(G_NB_WORDS-1 downto 0);                        -- Output replicated valid
         M_TDATA  : out std_logic_vector(G_NB_WORDS*G_DATA_WIDTH-1 downto 0)            -- Output replicated data
      );
  end component replication_tree;

end dev_utils_2008_pkg;

--========================== PACKAGE BODY ===========================--

package body dev_utils_2008_pkg is

  ---------------------------------------------------------------------
  --       INTERNAL FUNCTIONS
  ---------------------------------------------------------------------

  -- init_tree creates an empty tree structure of correct size
  function init_tree(constant nbWords : in integer; constant radix : in integer) return t_tree is
    constant C_NB_LAYERS_INIT : integer := logb_ceil(nbWords, radix);
    variable v_res_init       : t_tree(nbCompNodes(0 to C_NB_LAYERS_INIT - 1), nbSyncNodes(0 to C_NB_LAYERS_INIT - 1), baseIdx(0 to C_NB_LAYERS_INIT + 1)); -- constraining dimensions
  begin
    if C_NB_LAYERS_INIT = 1 then
      v_res_init.nbCompNodes := (0 => 1);
      v_res_init.nbSyncNodes := (0 => 0);
    else
      v_res_init.nbCompNodes := (0 => nbWords / radix, others => -1);
      v_res_init.nbSyncNodes := (0 => nbWords mod radix, others => -1);
    end if;
    v_res_init.baseIdx := (others => -1);
    return v_res_init;
  end function init_tree;

  -- derive_branches tries to find the best branches to complete the tree from the startLayer down
  function derive_branches(constant nbWords : in integer; constant radix : in integer; constant tree : in t_tree; constant startLayer : in integer) return t_tree is
    constant C_NB_LAYERS_BRANCH : integer := amax(1, logb_ceil(nbWords, radix));
    variable v_res_branch       : t_tree(nbCompNodes(0 to C_NB_LAYERS_BRANCH - 1), nbSyncNodes(0 to C_NB_LAYERS_BRANCH - 1), baseIdx(0 to C_NB_LAYERS_BRANCH + 1)); -- constraining dimensions
    variable v_nb_nodes_branch  : integer range integer'low to integer'high;
  begin
    if startLayer = 0 then
      v_res_branch := init_tree(nbWords, radix);
    else
      v_res_branch := tree;
    end if;
    for l in startLayer to C_NB_LAYERS_BRANCH - 1 loop
      v_nb_nodes_branch := v_res_branch.nbCompNodes(amax(0, l - 1)) + v_res_branch.nbSyncNodes(amax(0, l - 1));
      if l = (C_NB_LAYERS_BRANCH - 1) then                                      -- Last stage needs to have exactly one compute node
        v_res_branch.nbCompNodes(l) := 1;
        v_res_branch.nbSyncNodes(l) := amax(0, v_nb_nodes_branch - radix);              -- might not be 0 if irregular
      elsif l > 0 then                                                   -- First stage is never touched by this function
        v_res_branch.nbCompNodes(l) := v_nb_nodes_branch / radix;
        v_res_branch.nbSyncNodes(l) := v_nb_nodes_branch mod radix;
      end if;
    end loop;
    return v_res_branch;
  end function derive_branches;

  -- derive_regular_tree is a wrapper for derive_branches: it derives branches until the tree becomes regular (which necessarily exists)
  function derive_regular_tree(constant nbWords : in integer; constant radix : in integer; constant tree : in t_tree; constant startLayer : in integer) return t_tree is
    constant C_NB_LAYERS_TREE  : integer                                   := amax(1, logb_ceil(nbWords, radix));
    variable v_res_tree        : t_tree(nbCompNodes(0 to C_NB_LAYERS_TREE - 1), nbSyncNodes(0 to C_NB_LAYERS_TREE - 1), baseIdx(0 to C_NB_LAYERS_TREE + 1)); -- constraining dimensions
    variable v_new_tree        : t_tree(nbCompNodes(0 to C_NB_LAYERS_TREE - 1), nbSyncNodes(0 to C_NB_LAYERS_TREE - 1), baseIdx(0 to C_NB_LAYERS_TREE + 1)); -- constraining dimensions
    variable v_tmp_tree        : t_tree(nbCompNodes(0 to C_NB_LAYERS_TREE - 1), nbSyncNodes(0 to C_NB_LAYERS_TREE - 1), baseIdx(0 to C_NB_LAYERS_TREE + 1)); -- constraining dimensions
    variable v_nb_cn_best_tree : integer range integer'low to integer'high := integer'high; -- max value without overflow
    variable v_sum_tmp_tree    : integer range integer'low to integer'high;
  begin
    v_new_tree := derive_branches(nbWords, radix, tree, startLayer);
    if (v_new_tree.nbCompNodes(C_NB_LAYERS_TREE - 1) /= 1) or (v_new_tree.nbSyncNodes(C_NB_LAYERS_TREE - 1) /= 0) then
      for l in startLayer to C_NB_LAYERS_TREE - 2 loop
        if v_new_tree.nbSyncNodes(l) > 1 then
          v_tmp_tree                := v_new_tree;                                 -- copy
          v_tmp_tree.nbCompNodes(l) := v_tmp_tree.nbCompNodes(l) + 1;
          v_tmp_tree.nbSyncNodes(l) := 0;
          v_tmp_tree                := derive_regular_tree(nbWords, radix, v_tmp_tree, l + 1);
          if (v_tmp_tree.nbCompNodes(C_NB_LAYERS_TREE - 1) = 1) and (v_tmp_tree.nbSyncNodes(C_NB_LAYERS_TREE - 1) = 0) then
            v_sum_tmp_tree          := sum(v_tmp_tree.nbCompNodes);
            if v_sum_tmp_tree < v_nb_cn_best_tree then
              v_res_tree            := v_tmp_tree;
              v_nb_cn_best_tree     := v_sum_tmp_tree;
            end if;
          end if;
        end if;
      end loop;
    else
      v_res_tree := v_new_tree;
    end if;
    return v_res_tree;
  end function derive_regular_tree;

  ---------------------------------------------------------------------
  --       CONVERSION
  ---------------------------------------------------------------------

  -- to_slv_array(data: std_logic_vector) simply converts an std_logic_vector value to its t_slv_array of size 1 counterpart.
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_slv_array("0110") = t_slv_array'(("0110"))
  function to_slv_array(constant data : in std_logic_vector) return t_slv_array is
    variable v_res_toslvarr : t_slv_array(0 downto 0)(data'range);
  begin
    v_res_toslvarr(0) := data;
    return v_res_toslvarr;
  end function to_slv_array;

  -- to_slv_array converts a t_signed_array to a t_slv_array through termwise casting
  function to_slv_array(constant data : in t_signed_array) return t_slv_array is
    variable v_res_toslvarrs : t_slv_array(data'range)(data(data'low)'range);
  begin
    for i in data'range loop
      v_res_toslvarrs(i) := std_logic_vector(data(i));
    end loop;
    return v_res_toslvarrs;
  end function to_slv_array;

  -- alias for t_unsigned_array inputs
  function to_slv_array(constant data : in t_unsigned_array) return t_slv_array is
    variable v_res_toslvarru : t_slv_array(data'range)(data(data'low)'range);
  begin
    for i in data'range loop
      v_res_toslvarru(i) := std_logic_vector(data(i));
    end loop;
    return v_res_toslvarru;
  end function to_slv_array;


  -- to_signed_array(data: signed) simply converts a signed value to its t_signed_array of size 1 counterpart.
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_signed_array(signed'("0110")) = t_signed_array'(("0110"))
  function to_signed_array(constant data : in signed) return t_signed_array is
    variable v_res_tosarr : t_signed_array(0 downto 0)(data'range);
  begin
    v_res_tosarr(0) := data;
    return v_res_tosarr;
  end function to_signed_array;

  -- to_signed_array converts a t_slv_array to a t_signed_array through termwise casting
  function to_signed_array(constant data : in t_slv_array) return t_signed_array is
    variable v_res_tosarrslv : t_signed_array(data'range)(data(data'low)'range);
  begin
    for i in data'range loop
      v_res_tosarrslv(i) := signed(data(i));
    end loop;
    return v_res_tosarrslv;
  end function to_signed_array;

  -- alias for t_integer_array inputs
  function to_signed_array(constant data : in t_integer_array; constant nbBits : in positive) return t_signed_array is
    variable v_res_tosarrint : t_signed_array(data'range)(nbBits - 1 downto 0);
  begin
    for i in data'range loop
      v_res_tosarrint(i) := to_signed(data(i), nbBits);
    end loop;
    return v_res_tosarrint;
  end function to_signed_array;


  -- to_unsigned_array(data: unsigned) simply converts an unsigned value to its t_unsigned_array of size 1 counterpart.
  --
  -- Inputs: data      - data to convert
  --
  -- Example:  to_unsigned_array(unsigned'("0110")) = t_unsigned_array'(("0110"))
  function to_unsigned_array(constant data : in unsigned) return t_unsigned_array is
    variable v_res_tounsarr : t_unsigned_array(0 downto 0)(data'range);
  begin
    v_res_tounsarr(0) := data;
    return v_res_tounsarr;
  end function to_unsigned_array;

  -- alias for t_unsigned_array inputs
  function to_signed_array(constant data : in t_unsigned_array) return t_signed_array is
  begin
    return to_signed_array(to_slv_array(data));
  end function to_signed_array;

  -- to_unsigned_array converts a t_slv_array to a t_unsigned_array through termwise casting
  function to_unsigned_array(constant data : in t_slv_array) return t_unsigned_array is
    variable v_res_touarrslv : t_unsigned_array(data'range)(data(data'low)'range);
  begin
    for i in data'range loop
      v_res_touarrslv(i) := unsigned(data(i));
    end loop;
    return v_res_touarrslv;
  end function to_unsigned_array;

  -- alias for t_integer_array inputs
  function to_unsigned_array(constant data : in t_integer_array; constant nbBits : in positive) return t_unsigned_array is
    variable v_res_touarrint : t_unsigned_array(data'range)(nbBits - 1 downto 0);
  begin
    for i in data'range loop
      v_res_touarrint(i) := to_unsigned(data(i), nbBits);
    end loop;
    return v_res_touarrint;
  end function to_unsigned_array;

  -- alias for t_signed_array inputs
  function to_unsigned_array(constant data : in t_signed_array) return t_unsigned_array is
  begin
    return to_unsigned_array(to_slv_array(data));
  end function to_unsigned_array;

  -- to_integer_array converts a t_signed_array to a t_integer_array through termwise casting
  function to_integer_array(constant data : in t_signed_array) return t_integer_array is
    variable v_res_tointarrs : t_integer_array(data'range);
  begin
    for i in data'range loop
      v_res_tointarrs(i) := to_integer(data(i));
    end loop;
    return v_res_tointarrs;
  end function to_integer_array;

  -- alias for t_unsigned_array inputs
  function to_integer_array(constant data : in t_unsigned_array) return t_integer_array is
    variable v_res_tointarru : t_integer_array(data'range);
  begin
    for i in data'range loop
      v_res_tointarru(i) := to_integer(data(i));
    end loop;
    return v_res_tointarru;
  end function to_integer_array;


  ---------------------------------------------------------------------
  --      ENUMERATION/COUNT
  ---------------------------------------------------------------------

  -- nbComputeNodes, nbSyncNodes, baseIdx = create_tree(nbWords, radix=4, SNCplx=2, CNCplx=0)
  -- finds the best possible tree to perform (nbWords:1) data reduction based on the given radix
  -- It tries to attain the minimum number of computation nodes (and always does if SNCplx=0, that is
  -- the complexity of synchronization nodes is null) in the minimum number of logic stages, and
  -- tries to minimize the number of synchronization nodes needed when doing so, or to find a
  -- balance betwenn both based on their relative complexity, possibly normalized by the remaining
  -- available resources on the FPGA (or to always favour synchronization nodes if CNCplx=0,
  -- that is if the complexity of computation nodes is null), so that the number of computation
  -- nodes is not always the priority. For this optimization, the number of logic stages between
  -- two registers is also taken into account, as this will effectively affect the number of
  -- actually instantiated synchronization nodes.
  -- This function was made to derive a mux tree, but could be used to derive all sorts of (N:1) trees,
  -- like adder trees, or comparison trees for instance
  function create_tree(constant nbWords : in integer; constant radix : in integer; constant cnCplx : in real := 1.0; constant snCplx : in real := 0.0) return t_tree is
    constant C_NB_LAYERS_CREATE    : integer := amax(1, logb_ceil(nbWords, radix));
    variable v_res_create          : t_tree(nbCompNodes(0 to C_NB_LAYERS_CREATE - 1), nbSyncNodes(0 to C_NB_LAYERS_CREATE - 1), baseIdx(0 to C_NB_LAYERS_CREATE + 1)); -- constraining dimensions
    variable v_nb_sn_wasted_create : integer range integer'low to integer'high;
    variable v_base_create         : integer range integer'low to integer'high;
  begin
    assert radix > 1 report ("Incorrect radix value (divide by 0)") severity failure;
    assert (snCplx /= 0.0) or (cnCplx /= 0.0)
    report "Impossible snCplx/cnCplx combinations. Priority is given to cnCplx, effectively minimizing the computation nodes count, even if it means increasing the synchronization nodes count."
    severity warning;

    -- Special case: no tree needed
    if nbWords = 1 then
      v_res_create.nbCompNodes(0) := 0;
      v_res_create.nbSyncNodes(0) := 0;
      v_res_create.baseIdx        := (0, 1, 1);
    else

      -- First, we derive the reference tree
      v_res_create              := derive_regular_tree(nbWords, radix, v_res_create, 0);
      -- Then we need to optimize the tree with respect to the SN/CN balance, so we increase
      -- the CN count for each layer starting from the bottom, in which it could result in
      -- interesting SN savings, after what a regular tree is re-derived, and we proceed like
      -- this until we reach the end leaf
      for l in 0 to C_NB_LAYERS_CREATE - 1 loop
        -- We essentially measure the area assuming a triangular shape (and supporting a flat triangle)
        -- Thus, we need a base, which is reset after each stage empty of synchronization nodes to
        -- avoid overestimating the SN savings
        v_base_create           := v_res_create.nbSyncNodes(l);
        v_nb_sn_wasted_create   := 0;                                               -- Area associated with this layer
        for m in l to C_NB_LAYERS_CREATE - 1 loop
          v_nb_sn_wasted_create := v_nb_sn_wasted_create + amax(0, amin(v_base_create, v_res_create.nbSyncNodes(m)) - 1);
          if v_res_create.nbSyncNodes(m) = 0 then                               -- Area is complete
            exit;
          end if;
        end loop;
        if (real(v_nb_sn_wasted_create) * snCplx) > cnCplx then
          v_res_create.nbCompNodes(l) := v_res_create.nbCompNodes(l) + 1;
          v_res_create.nbSyncNodes(l) := 0;
          v_res_create                := derive_regular_tree(nbWords, radix, v_res_create, l + 1);
        end if;
      end loop;
      assert (v_res_create.nbCompNodes(C_NB_LAYERS_CREATE - 1) = 1) and (v_res_create.nbSyncNodes(C_NB_LAYERS_CREATE - 1) = 0)
      report "Unable to converge towards a regular solution. A solution necessarily exists, so this behavious is either due to inconsistent parameters or to a hidden bug."
      severity failure;
      v_res_create.baseIdx := cumsum(0 & nbWords & add(v_res_create.nbCompNodes, v_res_create.nbSyncNodes));
    end if;
    return v_res_create;
  end function create_tree;

  ---------------------------------------------------------------------
  --       MISCELLANEOUS
  ---------------------------------------------------------------------

  -- resize performs termwise resizing of a t_signed_array using ieee.numeric_std routine
  function resize(constant data : in t_signed_array; constant newWordSize : in positive) return t_signed_array is
    variable v_res_resizesarr : t_signed_array(data'range)(newWordSize - 1 downto 0);
  begin
    for i in data'range loop
      v_res_resizesarr(i) := resize(data(i), newWordSize);
    end loop;
    return v_res_resizesarr;
  end function resize;

  -- resize performs termwise resizing of a t_unsigned_array using ieee.numeric_std routine
  function resize(constant data : in t_unsigned_array; constant newWordSize : in positive) return t_unsigned_array is
    variable v_res_resizeuarr : t_unsigned_array(data'range)(newWordSize - 1 downto 0);
  begin
    for i in data'range loop
      v_res_resizeuarr(i) := resize(data(i), newWordSize);
    end loop;
    return v_res_resizeuarr;
  end function resize;

  -- cat concatenates an input t_slv_array into a single std_logic_vector
  function cat(constant data : in t_slv_array) return std_logic_vector is
    constant C_WORD_SIZE_CAT : integer := data(data'low)'length;
    variable v_res_cat       : std_logic_vector((data'length * C_WORD_SIZE_CAT) - 1 downto 0);
  begin
    for i in data'range loop
      v_res_cat((i + 1 - data'low) * C_WORD_SIZE_CAT - 1 downto (i - data'low) * C_WORD_SIZE_CAT) := data(i);
    end loop;
    return v_res_cat;
  end function cat;

  -- split splits a single std_logic_vector into an agreggate of multiple ones as a t_slv_array
  function split(constant data : in std_logic_vector; constant wordSize : in positive := 8) return t_slv_array is
    constant C_NB_WORDS_SPLIT : integer := data'length / wordSize;
    variable v_res_split      : t_slv_array(C_NB_WORDS_SPLIT - 1 downto 0)(wordSize - 1 downto 0);
  begin
    assert data'length = (C_NB_WORDS_SPLIT * wordSize) report "Inconsistent input parameters: total length should be a multiple of wordSize" severity error;
    for i in 0 to C_NB_WORDS_SPLIT - 1 loop
      v_res_split(i) := data((i + 1) * wordSize - 1 + data'low downto (i * wordSize) + data'low);
    end loop;
    return v_res_split;
  end function split;

  -- swap_words reverses the words order, returning a t_slv_array of same range
  --
  -- Inputs: data     - array of vector of bits
  --
  -- Example: swap_words("01001"&"11101") = "11101"&"01001"
  function swap_words(constant data : in t_slv_array) return t_slv_array is
    variable v_res_swapw : t_slv_array(data'range)(data(data'low)'range);
  begin
    for i in data'low to data'high loop
      v_res_swapw(i) := data(data'high - i + data'low);
    end loop;
    return v_res_swapw;
  end function swap_words;

  -- swap_bits reverses the bits order of each word, returning a t_slv_array of same range
  --
  -- Inputs: data     - array of vector of bits
  --
  -- Example: swap_bits("01001"&"11101") = "10010"&"10111"
  function swap_bits(constant data : in t_slv_array) return t_slv_array is
    variable v_res_swapb : t_slv_array(data'range)(data(data'low)'range);
  begin
    for i in data'low to data'high loop
      v_res_swapb(i) := swap(data(i));
    end loop;
    return v_res_swapb;
  end function swap_bits;

  -- swap reverses the order of all the bits, returning a t_slv_array of same range
  --
  -- Inputs: data     - array of vector of bits
  --
  -- Example: swap("01001"&"11101") = "10111"&"10010"
  function swap(constant data : in t_slv_array) return t_slv_array is
  begin
    return swap_bits(swap_words(data));
  end function swap;

end dev_utils_2008_pkg;

--================================== END ====================================--
