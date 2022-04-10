module cpu_tb();
    reg clk, reset, s, load;
    reg [15:0] in;
    wire [15:0] out;
    wire N, V, Z, w;

    reg err;

    cpu DUT (clk,reset,s,load,in,out,N,V,Z,w);

    task checker_out;  // create checker to check for out
        input [15:0] expected_out;
        begin 
            if( out !== expected_out ) begin
            $display("ERROR ** out is %b, expected out is %b", out, expected_out);
            err = 1'b1;
            end
        end
    endtask

    task instruction_run;  // create checker to check for out  checker_reg(d5, 6)
            input [15:0] instruction;
            begin 
            in = instruction;
            load = 1;
            #10;
            load = 0;
            s = 1;
            #10
            s = 0;
            @(posedge w); // wait for w to go high again
            #10;
            
        end
    endtask

    initial begin
        clk = 0; #5;
        forever begin
            clk = 1; #5;
            clk = 0; #5;
        end
    end 

    initial begin
    err = 0;
    reset = 1; s = 0; load = 0; in = 16'b0;
    #10;
    reset = 0; 
    #10;

    //MOV R0, #7
    instruction_run (16'b1101000000000111);
    if (DUT.DP.REGFILE.R0 !== 16'd7) begin
        err = 1;
            $display("FAILED: MOV R0, #7");  
        $stop;
    end

    //MOV R1, #2
    instruction_run (16'b1101000100000010);
    if (DUT.DP.REGFILE.R1 !== 16'd2) begin
        err = 1;
            $display("FAILED: MOV R1, #2");
            $stop;
    end

    //MOV R4, #9
    instruction_run (16'b110_10_10000001001);
    if (DUT.DP.REGFILE.R4 !== 16'd9) begin
        err = 1;
            $display("FAILED: MOV R4, #9");  
        $stop;
    end

    //ADD R2, R0, R1
    instruction_run(16'b101_00_001_010_00_000); 
    if (DUT.DP.REGFILE.R2 !== 16'd9) begin
        err = 1;
            $display("FAILED: ADD R2, R0, R1");  
            $stop;
    end

    //ADD R3, R1, R0, LSL#1
    instruction_run(16'b101_00_001_011_01_000); //Rn_Rd_Rm (Rm is shifted)
    if (DUT.DP.REGFILE.R3 !== 16'd16) begin
        err = 1;
            $display("FAILED: ADD R3, R1, R0, LSL#1");
            $stop;
    end

    //ADD R7, R4, R1, LSR#1
    instruction_run(16'b101_00_100_111_10_001);
    if (DUT.DP.REGFILE.R7 !== 16'd10) begin
        err = 1;
            $display("FAILED: ADD R7, R4, R1, LSR#1");
            $stop;
    end   

    //CMP R0, R4   R0 - R4, (7-9) negative flag
    instruction_run(16'b101_01_000_000_00_100);
    if ({N,V,Z} !== 3'b100) begin
        err = 1;
            $display("FAILED: CMP R0, R4");
            $stop;
    end     
            
    //AND R5, R4, R0 (And b9 and b7 = 1)   
    instruction_run(16'b101_10_100_101_00_000);
    if (DUT.DP.REGFILE.R5 !== 16'd1) begin
        err = 1;
            $display("FAILED: AND R5, R4, R0");
            $stop;
    end

    //MVN R6, R1 
    instruction_run(16'b101_11_000_110_00_001);
    if (DUT.DP.REGFILE.R6 !== -16'd3) begin
        err = 1;
            $display("FAILED: MVN R6, R1");
            $stop;
    end

    //MOV R5, R1
    instruction_run(16'b110_00_000_101_00_001); //(put r1 into r5)
    if (DUT.DP.REGFILE.R5 !== 16'd2) begin
        err = 1;
            $display("FAILED: MOV R5, R1");
            $stop;
    end

    //MOV R5, R1, LSL#1
    instruction_run(16'b110_00_000_101_01_001); 
    if (DUT.DP.REGFILE.R5 !== 16'd4) begin
        err = 1;
            $display("FAILED: MOV R5, R1,LSL #1");
            $stop;
    end
    //MOV R3, #5
    instruction_run (16'b110_10_011_00000101);
    if (DUT.DP.REGFILE.R3 !== 16'd5) begin
        err = 1;
            $display("FAILED: MOV R3, #5");
            $stop;
    end

    //MOV R4, R5
    instruction_run(16'b110_00_000_100_00_101); // move value of r5 into r4
    if (DUT.DP.REGFILE.R4 !== 16'd4) begin
        err = 1;
            $display("FAILED: MOV R4, R5");
            $stop;
    end

    //ADD R5, R3, R4, LSR#1
    instruction_run(16'b101_00_011_101_10_100);
    if (DUT.DP.REGFILE.R5 !== 16'd7) begin
        err = 1;
            $display("FAILED: ADD R5, R3, R4, LSR#1");
            $stop;
    end

    // CMP R5, R0   
    instruction_run(16'b101_01_101_000_00_000);
    if ({N,V,Z} !== 3'b001) begin
        err = 1;
            $display("CMP R5, R0");
            $stop;
    end 

    //MVN R6, R5, LSL#1 
    instruction_run(16'b101_11_000_110_01_101);
    if (DUT.DP.REGFILE.R6 !== -16'd15) begin
        err = 1;
            $display("FAILED: MVN R6, R1");
            $stop;
    end

        //MOV R3, #0
    instruction_run (16'b110_10_011_01111111);
    if (DUT.DP.REGFILE.R3 !== 16'd127) begin
        err = 1;
            $display("FAILED: MOV R0, #7");  
        $stop;
    end
    //mov r4,0
    instruction_run (16'b110_10_100_00000000);
    if (DUT.DP.REGFILE.R4 !== 16'd0) begin
        err = 1;
            $display("FAILED: MOV R0, #7");  
        $stop;
    end



    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_00_011_011_01_011);
    instruction_run(16'b101_01_100_000_01_011);

    if (V !== 1'b1) begin
        err = 1;
            $display("FAILED CMP R5, R0");
            $stop;
    end 

        if( ~err ) $display("PASSED");
    else $display("FAILED");
    
    end 

endmodule
