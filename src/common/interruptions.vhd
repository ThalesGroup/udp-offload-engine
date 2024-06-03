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

entity interruptions is
  generic (
    G_STATUS_WIDTH  : natural   := 1;                 -- Number of IRQs
    G_ACTIVE_RST    : std_logic := '1';               -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST     : boolean   := false              -- Type of reset used (synchronous or asynchronous resets)
  );
  port (
    CLK             : in  std_logic;
    RST             : in  std_logic;
    IRQ_SOURCES     : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0); -- Interrupt sources vector
    IRQ_STATUS_RO   : out std_logic_vector(G_STATUS_WIDTH-1 downto 0); -- Interrupt status vector
    IRQ_ENABLE_RW   : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0); -- Interrupt enable vector
    IRQ_CLEAR_WO    : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0); -- Clear interrupt status vector
    IRQ_CLEAR_WRITE : in  std_logic;                                   -- Clear interrupt status
    IRQ_SET_WO      : in  std_logic_vector(G_STATUS_WIDTH-1 downto 0); -- Set interrupt status vector
    IRQ_SET_WRITE   : in  std_logic;                                   -- Set interrupt status
    IRQ             : out std_logic
  );
end interruptions;

architecture rtl of interruptions is

  -- Function OR_REDUCE
  function OR_REDUCE (constant ARG : in std_logic_vector) return std_logic is
    variable result : STD_LOGIC;
  begin
    result := '0';
    for i in ARG'range loop
      result := result or ARG(i);
    end loop;
    return result;
  end OR_REDUCE;

  signal status     : std_logic_vector (G_STATUS_WIDTH-1 downto 0); -- Instantaneous status vector
  signal reg_status : std_logic_vector (G_STATUS_WIDTH-1 downto 0);

begin

  IRQ_STATUS_RO <= reg_status;

  -- Interruptions process
  IT_PROCESS : process(CLK, RST)
  begin
    -- asynchronous reset
    if (G_ASYNC_RST and (RST = G_ACTIVE_RST)) then
        IRQ        <= '0';
        reg_status <= (others => '0');
        status     <= (others => '0');

    elsif rising_edge(CLK) then
      -- synchronous reset
      if (not(G_ASYNC_RST) and (RST = G_ACTIVE_RST)) then
        IRQ        <= '0';
        reg_status <= (others => '0');
        status     <= (others => '0');

      else
        IRQ <= OR_REDUCE(reg_status and IRQ_ENABLE_RW);

        if IRQ_CLEAR_WRITE = '1' then
          reg_status <= ((reg_status or status) and (not IRQ_CLEAR_WO));
        else
          reg_status <= (reg_status or status);
        end if;

        if IRQ_SET_WRITE = '1' then
          status     <= ((IRQ_SOURCES or IRQ_SET_WO) and (IRQ_ENABLE_RW));
        else
          status     <= (IRQ_SOURCES and IRQ_ENABLE_RW);
        end if;

      end if;
    end if;
  end process IT_PROCESS;

end rtl;
