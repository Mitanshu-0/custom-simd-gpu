// Writeback and control feedback

`include "../../cu_defs.svh"

module writeback_stage (
    input logic writeback_instruction_valid, // Writeback pipeline data
    input logic [`WARP_ID_WIDTH-1:0] writeback_warp_id, // Writeback pipeline data
    input logic [`WARP_SIZE-1:0] writeback_active_lane_mask, // Writeback pipeline data
    input logic [`LANE_WIDTH-1:0] writeback_result_data [0:`WARP_SIZE-1], // Writeback pipeline data
    input logic [`REG_ID_WIDTH-1:0] writeback_destination_register_id, // Writeback pipeline data
    input logic writeback_register_write_enable, // Writeback pipeline data
    input logic writeback_branch_instruction, // Writeback pipeline data
    input logic writeback_branch_taken, // Writeback pipeline data
    input logic [`PC_WIDTH-1:0] writeback_branch_target_program_counter, // Calculate branch target
    input logic writeback_exit_instruction, // Writeback pipeline data

    output logic register_file_write_valid, // register-file write valid
    output logic [`WARP_ID_WIDTH-1:0] register_file_write_warp_id, // register-file write warp ID
    output logic [`REG_ID_WIDTH-1:0] register_file_write_destination_register_id, // register-file destination
    output logic [`LANE_WIDTH-1:0] register_file_write_data [0:`WARP_SIZE-1], // lane write data
    output logic [`WARP_SIZE-1:0] register_file_write_mask, // lane write mask

    output logic scoreboard_clear_valid, // scoreboard clear valid
    output logic [`WARP_ID_WIDTH-1:0] scoreboard_clear_warp_id, // scoreboard clear warp ID
    output logic [`REG_ID_WIDTH-1:0] scoreboard_clear_destination_register_id, // scoreboard clear destination

    output logic branch_commit, // branch commit
    output logic [`WARP_ID_WIDTH-1:0] branch_warp_id, // branch warp ID
    output logic branch_taken, // branch taken
    output logic [`PC_WIDTH-1:0] branch_target_program_counter, // Calculate branch target

    output logic exit_commit, // EXIT commit
    output logic [`WARP_ID_WIDTH-1:0] exit_warp_id // EXIT warp ID
);

    always_comb begin
        register_file_write_valid = writeback_instruction_valid && writeback_register_write_enable && // Writeback pipeline data
                                    (writeback_destination_register_id != `REG_ZERO); // Writeback pipeline data
        register_file_write_warp_id = writeback_warp_id; // Writeback pipeline data
        register_file_write_destination_register_id = writeback_destination_register_id; // Writeback pipeline data
        register_file_write_mask = writeback_active_lane_mask; // Writeback pipeline data

        scoreboard_clear_valid = writeback_instruction_valid && writeback_register_write_enable && // Writeback pipeline data
                                 (writeback_destination_register_id != `REG_ZERO); // Writeback pipeline data
        scoreboard_clear_warp_id = writeback_warp_id; // Writeback pipeline data
        scoreboard_clear_destination_register_id = writeback_destination_register_id; // Writeback pipeline data

        branch_commit = writeback_instruction_valid && writeback_branch_instruction; // Writeback pipeline data
        branch_warp_id = writeback_warp_id; // Writeback pipeline data
        branch_taken = writeback_branch_taken; // Writeback pipeline data
        branch_target_program_counter = writeback_branch_target_program_counter; // Calculate branch target

        exit_commit = writeback_instruction_valid && writeback_exit_instruction; // Writeback pipeline data
        exit_warp_id = writeback_warp_id; // Writeback pipeline data

        for (int lane = 0; lane < `WARP_SIZE; lane++)
            register_file_write_data[lane] = writeback_result_data[lane]; // Writeback pipeline data
    end
endmodule
