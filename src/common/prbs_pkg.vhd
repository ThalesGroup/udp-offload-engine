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

----------------------------------
-- Package prbs_pkg
----------------------------------
--
-- This package contains the declaration of the 
-- tables used to generate PRBS. The coefficients
-- in the table are based on Xilinx files XAPP052
-- (https://docs.xilinx.com/v/u/en-US/xapp052)
-- 
-- The package also contains the function xor_lfsr
-- used to calculate the xor of LFSR.
--
----------------------------------

package prbs_pkg is

  --------------------------------------------------------------------
  -- Types declaration
  --------------------------------------------------------------------
  type lfsr_2_array is array (2 to 64, 1 to 2) of integer range 0 to 64;                  -- LFSR cannot be done if there is only 0 or 1 bit on data bus : begin at 2
  type lfsr_4_array is array (2 to 64, 1 to 4) of integer range 0 to 64;
  type lfsr_type_array is array (2 to 64) of std_logic;

  --------------------------------------------------------------------
  -- Constant declaration 
  --------------------------------------------------------------------
  constant C_INIT_PRBS : integer   := 4;
  constant C_LFSR_2    : std_logic := '0';
  constant C_LFSR_4    : std_logic := '1';

  constant C_LFSR_4_VALUE_TABLE : lfsr_4_array := (
    (0, 0, 0, 0),                                     -- Begin at PRBS length 2
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (8, 6, 5, 4),                                     -- IF PRBS length is 8, LFSR_4(PRBS_LENGTH,1) = 9, LFSR_4(PRBS_LENGTH,2) = 8, etc...
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (12, 6, 4, 1),
    (13, 4, 3, 1),
    (14, 5, 3, 1),
    (0, 0, 0, 0),
    (16, 15, 13, 4),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (19, 6, 2, 1),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (24, 23, 22, 17),
    (0, 0, 0, 0),
    (26, 6, 2, 1),
    (27, 5, 2, 1),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (30, 6, 4, 1),
    (0, 0, 0, 0),
    (32, 22, 2, 1),
    (0, 0, 0, 0),
    (34, 27, 2, 1),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (37, 5, 4, 3),
    (38, 6, 5, 1),
    (0, 0, 0, 0),
    (40, 38, 21, 19),
    (0, 0, 0, 0),
    (42, 41, 20, 19),
    (43, 42, 38, 37),
    (44, 43, 18, 17),
    (45, 44, 42, 41),
    (46, 45, 26, 25),
    (0, 0, 0, 0),
    (48, 47, 21, 20),
    (0, 0, 0, 0),
    (50, 49, 24, 23),
    (51, 50, 36, 35),
    (0, 0, 0, 0),
    (53, 52, 38, 37),
    (54, 53, 18, 17),
    (0, 0, 0, 0),
    (56, 55, 35, 34),
    (0, 0, 0, 0),
    (0, 0, 0, 0),
    (59, 58, 38, 37),
    (0, 0, 0, 0),
    (61, 60, 46, 45),
    (62, 61, 6, 5),
    (0, 0, 0, 0),
    (64, 63, 61, 60)
  );

  -- LFSR 2 TABLE  
  constant C_LFSR_2_VALUE_TABLE : lfsr_2_array := (
    (2, 1),                                           -- IF PRBS length is 2, the XOR will use the bits 2 and 1 of prbs
    (3, 2),
    (4, 3),
    (5, 3),
    (6, 5),
    (7, 6),
    (0, 0),
    (9, 5),                                           -- IF PRBS length is 9, the XOR will use bits 9 and 5 of prbs
    (10, 7),
    (11, 9),
    (0, 0),
    (0, 0),
    (0, 0),
    (15, 14),
    (0, 0),
    (17, 14),
    (18, 11),
    (0, 0),
    (20, 17),
    (21, 19),
    (22, 21),
    (23, 18),
    (0, 0),
    (25, 22),
    (0, 0),
    (0, 0),
    (28, 25),
    (29, 27),
    (0, 0),
    (31, 28),
    (0, 0),
    (33, 20),
    (0, 0),
    (35, 33),
    (36, 25),
    (0, 0),
    (0, 0),
    (39, 35),
    (0, 0),
    (41, 38),
    (0, 0),
    (0, 0),
    (0, 0),
    (0, 0),
    (0, 0),
    (47, 42),
    (0, 0),
    (49, 40),
    (0, 0),
    (0, 0),
    (52, 49),
    (0, 0),
    (0, 0),
    (55, 31),
    (0, 0),
    (57, 50),
    (58, 39),
    (0, 0),
    (60, 59),
    (0, 0),
    (0, 0),
    (63, 62),
    (0, 0)
  );

  -- LFSR_2 or LFSR 4
  constant C_LFSR_TYPE_TABLE : lfsr_type_array := (
    C_LFSR_2,                                         -- IF PRBS length is 2, we use LFSR_2
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4,
    C_LFSR_4,
    C_LFSR_2,
    C_LFSR_4                                          -- IF PRBS length is 64, we use LFSR_4
  );

  --------------------------------------------------------------------
  -- Functions declaration
  --------------------------------------------------------------------
  function xor_lfsr(constant prbs : in std_logic_vector; constant prbs_size : in integer) return std_logic;


end prbs_pkg;

-------------------------------------------
-- Package Body
-------------------------------------------
package body prbs_pkg is

  -- Function uses to calculate the XOR in the module
  function xor_lfsr(constant prbs : in std_logic_vector; constant prbs_size : in integer) return std_logic is
    variable xor_prbs : std_logic;
  begin
    if C_LFSR_TYPE_TABLE(prbs_size) = C_LFSR_2 then
      xor_prbs := prbs(C_LFSR_2_VALUE_TABLE(prbs_size, 1)) xor prbs(C_LFSR_2_VALUE_TABLE(prbs_size, 2));
    else
      xor_prbs := prbs(C_LFSR_4_VALUE_TABLE(prbs_size, 1)) xor prbs(C_LFSR_4_VALUE_TABLE(prbs_size, 2)) xor prbs(C_LFSR_4_VALUE_TABLE(prbs_size, 3)) xor prbs(C_LFSR_4_VALUE_TABLE(prbs_size, 4));
    end if;
    return xor_prbs;
  end function xor_lfsr;


end prbs_pkg;
