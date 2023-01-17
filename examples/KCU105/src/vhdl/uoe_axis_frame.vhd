 
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uoe_axis_frame is
	generic(
		C_TYPE             : string                   := "WO"; -- "RO" "WO"
		C_AXIS_TDATA_WIDTH : integer range 1 to 64    := 64;
		C_TIMEOUT          : integer range 1 to 2**30 := 2**30;
		C_FRAME_SIZE_MIN   : integer range 1 to 65535 := 1;
		C_FRAME_SIZE_MAX   : integer range 1 to 65535 := 65535;
		C_INIT_VALUE       : integer range 1 to 2048  := 4;
		C_DATA_TYPE        : string := "PRBS"                     -- "PRBS" "RAMP"
	);
	port(
		clk               : in  std_logic;
		rst               : in  std_logic;
		--axis interface
		m_axis_tdata      : out std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
		m_axis_tvalid     : out std_logic;
		m_axis_tlast      : out std_logic;
		m_axis_tkeep      : out std_logic_vector(C_AXIS_TDATA_WIDTH / 8 - 1 downto 0);
		m_axis_tuser      : out std_logic_vector(31 downto 0);
		m_axis_tready     : in  std_logic;
		s_axis_tdata      : in  std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
		s_axis_tvalid     : in  std_logic;
		s_axis_tlast      : in  std_logic;
		s_axis_tready     : out std_logic;
		s_axis_tuser      : in  std_logic_vector(31 downto 0);
		s_axis_tkeep      : in  std_logic_vector(C_AXIS_TDATA_WIDTH / 8 - 1 downto 0);
		--parameters      
		start             : in  std_logic;
		stop              : in  std_logic;
		frame_size_type   : in  std_logic; -- '0' STATIC      '1' DYNAMIC
		random_threshold  : in  std_logic_vector(7 downto 0); -- 0 to 2^8-1 --> 50% = 2^7-1
		nb_data           : in  std_logic_vector(63 downto 0); -- number of bytes to generate/check
		frame_size        : in  std_logic_vector(15 downto 0); -- number of bytes in each frame

		-- Results
		transfert_time    : out std_logic_vector(63 downto 0);
		end_of_axis_frame : out std_logic;
		tdata_error       : out std_logic;
		link_error        : out std_logic
	);
end uoe_axis_frame;

