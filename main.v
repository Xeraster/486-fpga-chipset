`include "utils.v"
`include "bram.v"

//tested working 02/24/24
/*module BE_to_A00A01 (b0, b1, b2, b3, a0, a1, ADS, CPU_CLK);
    input b0, b1, b2, b3;
    input ADS, CPU_CLK;
    output reg a0, a1;

    /*always@(b0, b1, b2, b3)
	begin
    	//following diagram on page 7-6 of Intel hardware reference manual
    	a1 = (b0 & b1);
    	a0 = ~(~(b0 & b2) & ~(~b1 & b0));
	end*/

/*    wire b0l, b1l, b2l, b3l;
    always @(posedge CPU_CLK)
    begin
        b0l <= b0;
        b1l <= b1;
        b2l <= b2;
        b3l <= b3;
    end

    always @(posedge ADS)
    begin
        a0 <= (b0l & b1l);
        a1 <= ~(~(b0l & b2l) & ~(~b1l & b0l));
    end

endmodule*/

module BE_to_A00A01 (b0, b1, b2, b3, a0, a1, ADS, CPU_CLK);
    input b0, b1, b2, b3;
    input ADS, CPU_CLK;
    output reg a0, a1;

    /*always@(b0, b1, b2, b3)
	begin
    	//following diagram on page 7-6 of Intel hardware reference manual
    	a1 = (b0 & b1);
    	a0 = ~(~(b0 & b2) & ~(~b1 & b0));
	end*/

    //reg b0l, b1l, b2l, b3l;
    always @(posedge CPU_CLK)
    begin
        /*b0l <= b0;
        b1l <= b1;
        b2l <= b2;
        b3l <= b3;*/
        //it's actually better not to latch A0 and A1 using ADS because BE0-BE3 change during burst cycles - even while ADS is asserted. See
        a0 <= (b0 & b1);
        a1 <= ~(~(b0 & b2) & ~(~b1 & b0));
    end



    /*always @(posedge ADS)
    begin
        b0l <= b0;
        b1l <= b1;
        b2l <= b2;
        b3l <= b3;
        a0 <= (b0l & b1l);
        a1 <= ~(~(b0l & b2l) & ~(~b1l & b0l));
    end*/
    /*wire dummy0, dummy1;
    d_latch dl0(a0, dummy0, ADS, (b0l & b1l));
    d_latch dl1(a1, dummy1, ADS, ~(~(b0l & b2l) & ~(~b1l & b0l)));*/

    //it's actually better not to latch this stuff because BE0-BE3 change during burst cycles
    /*wire dummy0, dummy1;
    d_latch dl0(a0, dummy0, ADS, (b0 & b1));
    d_latch dl1(a1, dummy1, ADS, ~(~(b0 & b2) & ~(~b1 & b0)));*/

endmodule

//tested working
module manageReset(input FPGA_RESET, output reg SYSTEM_RESET, input CPU_CLK);//SYSTEM_RESET is declared here as wire. 

	reg [7:0] count;
	always@(posedge CPU_CLK)
	begin
		if (!FPGA_RESET)
			count <= 0;
		else if (count < 254)
			count <= count + 1;

		if (count > 250)            //wait a nice long ass time for things to stablize
			SYSTEM_RESET <= 1;
		else
			SYSTEM_RESET <= 0;
	end
endmodule

//outputs the memory cycle from control signals. tested working
module memCycles(
    input DC,
    input WR,
    input MIO,
    input ADS,
    output reg MEMR,
    output reg MEMW,
    output reg IOR,
    output reg IOW,
    output reg INTA,
    output reg HALT,
    input BCLK              //delay the MEMW line by just 1 clock and see if that stops the bug
);

    //outputs have to be modified after being processed in the decoder so... try to make intermediate variables?
    wire inta_i, halt_placeholder, ior_i, iow_i, memr_i1, reserved, memr_i2, memw_i;

    wire MIO_L, DC_L, WR_L;
    d3_latch d3lctrl(WR, DC, MIO, WR_L, DC_L, MIO_L, ADS);  //latch control signals on each cycle.
    decoder_3to8 m1(MIO, DC, WR, inta_i, halt_placeholder, ior_i, iow_i, memr_i1, reserved, memr_i2, memw_i);

    reg [2:0] counter;    //delay the MEMW line by just 1 clock (or more depending on how fucked up everything is)
    //fuck! out of memory. its a 1 bit counter then

    //trying to delay MEMR and or MEMW has made no difference whatsoever
    always@(posedge BCLK)
    begin
        //basically do the same shit that gets done in wait state control
        if (~ADS)
            begin
                counter <= 0;
            end
        else
        begin
            if (ADS & counter < 3)
                counter <= counter + 1;
        end
    end

    always @(*)
    begin

        //all this stuff is active low. high while not asserted. low when asserted.
        IOR = ~(ior_i&ADS);
        IOW = ~(iow_i&ADS);
        MEMR = ~((memr_i1|memr_i2)&ADS/*&counter>1*/);	//code reads and memory reads are both memory read cycles
        MEMW = ~(memw_i&ADS/*&counter>1*/);     //delaying MEMR and or MEMW signals doesn't stop the bug from happening
        INTA = (inta_i&ADS);
        HALT = (halt_placeholder&ADS);

    end

