module shifter_tb();
    reg [15:0] in;
    reg [1:0] shift;

    wire [15:0] sout;
    reg err;

    shifter DUT (in,shift,sout);

    task checker;
        input [15:0] expected_sout;
        begin 
            if( sout !== expected_sout ) begin
            $display("ERROR ** out is %b, expected %b", sout, expected_sout);
            err = 1'b1;
            end
        end
    endtask

    initial begin 
        err = 0; //error is 0
        in = 16'b0000_0000_0000_1111; shift = 00; #10;  //checking to see if shift op 00 works 
        checker(16'b0000_0000_0000_1111); //no change to in 

        in = 16'b0000_0000_0000_1111; shift = 01; #10; //checking to see if left shift works
        checker(16'b0000_0000_0001_1110); //shifted 1 bit to the left, LSB is 0

        in = 16'b0000_0000_0000_1111; shift = 10; #10; //checking to see if right shift works
        checker(16'b0000_0000_0000_0111); //shifted to the right, MSB is 0

        in = 16'b1000_0000_0000_1110; shift = 11; #10; //checking to see if right shift with MSB copy works
        checker(16'b1100_0000_0000_0111); //shifted to the right, MSB is in[15]

        if( ~err ) $display("PASSED");
        else $display("FAILED");
        //$stop;
        
    end
endmodule
        