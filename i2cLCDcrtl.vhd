LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity i2cLCDctrl is
port(
    clk				: IN std_logic;
	 LineOne			: IN std_logic_vector(95 downto 0);
	 LineTwo			: IN std_logic_vector(95 downto 0);
    scl				: INOUT std_logic;
    sda				: INOUT std_logic
);
end i2cLCDctrl;
	
-----------------------------------------------------------------------------------

architecture logic of i2cLCDctrl is

component i2c_master IS
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz --100_000_000
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz --400_000 or 400_000
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END component;

type stateTypes is (start, writing, stop);
signal state        : stateTypes;
signal i2c_ena      : std_logic;
signal slave_addr   : std_logic_vector(6 downto 0):="0100111";
signal i2c_addr     : std_logic_vector(6 downto 0);
signal data_wr      : std_logic_vector(7 downto 0);
signal busy	        : std_logic;
signal byteSel      : integer range 0 to 185;
signal reset_n,i2c_rw,oldBusy :std_logic;
signal cont 		:integer:=250000;
signal newLineOne: std_logic_vector(95 downto 0);
signal newLineTwo: std_logic_vector(95 downto 0);

-- -----------------------------------------------------------------------------------------------------------------------------------
begin

inst_i2cMaster: i2c_master
generic map(
	input_clk => 125_000_000, --input clock speed from user logic in Hz --50_000_000 for Altera//125_000_000 for Digilent
	bus_clk 	 => 10_000) 	 --speed the i2c bus (scl) will run at in Hz --100_000
port map(
	clk       =>clk,                   --system clock
    reset_n   =>reset_n,			 --active low reset
    ena       =>i2c_ena,			 --latch in command
    addr      =>i2c_addr, 			--address of target slave
    rw        =>'0'	,				--'0' is write, '1' is read (I am writing data ABCD)
    data_wr   =>data_wr, 		--data to write to slave
    busy      =>busy,--indicates transaction in progress
    data_rd   =>open,--data read from slave (e.g. a sensor)
    ack_error =>open,                    --flag if improper acknowledge from slave
    sda       =>sda,--serial data output of i2c bus
    scl       =>scl

);

