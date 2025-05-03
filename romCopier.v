//copy the contents of spi rom into fpga block ram somehow

// https://www.fpga4student.com/2017/08/verilog-code-for-clock-divider-on-fpga.html
// fpga4student.com: FPGA projects, VHDL projects, Verilog projects
// Verilog project: Verilog code for clock divider on FPGA
// Top level Verilog code for clock divider on FPGA
module clockDivider(clock_in,clock_out);
input clock_in; // input clock on FPGA
output clock_out; // output clock after dividing the input clock by divisor
reg[27:0] counter=28'd0;
parameter DIVISOR = 28'd4;
reg clock_out_i;
// The frequency of the output clk_out
//  = The frequency of the input clk_in divided by DIVISOR
// For example: Fclk_in = 50Mhz, if you want to get 1Hz signal to blink LEDs
// You will modify the DIVISOR parameter value to 28'd50.000.000
// Then the frequency of the output clk_out = 50Mhz/50.000.000 = 1Hz
assign clock_out = clock_out_i;
always @(posedge clock_in)
begin
 counter <= counter + 28'd1;
 if(counter>=(DIVISOR-1))
  counter <= 28'd0;

 clock_out_i <= (counter<DIVISOR/2)?1'b1:1'b0;

end
endmodule

module CopyDataSpiRom(
    input RESET,        //reset signal that resets all the stuff normnally i guess or whatever
    input CLOCK,        //the system clock. i.e. the 25mhz clock that runs the cpu and the fpga
    input MISO,         //the input spi line
    output MOSI,        //the output spi line
    output SPI_CLK,     //the spi clock signal. use this to drive spi clock
    output SPI_SS,       //drives the spi SS line for chip select or whatever
    output[7:0] romData,
    output memWrite,    //if 1 = write internal block ram. if 0 = don't write. write enable basicly
    output[15:0] romAddress    //the address in block ram to write to
    );
    
    reg SPI_SS_i, memWrite_i;


    reg[23:0] romWriteAddress;
    reg[7:0] addressIndex;
    reg[23:0] romAddress_i;

    reg[3:0] step;//which step the spi state machine is in
    reg[7:0] inputData;//what to send to the spi slave device
    reg validData;  //set to 1 to send a byte
    wire spiDataReady;//when this is high, it has completed sending the sendable byte
    wire spiDataValidw;
    wire[7:0] dataOut;
    wire spiClk;
    reg ispimiso;
    wire ospimosi;
    reg mosiOverrideBit;//needed for the address parameter part of the spi
    wire sckOverride;    //the override sck signal for when it needs to transmit the special 24 bit spi rom address

    SPI_Master sm(RESET, CLOCK, inputData, validData, spiDataReady, spiDataValidw, dataOut, spiClk, ispimiso, ospimosi);

    //goddammit, its out of fucking phase
    wire sckOverrideInverse;
    clockDivider cd(CLOCK,sckOverrideInverse);
    assign sckOverride = !sckOverrideInverse;//fixed

    assign romData = step == 3 ? overrideDataOut : dataOut;
    assign memWrite = memWrite_i;
    assign romAddress = romAddress_i;
    //assign SPI_CLK = spiClk;
    assign SPI_CLK = step == 2 | step == 3 ? sckOverride : spiClk;
    assign SPI_SS = SPI_SS_i;
    assign MOSI = step == 2 ? mosiOverrideBit : ospimosi;

    reg[4:0] numBitsThisByte;       //during the data read phase, keep track of bits in a byte
    //reg[16:0] numBytesRecieved;     //keep track of the total number of bytes recieved so it can stop after getting 65535 of them

    reg[7:0] ctrSinceStep1;
    reg[7:0] stupidDivideCtr;
    reg[7:0] overrideDataOut;
    always @(posedge CLOCK)
    begin
        if (~RESET) begin
            step <= 0;
            romWriteAddress <= 24'h100000;
            addressIndex <= 23;//start at 22 because index position 23 has to be artifically specially preloaded because verilog and fuck and timing and flip flops and all that horseshit
            romAddress_i <= 16'h0;
            SPI_SS_i <= 1;
            memWrite_i <= 0;
            ctrSinceStep1 <= 0;
            stupidDivideCtr <= 0;
            numBitsThisByte <= 0;
        end

        if (step == 0) begin
            SPI_SS_i <= 0;
            //send the 0x03 command for read data
            inputData <= 8'h3;
            validData <= 1;
            step <= 1;
        end else if (step == 1) begin
            validData <= 0;
            ctrSinceStep1 <= ctrSinceStep1 + 1;
            if (spiDataReady & ctrSinceStep1 > 10) begin
                step <= 2;
                mosiOverrideBit <= romWriteAddress[23];
            end
        end else if (step == 2) begin
            //this approach seems to work for some stupid reason despite not special casing the length of the first cycle. i can't wait to delete it all and remake it when i try to run it on hardware and it ends up not working because of problems i wont know about until i try to syntehsize it for the first time
            if (stupidDivideCtr == 3 & addressIndex > 0) begin
                addressIndex <= addressIndex - 1;
                mosiOverrideBit <= romWriteAddress[addressIndex];
                stupidDivideCtr <= 0;
            end else begin
                stupidDivideCtr <= stupidDivideCtr + 1;
                if (stupidDivideCtr != 0) begin
                    mosiOverrideBit <= romWriteAddress[addressIndex];
                end
            end
            //bits 24-20 = 1
            //might have to manually take control of the mosi line to make a 24 bit transfer possible. fuck.
            if (addressIndex == 8'h0 & stupidDivideCtr == 3) begin
                step <= 3;
                stupidDivideCtr <= 1;
                //numBitsThisByte <= 1;
            end
        end else if (step == 3) begin
            ispimiso <= MISO;
            //the command has been sent. the address parameter has been sent. now, start saving data bits into block ram and stop after its been done 65535 times
            inputData <= 8'h0;
            /*if (spiDataValidw) begin
                romAddress_i <= romAddress_i + 1;
                memWrite_i <= 1;
            end
            else begin
                memWrite_i <= 0;
            end*/

            if (stupidDivideCtr == 1) begin
                overrideDataOut[numBitsThisByte] <= MISO;
            end

            if (numBitsThisByte == 7 && stupidDivideCtr == 0) begin
                numBitsThisByte <= 0;
            end else if (stupidDivideCtr == 0) begin
                numBitsThisByte <= numBitsThisByte + 1;
            end

            if (numBitsThisByte == 7 && stupidDivideCtr == 3) begin
                memWrite_i <= 1;
            end else if (numBitsThisByte == 7 && stupidDivideCtr == 0) begin
                romAddress_i <= romAddress_i + 1;   //increment the rom address just a LITTLE bit after the write signal is asserted
                memWrite_i <= 0;
            end else begin
                memWrite_i <= 0;
            end

            if (stupidDivideCtr == 3) begin
                stupidDivideCtr <= 0;
            end else begin
                stupidDivideCtr <= stupidDivideCtr + 1;
            end

        end else begin
            validData <= 0;
        end
            

        //if (spiDataReady) begin
        //    step <= step + 1;
        //end
        //validData <= 0;
        //inputData <= 8'h3;// 0x03 = the read data command
        //we need to send the address 0x100000 over the 
    end
endmodule