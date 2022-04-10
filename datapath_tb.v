module datapath_tb;
    reg clk, loada, loadb, asel, bsel, loadc, loads, write;
    reg [1:0] vsel;
    reg [2:0] readnum; 
    reg [1:0] shift;
    reg [1:0] ALUop;
    reg [2:0] writenum;
    reg [15:0] sximm8;
    reg [15:0] sximm5;
    reg [15:0] mdata;
    reg [7:0] PC;
    wire [2:0] status_out; 
    wire [15:0] datapath_out;

    reg err; 

    datapath DUT (clk, readnum, vsel, loada, loadb, shift, asel, bsel, ALUop, loadc, loads, writenum, write, mdata, sximm8, sximm5, PC, status_out, datapath_out);
    
    task checker; 
        input [15:0] expected_datapath_out;
        input [2:0] expected_status_out;
        begin 
            if( datapath_out !== expected_datapath_out ) begin
            $display("ERROR ** datapath output is %d, expected %d", datapath_out, expected_datapath_out );
            err = 1'b1;
            end
      
            if( status_out !== expected_status_out) begin
            $display("ERROR ** status output is %b, expected %b", status_out, expected_status_out );
            err = 1'b1;
            end
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
        err = 1'b0;        
        //Testing no shift and adding 
        vsel = 2'b01; sximm8 = 16'b0000_0000_0000_1111; #10; //set vsel to 0 to input sximm8 into register file
        writenum = 3'b000; write = 1'b1; //input conditions into register file. Write into register 0, write enabled 
        #10; //rising edge so b1111 is written into register 0 
        readnum = 3'b000; #10; //reading register 0 and setting it to data_out
        loada = 1'b1; loadb = 1'b0; //select register A to load into 
        #10; //loading b1111 into register A at rising edge
        sximm8 = 16'b0000_0000_0000_1000; writenum = 3'b001; 
        #10; //load b1000 into register 1
        readnum = 3'b001; loada = 1'b0; loadb = 1'b1; //load b1000 into register B
        #10 // load value in register 1
        shift = 2'b00; //no shift 
        #10; //shifting 
        asel = 1'b0; bsel = 1'b0; 
        #10;
        ALUop = 2'b00; #10; //adding register A and register B
        loadc = 1'b1; loads = 1'b1;
        #10;
        checker(16'b0000_0000_0001_0111, 3'b000); //checking to see if datapath_out is 10111 and Z flag is 0 (non-zero output)
        
        //test case from lab handout: 
        //MOV R0, #7 ; 
        //MOV R1, #2 ; 
        //ADD R2, R1, R0, LSL#1 
        vsel = 2'b01; sximm8 = 16'b0000_0000_0000_0111; #10; //set vsel to 0 to input sximm8 into register file
        writenum = 3'b000; write = 1'b1; //input conditions into register file. Write into register 0, write enabled 
        #10; //rising edge so b0111 is written into register 0 
        readnum = 3'b000; #10; //reading register 0 and setting it to data_out
        loada = 1'b0; loadb = 1'b1; //select register B to load into 
        #10; //loading b0111 into register B at rising edge
        sximm8 = 16'b0000_0000_0000_0010; writenum = 3'b001; //datapath input 2
        #10; //load b0010 into register 1
        readnum = 3'b001; loada = 1'b1; loadb = 1'b0; //load b1000 into register B
        #10 // load value in register 1
        shift = 2'b01; //left shift by 1 
        #10; //shifting 
        asel = 1'b0; bsel = 1'b0; 
        #10;
        ALUop = 2'b00; #10;  //adding register A and register B
        loadc = 1'b1; loads = 1'b1; 
        #10;
        vsel = 2'b11; writenum = 3'b010; 
        #10;
        readnum = 3'b010;
        #10;
        if( datapath_tb.DUT.REGFILE.R2 !== 16'd16) begin //checking to see if r2 holds the value of 16
            $display("ERROR ** regfile is %d, expected %d",  datapath_tb.DUT.REGFILE.R2, 16'd16 );
            err = 1'b1; 
        end
        checker(16'd16, 3'b000); // check datapath_out, Z_out

        //testing Z flag 
        vsel = 2'b01; sximm8 = 16'b0000_0000_0000_0000; writenum = 3'b011; write = 1'b1; 
        #10; //write 0 into register 3
        readnum = 3'b011; loada = 1'b1; loadb = 1'b0; //load into register A 
        #10; //load into A
        sximm8 = 16'b0101_0110_0000_1111; writenum = 3'b010; write = 1'b1; 
        #10; //write sximm8 into register 2
        readnum = 3'b010; loada = 1'b0; loadb = 1'b1; //load into register B
        #10; //load into B
        asel = 1'b0; bsel = 1'b0; ALUop = 2'b10; loadc = 1'b1; loads = 1'b1; #10; //ALU operation and load into register C
        #10;
        checker(16'd0, 3'b001); // check datapath_out, Z flag = 1

        //testing anding and z flag
        vsel = 2'b11; sximm8 = 16'b0000_0000_0000_0000; #10; //set vsel to 0 to input sximm8 into register file
        writenum = 3'b011; write = 1'b1; //input conditions into register file. Write into register 3, write enabled 
        #10; //rising edge so b1111 is written into register 0 
        readnum = 3'b011; #10; //reading register 0 and setting it to data_out
        loada = 1'b1; loadb = 1'b0; //select register A to load into 
        #10; //loading into register A at rising edge
        sximm8 = 16'b1011_1111_1111_1111; writenum = 3'b100; 
        #10; //load into register 4
        readnum = 3'b100; loada = 1'b0; loadb = 1'b1; //load into register B
        #10 // load value in register B
        shift = 2'b11; //no shift 
        #10; //shifting 
        asel = 1'b0; bsel = 1'b0; 
        #10;
        ALUop = 2'b10; #10; //anding register A and register B
        loadc = 1'b1; loads = 1'b1;
        #10;    
        checker(16'b0000_0000_0000_0000, 3'b001); //checking to see if datapath_out is 10111 and Z flag is 0 (non-zero output)
                

        //Testing overflow 
        vsel = 2'b01; sximm8 = 16'b0111_1111_1111_1111; #10; //set vsel to 01 to input sximm8 into register file
        writenum = 3'b000; write = 1'b1; //input conditions into register file. Write into register 0, write enabled 
        #10; //rising edge so sximm8 is written into register 0 
        readnum = 3'b000; #10; //reading register 0 and setting it to data_out
        loada = 1'b1; loadb = 1'b0; //select register A to load into 
        #10; //loading b1111 into register A at rising edge
        sximm8 = 16'b0111_1111_1111_1111; writenum = 3'b001; 
        #10; //load b1000 into register 1
        readnum = 3'b001; loada = 1'b0; loadb = 1'b1; //load b1000 into register B
        #10 // load value in register 1
        shift = 2'b00; //no shift 
        #10; //shifting 
        asel = 1'b0; bsel = 1'b0; 
        #10;
        ALUop = 2'b00; #10; //adding register A and register B
        loadc = 1'b1; loads = 1'b1;
        #10;
        checker(16'b1111_1111_1111_1110, 3'b110); //checking to see if datapath_out is 10111 and Z flag is 0 (non-zero output)

        
        if( ~err ) $display("PASSED");
        else $display("FAILED");
        $stop;


    end
endmodule
        