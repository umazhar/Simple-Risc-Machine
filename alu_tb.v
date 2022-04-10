module ALU_tb();
    reg     [15:0] Ain, Bin;
    reg     [1:0] ALUop;
    wire    [15:0] out;
    wire    [2:0] status;
    reg     err;

    ALU DUT(Ain,Bin,ALUop,out,status);

    task checker;  // create checker to check for status flags
        input [2:0] expected_status;
        begin 
            if( status !== expected_status ) begin
            $display("ERROR ** status is %b, expected %b", status, expected_status );
            err = 1'b1;
            end
        end
    endtask

    //checking negative, overflow and zero flags

    initial begin 
        err = 0;
        Ain = 16'd12; Bin = 16'd20; ALUop = 2'b01; #10; //checking negative flag
        checker(3'b100); 
        
        Ain = 16'd0; Bin = 16'd0; ALUop = 2'b01; #10; //checking zero flag
        checker(3'b001);
        
        Ain = 16'b0111_1111_1111_1111; Bin = 16'b0111_1111_1111_1111; ALUop = 2'b00; #10;//checking overflow flag
        checker(3'b110);//negative flag is 1 because bit 16 should be a 1

        Ain = -16'd10000; Bin = -16'd10000; ALUop = 2'b00; #10;//negative flag
        checker(3'b100);

        Ain = -16'd3245; Bin = 16'd4000; ALUop = 2'b00; #10; //no flag, testing negative + larger magnitude positive
        checker(3'b000);

        Ain = -16'd32045; Bin = 16'd20324; ALUop = 2'b01; #10; //overflow flag by subtracting two large negative numbers
        checker(3'b010);

        Ain = 16'd0; Bin = 16'd2; ALUop = 2'b11; #10; //and 
        checker(3'b100);
        
        if( ~err ) $display("PASSED");
        else $display("FAILED");
        //$stop;
        
    end
endmodule