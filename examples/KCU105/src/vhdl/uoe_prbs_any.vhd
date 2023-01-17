 
----------------------------------------------------------------------- 
--
-- Copyright (C) 2011 by THALES. All rights reserved.
-- Design                 : fpga_rf_kappa
-- Company                : THALES
-- Product name           : RF KAPPA Demonstrator
-- Board name             : EVB VC707
-- Filename               : prbs_any.vhd
-- Creation Date          : The creation date
-- Current Version        : The Revision
-- Commit Date            : The commit date
-- Purpose                : 
--
-- Level of description   : rtl
-- Limitations            : -
-- Authors                : f_rubisk
-- Projects               : -
-- Tools & tools versions : Firefox default
--                        : Design Checker 2012.2b
--                        : IO Checker 3.0
--                        : Text_editor default
--                        : Textedit default
--                        : Xilinx Vivado 2015.1
--                        : ModelSim 10.3d
-- Reference              : -
-- Coding Standards       : - 87100217_DDQ_GRP_EN
-- Design Standards       : - 87206624_DDQ_GRP_EN
--
----------------------------------------------------------------------- 
--
-- History                : 
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity uoe_prbs_any is
    generic (      
        C_CHK_MODE      : boolean := FALSE; 
        C_INV_PATTERN   : boolean := FALSE;
        C_NBITS         : integer range 1 to 1024 := 4;
        C_INIT_VALUE    : integer range 1 to 1024 := 4
    );
    port (
        RST             : in  std_logic;                                                -- sync reset active high
        CLK             : in  std_logic;                                                -- system clock
        DATA_IN         : in  std_logic_vector(C_NBITS - 1 downto 0);                   -- inject error/data to be checked
        EN              : in  std_logic;                                                -- enable/pause pattern generation
        DATA_OUT        : out std_logic_vector(C_NBITS - 1 downto 0):= (others => '0')  -- generated prbs pattern/errors found
    );
end uoe_prbs_any;


