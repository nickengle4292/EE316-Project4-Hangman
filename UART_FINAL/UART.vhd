LIBRARY ieee;
USE ieee.std_logic_1164.all;

-- Declaration of the UART entity
ENTITY UART IS
  GENERIC(
    clk_freq  :  INTEGER    := 50000000;  -- Frequency of the system clock in Hertz
    baud_rate :  INTEGER    := 9600;      -- Data link baud rate in bits/second (9600)
    os_rate   :  INTEGER    := 16;        -- Oversampling rate to find center of receive bits (in samples per baud period)
    d_width   :  INTEGER    := 8;         -- Data bus width
    parity    :  INTEGER    := 0;         -- 0 for no parity, 1 for parity
    parity_eo :  STD_LOGIC  := '0');      -- '0' for even, '1' for odd parity
  PORT(
    clk      :  IN   STD_LOGIC;                             -- System clock
    reset_n  :  IN   STD_LOGIC;                             -- Asynchronous reset
    tx_ena   :  IN   STD_LOGIC;                             -- Initiate transmission
    tx_data  :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  -- Data to transmit
    rx       :  IN   STD_LOGIC;                             -- Receive pin
    rx_busy  :  OUT  STD_LOGIC;                             -- Data reception in progress
    rx_error :  OUT  STD_LOGIC;                             -- Start, parity, or stop bit error detected
    rx_data  :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  -- Data received
    tx_busy  :  OUT  STD_LOGIC;                             -- Transmission in progress
    tx       :  OUT  STD_LOGIC);                            -- Transmit pin
END UART;
    
-- Architecture of the UART entity
ARCHITECTURE logic OF UART IS
  TYPE   tx_machine IS(idle, transmit);                       -- Transmission state machine data type
  TYPE   rx_machine IS(idle, receive);                        -- Receive state machine data type
  SIGNAL tx_state     :  tx_machine;                          -- Transmission state machine
  SIGNAL rx_state     :  rx_machine;                          -- Receive state machine
  SIGNAL baud_pulse   :  STD_LOGIC := '0';                    -- Periodic pulse that occurs at the baud rate
  SIGNAL os_pulse     :  STD_LOGIC := '0';                    -- Periodic pulse that occurs at the oversampling rate
  SIGNAL parity_error :  STD_LOGIC;                           -- Receive parity error flag
  SIGNAL rx_parity    :  STD_LOGIC_VECTOR(d_width DOWNTO 0);  -- Calculation of receive parity
  SIGNAL tx_parity    :  STD_LOGIC_VECTOR(d_width DOWNTO 0);  -- Calculation of transmit parity
  SIGNAL rx_buffer    :  STD_LOGIC_VECTOR(parity+d_width DOWNTO 0) := (OTHERS => '0');   -- Values received
  SIGNAL tx_buffer    :  STD_LOGIC_VECTOR(parity+d_width+1 DOWNTO 0) := (OTHERS => '1'); -- Values to be transmitted
