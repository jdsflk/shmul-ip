library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
---------------------------------------------------------------------------------------------------
entity acu_mmio_peripheral_template is
	generic (
		metastable_filter_bypass_acu:			boolean;
		metastable_filter_bypass_recover_fsm_n:	boolean;
		generate_intr:							boolean;
		my_address: 							integer range 0 to 65535
	);
	
	port (
		clk:						in	std_logic;
		raw_reset_n:				in	std_logic;
		
		-- ACU memory-mapped I/O interface
		read_strobe_from_acu:		in	std_logic;
		write_strobe_from_acu:		in	std_logic;
		ready_2_acu:				out	std_logic;
		address_from_acu:			in	std_logic_vector (15 downto 0);
		data_from_acu:				in	std_logic_vector (15 downto 0);
		data_2_acu:					out	std_logic_vector (15 downto 0);
		
		-- ACU interrupt interface
		intr_rqst:					out	std_logic;
		intr_ack:					in	std_logic;
		
		-- User logic external interface
		enable_intr: 				in boolean;
		-- ...
		-- ...
		-- ...
		
		-- FSM error interface
		invalid_state_error:		out	std_logic;
		recover_fsm_n:				in	std_logic;
		recover_fsm_n_ack:			out	std_logic
	);
end entity acu_mmio_peripheral_template;
---------------------------------------------------------------------------------------------------
architecture rtl of acu_mmio_peripheral_template is

	-- Reset synchronizer resources
	signal ff_reset_n:						std_logic;
	signal as_reset_n:						std_logic;
		
	-- Metastable filter resources	
	signal ff_write_strobe_from_acu:		std_logic;
	signal write_strobe_from_acu_filtered:	std_logic;
	signal write_strobe_from_acu_internal:	std_logic;
	signal ff_read_strobe_from_acu:			std_logic;
	signal read_strobe_from_acu_filtered:	std_logic;
	signal read_strobe_from_acu_internal:	std_logic;
	signal ff_recover_fsm_n:				std_logic;
	signal recover_fsm_n_filtered:			std_logic;
	signal recover_fsm_n_internal:			std_logic;
	signal ff_intr_ack:						std_logic;
	signal intr_ack_filtered:				std_logic;
	signal intr_ack_internal:				std_logic;
	
	-- Interrupt generation resources
	signal user_intr_rqst:					std_logic;
	signal user_intr_rqst_d:				std_logic;
	signal user_intr_rqst_rising:			std_logic;
	
	type state_t is (
		idle,
		write_1, write_2, write_3,
		read_1, read_2, read_3,
		wait_for_deassert_strobes,
		error
	);
	signal state: state_t;
	attribute syn_preserve: boolean;
	attribute syn_preserve of state:signal is true;
	
	signal cs:								std_logic;
	signal s_data_2_acu:					std_logic_vector (15 downto 0);
	signal s_ready_2_acu:					std_logic;
	signal adapter_invalid_state_error:		std_logic;
	
	-- User logic internal interface signals
	signal user_fsm_invalid_state_error:	std_logic;
	signal user_logic_intr_output:			std_logic;
	-- ...
	-- ...
	-- ...
	
