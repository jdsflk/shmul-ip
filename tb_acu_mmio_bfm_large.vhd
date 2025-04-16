library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

---------------------------------------------------------------------------------------------------
entity tb_acu_mmio_bfm_large is
end entity tb_acu_mmio_bfm_large;
---------------------------------------------------------------------------------------------------
architecture behavior of tb_acu_mmio_bfm_large is

	signal generate_read_cycle:						std_logic	 					:= '0';
	signal generate_write_cycle:					std_logic						:= '0';
	signal address:									std_logic_vector (15 downto 0) 	:= (others => '0');
	signal data_2_write:							std_logic_vector (15 downto 0)	:= (others => '0');
	signal data_read:								std_logic_vector (15 downto 0);
	signal busy:									std_logic;
	signal interrupt_received_and_acknowledged:		std_logic;
	
	signal clk_bfm:									std_logic						:= '0';
	signal clk_uart:								std_logic						:= '1';
	signal raw_reset_n:								std_logic						:= '1';
	signal uart_intr_rqst:							std_logic;
	signal acu_intr_ack:							std_logic;
	signal acu_write_strobe:						std_logic;
	signal acu_read_strobe:							std_logic;
	signal uart_ready:								std_logic;
	signal acu_address:								std_logic_vector (15 downto 0);
	signal acu_data:								std_logic_vector (15 downto 0);
	signal uart_data:								std_logic_vector (15 downto 0);
	signal concat:									std_logic_vector (63 downto 0);

	signal largenum1: std_logic_vector(31 downto 0);
	signal largenum2: std_logic_vector(31 downto 0);
	signal ready_val: std_logic;
	signal pos_pos_number: std_logic_vector(63 downto 0)							:= X"0000020BDE736400";
	signal pos_neg_number: std_logic_vector(63 downto 0)							:= X"FFFFFDF4218C9C00";
	signal neg_neg_number: std_logic_vector(63 downto 0)							:= X"0000020BDE736400";

