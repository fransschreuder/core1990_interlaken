library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.ALL; 
use work.interlaken_package.all;

entity Descrambler is 
	generic (
		PacketLength : positive
	);
	port ( 
		Clk				: in std_logic;			              -- System clock
		Reset			: in std_logic;			              -- Descrambler reset, use for initialization
		
		Data_In 		: in std_logic_vector (66 downto 0);  -- Data input
		Data_Out 		: out std_logic_vector (66 downto 0); -- Data output
		
		Lane_Number		: in std_logic_vector (3 downto 0);   -- Each lane number starts with different scrambler word
		Data_Valid_In   : in std_logic;                       -- 
		Data_Valid_Out  : out std_logic;                      -- Output data is valid for the next component/in lock
		Lock            : out std_logic;
        
        Error_BadSync 		: out std_logic; 	-- Bad sync words after being in lock
        Error_StateMismatch : out std_logic; 	-- Scrambler state mismatches occured more than three times
        Error_NoSync 		: out std_logic 	-- Bad sync and not been in lock
       
	);
end Descrambler;

architecture behavior of Descrambler is 
	type state_type is (IDLE, SYNC, LOCKED);
	signal pres_state : state_type;
	
	signal MetaCounter : integer range 0 to PacketLength;
	signal Sync_Word_Detected : std_logic;
	signal Sync_Words : integer range 0 to 3;
	signal ScramblerSyncMismatch : std_logic;
	
	signal Data_Valid_P1, Data_Valid_P2, Data_Valid : std_logic;
	signal Data_P1, Data_Descrambled : std_logic_vector(63 downto 0);
	
	signal Data_In_P1 : std_logic_vector(66 downto 0); ---
	signal scram_state_word_detected : std_logic; ---
	
	signal Scrambler_State_Mismatch : integer range 0 to 3;
    signal Sync_Word_Mismatch : integer range 0 to 4;
	
	signal Poly : std_logic_vector (57 downto 0);
	signal Shiftreg : std_logic_vector (63 downto 0);	
	signal Data_HDR_P1, Data_HDR : std_logic_vector(2 downto 0);
   

