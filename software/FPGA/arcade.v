// Top-level module
module arcade (
// Common pins
	gen,								//input gen clk 50MHz
	nReset,							//External Reset signal (active - LOW)
// Video out pins	
	hs,								//HSYNC+VSYNC out (15625 kHz, 50Hz)
	vs,								//Logic "1" out, RGB input ON
	vgad[15:0],						//R out (5 bit) + G out (6 bit) + B out (5 bit)
// Leds and buzzer pins	
	buzzer,							//Buzzer ON out (active LOW)
	nReset_out,						//LED0
	blinker,							//LED1
	rd_done,							//LED2
	cpuled,							//LED3
	sel[7:0],						//LED display select outputs (active LOW)
	dig[7:0],						//LED display segments drive (active LOW)
// SDRAM pins
	sdram_clk,  	   			//sdram clock
	sdram_cke,     				//sdram clock enable
	sdram_cs_n,    				//sdram chip select
	sdram_we_n,    				//sdram write enable
	sdram_cas_n,   				//sdram column address strobe
	sdram_ras_n,					//sdram row address strobe
	sdram_dqm[1:0],				//sdram data enable 
	sdram_ba[1:0],					//sdram bank address
	sdram_addr[12:0],				//sdram address
	sdram_dq[15:0],				//sdram data
// LCD output pins
	lcd_dclk,						//lcd data clock
	lcd_hs,							//lcd horizontal synchronization
	lcd_vs,							//lcd vertical synchronization  
	lcd_de,							//lcd data valid
	lcd_r[7:0],						//lcd red
	lcd_g[7:0],						//lcd green
	lcd_b[7:0],						//lcd blue
// Key input pins
	key[20:0],						//keyboard
	rst_btn,
	inc_btn,
	dec_btn,
// Audio out pins
	DMC[6:0], 		     			//Выход канала дельта-модуляции
	SOUT[5:0],						//Выход суммы каналов SQA + SQB + RND + TRIA
// SD card pins
	sdcs,								//not used, connect to hZ
	sdclk,							//SDcard clock signal
	sdcmd,							//SDcard cmd signal
	sddat0,  							//SDcard data signal
// Coin input signal	
	coin_inp
//	Test pins output
	//,test[14:0]
);
				
// Define inputs and outputs			
input		gen;
input		nReset;

// Video out pins
output	hs;
output	vs;
output	[15:0]	vgad;

// Leds and buzzer pins
output	buzzer;
output	nReset_out;
output	blinker;
output	rd_done;
output	cpuled;
output	[7:0]		sel;
output	[7:0]		dig;

// SDRAM pins
output	sdram_clk;
output	sdram_cke;
output	sdram_cs_n;
output	sdram_we_n;
output	sdram_cas_n;
output	sdram_ras_n;
output	[1:0]		sdram_dqm; 
output	[1:0]		sdram_ba;
output	[12:0]	sdram_addr;
inout		[15:0]	sdram_dq;

// LCD output pins
output	lcd_dclk;   
output	lcd_hs;
output	lcd_vs; 
output   lcd_de;
output	[7:0]		lcd_r;
output	[7:0]		lcd_g;
output	[7:0]		lcd_b;

// Key input pins
input		[20:0]	key;
input		rst_btn;
input		inc_btn;
input		dec_btn;

// Audio out pins
output	[6:0]		DMC;
output	[5:0]		SOUT;

// SD card pins
output	sdcs;
output	sdclk;
inout		sdcmd;
input		sddat0;

// Coin input signal
input		coin_inp;

//	Test pins output
//output	[14:0]	test;

// Define flip-flops and registers
reg		[7:0]		LS373;		//NES LS373 register
reg		[16:0]	div;			//General divider
reg		[14:0]	timer;		//1s timer
reg		[23:0]	res_cnt;		//SD read done counter

//sdram interface
reg		[23:0]	wr_burst_addr;
reg		[15:0]	wr_burst_data;
reg		[7:0]		wr_buff;
reg		[7:0]		rd_buff;
reg		wr_burst_req;
reg		rd_burst_req;
reg		wr_done;
reg		rd_block;
reg		rd_val;

//keyboard interface
reg		[7:0]		btn1;
reg		[7:0]		btn2;
reg		[2:0]		key1_point;
reg		[2:0]		key2_point;

