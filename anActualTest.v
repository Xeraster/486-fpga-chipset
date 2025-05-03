//i lost the other tests so time to make a new one

//the main file for the 486 chipset
`include "main.v"
//`include "SPI_Master.v"

`default_nettype none

module tb();
reg BUSCLK;
reg RESET;//i forgor if its active high or active low

reg [31:0] addressBus;
wire SYSTEM_RESET;
reg DC, WR, MIO, ADS;
wire MEMR, MEMW, IOR, IOW, INTA, HALT;
wire A00, A01;
reg BE0, BE1, BE2, BE3;

manageReset mr(RESET, SYSTEM_RESET, BUSCLK);

memCycles mc(DC, WR, MIO, ADS, MEMR, MEMW, IOR, IOW, INTA, HALT, BUSCLK);

BE_to_A00A01 bta(BE0, BE1, BE2, BE3, A01, A00, ADS, BUSCLK);

wire TE0, TE1, TE2, TE3;
trancieverControl tc(A00, A01, ADS, TE0, TE1, TE2, TE3);

/*reg[7:0] poop;
reg spiDataValid;   //set this to 1 to write whatever
wire spiDataReady;//when this is high, it has completed sending the sendable byte
wire spiDataValidw;
wire[7:0] poopOut;
wire spiClk;
wire ispimiso;//input from the spi slave device. sdo? sdi? one of them
wire ospimosi;//idk waht this does. you know how the above line is either sdo or sdi? this is whichever one the above isn't
SPI_Master sm(RESET, BUSCLK, poop, spiDataValid, spiDataReady, spiDataValidw, poopOut, spiClk, ispimiso, ospimosi);*/
reg MISO;
wire MOSI, SPICLK, SPISS, memWrite;
wire[7:0] spiDataIn;
wire[15:0] romAddress;
CopyDataSpiRom cdsr(RESET, BUSCLK, MISO, MOSI, SPICLK, SPISS, spiDataIn, memWrite, romAddress);

//where spi rom data extracted from the spi rom gets copied to
reg[15:0] biosRequestAddress;
wire[7:0] biosRequestData;
bram_65535x8 bram(spiDataIn, memWrite, romAddress, BUSCLK, biosRequestAddress, BUSCLK, biosRequestData);

wire rom_en, sram_active, lcd_active, PIT_en, rtc_en, PIC1_en, PIC0_en, hd0_RD, hd0_WR, kbd_en, cpld1_reg0, vgamap_en, cpld1_reg1, v9958_en, cfcard_en, SMEMR, SMEMW, interrupt_vector;
addressDecode adc(
        addressBus,
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
        cfcard_en,
		SMEMR,
		SMEMW,
        ADS,
        BUSCLK,
        interrupt_vector,
        valid_bus
	);

    reg SLOT_RDY;
    wire sram_en;
    wire WAIT_READY;
    wire RDY;
    wire lcd_en;
    wire valid_bus;
    wire[8:0] tstates;
    waitStateControl_improved wsc(lcd_active, rom_en, kbd_en, BUSCLK, ADS, SLOT_RDY, v9958_en, cfcard_en, sram_active, lcd_en, RDY, sram_en, valid_bus, tstates);
    //always@(*) begin
    //    iRDY <= ~(~WAIT_READY & ADS);
    //end

    //wire bus_valid;
    wire [4:0] tcycles;
    //busCycleValidator bcs(RDY, BUSCLK, ADS, bus_valid, tcycles, actualBusCycle);

    wire IOREQ, MREQ, WE, RD;
    //assign IOREQ = MIO | ~valid_bus;
    //assign MREQ = ~MIO | ~valid_bus;
    //assign RD = IOR | ~valid_bus;
    //assign WE = IOW | ~valid_bus;

    assign IOREQ = /*MIO | ~valid_bus*/~(~MIO & valid_bus);
    assign MREQ = /*~(MIO & valid_bus & addressBus < 32'hFFFF)*/1;  //meh, no x86 compatible SLPC peripherals ever made used memory mapped I/O
    assign RD = ~(~IOR & valid_bus);

    //IF THE V9958 IS BEING SELECTED, DON'T ALLOW WE TO BE LOW WHILE RDY IS LOW. The v9958 latches write data on the RISING EDGE of this signal. hopefully that fixes all issues once and for all
    //assign WE = ~(~IOW & valid_bus & (v9958_en | ( ~v9958_en & tstates < 10 & tstates > 5)));//if IOW is low and valid bus is high, low. but do a special case for the v9958
    assign WE = ~(~IOW & valid_bus & (v9958adjust | cfcardreadadjust) & tstates > 0);
    //assign WE = ~(~IOW & valid_bus);

    reg cfcardreadadjust;
    reg v9958adjust;
    always@(posedge BUSCLK) begin
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

initial begin
    $dumpfile("tb_.vcd");
    $dumpvars(0, tb); 
end

initial begin
    #10
    SLOT_RDY=0;
    ADS=1;
    addressBus=32'h61;
    RESET=1;
    BUSCLK=1;
    BE0=0;
    BE1=1;
    BE2=1;
    BE3=1;
    DC=1;
    MIO=0;
    WR=0;
    #10
    BUSCLK=0;
    RESET=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    RESET=1;
    #10
    BUSCLK=0;
    ADS=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=1;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=0;
    MIO=1;
    BE0=1;
    BE1=0;
    BE2=1;
    BE3=1;
    addressBus=32'hFFFF;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=1;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=1;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    //v9958 test cycle
    ADS=0;
    MIO=0;
    WR=1;
    addressBus=32'hA020;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    ADS=1;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    SLOT_RDY=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    //SLOT_RDY=1;//v9958 deasserts the wait line
    BUSCLK=0;
    #10
    BUSCLK=1;
    #10
    BUSCLK=0;
end

endmodule