architecture rtl of uoe_axis_frame is

	component UOE_PRBS_ANY
		generic(
			C_CHK_MODE    : boolean                 := false;
			C_INV_PATTERN : boolean                 := false;
			C_NBITS       : natural range 0 to 1024 := 16;
			C_INIT_VALUE  : integer range 1 to 1024 := 4
		);
		port(
			RST      : in  std_logic;   -- sync reset active high
			CLK      : in  std_logic;   -- system clock
			DATA_IN  : in  std_logic_vector(C_NBITS - 1 downto 0); -- inject error/data to be checked
			EN       : in  std_logic;   -- enable/pause pattern generation
			DATA_OUT : out std_logic_vector(C_NBITS - 1 downto 0) -- generated prbs pattern/errors found
		);
	end component UOE_PRBS_ANY;

	function incr_calc(data_width : integer) return std_logic_vector is
	    variable vect_var      : std_logic_vector(data_width-1 downto 0);
	    variable nb_bytes_var  : integer;
	    variable nb_words_var  : integer;
	begin
	    -- Number of bytes in a vector
	    nb_bytes_var := data_width/8;
	    -- Number of 32-bits words in a vector
	    nb_words_var := nb_bytes_var/4;

	    if nb_words_var > 0 then
	        for i in 0 to nb_words_var-1 loop
	           vect_var(32*i+31 downto 32*i) := std_logic_vector(to_unsigned(nb_words_var,32));
	        end loop;
	    else
            vect_var := std_logic_vector(to_unsigned(1,data_width));
	    end if;
	    return vect_var;
	end function;

    function init_calc(data_width : integer) return std_logic_vector is
        variable vect_var      : std_logic_vector(data_width-1 downto 0);
        variable nb_bytes_var  : integer;
        variable nb_words_var  : integer;
    begin
        -- Number of bytes in a vector
        nb_bytes_var := data_width/8;
        -- Number of 32-bits words in a vector
        nb_words_var := nb_bytes_var/4;

        if nb_words_var > 0 then
            for i in 0 to nb_words_var-1 loop
               vect_var(32*i+31 downto 32*i) := std_logic_vector(to_unsigned(i,32));
            end loop;
        else
            vect_var := std_logic_vector(to_unsigned(0,data_width));
        end if;
        return vect_var;
    end function;

    constant C_RAMP_INIT        : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0) := init_calc(C_AXIS_TDATA_WIDTH);
    constant C_RAMP_INCR        : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0) := incr_calc(C_AXIS_TDATA_WIDTH);

    signal ramp_data_exp        : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0) := (others => '0');
    signal error_tdata          : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal en                   : std_logic;

    type array_main_fsm is (idle, init_prbs, send_data, receive_data);
    signal fsm_gen              : array_main_fsm;
    signal fsm_chk              : array_main_fsm;

    signal cpt_transmit               : std_logic_vector(63 downto 0);
    signal cpt_timeout                : std_logic_vector(31 downto 0);
    signal cnt_keep                   : std_logic_vector(integer(ceil(log2(real(C_AXIS_TDATA_WIDTH / 8)))) downto 0);
    signal cnt_remaining_data_frame   : std_logic_vector(63 downto 0);
    signal cnt_remaining_data_to_send : std_logic_vector(63 downto 0);

    signal cnt_data_received    : std_logic_vector(63 downto 0);
    signal cnt_receive_time     : std_logic_vector(63 downto 0);

    signal internal_tlast       : std_logic;

    signal m_axis_tvalid_i      : std_logic;
    signal m_axis_tdata_i       : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);

    signal start_i              : std_logic;
    signal rst_prbs             : std_logic;

    signal s_axis_tvalid_i      : std_logic;
    signal tdata_error_i        : std_logic;

    signal random_i             : std_logic_vector(7 downto 0);

    signal random_signal        : std_logic;

    signal s_axis_tready_i      : std_logic;

    signal frame_size_random_16 : std_logic_vector(15 downto 0);
    signal frame_size_random    : std_logic_vector(15 downto 0);
    signal internal_frame_size  : std_logic_vector(63 downto 0);

    signal continuous_mode      : std_logic;

    signal stop_int             : std_logic;	

	function or_reduct(data_in : std_logic_vector) return std_logic is
		variable result : std_logic;
	begin
		for i in data_in'range loop
			if i = data_in'left then
				result := data_in(i);
			else
				result := result or data_in(i);
			end if;
		end loop;
		return result;
	end or_reduct;

	-- translates a number of valid bytes into a tkeep value
	-- Equivalent : 2**nb_of_data-1
	function count_to_tkeep(nb_of_data : in integer) return std_logic_vector is
		variable tkeep : std_logic_vector(C_AXIS_TDATA_WIDTH / 8 - 1 downto 0);
	begin
		for i in tkeep'range loop
			if i < nb_of_data then
				tkeep(i) := '1';
			else
				tkeep(i) := '0';
			end if;
		end loop;
		return tkeep;
	end count_to_tkeep;

	-- extends each bit of a tkeep signal on a byte to allow bit to bit comparisons
	function tkeep_to_bits(tkeep : in std_logic_vector) return std_logic_vector is
		variable tkeep_bits : std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
	begin
		for i in tkeep'range loop
			for j in i * 8 + 8 - 1 downto i * 8 loop
				tkeep_bits(j) := tkeep(i);
			end loop;
		end loop;
		return tkeep_bits;
	end tkeep_to_bits;

	function tkeep_to_count(tkeep : in std_logic_vector(C_AXIS_TDATA_WIDTH/8-1 downto 0)) return integer is
		variable i : integer range 0 to C_AXIS_TDATA_WIDTH / 8 - 1;
	begin
		for i in C_AXIS_TDATA_WIDTH / 8 - 1 downto 0 loop
			if tkeep(i) = '1' then
				return i + 1;
			end if;
		end loop;
		return 0;
	end;

