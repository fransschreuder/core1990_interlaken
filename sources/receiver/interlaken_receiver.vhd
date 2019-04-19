library ieee; 
use ieee.std_logic_1164.all;
library work;

entity Interlaken_Receiver is
    generic (
        --channelnumber : integer;
        PacketLength : positive
    );
	port (
	    fifo_read_clk	: in std_logic;
		clk   		    : in std_logic;
		reset 		    : in std_logic;
		
		RX_Data_In 	: in std_logic_vector(66 downto 0);
		RX_Data_Out : out std_logic_vector (63 downto 0);        -- Data ready to transmit
		
		RX_Valid_Out: out std_logic;
		
		--RX_Enable    	: out std_logic;      --not used                   -- Enable the TX
		RX_SOP        	: out std_logic;                         -- Start of Packet
		RX_EOP_Valid 	: out std_logic_vector(2 downto 0);      -- Valid bytes packet contains
		RX_EOP        	: out std_logic;                         -- End of Packet
		RX_FlowControl	: out std_logic_vector(15 downto 0);     -- Flow control data (yet unutilized)
		RX_prog_full    : out std_logic_vector(15 downto 0);     -- Indication FIFO of this channel is full
		RX_Channel    	: out std_logic_vector(7 downto 0);      -- Select transmit channel (yet unutilized)
		RX_Datavalid    : in std_logic;
		
		CRC24_Error       : out std_logic;
		CRC32_Error       : out std_logic;
		Decoder_lock      : out std_logic;
		Descrambler_lock  : out std_logic;
		
		Data_Descrambler : out std_logic_vector(66 downto 0);
		Data_Decoder     : out std_logic_vector(66 downto 0);
		
		RX_FIFO_Full         : out std_logic;
		RX_FIFO_Empty        : out std_logic;
		RX_FIFO_Read         : in std_logic;
		
		RX_Link_Up      : out std_logic;
		
		Bitslip         : out std_logic
	);
end entity Interlaken_Receiver;

architecture Receiver of Interlaken_Receiver is
    type state_type is (IDLE, DATA);
	signal pres_state, next_state: state_type;
	
    signal FIFO_Read_Count, FIFO_Write_Count : std_logic_vector(5 downto 0);
    signal FIFO_prog_full, FIFO_prog_empty  : std_logic;
    signal FIFO_Data_Out : std_logic_vector(68 downto 0);
    
    COMPONENT RX_FIFO
		PORT (
            rst : IN STD_LOGIC;
            wr_clk : IN STD_LOGIC;
            rd_clk : IN STD_LOGIC;
            din : IN STD_LOGIC_VECTOR(68 DOWNTO 0);
            wr_en : IN STD_LOGIC;
            rd_en : IN STD_LOGIC;
            dout : OUT STD_LOGIC_VECTOR(68 DOWNTO 0);
            full : OUT STD_LOGIC;
            empty : OUT STD_LOGIC;
            rd_data_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
            wr_data_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
            prog_full : OUT STD_LOGIC;
            prog_empty : OUT STD_LOGIC;
            valid : OUT STD_LOGIC
		);
    END COMPONENT;
    
    signal Data_Burst_Out : std_logic_vector(68 downto 0);
    
    signal RX_FIFO_Data : std_logic_vector(68 downto 0);
    signal RX_FIFO_Write : std_logic;
    signal Data_valid_Burst_Out : std_logic;
    signal Flowcontrol : std_logic_vector (15 downto 0);
    --signal FIFO_empty : std_logic;
    
    signal Data_Meta_Out : std_logic_vector(66 downto 0);
    signal Data_Descrambler_Out : std_logic_vector(66 downto 0);
    signal Data_Control_Descrambler_Out : std_logic;
    signal Data_control_Meta_out : std_logic;
    signal Data_valid_Meta_out : std_logic;
    
    signal Data_Decoder_Out : std_logic_vector(66 downto 0);
    signal Data_Control_Decoder_Out, Data_valid_decoder_out : std_logic;
    signal Data_valid_Descrambler_out : std_logic;
    signal Lane_Number : std_logic_vector(3 downto 0);
    signal Error_BadSync : std_logic;
    signal Error_StateMismatch : std_logic;
    signal Error_NoSync : std_logic;
    signal Error_Decoder_Sync : std_logic;
    signal Descrambler_In_lock: std_logic;
    -- signal FIFO_dout_valid : std_logic;
    
