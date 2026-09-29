// Memory stage and MEM/WB transfer

`include "../../cu_defs.svh"

module mem_stage (
    input logic clk, // clock
    input logic rst, // reset
    input logic memory_instruction_valid, // MEM instruction valid
    input logic [`WARP_ID_WIDTH-1:0] memory_warp_id, // MEM warp ID
    input logic [`PC_WIDTH-1:0] memory_program_counter, // MEM PC
    input logic [`WARP_SIZE-1:0] memory_active_lane_mask, // active lane mask
    input logic [`LANE_WIDTH-1:0] memory_alu_result [0:`WARP_SIZE-1], // lane ALU results
    input logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1], // lane addresses
    input logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1], // lane store data
    input logic [`REG_ID_WIDTH-1:0] memory_destination_register_id, // MEM destination register
    input logic memory_register_write_enable, // MEM register write enable
    input logic memory_read_enable, // load enable
    input logic memory_write_enable, // store enable
    input logic memory_branch_instruction, // MEM branch
    input logic memory_branch_taken, // branch result
    input logic [`PC_WIDTH-1:0] memory_branch_target_program_counter, // Calculate branch target
    input logic memory_exit_instruction, // MEM EXIT
    input logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1], // lane load data

    output logic [`LANE_WIDTH-1:0] data_memory_address [0:`WARP_SIZE-1], // lane addresses
    output logic [`LANE_WIDTH-1:0] data_memory_store_data [0:`WARP_SIZE-1], // lane store data
    output logic [`WARP_SIZE-1:0] data_memory_active_lane_mask, // active lanes
    output logic data_memory_read_enable, // load enable
    output logic data_memory_write_enable, // store enable

    output logic writeback_instruction_valid, // Writeback pipeline data
    output logic [`WARP_ID_WIDTH-1:0] writeback_warp_id, // Writeback pipeline data
    output logic [`WARP_SIZE-1:0] writeback_active_lane_mask, // Writeback pipeline data
    output logic [`LANE_WIDTH-1:0] writeback_result_data [0:`WARP_SIZE-1], // Writeback pipeline data
    output logic [`REG_ID_WIDTH-1:0] writeback_destination_register_id, // Writeback pipeline data
    output logic writeback_register_write_enable, // Writeback pipeline data
    output logic writeback_branch_instruction, // Writeback pipeline data
    output logic writeback_branch_taken, // Writeback pipeline data
    output logic [`PC_WIDTH-1:0] writeback_branch_target_program_counter, // Calculate branch target
    output logic writeback_exit_instruction // Writeback pipeline data
);

    always_comb begin
        data_memory_active_lane_mask = memory_active_lane_mask;
        data_memory_read_enable = memory_instruction_valid && memory_read_enable;
        data_memory_write_enable = memory_instruction_valid && memory_write_enable;
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin
            data_memory_address[lane] = memory_address[lane];
            data_memory_store_data[lane] = memory_store_data[lane];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            writeback_instruction_valid <= 1'b0; // Writeback pipeline data
            writeback_warp_id <= '0; // Writeback pipeline data
            writeback_active_lane_mask <= '0; // Writeback pipeline data
            writeback_destination_register_id <= `REG_ZERO; // Writeback pipeline data
            writeback_register_write_enable <= 1'b0; // Writeback pipeline data
            writeback_branch_instruction <= 1'b0; // Writeback pipeline data
            writeback_branch_taken <= 1'b0; // Writeback pipeline data
            writeback_branch_target_program_counter <= '0; // Calculate branch target
            writeback_exit_instruction <= 1'b0; // Writeback pipeline data
            for (int lane = 0; lane < `WARP_SIZE; lane++)
                writeback_result_data[lane] <= '0; // Writeback pipeline data
        end else begin
            writeback_instruction_valid <= memory_instruction_valid; // Writeback pipeline data
            writeback_warp_id <= memory_warp_id; // Writeback pipeline data
            writeback_active_lane_mask <= memory_active_lane_mask; // Writeback pipeline data
            writeback_destination_register_id <= memory_destination_register_id; // Writeback pipeline data
            writeback_register_write_enable <= memory_instruction_valid && memory_register_write_enable; // Writeback pipeline data
            writeback_branch_instruction <= memory_instruction_valid && memory_branch_instruction; // Writeback pipeline data
            writeback_branch_taken <= memory_branch_taken; // Writeback pipeline data
            writeback_branch_target_program_counter <= memory_branch_target_program_counter; // Calculate branch target
            writeback_exit_instruction <= memory_instruction_valid && memory_exit_instruction; // Writeback pipeline data

            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                if (memory_read_enable)
                    writeback_result_data[lane] <= memory_load_data[lane]; // Writeback pipeline data
                else
                    writeback_result_data[lane] <= memory_alu_result[lane]; // Writeback pipeline data
            end
        end
    end
endmodule
