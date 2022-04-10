/*lab 7 changes
    new outputs state machine: mem_cmd, reset_pc, load_addr, load_pc, load_ir
    remove outpus state machine: w
    remove wait state
    STR R2, [R1]
        r2 = 10
        r1 = 3              stores 1/0 into address 3
//
*/

//states
`define halt_state          5'd0
`define reset_state         5'd1
`define decode_state        5'd2
`define get_A_state         5'd3
`define get_B_state         5'd4
`define add_state           5'd5  
`define write_reg_state     5'd6
`define write_imm_state     5'd7
`define cmp_state           5'd8
`define and_state           5'd9
`define mvn_state           5'd10
`define mov_reg_state       5'd11
`define get_B_reg_state     5'd12
`define IF1_state           5'd13 
`define IF2_state           5'd14
`define update_pc_state     5'd15
`define ldr_state_1         5'd16
`define ldr_state_2         5'd17
`define ldr_state_3         5'd18
`define ldr_write_reg_state 5'd19
`define ldr_write_reg_state_2 5'd20
`define str_state_1         5'd21
`define str_state_2         5'd22
`define str_state_3         5'd23
`define str_state_4         5'd24
`define str_state_5         5'd25
`define str_state_6         5'd26

//opcodes
`define mov_opcode 3'b110
`define alu_opcode 3'b101
`define halt_opcode 3'b111
`define ldr_opcode 3'b011
`define str_opcode 3'b100
//op
`define mov_imm_op 2'b10
`define mov_reg_op 2'b00

`define alu_add_op 2'b00
`define alu_cmp_op 2'b01
`define alu_and_op 2'b10
`define alu_mvn_op 2'b11

