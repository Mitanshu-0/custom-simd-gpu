// Per-warp, per-lane register file

`include "../../cu_defs.svh"

module vector_register_file #(
    parameter int `WARP_SIZE  = `WARP_SIZE, // 4 lanes
    parameter int `NUM_WARPS  = `NUM_WARPS, // 4 warps
    parameter int `NUM_VREGS  = `NUM_VREGS, // 32 registers/lane
    parameter int `LANE_WIDTH = `LANE_WIDTH // 32 bits/lane
) (
    input  logic                  clk, // clock
    input  logic                  rst, // reset
    input  logic [`WARP_ID_WIDTH-1:0] read_warp_id, // warp ID for read
    input  logic [`REG_ID_WIDTH-1:0]  source_register_1_id, // source register 1
    input  logic [`REG_ID_WIDTH-1:0]  source_register_2_id, // source register 2
    input  logic                  write_valid, // register write valid
    input  logic [`WARP_ID_WIDTH-1:0] write_warp_id, // warp ID for write
    input  logic [`REG_ID_WIDTH-1:0]  destination_register_id, // destination register
    input  logic [`LANE_WIDTH-1:0] write_data [0:`WARP_SIZE-1],
    input  logic [`WARP_SIZE-1:0] write_mask, // lane write mask
    output logic [`LANE_WIDTH-1:0] source_register_1_data [0:`WARP_SIZE-1],
    output logic [`LANE_WIDTH-1:0] source_register_2_data [0:`WARP_SIZE-1]
);
    logic [`LANE_WIDTH-1:0] registers [0:`NUM_WARPS-1][0:`WARP_SIZE-1][0:`NUM_VREGS-1];
    integer warp_index, lane_index, register_index;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int warp_index = 0; warp_index < `NUM_WARPS; warp_index++) begin
                for (int lane_index = 0; lane_index < `WARP_SIZE; lane_index++) begin
                    for (int register_index = 0; register_index < `NUM_VREGS; register_index++) begin
                        registers[warp_index][lane_index][register_index] <= '0;
                    end
                    if (`NUM_VREGS > 1)
                        registers[warp_index][lane_index][`REG_TID] <= warp_index * `WARP_SIZE + lane_index;
                end
            end
        end else if (write_valid && (destination_register_id != `REG_ZERO)) begin
            for (int lane_index = 0; lane_index < `WARP_SIZE; lane_index++) begin
                if (write_mask[lane_index]) begin
                    registers[write_warp_id][lane_index][destination_register_id] <= write_data[lane_index];
                end
            end
        end
    end

    genvar lane;
    generate
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin : GEN_REGISTER_READ
            always_comb begin
                if (source_register_1_id == `REG_ZERO)
                    source_register_1_data[lane] = '0;
                else
                    source_register_1_data[lane] = registers[read_warp_id][lane][source_register_1_id];

                if (source_register_2_id == `REG_ZERO)
                    source_register_2_data[lane] = '0;
                else
                    source_register_2_data[lane] = registers[read_warp_id][lane][source_register_2_id];
            end
        end
    endgenerate

`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (!rst) begin
            for (int lane_index = 0; lane_index < `WARP_SIZE; lane_index++) begin
                assert (registers[read_warp_id][lane_index][`REG_ZERO] == '0)
                    else $error("R0 invariant violated in lane %0d", lane_index);
            end
        end
    end
`endif
endmodule