begin

	gen_prbs : if (C_TYPE = "WO") generate

		----------------------------------------------      
		-- Instantiate the PRBS generator for VALID/READY
		----------------------------------------------  

		INST_PRBS_VALID_READY_GEN : UOE_PRBS_ANY
			GENERIC MAP(
				C_CHK_MODE    => FALSE,
				C_INV_PATTERN => FALSE,
				C_NBITS       => 8,
				C_INIT_VALUE  => 1
			)
			PORT MAP(
				RST      => rst,
				CLK      => clk,
				DATA_IN  => (others => '0'),
				EN       => '1',
				DATA_OUT => random_i
			);

		-- select bandwidth for GENERATOR
		proc_random : process(clk)
		begin
			if rising_edge(clk) then
				if random_i <= random_threshold then
					random_signal <= '1';
				else
					random_signal <= '0';
				end if;
			end if;
		end process proc_random;

		----------------------------------------------      
		-- Instantiate the PRBS generator for FRAME SIZE
		----------------------------------------------  
		INST_PRBS_FRAME_SIZE_GEN : UOE_PRBS_ANY
			GENERIC MAP(
				C_CHK_MODE    => FALSE,
				C_INV_PATTERN => FALSE,
				C_NBITS       => 16,
				C_INIT_VALUE  => 1
			)
			PORT MAP(
				RST      => rst,
				CLK      => clk,
				DATA_IN  => (others => '0'),
				EN       => '1',
				DATA_OUT => frame_size_random_16
			);

        frame_size_random   <= std_logic_vector(resize(unsigned(frame_size_random_16(integer(ceil(log2(real(C_FRAME_SIZE_MAX))))-1 downto 0)),16));
		--frame_size_random   <= frame_size_random_16;
		----------------------------------------------      
		-- Instantiate the PRBS generator for DATA
		----------------------------------------------  
        prbs_gen : if C_DATA_TYPE = "PRBS" generate
    		INST_PRBS_ANY_GEN : UOE_PRBS_ANY
    			GENERIC MAP(
    				C_CHK_MODE    => FALSE,
    				C_INV_PATTERN => FALSE,
    				C_NBITS       => C_AXIS_TDATA_WIDTH,
    				C_INIT_VALUE  => C_INIT_VALUE
    			)
    			PORT MAP(
    				RST      => rst_prbs,
    				CLK      => clk,
    				DATA_IN  => (others => '0'),
    				EN       => en,
    				DATA_OUT => m_axis_tdata
    			);
        end generate;
    	
    	ramp_gen : if 	C_DATA_TYPE = "RAMP" generate
            p_ramp : process(clk)
            begin
                if rising_edge(clk) then
                    if rst_prbs = '1' then
                        m_axis_tdata_i    <= C_RAMP_INIT;
                    else
                        if en = '1' then
                            m_axis_tdata_i    <= std_logic_vector(unsigned(m_axis_tdata_i)+unsigned(C_RAMP_INCR));
                        end if;
                    end if;
                end if;
            end process;
            m_axis_tdata    <= m_axis_tdata_i;
        end generate;

		--enable_data
		en            <= (m_axis_tvalid_i and m_axis_tready and random_signal);
		m_axis_tvalid <= m_axis_tvalid_i and random_signal;

		--not used signals
		s_axis_tready     <= '0';
		s_axis_tready_i   <= '0';
		s_axis_tvalid_i   <= '0';
		tdata_error       <= '0';
		cnt_data_received <= (others => '0');
		cnt_receive_time  <= (others => '0');
		error_tdata       <= (others => '0');
		tdata_error_i     <= '0';

		-- Outputs
		m_axis_tlast <= internal_tlast;
		m_axis_tkeep <= count_to_tkeep(to_integer(unsigned(cnt_keep)));

		proc_gen : process(clk)
		begin
			if rising_edge(clk) then
				if rst = '1' then
					m_axis_tvalid_i            <= '0';
					m_axis_tuser               <= (others => '0');
					cpt_transmit               <= (others => '0');
					cpt_timeout                <= (others => '0');
					transfert_time             <= (others => '0');
					end_of_axis_frame          <= '0';
					rst_prbs                   <= '1';
					start_i                    <= '0';
					link_error                 <= '0';
					fsm_gen                    <= idle;
					internal_tlast             <= '0';
					cnt_keep                   <= (others => '0');
					cnt_remaining_data_frame   <= (others => '0');
					cnt_remaining_data_to_send <= (others => '0');
					internal_frame_size        <= (others => '0');
					stop_int 				   <= '0';
					continuous_mode			   <= '0';
				else

					start_i <= start;

					-- select frame size
					if (frame_size_type = '0') then
						internal_frame_size <= std_logic_vector(resize(unsigned(frame_size), internal_frame_size'length));
					else
						-- use min/max threshold on frame_size
						if frame_size_random < std_logic_vector(to_unsigned(C_FRAME_SIZE_MIN, 16)) then
							-- min threshold
							internal_frame_size <= std_logic_vector(to_unsigned(C_FRAME_SIZE_MIN, internal_frame_size'length));
						elsif frame_size_random > std_logic_vector(to_unsigned(C_FRAME_SIZE_MAX, 16)) then
							-- max threshold
							internal_frame_size <= std_logic_vector(to_unsigned(C_FRAME_SIZE_MAX, internal_frame_size'length));
						else
							-- random threshold
							internal_frame_size <= std_logic_vector(resize(unsigned(frame_size_random), internal_frame_size'length));
						end if;
					end if;

					if (nb_data = std_logic_vector(to_unsigned(0,64))) then
						continuous_mode <= '1';
					else
						continuous_mode <= '0';
					end if;
					
					if (stop = '1') then
						stop_int <= '1';
					end if;

					case fsm_gen is

						when idle =>
							m_axis_tvalid_i   <= '0';
							cpt_transmit      <= (others => '0');
							cpt_timeout       <= (others => '0');
							end_of_axis_frame <= '0';
							internal_tlast    <= '0';
							--wait for start
							if start = '1' and start_i = '0' then
								rst_prbs       <= '0';
								link_error     <= '0';
								transfert_time <= (others => '0');

								fsm_gen <= init_prbs;
							else
								rst_prbs <= '1';
								fsm_gen  <= idle;
							end if;

						when init_prbs =>

							if (continuous_mode = '0') then

								if (internal_frame_size <= nb_data) then
									-- more than one complete frame
									if (internal_frame_size <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
										-- one data to send max
										cnt_keep                   <= std_logic_vector(resize(unsigned(internal_frame_size), cnt_keep'length));
										cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame
										cnt_remaining_data_to_send <= std_logic_vector(unsigned(nb_data) - unsigned(internal_frame_size));
										m_axis_tuser               <= internal_frame_size(31 downto 0);
										internal_tlast             <= '1';
									else
										-- more than one data to send
										cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
										cnt_remaining_data_frame   <= std_logic_vector(unsigned(internal_frame_size) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										cnt_remaining_data_to_send <= std_logic_vector(unsigned(nb_data) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										m_axis_tuser               <= internal_frame_size(31 downto 0);
										internal_tlast             <= '0';
									end if;
								else
									-- one incomplete frame
									if (nb_data <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
										-- one data to send max
										cnt_keep                   <= std_logic_vector(resize(unsigned(nb_data), cnt_keep'length));
										cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame 
										cnt_remaining_data_to_send <= (others => '0');
										m_axis_tuser               <= nb_data(31 downto 0);
										internal_tlast             <= '1';
									else
										-- more than one data to send
										cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
										cnt_remaining_data_frame   <= std_logic_vector(unsigned(nb_data) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										cnt_remaining_data_to_send <= std_logic_vector(unsigned(nb_data) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										m_axis_tuser               <= nb_data(31 downto 0);
										internal_tlast             <= '0';
									end if;
								end if;

							else
								-- more than one complete frame
								if (internal_frame_size <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
									-- one data to send max
									cnt_keep                   <= std_logic_vector(resize(unsigned(internal_frame_size), cnt_keep'length));
									cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame
									cnt_remaining_data_to_send <= std_logic_vector(unsigned(nb_data) - unsigned(internal_frame_size));
									m_axis_tuser               <= internal_frame_size(31 downto 0);
									internal_tlast             <= '1';
								else
									-- more than one data to send
									cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
									cnt_remaining_data_frame   <= std_logic_vector(unsigned(internal_frame_size) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
									cnt_remaining_data_to_send <= std_logic_vector(unsigned(nb_data) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
									m_axis_tuser               <= internal_frame_size(31 downto 0);
									internal_tlast             <= '0';
								end if;

							end if;

							-- load first PRB value
							m_axis_tvalid_i <= '1';

							-- counter for bandwidth
							cpt_transmit <= std_logic_vector(unsigned(cpt_transmit) + 1);
							cpt_timeout  <= std_logic_vector(unsigned(cpt_timeout) + 1);
							-- state mngt
							fsm_gen      <= send_data;

						when send_data =>

							if (continuous_mode = '0') then

							-- transmission time counter
							cpt_transmit <= std_logic_vector(unsigned(cpt_transmit) + 1);

							if (en = '1') then -- same as valid+ready 

								-- reset timeout counter
								cpt_timeout <= (others => '0');

								if (internal_tlast = '1') then
									-- end of frame

									if cnt_remaining_data_to_send = std_logic_vector(to_unsigned(0, 64)) then
										-- End of transfert --> go to idle
										cpt_transmit      <= (others => '0');
										end_of_axis_frame <= '1';
										m_axis_tvalid_i   <= '0';
                                        internal_tlast    <= '0';
										-- update results for bandwidth measure
										transfert_time <= cpt_transmit;

										fsm_gen <= idle;
									else
										-- start next frame
										if (internal_frame_size <= cnt_remaining_data_to_send) then
											-- complete frame
											if (internal_frame_size <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
												-- one data to send max
												cnt_keep                   <= std_logic_vector(resize(unsigned(internal_frame_size), cnt_keep'length));
												cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame
												cnt_remaining_data_to_send <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - unsigned(internal_frame_size));
												m_axis_tuser               <= internal_frame_size(31 downto 0);
												internal_tlast             <= '1';
											else
												-- more than one data to send
												cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
												cnt_remaining_data_frame   <= std_logic_vector(unsigned(internal_frame_size) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
												cnt_remaining_data_to_send <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
												m_axis_tuser               <= internal_frame_size(31 downto 0);
												internal_tlast             <= '0';
											end if;
										else
											-- incomplete frame
											if (cnt_remaining_data_to_send <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
												-- one data to send max
												cnt_keep                   <= std_logic_vector(resize(unsigned(cnt_remaining_data_to_send), cnt_keep'length));
												cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame 
												cnt_remaining_data_to_send <= (others => '0');
												m_axis_tuser               <= cnt_remaining_data_to_send(31 downto 0);
												internal_tlast             <= '1';
											else
												-- more than one data to send
												cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
												cnt_remaining_data_frame   <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
												cnt_remaining_data_to_send <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
												m_axis_tuser               <= cnt_remaining_data_to_send(31 downto 0);
												internal_tlast             <= '0';
											end if;
										end if;
									end if;
								else
									-- frame in progress ...
									if cnt_remaining_data_frame <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_remaining_data_frame'length)) then
										-- last data for the current frame
										cnt_keep                   <= std_logic_vector(resize(unsigned(cnt_remaining_data_frame), cnt_keep'length));
										cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame 
										cnt_remaining_data_to_send <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - unsigned(cnt_remaining_data_frame));
										internal_tlast             <= '1';
									else
										-- send new data
										cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
										cnt_remaining_data_frame   <= std_logic_vector(unsigned(cnt_remaining_data_frame) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										cnt_remaining_data_to_send <= std_logic_vector(unsigned(cnt_remaining_data_to_send) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										internal_tlast             <= '0';
									end if;
								end if;

							elsif (to_integer(unsigned(cpt_timeout)) = C_TIMEOUT) then
								-- timeout                
								link_error                 <= '1'; -- timeout when elapsed time is 16 times the required time to transmit the frame
								cpt_transmit               <= (others => '0');
								cnt_remaining_data_to_send <= (others => '0');
								cnt_keep                   <= (others => '0');
								cnt_remaining_data_frame   <= (others => '0');
								internal_tlast             <= '0';
								end_of_axis_frame          <= '1';
								fsm_gen                    <= idle;
								transfert_time             <= (others => '0');
								m_axis_tvalid_i            <= '0';
							else
								-- timout counter incrementation
								cpt_timeout <= std_logic_vector(unsigned(cpt_timeout) + 1);
							end if;
						else
							
							-- transmission time counter
							cpt_transmit <= (others=>'0');
							-- timeout counter
							cpt_timeout <= (others => '0');
							-- no bandwidth measurement
							transfert_time <= (others => '0');							

							if (en = '1') then -- same as valid+ready 

								if (internal_tlast = '1') then
									-- end of frame

									if (stop_int = '1') then
										-- End of transfert --> go to idle
										end_of_axis_frame <= '1';
										m_axis_tvalid_i   <= '0';
										
										stop_int <= '0';

										fsm_gen <= idle;
									else
										-- complete frame
										if (internal_frame_size <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, internal_frame_size'length))) then
											-- one data to send max
											cnt_keep                   <= std_logic_vector(resize(unsigned(internal_frame_size), cnt_keep'length));
											cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame
											m_axis_tuser               <= internal_frame_size(31 downto 0);
											internal_tlast             <= '1';
										else
											-- more than one data to send
											cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
											cnt_remaining_data_frame   <= std_logic_vector(unsigned(internal_frame_size) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
											m_axis_tuser               <= internal_frame_size(31 downto 0);
											internal_tlast             <= '0';
										end if;
									end if;
								else
									-- frame in progress ...
									if cnt_remaining_data_frame <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_remaining_data_frame'length)) then
										-- last data for the current frame
										cnt_keep                   <= std_logic_vector(resize(unsigned(cnt_remaining_data_frame), cnt_keep'length));
										cnt_remaining_data_frame   <= (others => '0'); -- all is sent in one frame 
										internal_tlast             <= '1';
									else
										-- send new data
										cnt_keep                   <= std_logic_vector(to_unsigned(C_AXIS_TDATA_WIDTH / 8, cnt_keep'length));
										cnt_remaining_data_frame   <= std_logic_vector(unsigned(cnt_remaining_data_frame) - to_unsigned(C_AXIS_TDATA_WIDTH / 8, 64));
										internal_tlast             <= '0';
									end if;
								end if;
							end if;							
							
						end if;
						when others =>
							transfert_time    <= (others => '0');
							end_of_axis_frame <= '0';
							rst_prbs          <= '1';
							link_error        <= '0';
							fsm_gen           <= idle;
					end case;
				end if;
			end if;
		end process proc_gen;

	end generate gen_prbs;

	chk_prbs : if (C_TYPE = "RO") generate

		----------------------------------------------      
		-- Instantiate the PRBS generator for VALID/READY
		----------------------------------------------  

		INST_PRBS_VALID_READY_CHK : UOE_PRBS_ANY
			GENERIC MAP(
				C_CHK_MODE    => FALSE,
				C_INV_PATTERN => FALSE,
				C_NBITS       => 8,
				C_INIT_VALUE  => 2
			)
			PORT MAP(
				RST      => rst,
				CLK      => clk,
				DATA_IN  => (others => '0'),
				EN       => '1',
				DATA_OUT => random_i
			);

		proc_random : process(clk)
		begin
			if rising_edge(clk) then
				if random_i <= random_threshold then
					random_signal <= '1';
				else
					random_signal <= '0';
				end if;
			end if;
		end process proc_random;

		----------------------------------------------      
		-- Instantiate the PRBS checker
		----------------------------------------------
		prbs_check_gen : if C_DATA_TYPE = "PRBS" generate     
    		INST_PRBS_ANY_CHK : UOE_PRBS_ANY
    			GENERIC MAP(
    				C_CHK_MODE    => FALSE, -- False here so if there is an error (which can happen when a tkeep is not full) it does not affect the next generated values
    				C_INV_PATTERN => FALSE,
    				C_NBITS       => C_AXIS_TDATA_WIDTH,
    				C_INIT_VALUE  => C_INIT_VALUE
    			)
    			PORT MAP(
    				RST      => rst_prbs,
    				CLK      => clk,
    				DATA_IN  => s_axis_tdata,
    				EN       => s_axis_tvalid_i,
    				DATA_OUT => error_tdata
    			);
    	end generate;

		ramp_check_gen : if C_DATA_TYPE = "RAMP" generate
    		p_ramp_check : process(clk)
    		begin
    		    if rising_edge(clk) then
    		        if rst_prbs = '1' then
    		            ramp_data_exp    <= C_RAMP_INIT;
                    else
                        if s_axis_tvalid_i = '1' then
                            ramp_data_exp    <= std_logic_vector(unsigned(ramp_data_exp)+ unsigned(C_RAMP_INCR));
                        end if;
                    end if;
    		    end if;
    		end process;
            error_tdata       <= s_axis_tdata xor ramp_data_exp;
        end generate;

		--not used signals
		m_axis_tdata               <= (others => '0');
		m_axis_tkeep               <= (others => '0');
		m_axis_tvalid              <= '0';
		m_axis_tlast               <= '0';
		s_axis_tvalid_i            <= s_axis_tvalid and random_signal;
		s_axis_tready              <= s_axis_tready_i and random_signal;
		en                         <= '0';
		m_axis_tvalid_i            <= '0';
		cpt_transmit               <= (others => '0');
		cnt_keep                   <= (others => '0');
		cnt_remaining_data_frame   <= (others => '0');
		cnt_remaining_data_to_send <= (others => '0');
		m_axis_tuser               <= (others => '0');
		internal_tlast             <= '0';
		frame_size_random          <= (others => '0');
		internal_frame_size        <= (others => '0');

		tdata_error <= tdata_error_i;

		proc_chk : process(clk)
		begin
			if rising_edge(clk) then
				if rst = '1' then
					s_axis_tready_i   <= '0';
					tdata_error_i     <= '0';
					transfert_time    <= (others => '0');
					fsm_chk           <= idle;
					rst_prbs          <= '1';
					start_i           <= '0';
					cnt_data_received <= (others => '0');
					cnt_receive_time  <= (others => '0');
					cpt_timeout       <= (others => '0');
					end_of_axis_frame <= '0';
					link_error        <= '0';
					stop_int 				   <= '0';
					continuous_mode			   <= '0';					
				else
					-- 1 cc for checker calc
					start_i <= start;
					
					if (nb_data = std_logic_vector(to_unsigned(0,64))) then
						continuous_mode <= '1';
					else
						continuous_mode <= '0';
					end if;
					
					if (stop = '1') then
						stop_int <= '1';
					end if;					

					case fsm_chk is
						when idle =>
							cnt_receive_time  <= (others => '0');
							cpt_timeout       <= (others => '0');
							end_of_axis_frame <= '0';
							s_axis_tready_i   <= '0';
							--wait for start
							if start = '1' and start_i = '0' then
								rst_prbs      <= '0';
								tdata_error_i <= '0';
								link_error    <= '0';
								fsm_chk       <= init_prbs;
							else
								rst_prbs <= '1';
								fsm_chk  <= idle;
							end if;

						when init_prbs =>
							s_axis_tready_i <= '1';
							cpt_timeout     <= std_logic_vector(unsigned(cpt_timeout) + 1);
							fsm_chk         <= receive_data;

						when receive_data =>
						if (continuous_mode = '0') then
							-- Data check
							if (s_axis_tvalid_i = '1' and s_axis_tready_i = '1') then
								tdata_error_i     <= or_reduct(error_tdata and tkeep_to_bits(s_axis_tkeep)) or tdata_error_i;
								cnt_data_received <= std_logic_vector(unsigned(cnt_data_received) + to_unsigned(tkeep_to_count(s_axis_tkeep), cnt_data_received'length));
								if cnt_receive_time = std_logic_vector(to_unsigned(0, cnt_receive_time'length)) then
									cnt_receive_time <= std_logic_vector(unsigned(cnt_receive_time) + 1); -- begin time counter incrementation when first data is received.
								end if;
								cpt_timeout       <= (others => '0');
							else
								cpt_timeout <= std_logic_vector(unsigned(cpt_timeout) + 1);
							end if;

							-- FSM Management --
							-- If all expected data has been received
							if (s_axis_tvalid_i = '1' and s_axis_tready_i = '1' and std_logic_vector(unsigned(cnt_data_received) + to_unsigned(tkeep_to_count(s_axis_tkeep), cnt_data_received'length)) = nb_data) then -- if we don't take the current tkeep into consideration, tready is deasserted one cc too late (which is not necessarily a problem)

								-- s_axis_tready_i       <= '0';
								link_error        <= '0';
								cnt_data_received <= (others => '0');
								cnt_receive_time  <= (others => '0');
								transfert_time    <= std_logic_vector(unsigned(cnt_receive_time) + 1); -- +1 because the last cc is not yet taken into account in cnt_receive_time 

								end_of_axis_frame <= '1';
								s_axis_tready_i   <= '0';
								fsm_chk           <= idle;

							-- or if timeout
							elsif cpt_timeout = std_logic_vector(to_unsigned(C_TIMEOUT, cpt_timeout'length)) then
								end_of_axis_frame <= '1';
								s_axis_tready_i   <= '0';
								link_error        <= '1';
								cnt_receive_time  <= (others => '0');
								cnt_data_received <= (others => '0');
								transfert_time    <= std_logic_vector(unsigned(cnt_receive_time) + 1);
								fsm_chk           <= idle;
							-- Receiving data
							else
								link_error <= '0';
								if cnt_receive_time > std_logic_vector(to_unsigned(0, cnt_receive_time'length)) then -- if first data has been received, increment at each clock cycle
									cnt_receive_time <= std_logic_vector(unsigned(cnt_receive_time) + 1); -- Time counter for throughput calculation
								end if;

								end_of_axis_frame <= '0';
								s_axis_tready_i   <= '1';
								fsm_chk           <= receive_data;

							end if;
						else
							-- Data check
							if (s_axis_tvalid_i = '1' and s_axis_tready_i = '1') then
								tdata_error_i     <= or_reduct(error_tdata and tkeep_to_bits(s_axis_tkeep)) or tdata_error_i;
								cnt_data_received <= std_logic_vector(unsigned(cnt_data_received) + to_unsigned(tkeep_to_count(s_axis_tkeep), cnt_data_received'length));							
							end if;

							-- FSM Management --
							-- If all expected data has been received
							if (s_axis_tvalid_i = '1' and s_axis_tready_i = '1' and s_axis_tlast = '1' and stop_int = '1') then -- if we don't take the current tkeep into consideration, tready is deasserted one cc too late (which is not necessarily a problem)
								stop_int <= '0';
								end_of_axis_frame <= '1';
								s_axis_tready_i   <= '0';
								fsm_chk           <= idle;
							-- Receiving data
							else
								end_of_axis_frame <= '0';
								s_axis_tready_i   <= '1';
								fsm_chk           <= receive_data;
							end if;							
						end if;
						when others =>
							rst_prbs      <= '0';
							tdata_error_i <= '0';
							link_error    <= '0';
							fsm_chk       <= idle;
					end case;
				end if;
			end if;
		end process proc_chk;

	end generate chk_prbs;

	nu_prbs : if (C_TYPE = "NU") generate

		m_axis_tdata      <= (others => '0');
		m_axis_tvalid     <= '0';
		m_axis_tlast      <= '0';
		s_axis_tready     <= '0';
		tdata_error       <= '0';
		transfert_time    <= (others => '0');
		end_of_axis_frame <= '0';
		tdata_error       <= '0';
		link_error        <= '0';

	end generate nu_prbs;

end rtl;