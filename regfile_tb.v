module regfile_tb();
    reg [15:0] data_in;
    reg [2:0] writenum, readnum;
    reg write, clk, err;

    wire [15:0] data_out;

    regfile DUT (data_in,writenum,write,readnum,clk,data_out);

    initial begin
        clk = 0; #5;
        forever begin
            clk = 1; #5;
            clk = 0; #5;
        end
    end

    task checker;
        input [15:0] expected_data_out;

        begin 
            if( data_out !== expected_data_out ) begin
            $display("ERROR ** data_out is %b, expected %b", data_out, expected_data_out );
            err = 1'b1;
            end
        end
    endtask
  

    initial begin
        data_in = 16'd65; writenum = 3'b000; readnum =3'b000; write = 1'b1; err = 1'b0; #10; 
        data_in = 16'd100; writenum = 3'b001; readnum = 3'b000; write = 1'b1; err = 1'b0; #10;
        data_in = 16'd45; writenum = 3'b100; readnum = 3'b000; write = 1'b1; err = 1'b0; #10;
        data_in = 16'd12; writenum = 3'b101; readnum = 3'b000; write = 1'b1; err = 1'b0; #10;
        write = 1'b0; #5;
        readnum = 3'b000;
        checker(16'd65); #5; 
        readnum = 3'b001; #5;
        checker(16'd100); #5;
        readnum = 3'b100; #5;
        checker(16'd45); #5;
        readnum = 3'b101; #5;
        checker(16'd12); #5
        
        if( ~err ) $display("PASSED");
        else $display("FAILED");
        //$stop;

        
    end
endmodule

    
