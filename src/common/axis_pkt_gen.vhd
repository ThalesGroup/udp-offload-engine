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
--        AXIS_PKT_GEN
--
------------------------------------------------
-- AXI4-Stream frame generator
------------------------------
-- This module is used to test other module by generating data sent on an AXI4-Stream interface
-- 
-- It can generate random or incremental frames
-- The user can parameter the number of frames to generate, 
-- if the size of the frame should be constant or not and 
-- the size of the frame if it's constant
--
------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.axis_utils_pkg.all;

use common.datatest_tools_pkg.all;

entity axis_pkt_gen is
  generic(
    G_ASYNC_RST      : boolean   := false;
    G_ACTIVE_RST     : std_logic := '1';
    G_TDATA_WIDTH    : positive  := 64;                                                   -- Data bus size
    G_TUSER_WIDTH    : positive  := 8;                                                    -- User bus size used to transmit frame size 
    G_LSB_TKEEP      : boolean   := true;                                                 -- To choose if the TKEEP must be in LSB or MSB
    G_FRAME_SIZE_MIN : positive  := 1;                                                    -- Minimum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
    G_FRAME_SIZE_MAX : positive  := 255;                                                  -- Maximum size for data frame : must be between 1 and (2^G_TUSER_WIDTH) - 1
    G_DATA_TYPE      : integer   := C_GEN_PRBS                                            -- PRBS : 0 / RAMP : 1
  );
  port(
    CLK               : in  std_logic;
    RST               : in  std_logic;
    -- Output ports
    M_TREADY          : in  std_logic;
    M_TVALID          : out std_logic;
    M_TDATA           : out std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
    M_TLAST           : out std_logic;
    M_TKEEP           : out std_logic_vector(((G_TDATA_WIDTH + 7) / 8) - 1 downto 0);
    M_TUSER           : out std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
    --Configuration ports
    ENABLE            : in  std_logic;
    NB_FRAME          : in  std_logic_vector(15 downto 0);                                -- Number of frame to generate : if 0, frame are generated endlessly
    FRAME_TYPE        : in  std_logic;                                                    -- '0' (static) : frames generated will always have the same size / '1' (dynamic) : frames will have different sizes
    FRAME_STATIC_SIZE : in  std_logic_vector(G_TUSER_WIDTH - 1 downto 0);                 -- Number of bytes in each frame in case the frame type is static
    DONE              : out std_logic                                                     -- When asserted, indicate the end of data generation
  );
end axis_pkt_gen;

architecture rtl of axis_pkt_gen is

  --------------------------------------------------------------------
  -- Constants declaration
  --------------------------------------------------------------------
  constant C_PRBS_LENGTH    : integer                                      := 4;          -- To parametrize PRBS for generation of frame size : must be between 2 and 63
  constant C_TKEEP_WIDTH    : integer                                      := (G_TDATA_WIDTH + 7) / 8;
  constant C_FRAME_SIZE_MIN : std_logic_vector(G_TUSER_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(G_FRAME_SIZE_MIN, G_TUSER_WIDTH));
  constant C_FRAME_SIZE_MAX : std_logic_vector(G_TUSER_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(G_FRAME_SIZE_MAX, G_TUSER_WIDTH));
  
  --------------------------------------------------------------------
  -- Signals declaration
  --------------------------------------------------------------------
  -- Global management
  signal enable_r      : std_logic;
  signal start         : std_logic;
  signal stop          : std_logic;
  signal en_gen        : std_logic;
  signal cnt_byte      : unsigned(G_TUSER_WIDTH downto 0);   -- To count number of bytes sent to assert TLAST
  signal cnt_tlast_gen : unsigned(NB_FRAME'range);           -- To count number of TLAST sent in case you want to send NB_FRAME
  signal last_frame    : std_logic;

  -- Data
  signal config_tready   : std_logic;
  signal config_tvalid   : std_logic;
  signal config_tvalid_r : std_logic;

  signal prbs_ramp_tready : std_logic;
  signal prbs_ramp_tvalid : std_logic;

  signal gen_tready : std_logic_vector(1 downto 0);
  signal gen_tvalid : std_logic_vector(1 downto 0);
  signal gen_tdata  : std_logic_vector(G_TDATA_WIDTH - 1 downto 0);
  signal gen_tlast  : std_logic;
  signal gen_tkeep  : std_logic_vector(C_TKEEP_WIDTH - 1 downto 0);
  signal gen_tuser  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);

  -- Frame size
  signal frame_size_ready : std_logic;
  signal frame_size_rand  : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal frame_size_int   : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);
  signal frame_size_int_r : std_logic_vector(G_TUSER_WIDTH - 1 downto 0);

