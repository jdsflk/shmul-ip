library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity shmul is
  generic (
    operand_size : integer range 1 to 32
  );

  port (
    clk                          : in std_logic;
    as_reset_n                   : in std_logic;
    start                        : in std_logic;
    recover_fsm_n                : in std_logic;
    op_1                         : in std_logic_vector (operand_size - 1 downto 0);
    op_2                         : in std_logic_vector (operand_size - 1 downto 0);

    product                      : out std_logic_vector (63 downto 0);
    ready                        : out std_logic;
    user_fsm_invalid_state_error : out std_logic
  );
end entity shmul;

architecture rtl of shmul is
  type state_t is (wait_for_start, init, check_for_sign, check_addition, shift, check_if_done, done, error);
  signal state : state_t;

  signal B                       : std_logic_vector (operand_size - 1 downto 0);
  signal Q                       : std_logic_vector (operand_size - 1 downto 0);
  signal A                       : std_logic_vector (2 * operand_size - 1 downto 0);
  signal N                       : integer range 0 to 32;

  signal temp_product: std_logic_vector (63 downto 0);

  signal negative_result         : std_logic;

begin

    product <= temp_product;
    L_CTRL_FSM: process (clk, as_reset_n, recover_fsm_n)
    begin
        if as_reset_n = '0' or recover_fsm_n = '0' then
            state <= wait_for_start;
            A <= ((others => '0'));
            B <= ((others => '0'));
            Q <= ((others => '0'));
            N <= operand_size;
            temp_product <= ((others => '0'));
            user_fsm_invalid_state_error <= '0';
            ready <= '1';
        elsif rising_edge(clk) then
            case state is
                when wait_for_start =>
                    ready <= '1';
                    if (start = '1') then
                        state <= init;
                    end if;
                when init =>
                    B <= op_1;
                    Q <= op_2;
                    A <= (others => '0');
					N <= operand_size;
                    ready <= '0';
                    state <= check_for_sign;
                when check_for_sign =>
                    if((B(operand_size - 1)) /= (Q(operand_size - 1))) then
                        negative_result <= '1';
                    else
                        negative_result <= '0';
                    end if;
                    -- maybe we need a separate state to do this
                    if(B(operand_size -1) = '1') then
                        B <= std_logic_vector(-signed(B));
                    end if;
                    if(Q(operand_size -1) = '1') then
                        Q <= std_logic_vector(-signed(Q));
                    end if;
                    state <= check_addition;
                when check_addition =>
                    if(Q(0) = '1') then
                        A <= std_logic_vector(unsigned(A) + unsigned(B));
                    end if;
                    state <= shift;
                when shift =>
                    B <= (B(operand_size - 2 downto 0) & '0');
                    Q <= ('0' & Q(operand_size -1 downto 1));
                    N <= N - 1;
                    state <= check_if_done;
                when check_if_done =>
                    if(N = 0) then
                        if(negative_result = '1') then
                            temp_product <= std_logic_vector(-signed(A));
                        else
                            if (operand_size = 32) then
                                temp_product <= A;
                            else
                            temp_product <= temp_product(63 downto 2* operand_size) & A;
                            end if;
                        end if;
                        state <= wait_for_start;
                    else
                        state <= check_addition;
                    end if;
                when error => user_fsm_invalid_state_error <= '1';
                when others =>
                    state <= error;
            end case;
        end if;
    end process;
end architecture;