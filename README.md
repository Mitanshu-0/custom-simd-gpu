# Custom SIMD GPU — RTL V1

<p align="center">

![SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue)
![Architecture](https://img.shields.io/badge/Architecture-SIMD%2FSIMT-orange)
![Pipeline](https://img.shields.io/badge/Pipeline-5--Stage-green)
![Lanes](https://img.shields.io/badge/Lanes-4-purple)
![Warps](https://img.shields.io/badge/Warps-4-red)
![Version](https://img.shields.io/badge/Version-V1-lightgrey)

</p>

A compact educational GPU-style processor implemented from scratch in
SystemVerilog RTL.

The design combines a **warp-based SIMT execution model** with a
**parallel SIMD lane datapath**. Each warp contains multiple 32-bit lanes,
and the processor executes one instruction across the active lanes of the
selected warp.

The project is designed to make GPU microarchitecture understandable at
RTL level by keeping the datapath, warp scheduler, register file,
scoreboard, pipeline, and memory system explicit and easy to study.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Architecture Diagram](#architecture-diagram)
- [Default Configuration](#default-configuration)
- [Pipeline](#pipeline)
- [Warp Organization](#warp-organization)
- [Warp Scheduler](#warp-scheduler)
- [Register File](#register-file)
- [SIMD Execution](#simd-execution)
- [Scoreboard and Hazard Detection](#scoreboard-and-hazard-detection)
- [Instruction Set](#instruction-set)
- [Instruction Format](#instruction-format)
- [Memory System](#memory-system)
- [Branch Handling](#branch-handling)
- [EXIT Handling](#exit-handling)
- [Active Lane Mask](#active-lane-mask)
- [Top-Level Module](#top-level-module)
- [RTL Repository Structure](#rtl-repository-structure)
- [Configuration Parameters](#configuration-parameters)
- [Memory Initialization](#memory-initialization)
- [Example Program](#example-program)
- [Design Decisions](#design-decisions)
- [Current Limitations](#current-limitations)
- [Future Work](#future-work)
- [Learning Objectives](#learning-objectives)
- [Getting Started](#getting-started)
- [Project Status](#project-status)

---

# Overview

Modern GPU architectures obtain parallelism by executing the same
instruction across multiple execution lanes.

This project implements a simplified version of that idea in synthesizable
SystemVerilog RTL.

The processor is organized around:

- Multiple independent warps
- Multiple lanes per warp
- A per-warp program counter
- A per-warp active-lane mask
- Round-robin warp scheduling
- A 5-stage pipeline
- A per-warp register dependency scoreboard
- A per-warp, per-lane register file
- A parallel lane-based ALU
- Per-lane memory addressing
- Basic branch handling
- Explicit warp completion using `EXIT`

The default configuration contains:

```text
4 warps
4 lanes per warp
32 registers per lane
32-bit datapath
```

Therefore, the default configuration represents:

```text
4 × 4 = 16 logical execution lanes
```

The design intentionally avoids advanced GPU mechanisms such as caches,
warp instruction buffers, register renaming, multiple schedulers,
multiple execution units, complex divergence stacks, and memory
coalescing logic.

This keeps the architecture small enough to understand directly from
the RTL.

---

# Key Features

## Processor

- SystemVerilog RTL implementation
- 32-bit datapath
- 32-bit instructions
- 16-bit program counter
- 5-stage in-order pipeline
- Parameterized lane and warp dimensions

## Warp Execution

- 4 independent warps by default
- 4 lanes per warp by default
- Per-warp program counter
- Per-warp active-lane mask
- Per-warp execution state
- Round-robin warp scheduler

## Execution

- Parallel lane ALUs
- ADD
- SUB
- AND
- OR
- XOR
- SLT
- Immediate ADD
- Per-lane active-mask gating

## Hazard Handling

- Per-warp scoreboard
- RAW dependency detection
- Source-operand usage tracking
- Destination register tracking
- Warp stalling when dependencies are unresolved
- Scoreboard clearing during writeback

## Memory

- Separate instruction and data memories
- Word-oriented memory access
- Per-lane addresses
- Per-lane store data
- Per-lane load data
- Active-lane memory masking
- Synchronous memory writes
- Combinational/asynchronous data-memory reads

## Control Flow

- BEQ
- BNE
- Per-warp branch handling
- Branch target based on the branch instruction PC
- Explicit EXIT instruction
- DONE warp state

---

# Architecture

The processor is divided into three major levels:

```text
                    ┌──────────────────────┐
                    │         TOP          │
                    │       top.sv         │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
      Instruction Memory   Compute Unit     Data Memory
      instruction_memory   compute_unit     data_memory
                              │
                              │
              ┌───────────────┴────────────────┐
              │                                │
              ▼                                ▼
        Warp Management                  5-Stage Pipeline
        ┌───────────────┐          ┌─────────────────────┐
        │ warp_manager  │          │ IF → ID → EX → MEM │
        │ scoreboard    │          │        → WB         │
        └───────────────┘          └─────────────────────┘
                                             │
                           ┌─────────────────┼─────────────────┐
                           │                 │                 │
                           ▼                 ▼                 ▼
                      Register File       Vector ALU       Memory
```

The central component is the `compute_unit`.

It connects:

- Warp manager
- Instruction fetch unit
- Decode unit
- Vector register file
- Scoreboard
- Execute stage
- Memory stage
- Writeback stage
- Instruction memory
- Data memory

---

# Architecture Diagram

The repository contains the architecture diagram:

![SIMD GPU Architecture](img/simt_gpu_rtl_architecture%20(1).svg)

The diagram shows the main module hierarchy and the signal-level
connections between the major blocks.

---

# Default Configuration

The architectural constants are defined in:

```text
rtl/top/cu_defs.svh
```

Default configuration:

| Parameter | Value | Description |
|---|---:|---|
| `WARP_SIZE` | 4 | Lanes per warp |
| `NUM_WARPS` | 4 | Number of resident warps |
| `NUM_VREGS` | 32 | Registers per lane |
| `LANE_WIDTH` | 32 | Bits per lane |
| `INST_WIDTH` | 32 | Instruction width |
| `PC_WIDTH` | 16 | Program counter width |
| `IMM_WIDTH` | 16 | Immediate field width |
| `IMEM_DEPTH` | 256 | Instruction memory words |
| `DMEM_DEPTH` | 1024 | Data memory words |
| `WARP_ID_WIDTH` | 2 | Warp identifier width |
| `REG_ID_WIDTH` | 5 | Register identifier width |

The configuration can be modified through the definitions in
`cu_defs.svh`.

---

# Pipeline

The processor uses a classic five-stage in-order pipeline:

```text
IF → ID → EX → MEM → WB
```

## 1. IF — Instruction Fetch

Implemented by:

```text
rtl/top/compute_unit/pipeline/IFU.sv
```

Responsibilities:

- Receive the selected warp from the scheduler
- Generate the instruction memory address
- Capture the selected warp ID
- Capture the warp PC
- Capture the active-lane mask
- Align the instruction memory response with the corresponding warp

The instruction memory uses the program counter as a byte address.

The instruction memory internally indexes using:

```text
PC[PC_WIDTH-1:2]
```

because instructions are 32 bits / 4 bytes.

---

## 2. ID — Instruction Decode

Implemented by:

```text
rtl/top/compute_unit/pipeline/decode_unit.sv
```

Responsibilities:

- Decode opcode
- Extract source registers
- Extract destination register
- Sign-extend immediate
- Generate ALU control
- Generate memory control
- Generate branch control
- Generate EXIT control
- Identify which source operands are actually used
- Generate scoreboard requests

The decoder explicitly distinguishes:

```text
rs_used
rt_used
```

This prevents the scoreboard from treating unused instruction fields
as real source operands.

---

## 3. EX — Execute

Implemented by:

```text
rtl/top/compute_unit/pipeline/execute_stage.sv
```

Responsibilities:

- Execute ALU operations
- Generate per-lane addresses
- Perform branch comparison
- Determine branch taken/not-taken
- Generate branch target
- Forward control/data information to MEM

The vector ALU contains one `lane_alu` for each configured lane.

---

## 4. MEM — Memory

Implemented by:

```text
rtl/top/compute_unit/pipeline/mem_stage.sv
```

Responsibilities:

- Generate data-memory control signals
- Pass per-lane addresses to data memory
- Pass per-lane store data to data memory
- Capture load data
- Select ALU result or memory result
- Transfer results to WB

---

## 5. WB — Writeback

Implemented by:

```text
rtl/top/compute_unit/pipeline/writeback_stage.sv
```

Responsibilities:

- Write results into the register file
- Clear scoreboard destination registers
- Commit branches
- Commit EXIT instructions
- Restore stalled warps to the appropriate state

---

# Warp Organization

Each warp contains:

```text
Program Counter
Active Lane Mask
Warp State
Register Context
```

The default design contains:

```text
4 warps × 4 lanes
```

Each warp therefore represents four parallel execution lanes.

The warp states are:

```text
READY
STALL
DONE
```

A simplified warp lifecycle is:

```text
             ┌─────────┐
             │  READY  │
             └────┬────┘
                  │
                  │ dependency / branch / EXIT
                  ▼
             ┌─────────┐
             │  STALL  │
             └────┬────┘
                  │
                  │ dependency resolved / branch commit
                  ▼
             ┌─────────┐
             │  READY  │
             └─────────┘

             EXIT
               │
               ▼
           ┌─────────┐
           │  DONE   │
           └─────────┘
```

DONE warps are permanently removed from normal scheduling.

---

# Warp Scheduler

Implemented by:

```text
rtl/top/compute_unit/warp/warp_manager.sv
```

The scheduler uses a simple round-robin policy.

The scheduler:

1. Starts from the current round-robin pointer.
2. Searches for a READY warp.
3. Selects the first eligible warp.
4. Issues the warp.
5. Advances the round-robin pointer.
6. Skips stalled and completed warps.

Conceptually:

```text
Warp 0 → Warp 1 → Warp 2 → Warp 3
   ↑                         │
   └─────────────────────────┘
```

This provides deterministic interleaving between independent warps.

---

# Register File

Implemented by:

```text
rtl/top/compute_unit/register_file/vector_register_file.sv
```

The register file is organized as:

```text
registers[warp][lane][register]
```

Therefore:

```text
4 warps
×
4 lanes
×
32 registers
```

Each register contains:

```text
32 bits
```

The register file provides:

- Per-warp context
- Per-lane storage
- Two asynchronous source reads
- Synchronous writeback
- Per-lane write masking

---

## Special Registers

### R0 — Constant Zero

```text
R0 = 0
```

R0 cannot be written.

The RTL also contains a simulation-time assertion that checks the R0
invariant.

### R1 — Thread ID

R1 is initialized during reset with:

```text
Thread ID = warp_id × WARP_SIZE + lane_id
```

For the default configuration:

| Warp | Lane | R1 |
|---:|---:|---:|
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 0 | 2 | 2 |
| 0 | 3 | 3 |
| 1 | 0 | 4 |
| 1 | 1 | 5 |
| ... | ... | ... |
| 3 | 3 | 15 |

This provides a simple way for programs to distinguish lanes.

---

# SIMD Execution

The vector ALU is implemented by:

```text
rtl/top/compute_unit/alu/vector_alu.sv
```

Each vector instruction is applied to all active lanes.

Internally:

```text
                 Vector ALU
                     │
       ┌─────────────┼─────────────┐
       │             │             │
       ▼             ▼             ▼
    Lane ALU      Lane ALU      Lane ALU ...
    Lane 0        Lane 1        Lane 2
```

The number of lane ALUs follows:

```text
WARP_SIZE
```

Each lane operates on:

```text
32-bit operand A
32-bit operand B
```

or:

```text
32-bit operand A
32-bit immediate
```

Inactive lanes produce zero on the ALU result output.

---

# Supported ALU Operations

The lane ALU implements:

| Operation | Function |
|---|---|
| `ADD` | Addition |
| `SUB` | Subtraction |
| `AND` | Bitwise AND |
| `OR` | Bitwise OR |
| `XOR` | Bitwise XOR |
| `SLT` | Signed Set-Less-Than |

Immediate ALU instructions currently use the ADD operation.

---

# Scoreboard and Hazard Detection

Implemented by:

```text
rtl/top/compute_unit/warp/scoreboard.sv
```

The scoreboard tracks destination registers that contain values still
in flight.

The structure is conceptually:

```text
busy[warp][register]
```

For every instruction entering the decode stage:

1. Determine which source operands are used.
2. Check whether those source registers are busy.
3. If a dependency exists, generate a RAW hazard.
4. Stall that warp.
5. Remember the blocked source operands.
6. Wait until the dependency is resolved.
7. Allow the warp to become READY again.

---

## RAW Hazard Example

Consider:

```text
ADDI R4, R0, 5
ADD  R5, R4, R0
```

The first instruction marks:

```text
R4 = busy
```

When the second instruction is decoded:

```text
R4 = source operand
```

The scoreboard detects:

```text
R4 is busy
```

Therefore:

```text
Warp → STALL
```

After writeback:

```text
R4 = clear
```

and the warp can return to:

```text
READY
```

This provides explicit hardware-level RAW dependency tracking.

---

# Instruction Set

The instruction encoding uses a 32-bit instruction.

Supported instruction classes:

| Instruction | Opcode | Description |
|---|---|---|
| R-type ALU | `000000` | Register-register ALU |
| ALU-I | `000001` | Register-immediate ALU |
| LOAD | `001000` | Load from data memory |
| STORE | `001001` | Store to data memory |
| BEQ | `010000` | Branch if equal |
| BNE | `010001` | Branch if not equal |
| EXIT | `011000` | Terminate current warp |

---

# ALU Function Codes

For R-type ALU instructions:

| Function | Code | Operation |
|---|---|---|
| ADD | `000000` | `A + B` |
| SUB | `000001` | `A - B` |
| AND | `000010` | `A & B` |
| OR | `000011` | `A \| B` |
| XOR | `000100` | `A ^ B` |
| SLT | `000101` | Signed `A < B` |

---

# Instruction Format

The instruction width is:

```text
32 bits
```

The decoder extracts:

```text
31             26 25      21 20      16 15      11 10       6 5        0
┌────────────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│     OPCODE     │    RS    │    RT    │    RD    │          │ FUNCTION │
└────────────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

### Fields

```text
opcode = instruction[31:26]
rs     = instruction[25:21]
rt     = instruction[20:16]
rd     = instruction[15:11]
imm    = instruction[15:0]
func   = instruction[5:0]
```

The exact fields used depend on the instruction type.

---

# Immediate Values

The immediate field is:

```text
16 bits
```

It is sign-extended to the 32-bit lane datapath.

For example:

```text
16'h8001
```

becomes:

```text
32'hFFFF8001
```

This allows signed immediate arithmetic.

---

# Memory System

The project uses separate instruction and data memories.

```text
Instruction Memory
        │
        ▼
   Instruction
        │
        ▼
    Compute Unit
        │
        ▼
    Data Memory
```

---

## Instruction Memory

Implemented by:

```text
rtl/top/memory/instruction_memory.sv
```

Configuration:

```text
Depth  = 256 words
Width  = 32 bits
```

The memory is initialized from:

```text
program.mem
```

The PC is treated as a byte address and the lower two bits are ignored
when selecting the instruction word.

---

## Data Memory

Implemented by:

```text
rtl/top/memory/data_memory.sv
```

Configuration:

```text
Depth  = 1024 words
Width  = 32 bits
```

The memory is initialized from:

```text
data.mem
```

Each lane has an independent:

```text
Address
Store Data
Load Data
```

Memory operations are controlled by the warp's active-lane mask.

---

## Memory Instructions

### LOAD

The effective address is:

```text
address = rs + sign_extended_immediate
```

The loaded value is written into the destination register of each active
lane.

### STORE

The effective address is:

```text
address = rs + sign_extended_immediate
```

The value from the second source register is stored for each active lane.

---

# Branch Handling

The supported branch instructions are:

```text
BEQ
BNE
```

Branch comparison is performed across the active lanes.

For an active warp:

### BEQ

The branch is taken when all active lanes satisfy:

```text
rs == rt
```

### BNE

The branch is taken when all active lanes satisfy:

```text
rs != rt
```

Inactive lanes do not participate in the comparison.

---

## Branch Target

The branch target is calculated using:

```text
branch_target = branch_instruction_PC
                + sign_extended_immediate
```

The immediate is **not shifted left by two**.

This is an intentional property of the V1 instruction format.

---

# EXIT Handling

`EXIT` is used to terminate a warp.

When an EXIT instruction reaches writeback:

```text
warp_state[warp_id] = DONE
```

The completed warp is removed from future scheduling.

This allows different warps to finish independently.

---

# Active Lane Mask

Every warp carries an active-lane mask:

```text
[WARP_SIZE-1:0]
```

For the default configuration:

```text
4 bits
```

Reset initializes the mask to:

```text
1111
```

meaning all lanes are active.

The mask is propagated through the pipeline:

```text
Warp Manager
      │
      ▼
     IFU
      │
      ▼
     ID
      │
      ▼
     EX
      │
      ▼
    MEM/WB
```

The mask controls:

- ALU result generation
- Register writeback
- Store operations
- Branch comparison participation

This provides the basic lane-masking mechanism required for SIMD/SIMT
execution.

---

# Top-Level Module

The top-level module is:

```text
rtl/top/top.sv
```

It instantiates three major blocks:

```text
top
├── instruction_memory
├── compute_unit
└── data_memory
```

The top-level interface is intentionally small:

```systemverilog
input logic clk
input logic rst
```

All instruction and data memory communication occurs internally.

---

# Compute Unit

The main processor block is:

```text
rtl/top/compute_unit/compute_unit.sv
```

The compute unit connects:

```text
                    ┌─────────────────┐
                    │  warp_manager   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │      IFU        │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ decode_unit     │
                    └───────┬─┬───────┘
                            │ │
                ┌───────────┘ └────────────┐
                ▼                          ▼
       ┌─────────────────┐       ┌─────────────────┐
       │ vector_register │       │   scoreboard    │
       │      file       │       │                 │
       └────────┬────────┘       └─────────────────┘
                │
                ▼
       ┌─────────────────┐
       │ execute_stage   │
       └────────┬────────┘
                │
                ▼
       ┌─────────────────┐
       │    mem_stage    │
       └────────┬────────┘
                │
                ▼
       ┌─────────────────┐
       │ writeback_stage │
       └─────────────────┘
```

---

# RTL Repository Structure

```text
custom-simd-gpu/
│
├── img/
│   └── simt_gpu_rtl_architecture (1).svg
│
├── rtl/
│   └── top/
│       │
│       ├── top.sv
│       ├── cu_defs.svh
│       │
│       ├── memory/
│       │   ├── instruction_memory.sv
│       │   └── data_memory.sv
│       │
│       └── compute_unit/
│           │
│           ├── compute_unit.sv
│           │
│           ├── alu/
│           │   ├── vector_alu.sv
│           │   └── lane_alu.sv
│           │
│           ├── pipeline/
│           │   ├── IFU.sv
│           │   ├── decode_unit.sv
│           │   ├── execute_stage.sv
│           │   ├── mem_stage.sv
│           │   └── writeback_stage.sv
│           │
│           ├── register_file/
│           │   └── vector_register_file.sv
│           │
│           └── warp/
│               ├── warp_manager.sv
│               └── scoreboard.sv
│
├── program.mem
├── data.mem
└── README.md
```

---

# Module Responsibilities

| Module | Responsibility |
|---|---|
| `top.sv` | Top-level GPU integration |
| `compute_unit.sv` | Main pipeline and control connectivity |
| `cu_defs.svh` | Architecture parameters and ISA definitions |
| `warp_manager.sv` | Warp scheduling and PC/state management |
| `scoreboard.sv` | RAW dependency tracking |
| `IFU.sv` | Instruction fetch and pipeline alignment |
| `decode_unit.sv` | Instruction decoding and control generation |
| `vector_register_file.sv` | Per-warp/per-lane register storage |
| `vector_alu.sv` | Parallel lane execution |
| `lane_alu.sv` | Single-lane 32-bit ALU |
| `execute_stage.sv` | ALU, address and branch execution |
| `mem_stage.sv` | Memory-stage processing |
| `writeback_stage.sv` | Register, scoreboard and control commit |
| `instruction_memory.sv` | Program storage |
| `data_memory.sv` | Data storage |

---

# Configuration Parameters

The main configuration is centralized in:

```text
rtl/top/cu_defs.svh
```

The default values are:

```systemverilog
`define WARP_SIZE     4
`define NUM_WARPS     4
`define NUM_VREGS     32
`define LANE_WIDTH    32
`define INST_WIDTH    32
`define PC_WIDTH      16
`define IMM_WIDTH     16
`define IMEM_DEPTH    256
`define DMEM_DEPTH    1024
```

For example, increasing:

```systemverilog
`define WARP_SIZE 8
```

changes the number of lanes handled by the vector datapath and related
lane arrays.

Similarly:

```systemverilog
`define NUM_WARPS 8
```

increases the number of independently scheduled warps.

The associated ID-width definitions must remain consistent with the
selected configuration.

---

# Memory Initialization

Instruction memory loads:

```text
program.mem
```

Data memory loads:

```text
data.mem
```

The memory files use hexadecimal values.

### `program.mem`

The current V1 repository contains a small example instruction image:

```text
04020001
04020002
00401800
04640007
24040000
20050000
00A43000
40C60004
60000000
```

### `data.mem`

The current data image contains initialized zero words:

```text
00000000
00000000
00000000
00000000
```

These files can be replaced with different program and data images when
experimenting with the architecture.

---

# Example Program Flow

The supplied instruction memory image demonstrates the custom 32-bit
instruction encoding and includes ALU, immediate, memory/control-flow
operations followed by `EXIT`.

The final instruction:

```text
60000000
```

corresponds to:

```text
EXIT
```

The exact program behavior depends on the configured instruction
encoding and the state of each warp/lane.

---

# Design Decisions

The V1 architecture intentionally favors clarity over GPU complexity.

## No Per-Warp Instruction Buffers

Instructions are fetched through the common instruction-fetch path using
the currently selected warp.

There is no dedicated instruction queue for every warp.

---

## One Scheduler

The architecture contains one simple round-robin warp scheduler.

It selects one READY warp at a time.

---

## One Vector Execution Path

The vector ALU represents the parallel execution datapath.

Each lane has its own 32-bit ALU.

---

## No Register Renaming

Registers are architecturally visible and dependencies are handled using
the scoreboard.

---

## No Out-of-Order Execution

Instructions execute through an in-order five-stage pipeline.

---

## No Cache Hierarchy

The V1 design directly uses instruction and data memories.

There are no:

- Instruction caches
- Data caches
- Shared-memory banks
- Cache replacement policies
- Cache coherence mechanisms

---

## No Complex Memory Coalescing

Each lane generates its own memory address.

The memory system does not implement a sophisticated GPU memory
coalescer.

---

## No Divergence Stack

Version 1 does not implement hardware divergence/reconvergence using a
stack.

The active-lane mask infrastructure is present, but advanced divergent
control-flow handling is outside the V1 scope.

---

# Current Limitations

V1 intentionally does not include several features found in production
GPUs.

### Not implemented

- Dynamic branch divergence
- Reconvergence stack
- Per-warp instruction queues
- Instruction cache
- Data cache
- Shared-memory banks
- Bank-conflict handling
- Memory coalescing
- Multiple execution units
- Multiple schedulers
- Register renaming
- Out-of-order execution
- Operand collectors
- Warp-level synchronization primitives
- Floating-point execution units
- Graphics pipeline
- CUDA/OpenCL compiler frontend

The goal of V1 is not to reproduce a commercial GPU.

The goal is to provide a small and understandable RTL implementation
that demonstrates the fundamental mechanisms of parallel GPU-style
execution.

---

# Verification and Development Checks

During development, the architecture was exercised with focused
hardware-level checks covering:

- Immediate sign extension
- Register-file read/write behavior
- R0 zero invariant
- RAW dependency detection
- Multi-warp scheduling
- Active-lane masking
- Branch/EXIT control flow
- End-to-end program execution
- RTL connectivity
- Parameterized warp configurations

The development verification also included RAW dependency experiments
with different numbers of active warps to verify that the scoreboard
properly stalls a dependent warp when scheduling cannot hide the
dependency.

The repository snapshot itself is intentionally lightweight and contains
the RTL implementation and memory images rather than a complete
simulation-framework directory.

---

# Learning Objectives

This project is intended to provide hands-on understanding of:

### Computer Architecture

- Instruction pipelines
- Pipeline stages
- Program counters
- Register files
- Data hazards
- RAW dependency handling
- Control hazards

### GPU Architecture

- Warp-based execution
- SIMD lane execution
- Active-lane masks
- Warp scheduling
- Per-warp state
- GPU-style latency hiding

### RTL Design

- SystemVerilog modules
- Module hierarchy
- Parameterized hardware
- Combinational logic
- Sequential logic
- Pipeline registers
- Multi-dimensional register arrays
- Memory modeling
- Hardware assertions

### Microarchitecture

- Scoreboards
- Dependency tracking
- Branch handling
- Pipeline control
- Writeback commit
- Memory-stage integration

---

# Getting Started

## 1. Clone the repository

```bash
git clone https://github.com/Mitanshu-0/custom-simd-gpu.git
cd custom-simd-gpu
```

## 2. Inspect the architecture

Start with:

```text
rtl/top/cu_defs.svh
```

Then study the modules in this order:

```text
1. lane_alu.sv
2. vector_alu.sv
3. vector_register_file.sv
4. decode_unit.sv
5. execute_stage.sv
6. data_memory.sv
7. mem_stage.sv
8. writeback_stage.sv
9. scoreboard.sv
10. warp_manager.sv
11. IFU.sv
12. compute_unit.sv
13. top.sv
```

This order follows the data/control flow from the smallest execution
unit to the complete processor.

---

# Recommended Study Flow

The architecture can be understood through the following execution path:

```text
Instruction Memory
        │
        ▼
   Warp Manager
        │
        ▼
       IFU
        │
        ▼
     Decode
        │
        ├──────────────► Scoreboard
        │
        ▼
 Register File
        │
        ▼
   Vector ALU
        │
        ▼
     Execute
        │
        ▼
      Memory
        │
        ▼
    Writeback
        │
        ├──────────────► Register File
        ├──────────────► Scoreboard
        ├──────────────► Warp Manager
        └──────────────► Branch / EXIT control
```

---

# Version 1 Scope

The current release is:

```text
Custom SIMD GPU — RTL V1
```

The primary objective of V1 is to establish a clean architectural
foundation containing:

```text
✓ Warp management
✓ Round-robin scheduling
✓ SIMD lane execution
✓ Per-warp register storage
✓ 5-stage pipeline
✓ RAW scoreboard
✓ Instruction memory
✓ Data memory
✓ Basic branches
✓ EXIT handling
✓ Active-lane masking
```

Advanced GPU features are intentionally deferred to future versions.

---

# Future Work

Possible future architectural extensions include:

- Branch divergence handling
- Reconvergence mechanism
- Per-warp instruction buffering
- More complete control-flow support
- Additional ALU instructions
- Multiply/divide instructions
- Floating-point unit
- Shared memory
- Memory coalescing
- Cache hierarchy
- Multiple execution units
- Multiple warp schedulers
- Warp synchronization
- Performance counters
- More extensive simulation infrastructure
- FPGA implementation
- Automated regression testing

---

# Project Philosophy

The design follows a simple principle:

> **Keep the hardware visible and understandable.**

Instead of hiding GPU behavior behind a large framework, this project
implements the fundamental mechanisms directly in SystemVerilog.

The result is a compact architecture where the relationship between:

```text
Warp
  ↓
Scheduler
  ↓
Instruction
  ↓
Register File
  ↓
SIMD Lanes
  ↓
Memory
  ↓
Writeback
```

can be studied directly from the RTL.

---

# License

This repository currently does not include a separate license file.

If this project is intended for public open-source reuse, add an
appropriate license before distributing it under open-source terms.

---

# Author

**Mitanshu Dhameliya**

GitHub:

**Mitanshu-0**

Repository:

`custom-simd-gpu`

---

## Project Summary

```text
Custom SIMD GPU
│
├── 4 Warps
├── 4 Lanes / Warp
├── 32-bit Lane Datapath
├── 32 Registers / Lane
├── 32-bit Instructions
├── 16-bit Program Counter
│
├── Round-Robin Warp Scheduler
├── RAW Scoreboard
├── Active Lane Mask
│
├── IF → ID → EX → MEM → WB
│
├── Parallel Lane ALUs
├── Instruction Memory
├── Data Memory
│
├── BEQ / BNE
└── EXIT
```

**Version 1 — A compact RTL foundation for studying SIMD/SIMT GPU
microarchitecture.**