//MEM actions
`define MREAD  2'd1
`define MWRITE 2'd2
`define MNONE  2'd3 

module cpu(clk,reset,N,V,Z,mem_cmd, mem_addr, write_data, read_data);

    input clk, reset;
    input [15:0] read_data;
    output N, V, Z;
    output [1:0] mem_cmd; 
    output [8:0] mem_addr;
    output [15:0] write_data;

    //IR 
    wire [1:0] op, ALUop, shift;
    wire [2:0] nsel;
    wire [15:0] sximm5, sximm8;
    wire [2:0] opcode, readnum, writenum;
    wire [15:0] ir_out; //instruction register out
    wire load_ir;

    vDFFE #(16) instruction_register (clk, load_ir, read_data, ir_out);

    wire [2:0] status_out;
    wire [1:0] vsel, dp_shift; 
    wire write, loada, loadb, asel, bsel, loadc, loads;
    wire [15:0]datapath_out;
    wire [8:0] PC;
    wire load_pc, reset_pc, load_addr, addr_sel;

    InstructionDecoder ID(ir_out, opcode, op, nsel, ALUop, sximm5, sximm8, shift, readnum, writenum);

    StateMachine FSM(clk, reset, opcode, op, nsel, vsel, write, loada, loadb, dp_shift, 
                    asel, bsel, loadc, loads, reset_pc, load_addr, load_pc, load_ir, addr_sel, mem_cmd);
                
    datapath DP(
                .clk(clk), .readnum(readnum), .vsel(vsel), .loada(loada), .loadb(loadb), .shift(shift), .asel(asel),
                .bsel(bsel), .ALUop(ALUop), .loadc(loadc), .loads(loads), .writenum(writenum), .write(write), .mdata(read_data), .sximm8(sximm8), 
                .sximm5(sximm5), .PC_dp(PC[7:0]), .status_out(status_out), .datapath_out(datapath_out)
                );

    wire [8:0] data_addr_out, next_pc;

    vDFFE #(9) program_counter (clk, load_pc, next_pc, PC);
    vDFFE #(9) data_address (clk, load_addr, datapath_out[8:0], data_addr_out);

    assign mem_addr = addr_sel ? PC: data_addr_out; //if addr_sel = 1, drive the output as the output of the PC register
    assign next_pc = reset_pc ? 9'd0 : PC + 1'b1; // If reset_pc = 1, pc = 0, otherwise pc = pc register + 1    
    
    assign N = status_out[2];
    assign V = status_out[1];
    assign Z = status_out[0];

//    assign mdata = read_data;

    assign write_data = datapath_out;

endmodule

//Decodes instruction from Instruction register into signals for statemachine and datapath
module InstructionDecoder(instruction, opcode, op, nsel, ALUop, sximm5, sximm8, shift, readnum, writenum);
    input [15:0] instruction;
    input [2:0] nsel;

    output [1:0] op, ALUop, shift;
    output [15:0] sximm5, sximm8;
    output [2:0] opcode;
    output reg [2:0] readnum, writenum;

    assign ALUop = instruction[12:11];
    assign opcode = instruction[15:13];
    assign op = instruction[12:11];
    assign sximm5 = { {11{instruction[4]}} , instruction[4:0] };
    assign sximm8 = { {8{instruction[7]}} , instruction[7:0] };
    assign shift = instruction[4:3];
    
    always @(*) begin 
        case(nsel)
            3'b001: {readnum, writenum} = {2{instruction[2:0]}};  //Rm  
            3'b010: {readnum, writenum} = {2{instruction[7:5]}}; //Rd
            3'b100: {readnum, writenum} = {2{instruction[10:8]}}; //Rn
            default: {readnum, writenum} = {6{1'bx}};
        endcase
    end
endmodule  

//state machine controller for datapath
module StateMachine(clk, reset, opcode, op, nsel, vsel, write, loada, loadb, shift, 
                    asel, bsel, loadc, loads, reset_pc, load_addr, load_pc, load_ir, addr_sel, mem_cmd);
    input clk;
    input reset;
    input [2:0] opcode;
    input [1:0] op;
    output reg [2:0] nsel;
    output reg [1:0] vsel, shift; 
    output reg write, loada, loadb, asel, bsel, loadc, loads; 

    //lab7 changes
    output reg [1:0] mem_cmd;
    output reg reset_pc, load_addr, load_pc, load_ir, addr_sel; 

    reg [4:0] state;
    //combinational logic block for state transitions
    always @(posedge clk) begin 
        if (reset) begin
			state = `reset_state; // if reset is 1, go to reset state 
		end else begin 
			casex({state, opcode, op})
				{`reset_state, 3'bxxx, 2'bxx}:              state = `IF1_state;
                {`IF1_state, 3'bxxx, 2'bxx}:                state = `IF2_state;
                {`IF2_state, 3'bxxx, 2'bxx}:                state = `update_pc_state;
                {`update_pc_state, 3'bxxx, 2'bxx}:          state = `decode_state;

                {`decode_state, `alu_opcode, `alu_add_op}:  state = `get_A_state;
                {`decode_state, `alu_opcode, `alu_cmp_op}:  state = `get_A_state;
                {`decode_state, `alu_opcode, `alu_and_op}:  state = `get_A_state;
                {`decode_state, `alu_opcode, `alu_mvn_op}:  state = `get_B_state;
                {`decode_state, `ldr_opcode, 2'b00}:        state = `ldr_state_1;
                {`decode_state, `str_opcode, 2'b00}:        state = `str_state_1;
                
                //ldr instruction
                {`ldr_state_1, 3'bxxx, 2'bxx}:              state = `ldr_state_2;
                {`ldr_state_2, 3'bxxx, 2'bxx}:              state = `ldr_state_3;                
                {`ldr_state_3, 3'bxxx, 2'bxx}:              state = `ldr_write_reg_state;
                {`ldr_write_reg_state, 3'bxxx, 2'bxx}:      state = `ldr_write_reg_state_2;
                {`ldr_write_reg_state_2, 3'bxxx, 2'bxx}:    state = `IF1_state;

                //str instruction
                {`str_state_1, 3'bxxx, 2'bxx}:              state = `str_state_2;
                {`str_state_2, 3'bxxx, 2'bxx}:              state = `str_state_3;
                {`str_state_3, 3'bxxx, 2'bxx}:              state = `str_state_4;
                {`str_state_4, 3'bxxx, 2'bxx}:              state = `str_state_5;
                {`str_state_5, 3'bxxx, 2'bxx}:              state = `str_state_6;
                 {`str_state_6, 3'bxxx, 2'bxx}:              state = `IF1_state;

                //HALT state
                {`decode_state, `halt_opcode, 3'b00}:       state = `halt_state;
                {`halt_state, 3'bxxx, 2'bxx}:               state = `halt_state;
                
                //move imm into register
                {`decode_state, `mov_opcode, `mov_imm_op}:  state = `write_imm_state;
                {`write_imm_state, 3'bxxx, 2'bxx}:          state = `IF1_state;

                //move datapath_out into register 
                {`decode_state, `mov_opcode, `mov_reg_op}:  state = `get_B_reg_state;
                {`get_B_reg_state, 3'bxxx, `alu_add_op}:    state = `mov_reg_state;
                {`mov_reg_state, 3'bxxx, 2'bxx}:            state = `write_reg_state;

                //move to wait after write                
                {`write_reg_state, 3'bxxx, 2'bxx}:          state = `IF1_state;

                //alu add operation
                {`get_A_state, 3'bxxx, 2'bxx}:              state = `get_B_state; //selects Rn
                {`get_B_state, 3'bxxx, `alu_add_op}:        state = `add_state;
                {`add_state, 3'bxxx, 2'bxx}:                state = `write_reg_state;

                //alu cmp operation 
                {`get_B_state, 3'bxxx, `alu_cmp_op}:        state = `cmp_state;
                {`cmp_state, 3'bxxx, 2'bxx}:                state = `IF1_state;
                
                //alu and operation 
                {`get_B_state, 3'bxxx, `alu_and_op}:        state = `and_state;
                {`and_state, 3'bxxx, 2'bxx}:                state = `write_reg_state;

                //alu mvn operation
                {`get_B_state, 3'bxxx, `alu_mvn_op}:        state = `mvn_state; //selects Rn
                {`mvn_state, 3'bxxx, 2'bxx}:                state = `write_reg_state;

                default:                                    state = 5'b11111; //should never reach
            endcase
        end
    end  
    
    //asynchronous logic block for state outputs
    always @(*) begin
        case(state)
            `reset_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b1,           //reset_pc      reset_pc = 1
                        1'b0,           //load_addr 
                        1'b1,           //load_pc       load_pc = 1
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `IF1_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MREAD,          //mem_cmd       mem_cmd = `MREAD
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,           //load_ir 
                        1'b1            //addr_sel      addr_sel = 1
                    };

            `IF2_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MREAD,          //mem_cmd      mem_cmd = MREAD
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b1,            //load_ir      load_ir = 1
                        1'b1            //addr_sel      addr_sel = 1
                    };

            `update_pc_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b1,           //load_pc     load_pc = 1
                        1'b0,            //load_ir 
                        1'b0            //addr_sel
                    };

            `decode_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir
                        1'b0            //addr_sel  
                    };
            `halt_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      reset_pc = 1
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       load_pc = 1
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `get_A_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b100,         //nsel          nsel = 100 (selects Rn)
                        1'b0,           //write
                        1'b1,           //loada         loada = 1
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir 
                        1'b0            //addr_sel  
                    };
            `get_B_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b001,         //nsel          nsel = 010
                        1'b0,           //write
                        1'b0,           //loada
                        1'b1,           //loadb         loadb = 1
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir    
                        1'b0            //addr_sel
                    };
                    
            `get_B_reg_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b001,         //nsel          nsel = 010
                        1'b0,           //write
                        1'b0,           //loada
                        1'b1,           //loadb         loadb = 1
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir  
                        1'b0            //addr_sel  
                    };
            `mov_reg_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b1,           //asel          asel = 1
                        1'b0,           //bsel          bsel = 0
                        1'b1,           //loadc         loadc = 1
                        1'b0,           //loads
                        2'b00,          //shift         shift = 00
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir  
                        1'b0            //addr_sel 
                    };
            `add_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          asel = 0
                        1'b0,           //bsel          bsel = 0
                        1'b1,           //loadc         loadc = 1
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir  
                        1'b0            //addr_sel 
                    };
            `cmp_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          asel = 0
                        1'b0,           //bsel          bsel = 0
                        1'b0,           //loadc         loadc = 0
                        1'b1,           //loads         loads = 1
                        2'b00,          //shift          shift = 00
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir 
                        1'b0            //addr_sel  
                    };   
            `and_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          asel = 0
                        1'b0,           //bsel          bsel = 0
                        1'b1,           //loadc         loadc = 0
                        1'b0,           //loads         loads = 1
                        2'b00,          //shift          shift = 00
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir 
                        1'b0            //addr_sel  
                    };      
            `mvn_state:  {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b00,          //vsel
                        3'b000,         //nsel
                        1'b0,           //write
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b1,           //asel          asel = 0
                        1'b0,           //bsel          bsel = 0
                        1'b1,           //loadc         loadc = 1
                        1'b0,           //loads         loads = 1
                        2'b00,          //shift          shift = 00
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir
                        1'b0            //addr_sel   
                    };  
            `write_reg_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b11,          //vsel          vsel = 11 (setting datapath out to register file in)
                        3'b010,         //nsel          nsel = 010
                        1'b1,           //write         write = 1
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir 
                        1'b0            //addr_sel   
                    };
            `write_imm_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { 
                        2'b01,          //vsel          vsel = 01 (setting imm8 to register file in)
                        3'b100,         //nsel          nsel = 100 (Rn)
                        1'b1,           //write         write = 1
                        1'b0,           //loada
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc
                        1'b0,           //load_addr
                        1'b0,           //load_pc
                        1'b0,            //load_ir
                        1'b0            //addr_sel   
                    };
            `ldr_state_1: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b100,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b1,           //loada       load imm into reg. A
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b1,           //bsel         bsel to get sximm5
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `ldr_state_2: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b010,         //nsel        nsel = 010 (Rd)
                        1'b0,           //write
                        1'b0,           //loada      
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b1,           //bsel         bsel = 1 (sximm5)
                        1'b1,           //loadc        loadc = 1
                        1'b0,           //loads[]
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `ldr_state_3: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b00,          //vsel
                        3'b100,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write         w = 1
                        1'b0,           //loada      
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel         bsel = 0 
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b1,           //load_addr   load_addr = 1
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel    load data_address 
                    };
            `ldr_write_reg_state: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b00,          //vsel        mdata
                        3'b010,         //nsel        nsel = 010 (Rd)
                        1'b0,           //write       write = 1
                        1'b0,           //loada      
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel         bsel = 1 (sximm5)
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,         //mem_cmd      `MREAD
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `ldr_write_reg_state_2: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b00,          //vsel
                        3'b010,         //nsel        nsel = 010 (rd)
                        1'b1,           //write
                        1'b0,           //loada      
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b0,           //bsel         bsel = 0 
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MREAD,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr   load_addr = 1
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel    load data_address 
                    };
            `str_state_1: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b100,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b1,           //loada       load imm into reg. A
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b1,           //bsel         bsel to get sximm5
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `str_state_2: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b100,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b0,           //loada       turn off load a
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b1,           //bsel         bsel to get sximm5
                        1'b1,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `str_state_3: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b100,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b1,           //loada       load imm into reg. A
                        1'b0,           //loadb
                        1'b0,           //asel          
                        1'b1,           //bsel         bsel to get sximm5
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MNONE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b1,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `str_state_4: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b010,         //nsel        nsel = 010 (Rd)
                        1'b0,           //write
                        1'b0,           //loada       load imm into reg. B
                        1'b1,           //loadb
                        1'b1,           //asel          
                        1'b0,           //bsel         bsel to get sximm5
                        1'b0,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MWRITE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `str_state_5: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b010,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b0,           //loada       load imm into reg. A
                        1'b0,           //loadb
                        1'b1,           //asel          
                        1'b0,           //bsel       
                        1'b1,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MWRITE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            `str_state_6: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = { //load value into reg.
                        2'b01,          //vsel
                        3'b010,         //nsel        nsel = 100 (Rn)
                        1'b0,           //write
                        1'b0,           //loada       load imm into reg. A
                        1'b0,           //loadb
                        1'b1,           //asel          
                        1'b0,           //bsel       
                        1'b1,           //loadc
                        1'b0,           //loads
                        2'b00,          //shift
                        `MWRITE,          //mem_cmd
                        1'b0,           //reset_pc      
                        1'b0,           //load_addr 
                        1'b0,           //load_pc       
                        1'b0,           //load_ir 
                        1'b0            //addr_sel
                    };
            default: {vsel, nsel, write, loada, loadb, asel, bsel, loadc, loads, shift, mem_cmd, reset_pc, load_addr, load_pc, load_ir, addr_sel} = {21{1'bx}};
        endcase
    
    
    end
endmodule

//decodes instruction into signals