begin
	
	-- Reset circuitry: Active-LOW asynchronous assert, synchronous deassert with meta-stable filter.
	L_RESET_CIRCUITRY:	process ( clk, raw_reset_n )
	begin
		if ( raw_reset_n = '0' ) then
			ff_reset_n <= '0';
			as_reset_n <= '0';
		elsif ( rising_edge(clk) ) then
			ff_reset_n <= '1';
			as_reset_n <= ff_reset_n;
		end if;
	end process;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_METASTBLE_FILTER_BLOCK: process ( clk, as_reset_n )
	begin
		if ( as_reset_n = '0' ) then
			ff_write_strobe_from_acu <= '0';
			write_strobe_from_acu_filtered <= '0';
			ff_read_strobe_from_acu <= '0';
			read_strobe_from_acu_filtered <= '0';
			ff_recover_fsm_n <= '1';
			recover_fsm_n_filtered <= '1';
			ff_intr_ack <= '0';
			intr_ack_filtered <= '0';
		elsif ( rising_edge(clk) ) then
			ff_write_strobe_from_acu <= write_strobe_from_acu;
			write_strobe_from_acu_filtered <= ff_write_strobe_from_acu;
			ff_read_strobe_from_acu <= read_strobe_from_acu;
			read_strobe_from_acu_filtered <= ff_read_strobe_from_acu;
			ff_recover_fsm_n <= recover_fsm_n;
			recover_fsm_n_filtered <= ff_recover_fsm_n;
			ff_intr_ack <= intr_ack;
			intr_ack_filtered <= ff_intr_ack;
		end if;
	end process;
	
	L_METASTABLE_FILTER_BYPASS: block
	begin
		write_strobe_from_acu_internal <= write_strobe_from_acu when metastable_filter_bypass_acu = true else write_strobe_from_acu_filtered;
		read_strobe_from_acu_internal <= read_strobe_from_acu when metastable_filter_bypass_acu = true else read_strobe_from_acu_filtered;
		recover_fsm_n_internal <= recover_fsm_n when metastable_filter_bypass_recover_fsm_n = true else recover_fsm_n_filtered;
		intr_ack_internal <= intr_ack when metastable_filter_bypass_acu = true else intr_ack_filtered;
	end block;
	
	L_METASTABLE_FILTER_ACKNOWLEDGE: block
	begin
		recover_fsm_n_ack <= recover_fsm_n_internal;
	end block;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_INTR_GENERATION: block
	begin
		x <= user_logic_intr_output when enable_intr = true else '0';
		user_intr_rqst <= x when generate_intr = true else '0';
		
		process ( clk, as_reset_n )
		begin
			if ( as_reset_n = '0' ) then
				user_intr_rqst_d <= '0';
				intr_rqst <= '0';
			elsif ( rising_edge(clk) ) then
				user_intr_rqst_d <= user_intr_rqst;
				
				if ( intr_ack_internal = '1' ) then
					intr_rqst <= '0';
				elsif ( user_intr_rqst_rising = '1' ) then
					intr_rqst <= '1';
				end if;
				
			end if;
		end process;
		user_intr_rqst_rising <= user_intr_rqst and not user_intr_rqst_d;
		
	end block;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_LOCAL_ADDRESS_DECODER: block
	begin
		cs <= '1' when (unsigned(address_from_acu) = my_address_1 or
						unsigned(address_from_acu) = my_address_2 or
						unsigned(address_from_acu) = my_address_3) else '0';
		ready_2_acu <= s_ready_2_acu when cs = '1' else '0';
		data_2_acu <= s_data_2_acu when cs = '1' else (others => '0');
	end block;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_ACU_MMIO_PERIPHERAL_ADAPTER: process ( clk, as_reset_n )
	begin
		if ( as_reset_n = '0' ) then
			state <= idle;
			s_ready_2_acu <= '0';
			s_data_2_acu <= (others => '0');
			adapter_invalid_state_error <= '0';
			
			-- ...
			-- ...
			-- ...
			
		elsif ( rising_edge(clk) ) then
			case state is
				when idle	=>	s_ready_2_acu <= '1';
								
								-- Handle ACU writes
								if ( write_strobe_from_acu_internal = '1' and cs = '1' ) then
									
									s_ready_2_acu <= '0';
									
									if ( unsigned(address_from_acu) = my_address_1 ) then
										state <= write_1;
									elsif ( unsigned(address_from_acu) = my_address_2 ) then
										state <= write_2;
									elsif ( unsigned(address_from_acu) = my_address_3 ) then
										state <= write_3;
									else
										state <= wait_for_deassert_strobes;
									end if;
									
								end if;
								
								-- Handle ACU reads
								if ( read_strobe_from_acu_internal = '1' and cs = '1') then
									
									s_ready_2_acu <= '0';
									
									if ( unsigned(address_from_acu) = my_address_1 ) then
										state <= read_1;
									elsif ( unsigned(address_from_acu) = my_address_2 ) then
										state <= read_2;
									elsif ( unsigned(address_from_acu) = my_address_3 ) then
										state <= read_3;
									else
										state <= wait_for_deassert_strobes;
									end if;
									
								end if;
				
				----------------------------------------------------------------------------------------------
				
				when write_1	=>	-- ...
									-- ...
									-- ...
									
				when write_2	=>	-- ...
									-- ...
									-- ...
									
				when write_3	=>	-- ...
									-- ...
									-- ...
									
				when read_1		=>	-- ...
									-- ...
									-- ...
									
				when read_2		=>	-- ...
									-- ...
									-- ...
									
				when read_3		=>	-- ...
									-- ...
									-- ...
				
				----------------------------------------------------------------------------------------------
				
				when wait_for_deassert_strobes	=>	if ( read_strobe_from_acu_internal = '0' and write_strobe_from_acu_internal = '0' ) then
														state <= idle;
													end if;
													
				----------------------------------------------------------------------------------------------
				
				when error	=>	-- reset all
								s_ready_2_acu <= '0';
								s_data_2_acu <= (others => '0');
								-- ...
								-- ...
								-- ...
								
								if ( recover_fsm_n_internal = '0' ) then
									adapter_invalid_state_error <= '0';
									state <= idle;
								end if;
								
				when others	=>	adapter_invalid_state_error <= '1';
								state <= error;
			end case;
		end if;
	end process;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_USER_LOGIC:	-- ...
					-- ...
					-- ...
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	invalid_state_error <= 	adapter_invalid_state_error or user_fsm_invalid_state_error;

end architecture rtl;
---------------------------------------------------------------------------------------------------