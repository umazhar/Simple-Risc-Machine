
`define MREAD 2'd1
`define MWRITE 2'd2
`define MNONE  2'd3 

module top(KEY,SW,LEDR,HEX0,HEX1,HEX2,HEX3,HEX4,HEX5);
  input [3:0] KEY;
  input [9:0] SW;
  output [9:0] LEDR;
  output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

  wire [1:0]  mem_cmd;
  wire [8:0]  mem_addr;
  wire [15:0] read_data, write_data, dout; 
  wire N, V, Z, write_RAM, tristate_enable; 

  cpu CPU ( .clk          (~KEY[0]),
            .reset        (~KEY[1]),
            .N            (N),
            .V            (V),
            .Z            (Z),
            .mem_cmd      (mem_cmd), 
            .mem_addr     (mem_addr),   
            .write_data   (write_data), 
            .read_data    (read_data)
          );
  RAM MEM ( .clk              (~KEY[0]),
            .read_address     (mem_addr[7:0]),
            .write_address    (mem_addr[7:0]),
            .write            (write_RAM),
            .din              (write_data),
            .dout             (dout)
          );

  //RAM Input/Output Logic
  assign write_RAM = (`MWRITE == mem_cmd) & (1'b0 == mem_addr[8]); // sets the value of write going into RAM
  assign tri_state_enable = (`MREAD == mem_cmd) & (1'b0 == mem_addr[8]);   //enable input into tristate driver dout coming out of RAM
  assign read_data = tri_state_enable ? dout : {16{1'bz}};   //tri state driver dout
  
  //Switch logic
  assign tri_state_switch_enable = ((mem_addr == 9'h140) && (mem_cmd == `MREAD));
  //left tristate switch driver
  assign read_data[15:8] = tri_state_switch_enable ? 8'h00 : {8{1'bz}};
  //right tristate switch driver
  assign read_data[7:0] = tri_state_switch_enable ? SW[7:0] : {8{1'bz}};
  
  //LED register enable
  assign led_enable = ((mem_addr == 9'h100) && (mem_cmd == `MWRITE));

  vDFFE #(8) ledr_register(.clk (KEY[0]), .en (led_enable), .in (write_data[7:0]), .out (LEDR[7:0]));



endmodule 

module RAM(clk,read_address,write_address,write,din,dout);
  parameter data_width = 16; 
  parameter addr_width = 8;
  parameter filename = "data.txt";

  input clk;
  input [addr_width-1:0] read_address, write_address;
  input write;
  input [data_width-1:0] din;
  output [data_width-1:0] dout;
  reg [data_width-1:0] dout;

  reg [data_width-1:0] mem [2**addr_width-1:0];

  initial $readmemb(filename, mem);

  always @ (posedge clk) begin
    if (write)
      mem[write_address] <= din;
    dout <= mem[read_address]; // dout doesn't get din in this clock cycle 
                               // (this is due to Verilog non-blocking assignment "<=")
  end 
endmodule

