// Per-lane data memory

`include "../cu_defs.svh"

module data_memory (
    input logic clk, // clock
    input logic memory_read_enable, // load enable
    input logic memory_write_enable, // store enable
    input logic [`WARP_SIZE-1:0] active_lane_mask, // active lanes
    input logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1], // lane addresses
    input logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1], // lane store data
    output logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1] // lane load data
);
    logic [`LANE_WIDTH-1:0] memory [0:`DMEM_DEPTH-1];
    localparam int ADDRESS_INDEX_WIDTH = $clog2(`DMEM_DEPTH);

    initial begin
        for (int index = 0; index < `DMEM_DEPTH; index++)
            memory[index] = '0;
        $readmemh("data.mem", memory); // Load data image
    end

    always_ff @(posedge clk) begin
        if (memory_write_enable) begin
            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                if (active_lane_mask[lane])
                    memory[memory_address[lane][ADDRESS_INDEX_WIDTH+1:2]] <= memory_store_data[lane];
            end
        end
    end

    always_comb begin
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin
            if (memory_read_enable)
                memory_load_data[lane] = memory[memory_address[lane][ADDRESS_INDEX_WIDTH+1:2]];
            else
                memory_load_data[lane] = '0;
        end
    end
endmodule
