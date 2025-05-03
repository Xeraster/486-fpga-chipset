//i recently identified some issues so now it's time to redo some parts of this

/*i made this entire thing before I really understood what I was doing in verilog. It should not be referred to as an example of best practices.
maybe I'll make it better, maybe I won't. I'm working on an ISA version of this chipset.

as of 03/05/2025 these are the proposed but untested changes that could be made in order to make the cfcard work
*/
`include "utils.v"

//i'm sick and tired of parellel roms because they break all the time. i need this so I can try to use the serial spi rom for bios
`include "SPI_Master.v"
`include "romCopier.v"

//16kb block ram for storing 1/4th of the bios at a time
module bram_16384x8(din, write_en, waddr, wclk, raddr, rclk, dout);//16384x8
parameter addr_width = 14;
parameter data_width = 8;
input [addr_width-1:0] waddr, raddr;
input [data_width-1:0] din;
input write_en, wclk, rclk;
output reg [data_width-1:0] dout;
reg [data_width-1:0] mem [(1<<addr_width)-1:0];

always @(posedge wclk) // Write memory.
begin
    if (write_en)
    begin
        mem[waddr] <= din; // Using write address bus.
    end
end

always @(posedge rclk) // Read memory.
begin
    dout <= mem[raddr]; // Using read address bus.
end
endmodule

//tested working 02/24/24
/*module BE_to_A00A01 (b0, b1, b2, b3, a0, a1, ADS, CPU_CLK);
    input b0, b1, b2, b3;
    input ADS, CPU_CLK;
    output reg a0, a1;*/

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
    input[31:0] addressBus,
    input MIO,                  //need to be able to distinguish IO and memory cycles from each other
    input WR,                   //need to be able to distinguish read and write cycles from each other
    input DC,                   //DC probably doesn't matter for this. You *could* use DC to chip select ram vs rom if you wanted but meh

    output rom_en,              //FFFE000h
    output sram_en,
    output lcd_active,              //A000h-A003h
    output PIT_en,              //0040h-0043h
    output rtc_en,              //0070h-007Fh
    output PIC1_en,             //00A0h-00A1h
    output PIC0_en,             //0020h-0023h
    output hd0_RD,              //A030h-A03Fh
    output hd0_WR,
    output kbd_en,              //0060h, 0064h
    output cpld1_reg0_en,       //0061h
    output vgamap_en,           //A0000h-C7FFFh
    output cpld1_reg1_en,
    output v9958_en,           //A020-A023
    output cfcard_en,

    output SMEMR,               //active any time a memory read happens below the 20 bit address boundary
    output SMEMW,               //active any time a memory write happens below the 20 bit address boundary
    input ADS,                       //there needs to be an ads signal because chip select lines should only be active while valid data is on the bus
    input clock,                     //clock cycles have to be counted to get lcd enable timing just right
    output interrupt_vector,          //debugging output for if the cpu is accessing an interrupt vector in ram
    input valid_bus            //prevent it from selecting devices during invalid bus states to avoid having to make per-device verilog bus changes
);
    //wire low16, high16;
    //assign low16 = (a00|a01|a02|a03|a04|a05|a06|a07|a08|a09|a10|a11|a12|a13|a14|a15);
    //assign high16 = (a16|a17|a18|a19|a20|a21|a22|a23|a24|a25|a26|a27|a28|a29|a30|a31);
    //reg lcd_en_base;

    //the same as v9958 except different
    //assign cfcard_en = ~(~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & a05 & a04) & ~MIO & ADS;
    assign cfcard_en = ~(addressBus >= 32'hA030 & addressBus <= 32'hA03F & ~MIO & ADS & valid_bus);
    //supposed to be A030-A03F

    assign rom_en = ~(addressBus >= 32'hFF000000 & MIO & ADS);
    assign sram_en = ~(addressBus < 32'hFF000000 & MIO & ADS) | ~valid_bus;
    assign lcd_active = (addressBus >= 32'hA000 & addressBus <= 32'hA003 & ~MIO & ADS);
    assign PIT_en = ~(addressBus >= 32'h40 & addressBus <= 32'h43 & ~MIO & ADS);
    assign PIC0_en = ~(addressBus >= 32'h20 & addressBus <= 32'h23 & ~MIO & ADS);
    assign PIC1_en = ~(addressBus >= 32'hA0 & addressBus <= 32'hA3 & ~MIO & ADS);
    assign rtc_en = ~(addressBus >= 32'h70 & addressBus <= 32'h7F & ~MIO & ADS);
    assign SMEMR = ~((addressBus < 32'h100000) & MIO & ~WR & ADS);
    assign SMEMW = ~((addressBus < 32'h100000) & MIO & WR & ADS);
    assign kbd_en = ~(addressBus >= 32'h60 & addressBus <= 32'h67 & ADS);
    assign v9958_en = ~(addressBus >= 32'hA020 & addressBus <= 32'hA023 & ~MIO & ADS & valid_bus);
    assign interrupt_vector = (addressBus > 32'h1000) & MIO & ADS;
    
    //reg [0:3] enable_delay;
    //do the easy obvious stuff first
    //always @(*)
    //begin
        
        //if bit 22 or higher is a 1, enable rom. this way, rom wraps around from the 4mb boundary all the way to the 4gb 32 bit address limit
        //rom_en = ~((a22|a23|a24|a25|a26|a27|a28|a29|a30|a31)&MIO&ADS);
        //rom_en = ~(addressBus >= 32'hFF000000 & MIO & ADS);

        //sram_en = ~((~a22|~a23|~a24|~a25|~a26|~a27|~a28|~a29|~a30|~a31)&MIO&ADS);
        //sram_en = ~(addressBus < 32'hFF000000 & MIO & ADS);
        
        //A000h-A003h. lcd active is the normal lcd active high signal just without the beginning wait states
        //lcd_active = (addressBus >= 32'hA000 & addressBus <= 32'hA003 & ~MIO & ADS);

        //0040h-0043h
        //PIT_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & a06 & ~a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //PIT_en = ~(addressBus >= 32'h40 & addressBus <= 32'h43 & ~MIO & ADS);

        //0020h-0023h
        //PIC0_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //PIC0_en = ~(addressBus >= 32'h20 & addressBus <= 32'h23 & ~MIO & ADS);
        //00A0h-00A3h
        //PIC1_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        //PIC1_en = ~(addressBus >= 32'hA0 & addressBus <= 32'hA3 & ~MIO & ADS);

        //0070h-007Fh
        //rtc_en = ~(addressBus >= 32'h70 & addressBus <= 32'h7F & ~MIO & ADS);

        //lower 20 bit mem bus cycle definitions
        //SMEMR = ~((~high16 && ~a16 & ~a17 & ~a18 & ~a19) & MIO & ~WR & ADS);
        //SMEMW = ~((~high16 && ~a16 & ~a17 & ~a18 & ~a19) & MIO & WR & ADS);

	    //keyboard controller is ports 0x60 andd 0x64. HT6542B is active low. 0060-0067 becuase laziness
	    //kbd_en = ~(~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & a06 & a05 & ~a04 & ~a03 & ADS);

        //active low. high when not selected. video card should be optional even without a pull-up resistor on the slot ready line
        //v9958_en = ~(~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;

        //interrupt_vector = (~high16 & ~a15 & ~a14 & ~a13 & ~a12 & ~a11) & MIO & ADS;    //if it accesses the lower 0-1024 bytes of address space, then its an interrupt vector exception or whatever

        //output a debug signal if the cpu is accessing the bottom 1024
	
	    /*if (enable_delay<5)
            lcd_active <= 0;
        else
            lcd_active <= (~high16 & a15 & ~a14 & a13 & ~a12 & ~a11 & ~a10 & ~a09 & ~a08 & ~a07 & ~a06 & ~a05 & ~a04 & ~a03 & ~a02) & ~MIO & ADS;
        */
    //end

endmodule

module waitStateControl(
    input lcd_active,
    input rom_en,       //experiment with rom wait states and see what happens
    input kbd_en,       //definitely needs wait states
    input clock,        //the system clock
    input ADS,          //wait state counting should only be valid while ADS is high
    input SLOT_RDY,     //signal from the z80 wait compatible line
    input v9958_en,     //active low, when low, use SLOT_RDY to determine wait states
    input cfcard_en,
    input sram_active,      //add a few wait states to sram access
    output reg lcd_en,  //the 20x2 lcd needs wait states at both the beginning and the end of the bus cycle
    output reg RDY,      //output ready or not
    output reg sram_en      //maybe delaying sram enable just a little will make it work better
);

    reg [4:0] lcdcounter;
    reg [4:0] romcounter;
    reg [4:0] kbdcounter;
    reg [4:0] sramcounter;
    reg [4:0] cfcardcounter;

    //clear the wait state counters on the rising edge of ADS
    always@(posedge clock)
    begin
        if (~ADS)
            begin
            lcdcounter <= 0;
            kbdcounter <= 0;
            romcounter <= 0;
            sramcounter <= 0;
            cfcardcounter <= 0;
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

            if (~cfcard_en & cfcardcounter < 15) begin
                cfcardcounter <= cfcardcounter + 1;
            end
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
        else if (cfcardcounter < 6 & ~cfcard_en)
            RDY <= 1;//this will wait state it all right, but additional steps may have to be taken to ensure the right bytes are getting read and written
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

module waitStateControl_improved(
    input lcd_active, 
    input rom_en, 
    input kbd_en,
    input clock,
    input ADS,
    input SLOT_RDY,
    input v9958_en,
    input cfcard_en,
    input sram_active,
    output lcd_en,
    output RDY,
    output sram_en,
    output valid_bus,            //1 if there is valid data to or from the host on the bus, 0 if GTFO. mainly for debugging purposes
    output[8:0] tstates
    );

    reg [4:0] lcdcounter;       //actually needs a lot of wait states
    reg [4:0] romcounter;       //actually needs a lot of wait states
    reg [4:0] kbdcounter;       //actually needs a lot of wait states
    reg [4:0] sramcounter;      //basically needs no wait states
    reg [4:0] cfcardcounter;    //actually needs a lot of wait states

    //reg [4:0] waitCtr;          //what if I just use a single counter instead of a bunch

    assign sram_en = sram_active;
    assign lcd_en = lcd_active;
    reg iRDY;
    assign RDY = iRDY;

    reg ivalid_bus;
    assign valid_bus = ivalid_bus;

    assign tstates = tcycles; 
    reg[8:0] tcycles; //you just have to count bus clocks to figure out when the end of the cycle is supposed to be. There is no single pin on the 486 that indicates this.
    //also use this for wait states

    always@(posedge clock/* or negedge ADS*/) begin
        if (~ADS) begin
            lcdcounter <= 0;
            kbdcounter <= 0;
            romcounter <= 0;
            sramcounter <= 0;
            cfcardcounter <= 0;
            tcycles <= 0;
            //iRDY <= 1;//not doing this causes unpredictable behavior
            //waitCtr <= 0;
            ivalid_bus <= 1;
        end else if (~RDY) begin
            ivalid_bus <= 0;
        end else begin
            //waitCtr <= waitCtr + 1;

            if (tcycles < 240) begin
                tcycles <= tcycles + 1;
            end

            /*if (tcycles < 7 & ~rom_en) begin   //7 wait states is enough for the rom at 25mhz
                iRDY <= 1;
            end else if (tcycles < 15 & lcd_active) begin
                iRDY <= 1;
            end else if (tcycles < 7 & ~kbd_en) begin
                iRDY <= 1;
            end else if (tcycles < 1 & ~sram_active) begin
                iRDY <= 1;
            end else if (~v9958_en & ~SLOT_RDY) begin
                iRDY <= 1;
            end else if (tcycles < 15 & ~cfcard_en) begin
                iRDY <= 1;
            end else begin
                iRDY <= 0;
            end*/
        end

        //its VERY IMPORTANT (to the FPGA, not the 486) that RDY ONLY GOES LOW WHEN ACTUALLY READY TO END THE BUS CYCLE
        //this is because THE ONLY WAY to avoid bus timing errors is to know EXACTLY when the bus cycle is ending. 
        //inserting additional wait states to circumvent the issues caused by not doing this on a per-device basis is bullshit and stupid
        /*if (~RDY) begin
            ivalid_bus <= 0
        end else begin
            ival
        end*/
    end

    //ugh, what a mess this is
    always@(negedge clock or negedge ADS) begin
        if (~ADS) begin
            iRDY <= 1;
        end else if (tcycles < 7 & ~rom_en) begin   //7 wait states is enough for the rom at 25mhz
            iRDY <= 1;
        end else if (tcycles < 15 & lcd_active) begin
            iRDY <= 1;
        end else if (tcycles < 7 & ~kbd_en) begin
            iRDY <= 1;
        end else if (tcycles < 1 & ~sram_active) begin
            iRDY <= 1;
        end else if (~v9958_en & (~SLOT_RDY | tcycles < 16)) begin//test bench is easier when this has less wait states
            iRDY <= 1;
        end else if (tcycles < 15 & ~cfcard_en) begin
            iRDY <= 1;
        end else if (tcycles > 0) begin
            iRDY <= 0;
        end
    end

endmodule

//input control signals and when 
module busCycleValidator(
    input RDY,
    input clock,
    input ADS,
    output bus_valid,       //1 if valid stuff on bus, 0 if the enable signals need to be deasserted. for more information, rtfm
    output[4:0] tcycles,
    input actualBusCycle
);

    reg ibus_valid, iT1, iT2;
    reg[4:0] itcycles;
    assign tcycles = itcycles;
    assign bus_valid = ibus_valid;
    always@(posedge clock) begin
        if (actualBusCycle & ADS) begin
            //since this happens on the rising edge of clock, by the time its able to sampel the state of RDY, it its low then its time to stop having stuff on the bus
            ibus_valid <= 1;
            itcycles <= 0;
        end else/* if (ADS) */begin
            ibus_valid <= 0;
        end

        if (itcycles < 2) begin
            itcycles <= tcycles + 1;
        end
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
    input SLOT_RDY,    //wait signal from SLPC slots

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
    //output SMEMR,
    //output SMEMW,
    output cfcard_en,
    output xbus_en,
    output z80bus_en,
    output isabus_en,
    output interrupt_vector,        //output 1 if the host system is accessing a low enough memory location that it's probably an interrupt vecotr
    output ts_ctrl,                  //set to 1 to deactivate fpga bus tranciever
    output [7:0]xd

    );

    //test signals
    //assign xd[0] = cfcard_en;
    //assign xd[1] = v9958_en;
    //assign xd[2] = SLOT_RDY;
    //assign xd[3] = RD & WE;

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

    wire memWrite;
    wire[7:0] spiDataIn;
    wire[15:0] romAddress;
    CopyDataSpiRom cdsr(RESET, BUSCLK, MISO, MOSI, SPICLK, SPISS, spiDataIn, memWrite, romAddress);

    //where spi rom data extracted from the spi rom gets copied to
    //reg[15:0] biosRequestAddress;
    wire[15:0] biosRequestAddress;
    assign biosRequestAddress = address[15:0];
    wire[7:0] biosRequestData;
    assign xd = biosRequestData;//output the contents of block ram bios rom at all times because why not
    bram_16384x8 bram(spiDataIn, memWrite, romAddress, CPU_CLK, biosRequestAddress, CPU_CLK, biosRequestData);

    wire v9958_en;
    wire sram_active;    //using sram_active for the enable signel since delaying the enable by 1 or 2 clocks might make it more reliable
    wire lcd_active;
    wire[31:0] fullAddress;
    assign fullAddress[31:2] = address;
    assign fullAddress[1] = A01;
    assign fullAddress[0] = A00; 
    addressDecode adc(
        fullAddress,
		MIO,
		WR,
		DC,
		ts_ctrl,
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
        cfcard_en,
		SMEMR,
		SMEMW,
        ADS,
        CPU_CLK,
        interrupt_vector,
        valid_bus
	);

    trancieverControl tc(A00, A01, ADS, TE0, TE1, TE2, TE3);

    //wire WAIT_READY;
    //reg iRDY;
    //assign RDY = iRDY;

    wire valid_bus;

    wire[8:0] tstates;
    waitStateControl_improved wsc(lcd_active, rom_en, kbd_en, CPU_CLK, ADS, SLOT_RDY, v9958_en, cfcard_en, sram_active, lcd_en, RDY, sram_en, valid_bus, tstates);
    //always@(*) begin
    //    iRDY <= ~(~WAIT_READY & ADS);
    //end

    assign rom_en = 1;      //stop using this because im going to try using the spi rom for bios
    //assign ts_ctrl = 1;     //keep this disabled
    /*TODO: 
        - completely disable the rom chip by setting it to 1 
        - set ts_ctrl to the rom_en, hopefully the W/R on A->B thing will work out
        - make the address bus feed in to the bios rom block ram at all times
        - elongate the reset startup time to ensure the rom can be read
    */

    //MIO 1 = MEMORY. MIO 0 = IO.
    assign IOREQ = /*MIO | ~valid_bus*/~(~MIO & valid_bus);
    assign MREQ = /*~(MIO & valid_bus & addressBus < 32'hFFFF)*/1;  //meh, no x86 compatible SLPC peripherals ever made used memory mapped I/O
    assign RD = ~(~IOR & valid_bus);
    //assign WE = ~(~IOW & valid_bus);
    //IF THE V9958 IS BEING SELECTED, DON'T ALLOW WE TO BE LOW WHILE RDY IS LOW. The v9958 latches write data on the RISING EDGE of this signal. hopefully that fixes all issues once and for all
    //assign WE = ~(~IOW & valid_bus & (v9958_en | ( ~v9958_en & tstates < 10 & tstates > 5)));//if IOW is low and valid bus is high, low. but do a special case for the v9958

    assign WE = ~(~IOW & valid_bus & (v9958adjust | cfcardreadadjust) & tstates > 0);
    //assign WE = ~(~IOW & valid_bus);

    reg cfcardreadadjust;
    reg v9958adjust;
    always@(posedge CPU_CLK) begin
        if ((tstates > 4 & tstates < 11 & ~cfcard_en)) begin
            cfcardreadadjust <= 1;
        end else begin
            cfcardreadadjust <= 0;
        end

        if (( ~v9958_en & tstates < 10 & tstates > 5)) begin
            v9958adjust <= 1;
        end else begin
            v9958adjust <= 0;
        end
    end

endmodule