architecture rtl of uoe_prbs_any is

  constant LFSR_2 : std_logic := '0';
  constant LFSR_4 : std_logic := '1';

  type lfsr_2_array is array (2 to 64, 1 to 2) of integer range 1 to 64;
  type lfsr_4_array is array (2 to 64, 1 to 4) of integer range 1 to 64;
  
  type lfsr_type_array is array (2 to 64) of std_logic;

  -- LFSR 4 TABLE
  constant LFSR_4_value_table : lfsr_4_array := (
    (1, 1, 1, 1    ),
    (1, 1, 1, 1    ),
    (1, 1, 1, 1    ),
    (5, 4, 3, 2    ),
    (6, 5, 3, 2    ),
    (7, 6, 5, 4    ),
    (8, 6, 5, 4    ),
    (9, 8, 6, 5    ),
    (10, 9, 7, 6   ),
    (11, 10, 9, 7  ),
    (12, 11, 8, 6  ),
    (13, 12, 10, 9 ),
    (14, 13, 11, 9 ),
    (15, 14, 13, 11),
    (16, 14, 13, 11),
    (17, 16, 15, 14),
    (18, 17, 16, 13),
    (19, 18, 17, 14),
    (20, 19, 16, 14),
    (21, 20, 19, 16),
    (22, 19, 18, 17),
    (23, 22, 20, 18),
    (24, 23, 21, 20),
    (25, 24, 23, 22),
    (26, 25, 24, 20),
    (27, 26, 25, 22),
    (28, 27, 24, 22),
    (29, 28, 27, 25),
    (30, 29, 26, 24),
    (31, 30, 29, 28),
    (32, 30, 26, 25),
    (33, 32, 29, 27),
    (34, 31, 30, 26),
    (35, 34, 28, 27),
    (36, 35, 29, 28),
    (37, 36, 33, 31),
    (38, 37, 33, 32),
    (39, 38, 35, 32),
    (40, 37, 36, 35),
    (41, 40, 39, 38),
    (42, 40, 37, 35),
    (43, 42, 38, 37),
    (44, 42, 39, 38),
    (45, 44, 42, 41),
    (46, 40, 39, 38),
    (47, 46, 43, 42),
    (48, 44, 41, 39),
    (49, 45, 44, 43),
    (50, 48, 47, 46),
    (51, 50, 48, 45),
    (52, 51, 49, 46),
    (53, 52, 51, 47),
    (54, 51, 48, 46),
    (55, 54, 53, 49),
    (56, 54, 52, 49),
    (57, 55, 54, 52),
    (58, 57, 53, 52),
    (59, 57, 55, 52),
    (60, 58, 56, 55),
    (61, 60, 59, 56),
    (62, 59, 57, 56),
    (63, 62, 59, 58),
    (64, 63, 61, 60)
  );

  -- LFSR 2 TABLE  
  constant LFSR_2_value_table : lfsr_2_array := (
    (2, 1  ),
    (3, 2  ),
    (4, 3  ),
    (5, 3  ),
    (6, 5  ),
    (7, 6  ),
    (1, 1  ),
    (9, 5  ),
    (10, 7 ),
    (11, 9 ),
    (1, 1  ),
    (1, 1  ),
    (1, 1  ),
    (15, 14),
    (1, 1  ),
    (17, 14),
    (18, 11),
    (1, 1  ),
    (20, 17),
    (21, 19),
    (22, 21),
    (23, 18),
    (1, 1  ),
    (25, 22),
    (1, 1  ),
    (1, 1  ),
    (28, 25),
    (29, 27),
    (1, 1  ),
    (31, 28),
    (1, 1  ),
    (33, 20),
    (1, 1  ),
    (35, 33),
    (36, 25),
    (1, 1  ),
    (1, 1  ),
    (39, 35),
    (1, 1  ),
    (41, 38),
    (1, 1  ),
    (1, 1  ),
    (1, 1  ),
    (1, 1  ),
    (1, 1  ),
    (47, 42),
    (1, 1  ),
    (49, 40),
    (1, 1  ),
    (1, 1  ),
    (52, 49),
    (1, 1  ),
    (1, 1  ),
    (55, 31),
    (1, 1  ),
    (57, 50),
    (58, 39),
    (1, 1  ),
    (60, 59),
    (1, 1  ),
    (1, 1  ),
    (63, 62),
    (1, 1  )
  );

  -- LFSR_2 or LFSR 4
  constant LFSR_type_table : lfsr_type_array:= (
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_4,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_2,
    LFSR_4,
    LFSR_2,
    LFSR_4,
    LFSR_4,
    LFSR_2,
    LFSR_4
  );
  
  type prbs_type is array (C_NBITS downto 0) of std_logic_vector(1 to C_NBITS);
  signal prbs          : prbs_type := (others => (others=>'1'));
  
  signal data_in_i     : std_logic_vector(C_NBITS-1 downto 0);    
  signal prbs_xor_a    : std_logic_vector(C_NBITS-1 downto 0);                                                  
  signal prbs_xor_b    : std_logic_vector(C_NBITS-1 downto 0);                                                 
  signal prbs_msb      : std_logic_vector(C_NBITS downto 1); 
      
begin 

   data_in_i <= DATA_IN when C_INV_PATTERN = FALSE else (not DATA_IN);
   
   g1: for I in 0 to C_NBITS-1 generate    
      
      -- PRBS GENERATION --> DEPEND OF NB_BIT FOR MAXIMUM LENGTH
      prbs_xor_a(I) <= prbs(I)(LFSR_2_value_table(C_NBITS,1)) xor prbs(I)(LFSR_2_value_table(C_NBITS,2)) when LFSR_type_table(C_NBITS) = LFSR_2 else
	                   prbs(I)(LFSR_4_value_table(C_NBITS,1)) xor prbs(I)(LFSR_2_value_table(C_NBITS,2)) xor prbs(I)(LFSR_4_value_table(C_NBITS,3)) xor prbs(I)(LFSR_4_value_table(C_NBITS,4)); 
      
	  -- CHECK RESULT (CHECKER MODE) or ERROR INSERTION (GENERATOR MODE)
	  prbs_xor_b(I) <= prbs_xor_a(I) xor data_in_i(I); 

      -- RESULTS INVERSION
      prbs_msb(I+1) <= prbs_xor_a(I) when C_CHK_MODE = FALSE else data_in_i(I);   
	  
      prbs(I+1) <= prbs_msb(I+1) & prbs(I)(1 to C_NBITS-1);      
   end generate;
      
   PRBS_GEN_01 : process (CLK)
   begin
      if rising_edge(CLK) then
         if RST = '1' then
            prbs(0)  <= std_logic_vector(to_unsigned(C_INIT_VALUE,C_NBITS));
         else
            if EN = '1' then
                prbs(0) <= prbs(C_NBITS);         
            end if;  
         end if;   
      end if;
   end process;

    DATA_OUT <= prbs_xor_b;     
        
   
end rtl;