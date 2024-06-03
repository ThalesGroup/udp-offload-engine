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
--        ARBITER_ONEHOT
--
------------------------------------------------
-- Arbiter that grants priorities in one hot mode
----------------------
-- The arbitration can be set to be done only at packet boundary (arbitration on tlast)
--
-- Priorities:
-- Either in fixed priority mode (the highest priority is given to the port with the least index)
-- or in a round robin fashion (the highest priority is given to the port after the last given one)
--
----------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.axis_utils_pkg.axis_register;

entity arbiter_onehot is
  generic(
    G_ACTIVE_RST   : std_logic := '1';   -- State at which the reset signal is asserted (active low or active high)
    G_ASYNC_RST    : boolean   := true;  -- Type of reset used (synchronous or asynchronous resets)
    G_NB_SLAVE     : positive  := 2;     -- Number of Slave interfaces
    G_REG_FORWARD  : boolean   := true;  -- Whether to register the forward path (tdata, tvalid and others) for selection ports
    G_REG_BACKWARD : boolean   := true;  -- Whether to register the backward path (tready) for selection ports
    G_PACKET_MODE  : boolean   := false; -- Whether to arbitrate on TLAST (packet mode) or for each sample (sample mode)
    G_ROUND_ROBIN  : boolean   := false  -- Whether to use a round_robin or fixed priorities
  );
  port(
    RST        : in  std_logic;
    CLK        : in  std_logic;
    -- SLAVE INTERFACES MONITORING
    S_TVALID   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    S_TLAST    : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    S_TREADY   : in  std_logic_vector(G_NB_SLAVE - 1 downto 0);
    -- SELECTION INTERFACE
    SEL_TDATA  : out std_logic_vector(G_NB_SLAVE - 1 downto 0);
    SEL_TVALID : out std_logic;
    SEL_TREADY : in  std_logic
  );
end arbiter_onehot;

architecture rtl of arbiter_onehot is

  -- Signals declaration

  -- arbitration decision
  signal arb_tvalid : std_logic;
  signal arb_tdata  : std_logic_vector(SEL_TDATA'range);
  signal prio_r     : integer range 0 to G_NB_SLAVE - 1;
  signal req_left   : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal arb_left   : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal arb_prio   : std_logic_vector(G_NB_SLAVE - 1 downto 0);

  -- block the arbitration
  signal unblock : std_logic_vector(G_NB_SLAVE - 1 downto 0);
  signal blocked : std_logic;

  -- output management
  signal sel_tdata_int  : std_logic_vector(SEL_TDATA'range);
  signal sel_tvalid_int : std_logic;
  signal sel_tready_int : std_logic;
  signal sel_tdata_r    : std_logic_vector(SEL_TDATA'range);
  signal sel_tvalid_r   : std_logic;

begin

  -- barrel shift right to set the highest priority on LSB
  req_left <= std_logic_vector(unsigned(S_TVALID) ror prio_r);

  -- asynchronous process to grant the access to highest priority
  -- drive the arb axis bus
  ASYNC_ARB : process(req_left)
  begin
    -- default values
    arb_tvalid <= '0';
    arb_left   <= (others => '0');

    -- search for the first '1' and copy it for arbitration decision
    for I in 0 to G_NB_SLAVE - 1 loop
      if (req_left(I) = '1') then
        arb_tvalid  <= '1';
        arb_left(I) <= '1';
        exit;
      end if;
    end loop;

  end process ASYNC_ARB;

  -- barrel shift left to set the arbitration value on the proper bit
  arb_tdata <= std_logic_vector(unsigned(arb_left) rol prio_r);
  -- next priority is given to the next value
  arb_prio  <= std_logic_vector(unsigned(arb_tdata) rol 1);

  -- unblocking condition for arbitration
  unblock <= S_TVALID and S_TREADY and S_TLAST when G_PACKET_MODE else S_TVALID and S_TREADY;

  -- synchronous process to register last arbitration
  SYNC_GRANT : process(CLK, RST) is
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      -- Asynchronous reset
      sel_tdata_r  <= (others => '0');
      sel_tvalid_r <= '0';
      blocked      <= '0';
      prio_r       <= 0;

    elsif rising_edge(CLK) then
      if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
        -- Synchronous reset
        sel_tdata_r  <= (others => '0');
        sel_tvalid_r <= '0';
        blocked      <= '0';
        prio_r       <= 0;

      else

        -- axis_handshake
        if sel_tready_int = '1' then
          sel_tvalid_r <= '0';
        end if;

        -- check if ready to send a new arbitration
        if (sel_tready_int or (not sel_tvalid_r)) = '1' then

          -- register the new arbitration
          if (arb_tvalid and (not blocked)) = '1' then

            -- register the selection
            -- only if no handshake in the same cycle
            sel_tvalid_r <= not sel_tready_int;
            sel_tdata_r  <= arb_tdata;

            -- become blocked on the new arbitration (mask with sel_tdata_int)
            if (unblock and sel_tdata_int) = sel_tdata_int then
              blocked <= '0';
            else
              blocked <= '1';
            end if;

            -- compute the priority
            if G_ROUND_ROBIN then
              for J in 0 to G_NB_SLAVE - 1 loop
                if arb_prio(J) = '1' then
                  prio_r <= J;
                end if;
              end loop;
            else
              prio_r <= 0;
            end if;

          end if;
        end if;

        -- check the blocking condition when blocked
        if blocked = '1' then

          -- unblock the arbitration (mask with sel_tdata_int)
          if (unblock and sel_tdata_int) = sel_tdata_int then
            blocked <= '0';
          else
            blocked <= '1';
          end if;

        end if;

      end if;
    end if;
  end process SYNC_GRANT;

  -- output of the selection command
  sel_tvalid_int <= sel_tvalid_r when (blocked or sel_tvalid_r) = '1' else arb_tvalid;
  sel_tdata_int  <= sel_tdata_r when (blocked or sel_tvalid_r) = '1' else arb_tdata;

  -- output registering
  inst_axis_register : component axis_register
    generic map(                         -- @suppress All parameters are not used
      G_ACTIVE_RST   => G_ACTIVE_RST,
      G_ASYNC_RST    => G_ASYNC_RST,
      G_REG_FORWARD  => G_REG_FORWARD,
      G_REG_BACKWARD => G_REG_BACKWARD,
      G_TDATA_WIDTH  => SEL_TDATA'length
    )
    port map(                            -- @suppress All unused ports are left to default values
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => sel_tdata_int,
      S_TVALID => sel_tvalid_int,
      S_TREADY => sel_tready_int,
      M_TDATA  => SEL_TDATA,
      M_TVALID => SEL_TVALID,
      M_TREADY => SEL_TREADY
    );

end rtl;
