library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_user is
    generic(
        data_length : integer := 33
    );
    port(
        clock : in std_logic;
        reset_n : in std_logic;
        inData : in std_logic_vector(7 downto 0);
        keypressed : in std_logic;
        rx      : in std_logic;
        tx      : out std_logic;        
        odataArray : out std_logic_vector(data_length*8 - 1 downto 0)        
        );
end UART_user;

architecture Behavioral of UART_user is

component UART IS
  GENERIC(
    clk_freq  :  INTEGER    := 50000000;  --frequency of system clock in Hertz
    baud_rate :  INTEGER    := 9600;      --data link baud rate in bits/second
    os_rate   :  INTEGER    := 16;          --oversampling rate to find center of receive bits (in samples per baud period)
    d_width   :  INTEGER    := 8;           --data bus width
    parity    :  INTEGER    := 0;           --0 for no parity, 1 for parity
    parity_eo :  STD_LOGIC  := '0');        --'0' for even, '1' for odd parity
  PORT(
    clk      :  IN   STD_LOGIC;                             --system clock
    reset_n  :  IN   STD_LOGIC;                             --ascynchronous reset
    tx_ena   :  IN   STD_LOGIC;                             --initiate transmission
    tx_data  :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
    rx       :  IN   STD_LOGIC;                             --receive pin
    rx_busy  :  OUT  STD_LOGIC;                             --data reception in progress
    rx_error :  OUT  STD_LOGIC;                             --start, parity, or stop bit error detected
    rx_data  :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data received
    tx_busy  :  OUT  STD_LOGIC;                             --transmission in progress
    tx       :  OUT  STD_LOGIC);                            --transmit pin
END component;

signal tx_en : std_logic;
signal tx_busy : std_logic;
signal rx_busy : std_logic;
signal rx_error : std_logic;
signal outData : std_logic_vector(7 downto 0);
signal sel  : integer range 0 to data_length := data_length;

-- ASCII to 7-Segment conversion function
function ascii_to_7seg(input_char: std_logic_vector(7 downto 0)) return std_logic_vector is
    variable result : std_logic_vector(6 downto 0);
begin
    case input_char is
        when "01000001" => result := "1000000"; -- 'A'
        when "01000010" => result := "1111001"; -- 'B'
        when "01000011" => result := "0100100"; -- 'C'
        when "01000100" => result := "0110001"; -- 'D'
        when "01000101" => result := "0011000"; -- 'E'
        when "01000110" => result := "0010000"; -- 'F'
        when "01000111" => result := "0001100"; -- 'G'
        when "01001000" => result := "1111000"; -- 'H'
        when "01001001" => result := "1111000"; -- 'I'
        when "01001010" => result := "1111000"; -- 'J'
        when "01001011" => result := "1111000"; -- 'K'
        when "01001100" => result := "1111000"; -- 'L'
        when "01001101" => result := "1111000"; -- 'M'
        when "01001110" => result := "1111000"; -- 'N'
        when "01001111" => result := "1111000"; -- 'O'
        when "01010000" => result := "1111000"; -- 'P'
        when "01010001" => result := "1111000"; -- 'Q'
        when "01010010" => result := "1111000"; -- 'R'
        when "01010011" => result := "1111000"; -- 'S'
        when "01010100" => result := "1111000"; -- 'T'
        when "01010101" => result := "1111000"; -- 'U'
        when "01010110" => result := "1111000"; -- 'V'
        when "01010111" => result := "1111000"; -- 'W'
        when "01011000" => result := "1111000"; -- 'X'
        when "01011001" => result := "1111000"; -- 'Y'
        when "01011010" => result := "1111000"; -- 'Z'
        when others     => result := "0000000"; -- default to blank
    end case;
    return result;
end function;

begin

outData <= outData;
tx_busy <= tx_busy;
rx_busy <= rx_busy;
rx_error <= rx_error;

process(rx_busy)
begin
    if falling_edge(rx_busy) and rx_error = '0' then
        if sel /= 0 then
            odataArray(sel*8 downto (sel-1)*8 + 1) <= outData;
            sel <= sel - 1;
        else
            sel <= data_length;
        end if;
   
    end if;
end process;

 process(keypressed, inData)
    begin
        if keypressed = '1' then
            if tx_busy = '0' then
                tx_en <= '1';
                -- Transmit the key pressed via UART
                tx_data <= ascii_to_7seg(inData); -- Convert input data to 7-segment format
            end if;    
        else
            tx_en <= '0';    
        end if;
    end process;

-- UART component instantiation
Inst_UART: UART
  GENERIC MAP(
    clk_freq  => 50000000,  --frequency of system clock in Hertz
    baud_rate => 9600,      --data link baud rate in bits/second
    os_rate   => 16,          --oversampling rate to find center of receive bits (in samples per baud period)
    d_width   => 8,           --data bus width
    parity    => 0,           --0 for no parity, 1 for parity
    parity_eo => '0')        --'0' for even, '1' for odd parity
  PORT MAP(
    clk      =>  clock,                           --system clock
    reset_n  =>  reset_n,                           --ascynchronous reset
    tx_ena   =>  tx_en,                           --initiate transmission
    tx_data  =>  inData,                           --data to transmit
    rx       =>  rx,                           --receive pin
    rx_busy  =>  rx_busy,                           --data reception in progress
    rx_error =>  rx_error,                          --start, parity, or stop bit error detected
    rx_data  =>  outData,                           --data received
    tx_busy  =>  tx_busy,                           --transmission in progress
    tx       =>  tx                          --transmit pin
    );
    
end Behavioral;
