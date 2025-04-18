library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
---------------------------------------------------------------------------------------------------
entity shmul_acu_mmio_peripheral_template is
	generic (
		metastable_filter_bypass_acu:			boolean := false;
		metastable_filter_bypass_recover_fsm_n:	boolean := true;
		generate_intr:							boolean := false;
		operand_address: 						integer range 0 to 65535 := 0;
		product_1_address: 						integer range 0 to 65535 := 1;
		product_2_address: 						integer range 0 to 65535 := 2;
		product_3_address: 						integer range 0 to 65535 := 3;
		product_4_address: 						integer range 0 to 65535 := 4;
		ready_address: 							integer range 0 to 65535 := 5;
		intr_en_address: 						integer range 0 to 65535 := 6;
		operand_size:                           integer range 1 to 32 := 32
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
			
		-- FSM error interface
		invalid_state_error:		out	std_logic;
		recover_fsm_n:				in	std_logic;
		recover_fsm_n_ack:			out	std_logic
	);
end entity shmul_acu_mmio_peripheral_template;
---------------------------------------------------------------------------------------------------
architecture rtl of shmul_acu_mmio_peripheral_template is

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

	signal interrupt_enable:     		    std_logic;
	signal ready_intr_rqst_rising:			std_logic;
	signal ready_d:							std_logic;
	
	type state_t is (
		idle,
		write_operand, write_intr_en, send_start, 
		read_product_1, read_product_2, read_product_3, read_product_4, read_ready,
		wait_for_deassert_strobes, wait_for_ready,
		error);
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
	signal ready:							std_logic;
	signal start:							std_logic;
	signal op_1:							std_logic_vector (operand_size-1 downto 0);
	signal op_2:							std_logic_vector (operand_size-1 downto 0);
	signal product:							std_logic_vector (63 downto 0);

	signal operand_counter: integer range 1 to 4;
	signal x: std_logic;
	
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
		user_logic_intr_output <= ready_intr_rqst_rising;
		x <= user_logic_intr_output when interrupt_enable = '1' else '0';
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


		process ( clk, as_reset_n )
		begin
			if ( as_reset_n = '0' ) then
				ready_d <= '0';
			elsif ( rising_edge(clk) ) then
				ready_d <= ready;
			end if;
		end process;
		ready_intr_rqst_rising <= ready and not ready_d;
		
	end block;
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	L_LOCAL_ADDRESS_DECODER: block
	begin
		cs <= '1' when (unsigned(address_from_acu) = operand_address or
						unsigned(address_from_acu) = product_1_address or
						unsigned(address_from_acu) = product_2_address or
						unsigned(address_from_acu) = product_3_address or
						unsigned(address_from_acu) = product_4_address or
						unsigned(address_from_acu) = ready_address or
						unsigned(address_from_acu) = intr_en_address) else '0';
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
			op_1 <= (others => '0');
			op_2 <= (others => '0');
			operand_counter <= 1;
			
		elsif ( rising_edge(clk) ) then
			case state is
				when idle	=>	s_ready_2_acu <= '1';
								
								-- Handle ACU writes
								if ( write_strobe_from_acu_internal = '1' and cs = '1' ) then
									
									s_ready_2_acu <= '0';
									
									if ( unsigned(address_from_acu) = operand_address ) then
										state <= write_operand;
									elsif ( unsigned(address_from_acu) = intr_en_address ) then
										state <= write_intr_en;
									else
										state <= wait_for_deassert_strobes;
									end if;
									
								end if;
								
								-- Handle ACU reads
								if ( read_strobe_from_acu_internal = '1' and cs = '1') then
									
									s_ready_2_acu <= '0';
									
									if ( unsigned(address_from_acu) = product_1_address ) then
										state <= read_product_1;
									elsif ( unsigned(address_from_acu) = product_2_address ) then
										state <= read_product_2;
									elsif ( unsigned(address_from_acu) = product_3_address ) then
										state <= read_product_3;
									elsif ( unsigned(address_from_acu) = product_4_address ) then
										state <= read_product_4;
									elsif ( unsigned(address_from_acu) = ready_address ) then
										state <= read_ready;									
									else
										state <= wait_for_deassert_strobes;
									end if;
									
								end if;
				
				----------------------------------------------------------------------------------------------
				
				when write_operand	=>	
				if(operand_size < 17) then
					case operand_counter is
						when 1 => op_1 <= data_from_acu(operand_size-1 downto 0);
								  operand_counter <= operand_counter + 1;
						          state <= wait_for_deassert_strobes;
						when 2 => op_2 <= data_from_acu(operand_size-1 downto 0);
						          operand_counter <= 1;
								  state <= send_start;
						when others => state <= wait_for_deassert_strobes;
					end case;
				else 
					case operand_counter is
						when 1 => op_1 <= op_1(operand_size-1 downto 16) & data_from_acu;
								  operand_counter <= operand_counter + 1;
						          state <= wait_for_deassert_strobes;
						when 2 => op_1 <= data_from_acu(operand_size-17 downto 0) & op_1(15 downto 0);
								  operand_counter <= operand_counter + 1;
								  state <= wait_for_deassert_strobes;
						when 3 => op_2 <= op_2(operand_size-1 downto 16) & data_from_acu;
								   operand_counter <= operand_counter + 1;
						           state <= wait_for_deassert_strobes;
						when 4 => op_2 <= data_from_acu(operand_size-17 downto 0) & op_2(15 downto 0);
						          operand_counter <= 1;
								  state <= send_start;
						when others => state <= wait_for_deassert_strobes;
					end case;
					end if;
									
				when send_start	=>	start <= '1';
									state <= wait_for_ready;
									
				when wait_for_ready	=>	if(ready = '0') then
											start <= '0';
											state <= wait_for_deassert_strobes;
										end if;	
									
				when read_ready			=>	s_data_2_acu(0) <= ready;
											state <= wait_for_deassert_strobes;
									
				when read_product_1		=>	s_data_2_acu <= product(15 downto 0);
											state <= wait_for_deassert_strobes;

				when read_product_2		=>	s_data_2_acu <= product(31 downto 16);
											state <= wait_for_deassert_strobes;
									
				when read_product_3		=>	s_data_2_acu <= product(47 downto 32);
											state <= wait_for_deassert_strobes;

				when read_product_4		=>	s_data_2_acu <= product(63 downto 48);
											state <= wait_for_deassert_strobes;
				
				when write_intr_en      =>  interrupt_enable <= data_from_acu(0);
				                            state <= wait_for_deassert_strobes;
				
				----------------------------------------------------------------------------------------------
				
				when wait_for_deassert_strobes	=>	if ( read_strobe_from_acu_internal = '0' and write_strobe_from_acu_internal = '0' ) then
														state <= idle;
													end if;
													
				----------------------------------------------------------------------------------------------
				
				when error	=>	-- reset all
								s_ready_2_acu <= '0';
								s_data_2_acu <= (others => '0');
			                    operand_counter <= 1;
								
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
	
	L_USER_LOGIC:    entity work.shmul(rtl)
					 generic map(
						operand_size => operand_size
					)
					 port map(
						clk => clk,
						as_reset_n => as_reset_n,
						start => start,
						recover_fsm_n => recover_fsm_n,
						op_1 => op_1,
						op_2 => op_2,
						product => product,
						ready => ready,
						user_fsm_invalid_state_error => user_fsm_invalid_state_error
					);
	
	--------------------------------------------------------
	--------------------------------------------------------
	--------------------------------------------------------
	
	invalid_state_error <= 	adapter_invalid_state_error or user_fsm_invalid_state_error;

end architecture rtl;
---------------------------------------------------------------------------------------------------