begin
    
    RX_prog_full(0) <= not FIFO_prog_full;
    RX_prog_full(15 downto 1) <= (others => '0');
    --RX_FlowControl       <= FlowControl; --RX_FlowControl(channelnumber) <= FIFO_prog_full;

    FIFO_Receiver : RX_FIFO
    port map (
        rst             => Reset,
        wr_clk          => clk,
        rd_clk          => fifo_read_clk,
        din             => RX_FIFO_Data,
        wr_en           => RX_FIFO_Write,
        rd_en           => RX_FIFO_Read,
        dout            => FIFO_Data_Out,
        full            => RX_FIFO_Full,
        empty           => RX_FIFO_Empty,
        rd_data_count   => FIFO_Read_Count,
        wr_data_count   => FIFO_Write_Count,
        prog_full       => FIFO_prog_full,
        prog_empty      => FIFO_prog_empty,
        valid           => RX_Valid_Out
    );
    
    Deframing_Burst : entity work.Burst_Deframer
    port map (
        clk         => clk,
        reset       => reset,
        
        Data_in          => Data_Meta_Out,
        Data_out         => Data_Burst_Out(63 downto 0),
        
        SOP              => Data_Burst_Out(68),--: out std_logic;
        EOP              => Data_Burst_Out(67),--: out std_logic;
        EOP_valid        => Data_Burst_Out(66 downto 64),--: out std_logic_vector(2 downto 0);
        
       -- Data_control_in  => Data_Control_Meta_Out,
        
        Flowcontrol => RX_Flowcontrol,
        CRC24_Error => CRC24_Error,
        
        Data_valid_in   => Data_valid_Meta_Out,
        Data_valid_out  => Data_valid_Burst_Out
    );
    RX_FIFO_Write <= Data_valid_Burst_Out;
    RX_FIFO_Data <= Data_Burst_Out;
           
    Deframing_Meta : entity work.Meta_Deframer
    port map (
        clk         => clk,
        reset       => reset,
        
        CRC32_Error => CRC32_Error,
        
        Data_in          => Data_Descrambler_Out,
        Data_out         => Data_Meta_Out,
       -- Data_control_in  => Data_Control_Descrambler_Out,
        --Data_control_out => Data_control_Meta_out,
        Data_valid_in    => Data_valid_Descrambler_out,
        Data_valid_out   => Data_valid_Meta_out
    );
    
    Data_Descrambler <= Data_Descrambler_Out;
    Data_Decoder <= Data_Decoder_Out;
    
    Descrambler : entity work.Descrambler 
    generic map (
        PacketLength => PacketLength
    )
    port map (
        clk     => clk,
        reset   => reset,
        
        Data_in          => Data_Decoder_Out,
        Data_out         => Data_Descrambler_Out,
        --Data_control_In  => Data_Control_Decoder_Out,
        --Data_control_Out => Data_control_Descrambler_Out,
        Data_valid_in    => Data_valid_decoder_out,
        Data_valid_out   => Data_valid_Descrambler_out,
        Lock             => Descrambler_In_lock,
        
        Lane_Number => "0001",
        
        Error_BadSync       => Error_BadSync,
        Error_StateMismatch => Error_StateMismatch,
        Error_NoSync        => Error_NoSync
    );
    
    Descrambler_Lock <= Descrambler_In_lock;
    
    sync_proc: process(fifo_read_clk)
    begin
        if rising_edge(fifo_read_clk) then
            RX_Link_Up <= Descrambler_In_lock;
        end if;
    end process;
    
        
    Decoder : entity work.Decoder 
    port map (
        clk         => clk,
        reset       => reset,
        Decoder_En  => '1',
        
        Data_in       => RX_Data_In,
        Data_out      => Data_Decoder_Out,
        Data_Valid_In => RX_Datavalid,
        Data_Valid_Out => Data_valid_decoder_out,
        Data_control  => Data_control_Decoder_Out,
        
        Sync_Locked => Decoder_lock,
        Sync_error  => Error_Decoder_Sync,
        Bitslip     => Bitslip
    );
    
--    linkup_proc: process(clk)
--        variable link_up_p1: std_logic;
--    begin
--        if rising_edge(clk) then
--            RX_Link_Up <= Data_Valid_Descrambler_Out or link_up_p1;
--            link_up_p1 := Data_Valid_Descrambler_Out;
--        end if;
--    end process;
    
    output : process (fifo_read_clk, reset) is
    begin
        if (reset = '1') then
            RX_Data_Out <= (others => '0');
        elsif (rising_edge(fifo_read_clk)) then
            RX_SOP <= FIFO_Data_Out(68);
            RX_EOP <= FIFO_Data_Out(67);
            RX_EOP_Valid <= FIFO_Data_Out(66 downto 64);
            RX_Data_Out <= FIFO_Data_Out(63 downto 0);
        end if;
    end process output;
    
--    state_register : process (clk) is 
--    begin
--       if (rising_edge(clk)) then
--           pres_state <= next_state;
--       end if;
--    end process state_register;
    
--    state_decoder : process (pres_state, Data_Burst_Out) is
--    begin
--       case pres_state is
--       when IDLE =>
--           if  (Data_Burst_Out(65) = '1') then
--               next_state <= DATA;
--           else
--               next_state <= IDLE;
--           end if;
           
--       when DATA =>
--           if(Data_Burst_Out(64) = '1') then
--               next_state <= IDLE;
--           else
--               next_state <= DATA;
--           end if;
--       when others =>
--           next_state <= IDLE;
--       end case;
--    end process state_decoder;
    
--    fifo_out : process(fifo_empty) is
--    begin
--        RX_fifo_read <= '0';
--        if(fifo_empty = '0') then
--            RX_fifo_read <= '1';
--        end if;
--    end process;
    
--    output_state : process (pres_state, clk) is
--    begin
--        if rising_edge(clk) then
--            case pres_state is
--            when IDLE =>
--                RX_FIFO_Write <= '0';
--                RX_FIFO_Data <= (others => '0');
--                if  (Data_Burst_Out(65) = '1') then
--                    RX_FIFO_Write <= Data_valid_Burst_Out;
--                    RX_FIFO_Data <= Data_Burst_Out;                
--                end if;
               
--            when DATA =>
--                RX_FIFO_Write <= Data_valid_Burst_Out;
--                RX_FIFO_Data <= Data_Burst_Out;                
--            end case;
--        end if;
--    end process output_state;

end architecture Receiver;
