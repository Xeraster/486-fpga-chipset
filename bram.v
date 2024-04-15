module implicit_bram(input wire clk, input wire rd_en, input wire wr_en, input wire [8:0] rd_addr, input wire [8:0] wr_addr, input wire [7:0] data_in, output reg [7:0] data_out, output reg valid_out);

   reg [7:0] memory [0:511];        //512 bytes of 8 bit ram. Don't spend it all in one place
   integer i;

   initial begin
      for(i = 0; i <= 511; i=i+1) begin
         memory[i] = 8'b001;
      end
      // data_out = 0; //should not exist if we want bram to be inferred
      valid_out = 0;
   end

   always @(posedge clk)
   begin
      // default
      valid_out <= 0;

      if(wr_en) begin
         memory[wr_addr] <= data_in;
      end
      if (rd_en) begin
         data_out <= memory[rd_addr];
         valid_out <= 1;
      end
   end
endmodule