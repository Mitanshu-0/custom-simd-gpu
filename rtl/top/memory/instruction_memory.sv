// Synchronous instruction memory

`include "../cu_defs.svh"

module instruction_memory (
    input logic clk, // clock
    input logic [`PC_WIDTH-1:0] address, // instruction byte address
    output logic [`INST_WIDTH-1:0] instruction_data // instruction word
);
    logic [`INST_WIDTH-1:0] memory [0:`IMEM_DEPTH-1];

    initial begin
        for (int index = 0; index < `IMEM_DEPTH; index++)
            memory[index] = '0;
        $readmemh("program.mem", memory); // Load program image
    end

    always_ff @(posedge clk)
        instruction_data <= memory[address[`PC_WIDTH-1:2]]; // Read instruction on clock
endmodule