begin

	L_CLOCK_BFM: process
	begin
		wait for 32 ns;
		loop
			wait for 10 ns;
			clk_bfm <= not clk_bfm;
		end loop;
	end process;

	L_CLOCK_UART: process
	begin
		wait for 25 ns;
		clk_uart <= not clk_uart;
	end process;

	L_ACU_MMIO_BFM:	entity work.acu_mmio_bfm(behavior)
						port map (
							generate_read_cycle						=> generate_read_cycle,
							generate_write_cycle					=> generate_write_cycle,
							address									=> address,
							data_2_write							=> data_2_write,
							data_read								=> data_read,
							busy									=> busy,
							interrupt_received_and_acknowledged		=> interrupt_received_and_acknowledged,
							clk										=> clk_bfm,
							intr_rqst								=> uart_intr_rqst,
							intr_ack								=> acu_intr_ack,
							write_strobe							=> acu_write_strobe,
							read_strobe								=> acu_read_strobe,
							dmem_ready								=> uart_ready,
							address_2_dmem							=> acu_address,
							data_from_dmem							=> uart_data,
							data_2_dmem								=> acu_data
						);
	

	L_ACU_MMIO_SHMUL_LARGE: entity work.shmul_acu_mmio_peripheral_template(rtl)
	generic map(
	   metastable_filter_bypass_acu => false,
	   metastable_filter_bypass_recover_fsm_n => true,
	   generate_intr => true,
	   operand_address => 8,
	   product_1_address => 9,
	   product_2_address => 10,
	   product_3_address => 11,
	   product_4_address => 12,
	   ready_address => 13,
	   intr_en_address => 14,
	   operand_size => 24
    )
	port map(
	   clk => clk_uart,
	   raw_reset_n => raw_reset_n,
	   read_strobe_from_acu => acu_read_strobe,
	   write_strobe_from_acu => acu_write_strobe,
	   ready_2_acu => uart_ready,
	   address_from_acu => acu_address,
	   data_from_acu => acu_data,
	   data_2_acu => uart_data,
	   intr_rqst => uart_intr_rqst,
	   intr_ack => acu_intr_ack,
	   invalid_state_error => open,
	   recover_fsm_n => '1',
	   recover_fsm_n_ack => open
    );

	L_TEST_SEQUENCE: process
	begin
	
		wait for 100 ns;
		raw_reset_n <= '0';
		wait for 100 ns;
		raw_reset_n <= '1';
		wait for 1 us;


		L_TEST_POS_POS_LARGE:
		largenum1 <= std_logic_vector(to_signed(1500000, 32));
		largenum2 <= std_logic_vector(to_signed(1500000, 32));
		
		wait for 100 ns;
		
		address <= X"000E";		--intr off
		data_2_write <= X"0000";
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 also
		data_2_write <= largenum1(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 felso
		data_2_write <= largenum1(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 also
		data_2_write <= largenum2(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 felso
		data_2_write <= largenum2(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 5 us;

		address <= X"000D";		-- ready?
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		ready_val <= data_read(0);
		wait for 50 ns;
		assert ready_val = '1' report "Ready is not 1" severity WARNING;

		wait for 100 ns;
		address <= X"0009";		-- product_1
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(15 downto 0) <= data_read;

		wait for 100 ns;
		address <= X"000A";		-- product_2
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(31 downto 16) <= data_read;

		wait for 100 ns;
		address <= X"000B";		-- product_3
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(47 downto 32) <= data_read;

		wait for 100 ns;
		address <= X"000C";		-- product_4
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';

		concat(63 downto 48) <= data_read;
		wait for 100 ns;

		assert concat = pos_pos_number report "Large positive-positive multiplication failed" severity FAILURE;
		assert concat(63) = '0' report "Positive times positive should be positive" severity WARNING;
	
		L_TEST_POS_NEG_LARGE:
		wait for 100 ns;
		largenum1 <= std_logic_vector(to_signed(1500000, 32));
		largenum2 <= std_logic_vector(to_signed(-1500000, 32));
		
		wait for 100 ns;
		address <= X"000E";		--intr on
		data_2_write <= X"0001";
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 also
		data_2_write <= largenum1(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 felso
		data_2_write <= largenum1(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 also
		data_2_write <= largenum2(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 felso
		data_2_write <= largenum2(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 5 us;

		address <= X"000D";		-- ready?
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		ready_val <= data_read(0);
		wait for 50 ns;
		assert ready_val = '1' report "Ready is not 1" severity WARNING;

		wait for 100 ns;
		address <= X"0009";		-- product_1
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(15 downto 0) <= data_read;

		wait for 100 ns;
		address <= X"000A";		-- product_2
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(31 downto 16) <= data_read;

		wait for 100 ns;
		address <= X"000B";		-- product_3
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(47 downto 32) <= data_read;

		wait for 100 ns;
		address <= X"000C";		-- product_4
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';

		concat(63 downto 48) <= data_read;
		wait for 100 ns;

		assert concat = pos_neg_number report "Large positive-negative multiplication failed" severity FAILURE;
		assert concat(63) = '1' report "Positive times negative should be negative" severity WARNING;
	
		L_TEST_NEG_POS_LARGE:
		wait for 100 ns;
		largenum1 <= std_logic_vector(to_signed(-1500000, 32));
		largenum2 <= std_logic_vector(to_signed(1500000, 32));
		wait for 100 ns;

		address <= X"0008";		-- op 1 also
		data_2_write <= largenum1(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 felso
		data_2_write <= largenum1(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 also
		data_2_write <= largenum2(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 felso
		data_2_write <= largenum2(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 5 us;

		address <= X"000D";		-- ready?
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		ready_val <= data_read(0);
		wait for 50 ns;
		assert ready_val = '1' report "Ready is not 1" severity WARNING;

		wait for 100 ns;
		address <= X"0009";		-- product_1
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(15 downto 0) <= data_read;

		wait for 100 ns;
		address <= X"000A";		-- product_2
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(31 downto 16) <= data_read;

		wait for 100 ns;
		address <= X"000B";		-- product_3
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(47 downto 32) <= data_read;

		wait for 100 ns;
		address <= X"000C";		-- product_4
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';

		concat(63 downto 48) <= data_read;
		wait for 100 ns;

		assert concat = pos_neg_number report "Large negative-positive multiplication failed" severity FAILURE;
		assert concat(63) = '1' report "Negative times positive should be positive" severity WARNING;

		L_TEST_NEG_NEG_LARGE:
		wait for 100 ns;
		largenum1 <= std_logic_vector(to_signed(-1500000, 32));
		largenum2 <= std_logic_vector(to_signed(-1500000, 32));
		
		wait for 100 ns;
		address <= X"0008";		-- op 1 also
		data_2_write <= largenum1(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 1 felso
		data_2_write <= largenum1(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 also
		data_2_write <= largenum2(15 downto 0);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 100 ns;
		address <= X"0008";		-- op 2 felso
		data_2_write <= largenum2(31 downto 16);
		generate_write_cycle <= '1';
		wait until falling_edge(busy);
		generate_write_cycle <= '0';

		wait for 5 us;

		address <= X"000D";		-- ready?
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		ready_val <= data_read(0);
		wait for 50 ns;
		assert ready_val = '1' report "Ready is not 1" severity WARNING;

		wait for 100 ns;
		address <= X"0009";		-- product_1
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(15 downto 0) <= data_read;

		wait for 100 ns;
		address <= X"000A";		-- product_2
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(31 downto 16) <= data_read;

		wait for 100 ns;
		address <= X"000B";		-- product_3
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';
		concat(47 downto 32) <= data_read;

		wait for 100 ns;
		address <= X"000C";		-- product_4
		generate_read_cycle <= '1';
		wait until falling_edge(busy);
		generate_read_cycle <= '0';

		concat(63 downto 48) <= data_read;
		wait for 100 ns;

		assert concat = pos_pos_number report "Large negative-negative multiplication failed" severity FAILURE;
		assert concat(63) = '0' report "Negative times negative should be positive" severity WARNING;
		
		

		wait;
	end process;

end architecture behavior;
---------------------------------------------------------------------------------------------------