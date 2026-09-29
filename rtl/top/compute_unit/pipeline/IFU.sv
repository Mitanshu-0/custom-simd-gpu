// Instruction fetch and request alignment

`include "../../cu_defs.svh"

module instruction_fetch_unit (
    input  logic clk, // clock
    input  logic rst, // reset
    input  logic instruction_issue_valid, // fetch request valid
    input  logic [`WARP_ID_WIDTH-1:0] selected_warp_id, // selected warp
    input  logic [`PC_WIDTH-1:0] selected_warp_program_counter, // selected PC
    input  logic [`WARP_SIZE-1:0] selected_warp_active_lane_mask, // selected active lanes
    input  logic [`INST_WIDTH-1:0] instruction_memory_data, // instruction data
    output logic [`PC_WIDTH-1:0] instruction_memory_address, // instruction address
    output logic fetch_instruction_valid, // fetched instruction valid
    output logic [`WARP_ID_WIDTH-1:0] fetch_warp_id, // fetched warp
    output logic [`PC_WIDTH-1:0] fetch_program_counter, // fetched PC
    output logic [`WARP_SIZE-1:0] fetch_active_lane_mask, // fetched active lanes
    output logic [`INST_WIDTH-1:0] fetch_instruction // fetched instruction
);
    logic request_valid;
    logic [`WARP_ID_WIDTH-1:0] request_warp_id;
    logic [`PC_WIDTH-1:0] request_program_counter;
    logic [`WARP_SIZE-1:0] request_active_lane_mask;

    assign instruction_memory_address = selected_warp_program_counter; // Selected PC goes to IMEM

    always_ff @(posedge clk) begin
        if (rst) begin
            request_valid <= 1'b0; // Capture next fetch request
            request_warp_id <= '0;
            request_program_counter <= '0;
            request_active_lane_mask <= '0;
            fetch_instruction_valid <= 1'b0; // Align valid with IMEM response
            fetch_warp_id <= '0;
            fetch_program_counter <= '0;
            fetch_active_lane_mask <= '0;
            fetch_instruction <= '0;
        end else begin
            fetch_instruction_valid <= request_valid; // Align valid with IMEM response
            fetch_warp_id <= request_warp_id;
            fetch_program_counter <= request_program_counter;
            fetch_active_lane_mask <= request_active_lane_mask;
            fetch_instruction <= instruction_memory_data;

            request_valid <= instruction_issue_valid; // Capture next fetch request
            request_warp_id <= selected_warp_id;
            request_program_counter <= selected_warp_program_counter;
            request_active_lane_mask <= selected_warp_active_lane_mask;
        end
    end
endmodule
