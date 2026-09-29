// Common GPU constants and ISA definitions

`ifndef CU_DEFS_SVH
`define CU_DEFS_SVH

`define WARP_SIZE 4                         // 4 lanes per warp
`define NUM_WARPS 4                         // 4 warps
`define NUM_VREGS 32                        // 32 registers per lane
`define LANE_WIDTH 32                       // 32 bits per lane
`define INST_WIDTH 32                       // 32 bits per instruction
`define PC_WIDTH 16                         // 16-bit PC
`define IMM_WIDTH 16                        // 16-bit immediate field
`define IMEM_DEPTH 256                      // 256 instruction words
`define DMEM_DEPTH 1024                     // 1024 data words
`define WARP_ID_WIDTH 2                     // 2 bits for 4 warps
`define REG_ID_WIDTH 5                      // 5 bits for 32 registers
`define WARP_STATE_WIDTH 2                  // 2-bit warp state
`define PENDING_COUNT_WIDTH 4                // Unused in simple scoreboard

`define WARP_READY 2'b00                    // Ready
`define WARP_STALL 2'b01                    // Stalled
`define WARP_DONE  2'b10                    // Done

`define OPCODE_ALU_R 6'b000000              // R-type ALU
`define OPCODE_ALU_I 6'b000001              // Immediate ALU
`define OPCODE_LOAD  6'b001000              // Load
`define OPCODE_STORE 6'b001001              // Store
`define OPCODE_BEQ   6'b010000              // Branch equal
`define OPCODE_BNE   6'b010001              // Branch not equal
`define OPCODE_EXIT  6'b011000              // Exit warp

`define FUNC_ADD 6'b000000                   // ADD
`define FUNC_SUB 6'b000001                   // SUB
`define FUNC_AND 6'b000010                   // AND
`define FUNC_OR  6'b000011                   // OR
`define FUNC_XOR 6'b000100                   // XOR
`define FUNC_SLT 6'b000101                   // SLT

`define REG_ZERO 5'd0                      // R0 is always zero
`define REG_TID  5'd1                      // R1 holds lane thread ID
`define FULL_MASK {`WARP_SIZE{1'b1}}        // All lanes active

`endif
