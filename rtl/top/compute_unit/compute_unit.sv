// Main GPU pipeline and control connections

`include "../cu_defs.svh"

module compute_unit (
    input logic clk, // clock
    input logic rst, // reset

    output logic [`PC_WIDTH-1:0] instruction_memory_address, // instruction address
    input logic [`INST_WIDTH-1:0] instruction_memory_data, // instruction data

    output logic memory_read_enable, // load enable
    output logic memory_write_enable, // store enable
    output logic [`WARP_SIZE-1:0] memory_active_lane_mask, // active lane mask
    output logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1], // lane addresses
    output logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1], // lane store data
    input logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1] // lane load data
);

    logic instruction_issue_valid; // fetch request valid
    logic [`WARP_ID_WIDTH-1:0] selected_warp_id; // selected warp
    logic [`PC_WIDTH-1:0] selected_warp_program_counter; // selected PC
    logic [`WARP_SIZE-1:0] selected_warp_active_lane_mask; // selected active lanes

    logic fetch_instruction_valid; // fetched instruction valid
    logic [`WARP_ID_WIDTH-1:0] fetch_warp_id; // fetched warp
    logic [`PC_WIDTH-1:0] fetch_program_counter; // fetched PC
    logic [`WARP_SIZE-1:0] fetch_active_lane_mask; // fetched active lanes
    logic [`INST_WIDTH-1:0] fetch_instruction; // fetched instruction

    logic register_dependency_hazard_detected; // RAW hazard
    logic [`NUM_WARPS-1:0] dependency_resolved_for_warp;
    logic scoreboard_set_valid;
    logic [`WARP_ID_WIDTH-1:0] scoreboard_set_warp_id;
    logic [`REG_ID_WIDTH-1:0] scoreboard_set_destination_register_id;
    logic scoreboard_check_valid;
    logic [`WARP_ID_WIDTH-1:0] scoreboard_check_warp_id;
    logic [`REG_ID_WIDTH-1:0] scoreboard_check_source_register_1_id;
    logic [`REG_ID_WIDTH-1:0] scoreboard_check_source_register_2_id;
    logic scoreboard_check_rs_used;
    logic scoreboard_check_rt_used;
    logic branch_stall_requested;
    logic [`WARP_ID_WIDTH-1:0] branch_stall_warp_id;
    logic [`PC_WIDTH-1:0] branch_stall_program_counter;
    logic exit_stall_requested;
    logic [`WARP_ID_WIDTH-1:0] exit_stall_warp_id;
    logic [`PC_WIDTH-1:0] exit_stall_program_counter;

    logic execute_instruction_valid;
    logic [`WARP_ID_WIDTH-1:0] execute_warp_id;
    logic [`PC_WIDTH-1:0] execute_program_counter;
    logic [`WARP_SIZE-1:0] execute_active_lane_mask;
    logic [`REG_ID_WIDTH-1:0] execute_source_register_1_id;
    logic [`REG_ID_WIDTH-1:0] execute_source_register_2_id;
    logic [`REG_ID_WIDTH-1:0] execute_destination_register_id;
    logic [`LANE_WIDTH-1:0] execute_immediate_value;
    logic [5:0] execute_alu_operation;
    logic execute_uses_immediate_operand;
    logic execute_register_write_enable;
    logic execute_memory_read_enable;
    logic execute_memory_write_enable;
    logic execute_branch_instruction;
    logic execute_branch_not_equal;
    logic execute_exit_instruction;

    logic [`LANE_WIDTH-1:0] source_register_1_data [0:`WARP_SIZE-1];
    logic [`LANE_WIDTH-1:0] source_register_2_data [0:`WARP_SIZE-1];

    logic memory_instruction_valid;
    logic [`WARP_ID_WIDTH-1:0] memory_warp_id;
    logic [`PC_WIDTH-1:0] memory_program_counter;
    logic [`WARP_SIZE-1:0] memory_pipeline_active_lane_mask;
    logic [`LANE_WIDTH-1:0] memory_alu_result [0:`WARP_SIZE-1];
    logic [`LANE_WIDTH-1:0] memory_pipeline_address [0:`WARP_SIZE-1];
    logic [`LANE_WIDTH-1:0] memory_pipeline_store_data [0:`WARP_SIZE-1];
    logic [`REG_ID_WIDTH-1:0] memory_destination_register_id;
    logic memory_register_write_enable;
    logic memory_pipeline_read_enable;
    logic memory_pipeline_write_enable;
    logic memory_branch_instruction;
    logic memory_branch_taken;
    logic [`PC_WIDTH-1:0] memory_branch_target_program_counter; // Calculate branch target
    logic memory_exit_instruction;

    logic writeback_instruction_valid; // Writeback pipeline data
    logic [`WARP_ID_WIDTH-1:0] writeback_warp_id; // Writeback pipeline data
    logic [`WARP_SIZE-1:0] writeback_active_lane_mask; // Writeback pipeline data
    logic [`LANE_WIDTH-1:0] writeback_result_data [0:`WARP_SIZE-1]; // Writeback pipeline data
    logic [`REG_ID_WIDTH-1:0] writeback_destination_register_id; // Writeback pipeline data
    logic writeback_register_write_enable; // Writeback pipeline data
    logic writeback_branch_instruction; // Writeback pipeline data
    logic writeback_branch_taken; // Writeback pipeline data
    logic [`PC_WIDTH-1:0] writeback_branch_target_program_counter; // Calculate branch target
    logic writeback_exit_instruction; // Writeback pipeline data

    logic register_file_write_valid;
    logic [`WARP_ID_WIDTH-1:0] register_file_write_warp_id;
    logic [`REG_ID_WIDTH-1:0] register_file_write_destination_register_id;
    logic [`LANE_WIDTH-1:0] register_file_write_data [0:`WARP_SIZE-1];
    logic [`WARP_SIZE-1:0] register_file_write_mask;
    logic scoreboard_clear_valid;
    logic [`WARP_ID_WIDTH-1:0] scoreboard_clear_warp_id;
    logic [`REG_ID_WIDTH-1:0] scoreboard_clear_destination_register_id;
    logic branch_commit;
    logic [`WARP_ID_WIDTH-1:0] branch_warp_id;
    logic branch_taken;
    logic [`PC_WIDTH-1:0] branch_target_program_counter; // Calculate branch target
    logic exit_commit;
    logic [`WARP_ID_WIDTH-1:0] exit_warp_id;

    logic stall_requested;
    logic [`WARP_ID_WIDTH-1:0] stall_warp_id;
    logic [`PC_WIDTH-1:0] stall_program_counter;
    logic stall_is_branch;
    logic stall_is_exit;

    assign stall_requested = register_dependency_hazard_detected || branch_stall_requested || exit_stall_requested;
    assign stall_warp_id = register_dependency_hazard_detected ? fetch_warp_id :
                           branch_stall_requested ? branch_stall_warp_id : exit_stall_warp_id;
    assign stall_program_counter = register_dependency_hazard_detected ? fetch_program_counter :
                                   branch_stall_requested ? branch_stall_program_counter : exit_stall_program_counter;
    assign stall_is_branch = branch_stall_requested && !register_dependency_hazard_detected && !exit_stall_requested;
    assign stall_is_exit = exit_stall_requested && !register_dependency_hazard_detected && !branch_stall_requested;
    warp_manager u_warp_manager (
        .clk(clk),
        .rst(rst),
        .stall_requested(stall_requested),
        .stall_warp_id(stall_warp_id),
        .stall_program_counter(stall_program_counter),
        .stall_is_branch(stall_is_branch),
        .stall_is_exit(stall_is_exit),
        .dependency_resolved_for_warp(dependency_resolved_for_warp),
        .branch_commit(branch_commit),
        .branch_warp_id(branch_warp_id),
        .branch_taken(branch_taken),
        .branch_target_program_counter(branch_target_program_counter), // Calculate branch target
        .exit_commit(exit_commit),
        .exit_warp_id(exit_warp_id),
        .instruction_issue_valid(instruction_issue_valid),
        .selected_warp_id(selected_warp_id),
        .selected_warp_program_counter(selected_warp_program_counter),
        .selected_warp_active_lane_mask(selected_warp_active_lane_mask),
        .warp_state(),
        .warp_program_counter()
    );

    instruction_fetch_unit u_ifu (
        .clk(clk),
        .rst(rst),
        .instruction_issue_valid(instruction_issue_valid),
        .selected_warp_id(selected_warp_id),
        .selected_warp_program_counter(selected_warp_program_counter),
        .selected_warp_active_lane_mask(selected_warp_active_lane_mask),
        .instruction_memory_data(instruction_memory_data),
        .instruction_memory_address(instruction_memory_address),
        .fetch_instruction_valid(fetch_instruction_valid),
        .fetch_warp_id(fetch_warp_id),
        .fetch_program_counter(fetch_program_counter),
        .fetch_active_lane_mask(fetch_active_lane_mask),
        .fetch_instruction(fetch_instruction)
    );

    scoreboard u_scoreboard (
        .clk(clk),
        .rst(rst),
        .set_valid(scoreboard_set_valid),
        .set_warp_id(scoreboard_set_warp_id),
        .set_destination_register_id(scoreboard_set_destination_register_id),
        .clear_valid(scoreboard_clear_valid),
        .clear_warp_id(scoreboard_clear_warp_id),
        .clear_destination_register_id(scoreboard_clear_destination_register_id),
        .check_valid(scoreboard_check_valid),
        .check_warp_id(scoreboard_check_warp_id),
        .check_source_register_1_id(scoreboard_check_source_register_1_id),
        .check_source_register_2_id(scoreboard_check_source_register_2_id),
        .check_rs_used(scoreboard_check_rs_used),
        .check_rt_used(scoreboard_check_rt_used),
        .register_dependency_hazard_detected(register_dependency_hazard_detected),
        .dependency_resolved_for_warp(dependency_resolved_for_warp)
    );

    decode_unit u_decode (
        .clk(clk),
        .rst(rst),
        .fetch_instruction(fetch_instruction),
        .fetch_instruction_valid(fetch_instruction_valid),
        .fetch_warp_id(fetch_warp_id),
        .fetch_program_counter(fetch_program_counter),
        .fetch_active_lane_mask(fetch_active_lane_mask),
        .register_dependency_hazard_detected(register_dependency_hazard_detected),
        .scoreboard_set_valid(scoreboard_set_valid),
        .scoreboard_set_warp_id(scoreboard_set_warp_id),
        .scoreboard_set_destination_register_id(scoreboard_set_destination_register_id),
        .scoreboard_check_valid(scoreboard_check_valid),
        .scoreboard_check_warp_id(scoreboard_check_warp_id),
        .scoreboard_check_source_register_1_id(scoreboard_check_source_register_1_id),
        .scoreboard_check_source_register_2_id(scoreboard_check_source_register_2_id),
        .scoreboard_check_rs_used(scoreboard_check_rs_used),
        .scoreboard_check_rt_used(scoreboard_check_rt_used),
        .branch_stall_requested(branch_stall_requested),
        .branch_stall_warp_id(branch_stall_warp_id),
        .branch_stall_program_counter(branch_stall_program_counter),
        .exit_stall_requested(exit_stall_requested),
        .exit_stall_warp_id(exit_stall_warp_id),
        .exit_stall_program_counter(exit_stall_program_counter),
        .execute_instruction_valid(execute_instruction_valid),
        .execute_warp_id(execute_warp_id),
        .execute_program_counter(execute_program_counter),
        .execute_active_lane_mask(execute_active_lane_mask),
        .execute_source_register_1_id(execute_source_register_1_id),
        .execute_source_register_2_id(execute_source_register_2_id),
        .execute_destination_register_id(execute_destination_register_id),
        .execute_immediate_value(execute_immediate_value),
        .execute_alu_operation(execute_alu_operation),
        .execute_uses_immediate_operand(execute_uses_immediate_operand),
        .execute_register_write_enable(execute_register_write_enable),
        .execute_memory_read_enable(execute_memory_read_enable),
        .execute_memory_write_enable(execute_memory_write_enable),
        .execute_branch_instruction(execute_branch_instruction),
        .execute_branch_not_equal(execute_branch_not_equal),
        .execute_exit_instruction(execute_exit_instruction)
    );

    vector_register_file u_register_file (
        .clk(clk),
        .rst(rst),
        .read_warp_id(execute_warp_id),
        .source_register_1_id(execute_source_register_1_id),
        .source_register_2_id(execute_source_register_2_id),
        .write_valid(register_file_write_valid),
        .write_warp_id(register_file_write_warp_id),
        .destination_register_id(register_file_write_destination_register_id),
        .write_data(register_file_write_data),
        .write_mask(register_file_write_mask),
        .source_register_1_data(source_register_1_data),
        .source_register_2_data(source_register_2_data)
    );

    execute_stage u_execute (
        .clk(clk),
        .rst(rst),
        .execute_instruction_valid(execute_instruction_valid),
        .execute_warp_id(execute_warp_id),
        .execute_program_counter(execute_program_counter),
        .execute_active_lane_mask(execute_active_lane_mask),
        .source_register_1_data(source_register_1_data),
        .source_register_2_data(source_register_2_data),
        .execute_immediate_value(execute_immediate_value),
        .execute_destination_register_id(execute_destination_register_id),
        .execute_alu_operation(execute_alu_operation),
        .execute_uses_immediate_operand(execute_uses_immediate_operand),
        .execute_register_write_enable(execute_register_write_enable),
        .execute_memory_read_enable(execute_memory_read_enable),
        .execute_memory_write_enable(execute_memory_write_enable),
        .execute_branch_instruction(execute_branch_instruction),
        .execute_branch_not_equal(execute_branch_not_equal),
        .execute_exit_instruction(execute_exit_instruction),
        .memory_instruction_valid(memory_instruction_valid),
        .memory_warp_id(memory_warp_id),
        .memory_program_counter(memory_program_counter),
        .memory_active_lane_mask(memory_pipeline_active_lane_mask),
        .memory_alu_result(memory_alu_result),
        .memory_address(memory_pipeline_address),
        .memory_store_data(memory_pipeline_store_data),
        .memory_destination_register_id(memory_destination_register_id),
        .memory_register_write_enable(memory_register_write_enable),
        .memory_read_enable(memory_pipeline_read_enable),
        .memory_write_enable(memory_pipeline_write_enable),
        .memory_branch_instruction(memory_branch_instruction),
        .memory_branch_taken(memory_branch_taken),
        .memory_branch_target_program_counter(memory_branch_target_program_counter), // Calculate branch target
        .memory_exit_instruction(memory_exit_instruction)
    );

    mem_stage u_memory_stage (
        .clk(clk),
        .rst(rst),
        .memory_instruction_valid(memory_instruction_valid),
        .memory_warp_id(memory_warp_id),
        .memory_program_counter(memory_program_counter),
        .memory_active_lane_mask(memory_pipeline_active_lane_mask),
        .memory_alu_result(memory_alu_result),
        .memory_address(memory_pipeline_address),
        .memory_store_data(memory_pipeline_store_data),
        .memory_destination_register_id(memory_destination_register_id),
        .memory_register_write_enable(memory_register_write_enable),
        .memory_read_enable(memory_pipeline_read_enable),
        .memory_write_enable(memory_pipeline_write_enable),
        .memory_branch_instruction(memory_branch_instruction),
        .memory_branch_taken(memory_branch_taken),
        .memory_branch_target_program_counter(memory_branch_target_program_counter), // Calculate branch target
        .memory_exit_instruction(memory_exit_instruction),
        .memory_load_data(memory_load_data),
        .data_memory_address(memory_address),
        .data_memory_store_data(memory_store_data),
        .data_memory_active_lane_mask(memory_active_lane_mask),
        .data_memory_read_enable(memory_read_enable),
        .data_memory_write_enable(memory_write_enable),
        .writeback_instruction_valid(writeback_instruction_valid), // Writeback pipeline data
        .writeback_warp_id(writeback_warp_id), // Writeback pipeline data
        .writeback_active_lane_mask(writeback_active_lane_mask), // Writeback pipeline data
        .writeback_result_data(writeback_result_data), // Writeback pipeline data
        .writeback_destination_register_id(writeback_destination_register_id), // Writeback pipeline data
        .writeback_register_write_enable(writeback_register_write_enable), // Writeback pipeline data
        .writeback_branch_instruction(writeback_branch_instruction), // Writeback pipeline data
        .writeback_branch_taken(writeback_branch_taken), // Writeback pipeline data
        .writeback_branch_target_program_counter(writeback_branch_target_program_counter), // Calculate branch target
        .writeback_exit_instruction(writeback_exit_instruction) // Writeback pipeline data
    );

    writeback_stage u_writeback ( // Writeback pipeline data
        .writeback_instruction_valid(writeback_instruction_valid), // Writeback pipeline data
        .writeback_warp_id(writeback_warp_id), // Writeback pipeline data
        .writeback_active_lane_mask(writeback_active_lane_mask), // Writeback pipeline data
        .writeback_result_data(writeback_result_data), // Writeback pipeline data
        .writeback_destination_register_id(writeback_destination_register_id), // Writeback pipeline data
        .writeback_register_write_enable(writeback_register_write_enable), // Writeback pipeline data
        .writeback_branch_instruction(writeback_branch_instruction), // Writeback pipeline data
        .writeback_branch_taken(writeback_branch_taken), // Writeback pipeline data
        .writeback_branch_target_program_counter(writeback_branch_target_program_counter), // Calculate branch target
        .writeback_exit_instruction(writeback_exit_instruction), // Writeback pipeline data
        .register_file_write_valid(register_file_write_valid),
        .register_file_write_warp_id(register_file_write_warp_id),
        .register_file_write_destination_register_id(register_file_write_destination_register_id),
        .register_file_write_data(register_file_write_data),
        .register_file_write_mask(register_file_write_mask),
        .scoreboard_clear_valid(scoreboard_clear_valid),
        .scoreboard_clear_warp_id(scoreboard_clear_warp_id),
        .scoreboard_clear_destination_register_id(scoreboard_clear_destination_register_id),
        .branch_commit(branch_commit),
        .branch_warp_id(branch_warp_id),
        .branch_taken(branch_taken),
        .branch_target_program_counter(branch_target_program_counter), // Calculate branch target
        .exit_commit(exit_commit),
        .exit_warp_id(exit_warp_id)
    );
endmodule
