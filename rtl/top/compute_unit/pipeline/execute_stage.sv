// Execute stage and lane ALU/branch logic

`include "../../cu_defs.svh"

module execute_stage (
    input logic clk, // clock
    input logic rst, // reset
    input logic execute_instruction_valid, // EX instruction valid
    input logic [`WARP_ID_WIDTH-1:0] execute_warp_id, // EX warp ID
    input logic [`PC_WIDTH-1:0] execute_program_counter, // EX PC
    input logic [`WARP_SIZE-1:0] execute_active_lane_mask, // EX lane mask
    input logic [`LANE_WIDTH-1:0] source_register_1_data [0:`WARP_SIZE-1], // lane source 1
    input logic [`LANE_WIDTH-1:0] source_register_2_data [0:`WARP_SIZE-1], // lane source 2
    input logic [`LANE_WIDTH-1:0] execute_immediate_value, // 32-bit immediate
    input logic [`REG_ID_WIDTH-1:0] execute_destination_register_id, // EX destination register
    input logic [5:0] execute_alu_operation, // ALU operation
    input logic execute_uses_immediate_operand, // use immediate operand
    input logic execute_register_write_enable, // register write enable
    input logic execute_memory_read_enable, // load enable
    input logic execute_memory_write_enable, // store enable
    input logic execute_branch_instruction, // branch instruction
    input logic execute_branch_not_equal, // BNE select
    input logic execute_exit_instruction, // EXIT instruction

    output logic memory_instruction_valid, // MEM instruction valid
    output logic [`WARP_ID_WIDTH-1:0] memory_warp_id, // MEM warp ID
    output logic [`PC_WIDTH-1:0] memory_program_counter, // MEM PC
    output logic [`WARP_SIZE-1:0] memory_active_lane_mask, // active lane mask
    output logic [`LANE_WIDTH-1:0] memory_alu_result [0:`WARP_SIZE-1], // lane ALU results
    output logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1], // lane addresses
    output logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1], // lane store data
    output logic [`REG_ID_WIDTH-1:0] memory_destination_register_id, // MEM destination register
    output logic memory_register_write_enable, // MEM register write enable
    output logic memory_read_enable, // load enable
    output logic memory_write_enable, // store enable
    output logic memory_branch_instruction, // MEM branch
    output logic memory_branch_taken, // branch result
    output logic [`PC_WIDTH-1:0] memory_branch_target_program_counter, // Calculate branch target
    output logic memory_exit_instruction // MEM EXIT
);
    logic [`LANE_WIDTH-1:0] alu_result [0:`WARP_SIZE-1];
    logic [`LANE_WIDTH-1:0] address_result [0:`WARP_SIZE-1];
    logic branch_taken_comb;
    logic all_equal, all_not_equal, saw_active;

    vector_alu u_vector_alu (
        .operand_a(source_register_1_data),
        .operand_b(source_register_2_data),
        .immediate_operand(execute_immediate_value),
        .use_immediate_operand(execute_uses_immediate_operand),
        .alu_operation(execute_alu_operation),
        .active_lane_mask(execute_active_lane_mask),
        .result(alu_result)
    );

    genvar address_lane;
    generate
        for (address_lane = 0; address_lane < `WARP_SIZE; address_lane++) begin : GEN_ADDRESS
            assign address_result[address_lane] =
                source_register_1_data[address_lane] + execute_immediate_value;
        end
    endgenerate

    always_comb begin
        all_equal = 1'b1;
        all_not_equal = 1'b1;
        saw_active = 1'b0;
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin
            if (execute_active_lane_mask[lane]) begin
                saw_active = 1'b1;
                if (source_register_1_data[lane] != source_register_2_data[lane])
                    all_equal = 1'b0;
                if (source_register_1_data[lane] == source_register_2_data[lane])
                    all_not_equal = 1'b0;
            end
        end
        if (!saw_active) begin
            all_equal = 1'b0;
            all_not_equal = 1'b0;
        end

        if (execute_branch_not_equal)
            branch_taken_comb = all_not_equal;
        else
            branch_taken_comb = all_equal;

        if (!execute_branch_instruction || !execute_instruction_valid)
            branch_taken_comb = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            memory_instruction_valid <= 1'b0;
            memory_warp_id <= '0;
            memory_program_counter <= '0;
            memory_active_lane_mask <= '0;
            memory_destination_register_id <= `REG_ZERO;
            memory_register_write_enable <= 1'b0;
            memory_read_enable <= 1'b0;
            memory_write_enable <= 1'b0;
            memory_branch_instruction <= 1'b0;
            memory_branch_taken <= 1'b0;
            memory_branch_target_program_counter <= '0; // Calculate branch target
            memory_exit_instruction <= 1'b0;
            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                memory_alu_result[lane] <= '0;
                memory_address[lane] <= '0;
                memory_store_data[lane] <= '0;
            end
        end else begin
            memory_instruction_valid <= execute_instruction_valid;
            memory_warp_id <= execute_warp_id;
            memory_program_counter <= execute_program_counter;
            memory_active_lane_mask <= execute_active_lane_mask;
            memory_destination_register_id <= execute_destination_register_id;
            memory_register_write_enable <= execute_register_write_enable;
            memory_read_enable <= execute_memory_read_enable;
            memory_write_enable <= execute_memory_write_enable;
            memory_branch_instruction <= execute_branch_instruction;
            memory_branch_taken <= branch_taken_comb;
            memory_branch_target_program_counter <= execute_program_counter + execute_immediate_value[`PC_WIDTH-1:0]; // Calculate branch target
            memory_exit_instruction <= execute_exit_instruction;

            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                memory_alu_result[lane] <= alu_result[lane];
                memory_address[lane] <= address_result[lane];
                memory_store_data[lane] <= source_register_2_data[lane];
            end
        end
    end
endmodule