endmodule

//8 bit data bus transciever control. tested working
module trancieverControl(
    input A00, 
    input A01, 
    input en, 
    output reg TE0, 
    output reg TE1, 
    output reg TE2, 
    output reg TE3);

    //if ADS == 1 and A0-A1 run through a d2_4e is that respective tranceiver, output low
    wire AE0, AE1, AE2, AE3;
    decoder_2to4_w_enable d1(A00, A01, AE0, AE1, AE2, AE3, en);

    always @(*)
    begin
        TE0 = ~AE0;
        TE1 = ~AE1;
        TE2 = ~AE2;
        TE3 = ~AE3;
    end

endmodule

module addressDecode (
    input a00, 
    input a01, 
    input a02, 
    input a03, 
    input a04, 
    input a05, 
    input a06, 
    input a07, 
    input a08, 
    input a09, 
    input a10, 
    input a11, 
    input a12, 
    input a13, 
    input a14, 
    input a15, 
    input a16, 
    input a17, 
    input a18, 
    input a19, 
    input a20, 
    input a21, 
    input a22, 
    input a23, 
    input a24, 
    input a25, 
    input a26, 
    input a27, 
    input a28, 
    input a29, 
    input a30, 
    input a31,
    input MIO,                  //need to be able to distinguish IO and memory cycles from each other
    input WR,                   //need to be able to distinguish read and write cycles from each other
    input DC,                   //DC probably doesn't matter for this. You *could* use DC to chip select ram vs rom if you wanted but meh

    output reg rom_en,              //FFFE000h
    output reg sram_en,
    output reg lcd_active,              //A000h-A003h
    output reg PIT_en,              //0040h-0043h
    output reg rtc_en,              //0070h-007Fh
    output reg PIC1_en,             //00A0h-00A1h
    output reg PIC0_en,             //0020h-0023h
    output reg hd0_RD,              //A030h-A03Fh
    output reg hd0_WR,
    output reg kbd_en,              //0060h, 0064h
    output reg cpld1_reg0_en,       //0061h
    output reg vgamap_en,           //A0000h-C7FFFh
    output reg cpld1_reg1_en,
    output reg v9958_en,           //A020-A023

    output reg SMEMR,               //active any time a memory read happens below the 20 bit address boundary
    output reg SMEMW,               //active any time a memory write happens below the 20 bit address boundary
    input ADS,                       //there needs to be an ads signal because chip select lines should only be active while valid data is on the bus
    input clock,                     //clock cycles have to be counted to get lcd enable timing just right
    output interrupt_vector          //debugging output for if the cpu is accessing an interrupt vector in ram
);
    wire low16, high16;
    assign low16 = (a00|a01|a02|a03|a04|a05|a06|a07|a08|a09|a10|a11|a12|a13|a14|a15);
    assign high16 = (a16|a17|a18|a19|a20|a21|a22|a23|a24|a25|a26|a27|a28|a29|a30|a31);
    //reg lcd_en_base;
    
    //reg [0:3] enable_delay;
    //do the easy obvious stuff first
    always @(*)
    begin
        
        //if bit 22 or higher is a 1, enable rom. this way, rom wraps around from the 4mb boundary all the way to the 4gb 32 bit address limit
        rom_en = ~((a22|a23|a24|a25|a26|a27|a28|a29|a30|a31)&MIO&ADS);

        sram_en = ~((~a22|~a23|~a24|~a25|~a26|~a27|~a28|~a29|~a30|~a31)&MIO&ADS);
        
        //A000h-A003h. lcd active is the normal lcd active high signal just without the beginning wait states
        lcd_active = (~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & ~a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;

        //0040h-0043h
        PIT_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & a06 & ~a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //0020h-0023h
        PIC0_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //00A0h-00A3h
        PIC1_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //0070h-007Fh
        rtc_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & a06 & a05 & a04) & ~MIO & ADS;

        //lower 20 bit mem bus cycle definitions
        SMEMR = ~((~high16 && ~a16 & ~a17 & ~a18 & ~a19) & MIO & ~WR & ADS);
        SMEMW = ~((~high16 && ~a16 & ~a17 & ~a18 & ~a19) & MIO & WR & ADS);

	    //keyboard controller is ports 0x60 andd 0x64. HT6542B is active low. 0060-0067 becuase laziness
	    kbd_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & a06 & a05 & ~a04 & ~a03 & ADS);

        //active low. high when not selected. video card should be optional even without a pull-up resistor on the slot ready line
        v9958_en = ~(~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;

        interrupt_vector = (~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11) & MIO & ADS;    //if it accesses the lower 0-1024 bytes of address space, then its an interrupt vector exception or whatever

        //output a debug signal if the cpu is accessing the bottom 1024
	
	    /*if (enable_delay<5)
            lcd_active <= 0;
        else
            lcd_active <= (~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & ~a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        */
    end

endmodule

module waitStateControl(
    input lcd_active,
    input rom_en,       //experiment with rom wait states and see what happens
    input kbd_en,       //definitely needs wait states
    input clock,        //the system clock
    input ADS,          //wait state counting should only be valid while ADS is high
    input SLOT_RDY,     //signal from the z80 wait compatible line
    input v9958_en,     //active low, when low, use SLOT_RDY to determine wait states
    input sram_active,      //add a few wait states to sram access
    output reg lcd_en,  //the 20x2 lcd needs wait states at both the beginning and the end of the bus cycle
    output reg RDY,      //output ready or not
    output reg sram_en      //maybe delaying sram enable just a little will make it work better
);

    reg [4:0] lcdcounter;
    reg [4:0] romcounter;
    reg [4:0] kbdcounter;
    reg [4:0] sramcounter;

    //clear the wait state counters on the rising edge of ADS
    always@(posedge clock)
    begin
        if (~ADS)
            begin
            lcdcounter <= 0;
            kbdcounter <= 0;
            romcounter <= 0;
            sramcounter <= 0;
            end
        else
        begin
            if (lcd_active & lcdcounter < 30)
                lcdcounter <= lcdcounter+1;

            if (~kbd_en & kbdcounter < 15)
                kbdcounter <= kbdcounter + 1;

            if (~rom_en & romcounter < 15)
                romcounter <= romcounter + 1;

            //not a lot of wait states but there still need to be more than 0
            if (~sram_active & sramcounter < 15) //was 4
                sramcounter <= sramcounter + 1;
        end
    end

    //can't use rising edge of clock or ads for this
    always @(*)
    begin
        if (lcdcounter < 15 & lcd_active)
            RDY <= 1;
        else if (romcounter < 7 & ~rom_en)
            RDY <= 1;
        else if (kbdcounter < 7 & ~kbd_en)
            RDY <= 1;
        else if (sramcounter < 7 & ~sram_active)        //was 4    //i'm sure it's possible to get the sram working with zero wait states but I'll have to figure that part out later
            RDY <= 1;
        else if (~v9958_en & ~SLOT_RDY)             //if the v9958 graphics card is selected and if it is outputting a not ready signal, hold the RDY line until that changes
            RDY <= 1;
        else
            RDY <= 0;

        //bruuuuuuh
        if (lcdcounter > 4 & lcd_active & lcdcounter < 18)
            lcd_en <= 1;
        else
            lcd_en <= 0;

        //send the enable signal to the sram a little after MEMW and or MEMR are asserted.
        //actually, don't delay that signal. See if anything different happens
        if (/*sramcounter > 5 & */~sram_active)
            sram_en <= 0;   //sram is active low
        else
            sram_en <= 1;
    end

endmodule

module top(
    input ADS,              //486 general control signals
    input DC,               //486 general control signals
    input MIO,              //486 general control signals
    input WR,               //486 general control signals
    input BE0,              //byte enable signal
    input BE1,              //byte enable signal
    input BE2,              //byte enable signal
    input BE3,              //byte enable signal
    input CPU_CLK,          //system clock. 1x multiplier, bus runs at same speed as cpu
    input FPGA_RESET,       //fpga reset signal from lm809
    output SYSTEM_RESET,    //the fpga tells the system when to reset
    output IOR,		        //active low IO read
	output IOW,		        //active low IO write
	output MEMR,	        //memory read to any address
	output MEMW,	        //memory write to any address
	output SMEMR,	        //memory read to any address less than 0x000FFFFF
	output SMEMW,	        //memory read to any address less than 0x000FFFFF
	output INTA,            //interrupt ack bus cycle
    output BALE,            //inverse of ADS. Earlier cpus didn't have this or an ADS line. No idea how to get around that issue tbh so I'm glad its not relevant right now
    output RD,              //z80 bus read enable active low
    output WE,              //z80 bus write enable active low
    output MREQ,            //z80 bus signal
    output IOREQ,           //z80 bus signal
    input [31:2]address,    //address bits 2-31
    
    output A00,             //A00 and A01 are derived from BE0-BE3
    output A01,

    //tranciever enables
    output TE0,
    output TE1,
    output TE2,
    output TE3,

    //timing and wait
    output RDY,         //cpu RDY signal. BRDY is disabled so there are no burst cycles
    output SLOT_RDY,    //wait signal from SLPC slots

    //chip enables
    output rom_en,
    output sram_en,
    output lcd_en,
    output PIT_en,
    output rtc_en,
    output PIC1_en,
    output PIC0_en,
    output hd0_RD,
    output hd0_WR,
    output kbd_en,
    output cpld1_reg0_en,
    output vgamap_en,
    output cpld1_reg1_en,
    output SMEMR,
    output SMEMW,
    output cfcard_en,
    output xbus_en,
    output z80bus_en,
    output isabus_en,
    output interrupt_vector,        //output 1 if the host system is accessing a low enough memory location that it's probably an interrupt vecotr
    output ts_ctrl,                  //set to 1 to deactivate fpga bus tranciever
    inout [7:0]xd

    );

    //works
    manageReset mr(FPGA_RESET, SYSTEM_RESET, CPU_CLK);

    //should work
    memCycles mc(DC, WR, MIO, ADS, MEMR, MEMW, IOR, IOW, INTA, HALT, CPU_CLK);

    BE_to_A00A01 bta(BE0, BE1, BE2, BE3, A01, A00, ADS, CPU_CLK);

    reg [31:0]aa;
    //assign [31:0]aa = [31:2]address;
    always@(*) begin
        aa = {address[31:2], A01, A00};
    end

    reg v9958_en;
    reg sram_active;    //using sram_active for the enable signel since delaying the enable by 1 or 2 clocks might make it more reliable
    wire lcd_active;
    addressDecode adc(
        A00,
        A01,
        aa[2],
        aa[3],
        aa[4],
        aa[5],
        aa[6],
        aa[7],
        aa[8],
        aa[9],
        aa[10],
        aa[11],
        aa[12],
        aa[13],
        aa[14],
        aa[15],
        aa[16],
        aa[17],
        aa[18],
        aa[19],
        aa[20],
        aa[21],
        aa[22],
        aa[23],
        aa[24],
        aa[25],
        aa[26],
        aa[27],
        aa[28],
        aa[29],
        aa[30],
        aa[31],
		MIO,
		WR,
		DC,
		rom_en,
		sram_active,
		lcd_active,
		PIT_en,
		rtc_en,
		PIC1_en,
		PIC0_en,
		hd0_RD,
		hd0_WR,
		kbd_en,
		cpld1_reg0,
		vgamap_en,
		cpld1_reg1,
        v9958_en,
		SMEMR,
		SMEMW,
        ADS,
        CPU_CLK,
        interrupt_vector
	);

    trancieverControl tc(A00, A01, ADS, TE0, TE1, TE2, TE3);

    wire WAIT_READY;
    waitStateControl wsc(lcd_active, rom_en, kbd_en, CPU_CLK, ADS, SLOT_RDY, v9958_en, sram_active, lcd_en, WAIT_READY, sram_en);
    always@(*) begin
        RDY <= ~(~WAIT_READY & ADS);
    end

    assign ts_ctrl = 1;     //keep this disabled

    //doesn't work. Will probably never figure out why
    //assign ts_ctrl = sram_active;   //use bram as system ram
    //wire bramW, bramR;
    //assign bramW = (~MEMW & ~sram_active);
    //assign bramR = (~MEMR & ~sram_active);  //assuming active high
    //implicit_bram fuckingRam(CPU_CLK, bramR, bramW, aa[8:0], aa[8:0], xd[7:0], xd[7:0]);



endmodule
