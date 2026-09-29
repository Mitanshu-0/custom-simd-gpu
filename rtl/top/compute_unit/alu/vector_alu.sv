// Parallel 32-bit lane ALUs

`include "../../cu_defs.svh"

module vector_alu #(
    parameter int `WARP_SIZE  = `WARP_SIZE,             // 4 lanes by default, // 4 lanes
    parameter int `LANE_WIDTH = `LANE_WIDTH              // 32 bits by default // 32 bits/lane
) (
    input  logic [`LANE_WIDTH-1:0] operand_a [0:`WARP_SIZE-1], // operand A
    input  logic [`LANE_WIDTH-1:0] operand_b [0:`WARP_SIZE-1], // operand B
    input  logic [`LANE_WIDTH-1:0] immediate_operand, // 32-bit immediate
    input  logic                  use_immediate_operand, // use immediate
    input  logic [5:0]            alu_operation, // ALU operation
    input  logic [`WARP_SIZE-1:0]  active_lane_mask, // active lanes
    output logic [`LANE_WIDTH-1:0] result [0:`WARP_SIZE-1] // lane result
);

    genvar lane;
    generate
        for (lane = 0; lane < `WARP_SIZE; lane++) begin : GEN_LANE_ALU
            logic [`LANE_WIDTH-1:0] lane_result;
            lane_alu #(.`LANE_WIDTH(`LANE_WIDTH)) u_lane_alu (
                .operand_a(operand_a[lane]),
                .operand_b(operand_b[lane]),
                .immediate_operand(immediate_operand),
                .use_immediate_operand(use_immediate_operand),
                .alu_operation(alu_operation),
                .result(lane_result)
            );
            assign result[lane] = active_lane_mask[lane] ? lane_result : '0; // Mask inactive lane
        end
    endgenerate
endmodule