---------------------------------------------------------------------------------------------------
process(clk)
begin 
if (clk'event and clk = '1') then 
case state is 
	when start => 
	if cont /= 0 then --if cont is not 0
		cont <= cont - 1; --decrement
		reset_n <= '0'; --assert the reset
		state <= start; -- stay in same state
		i2c_ena <= '0'; --enable goes low
		byteSel <= 0; --initialize bytesel
	else
		reset_n <= '1'; --de-assert the reset
		i2c_ena <= '1'; --enabled!
		i2c_addr <= slave_addr; --write the address of the device
		i2c_rw <= '0'; --writing
		--i2c_data_wr <= data_wr;
		state <= writing; --go to write state
	end if;
---------------------------------------------------------------------------------------------------
	when writing =>
	oldBusy <= busy; --save the current value of the busy flag
	newLineOne <= LineOne; --save the current value of the data
	newLineTwo <= LineTwo;
	if (busy = '0' and oldBusy /= busy) then--if it is not busy (busy = 0) and the busy changes its state...
		if byteSel /= 185 then --if it is not at the end of the byteSel sequences
			byteSel <= byteSel + 1; --increment
			state <= writing; --stay in writing state
		else
			byteSel <= 24; --otherwise, return to the point where it clears the display
			state <= stop; -- go to stop state
		end if;
	end if;
---------------------------------------------------------------------------------------------------
	when stop =>
		i2c_ena <= '0'; --disable
		--cont <= 250000;
		if (newLineOne /= LineOne) or (newLineTwo /= LineTwo) then --if it senses a data change
		state <= start; --go back to start and do this process again
		else 
		state <= stop; --otherwise, stay in the stop state
		end if;
	end case;
end if;
end process;

-- --------------------------------------------Type 2. Not sending the 0's with 0x30 and 0x20==>WORKS -------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

				-- [P7 P6 P5 P4] [P3]  [P2]  [P1]  [P0]
				-- [D7 D6 D5 D4] [ 1 ] [EN]	[R/W]  [RS]
				-- [  D A T A  ] [ 1 ] [1/0]	[1/0]  [0=cmd/1=data]
process(byteSel)
	begin
	case byteSel is
	--0x30
	when 0 => data_wr <= X"3" & '1' & '0' & '0' & '0'; --1st time sending 0x30/sends 3
	when 1 => data_wr <= X"3" & '1' & '1' & '0' & '0'; 
	when 2 => data_wr <= X"3" & '1' & '0' & '0' & '0'; 

	--0x30
	when 3 => data_wr <= X"3" & '1' & '0' & '0' & '0'; --2nd time sending 0x30/sends 3
	when 4 => data_wr <= X"3" & '1' & '1' & '0' & '0'; 
	when 5 => data_wr <= X"3" & '1' & '0' & '0' & '0'; 

	--0x30
	when 6 => data_wr <= X"3" & '1' & '0' & '0' & '0'; --3rd time sending 0x30/sends 3
	when 7 => data_wr <= X"3" & '1' & '1' & '0' & '0'; 
	when 8 => data_wr <= X"3" & '1' & '0' & '0' & '0'; 

	--0x20
	when 9 => data_wr <= X"2" & '1' & '0' & '0' & '0'; --sending 0x20/sends 2
	when 10 => data_wr <= X"2" & '1' & '1' & '0' & '0'; 
	when 11 => data_wr <= X"2" & '1' & '0' & '0' & '0'; 
	
	--0x28
	when 12 => data_wr <= X"2" & '1' & '0' & '0' & '0'; --sending 0x28/sends 2 //4-bit mode, 2-lines & 5x7 dots
	when 13 => data_wr <= X"2" & '1' & '1' & '0' & '0'; 
	when 14 => data_wr <= X"2" & '1' & '0' & '0' & '0'; 

	when 15 => data_wr <= X"8" & '1' & '0' & '0' & '0'; --sends 0
	when 16 => data_wr <= X"8" & '1' & '1' & '0' & '0'; 
	when 17 => data_wr <= X"8" & '1' & '0' & '0' & '0'; 
	
	--0x06
	when 18 => data_wr <= X"0" & '1' & '0' & '0' & '0'; --sending 0x06/sends 0 //Increment cursor direction & display shift OFF
	when 19 => data_wr <= X"0" & '1' & '1' & '0' & '0'; 
	when 20 => data_wr <= X"0" & '1' & '0' & '0' & '0'; 

	when 21 => data_wr <= X"6" & '1' & '0' & '0' & '0'; --sends 6
	when 22 => data_wr <= X"6" & '1' & '1' & '0' & '0'; 
	when 23 => data_wr <= X"6" & '1' & '0' & '0' & '0'; 
	
	--0x01
	when 24 => data_wr <= X"0" & '1' & '0' & '0' & '0'; --sending 0x01/sends 0 //Clears display and returns cursor to home
	when 25 => data_wr <= X"0" & '1' & '1' & '0' & '0'; 
	when 26 => data_wr <= X"0" & '1' & '0' & '0' & '0'; 

	when 27 => data_wr <= X"1" & '1' & '0' & '0' & '0'; --sends 1
	when 28 => data_wr <= X"1" & '1' & '1' & '0' & '0'; 
	when 29 => data_wr <= X"1" & '1' & '0' & '0' & '0';

	--0x0f
	when 30 => data_wr <= X"0" & '1' & '0' & '0' & '0'; --sending 0x0f/sends 0 //Display ON, Cursor ON, Blink ON
	when 31 => data_wr <= X"0" & '1' & '1' & '0' & '0'; 
	when 32 => data_wr <= X"0" & '1' & '0' & '0' & '0'; 

	when 33 => data_wr <= X"F" & '1' & '0' & '0' & '0'; --sends f
	when 34 => data_wr <= X"F" & '1' & '1' & '0' & '0'; 
	when 35 => data_wr <= X"F" & '1' & '0' & '0' & '0';	

	                     -- [P7 P6 P5 P4]   	[P3]   [P2] [P1]   [P0]
                        -- [D7 D6 D5 D4]     [ 1 ]   [EN] [R/W]  [RS]
                        -- [  D A T A  ]     [ 1 ]  [1/0] [1/0]  [0=cmd/1=data]
-----Done Initializing in 4-bit mode
	when 36 => data_wr <= LineOne(95 downto 92) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '1'
	when 37 => data_wr <= LineOne(95 downto 92) & '1' & '1' & '0' & '1';
	when 38 => data_wr <= LineOne(95 downto 92) & '1' & '0' & '0' & '1';
	
	when 39 => data_wr <= LineOne(91 downto 88) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '1'
	when 40 => data_wr <= LineOne(91 downto 88) & '1' & '1' & '0' & '1';
	when 41 => data_wr <= LineOne(91 downto 88) & '1' & '0' & '0' & '1';
	
	when 42 => data_wr <= LineOne(87 downto 84) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '2'
	when 43 => data_wr <= LineOne(87 downto 84) & '1' & '1' & '0' & '1';
	when 44 => data_wr <= LineOne(87 downto 84) & '1' & '0' & '0' & '1';
	
	when 45 => data_wr <= LineOne(83 downto 80) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '2'
	when 46 => data_wr <= LineOne(83 downto 80) & '1' & '1' & '0' & '1';
	when 47 => data_wr <= LineOne(83 downto 80) & '1' & '0' & '0' & '1';
	
	when 48 => data_wr <= LineOne(79 downto 76) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '3'
	when 49 => data_wr <= LineOne(79 downto 76) & '1' & '1' & '0' & '1';
	when 50 => data_wr <= LineOne(79 downto 76) & '1' & '0' & '0' & '1';
	
	when 51 => data_wr <= LineOne(75 downto 72) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '3'
	when 52 => data_wr <= LineOne(75 downto 72) & '1' & '1' & '0' & '1';
	when 53 => data_wr <= LineOne(75 downto 72) & '1' & '0' & '0' & '1';
	
	when 54 => data_wr <= LineOne(71 downto 68) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '4'
	when 55 => data_wr <= LineOne(71 downto 68) & '1' & '1' & '0' & '1';
	when 56 => data_wr <= LineOne(71 downto 68) & '1' & '0' & '0' & '1';
	
	when 57 => data_wr <= LineOne(67 downto 64) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '4'
	when 58 => data_wr <= LineOne(67 downto 64) & '1' & '1' & '0' & '1';
	when 59 => data_wr <= LineOne(67 downto 64) & '1' & '0' & '0' & '1';
	
	when 60 => data_wr <= LineOne(63 downto 60) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '5'
	when 61 => data_wr <= LineOne(63 downto 60) & '1' & '1' & '0' & '1';
	when 62 => data_wr <= LineOne(63 downto 60) & '1' & '0' & '0' & '1';
	
	when 63 => data_wr <= LineOne(59 downto 56) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '5'
	when 64 => data_wr <= LineOne(59 downto 56) & '1' & '1' & '0' & '1';
	when 65 => data_wr <= LineOne(59 downto 56) & '1' & '0' & '0' & '1';

	when 66 => data_wr <= LineOne(55 downto 52) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '6'
	when 67 => data_wr <= LineOne(55 downto 52) & '1' & '1' & '0' & '1';
	when 68 => data_wr <= LineOne(55 downto 52) & '1' & '0' & '0' & '1';
	
	when 69 => data_wr <= LineOne(51 downto 48) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '6'
	when 70 => data_wr <= LineOne(51 downto 48) & '1' & '1' & '0' & '1';
	when 71 => data_wr <= LineOne(51 downto 48) & '1' & '0' & '0' & '1';
	
	when 72 => data_wr <= LineOne(47 downto 44) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '7'
	when 73 => data_wr <= LineOne(47 downto 44) & '1' & '1' & '0' & '1';
	when 74 => data_wr <= LineOne(47 downto 44) & '1' & '0' & '0' & '1';
	
	when 75 => data_wr <= LineOne(43 downto 40) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '7'
	when 76 => data_wr <= LineOne(43 downto 40) & '1' & '1' & '0' & '1';
	when 77 => data_wr <= LineOne(43 downto 40) & '1' & '0' & '0' & '1';
	
	when 78 => data_wr <= LineOne(39 downto 36) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '8'
	when 79 => data_wr <= LineOne(39 downto 36) & '1' & '1' & '0' & '1';
	when 80 => data_wr <= LineOne(39 downto 36) & '1' & '0' & '0' & '1';
	
	when 81 => data_wr <= LineOne(35 downto 32) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '8'
	when 82 => data_wr <= LineOne(35 downto 32) & '1' & '1' & '0' & '1';
	when 83 => data_wr <= LineOne(35 downto 32) & '1' & '0' & '0' & '1';
	
	when 84 => data_wr <= LineOne(31 downto 28) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '9'
	when 85 => data_wr <= LineOne(31 downto 28) & '1' & '1' & '0' & '1';
	when 86 => data_wr <= LineOne(31 downto 28) & '1' & '0' & '0' & '1';
	
	when 87 => data_wr <= LineOne(27 downto 24) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '9'
	when 88 => data_wr <= LineOne(27 downto 24) & '1' & '1' & '0' & '1';
	when 89 => data_wr <= LineOne(27 downto 24) & '1' & '0' & '0' & '1';
	
	when 90 => data_wr <= LineOne(23 downto 20) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'A'
	when 91 => data_wr <= LineOne(23 downto 20) & '1' & '1' & '0' & '1';
	when 92 => data_wr <= LineOne(23 downto 20) & '1' & '0' & '0' & '1';
	
	when 93 => data_wr <= LineOne(19 downto 16) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'A'
	when 94 => data_wr <= LineOne(19 downto 16) & '1' & '1' & '0' & '1';
	when 95 => data_wr <= LineOne(19 downto 16) & '1' & '0' & '0' & '1';
	
	when 96 => data_wr <= LineOne(15 downto 12) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'B'
	when 97 => data_wr <= LineOne(15 downto 12) & '1' & '1' & '0' & '1';
	when 98 => data_wr <= LineOne(15 downto 12) & '1' & '0' & '0' & '1';
	
	when 99 => data_wr <= LineOne(11 downto 8) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'B'
	when 100 => data_wr <= LineOne(11 downto 8) & '1' & '1' & '0' & '1';
	when 101 => data_wr <= LineOne(11 downto 8) & '1' & '0' & '0' & '1';
	
	when 102 => data_wr <= LineOne(7 downto 4) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'C'
	when 103 => data_wr <= LineOne(7 downto 4) & '1' & '1' & '0' & '1';
	when 104 => data_wr <= LineOne(7 downto 4) & '1' & '0' & '0' & '1';
	
	when 105 => data_wr <= LineOne(3 downto 0) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'C'
	when 106 => data_wr <= LineOne(3 downto 0) & '1' & '1' & '0' & '1';
	when 107 => data_wr <= LineOne(3 downto 0) & '1' & '0' & '0' & '1';

	when 108 => data_wr <= X"C" & '1' & '0' & '0' & '0';  --first half of 0xC0 (8) /Force cursor to second line
	when 109 => data_wr <= X"C" & '1' & '1' & '0' & '0';
	when 110 => data_wr <= X"C" & '1' & '0' & '0' & '0';
	
	when 111 => data_wr <= X"0" & '1' & '0' & '0' & '0'; --second half of 0xC0 (0)
	when 112 => data_wr <= X"0" & '1' & '1' & '0' & '0';
	when 113 => data_wr <= X"0" & '1' & '0' & '0' & '0';
	
	when 114 => data_wr <= LineTwo(95 downto 92) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '1'
	when 115 => data_wr <= LineTwo(95 downto 92) & '1' & '1' & '0' & '1';
	when 116 => data_wr <= LineTwo(95 downto 92) & '1' & '0' & '0' & '1';

	when 117 => data_wr <= LineTwo(91 downto 88) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '1'
	when 118 => data_wr <= LineTwo(91 downto 88) & '1' & '1' & '0' & '1';
	when 119 => data_wr <= LineTwo(91 downto 88) & '1' & '0' & '0' & '1';

	when 120 => data_wr <= LineTwo(87 downto 84) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '2'
	when 121 => data_wr <= LineTwo(87 downto 84) & '1' & '1' & '0' & '1';
	when 122 => data_wr <= LineTwo(87 downto 84) & '1' & '0' & '0' & '1';

	when 123 => data_wr <= LineTwo(83 downto 80) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '2'
	when 124 => data_wr <= LineTwo(83 downto 80) & '1' & '1' & '0' & '1';
	when 125 => data_wr <= LineTwo(83 downto 80) & '1' & '0' & '0' & '1';

	when 126 => data_wr <= LineTwo(79 downto 76) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '3'
	when 127 => data_wr <= LineTwo(79 downto 76) & '1' & '1' & '0' & '1';
	when 128 => data_wr <= LineTwo(79 downto 76) & '1' & '0' & '0' & '1';

	when 129 => data_wr <= LineTwo(75 downto 72) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '3'
	when 130 => data_wr <= LineTwo(75 downto 72) & '1' & '1' & '0' & '1';
	when 131 => data_wr <= LineTwo(75 downto 72) & '1' & '0' & '0' & '1';

	when 132 => data_wr <= LineTwo(71 downto 68) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '4'
	when 133 => data_wr <= LineTwo(71 downto 68) & '1' & '1' & '0' & '1';
	when 134 => data_wr <= LineTwo(71 downto 68) & '1' & '0' & '0' & '1';

	when 135 => data_wr <= LineTwo(67 downto 64) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '4'
	when 136 => data_wr <= LineTwo(67 downto 64) & '1' & '1' & '0' & '1';
	when 137 => data_wr <= LineTwo(67 downto 64) & '1' & '0' & '0' & '1';

	when 138 => data_wr <= LineTwo(63 downto 60) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '5'
	when 139 => data_wr <= LineTwo(63 downto 60) & '1' & '1' & '0' & '1';
	when 140 => data_wr <= LineTwo(63 downto 60) & '1' & '0' & '0' & '1';

	when 141 => data_wr <= LineTwo(59 downto 56) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '5'
	when 142 => data_wr <= LineTwo(59 downto 56) & '1' & '1' & '0' & '1';
	when 143 => data_wr <= LineTwo(59 downto 56) & '1' & '0' & '0' & '1';

	when 144 => data_wr <= LineTwo(55 downto 52) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '6'
	when 145 => data_wr <= LineTwo(55 downto 52) & '1' & '1' & '0' & '1';
	when 146 => data_wr <= LineTwo(55 downto 52) & '1' & '0' & '0' & '1';

	when 147 => data_wr <= LineTwo(51 downto 48) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '6'
	when 148 => data_wr <= LineTwo(51 downto 48) & '1' & '1' & '0' & '1';
	when 149 => data_wr <= LineTwo(51 downto 48) & '1' & '0' & '0' & '1';

	when 150 => data_wr <= LineTwo(47 downto 44) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '7'
	when 151 => data_wr <= LineTwo(47 downto 44) & '1' & '1' & '0' & '1';
	when 152 => data_wr <= LineTwo(47 downto 44) & '1' & '0' & '0' & '1';

	when 153 => data_wr <= LineTwo(43 downto 40) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '7'
	when 154 => data_wr <= LineTwo(43 downto 40) & '1' & '1' & '0' & '1';
	when 155 => data_wr <= LineTwo(43 downto 40) & '1' & '0' & '0' & '1';

	when 156 => data_wr <= LineTwo(39 downto 36) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '8'
	when 157 => data_wr <= LineTwo(39 downto 36) & '1' & '1' & '0' & '1';
	when 158 => data_wr <= LineTwo(39 downto 36) & '1' & '0' & '0' & '1';

	when 159 => data_wr <= LineTwo(35 downto 32) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '8'
	when 160 => data_wr <= LineTwo(35 downto 32) & '1' & '1' & '0' & '1';
	when 161 => data_wr <= LineTwo(35 downto 32) & '1' & '0' & '0' & '1';

	when 162 => data_wr <= LineTwo(31 downto 28) & '1' & '0' & '0' & '1'; --Write Upper Nibble of '9'
	when 163 => data_wr <= LineTwo(31 downto 28) & '1' & '1' & '0' & '1';
	when 164 => data_wr <= LineTwo(31 downto 28) & '1' & '0' & '0' & '1';

	when 165 => data_wr <= LineTwo(27 downto 24) & '1' & '0' & '0' & '1'; --Write Lower Nibble of '9'
	when 166 => data_wr <= LineTwo(27 downto 24) & '1' & '1' & '0' & '1';
	when 167 => data_wr <= LineTwo(27 downto 24) & '1' & '0' & '0' & '1';

	when 168 => data_wr <= LineTwo(23 downto 20) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'A'
	when 169 => data_wr <= LineTwo(23 downto 20) & '1' & '1' & '0' & '1';
	when 170 => data_wr <= LineTwo(23 downto 20) & '1' & '0' & '0' & '1';

	when 171 => data_wr <= LineTwo(19 downto 16) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'A'
	when 172 => data_wr <= LineTwo(19 downto 16) & '1' & '1' & '0' & '1';
	when 173 => data_wr <= LineTwo(19 downto 16) & '1' & '0' & '0' & '1';

	when 174 => data_wr <= LineTwo(15 downto 12) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'B'
	when 175 => data_wr <= LineTwo(15 downto 12) & '1' & '1' & '0' & '1';
	when 176 => data_wr <= LineTwo(15 downto 12) & '1' & '0' & '0' & '1';

	when 177 => data_wr <= LineTwo(11 downto 8) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'B'
	when 178 => data_wr <= LineTwo(11 downto 8) & '1' & '1' & '0' & '1';
	when 179 => data_wr <= LineTwo(11 downto 8) & '1' & '0' & '0' & '1';

	when 180 => data_wr <= LineTwo(7 downto 4) & '1' & '0' & '0' & '1'; --Write Upper Nibble of 'C'
	when 181 => data_wr <= LineTwo(7 downto 4) & '1' & '1' & '0' & '1';
	when 182 => data_wr <= LineTwo(7 downto 4) & '1' & '0' & '0' & '1';

	when 183 => data_wr <= LineTwo(3 downto 0) & '1' & '0' & '0' & '1'; --Write Lower Nibble of 'C'
	when 184 => data_wr <= LineTwo(3 downto 0) & '1' & '1' & '0' & '1';
	when 185 => data_wr <= LineTwo(3 downto 0) & '1' & '0' & '0' & '1';

	
end case;
end process;

end logic;