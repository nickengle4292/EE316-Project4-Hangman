library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_RX is
  generic (
    g_CLKS_PER_BIT : integer := 5208   -- Needs to be set correctly take 50000000/speed sent by hangman
    );
  port (
    i_Clk       : in  std_logic;
    i_RX_Serial : in  std_logic;
    o_RX_DV     : out std_logic;
    o_RX_7Seg   : out std_logic_vector(6 downto 0)
    );
end UART_RX;

architecture rtl of UART_RX is

  type t_SM_Main is (s_Idle, s_RX_Start_Bit, s_RX_Data_Bits,
                     s_RX_Stop_Bit, s_Convert, s_Cleanup);
  signal r_SM_Main : t_SM_Main := s_Idle;

  signal r_RX_Data_R : std_logic := '0';
  signal r_RX_Data   : std_logic := '0';

  signal r_Clk_Count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
  signal r_Bit_Index : integer range 0 to 7 := 0;  -- 8 Bits Total
  signal r_RX_7Seg   : std_logic_vector(6 downto 0);
  signal r_RX_DV     : std_logic := '0';

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

  -- Purpose: Double-register the incoming data.
  -- This allows it to be used in the UART RX Clock Domain.
  -- (It removes problems caused by metastability)
  p_SAMPLE : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
      r_RX_Data_R <= i_RX_Serial;
      r_RX_Data   <= r_RX_Data_R; 
    end if; 
  end process p_SAMPLE;

  -- Purpose: Control RX state machine
  p_UART_RX : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
      case r_SM_Main is
        when s_Idle =>
          r_RX_DV     <= '0';
          r_Clk_Count <= 0;
          r_Bit_Index <= 0;

          if r_RX_Data = '0' then       -- Start bit detected
            r_SM_Main <= s_RX_Start_Bit;
          else
            r_SM_Main <= s_Idle;
          end if;

        -- Check middle of start bit to make sure it's still low
        when s_RX_Start_Bit =>
          if r_Clk_Count = (g_CLKS_PER_BIT-1)/2 then
            if r_RX_Data = '0' then
              r_Clk_Count <= 0;  -- reset counter since we found the middle
              r_SM_Main   <= s_RX_Data_Bits;
            else
              r_SM_Main   <= s_Idle;
            end if;
          else
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Start_Bit;
          end if;

        -- Wait g_CLKS_PER_BIT-1 clock cycles to sample serial data
        when s_RX_Data_Bits =>
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Data_Bits;
          else
            r_Clk_Count            <= 0;
            r_RX_7Seg <= ascii_to_7seg(r_RX_Data);
            
            -- Check if we have sent out all bits
            if r_Bit_Index < 7 then
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= s_RX_Data_Bits;
            else
              r_Bit_Index <= 0;
              r_SM_Main   <= s_RX_Stop_Bit;
            end if;
          end if;
           
        -- Receive Stop bit. Stop bit = 1
        when s_RX_Stop_Bit =>
          -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Stop_Bit;
          else
            r_RX_DV     <= '1';
            r_Clk_Count <= 0;
            r_SM_Main   <= s_Cleanup;
          end if;
            
        -- Stay here 1 clock
        when s_Cleanup =>
          r_SM_Main <= s_Idle;
          r_RX_DV   <= '0';
          
        when others =>
          r_SM_Main <= s_Idle;

      end case;
    end if;
  end process p_UART_RX;

  o_RX_DV     <= r_RX_DV;
  o_RX_7Seg   <= r_RX_7Seg;
   
end rtl;