begin
	shiftreg(63) <= Poly(57) xor Poly(38);
    shiftreg(62) <= Poly(56) xor Poly(37);
    shiftreg(61) <= Poly(55) xor Poly(36);
    shiftreg(60) <= Poly(54) xor Poly(35);
    shiftreg(59) <= Poly(53) xor Poly(34);
    shiftreg(58) <= Poly(52) xor Poly(33);
    shiftreg(57) <= Poly(51) xor Poly(32);
    shiftreg(56) <= Poly(50) xor Poly(31);
    shiftreg(55) <= Poly(49) xor Poly(30);
    shiftreg(54) <= Poly(48) xor Poly(29);
    shiftreg(53) <= Poly(47) xor Poly(28);
    shiftreg(52) <= Poly(46) xor Poly(27);
    shiftreg(51) <= Poly(45) xor Poly(26);
    shiftreg(50) <= Poly(44) xor Poly(25);
    shiftreg(49) <= Poly(43) xor Poly(24);
    shiftreg(48) <= Poly(42) xor Poly(23);
    shiftreg(47) <= Poly(41) xor Poly(22);
    shiftreg(46) <= Poly(40) xor Poly(21);
    shiftreg(45) <= Poly(39) xor Poly(20);
    shiftreg(44) <= Poly(38) xor Poly(19);
    shiftreg(43) <= Poly(37) xor Poly(18);
    shiftreg(42) <= Poly(36) xor Poly(17);
    shiftreg(41) <= Poly(35) xor Poly(16);
    shiftreg(40) <= Poly(34) xor Poly(15);
    shiftreg(39) <= Poly(33) xor Poly(14);
    shiftreg(38) <= Poly(32) xor Poly(13);
    shiftreg(37) <= Poly(31) xor Poly(12);
    shiftreg(36) <= Poly(30) xor Poly(11);
    shiftreg(35) <= Poly(29) xor Poly(10);
    shiftreg(34) <= Poly(28) xor Poly(9);
    shiftreg(33) <= Poly(27) xor Poly(8);
    shiftreg(32) <= Poly(26) xor Poly(7);
    shiftreg(31) <= Poly(25) xor Poly(6);
    shiftreg(30) <= Poly(24) xor Poly(5);
    shiftreg(29) <= Poly(23) xor Poly(4);
    shiftreg(28) <= Poly(22) xor Poly(3);
    shiftreg(27) <= Poly(21) xor Poly(2);
    shiftreg(26) <= Poly(20) xor Poly(1);
    shiftreg(25) <= Poly(19) xor Poly(0);
    shiftreg(24) <= Poly(57) xor Poly(38) xor Poly(18);
    shiftreg(23) <= Poly(56) xor Poly(37) xor Poly(17);
    shiftreg(22) <= Poly(55) xor Poly(36) xor Poly(16);
    shiftreg(21) <= Poly(54) xor Poly(35) xor Poly(15);
    shiftreg(20) <= Poly(53) xor Poly(34) xor Poly(14);
    shiftreg(19) <= Poly(52) xor Poly(33) xor Poly(13);
    shiftreg(18) <= Poly(51) xor Poly(32) xor Poly(12);
    shiftreg(17) <= Poly(50) xor Poly(31) xor Poly(11);
    shiftreg(16) <= Poly(49) xor Poly(30) xor Poly(10);
    shiftreg(15) <= Poly(48) xor Poly(29) xor Poly(9);
    shiftreg(14) <= Poly(47) xor Poly(28) xor Poly(8);
    shiftreg(13) <= Poly(46) xor Poly(27) xor Poly(7);
    shiftreg(12) <= Poly(45) xor Poly(26) xor Poly(6);
    shiftreg(11) <= Poly(44) xor Poly(25) xor Poly(5);
    shiftreg(10) <= Poly(43) xor Poly(24) xor Poly(4);
    shiftreg(9) <= Poly(42) xor Poly(23) xor Poly(3);
    shiftreg(8) <= Poly(41) xor Poly(22) xor Poly(2);
    shiftreg(7) <= Poly(40) xor Poly(21) xor Poly(1);
    shiftreg(6) <= Poly(39) xor Poly(20) xor Poly(0);
    shiftreg(5) <= Poly(57) xor Poly(19);
    shiftreg(4) <= Poly(56) xor Poly(18);
    shiftreg(3) <= Poly(55) xor Poly(17);
    shiftreg(2) <= Poly(54) xor Poly(16);
    shiftreg(1) <= Poly(53) xor Poly(15);
    shiftreg(0) <= Poly(52) xor Poly(14);
    
	detection : process (Clk, Reset) is
	begin
		if(Reset = '1') then            
            Sync_Word_Detected <= '0';
		elsif (rising_edge(clk)) then
			if (Data_In(65 downto 64) = "10") and (Data_In(63 downto 0) = SYNCHRONIZATION) then
				Sync_Word_Detected <= '1';
			else 
				Sync_Word_Detected <= '0';
			end if;
		end if;
	end process detection;
	
	data : process (clk, reset) is 
    begin
        if (reset = '1') then
            Data_Out <= (others => '0');
        elsif (rising_edge(clk)) then
            Data_Out  <= Data_HDR_P1 & Data_P1;
            Data_Valid_Out <= Data_Valid_P1;
            Data_Valid_P1<= Data_Valid;
        end if;
    end process data;
	
--	state_register : process (clk) is
--    begin
--        if (rising_edge(clk)) then
--            pres_state <= next_state;
--        end if;
--    end process state_register;
    
