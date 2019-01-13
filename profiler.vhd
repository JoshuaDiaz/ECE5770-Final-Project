library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
 
package RowOpInterface is -- component declaration package
	component profiler
		port(
			clk_100m0_i    : in std_logic;
			reset_i			: in std_logic := '1';
			row_addr_i		: in std_logic_vector(12 downto 0) := (others => '0');	-- Row addr
			bank_s_i			: in std_logic_vector(1 downto 0) := (others => '0');		-- Bank selector
			data_pattern_i : in std_logic_vector(15 downto 0) := (others => '1');	-- Data pattern to write in a row
			instr_i			: in std_logic_vector(1 downto 0) := (others => '0');		-- high for write / low for wait & read
			wait_cnt_i		: in std_logic_vector(17 downto 0) := (others => '0');	-- cycles to wait
			ready_o			: out std_logic := '0';
			done_o			: out std_logic := '0';
			--data_o			: out std_logic_vector(15 downto 0);
			compare_o		: out std_logic_vector(15 downto 0) := "1010101001010101";
			
			word_ready_o    : out std_logic := '0';
			
			-- refresh_i      : in std_logic := '0';		-- Initiate a refresh cycle, active high
			-- SDRAM side
			sdCke_o        : out std_logic;           -- Clock-enable to SDRAM
			sdCe_bo        : out std_logic;           -- Chip-select to SDRAM
			sdRas_bo       : out std_logic;           -- SDRAM row address strobe
			sdCas_bo       : out std_logic;           -- SDRAM column address strobe
			sdWe_bo        : out std_logic;           -- SDRAM write enable
			sdBs_o         : out std_logic_vector(1 downto 0);    -- SDRAM bank address
			sdAddr_o       : out std_logic_vector(12 downto 0);   -- SDRAM row/column address
			sdData_io      : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
			sdDqmh_o       : out std_logic;           -- Enable upper-byte of SDRAM databus if true
			sdDqml_o       : out std_logic            -- Enable lower-byte of SDRAM databus if true
			
		);
	end component;
end package;



library IEEE, UNISIM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use work.MemController.all;

entity profiler is
	generic (
        -- empty generic is not allowed
        DUMMY_PARAM: natural := 0
   );
	port(
		clk_100m0_i    : in std_logic;
		reset_i			: in std_logic := '1';
		row_addr_i		: in std_logic_vector(12 downto 0) := (others => '0');	-- Row addr
		bank_s_i			: in std_logic_vector(1 downto 0) := (others => '0');		-- Bank selector
		data_pattern_i : in std_logic_vector(15 downto 0) := (others => '1');	-- Data pattern to write in a row
		instr_i			: in std_logic_vector(1 downto 0) := (others => '0');		-- high for write / low for wait & read
		wait_cnt_i		: in std_logic_vector(17 downto 0) := (others => '0');	-- cycles to wait
		ready_o			: out std_logic := '0';
		done_o			: out std_logic := '0';
		--data_o			: out std_logic_vector(15 downto 0);
		compare_o		: out std_logic_vector(15 downto 0) := "1010101001010101";
		word_ready_o    : out std_logic := '0';
		
		
		-- refresh_i      : in std_logic := '0';		-- Initiate a refresh cycle, active high
		-- SDRAM side
		sdCke_o        : out std_logic;           -- Clock-enable to SDRAM
      sdCe_bo        : out std_logic;           -- Chip-select to SDRAM
      sdRas_bo       : out std_logic;           -- SDRAM row address strobe
      sdCas_bo       : out std_logic;           -- SDRAM column address strobe
      sdWe_bo        : out std_logic;           -- SDRAM write enable
      sdBs_o         : out std_logic_vector(1 downto 0);    -- SDRAM bank address
      sdAddr_o       : out std_logic_vector(12 downto 0);   -- SDRAM row/column address
      sdData_io      : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
      sdDqmh_o       : out std_logic;           -- Enable upper-byte of SDRAM databus if true
      sdDqml_o       : out std_logic            -- Enable lower-byte of SDRAM databus if true
		
	);
end entity;

architecture bhv of profiler is
	type fsm_state_type is (
   ST_INIT, ST_READY, ST_RD, ST_WR, ST_RF, ST_WAIT);
	signal curr_state : fsm_state_type := ST_INIT;
	signal rw : std_logic := '0';
	signal we : std_logic := '1';
	signal col_addr : std_logic_vector(8 downto 0);
	signal mem_ready : std_logic;
	signal wait_cnt : std_logic_vector(17 downto 0);
	signal word_ready : std_logic;
	signal data : std_logic_vector(15 downto 0);
	-- signal done : std_logic;
