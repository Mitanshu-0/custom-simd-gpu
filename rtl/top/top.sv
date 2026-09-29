// GPU top-level wiring

`include "cu_defs.svh"

module top (
    input logic clk, // clock
    input logic rst // reset
);
    logic [`PC_WIDTH-1:0] instruction_memory_address; // instruction address
    logic [`INST_WIDTH-1:0] instruction_memory_data; // instruction data
    logic memory_read_enable, memory_write_enable; // load enable
    logic [`WARP_SIZE-1:0] memory_active_lane_mask;
    logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1]; // lane addresses
    logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1]; // lane store data
    logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1]; // lane load data

    instruction_memory u_instruction_memory (
        .clk(clk),
        .address(instruction_memory_address),
        .instruction_data(instruction_memory_data)
    );

    data_memory u_data_memory (
        .clk(clk),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .active_lane_mask(memory_active_lane_mask),
        .memory_address(memory_address),
        .memory_store_data(memory_store_data),
        .memory_load_data(memory_load_data)
    );

    compute_unit u_compute_unit (
        .clk(clk),
        .rst(rst),
        .instruction_memory_address(instruction_memory_address),
        .instruction_memory_data(instruction_memory_data),
        .memory_read_enable(memory_read_enable),
        .memory_write_enable(memory_write_enable),
        .memory_active_lane_mask(memory_active_lane_mask),
        .memory_address(memory_address),
        .memory_store_data(memory_store_data),
        .memory_load_data(memory_load_data)
    );
endmodule
