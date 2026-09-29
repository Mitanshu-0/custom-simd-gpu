// RAW dependency scoreboard

`include "../../cu_defs.svh"

module scoreboard (
    input  logic clk, // clock
    input  logic rst, // reset

    input  logic set_valid, // scoreboard set
    input  logic [`WARP_ID_WIDTH-1:0] set_warp_id, // warp ID to set
    input  logic [`REG_ID_WIDTH-1:0] set_destination_register_id, // destination to mark busy

    input  logic clear_valid, // scoreboard clear
    input  logic [`WARP_ID_WIDTH-1:0] clear_warp_id, // warp ID to clear
    input  logic [`REG_ID_WIDTH-1:0] clear_destination_register_id, // destination to clear

    input  logic check_valid, // hazard check
    input  logic [`WARP_ID_WIDTH-1:0] check_warp_id, // warp ID to check
    input  logic [`REG_ID_WIDTH-1:0] check_source_register_1_id, // source register 1
    input  logic [`REG_ID_WIDTH-1:0] check_source_register_2_id, // source register 2
    input  logic check_rs_used, // source 1 is used
    input  logic check_rt_used, // source 2 is used

    output logic register_dependency_hazard_detected, // RAW hazard

    output logic [`NUM_WARPS-1:0] dependency_resolved_for_warp // dependency resolved per warp
);

    logic busy [0:`NUM_WARPS-1][0:`NUM_VREGS-1]; // RAW busy bits

    logic [`NUM_WARPS-1:0] blocked_valid;
    logic [`REG_ID_WIDTH-1:0] blocked_source_register_1 [0:`NUM_WARPS-1];
    logic [`REG_ID_WIDTH-1:0] blocked_source_register_2 [0:`NUM_WARPS-1];
    logic blocked_rs_used [0:`NUM_WARPS-1];
    logic blocked_rt_used [0:`NUM_WARPS-1];


    always_comb begin
        register_dependency_hazard_detected = 1'b0;

        if (check_valid) begin

            if (check_rs_used && (check_source_register_1_id != `REG_ZERO) &&
                busy[check_warp_id][check_source_register_1_id])
                register_dependency_hazard_detected = 1'b1; // Report RAW hazard

            if (check_rt_used && (check_source_register_2_id != `REG_ZERO) &&
                busy[check_warp_id][check_source_register_2_id])
                register_dependency_hazard_detected = 1'b1; // Report RAW hazard
        end

        for (int warp_index = 0; warp_index < `NUM_WARPS; warp_index++) begin
            dependency_resolved_for_warp[warp_index] = 1'b0;

            if (blocked_valid[warp_index]) begin
                dependency_resolved_for_warp[warp_index] = 1'b1;

                if (blocked_rs_used[warp_index] &&
                    (blocked_source_register_1[warp_index] != `REG_ZERO) &&
                    busy[warp_index][blocked_source_register_1[warp_index]])
                    dependency_resolved_for_warp[warp_index] = 1'b0;

                if (blocked_rt_used[warp_index] &&
                    (blocked_source_register_2[warp_index] != `REG_ZERO) &&
                    busy[warp_index][blocked_source_register_2[warp_index]])
                    dependency_resolved_for_warp[warp_index] = 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int warp_index = 0; warp_index < `NUM_WARPS; warp_index++) begin
                blocked_valid[warp_index] <= 1'b0;
                blocked_source_register_1[warp_index] <= `REG_ZERO;
                blocked_source_register_2[warp_index] <= `REG_ZERO;
                blocked_rs_used[warp_index] <= 1'b0;
                blocked_rt_used[warp_index] <= 1'b0;

                for (int register_index = 0; register_index < `NUM_VREGS; register_index++)
                    busy[warp_index][register_index] <= 1'b0; // Clear destination busy
            end
        end else begin

            if (check_valid && register_dependency_hazard_detected) begin
                blocked_valid[check_warp_id] <= 1'b1;
                blocked_source_register_1[check_warp_id] <= check_source_register_1_id;
                blocked_source_register_2[check_warp_id] <= check_source_register_2_id;
                blocked_rs_used[check_warp_id] <= check_rs_used;
                blocked_rt_used[check_warp_id] <= check_rt_used;
            end

            for (int warp_index = 0; warp_index < `NUM_WARPS; warp_index++) begin
                if (blocked_valid[warp_index] && dependency_resolved_for_warp[warp_index])
                    blocked_valid[warp_index] <= 1'b0;
            end

            if (set_valid && (set_destination_register_id != `REG_ZERO)) begin

                if (clear_valid &&
                    (set_warp_id == clear_warp_id) &&
                    (set_destination_register_id == clear_destination_register_id))
                    busy[set_warp_id][set_destination_register_id] <= 1'b1; // Mark destination busy
                else
                    busy[set_warp_id][set_destination_register_id] <= 1'b1; // Mark destination busy
            end

            if (clear_valid && (clear_destination_register_id != `REG_ZERO) &&
                !(set_valid &&
                  (set_warp_id == clear_warp_id) &&
                  (set_destination_register_id == clear_destination_register_id))) begin
                busy[clear_warp_id][clear_destination_register_id] <= 1'b0; // Clear destination busy
            end
        end
    end

`ifndef SYNTHESIS

    always_ff @(posedge clk) begin
        if (!rst) begin
            for (int warp_index = 0; warp_index < `NUM_WARPS; warp_index++) begin
                assert (!busy[warp_index][`REG_ZERO])
                    else $error("Scoreboard must never mark R0 busy");
            end
        end
    end
`endif

endmodule