BEGIN

  -- Generate clock enable pulses at the baud rate and the oversampling rate
  PROCESS(reset_n, clk)
    VARIABLE count_baud :  INTEGER RANGE 0 TO clk_freq/baud_rate-1 := 0;              -- Counter to determine baud rate period
    VARIABLE count_os   :  INTEGER RANGE 0 TO clk_freq/baud_rate/os_rate-1 := 0;      -- Counter to determine oversampling period
  BEGIN
    IF(reset_n = '0') THEN
      baud_pulse <= '0';                                -- Reset baud rate pulse
      os_pulse <= '0';                                  -- Reset oversampling rate pulse
      count_baud := 0;                                  -- Reset baud period counter
      count_os := 0;                                    -- Reset oversampling period counter
    ELSIF(clk'EVENT AND clk = '1') THEN
      -- Create baud enable pulse
      IF(count_baud < clk_freq/baud_rate-1) THEN        -- Baud period not reached
        count_baud := count_baud + 1;                     -- Increment baud period counter
        baud_pulse <= '0';                                -- Deassert baud rate pulse
      ELSE                                              -- Baud period reached
        count_baud := 0;                                  -- Reset baud period counter
        baud_pulse <= '1';                                -- Assert baud rate pulse
        count_os := 0;                                    -- Reset oversampling period counter to avoid cumulative error
      END IF;
      -- Create oversampling enable pulse
      IF(count_os < clk_freq/baud_rate/os_rate-1) THEN  -- Oversampling period not reached
        count_os := count_os + 1;                         -- Increment oversampling period counter
        os_pulse <= '0';                                  -- Deassert oversampling rate pulse    
      ELSE                                              -- Oversampling period reached
        count_os := 0;                                    -- Reset oversampling period counter
        os_pulse <= '1';                                  -- Assert oversampling pulse
      END IF;
    END IF;
  END PROCESS;

  -- Receive state machine
  PROCESS(reset_n, clk)
    VARIABLE rx_count :  INTEGER RANGE 0 TO parity+d_width+2 := 0; -- Count the bits received
    VARIABLE os_count :  INTEGER RANGE 0 TO os_rate-1 := 0;        -- Count the oversampling rate pulses
  BEGIN
    IF(reset_n = '0') THEN
      os_count := 0;                                         -- Clear oversampling pulse counter
      rx_count := 0;                                         -- Clear receive bit counter
      rx_busy <= '0';                                        -- Clear receive busy signal
      rx_error <= '0';                                       -- Clear receive errors
      rx_data <= (OTHERS => '0');                            -- Clear received data output
      rx_state <= idle;                                      -- Put in idle state
    ELSIF(clk'EVENT AND clk = '1' AND os_pulse = '1') THEN  -- Enable clock at oversampling rate
      CASE rx_state IS
        WHEN idle =>                                           -- Idle state
          rx_busy <= '0';                                        -- Clear receive busy flag
          IF(rx = '0') THEN                                      -- Start bit might be present
            IF(os_count < os_rate/2) THEN                          -- Oversampling pulse counter is not at start bit center
              os_count := os_count + 1;                              -- Increment oversampling pulse counter
              rx_state <= idle;                                      -- Remain in idle state
            ELSE                                                   -- Oversampling pulse counter is at bit center
              os_count := 0;                                         -- Clear oversampling pulse counter
              rx_count := 0;                                         -- Clear the bits received counter
              rx_busy <= '1';                                        -- Assert busy flag
              rx_buffer <= rx & rx_buffer(parity+d_width DOWNTO 1);  -- Shift the start bit into receive buffer							
              rx_state <= receive;                                   -- Advance to receive state
            END IF;
          ELSE                                                   -- Start bit not present
            os_count := 0;                                         -- Clear oversampling pulse counter
            rx_state <= idle;                                      -- Remain in idle state
          END IF;
        WHEN receive =>                                        -- Receive state
          IF(os_count < os_rate-1) THEN                          -- Not center of bit
            os_count := os_count + 1;                              -- Increment oversampling pulse counter
            rx_state <= receive;                                   -- Remain in receive state
          ELSIF(rx_count < parity+d_width) THEN                  -- Center of bit and not all bits received
            os_count := 0;                                         -- Reset oversampling pulse counter    
            rx_count := rx_count + 1;                              -- Increment number of bits received counter
            rx_buffer <= rx & rx_buffer(parity+d_width DOWNTO 1);  -- Shift new received bit into receive buffer
            rx_state <= receive;                                   -- Remain in receive state
          ELSE                                                   -- Center of stop bit
            rx_data <= rx_buffer(d_width DOWNTO 1);                -- Output data received to user logic
            rx_error <= rx_buffer(0) OR parity_error OR NOT rx;    -- Output start, parity, and stop bit error flag
            rx_busy <= '0';                                        -- Deassert received busy flag
            rx_state <= idle;                                      -- Return to idle state
          END IF;
      END CASE;
    END IF;
  END PROCESS;
    
  -- Receive parity calculation logic
  rx_parity(0) <= parity_eo;
  rx_parity_logic: FOR i IN 0 to d_width-1 GENERATE
    rx_parity(i+1) <= rx_parity(i) XOR rx_buffer(i+1);
  END GENERATE;
  WITH parity SELECT  -- Compare calculated parity bit with received parity bit to determine error
    parity_error <= rx_parity(d_width) XOR rx_buffer(parity+d_width) WHEN 1,  -- Using parity
                    '0' WHEN OTHERS;                                          -- Not using parity
    
  -- Transmit state machine
  PROCESS(reset_n, clk)
    VARIABLE tx_count :  INTEGER RANGE 0 TO parity+d_width+3 := 0;  -- Count bits transmitted
  BEGIN
    IF(reset_n = '0') THEN                                    -- Asynchronous reset asserted
      tx_count := 0;                                            -- Clear transmit bit counter
      tx <= '1';                                                -- Set tx pin to idle value of high
      tx_busy <= '1';                                           -- Set transmit busy signal to indicate unavailable
      tx_state <= idle;                                         -- Set tx state machine to ready state
    ELSIF(clk'EVENT AND clk = '1') THEN
      CASE tx_state IS
        WHEN idle =>                                              -- Idle state
          IF(tx_ena = '1') THEN                                     -- New transaction latched in
            tx_buffer(d_width+1 DOWNTO 0) <=  tx_data & '0' & '1';    -- Latch in data for transmission and start/stop bits
            IF(parity = 1) THEN                                       -- If parity is used
              tx_buffer(parity+d_width+1) <= tx_parity(d_width);        -- Latch in parity bit from parity logic
            END IF;
            tx_busy <= '1';                                           -- Assert transmit busy flag
            tx_count := 0;                                            -- Clear transmit bit count
            tx_state <= transmit;                                     -- Proceed to transmit state
          ELSE                                                      -- No new transaction initiated
            tx_busy <= '0';                                           -- Clear transmit busy flag
            tx_state <= idle;                                         -- Remain in idle state
          END IF;
        WHEN transmit =>                                          -- Transmit state
          IF(baud_pulse = '1') THEN                                 -- Beginning of bit
            tx_count := tx_count + 1;                                 -- Increment transmit bit counter
            tx_buffer <= '1' & tx_buffer(parity+d_width+1 DOWNTO 1);  -- Shift transmit buffer to output next bit
          END IF;
          IF(tx_count < parity+d_width+3) THEN                      -- Not all bits transmitted
            tx_state <= transmit;                                     -- Remain in transmit state
          ELSE                                                      -- All bits transmitted
            tx_state <= idle;                                         -- Return to idle state
          END IF;
      END CASE;
      tx <= tx_buffer(0);                                       -- Output last bit in transmit transaction buffer
    END IF;
  END PROCESS;  
  
  -- Transmit parity calculation logic
  tx_parity(0) <= parity_eo;
  tx_parity_logic: FOR i IN 0 to d_width-1 GENERATE
    tx_parity(i+1) <= tx_parity(i) XOR tx_data(i);
  END GENERATE;
  
END logic;
