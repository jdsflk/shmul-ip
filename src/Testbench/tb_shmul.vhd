library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_shmul is
end entity tb_shmul;

architecture bhv of tb_shmul is

  signal clk                          : std_logic := '0';
  signal as_reset_n                   : std_logic := '0';
  signal start                        : std_logic := '0';
  signal recover_fsm_n                : std_logic := '0';
  signal op_1                         : std_logic_vector (31 downto 0);
  signal op_2                         : std_logic_vector (31 downto 0);
  signal product                      : std_logic_vector (63 downto 0);
  signal ready                        : std_logic;
  signal user_fsm_invalid_state_error : std_logic;

begin
  L_CLK : process begin
    wait for 10 ns;
    clk <= not clk;
  end process;
  L_DUV : entity work.shmul(rtl)
    generic map(
      operand_size => 32
    )
    port map
    (
      clk                          => clk,
      as_reset_n                   => as_reset_n,
      start                        => start,
      recover_fsm_n                => recover_fsm_n,
      op_1                         => op_1,
      op_2                         => op_2,
      product                      => product,
      ready                        => ready,
      user_fsm_invalid_state_error => user_fsm_invalid_state_error
    );
  L_TEST_SEQ : process begin
    wait for 100 ns;
    as_reset_n <= '0'; recover_fsm_n <= '0';
    wait for 100 ns;
    as_reset_n <= '1'; recover_fsm_n <= '1';
    wait until rising_edge(clk);
    op_1 <= std_logic_vector(to_signed(-42, 32));
    op_2 <= std_logic_vector(to_signed(-42, 32));
    wait until rising_edge(clk);
    start <= '1';
    wait for 100 ns;
	start <= '0';
    wait until rising_edge(ready);
	wait until rising_edge(clk);
    op_1 <= std_logic_vector(to_signed(42, 32));
    op_2 <= std_logic_vector(to_signed(-42, 32));
    wait until rising_edge(clk);
    start <= '1';
    wait for 100 ns;
	start <= '0';
	wait until rising_edge(ready);
	wait until rising_edge(clk);
    op_1 <= std_logic_vector(to_signed(42, 32));
    op_2 <= std_logic_vector(to_signed(42, 32));
    wait until rising_edge(clk);
    start <= '1';
    wait for 100 ns;
	start <= '0';
	wait;
  end process;
end architecture;