--    state_decoder : process (pres_state, Sync_Word_Detected, MetaCounter, Sync_words, ScramblerSyncMismatch) is
--    begin
--        case pres_state is
--        when IDLE =>
--			if(Sync_Word_Detected = '1') then
--				next_state <= SYNC;
--			else
--				next_state <= IDLE;
--			end if;
--		when SYNC =>
--			if(Sync_Words = 3 and Sync_Word_Detected = '1') then
--				next_state <= LOCKED;
--			elsif(Sync_Words = 0) then
--				next_state <= IDLE;
--			else 
--			    next_state <= SYNC;
--			end if;
--		when LOCKED =>
--			if(ScramblerSyncMismatch = '1') then
--				next_state <= IDLE;
--			else
--				next_state <= LOCKED;
--			end if;
--        when others =>
--            next_state <= IDLE;
--        end case;
--    end process state_decoder;

    output : process (clk) is
    begin
        if rising_edge(clk) then
            lock <= '0';
            case pres_state is
            when IDLE =>
                Data_P1 <= (others => '0'); -- Reset data registers and polynomial
                Data_Descrambled <= (others => '0');
				Poly <= (others => '1');
				Poly(57 downto 54) <= Lane_Number(3 downto 0);
				
				Error_StateMismatch <= '0'; -- Reset error conditions
				Error_NoSync <= '0';
				Error_BadSync <= '0';
				
				MetaCounter <= 0;           -- Reset other values
				Data_HDR <= Data_In(66)&"10";
				Data_HDR_P1 <= Data_In(66)&"10";
				
				ScramblerSyncMismatch <= '0';
				Scrambler_State_Mismatch <= 0;
				Sync_Word_Mismatch <= 0;
				Data_Valid <= '0';
				
				if(Sync_Word_Detected = '1') then
				    MetaCounter <= 1;
				    Sync_Words <= Sync_Words + 1;
				    pres_state <= SYNC;
				end if;
				
			when SYNC =>
			    if (Data_Valid_In = '1') then
			        	    
                    MetaCounter <= MetaCounter + 1;
                    if(MetaCounter = 0) then
                    --if Data_In(63 downto 0) = SYNCHRONIZATION then
                        if(Sync_Word_Detected = '1') then --First position in metaframe should contain sync
                            Sync_Words <= Sync_Words + 1;
                            if(Sync_Words = 3) then 
                                Sync_Words <= 0;
                                Data_Descrambled <= SCRAM_STATE_INIT_VALUE;--X"2800_0000_0000_0000"; 
                                Data_P1 <= SYNCHRONIZATION;
                                Data_HDR <= Data_In(66)&"10";
                                Data_HDR_P1 <= Data_In(66)&"10";
                                Poly <= Data_In(57 downto 0);  -- Scrambler state in poly
                                pres_state <= LOCKED;
                            end if;
                        else
                            Error_NoSync <= '1';
                            pres_state <= IDLE;
                        end if;
                    end if;
                    
                    if(MetaCounter = (PacketLength-1)) then
                        MetaCounter <= 0;
                    end if;
                end if;
                if Sync_Words = 0 then
                    pres_state <= IDLE;
                end if;

            when LOCKED => 
                Lock <= '1';
                Data_Valid <= '0';
                Data_P1  <= Data_Descrambled;
                Data_HDR_P1  <= Data_HDR;
                
                scram_state_word_detected <= '0';
                
                if (Data_Valid_In = '1') then
                    Data_Valid <= '1';
                    MetaCounter <= MetaCounter + 1;
                    Data_HDR <= Data_In(66 downto 64);
                    --Data_In_P1 <= Data_In; ---
                    if (Data_in(65 downto 64) = "10" and Data_In(63) = '0' and 
                        MetaCounter = 0 and
                        ((Data_In(62 downto 58) = META_TYPE_SCRAM_STATE_P ) or 
                        (Data_In(62 downto 58) = META_TYPE_SCRAM_STATE_N ))
                        ) then
                        scram_state_word_detected <= '1';
                        Poly <= Data_In(57 downto 0);
                        Data_Descrambled <= Data_In(63 downto 0); 
                        if(Data_In(57 downto 0) /= Poly) then
                        --if(Data_In_P1(57 downto 0) /= Poly) then ---
                            Scrambler_State_Mismatch <= Scrambler_State_Mismatch + 1;
                            if(Scrambler_State_Mismatch = 2) then
                                ScramblerSyncMismatch <= '1';
                                Error_StateMismatch <= '1';
                                Scrambler_State_Mismatch <= 0;
                                Sync_Words <= 0;
                                pres_state <= IDLE;
                            end if;
                        end if;
                    elsif (Data_in(65 downto 64) = "10" and Data_In(63) = '0' and 
                        Data_In(63 downto 0) = SYNCHRONIZATION ) then
                        --((Data_In(62 downto 58) = META_TYPE_SYNCHRONIZATION_P and Data_In(66) = '0') or 
                        --(Data_In(62 downto 58) = META_TYPE_SYNCHRONIZATION_N and Data_In(66) = '1'))
                        --) then
                        MetaCounter <= 0;
                                            
                        if(MetaCounter /= (PacketLength-1)) then
                            Sync_Word_Mismatch <= Sync_Word_Mismatch + 1;
                            if(Sync_Word_Mismatch = 3) then
                                Error_BadSync <= '1';
                                Sync_Word_Mismatch <= 0;
                                ScramblerSyncMismatch <= '1';
                                pres_state <= IDLE;
                            end if;
                        end if;
                        Data_Descrambled <= Data_in(63 downto 0);
                    else  -- No Synchronization or scrambler state detected, apply descrambler to data and update Poly
                        Poly <= shiftreg(57 downto 0);
                        Data_Descrambled <= Data_In(63 downto 0) xor (Poly(57 downto 0) & Shiftreg(63 downto 58));
                    end if;
                    


                end if;
            when others =>
                pres_state <= IDLE;
            end case;
        end if;
    end process output;
	
end architecture behavior;