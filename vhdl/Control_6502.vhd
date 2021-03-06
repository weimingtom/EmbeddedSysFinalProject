------------------------------------------------------------------------------
------------------------------------------------------------------------------
--
--  COMS W480 Final Project
--    Sprint 2013
--    A 6502 CPU reconstructed in VHDL and synthesized on the Altera DE2
--
--
-- Team Double O Four is:
--     Yu Chen
--     Jaebin Choi
--     Anthony Erlinger
--     Arthy Padma Anandhi Sundaram
--
--
-- 6502 Control Interface
--
--
------------------------------------------------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity PC_6502 is
	port(
		IR				: in std_logic_vector(7 downto 0);	-- Instruction state
		MCycle			: in std_logic_vector(2 downto 0);	-- What timing cycle are we in?
		P				: in std_logic_vector(7 downto 0);	-- Processor status register
		LCycle			: out std_logic_vector(2 downto 0);	-- ???
		ALU_Op			: out std_logic_vector(3 downto 0);	-- Opcode for the ALU
		Set_BusA_To		: out std_logic_vector(2 downto 0); -- DI, A, X, Y, S, P
		Set_Addr_To		: out std_logic_vector(1 downto 0); -- PC Adder, S, AD, BA
		Write_Data		: out std_logic_vector(2 downto 0); -- DL, A, X, Y, S, P, PCL, PCH
		Jump			: out std_logic_vector(1 downto 0); -- PC, ++, DIDL, Rel
		BAAdd			: out std_logic_vector(1 downto 0);	-- None, DB Inc, BA Add, BA Adj
		BreakAtNA		: out std_logic;	-- ???
		ADAdd			: out std_logic;	-- ???
		PCAdd			: out std_logic;	-- Program counter add
		Inc_S			: out std_logic;	-- Increment Stack
		Dec_S			: out std_logic;	-- Decrement Stack
		LDA				: out std_logic;	-- Load Accumulator
		LDP				: out std_logic;	-- Load Processor status register
		LDX				: out std_logic;	-- Load X Register
		LDY				: out std_logic;	-- Load Y Register
		LDS				: out std_logic;	-- Load Stack Register
		LDDI			: out std_logic;	-- Load (I_ADDC?)
		LDALU			: out std_logic;	-- Load Allue
		LDAD			: out std_logic;	
		LDBAL			: out std_logic;	-- Load Address Bus Low
		LDBAH			: out std_logic;	-- Load Address Bus High
		SaveP			: out std_logic;	-- Save processor status
		Write			: out std_logic
	);
end PC_6502;

architecture rtl of PC_6502 is
	signal Branch : std_logic;