begin
	mc: sdram_simple port map (
		-- Host side
      clk_100m0_i, --clk_100m0_i    : in std_logic;            -- Master clock
      reset_i, --reset_i        : in std_logic := '0';     -- Reset, active high
      '0', --refresh_i      : in std_logic := '0';     -- Initiate a refresh cycle, active high
      rw, --rw_i           : in std_logic := '0';     -- Initiate a read or write operation, active high
      we, --we_i           : in std_logic := '0';     -- Write enable, active low
      bank_s_i & row_addr_i & col_addr, --addr_i         : in std_logic_vector(23 downto 0) := (others => '0');   -- Address from host to SDRAM
      data_pattern_i, --data_i         : in std_logic_vector(15 downto 0) := (others => '0');   -- Data from host to SDRAM
      '0', --ub_i           : in std_logic;            -- Data upper byte enable, active low
      '0', --lb_i           : in std_logic;            -- Data lower byte enable, active low
      mem_ready, --ready_o        : out std_logic := '0';    -- Set to '1' when the memory is ready
      word_ready, --done_o         : out std_logic := '0';    -- Read, write, or refresh, operation is done
      data, --data_o         : out std_logic_vector(15 downto 0);   -- Data from SDRAM to host
 
      -- SDRAM side
		sdCke_o,
      sdCe_bo,
      sdRas_bo,
      sdCas_bo,
      sdWe_bo,
      sdBs_o,
      sdAddr_o,
      sdData_io,
      sdDqmh_o,
      sdDqml_o
	);
	process (word_ready)
	begin
		word_ready_o <= word_ready;
	end process;
	
	process (clk_100m0_i)
   begin
      if rising_edge(clk_100m0_i) then
		
      if reset_i = '0' then
         curr_state <= ST_INIT;
			ready_o <= '0';
			done_o <= '0';
			rw <= '0';
			we <= '1';
      else
			case curr_state is
			when ST_INIT =>
				if mem_ready = '1' then
					curr_state <= ST_READY;
					ready_o <= '1';
					done_o <= '0';	
				else
					curr_state <= ST_INIT;
					ready_o <= '0';
					done_o <= '0';
				end if;
				rw <= '0';
				we <= '1';
			
			when ST_READY =>
				case instr_i is
				when "00" => -- NOP
					if wait_cnt_i = 0 then
						curr_state <= ST_READY;
						rw <= '0';
						we <= '1';
						ready_o <= '1';
						done_o <= '0';
					else
						curr_state <= ST_WAIT;
						rw <= '0';
						we <= '1';
						done_o <= '0';
						wait_cnt <= wait_cnt_i;
					end if;
				
				when "01" => -- refresh
					curr_state <= ST_RF;
					rw <= '1';
					we <= '1';
					ready_o <= '0';
					done_o <= '0';
					col_addr <= (others => '1');
					
				when "10" => -- read
					curr_state <= ST_RD;
					rw <= '1';
					we <= '1';
					ready_o <= '0';
					done_o <= '0';
					col_addr <= (others => '1');
				
				when "11" => -- write
					curr_state <= ST_WR;
					rw <= '1';
					we <= '0';
					ready_o <= '0';
					done_o <= '0';
					col_addr <= (others => '1');
				end case;
				
			when ST_WAIT =>
				rw <= '0';
				we <= '1';
				ready_o <= '0';
				done_o <= '0';
				if wait_cnt = 0 then
					ready_o <= '1';
					done_o <= '1';
					curr_state <= ST_READY;
				else
					wait_cnt <= (wait_cnt - 1);
					curr_state <= ST_WAIT;
				end if;
				
			when ST_RD =>
				curr_state <= ST_RD;
				rw <= '1';
				we <= '1';
				ready_o <= '0';
				done_o <= '0';
				if word_ready = '1' then
					compare_o <= (data xor data_pattern_i);
					if col_addr = 0 then
						curr_state <= ST_INIT;
						ready_o <= '1';
						done_o <= '1';
					else
						col_addr <= (col_addr - 1);
					end if;
				end if;
				
			when ST_WR =>
				curr_state <= ST_WR;
				rw <= '1';
				we <= '0';
				ready_o <= '0';
				done_o <= '0';
				if word_ready = '1' then
					if col_addr = 0 then
						curr_state <= ST_INIT;
						ready_o <= '1';
						done_o <= '1';
					else
						col_addr <= (col_addr - 1);
					end if;
				end if;
				
			when ST_RF =>
				curr_state <= ST_RF;
				rw <= '1';
				we <= '0';
				ready_o <= '0';
				done_o <= '0';
				if word_ready = '1' then
					curr_state <= ST_INIT;
					ready_o <= '1';
					done_o <= '1';
				end if;
			end case;
		
		
         
 
      end if;
      end if;
   end process;
	
end architecture;