begin

  --===================================
  -- FLUX MANAGEMENT
  --===================================
  -- This process is used to :
  --    * detect when the module is enabled
  --    * assign values for TLAST, TKEEP and TUSER
  P_GENERATE : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      enable_r        <= '0';
      start           <= '0';
      stop            <= '0';
      en_gen          <= '0';
      DONE            <= '0';
      config_tvalid   <= '0';
      config_tvalid_r <= '0';
      cnt_byte        <= (others => '0');
      cnt_tlast_gen   <= (others => '0');
      last_frame      <= '0';
      gen_tvalid(0)   <= '0';
      gen_tlast       <= '0';
      gen_tkeep       <= (others => '0');
      gen_tuser       <= (others => '0');
    else
      if rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          enable_r        <= '0';
          start           <= '0';
          stop            <= '0';
          en_gen          <= '0';
          DONE            <= '0';
          config_tvalid   <= '0';
          config_tvalid_r <= '0';
          cnt_byte        <= (others => '0');
          cnt_tlast_gen   <= (others => '0');
          last_frame      <= '0';
          gen_tvalid(0)   <= '0';
          gen_tlast       <= '0';
          gen_tkeep       <= (others => '0');
          gen_tuser       <= (others => '0');
        else

          -- Register to create a pulse on start
          enable_r <= ENABLE;

          -- Register to create a pulse on configuration to ignore the last generated data
          config_tvalid_r <= config_tvalid;

          -- Clear pulse
          start <= '0';
          if (config_tready = '1') then
            config_tvalid <= '0';
          end if;

          -- To detect rising edge on ENABLE
          if (ENABLE = '1') and (enable_r /= '1') then
            -- Pulse
            start         <= '1';
            config_tvalid <= '1';
            -- Not pulse
            stop          <= '0';
            DONE          <= '0';
          end if;

          if (ENABLE /= '1') and (enable_r = '1') then
            stop <= '1';
          end if;

          if (start = '1') then
            -- Allow data generation from PRBS and RAMP modules
            en_gen        <= '1';
            gen_tvalid(0) <= '1';
          end if;

          -- In case the size of frame is static, we put it in TUSER
          if (FRAME_TYPE /= '1') then
            gen_tuser <= FRAME_STATIC_SIZE;
          end if;

          -- To assign a value to TLAST, TKEEP and TUSER when there is a transaction
          if (gen_tready(0) = '1') or (gen_tvalid(0) = '0') then
            if (start = '1') or (en_gen = '1') then
              -- Default assignation
              gen_tlast <= '0';
              gen_tkeep <= (others => '1');
              
              -- We increment the counter to know how many bytes are already sent
              cnt_byte  <= cnt_byte + C_TKEEP_WIDTH;
              
              -- In case PRBS is allowed to generate a new random size of frame...
              if (frame_size_ready = '1') then
                -- ...the value generated is assigned to TUSER to indicate the size of the current frame...
                gen_tuser <= frame_size_int;
                
                -- ... and we check the value of frame_size_int to anticipate the TLAST and TKEEP values
                -- because frame_size_int will be the size of the next frame and we have to know if we will have to assert TLAST directly
                if (to_integer(unsigned(frame_size_int)) <= C_TKEEP_WIDTH) then
                  gen_tlast <= '1';
                  cnt_byte  <= (others => '0');
                  
                  -- The enabled bits of TKEEP will depend if the result must be in little endian or big endian
                  for i in 0 to C_TKEEP_WIDTH-1 loop
                    if G_LSB_TKEEP then
                      if i < to_integer(unsigned(frame_size_int)) then
                        gen_tkeep(i) <= '1';
                      else
                        gen_tkeep(i) <= '0';
                      end if;
                    
                    else
                      if i < (C_TKEEP_WIDTH - to_integer(unsigned(frame_size_int))) then
                        gen_tkeep(i) <= '0';
                      else
                        gen_tkeep(i) <= '1';
                      end if;
                    end if;
                  end loop;
                  
                end if;
              else
                -- In case PRBS is not allowed to generate a new random size of frame (for exemple because the transfer of the current frame is not over)...
                -- ...we compare the current value of the frame (indicated on TUSER) with the next value of the counter of byte to know if next data will be the last or not
                if unsigned(('0' & gen_tuser)) <= (cnt_byte + C_TKEEP_WIDTH) then
                  gen_tlast <= '1';
                  cnt_byte  <= (others => '0');
                end if;
                  
                -- The enabled bits of TKEEP will depend if the result must be in little endian or big endian
                if unsigned(('0' & gen_tuser)) < (cnt_byte + C_TKEEP_WIDTH) then
                  for i in 0 to C_TKEEP_WIDTH-1 loop
                    if G_LSB_TKEEP then
                      if i < (to_integer(unsigned(gen_tuser)) mod C_TKEEP_WIDTH) then
                        gen_tkeep(i) <= '1';
                      else
                        gen_tkeep(i) <= '0';
                      end if;
                    else
                      if i < (C_TKEEP_WIDTH - (to_integer(unsigned(gen_tuser)) mod C_TKEEP_WIDTH)) then
                        gen_tkeep(i) <= '0';
                      else
                        gen_tkeep(i) <= '1';
                      end if;
                    end if;
                  end loop;
                end if;
                  
              end if;
            end if;
          end if;

          -- When a frame is over...
          if (gen_tready(0) = '1') and (gen_tvalid(0) = '1') and (gen_tlast = '1') then
            -- ...we increament the counter to know how many frames have been sent...
            cnt_tlast_gen <= cnt_tlast_gen + 1;
            --...and we check if it's the last frame to send
            -- When NB_FRAME /= 0, the number of frame to send is finite
            if to_integer(unsigned(NB_FRAME)) /= 0 then
              -- When all the frames have been sent...
              if cnt_tlast_gen = (unsigned(NB_FRAME) - 1) then
                -- ...we stop data generation...
                DONE          <= '1';
                -- ...we disable PRBS and RAMP for data generation...
                en_gen        <= '0';
                -- ...and reinitialize the counters
                cnt_byte      <= (others => '0');
                cnt_tlast_gen <= (others => '0');
                stop          <= '1';
                gen_tvalid(0) <= '0';
              end if;
            -- When NB_FRAME = 0, the number of frame to send is infinite
            else
              -- In case the user stop the module at the same time...
              if ENABLE /= '1' then
                -- ...we reinitialize the signals
                en_gen        <= '0';
                DONE          <= '1';
                cnt_byte      <= (others => '0');
                cnt_tlast_gen <= (others => '0');
                gen_tlast     <= '0';
                gen_tkeep     <= (others => '0');
                gen_tuser     <= (others => '0');
                gen_tvalid(0) <= '0';
              end if;
            end if;
          end if;

          -- If the user stop the module during when the current frame is not over (TLAST = '0'), we continue to allowed data generation (en_gen = '1')
          if (stop = '1') and (en_gen = '1') then
            if (gen_tlast /= '1') then
              en_gen <= '1';
            end if;
          end if;

          last_frame <= '0';
          -- All the frames have been sent
          if cnt_tlast_gen = (unsigned(NB_FRAME) - 1) then
            last_frame <= '1';
          end if;

        end if;
      end if;
    end if;
  end process P_GENERATE;

  --===================================
  -- FRAME SIZE GENERATION
  --===================================
  frame_size_ready <= '0' when (FRAME_TYPE /= '1') else                                   -- Static frame size
                      '1' when (start = '1') else                                         -- Generate random size of first frame
                      '1' when (gen_tready(0) = '1') and (gen_tvalid(0) = '1') and (gen_tlast = '1') and (last_frame /= '1') else -- Generate random size of next but not last frame
                      '0';

  inst_gen_prbs_frame_size : gen_prbs
    generic map(
      G_ASYNC_RST   => G_ASYNC_RST,
      G_ACTIVE_RST  => G_ACTIVE_RST,
      G_TDATA_WIDTH => FRAME_STATIC_SIZE'length,
      G_PRBS_LENGTH => C_PRBS_LENGTH
    )
    port map(
      CLK             => CLK,
      RST             => RST,
      S_CONFIG_TREADY => open,
      S_CONFIG_TVALID => '0',
      S_CONFIG_TDATA  => (others => '0'),
      M_TREADY        => frame_size_ready,
      M_TVALID        => open,
      M_TDATA         => frame_size_rand
    );

  frame_size_int <= C_FRAME_SIZE_MIN when (unsigned(frame_size_rand) <= unsigned(C_FRAME_SIZE_MIN)) and (frame_size_ready = '1') else -- Frame with random size : size must be bounded
                    C_FRAME_SIZE_MAX when (unsigned(frame_size_rand) >= unsigned(C_FRAME_SIZE_MAX)) and (frame_size_ready = '1') else -- Frame with random size : size must be bounded
                    frame_size_rand when (frame_size_ready = '1') else
                    frame_size_int_r;

  -- Process used to memorize frame size
  P_SAVE : process(CLK, RST)
  begin
    if G_ASYNC_RST and (RST = G_ACTIVE_RST) then
      frame_size_int_r <= (others => '0');
    else
      if rising_edge(CLK) then
        if (not G_ASYNC_RST) and (RST = G_ACTIVE_RST) then
          frame_size_int_r <= (others => '0');
        else
          frame_size_int_r <= frame_size_int;
        end if;
      end if;
    end if;
  end process P_SAVE;

  --===================================
  -- DATA GENERATION
  --===================================
  -- Generate randow data
  GEN_DATA_PRBS : if (G_DATA_TYPE = C_GEN_PRBS) generate
    
    -- Constant declaration
    constant C_PRBS_INIT : std_logic_vector(C_PRBS_LENGTH-1 downto 0) := std_logic_vector(to_unsigned(4, C_PRBS_LENGTH));
    
    -- Signal declaration
    signal prbs_data       : std_logic_vector(7 downto 0);
    
  begin

    -- PRBS generator
    inst_gen_prbs : gen_prbs
      generic map(
        G_ASYNC_RST   => G_ASYNC_RST,
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_TDATA_WIDTH => 8,
        G_PRBS_LENGTH => C_PRBS_LENGTH
      )
      port map(
        CLK             => CLK,
        RST             => RST,
        S_CONFIG_TREADY => config_tready,
        S_CONFIG_TVALID => config_tvalid,
        S_CONFIG_TDATA  => C_PRBS_INIT,
        M_TREADY        => prbs_ramp_tready,
        M_TVALID        => prbs_ramp_tvalid,
        M_TDATA         => prbs_data
      );

    -- prbs_data is on 8 bits so we have to duplicate the value to have G_TDATA_WIDTH bits
    GEN_RESIZE_PRBS : for i in 0 to (C_TKEEP_WIDTH - 1) generate
      gen_tdata((8 * i) + 7 downto (8 * i)) <= std_logic_vector(unsigned(prbs_data) rol i); -- Rotate left : 1101 --> 1011 --> 0111 --> 1110
    end generate GEN_RESIZE_PRBS;

  end generate GEN_DATA_PRBS;

  -- Generate incremental data
  GEN_DATA_RAMP : if (G_DATA_TYPE = C_GEN_RAMP) generate
    -- Constant declaration
    constant C_RAMP_STEP : std_logic_vector(G_TDATA_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(1,G_TDATA_WIDTH));
  begin

    inst_gen_ramp : gen_ramp
      generic map(
        G_ASYNC_RST   => G_ASYNC_RST,
        G_ACTIVE_RST  => G_ACTIVE_RST,
        G_TDATA_WIDTH => G_TDATA_WIDTH
      )
      port map(
        CLK                 => CLK,
        RST                 => RST,
        S_CONFIG_TREADY     => config_tready,
        S_CONFIG_TVALID     => config_tvalid,
        S_CONFIG_TDATA_INIT => (others => '0'),
        S_CONFIG_TDATA_STEP => C_RAMP_STEP,
        M_TREADY            => prbs_ramp_tready,
        M_TVALID            => prbs_ramp_tvalid,
        M_TDATA             => gen_tdata
      );
  end generate GEN_DATA_RAMP;

  -- To ignore the last data generated but not used due to reconfiguration
  gen_tvalid(1)    <= prbs_ramp_tvalid xor config_tvalid_r;
  prbs_ramp_tready <= config_tvalid_r or gen_tready(1);

  --===================================
  -- OUTPUT
  --===================================
  inst_axis_combine : axis_combine
    generic map(
      G_ACTIVE_RST       => G_ACTIVE_RST,
      G_ASYNC_RST        => G_ASYNC_RST,
      G_TDATA_WIDTH      => G_TDATA_WIDTH,
      G_TUSER_WIDTH      => G_TUSER_WIDTH,
      G_TID_WIDTH        => 1,
      G_TDEST_WIDTH      => 1,
      G_NB_SLAVE         => 2,
      G_REG_OUT_FORWARD  => true,
      G_REG_OUT_BACKWARD => false
    )
    port map(
      CLK      => CLK,
      RST      => RST,
      S_TDATA  => gen_tdata,
      S_TVALID => gen_tvalid,
      S_TLAST  => gen_tlast,
      S_TUSER  => gen_tuser,
      S_TSTRB  => (others => '-'),
      S_TKEEP  => gen_tkeep,
      S_TID    => (others => '-'),
      S_TDEST  => (others => '-'),
      S_TREADY => gen_tready,
      M_TDATA  => M_TDATA,
      M_TVALID => M_TVALID,
      M_TLAST  => M_TLAST,
      M_TUSER  => M_TUSER,
      M_TSTRB  => open,
      M_TKEEP  => M_TKEEP,
      M_TID    => open,
      M_TDEST  => open,
      M_TREADY => M_TREADY
    );

end rtl;