// Define wires
// CLK's & Resets
wire		cpu_clk;					//CPU clk = 26.6 MHz
wire		ppu_clk;					//PPU clk = 53.2 MHz
wire		SD_clk;					//SD card clk = 13.3 MHz
wire		LS_clk;					//Low Speed clk = 1.25 MHz
wire 		rp_clk;
wire		nes_rst;
wire		apu_nes_rst;
reg		pulse_1s;

// NES CPU BUS
wire 		[7:0] 	DB;
wire		[7:0]		P_ROM;
wire		[7:0]		P_RAM;
wire		[15:0]	ADDR_BUS;
wire		RnW;
wire		nINT;
wire		M2_out;
wire		nIRQ_EXT;
wire		cpu_ram_ce;
wire		cpu_rom_ce;
wire		cpu_ppu_ce;
wire		[1:0]		nIN;
wire		[2:0]		OUT;

// Audio out signals
wire		[3:0]		SQA;			//Выход прямоугольного канала 1
wire		[3:0]		SQB;			//Выход прямоугольного канала 2
wire		[3:0]		RND;			//Выход шумового канала
wire		[3:0]		TRIA;			//Выход треугольного канала

// NES PPU BUS
wire		nWR;
wire		nRD;
wire		ALE;
wire 		[7:0] 	PD;
wire 		[7:0] 	DBIN;
wire		[7:0]		V_ROM;
wire		[7:0]		V_RAM;
wire		ppu_ram_A10;
wire		[17:0]	RGB;
wire 		[13:0] 	PAD;
wire		[2:0]		EMPH;
wire		nPicture;

// SD card reader
wire		outen;
wire		file_found;
wire		[3:0]		card_stat;         	//show the sdcard initialize status
wire		[1:0]		card_type;         	//0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
wire		[1:0]		filesystem_type;   	//0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
wire		[7:0]		outbyte;

// APU BUS
wire		[15:0]apu_addr;
wire		[7:0]apu_data;
wire		apu_ce;
wire		buzzer_en;
wire		apu_rd_ack;
wire		apu_rom_block;
wire		scroll;
wire		[23:0]	rd_apu_addr;
wire		[1:0]		rd_addr_sel;
wire		[7:0]		inreg2;
wire		[12:0]	V_RAM_ADDR;

// SDRAM BUS
wire		rd_ack;
wire		wr_burst_finish;
wire		rd_burst_finish;
wire		rd_burst_data_valid;
wire		wr_burst_data_req;
wire		[23:0]	rd_burst_addr;
wire		[15:0]	rd_burst_data;

