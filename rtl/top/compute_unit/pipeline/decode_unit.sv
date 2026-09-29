// Instruction decode and control generation

`include "../../cu_defs.svh"

module decode_unit (
    input  logic                   clk, // clock
    input  logic                   rst, // reset
    input  logic [`INST_WIDTH-1:0] fetch_instruction, // fetched instruction
    input  logic                   fetch_instruction_valid, // fetched instruction valid
    input  logic [`WARP_ID_WIDTH-1:0] fetch_warp_id, // fetched warp
    input  logic [`PC_WIDTH-1:0] fetch_program_counter, // fetched PC
    input  logic [`WARP_SIZE-1:0] fetch_active_lane_mask, // fetched active lanes
    input  logic                   register_dependency_hazard_detected, // RAW hazard

    output logic                   scoreboard_set_valid, // scoreboard set valid
    output logic [`WARP_ID_WIDTH-1:0] scoreboard_set_warp_id, // scoreboard set warp ID
    output logic [`REG_ID_WIDTH-1:0] scoreboard_set_destination_register_id, // destination register to mark busy

    output logic                   scoreboard_check_valid, // scoreboard check valid
    output logic [`WARP_ID_WIDTH-1:0] scoreboard_check_warp_id, // scoreboard check warp ID
    output logic [`REG_ID_WIDTH-1:0] scoreboard_check_source_register_1_id, // source register 1 to check
    output logic [`REG_ID_WIDTH-1:0] scoreboard_check_source_register_2_id, // source register 2 to check
    output logic                   scoreboard_check_rs_used, // source 1 is used
    output logic                   scoreboard_check_rt_used, // source 2 is used

    output logic                   branch_stall_requested, // branch stall request
    output logic [`WARP_ID_WIDTH-1:0] branch_stall_warp_id, // branch stall warp ID
    output logic [`PC_WIDTH-1:0] branch_stall_program_counter, // branch PC
    output logic                   exit_stall_requested, // EXIT stall request
    output logic [`WARP_ID_WIDTH-1:0] exit_stall_warp_id, // EXIT warp ID
    output logic [`PC_WIDTH-1:0] exit_stall_program_counter, // EXIT PC

    output logic                   execute_instruction_valid, // EX instruction valid
    output logic [`WARP_ID_WIDTH-1:0] execute_warp_id, // EX warp ID
    output logic [`PC_WIDTH-1:0] execute_program_counter, // EX PC
    output logic [`WARP_SIZE-1:0] execute_active_lane_mask, // EX lane mask
    output logic [`REG_ID_WIDTH-1:0] execute_source_register_1_id, // EX source register 1
    output logic [`REG_ID_WIDTH-1:0] execute_source_register_2_id, // EX source register 2
    output logic [`REG_ID_WIDTH-1:0] execute_destination_register_id, // EX destination register
    output logic [`LANE_WIDTH-1:0] execute_immediate_value, // 32-bit immediate
    output logic [5:0]             execute_alu_operation, // ALU operation
    output logic                   execute_uses_immediate_operand, // use immediate operand
    output logic                   execute_register_write_enable, // register write enable
    output logic                   execute_memory_read_enable, // load enable
    output logic                   execute_memory_write_enable, // store enable
    output logic                   execute_branch_instruction, // branch instruction
    output logic                   execute_branch_not_equal, // BNE select
    output logic                   execute_exit_instruction // EXIT instruction
);
    logic [5:0] opcode;
    logic [`REG_ID_WIDTH-1:0] rs, rt, rd;
    logic [`IMM_WIDTH-1:0] raw_immediate;

    logic reg_write_d, mem_read_d, mem_write_d;
    logic branch_d, branch_not_equal_d, exit_d;
    logic uses_immediate_d, rs_used_d, rt_used_d;
    logic [5:0] alu_operation_d;
    logic [`REG_ID_WIDTH-1:0] destination_register_d;
    logic [`REG_ID_WIDTH-1:0] source_register_1_d, source_register_2_d;
    logic [`LANE_WIDTH-1:0] sign_extended_immediate_d;

    assign opcode = fetch_instruction[31:26];
    assign rs = fetch_instruction[25:21];
    assign rt = fetch_instruction[20:16];
    assign rd = fetch_instruction[15:11];
    assign raw_immediate = fetch_instruction[15:0];
    assign sign_extended_immediate_d = {{(`LANE_WIDTH-`IMM_WIDTH){raw_immediate[`IMM_WIDTH-1]}}, raw_immediate};

    always_comb begin
        reg_write_d = 1'b0;
        mem_read_d = 1'b0;
        mem_write_d = 1'b0;
        branch_d = 1'b0;
        branch_not_equal_d = 1'b0;
        exit_d = 1'b0;
        uses_immediate_d = 1'b0;
        rs_used_d = 1'b0;
        rt_used_d = 1'b0;
        alu_operation_d = `FUNC_ADD;
        destination_register_d = `REG_ZERO;
        source_register_1_d = `REG_ZERO;
        source_register_2_d = `REG_ZERO;

        case (opcode)
            `OPCODE_ALU_R: begin
                reg_write_d = 1'b1;
                rs_used_d = 1'b1;
                rt_used_d = 1'b1;
                source_register_1_d = rs;
                source_register_2_d = rt;
                destination_register_d = rd;
                alu_operation_d = fetch_instruction[5:0];
            end
            `OPCODE_ALU_I: begin
                reg_write_d = 1'b1;
                rs_used_d = 1'b1;
                uses_immediate_d = 1'b1;
                source_register_1_d = rs;
                destination_register_d = rt;
                alu_operation_d = `FUNC_ADD;
            end
            `OPCODE_LOAD: begin
                reg_write_d = 1'b1;
                mem_read_d = 1'b1;
                rs_used_d = 1'b1;
                uses_immediate_d = 1'b1;
                source_register_1_d = rs;
                destination_register_d = rt;
                alu_operation_d = `FUNC_ADD;
            end
            `OPCODE_STORE: begin
                mem_write_d = 1'b1;
                rs_used_d = 1'b1;
                rt_used_d = 1'b1;
                uses_immediate_d = 1'b1;
                source_register_1_d = rs;
                source_register_2_d = rt;
                alu_operation_d = `FUNC_ADD;
            end
            `OPCODE_BEQ: begin
                branch_d = 1'b1;
                rs_used_d = 1'b1;
                rt_used_d = 1'b1;
                source_register_1_d = rs;
                source_register_2_d = rt;
            end
            `OPCODE_BNE: begin
                branch_d = 1'b1;
                branch_not_equal_d = 1'b1;
                rs_used_d = 1'b1;
                rt_used_d = 1'b1;
                source_register_1_d = rs;
                source_register_2_d = rt;
            end
            `OPCODE_EXIT: begin
                exit_d = 1'b1;
            end
            default: begin end
        endcase
    end

    always_comb begin
        scoreboard_check_valid = fetch_instruction_valid;
        scoreboard_check_warp_id = fetch_warp_id;
        scoreboard_check_source_register_1_id = source_register_1_d;
        scoreboard_check_source_register_2_id = source_register_2_d;
        scoreboard_check_rs_used = rs_used_d;
        scoreboard_check_rt_used = rt_used_d;

        branch_stall_requested = fetch_instruction_valid && branch_d && !register_dependency_hazard_detected;
        branch_stall_warp_id = fetch_warp_id;
        branch_stall_program_counter = fetch_program_counter;

        exit_stall_requested = fetch_instruction_valid && exit_d && !register_dependency_hazard_detected;
        exit_stall_warp_id = fetch_warp_id;
        exit_stall_program_counter = fetch_program_counter;

        scoreboard_set_valid = fetch_instruction_valid && !register_dependency_hazard_detected && !branch_d &&
                               reg_write_d && (destination_register_d != `REG_ZERO);
        scoreboard_set_warp_id = fetch_warp_id;
        scoreboard_set_destination_register_id = destination_register_d;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            execute_instruction_valid <= 1'b0;
            execute_warp_id <= '0;
            execute_program_counter <= '0;
            execute_active_lane_mask <= '0;
            execute_source_register_1_id <= `REG_ZERO;
            execute_source_register_2_id <= `REG_ZERO;
            execute_destination_register_id <= `REG_ZERO;
            execute_immediate_value <= '0;
            execute_alu_operation <= `FUNC_ADD;
            execute_uses_immediate_operand <= 1'b0;
            execute_register_write_enable <= 1'b0;
            execute_memory_read_enable <= 1'b0;
            execute_memory_write_enable <= 1'b0;
            execute_branch_instruction <= 1'b0;
            execute_branch_not_equal <= 1'b0;
            execute_exit_instruction <= 1'b0;
        end else begin
            execute_instruction_valid <= fetch_instruction_valid && !register_dependency_hazard_detected;
            execute_warp_id <= fetch_warp_id;
            execute_program_counter <= fetch_program_counter;
            execute_active_lane_mask <= fetch_active_lane_mask;
            execute_source_register_1_id <= source_register_1_d;
            execute_source_register_2_id <= source_register_2_d;
            execute_destination_register_id <= destination_register_d;
            execute_immediate_value <= sign_extended_immediate_d;
            execute_alu_operation <= alu_operation_d;
            execute_uses_immediate_operand <= uses_immediate_d;
            execute_register_write_enable <= fetch_instruction_valid && !register_dependency_hazard_detected && reg_write_d;
            execute_memory_read_enable <= fetch_instruction_valid && !register_dependency_hazard_detected && mem_read_d;
            execute_memory_write_enable <= fetch_instruction_valid && !register_dependency_hazard_detected && mem_write_d;
            execute_branch_instruction <= fetch_instruction_valid && !register_dependency_hazard_detected && branch_d;
            execute_branch_not_equal <= branch_not_equal_d;
            execute_exit_instruction <= fetch_instruction_valid && !register_dependency_hazard_detected && exit_d;
        end
    end
endmodule
