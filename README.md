# SIMT GPU RTL — Version 1

A clean, GitHub-ready SystemVerilog implementation of the educational SIMT GPU.

## Architecture

- 4 warps × 4 lanes by default
- 32-bit datapath per lane
- One reusable `lane_alu` instantiated for each lane
- Register file: `[warp][lane][register]`, 32 bits per entry
- 5 stages: IF → ID → EX → MEM → WB
- Round-robin warp scheduling
- Simple per-warp RAW scoreboard
- No per-warp instruction buffer
- No divergence/reconvergence in Version 1
- Asynchronous data-memory read and synchronous write

## Repository layout

```text
simt-gpu-v1/
├── rtl/
│   └── top/
│       ├── top.sv
│       ├── cu_defs.svh
│       ├── memory/
│       │   ├── instruction_memory.sv
│       │   └── data_memory.sv
│       └── compute_unit/
│           ├── compute_unit.sv
│           ├── pipeline/
│           │   ├── IFU.sv
│           │   ├── decode_unit.sv
│           │   ├── execute_stage.sv
│           │   ├── mem_stage.sv
│           │   └── writeback_stage.sv
│           ├── warp/
│           │   ├── warp_manager.sv
│           │   └── scoreboard.sv
│           ├── register_file/
│           │   └── vector_register_file.sv
│           └── alu/
│               ├── vector_alu.sv
│               └── lane_alu.sv
├── program.mem
├── data.mem
└── README.md
```

## RTL-only changes in this release

- Fixed all uses of `define` macros by using the required backtick syntax.
- Changed loop variables to block-local `int` declarations where applicable.
- No architectural or functional RTL changes were made.
