// Warp scheduling and control

`include "../../cu_defs.svh"

module warp_manager (
    input  logic clk, // clock
    input  logic rst, // reset

    input  logic stall_requested, // warp stall request
    input  logic [`WARP_ID_WIDTH-1:0] stall_warp_id, // stalled warp ID
    input  logic [`PC_WIDTH-1:0] stall_program_counter, // stalled instruction PC
    input  logic stall_is_branch, // stall is branch
    input  logic stall_is_exit, // stall is EXIT

    input  logic [`NUM_WARPS-1:0] dependency_resolved_for_warp, // dependency resolved per warp

    input  logic branch_commit, // branch commit
    input  logic [`WARP_ID_WIDTH-1:0] branch_warp_id, // branch warp ID
    input  logic branch_taken, // branch taken
    input  logic [`PC_WIDTH-1:0] branch_target_program_counter, // Calculate branch target

    input  logic exit_commit, // EXIT commit
    input  logic [`WARP_ID_WIDTH-1:0] exit_warp_id, // EXIT warp ID

    output logic instruction_issue_valid, // fetch request valid
    output logic [`WARP_ID_WIDTH-1:0] selected_warp_id, // selected warp
    output logic [`PC_WIDTH-1:0] selected_warp_program_counter, // selected PC
    output logic [`WARP_SIZE-1:0] selected_warp_active_lane_mask, // selected active lanes
    output logic [`WARP_STATE_WIDTH-1:0] warp_state [0:`NUM_WARPS-1], // per-warp state
    output logic [`PC_WIDTH-1:0] warp_program_counter [0:`NUM_WARPS-1] // per-warp PC
);
    logic [`WARP_SIZE-1:0] warp_active_lane_mask [0:`NUM_WARPS-1];
    logic [`WARP_ID_WIDTH-1:0] round_robin_pointer;
    logic [1:0] stall_reason [0:`NUM_WARPS-1];
    localparam logic [1:0] STALL_REASON_DEPENDENCY = 2'd0;
    localparam logic [1:0] STALL_REASON_BRANCH = 2'd1;
    localparam logic [1:0] STALL_REASON_EXIT = 2'd2;
    logic found;

    always_comb begin
        int candidate;
        found = 1'b0;
        selected_warp_id = round_robin_pointer;
        for (int i = 0; i < `NUM_WARPS; i++) begin
            candidate = round_robin_pointer + i;
            if (candidate >= `NUM_WARPS)
                candidate = candidate - `NUM_WARPS;
            if (!found && (warp_state[candidate] == `WARP_READY)) begin
                found = 1'b1;
                selected_warp_id = candidate[`WARP_ID_WIDTH-1:0];
            end
        end
        instruction_issue_valid = found && !(stall_requested && (stall_warp_id == selected_warp_id));
        selected_warp_program_counter = warp_program_counter[selected_warp_id];
        selected_warp_active_lane_mask = warp_active_lane_mask[selected_warp_id];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            round_robin_pointer <= '0;
            for (int i = 0; i < `NUM_WARPS; i++) begin
                warp_program_counter[i] <= '0;
                warp_active_lane_mask[i] <= `FULL_MASK;
                warp_state[i] <= `WARP_READY;
                stall_reason[i] <= STALL_REASON_DEPENDENCY;
            end
        end else begin

            if (instruction_issue_valid) begin
                warp_program_counter[selected_warp_id] <= warp_program_counter[selected_warp_id] + 16'd4;
                if (selected_warp_id == `NUM_WARPS-1)
                    round_robin_pointer <= '0;
                else
                    round_robin_pointer <= selected_warp_id + 1'b1;
            end

            if (stall_requested) begin
                warp_state[stall_warp_id] <= `WARP_STALL;
                if (stall_is_exit)
                    stall_reason[stall_warp_id] <= STALL_REASON_EXIT;
                else if (stall_is_branch)
                    stall_reason[stall_warp_id] <= STALL_REASON_BRANCH;
                else
                    stall_reason[stall_warp_id] <= STALL_REASON_DEPENDENCY;
                if (stall_is_branch)
                    warp_program_counter[stall_warp_id] <= stall_program_counter + 16'd4;
                else
                    warp_program_counter[stall_warp_id] <= stall_program_counter;
            end

            for (int i = 0; i < `NUM_WARPS; i++) begin
                if ((warp_state[i] == `WARP_STALL) && (stall_reason[i] == STALL_REASON_DEPENDENCY) &&
                    dependency_resolved_for_warp[i]) begin
                    warp_state[i] <= `WARP_READY;
                    stall_reason[i] <= STALL_REASON_DEPENDENCY;
                end
            end

            if (branch_commit) begin
                if (branch_taken)
                    warp_program_counter[branch_warp_id] <= branch_target_program_counter; // Calculate branch target
                warp_state[branch_warp_id] <= `WARP_READY;
                stall_reason[branch_warp_id] <= STALL_REASON_DEPENDENCY;
            end

            if (exit_commit) begin
                warp_state[exit_warp_id] <= `WARP_DONE;
                stall_reason[exit_warp_id] <= STALL_REASON_DEPENDENCY;
            end
        end
    end
endmodule