begin

	-- What is the branch condition?
	with IR(7 downto 0) select

		Branch <= 
			not P(Flag_N) 	when "000",
			P(Flag_N) 		when "001",
			not P(Flag_V) 	when "010",
			P(Flag_V) 		when "011",
			not P(Flag_C) 	when "100",
			P(Flag_C) 		when "101",
			not P(Flag_C) 	when "110",
			P(Flag_Z) 		when others;

	process (IR,  MCycle, P, Branch)
	begin

		-- Initial values are set to:
		LCycle 		<= "001";
		Set_BusA_To <= "001"; -- A (A initially points to A reg.)
		Set_Addr_To <= (others => '0');
		Write_Data 	<= (others => '0');
		Jump 		<= (others => '0');
		BAAdd 		<= "00";
		BreakAtNA 	<= '0';
		ADAdd 		<= '0';
		PCAdd 		<= '0';
		Inc_S 		<= '0';
		Dec_S 		<= '0';
		LDA 		<= '0';
		LDP 		<= '0';
		LDX 		<= '0';
		LDY 		<= '0';
		LDS 		<= '0';
		LDDI 		<= '0';
		LDALU 		<= '0';
		LDAD 		<= '0';
		LDBAL 		<= '0';
		LDBAH 		<= '0';
		SaveP 		<= '0';
		Write 		<= '0';

		-- OPCODE MASK:


		-- XXX00000
		case IR(7 downto 5) is

		when "100" =>
			case IR(1 downto 0) is
			when "00" =>
				Set_BusA_To <= "011";	-- SET TO Y!
				Write_Data	<= "011";	-- SET TO Y
			when "10" =>
				Set_BusA_To <= "010";	-- SET TO X!
				Write_Data 	<= "010";	-- SET TO X
			when others =>
				Write_Data <= "001";	-- SET TO A
			end case;

		when "101" =>
			case IR(1 downto 0) is
			when "00" =>
				if IR(4) /= '1' or IR(2) /= '0' then
					LDY <= '1';
				end if;
			when "10" =>
				LDX <= '1';
			when others =>
				LDA <= '1';
			end case;
			Set_BusA_To <= "000";		-- Data Input register

		when "110" =>
			case IR(1 downto 0) is
			when  "00" =>
				if IR(4) = '0' then
					LDY <= '1';
				end if;
				Set_BusA_To <= "011"; 	-- Y Register
			when others =>
				Set_BusA_To <= "001";	-- Accumulator
			end case;

		when "111" =>
			case IR(1 downto 0) is
			when "00" =>
				if IR(4) = '0' then
					LDX <= '1';
				end if;
				Set_BusA_To <= "010"; 	-- X Register
			when other =>
				Set_BusA_To <= "001";	-- Accumulator
			end case;

		when others =>
		end case;

		if IR(7 downto 6) /= "10" and IR(1 downto 0) = "10" then
			Set_BusA_To <= "000";	-- Data Input Register
		end if;

		case IR(4 downto 0) is
		when "00000" | "01000" | "01010" | "11000" | "11010" =>
			-- Implied mode
			case IR is

			-- BRK 
			when "00000000" =>
				LCycle <= "110";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Set_Addr_To <= "01"; -- S
					Write_Data <= "111"; -- PCH
					Write <= '1';
				when 2 =>
					Dec_S <= '1';
					Set_Addr_To <= "01"; -- S
					Write_Data <= "110"; -- PCL
					Write <= '1';
				when 3 =>
					Dec_S <= '1';
					Set_Addr_To <= "01"; -- S
					Write_Data <= "101"; -- P
					Write <= '1';
				when 4 =>
					Dec_S <= '1';
					Set_Addr_To <= "11"; -- BA
				when 5 =>
					LDDI <= '1';
					Set_Addr_To <= "11"; -- BA
				when 6 =>
					Jump <= "10"; -- DIDL
				when others =>
				end case;

			-- JSR
			when "00100000" =>
				LCycle <= "101";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Jump <= "01";
					LDDI <= '1';
					Set_Addr_To <= "01"; -- S
				when 2 =>
					Set_Addr_To <= "01"; -- S
					Write_Data <= "111"; -- PCH
					Write <= '1';
				when 3 =>
					Dec_S <= '1';
					Set_Addr_To <= "01"; -- S
					Write_Data <= "110"; -- PCL
					Write <= '1';
				when 4 =>
					Dec_S <= '1';
				when 5 =>
					Jump <= "10"; -- DIDL
				when others =>
				end case;

			-- RTI
			when "01000000" =>
				LCycle <= "101";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Set_Addr_To <= "01"; -- S
				when 2 =>
					Inc_S <= '1';
					Set_Addr_To <= "01"; -- S
				when 3 =>
					Inc_S <= '1';
					Set_Addr_To <= "01"; -- S
					Set_BusA_To <= "000"; -- DI
				when 4 =>
					LDP <= '1';
					Inc_S <= '1';
					LDDI <= '1';
					Set_Addr_To <= "01"; -- S
				when 5 =>
					Jump <= "10"; -- DIDL
				when others =>
				end case;

			-- RTS
			when "01100000" =>
				
				LCycle <= "101";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Set_Addr_To <= "01"; -- S
				when 2 =>
					Inc_S <= '1';
					Set_Addr_To <= "01"; -- S
				when 3 =>
					Inc_S <= '1';
					LDDI <= '1';
					Set_Addr_To <= "01"; -- S
				when 4 =>
					Jump <= "10"; -- DIDL
				when 5 =>
					Jump <= "01";
				when others =>
				end case;

			-- PHP, PHA, PHY*, PHX*
			when "00001000" | "01001000" | "01011010" | "11011010" =>

				LCycle <= "010";
				if IR(1) = '1' then -- if Mode = "00" and IR(1) = '1' then
					LCycle <= "001";
				end if;
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					case IR(7 downto 4) is
					when "0000" =>
						Write_Data <= "101"; -- P
					when "0100" =>
						Write_Data <= "001"; -- A
					when "0101" =>
						Write_Data <= "011"; -- Y
					when "1101" =>
						Write_Data <= "010"; -- X
					when others =>
					end case;
					Write <= '1';
					Set_Addr_To <= "01"; -- S
				when 2 =>
					Dec_S <= '1';
				when others =>
				end case;

			-- LDY, CPY, CPX
			when "10100000" | "11000000" | "11100000" =>
				-- Immediate
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Jump <= "01";
				when others =>
				end case;

			-- DEY
			when "10001000" =>
				LDY <= '1';
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Set_BusA_To <= "011"; -- Y
				when others =>
				end case;

			-- DEX
			when "11001010" =>
				LDX <= '1';
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Set_BusA_To <= "010"; -- X
				when others =>
				end case;

			-- INC*, DEC*
			when "00011010" | "00111010" =>
				--if Mode /= "00" then
				--	LDA <= '1'; -- A
				--end if;
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Set_BusA_To <= "100"; -- S
				when others =>
				end case

			-- ASL, ROL, LSR, ROR
			when "00001010" | "00101010" | "01001010" | "01101010" =>
				LDA <= '1'; 			-- A
				Set_BusA_To <= "001"; 	-- A
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
				when others =>
				end case;

			-- TYA, TXA
			when "10001010" | "10011000" =>
				LDA <= '1'; -- A
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
				when others =>
				end case;

			-- TAX, TAY
			when "10101010" | "10101000" =>
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Set_BusA_To <= "001"; -- A
				when others =>
				end case;

			when "10011010" =>
				-- TXS
				case to_integer(unsigned(MCycle)) is
				when 0 =>
					LDS <= '1';
				when 1 =>
				when others =>
				end case;

			when "10111010" =>
				-- TSX
				LDX <= '1';
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Set_BusA_To <= "100"; -- S
				when others =>
				end case;

			when others =>
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when others =>
				end case;
			end case;

		when "00001" | "00011" =>
			-- Zero Page Indexed Indirect (d,x)
			LCycle <= "101";
			if IR(7 downto 6) /= "10" then
				LDA <= '1';
			end if;
			case to_integer(unsigned(MCycle)) is
			when 0 =>
			when 1 =>
				Jump <= "01";
				LDAD <= '1';
				Set_Addr_To <= "10"; -- AD
			when 2 =>
				ADAdd <= '1';
				Set_Addr_To <= "10"; -- AD
			when 3 =>
				BAAdd <= "01";	-- DB Inc
				LDBAL <= '1';
				Set_Addr_To <= "10"; -- AD
			when 4 =>
				LDBAH <= '1';
				if IR(7 downto 5) = "100" then
					Write <= '1';
				end if;
				Set_Addr_To <= "11"; -- BA
			when 5 =>
			when others =>
			end case;

		when "01001" | "01011" =>
			-- Immediate
			LDA <= '1';
			case to_integer(unsigned(MCycle)) is
			when 0 =>
			when 1 =>
				Jump <= "01";
			when others =>
			end case;

		when "00010" | "10010" =>
			-- Immediate, KIL
			LDX <= '1';
			case to_integer(unsigned(MCycle)) is
			when 0 =>
			when 1 =>
				if IR = "10100010" then
					-- LDX
					Jump <= "01";
				else
					-- KIL !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
				end if;
			when others =>
			end case;

		-- Zero Page
		when "00100" =>
			LCycle <= "010";
			case to_integer(unsigned(MCycle)) is
			when 0 =>
				if IR(7 downto 5) = "001" then
					SaveP <= '1';
				end if;
			when 1 =>
				Jump <= "01";
				LDAD <= '1';
				if IR(7 downto 5) = "100" then
					Write <= '1';
				end if;
				Set_Addr_To <= "10"; -- AD
			when 2 =>
			when others =>
			end case;

		-- Zero Page
		when "00101" | "00110" | "00111" =>
			if IR(7 downto 6) /= "10" and IR(1 downto 0) = "10" then
				-- Read-Modify-Write
				LCycle <= "100";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Jump <= "01";
					LDAD <= '1';
					Set_Addr_To <= "10"; -- AD
				when 2 =>
					LDDI <= '1';
					Write <= '1';
					Set_Addr_To <= "10"; -- AD
				when 3 =>
					LDALU <= '1';
					SaveP <= '1';
					Write <= '1';
					Set_Addr_To <= "10"; -- AD
				when 4 =>
				when others =>
				end case;
			else
				LCycle <= "010";
				if IR(7 downto 6) /= "10" then
					LDA <= '1';
				end if;
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Jump <= "01";
					LDAD <= '1';
					if IR(7 downto 5) = "100" then
						Write <= '1';
					end if;
					Set_Addr_To <= "10"; -- AD
				when 2 =>
				when others =>
				end case;
			end if;

		-- Absolute
		when "01100" =>
			if IR(7 downto 6) = "01" and IR(4 downto 0) = "01100" then
				-- JMP
				if IR(5) = '0' then
					LCycle <= "011";
					case to_integer(unsigned(MCycle)) is
					when 2 =>
						Jump <= "01";
						LDDI <= '1';
					when 3 =>
						Jump <= "10"; -- DIDL
					when others =>
					end case;
				else
					LCycle <= "101";
					case to_integer(unsigned(MCycle)) is
					when 2 =>
						Jump <= "01";
						LDDI <= '1';
						LDBAL <= '1';
					when 3 =>
						LDBAH <= '1';
						--if Mode /= "00" then
						--	Jump <= "10"; -- DIDL
						--end if;
						--if Mode = "00" then
							Set_Addr_To <= "11"; -- BA
						--end if;
					when 4 =>
						LDDI <= '1';
						--if Mode = "00" then
							Set_Addr_To <= "11"; -- BA
							BAAdd <= "01";	-- DB Inc
						--else
						--	Jump <= "01";
						--end if;
					when 5 =>
						Jump <= "10"; -- DIDL
					when others =>
					end case;
				end if;
			else
				LCycle <= "011";
				case to_integer(unsigned(MCycle)) is
				when 0 =>
					if IR(7 downto 5) = "001" then
						SaveP <= '1';
					end if;
				when 1 =>
					Jump <= "01";
					LDBAL <= '1';
				when 2 =>
					Jump <= "01";
					LDBAH <= '1';
					if IR(7 downto 5) = "100" then
						Write <= '1';
					end if;
					Set_Addr_To <= "11"; -- BA
				when 3 =>
				when others =>
				end case;
			end if;

		-- Absolute
		when "01101" | "01110" | "01111" =>
			if IR(7 downto 6) /= "10" and IR(1 downto 0) = "10" then
				-- Read-Modify-Write
				LCycle <= "101";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Jump <= "01";
					LDBAL <= '1';
				when 2 =>
					Jump <= "01";
					LDBAH <= '1';
					Set_Addr_To <= "11"; -- BA
				when 3 =>
					LDDI <= '1';
					Write <= '1';
					Set_Addr_To <= "11"; -- BA
				when 4 =>
					Write <= '1';
					LDALU <= '1';
					SaveP <= '1';
					Set_Addr_To <= "11"; -- BA
				when 5 =>
					SaveP <= '1';
				when others =>
				end case;
			else
				LCycle <= "011";
				if IR(7 downto 6) /= "10" then
					LDA <= '1';
				end if;
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Jump <= "01";
					LDBAL <= '1';
				when 2 =>
					Jump <= "01";
					LDBAH <= '1';
					if IR(7 downto 5) = "100" then
						Write <= '1';
					end if;
					Set_Addr_To <= "11"; -- BA
				when 3 =>
				when others =>
				end case;
			end if;

		-- Relative
		when "10000" =>			
			if Branch = '1' then
				LCycle <= "100";
			else
				LCycle <= "010";
			end if;
			case to_integer(unsigned(MCycle)) is
			when 2 =>
				Jump <= "01";
				LDDI <= '1';
			when 3 =>
				Jump <= "11"; -- Rel
				PCAdd <= '1';
			when 4 =>
			when others =>
			end case;

		-- Zero Page Indirect Indexed (d),y
		when "10001" | "10011" =>
			LCycle <= "101";
			if IR(7 downto 6) /= "10" then
				LDA <= '1';
			end if;
			case to_integer(unsigned(MCycle)) is
			when 0 =>
			when 1 =>
				Jump <= "01";
				LDAD <= '1';
				Set_Addr_To <= "10"; -- AD
			when 2 =>
				LDBAL <= '1';
				BAAdd <= "01";	-- DB Inc
				Set_Addr_To <= "10"; -- AD
			when 3 =>
				Set_BusA_To <= "011"; -- Y
				BAAdd <= "10";	-- BA Add
				LDBAH <= '1';
				Set_Addr_To <= "11"; -- BA
			when 4 =>
				BAAdd <= "11";	-- BA Adj
				if IR(7 downto 5) = "100" then
					Write <= '1';
				else
					BreakAtNA <= '1';
				end if;
				Set_Addr_To <= "11"; -- BA
			when 5 =>
			when others =>
			end case;

		-- Zero Page, X
		when "10100" | "10101" | "10110" | "10111" =>
			if IR(7 downto 6) /= "10" and IR(1 downto 0) = "10" then
				-- Read-Modify-Write
				LCycle <= "101";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Jump <= "01";
					LDAD <= '1';
					Set_Addr_To <= "10"; -- AD
				when 2 =>
					ADAdd <= '1';
					Set_Addr_To <= "10"; -- AD
				when 3 =>
					LDDI <= '1';
					Write <= '1';
					Set_Addr_To <= "10"; -- AD
				when 4 =>
					LDALU <= '1';
					SaveP <= '1';
					Write <= '1';
					Set_Addr_To <= "10"; -- AD
				when 5 =>
				when others =>
				end case;
			else
				LCycle <= "011";
				if IR(7 downto 6) /= "10" then
					LDA <= '1';
				end if;
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Jump <= "01";
					LDAD <= '1';
					Set_Addr_To <= "10"; -- AD
				when 2 =>
					ADAdd <= '1';
					if IR(7 downto 5) = "100" then
						Write <= '1';
					end if;
					Set_Addr_To <= "10"; -- AD
				when 3 =>
				when others =>
				end case;
			end if;

		-- Absolute Y
		when "11001" | "11011" =>
			LCycle <= "100";
			if IR(7 downto 6) /= "10" then
				LDA <= '1';
			end if;
			case to_integer(unsigned(MCycle)) is
			when 0 =>
			when 1 =>
				Jump <= "01";
				LDBAL <= '1';
			when 2 =>
				Jump <= "01";
				Set_BusA_To <= "011"; -- Y
				BAAdd <= "10";	-- BA Add
				LDBAH <= '1';
				Set_Addr_To <= "11"; -- BA
			when 3 =>
				BAAdd <= "11";	-- BA adj
				if IR(7 downto 5) = "100" then
					Write <= '1';
				else
					BreakAtNA <= '1';
				end if;
				Set_Addr_To <= "11"; -- BA
			when 4 =>
			when others =>
			end case;

		-- Absolute X
		when "11100" | "11101" | "11110" | "11111" =>
			if IR(7 downto 6) /= "10" and IR(1 downto 0) = "10" then
				-- Read-Modify-Write
				LCycle <= "110";
				case to_integer(unsigned(MCycle)) is
				when 1 =>
					Jump <= "01";
					LDBAL <= '1';
				when 2 =>
					Jump <= "01";
					Set_BusA_To <= "010"; -- X
					BAAdd <= "10";	-- BA Add
					LDBAH <= '1';
					Set_Addr_To <= "11"; -- BA
				when 3 =>
					BAAdd <= "11";	-- BA adj
					Set_Addr_To <= "11"; -- BA
				when 4 =>
					LDDI <= '1';
					Write <= '1';
					Set_Addr_To <= "11"; -- BA
				when 5 =>
					LDALU <= '1';
					SaveP <= '1';
					Write <= '1';
					Set_Addr_To <= "11"; -- BA
				when 6 =>
				when others =>
				end case;
			else
				LCycle <= "100";
				if IR(7 downto 6) /= "10" then
					LDA <= '1';
				end if;
				case to_integer(unsigned(MCycle)) is
				when 0 =>
				when 1 =>
					Jump <= "01";
					LDBAL <= '1';
				when 2 =>
					Jump <= "01";
					Set_BusA_To <= "010"; -- X
					BAAdd <= "10";	-- BA Add
					LDBAH <= '1';
					Set_Addr_To <= "11"; -- BA
				when 3 =>
					BAAdd <= "11";	-- BA adj
					if IR(7 downto 5) = "100" then
						Write <= '1';
					else
						BreakAtNA <= '1';
					end if;
					Set_Addr_To <= "11"; -- BA
				when 4 =>
				when others =>
				end case;
			end if;
		when others =>
		end case;
	end process;

	process (IR, MCycle)
	begin
		-- ORA, AND, EOR, ADC, NOP, LD, CMP, SBC
		-- ASL, ROL, LSR, ROR, BIT, LD, DEC, INC
		case IR(1 downto 0) is
		when "00" =>
			case IR(4 downto 2) is
			when "000" | "001" | "011" =>
				case IR(7 downto 5) is
				when "110" | "111" =>
					-- CP
					ALU_Op <= "0110";
				when "101" =>
					-- LD
					ALU_Op <= "0101";
				when "001" =>
					-- BIT
					ALU_Op <= "1100";
				when others =>
					-- NOP/ST
					ALU_Op <= "0100";
				end case;
			when "010" =>
				case IR(7 downto 5) is
				when "111" | "110" =>
					-- IN
					ALU_Op <= "1111";
				when "100" =>
					-- DEY
					ALU_Op <= "1110";
				when others =>
					-- LD
					ALU_Op <= "1101";
				end case;
			when "110" =>
				case IR(7 downto 5) is
				when "100" =>
					-- TYA
					ALU_Op <= "1101";
				when others =>
					ALU_Op <= "----";
				end case;
			when others =>
				case IR(7 downto 5) is
				when "101" =>
					-- LD
					ALU_Op <= "1101";
				when others =>
					ALU_Op <= "0100";
				end case;
			end case;
		when "01" =>
			ALU_Op(3) <= '0';
			ALU_Op(2 downto 0) <= IR(7 downto 5);
		when "10" =>
			ALU_Op(3) <= '1';
			ALU_Op(2 downto 0) <= IR(7 downto 5);
			case IR(7 downto 5) is
			when "000" =>
				if IR(4 downto 2) = "110" then
					-- INC
					ALU_Op <= "1111";
				end if;
			when "001" =>
				if IR(4 downto 2) = "110" then
					-- DEC
					ALU_Op <= "1110";
				end if;
			when "100" =>
				if IR(4 downto 2) = "010" then
					-- TXA
					ALU_Op <= "0101";
				else
					ALU_Op <= "0100";
				end if;
			when others =>
			end case;
		when others =>
			case IR(7 downto 5) is
			when "100" =>
				ALU_Op <= "0100";
			when others =>
				if MCycle = "000" then
					ALU_Op(3) <= '0';
					ALU_Op(2 downto 0) <= IR(7 downto 5);
				else
					ALU_Op(3) <= '1';
					ALU_Op(2 downto 0) <= IR(7 downto 5);
				end if;
			end case;
		end case;
	end process;

end