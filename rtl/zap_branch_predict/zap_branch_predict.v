/*
 * A simple branch predictor to make up for the longer 
 * pipeline. Can store 512 branches and uses a 2-state
 * predictor algorithm. 
 *
 * Author:
 * Revanth Kamaraj.
 *
 * License:
 * MIT License.
 */

`default_nettype none

module zap_branch_predict
(
        // Clock and reset.
        input wire              i_clk,
        input wire              i_reset,         

        // Clear from writeback and ALU. Also data stall.
        input wire              i_clear_from_writeback,
        input wire              i_data_stall,
        input wire              i_clear_from_alu,
        input wire   [31:0]     i_pc,                   // PC from fetch. Not added 8!.
        input wire              i_confirm_from_alu,
        input wire   [31:0]     i_pc_from_alu,          // PC sent from ALU on both clear and confirm. For confirm, ALU subtracts 8 internally before giving this.

        input wire              i_stall_from_issue,
        input wire              i_stall_from_shifter,
        input wire              i_stall_from_decode,
        input wire              i_clear_from_decode,

        // From fetch unit along with IABORT.
        input wire   [31:0]     i_inst,
        input wire              i_val,
        input wire              i_abt,
        input wire   [31:0]     i_pc_plus_8,

        // Standard outputs.
        output reg   [31:0]     o_inst_ff,
        output reg              o_val_ff,   
        output reg              o_abt_ff,
        output reg [31:0]       o_pc_plus_8_ff,
        output reg [31:0]       o_pc_ff,

        // Branch state.
        output reg              o_taken_ff        
);

// For Thumb bit position.
`include "cpsr.vh"



// Branch states.
localparam      SNT     =       0; // Strongly Not Taken.
localparam      WNT     =       1; // Weakly Not Taken.
localparam      WT      =       2; // Weakly Taken.
localparam      ST      =       3; // Strongly Taken.

// Offset (For Thumb)
reg     [11:0] offset_ff, offset_nxt;

// Branch memory. Common for ARM and Thumb.
reg [1:0] mem_ff  [511:0];

// Mundane outputs.
always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                clear;
        end
        else if ( i_clear_from_writeback )
        begin
                clear;
        end
        else if ( i_data_stall )
        begin
                // Preserve values.
        end
        else if ( i_clear_from_alu )
        begin
                clear;
        end
        else if ( i_stall_from_shifter )
        begin
                // Preser val.
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve values.
        end
        else if ( i_stall_from_decode )
        begin
                // Preserve values.
        end
        else if ( i_clear_from_decode )
        begin
                clear;
        end
        else
        begin
                // Normal update.
                o_inst_ff       <= i_inst;
                o_val_ff        <= i_val;
                o_abt_ff        <= i_abt;
                o_pc_plus_8_ff  <= i_pc_plus_8; 
                o_taken_ff      <= ( mem_ff [ i_pc[9:1] ] ) >> 1;
                o_pc_ff         <= i_pc;
        end
end

task clear;
begin
        // Basically invalidate everything.
        o_inst_ff       <= 32'd0;
        o_val_ff        <= 1'd0;
        o_abt_ff        <= 1'd0;
        o_pc_plus_8_ff  <= 32'd8;
        o_pc_ff         <= 32'd0;
        o_taken_ff      <= 1'd0;
end
endtask

// The initial block initializes the memory.
initial
begin: blk1
                integer i;

                `ifdef SIM
                        $display($time, "Initializing branch RAM to 2'b00...");
                `endif

                // Must initialize to 0.
                for(i=0;i<512;i=i+1)
                        mem_ff[i] = 2'd0;
end

`define x i_pc_from_alu[9:1]

// Memory writes.
always @ (posedge i_clk)
begin: blk2

        if ( !i_data_stall ) // If there isn't a data stall.
        begin
                // Based on feedback, we modify stuff.
                if ( i_clear_from_alu )
                begin
                        case ( mem_ff[`x] )
                        SNT: mem_ff[`x] <= WNT;
                        WNT: mem_ff[`x] <= WT;
                        WT:  mem_ff[`x] <= WNT;
                        ST:  mem_ff[`x] <= WT;
                        endcase
                end
                else if ( i_confirm_from_alu )
                begin
                        case ( mem_ff[`x] )
                        SNT: mem_ff[`x] <= SNT;
                        WNT: mem_ff[`x] <= SNT;
                        WT:  mem_ff[`x] <= ST;
                        ST:  mem_ff[`x] <= ST;
                        endcase
                end
        end
end

`undef x

endmodule