// Define assignes
//assign	test[14:0] = {5'd0, key2_point[2:0], key1_point[2:0], nIN[1], nIN[0], OUT[0], M2_out};
// Video outputs
assign 	vs = 1'b1;
assign	vgad[15:11] = RGB[17:13];				//SCART red
assign	vgad[10:5] = RGB[11:6];					//SCART green
assign	vgad[4:0] = RGB[5:1];					//SCART blue
assign	lcd_r[7:0] = {RGB[17:12], 2'b00};	//lcd red
assign	lcd_g[7:0] = {RGB[11:6], 2'b00};		//lcd green
assign	lcd_b[7:0] = {RGB[5:0], 2'b00};		//lcd blue
assign	lcd_de = ~nPicture | ~lcd_vs;				      //lcd data valid

// SD card reader
assign	sdcs = 1'bz;

// Leds and buzzer pins
assign	buzzer = buzzer_en ? div[8] : 1'b1;
assign	blinker = div[16];

// NES
assign	nIRQ_EXT = 1'd1;
assign	ppu_ram_A10 = scroll ? PAD[10] : PAD[11];
assign	nes_rst = apu_nes_rst & key[20] & rst_btn;
assign	cpu_ram_ce = (M2_out & ~ADDR_BUS[15] & ~ADDR_BUS[14] & ~ADDR_BUS[13]);
assign	cpu_rom_ce = (M2_out & ADDR_BUS[15] & RnW);
assign	cpu_ppu_ce = (M2_out & ~ADDR_BUS[15] & ~ADDR_BUS[14] & ADDR_BUS[13]);
assign	PD[7:0] = (PAD[13] & ~nRD & nWR) ? V_RAM[7:0] : (~PAD[13] & ~nRD) ? V_ROM[7:0] : 8'b0;
assign	DB[7:0] = 	(cpu_ram_ce & RnW) ? P_RAM[7:0] : (cpu_rom_ce & RnW) ? rd_buff[7:0] : 
							~nIN[0] ? {7'd0, ~btn1[key1_point]} : ~nIN[1] ? {7'd0, ~btn2[key2_point]} : 8'bz;
assign	inreg2[7:0] = 	(rd_addr_sel[1:0] == 2'b00) ? wr_burst_addr[7:0] :
								(rd_addr_sel[1:0] == 2'b01) ? wr_burst_addr[15:8] :
								(rd_addr_sel[1:0] == 2'b10) ? wr_burst_addr[23:16] : 8'd0;

// APU
assign	rd_done = res_cnt[23];
assign	V_RAM_ADDR[12:0] = nes_rst ? {PAD[12:8], LS373[7:0]} : apu_addr[12:0];
assign	rd_burst_addr[23:0] = nes_rst ? (rd_apu_addr[23:0] + {9'd0, (apu_rom_block & ADDR_BUS[14]), ADDR_BUS[13:0]}) : rd_apu_addr[23:0];
assign	rd_ack = nes_rst ? cpu_rom_ce : apu_rd_ack;

// Logics															
always @(negedge LS_clk)
begin
	div[16:0] <= div[16:0] + 17'd1;		//Low speed divider	
end			

always @(negedge div[5])
begin
	timer[14:0] <= timer[14:0] + 15'd1;		//Timer counter	
	
	if(timer[14:0] == 15'd19531) begin
		timer[14:0] <= 15'd0;
		pulse_1s <= 1'b0;
	end
	else
		pulse_1s <= 1'b1;	
end		

always @(negedge ALE)
begin
	LS373[7:0] <= PAD[7:0];					//LS373 buffer	logic	
end						
								
always @(posedge M2_out)
begin
	if(OUT[0]) begin							//Joystick's logic
		if(cpuled) begin
			btn1[7:0] <= {4'b1111, key[9:8], 2'b11};
			btn2[7:0] <= 8'b11111111;
		end
		else begin
			btn1[7:0] <= {(key[1] | key[3]), (~key[1] | ~key[3]),  (key[0] | key[2]), (~key[0] | ~key[2]), key[9:8], (key[7] & (key[5] | div[16])), (key[6] & (key[4] | div[16]))};
			btn2[7:0] <= {key[17:14], 2'b11, (key[13] & (key[11] | div[16])), (key[12] & (key[10] | div[16]))};
		end

		key1_point[2:0] <= 3'd7;
		key2_point[2:0] <= 3'd7;
	end
	
	if(~nIN[0])
		key1_point[2:0] <= key1_point[2:0] + 3'd1;
	
	if(~nIN[1])
		key2_point[2:0] <= key2_point[2:0] + 3'd1;
		
end

always @(negedge sdram_clk or negedge nReset_out)
begin
	if(~nReset_out) begin					//SDRAM logic
		wr_done <= 1'b0;
		rd_block <= 1'b0;
		wr_burst_req <= 1'b0;
		wr_burst_addr[23:0] <= 24'd0;
	end
	else	begin
		if(outen && ~wr_done) begin
			wr_burst_req <= 1'b1;
			wr_buff[7:0] <= outbyte[7:0];	
			wr_done <= 1'b1;
		end
		
		if(wr_burst_data_req) begin
			wr_burst_data[15:0] <= {8'd0, wr_buff[7:0]};
			wr_burst_req <= 1'b0;
		end
		
		if(wr_burst_finish)
			wr_burst_addr[23:0] <= wr_burst_addr[23:0] + 24'd1;
		
		if(~outen)
			wr_done <= 1'b0;
		
		if(rd_ack & ~rd_block) begin
			rd_burst_req <= 1'b1;
			rd_val <= 1'b0;	
			rd_block <= 1'b1;
		end
		
		if(rd_burst_data_valid) begin
			rd_buff[7:0] <= rd_burst_data[7:0];
			rd_burst_req <= 1'b0;				
		end
		
		if(rd_burst_finish)
			rd_val <= 1'b1;
			
		if(~rd_ack)
			rd_block <= 1'b0;
	end
end

always @(negedge SD_clk or negedge nReset_out)
begin
	if(~nReset_out) begin					//SD read done signal logic
		res_cnt[23:0] <= 24'd0;
	end
	else
		if(outen || (card_stat[3:0] == 4'd0))
			res_cnt[23:0] <= 24'd0;
		else
			if(~res_cnt[23])
				res_cnt[23:0] <= res_cnt[23:0] + 24'd1;
end

// MODULES
// CPU
RP2A03 RP2A03_module(
	cpu_clk,               		//Тактовый сигнал          
	1'd1,               			//Режим PAL
	nINT,								//Вход немаскируемого прерывания
	nIRQ_EXT,          			//Вход маскируемого прерывания
	nes_rst,              		//Сигнал сброса
	DB[7:0],          			//Шина данных
	ADDR_BUS[15:0],   			//Шина Адреса
	RnW,              			//Внешний пин Чтение/Запись
	M2_out,           			//Фаза M2 процессора (внешний пин)
	SQA[3:0], 	     				//Выход прямоугольного канала 1
	SQB[3:0], 	     				//Выход прямоугольного канала 2
	RND[3:0], 	     				//Выход шумового канала
	TRIA[3:0], 	     				//Выход треугольного канала
	DMC[6:0], 	     				//Выход канала дельта-модуляции
	SOUT[5:0], 	     				//Выход суммы каналов SQA + SQB + RND + TRIA
	OUT[2:0], 	     				//Выход для портов периферии
	nIN[1:0] 	     				//Выход для портов периферии
);

// PPU
RP2C02_LITE RP2C02_LITE_module(
	ppu_clk,               		//Системный клок
	cpu_clk,	         			//Клок 21.477/ 26,601 для делителя
	1'd1,              			//Режим PAL/NTSC
	1'd1,             			//Режим DENDY	
	nes_rst,              		//Сигнал сброса
	1'd0, 
	1'd0, 
	RnW,               			//Внешний пин Чтение/Запись	
	~cpu_ppu_ce,              	//Строб обращения к PPU
	ADDR_BUS[2:0],            	//Адрес регистра
	PD[7:0],           			//Вход шины графических данных PPU
	DB[7:0],           			//Внешняя шина данных CPU
	RGB[17:0],        			//Выход RGB
	EMPH[2:0],
	PAD[13:0],        			//Выход адресов шины PPU
	nINT,              			//Выход запроса прерывания NMI
	ALE,              			//ALE выход строба защелкивания младшего байта адреса VRAM
	nWR,              			//Строб записи VRAM	
	nRD,              			//Строб чтения VRAM
	hs,             				//Выход композитной синхронизации
	lcd_hs,
	lcd_vs,
	lcd_dclk,
	nPicture
);

// PLL
pll pll_module(
	~nReset,
	gen,
	cpu_clk,
	ppu_clk,
	sdram_clk,
	SD_clk,
	LS_clk,
	nReset_out
);

// CPU SRAM
sram cpu_sram_module(
	ADDR_BUS[10:0],
	cpu_clk,
	DB[7:0],
	(RnW & cpu_ram_ce),
	(~RnW & cpu_ram_ce),
	P_RAM[7:0]
);

// PPU SRAM
sram ppu_sram_module(
	{ppu_ram_A10, PAD[9:8], LS373[7:0]},
	cpu_clk,
	PAD[7:0],
	(~nRD & PAD[13]),
	(~nWR & PAD[13]),
	V_RAM[7:0]
);

// PPU ROM (in RAM)
v_ram v_ram_module(
	V_RAM_ADDR[12:0],
	cpu_clk,
	apu_data[7:0],
	nes_rst,
	apu_ce,
	V_ROM[7:0]
);

// APU
apu apu_module(
	cpu_clk,
	div[9],
	nReset_out,
	sel[7:0],
	dig[7:0],
	{card_stat[3:0], card_type[1:0],	filesystem_type[1:0]},
	{(inc_btn & key[18]), (dec_btn & key[19]), 2'd0, coin_inp, rd_val, res_cnt[23], file_found},
	inreg2[7:0],
	rd_buff[7:0],	
	{rd_addr_sel[1:0], apu_rom_block, scroll, apu_rd_ack, apu_nes_rst, cpuled, buzzer_en},
	rd_apu_addr[7:0],
	rd_apu_addr[15:8],
	rd_apu_addr[23:16],
	apu_addr[15:0],
	apu_data[7:0],
	apu_ce,
	pulse_1s
);

sd_file_reader #(
	.FILE_NAME_LEN(7),
	.FILE_NAME("rom.nes"),
	.CLK_DIV(3'd1),
	.SIMULATE(0)
) sd_file_reader_module(
	nReset_out,						//rstn active-low, 1:working, 0:reset
	SD_clk,							//clock
	sdclk,							//SDcard signals (connect to SDcard), this design do not use sddat1~sddat3.
	sdcmd,
	sddat0,            			//FPGA only read SDDAT signal but never drive it
// Status output
	card_stat[3:0],         	//show the sdcard initialize status
	card_type[1:0],         	//0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
	filesystem_type[1:0],   	//0=UNASSIGNED , 1=UNKNOWN , 2=FAT16 , 3=FAT32 
	file_found,        			//0=file not found, 1=file found
// File content data output
	outen,             			//when outen=1, a byte of file content is read out from outbyte
	outbyte[7:0]            	//a byte of file content
);

sdram_core sdram_core_module
(
	.rst(~nReset_out),
	.clk(sdram_clk),
	.rd_burst_req(rd_burst_req),
	.rd_burst_len(10'd1),
	.rd_burst_addr(rd_burst_addr[23:0]),
	.rd_burst_data_valid(rd_burst_data_valid),
	.rd_burst_data(rd_burst_data[15:0]),
	.rd_burst_finish(rd_burst_finish),
	.wr_burst_req(wr_burst_req),
	.wr_burst_len(10'd1),
	.wr_burst_addr(wr_burst_addr[23:0]),
	.wr_burst_data_req(wr_burst_data_req),
	.wr_burst_data(wr_burst_data[15:0]),
	.wr_burst_finish(wr_burst_finish),
	.sdram_cke(sdram_cke),
	.sdram_cs_n(sdram_cs_n),
	.sdram_ras_n(sdram_ras_n),
	.sdram_cas_n(sdram_cas_n),
	.sdram_we_n(sdram_we_n),
	.sdram_dqm(sdram_dqm[1:0]),
	.sdram_ba(sdram_ba[1:0]),
	.sdram_addr(sdram_addr[12:0]),
	.sdram_dq(sdram_dq[15:0])
);
endmodule

module apu(
	clk,
	clk2,
	nReset,
	sel[7:0],
	dig[7:0],
	inreg0[7:0],
	inreg1[7:0],
	inreg2[7:0],
	inreg3[7:0],	
	outreg0[7:0],
	outreg1[7:0],
	outreg2[7:0],
	outreg3[7:0],
	ADDR[15:0],
	DOUT[7:0],
	CE,
	IRQ
);

input		clk;
input		clk2;
input		nReset;
input		[7:0]		inreg0;
input		[7:0]		inreg1;
input		[7:0]		inreg2;
input		[7:0]		inreg3;	
output reg	[7:0]		outreg0;
output reg	[7:0]		outreg1;
output reg	[7:0]		outreg2;
output reg	[7:0]		outreg3;
output	[7:0]		sel;
output	[7:0]		dig;
output	[15:0]	ADDR;
output	[7:0]		DOUT;
output	CE;
input		IRQ;

reg		[63:0] 	data;
reg 		[2:0]		point;
reg 		DIV0, DIV1, DIV2, DIV3;
reg 		DIV4, DIV5, DIV6, DIV7, DIVM2;

// Комбинаторика
wire 		LOCK;
wire		PHI0;
wire		PHI1;
wire		PHI2;
wire		M2;
wire		SYNC;
wire		[7:0]		DIN;
wire		[7:0]		A_ROM;
wire		[7:0]		A_RAM;
wire		RW;
wire		ram_ce;
wire		rom_ce;
wire		reg_ce;

// Assigns
assign 	LOCK = DIV1 | ~DIV0;
assign 	PHI0 = ~DIV0;
assign 	M2 = PHI2 | ~DIVM2;
assign	CE = ~RW & (M2 & ~ADDR[15] & ADDR[14] & ADDR[13]);
assign	ram_ce = (M2 & ~ADDR[15] & ~ADDR[14] & ~ADDR[13] & ~ADDR[12] & ~ADDR[11]);
assign	rom_ce = (M2 & ADDR[15] & ADDR[14] & ADDR[13] & ADDR[12] & ADDR[11] & RW);
assign	reg_ce = (M2 & ~ADDR[15] & ~ADDR[14] & ~ADDR[13] & ~ADDR[12] & ADDR[11]);
assign	DIN[7:0] = 	rom_ce ? A_ROM[7:0] : (ram_ce & RW) ? A_RAM[7:0] : 
							(reg_ce && RW && (ADDR[3:0] == 4'd12)) ? inreg0[7:0] :
							(reg_ce && RW && (ADDR[3:0] == 4'd13)) ? inreg1[7:0] :
							(reg_ce && RW && (ADDR[3:0] == 4'd14)) ? inreg2[7:0] :
							(reg_ce && RW && (ADDR[3:0] == 4'd15)) ? inreg3[7:0] : 8'd0;
assign	sel[7:0] = nReset ? (8'd255 ^ (8'd1 << point[2:0])) : 8'd255;
assign	dig[7:0] = ~nReset ? 8'd255 :	
							(point[2:0] == 3'b000) ? data[7:0] :
							(point[2:0] == 3'b001) ? data[15:8] :
							(point[2:0] == 3'b010) ? data[23:16] :
							(point[2:0] == 3'b011) ? data[31:24] :
							(point[2:0] == 3'b100) ? data[39:32] :
							(point[2:0] == 3'b101) ? data[47:40] :
							(point[2:0] == 3'b110) ? data[55:48] : data[63:56];

// Логика
always @(negedge clk)
begin
	DIVM2 <= DIV2 & LOCK;
	
	if(reg_ce && ~RW)
		if(ADDR[3:0] == 4'd0)
			data[7:0] <= DOUT[7:0];
		else
			if(ADDR[3:0] == 4'd1)
				data[15:8] <= DOUT[7:0];
			else
				if(ADDR[3:0] == 4'd2)
					data[23:16] <= DOUT[7:0];
				else
					if(ADDR[3:0] == 4'd3)
						data[31:24] <= DOUT[7:0];
					else
						if(ADDR[3:0] == 4'd4)
							data[39:32] <= DOUT[7:0];
						else
							if(ADDR[3:0] == 4'd5)
								data[47:40] <= DOUT[7:0];
							else
								if(ADDR[3:0] == 4'd6)
									data[55:48] <= DOUT[7:0];
								else
									if(ADDR[3:0] == 4'd7)
										data[63:56] <= DOUT[7:0];
									else
										if(ADDR[3:0] == 4'd8)
											outreg0[7:0] <= DOUT[7:0];
										else
											if(ADDR[3:0] == 4'd9)
												outreg1[7:0] <= DOUT[7:0];
											else
												if(ADDR[3:0] == 4'd10)
													outreg2[7:0] <= DOUT[7:0];	
												else
													if(ADDR[3:0] == 4'd11)
														outreg3[7:0] <= DOUT[7:0];
end

always @(negedge clk2)
begin
	point[2:0] <= point[2:0] + 3'd1;
end

always @(posedge clk) begin
	DIV0  <= DIV1;
	DIV1  <= DIV2 & LOCK;
	DIV2  <= DIV3 & LOCK;
   DIV3  <= DIV4 & LOCK;
	DIV4  <= DIV5 & LOCK;
   DIV5  <= DIV6 & LOCK;
   DIV6  <= DIV7 & LOCK;
	DIV7  <= PHI0;
end

// MOS6502 CORE
MOS6502_WBCD APU_module(
// Clocks                		
   clk,               			// Clock
   PHI0,              			// phase PHI0
// Inputs	
	1'b1,                		// Sync input		
	1'b1,              			// Non-maskable interrupt input	
	IRQ,              			// Maskable interrupt input
	nReset,              		// Reset signal
 	1'b1,               			// Processor ready signal	
	DIN[7:0],          			// Data bus (input)
// Outputs
	PHI1,             			// phase PHI1 (output)
	PHI2,             			// phase PHI2 (output)	
	RW,               			// Processor write signal
	DOUT[7:0],        			// Data bus (output)
	ADDR[15:0],          		// Address Bus
   SYNC	             			// Sync output (Т1) 
);

// APU SRAM 2K
sram APU_sram_module(
	ADDR[10:0],
	clk,
	DOUT[7:0],
	(RW & ram_ce),
	(~RW & ram_ce),
	A_RAM[7:0]
);

// APU ROM 2K
a_rom a_rom_module(
	ADDR[10:0],
	clk,
	A_ROM[7:0]);

endmodule


