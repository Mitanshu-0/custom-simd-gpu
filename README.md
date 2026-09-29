# Custom SIMD GPU

### A Parameterized Parallel GPU-Style Processor Implemented in SystemVerilog RTL

<p align="center">

![SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue)
![Architecture](https://img.shields.io/badge/Architecture-SIMD%2FSIMT-orange)
![Pipeline](https://img.shields.io/badge/Pipeline-5--Stage-green)
![Lanes](https://img.shields.io/badge/Lanes-4-purple)
![Warps](https://img.shields.io/badge/Warps-4-red)
![Datapath](https://img.shields.io/badge/Datapath-32--bit-informational)
![Status](https://img.shields.io/badge/RTL-Implemented-success)

</p>

A compact, parameterized GPU-style processor implemented entirely in
SystemVerilog RTL.

The architecture combines a **warp-based execution model** with a
**parallel SIMD datapath**, allowing the same instruction to operate on
multiple 32-bit lanes belonging to the selected warp.

The processor integrates:

- Multi-warp execution
- Parallel SIMD lanes
- Round-robin warp scheduling
- Per-warp program counters
- Per-warp active-lane masks
- Per-warp, per-lane register storage
- A five-stage in-order pipeline
- Scoreboard-based RAW dependency detection
- Parallel integer ALU execution
- Per-lane memory operations
- Conditional branch instructions
- Explicit warp termination

The implementation is intentionally compact so that the complete
instruction flow—from fetch and decode through execution, memory access,
writeback, and warp management—can be studied directly from the RTL.

---

# Table of Contents

- [Project Overview](#project-overview)
- [Architecture at a Glance](#architecture-at-a-glance)
- [System Architecture](#system-architecture)
- [Architecture Diagram](#architecture-diagram)
- [Processor Configuration](#processor-configuration)
- [Execution Model](#execution-model)
- [Pipeline Architecture](#pipeline-architecture)
- [Warp Management](#warp-management)
- [Round-Robin Scheduling](#round-robin-scheduling)
- [Register File](#register-file)
- [SIMD Execution Unit](#simd-execution-unit)
- [Active Lane Masking](#active-lane-masking)
- [Scoreboard and RAW Hazard Detection](#scoreboard-and-raw-hazard-detection)
- [Instruction Set Architecture](#instruction-set-architecture)
- [Instruction Encoding](#instruction-encoding)
- [Branch Architecture](#branch-architecture)
- [Memory System](#memory-system)
- [Top-Level Connectivity](#top-level-connectivity)
- [RTL Module Hierarchy](#rtl-module-hierarchy)
- [Repository Structure](#repository-structure)
- [Program and Data Images](#program-and-data-images)
- [Instruction Execution Flow](#instruction-execution-flow)
- [Architectural Scope](#architectural-scope)
- [Current Capabilities](#current-capabilities)
- [Current Limitations](#current-limitations)
- [Future Extensions](#future-extensions)
- [Learning and Research Focus](#learning-and-research-focus)
- [Getting Started](#getting-started)
- [Author](#author)

---

# Project Overview

GPUs obtain high throughput by executing the same operation across many
parallel processing elements.

This project explores that concept at the RTL level by implementing a
small GPU-style processor with multiple independently managed warps and
multiple execution lanes per warp.

The architecture separates **warp-level control** from **lane-level
data processing**.

At the control level, each warp maintains its own:

```text
Program Counter
Active Lane Mask
Execution State
Register Context
```

At the datapath level, an instruction selected for a warp is executed
across its active lanes through a parallel collection of 32-bit ALUs.

The resulting architecture can be viewed as:

```text
                    GPU-STYLE PROCESSOR
                           │
                           ▼
                  ┌──────────────────┐
                  │  Warp Management │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │ Instruction Fetch│
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │ Instruction Decode│
                  └────────┬─────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
         Register File          Scoreboard
                │                     │
                └──────────┬──────────┘
                           ▼
                  ┌──────────────────┐
                  │  SIMD Execution  │
                  │  Multiple ALUs   │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │ Memory / Control │
                  └────────┬─────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │    Writeback     │
                  └──────────────────┘
```

---

# Architecture at a Glance

| Feature | Implementation |
|---|---|
| Hardware Description Language | SystemVerilog |
| Execution Model | Warp-based SIMD/SIMT-style |
| Number of Warps | 4 |
| Lanes per Warp | 4 |
| Total Logical Lanes | 16 |
| Lane Width | 32 bits |
| Instruction Width | 32 bits |
| Program Counter | 16 bits |
| Registers per Lane | 32 |
| Pipeline | IF → ID → EX → MEM → WB |
| Warp Scheduler | Round-robin |
| Hazard Handling | Per-warp scoreboard |
| Register Storage | `[warp][lane][register]` |
| Instruction Memory | 256 × 32-bit |
| Data Memory | 1024 × 32-bit |
| Branch Instructions | BEQ, BNE |
| Termination | EXIT |
| ALU Operations | ADD, SUB, AND, OR, XOR, SLT |

---

# System Architecture

The processor is organized into three primary blocks:

```text
                     ┌───────────────────────┐
                     │         TOP           │
                     │        top.sv         │
                     └───────────┬───────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
     ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
     │ Instruction    │  │  Compute Unit  │  │ Data Memory    │
     │ Memory         │  │                │  │                │
     │                │  │                │  │                │
     │ program.mem    │  │ Warp Manager   │  │ data.mem       │
     └────────────────┘  │ IFU            │  └────────────────┘
                         │ Decode         │
                         │ Execute       │
                         │ Memory         │
                         │ Writeback      │
                         │ Register File   │
                         │ Scoreboard      │
                         └────────────────┘
```

The `compute_unit` is the central processing block.

It connects the warp-management logic, pipeline stages, register file,
SIMD execution unit, scoreboard, and external memory interfaces.

---

# Architecture Diagram

The repository contains a detailed architecture diagram showing the
major RTL blocks and their connectivity.

![Custom SIMD GPU Architecture](img/simt_gpu_rtl_architecture%20(1).svg)

The diagram can be used together with the RTL hierarchy to follow the
complete datapath and control flow.

---

# Processor Configuration

The architectural parameters are defined in:

```text
rtl/top/cu_defs.svh
```

The current configuration is:

```text
WARP_SIZE       = 4
NUM_WARPS       = 4
NUM_VREGS       = 32
LANE_WIDTH      = 32
INST_WIDTH      = 32
PC_WIDTH        = 16
IMM_WIDTH       = 16
IMEM_DEPTH      = 256
DMEM_DEPTH      = 1024
```

## Parallelism

The processor contains:

```text
4 warps
×
4 lanes per warp
=
16 logical execution lanes
```

Each lane operates on a 32-bit value.

The lane count is controlled through:

```systemverilog
`WARP_SIZE
```

and the number of resident warps through:

```systemverilog
`NUM_WARPS
```

This allows the architecture to be explored with different hardware
configurations.

---

# Execution Model

The processor uses a warp-oriented execution model.

Each warp maintains its own program counter and execution state.

A selected warp supplies:

```text
Warp ID
Program Counter
Active Lane Mask
```

to the instruction-fetch path.

The instruction is then decoded and executed across the active lanes of
that warp.

Conceptually:

```text
                Warp 0
              ┌─────────┐
              │ Lane 0  │
              │ Lane 1  │
              │ Lane 2  │
              │ Lane 3  │
              └─────────┘

                Warp 1
              ┌─────────┐
              │ Lane 0  │
              │ Lane 1  │
              │ Lane 2  │
              │ Lane 3  │
              └─────────┘

                Warp 2
              ┌─────────┐
              │ Lane 0  │
              │ Lane 1  │
              │ Lane 2  │
              │ Lane 3  │
              └─────────┘

                Warp 3
              ┌─────────┐
              │ Lane 0  │
              │ Lane 1  │
              │ Lane 2  │
              │ Lane 3  │
              └─────────┘
```

The scheduler selects among these warps while the SIMD datapath performs
the lane-level computation.

---

# Pipeline Architecture

The processor uses a five-stage in-order pipeline:

```text
┌────┐   ┌────┐   ┌────┐   ┌─────┐   ┌────┐
│ IF │ → │ ID │ → │ EX │ → │ MEM │ → │ WB │
└────┘   └────┘   └────┘   └─────┘   └────┘
```

## IF — Instruction Fetch

Implemented by:

```text
rtl/top/compute_unit/pipeline/IFU.sv
```

The IF stage:

- Receives the selected warp
- Uses its program counter
- Requests an instruction
- Carries the warp ID through the pipeline
- Carries the active-lane mask
- Preserves the instruction's originating PC

Instruction fetch is connected directly to:

```text
instruction_memory.sv
```

---

## ID — Instruction Decode

Implemented by:

```text
rtl/top/compute_unit/pipeline/decode_unit.sv
```

The decode stage generates the control information required by later
pipeline stages.

It identifies:

- Opcode
- Source registers
- Destination register
- Immediate value
- ALU operation
- Immediate-operand usage
- Register-write enable
- Memory-read enable
- Memory-write enable
- Branch operation
- EXIT operation
- Source-register usage for scoreboard checking

The decoder also provides the information required to distinguish actual
source operands from instruction fields that are not used by a particular
instruction.

---

## EX — Execute

Implemented by:

```text
rtl/top/compute_unit/pipeline/execute_stage.sv
```

The execute stage performs:

- Integer ALU operations
- Immediate arithmetic
- Branch comparison
- Branch target generation
- Effective-address generation

The SIMD ALU operates on the lane operands supplied by the register
file.

---

## MEM — Memory

Implemented by:

```text
rtl/top/compute_unit/pipeline/mem_stage.sv
```

The memory stage:

- Carries ALU results
- Carries lane addresses
- Carries store data
- Generates memory-operation controls
- Selects load data for writeback
- Carries branch and EXIT information toward commit

---

## WB — Writeback

Implemented by:

```text
rtl/top/compute_unit/pipeline/writeback_stage.sv
```

The writeback stage is responsible for committing completed operations.

It generates:

- Register-file write information
- Lane write mask
- Scoreboard-clear information
- Branch commit information
- EXIT commit information

This stage connects the execution pipeline back to the architectural
state.

---

# Warp Management

Warp control is implemented by:

```text
rtl/top/compute_unit/warp/warp_manager.sv
```

Each warp maintains:

```text
Program Counter
Active Lane Mask
Execution State
```

The supported warp states are:

```text
READY
STALL
DONE
```

## Warp Lifecycle

```text
             ┌─────────┐
             │  READY  │
             └────┬────┘
                  │
                  │ instruction issued
                  ▼
             ┌─────────┐
             │  STALL  │
             └────┬────┘
                  │
                  │ dependency resolved
                  │ / branch committed
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

A completed warp is no longer selected by the scheduler.

---

# Round-Robin Scheduling

Warp selection is performed by the `warp_manager` using a round-robin
policy.

The scheduler maintains:

```text
round_robin_pointer
```

and searches for an eligible READY warp.

For the default four-warp configuration:

```text
Warp 0 → Warp 1 → Warp 2 → Warp 3 → Warp 0 → ...
```

Stalled and completed warps are skipped.

This provides deterministic warp interleaving and allows independent
warps to make progress while another warp is waiting on a dependency.

---

# Register File

The register file is implemented by:

```text
rtl/top/compute_unit/register_file/vector_register_file.sv
```

The architectural organization is:

```text
registers[warp][lane][register]
```

Therefore the default storage contains:

```text
4 warps
×
4 lanes
×
32 registers
×
32 bits
```

Each lane has its own 32-bit register context.

---

## Register Access

Two source operands can be read for the selected warp.

Register writes occur synchronously and are controlled by a lane-level
write mask.

The register file therefore supports:

```text
Warp selection
      │
      ▼
Source Register 1 ──► Lane 0
                    ► Lane 1
                    ► Lane 2
                    ► Lane 3

Source Register 2 ──► Lane 0
                    ► Lane 1
                    ► Lane 2
                    ► Lane 3
```

---

# Special Registers

## R0 — Constant Zero

Register `R0` is architecturally fixed to zero.

Reads from R0 return:

```text
0
```

Writes to R0 are ignored.

The RTL contains an assertion that checks the R0 invariant during
simulation.

---

## R1 — Thread ID

Register `R1` is initialized during reset with a unique logical thread
identifier.

For the default configuration:

```text
Warp 0:  0  1  2  3
Warp 1:  4  5  6  7
Warp 2:  8  9 10 11
Warp 3: 12 13 14 15
```

Therefore each lane can identify its logical execution context through
R1 without requiring software initialization.

---

# SIMD Execution Unit

The vector execution unit is implemented by:

```text
rtl/top/compute_unit/alu/vector_alu.sv
```

and:

```text
rtl/top/compute_unit/alu/lane_alu.sv
```

The vector ALU contains one lane ALU for each configured lane.

For the default configuration:

```text
             Vector ALU
                 │
       ┌─────────┼─────────┐
       │         │         │
       ▼         ▼         ▼
    Lane ALU  Lane ALU  Lane ALU ...
       0         1         2
```

Each lane independently receives:

```text
Operand A
Operand B
Immediate
ALU operation
```

The resulting values are generated independently for all active lanes.

---

# Supported ALU Operations

| Operation | Function |
|---|---|
| ADD | `A + B` |
| SUB | `A - B` |
| AND | `A & B` |
| OR | `A \| B` |
| XOR | `A ^ B` |
| SLT | Signed `A < B` |

The ALU supports both register-register and immediate-based operations.

For immediate instructions, the immediate value replaces the second
register operand.

---

# Active Lane Masking

Each warp maintains an active-lane mask:

```text
[WARP_SIZE-1:0]
```

For four lanes:

```text
1111
```

represents all lanes active.

The mask is carried through the execution pipeline and controls
lane-level activity.

The active mask is used by:

- Vector ALU
- Register writeback
- Store operations
- Branch comparisons

An inactive lane does not contribute an ALU result or a memory store.

This provides the basic lane-predication mechanism required by the
parallel execution model.

---

# Scoreboard and RAW Hazard Detection

Dependency tracking is implemented by:

```text
rtl/top/compute_unit/warp/scoreboard.sv
```

The scoreboard maintains a per-warp busy state for destination
registers.

Conceptually:

```text
busy[warp][register]
```

When an instruction produces a register result, the corresponding
register is marked busy.

When the result reaches writeback, the entry is cleared.

---

## RAW Dependency Detection

Consider:

```text
ADDI R4, R0, 5
ADD  R5, R4, R0
```

The first instruction creates:

```text
R4 → BUSY
```

When the second instruction reaches dependency checking:

```text
R4 → source operand
R4 → BUSY
```

The scoreboard generates a dependency hazard.

The corresponding warp is stalled until the dependency is resolved.

---

## Source Operand Usage

The decoder explicitly identifies whether the source fields are used:

```text
rs_used
rt_used
```

This prevents unused instruction fields from being interpreted as
dependencies.

For example, an immediate instruction can use:

```text
rs
```

while the second register field represents the destination rather than
a source operand.

---

# Instruction Set Architecture

The processor uses a custom fixed-width:

```text
32-bit instruction format
```

The supported instruction classes are:

| Instruction | Opcode | Description |
|---|---|---|
| R-type ALU | `000000` | Register-register ALU |
| ALU-I | `000001` | Register-immediate ALU |
| LOAD | `001000` | Load from data memory |
| STORE | `001001` | Store to data memory |
| BEQ | `010000` | Branch if equal |
| BNE | `010001` | Branch if not equal |
| EXIT | `011000` | Complete the current warp |

---

# ALU Function Encoding

R-type ALU instructions use the following function field:

| Function | Code |
|---|---|
| ADD | `000000` |
| SUB | `000001` |
| AND | `000010` |
| OR | `000011` |
| XOR | `000100` |
| SLT | `000101` |

---

# Instruction Encoding

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

Primary fields:

```text
opcode = instruction[31:26]
rs     = instruction[25:21]
rt     = instruction[20:16]
rd     = instruction[15:11]
imm    = instruction[15:0]
func   = instruction[5:0]
```

The fields used depend on the instruction class.

---

# Immediate Operations

The immediate field is:

```text
16 bits
```

and is sign-extended to the lane datapath width.

For example:

```text
16'h8001
```

becomes:

```text
32'hFFFF8001
```

before being used by the 32-bit ALU.

This allows signed immediate arithmetic and branch offsets.

---

# Branch Architecture

The processor supports:

```text
BEQ
BNE
```

Branch information is generated in the execute stage and committed
through the writeback stage.

The architecture tracks:

```text
Branch instruction
Branch condition
Branch target
Warp ID
```

so that the correct warp program counter can be updated.

---

## Branch Target

The branch target is calculated as:

```text
branch_target =
    branch_instruction_PC
    + sign_extended_immediate
```

The immediate is not shifted left by two.

This is consistent with the current RTL branch-target implementation.

---

# Memory System

The processor uses separate instruction and data memories.

```text
                ┌──────────────────┐
                │ Instruction      │
                │ Memory           │
                └────────┬─────────┘
                         │
                         ▼
                     Compute
                       Unit
                         │
                         ▼
                ┌──────────────────┐
                │ Data Memory      │
                └──────────────────┘
```

---

# Instruction Memory

Implemented by:

```text
rtl/top/memory/instruction_memory.sv
```

Configuration:

```text
256 words
32 bits per word
```

The program image is loaded from:

```text
program.mem
```

Instruction addresses are byte-oriented, and the memory indexes the
instruction array using the PC bits:

```text
PC[PC_WIDTH-1:2]
```

This corresponds to 32-bit / 4-byte instructions.

---

# Data Memory

Implemented by:

```text
rtl/top/memory/data_memory.sv
```

Configuration:

```text
1024 words
32 bits per word
```

The memory is initialized from:

```text
data.mem
```

Each lane provides its own:

```text
Memory Address
Store Data
Load Data
```

The active-lane mask controls which lanes participate in a store.

Data reads are modeled combinationally when the read-enable signal is
active, while memory writes occur synchronously on the clock edge.

---

# LOAD

A LOAD instruction generates a per-lane effective address using:

```text
base register + sign-extended immediate
```

The resulting memory value is returned independently for each lane.

---

# STORE

A STORE instruction generates a per-lane address and store-data value.

Only lanes enabled by the active-lane mask perform the memory write.

Conceptually:

```text
Lane 0 ──► Address 0 ──► Data 0
Lane 1 ──► Address 1 ──► Data 1
Lane 2 ──► Address 2 ──► Data 2
Lane 3 ──► Address 3 ──► Data 3
```

---

# EXIT and Warp Completion

The `EXIT` instruction terminates the currently executing warp.

The EXIT instruction is carried through the pipeline and committed in
writeback.

At commit:

```text
warp_state[warp_id] = DONE
```

The scheduler then excludes that warp from future instruction issue.

This allows different warps to complete independently.

---

# Top-Level Connectivity

The top-level module is:

```text
rtl/top/top.sv
```

It instantiates:

```text
top
├── instruction_memory
├── compute_unit
└── data_memory
```

The main interface is:

```systemverilog
input logic clk
input logic rst
```

The compute unit connects to instruction memory through:

```text
instruction_memory_address
instruction_memory_data
```

and to data memory through:

```text
memory_read_enable
memory_write_enable
memory_active_lane_mask
memory_address[]
memory_store_data[]
memory_load_data[]
```

This keeps the external processor interface compact while the internal
compute unit manages the complete execution pipeline.

---

# RTL Module Hierarchy

```text
top
│
├── instruction_memory
│
├── compute_unit
│   │
│   ├── warp_manager
│   │
│   ├── IFU
│   │
│   ├── decode_unit
│   │
│   ├── vector_register_file
│   │
│   ├── scoreboard
│   │
│   ├── execute_stage
│   │   └── vector_alu
│   │       └── lane_alu × WARP_SIZE
│   │
│   ├── mem_stage
│   │
│   └── writeback_stage
│
└── data_memory
```

---

# RTL Module Responsibilities

| Module | Responsibility |
|---|---|
| `top.sv` | Complete processor integration |
| `cu_defs.svh` | Parameters, states, opcodes and ALU functions |
| `compute_unit.sv` | Main control and pipeline integration |
| `warp_manager.sv` | Warp state, PC management and scheduling |
| `scoreboard.sv` | Per-warp register dependency tracking |
| `IFU.sv` | Instruction fetch |
| `decode_unit.sv` | Instruction decoding and control generation |
| `execute_stage.sv` | ALU execution, address generation and branch processing |
| `mem_stage.sv` | Memory-stage pipeline processing |
| `writeback_stage.sv` | Register writeback and architectural commit |
| `vector_register_file.sv` | Per-warp/per-lane register storage |
| `vector_alu.sv` | Parallel lane execution |
| `lane_alu.sv` | Single-lane integer ALU |
| `instruction_memory.sv` | Instruction storage |
| `data_memory.sv` | Data storage and lane-level memory access |

---

# Repository Structure

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

# Program and Data Images

The processor loads its initial memory contents from external hexadecimal
files.

## Program Image

```text
program.mem
```

The current repository contains:

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

The image provides a compact instruction sequence for exercising the
custom instruction encoding and processor datapath.

---

## Data Image

```text
data.mem
```

The current data image contains initialized zero values:

```text
00000000
00000000
00000000
00000000
```

Both memory images can be replaced when experimenting with new programs.

---

# Instruction Execution Flow

A typical instruction follows this path:

```text
             ┌──────────────────┐
             │  Warp Manager    │
             └────────┬─────────┘
                      │
                      ▼
             ┌──────────────────┐
             │       IF         │
             │     Fetch       │
             └────────┬─────────┘
                      │
                      ▼
             ┌──────────────────┐
             │       ID         │
             │     Decode      │
             └────────┬─────────┘
                      │
             ┌────────┴────────┐
             │                 │
             ▼                 ▼
        Register File      Scoreboard
             │                 │
             └────────┬────────┘
                      ▼
             ┌──────────────────┐
             │       EX         │
             │  SIMD Execution  │
             └────────┬─────────┘
                      │
                      ▼
             ┌──────────────────┐
             │      MEM         │
             │ Memory Access    │
             └────────┬─────────┘
                      │
                      ▼
             ┌──────────────────┐
             │       WB         │
             │ Write / Commit   │
             └────────┬─────────┘
                      │
             ┌────────┴─────────┐
             ▼                  ▼
       Register File       Warp Manager
       / Scoreboard        / Branch / EXIT
```

This flow makes the relationship between data movement and control
movement explicit at RTL level.

---

# Architectural Scope

The processor focuses on the core mechanisms required to demonstrate
parallel GPU-style execution:

```text
Multi-Warp Control
        +
SIMD Lane Execution
        +
Pipeline Processing
        +
Register Dependency Tracking
        +
Per-Lane Memory Access
```

The architecture does not attempt to reproduce the complete complexity
of a commercial GPU.

Instead, it provides a compact hardware model where the major execution
mechanisms remain visible and directly traceable in SystemVerilog.

---

# Current Capabilities

The current RTL implements:

- Four independently managed warps
- Four execution lanes per warp
- 32-bit lane datapath
- 32-bit instruction encoding
- Five-stage in-order pipeline
- Round-robin warp scheduling
- Per-warp program counters
- Per-warp active-lane masks
- Per-warp/per-lane register storage
- R0 constant-zero behavior
- R1 thread-ID initialization
- Parallel integer ALU execution
- ADD / SUB / AND / OR / XOR / SLT
- Immediate ALU operations
- LOAD operations
- STORE operations
- BEQ branch operation
- BNE branch operation
- EXIT-based warp completion
- Per-warp RAW scoreboard
- Lane-level memory masking
- Separate instruction and data memories
- External program and data initialization files

---

# Current Limitations

The current architecture intentionally remains compact and does not
implement several advanced GPU mechanisms.

The following features are outside the current implementation:

- Dynamic branch divergence
- Hardware reconvergence stack
- Per-warp instruction queues
- Instruction cache
- Data cache
- Cache hierarchy
- Shared-memory bank architecture
- Bank-conflict handling
- Complex memory coalescing
- Multiple warp schedulers
- Multiple independent execution units
- Register renaming
- Out-of-order execution
- Floating-point execution units
- Vector floating-point arithmetic
- Warp synchronization primitives
- Graphics-specific processing stages
- CUDA/OpenCL compiler support

These features can be introduced incrementally without changing the
fundamental organization of the existing pipeline.

---

# Future Extensions

The architecture provides a foundation for extending the processor into
a more capable GPU-style core.

Potential extensions include:

### Control Flow

- Per-lane branch decisions
- Divergence detection
- Reconvergence stack
- Nested divergent branches
- Predicated instruction execution

### Execution

- Multiply/divide ALU operations
- Shift and comparison instructions
- Floating-point execution
- Specialized vector units
- Additional execution pipelines

### Memory

- Memory coalescing
- Shared memory
- Shared-memory banking
- Bank-conflict modeling
- Load/store queues
- Instruction and data caches

### Scheduling

- Multiple warp schedulers
- More sophisticated scheduling policies
- Latency-aware scheduling
- Warp prioritization
- Performance counters

### System Integration

- FPGA implementation
- Larger memory systems
- External memory interfaces
- Host processor interface
- Software assembler
- Program loader
- Automated simulation framework

---

# Learning and Research Focus

This project provides a hardware-level environment for studying several
important computer-architecture concepts.

## GPU Microarchitecture

- Warp execution
- SIMD parallelism
- Active-lane masking
- Warp scheduling
- Per-thread register state
- GPU-style execution control

## Pipeline Architecture

- Instruction fetch
- Decode
- Execute
- Memory
- Writeback
- Pipeline state propagation

## Hazard Handling

- RAW dependencies
- Scoreboard design
- Pipeline stalls
- Dependency resolution
- Writeback-based resource release

## RTL Design

- SystemVerilog hierarchy
- Parameterized hardware
- Multi-dimensional arrays
- Combinational datapaths
- Sequential state machines
- Pipeline registers
- Memory modeling
- Assertions

---

# Getting Started

## Clone the Repository

```bash
git clone https://github.com/Mitanshu-0/custom-simd-gpu.git
cd custom-simd-gpu
```

---

## Explore the Architecture

A useful study sequence is:

```text
1. cu_defs.svh
2. lane_alu.sv
3. vector_alu.sv
4. vector_register_file.sv
5. decode_unit.sv
6. execute_stage.sv
7. data_memory.sv
8. mem_stage.sv
9. writeback_stage.sv
10. scoreboard.sv
11. warp_manager.sv
12. IFU.sv
13. compute_unit.sv
14. top.sv
```

This moves from the smallest datapath element toward the complete
processor integration.

---

# Understanding the Complete Processor

A useful way to understand the architecture is to follow one instruction
from start to finish:

```text
1. Warp Manager selects a READY warp
              ↓
2. PC identifies the instruction
              ↓
3. Instruction Memory returns the instruction
              ↓
4. IFU associates instruction with warp context
              ↓
5. Decode generates execution controls
              ↓
6. Scoreboard checks source dependencies
              ↓
7. Register File supplies lane operands
              ↓
8. SIMD ALU executes across active lanes
              ↓
9. Memory stage performs LOAD/STORE when required
              ↓
10. Writeback updates architectural state
              ↓
11. Scoreboard releases the destination register
              ↓
12. Warp Manager updates the warp state / PC
```

This execution path is the central concept of the project.

---

# Project Goals

The project is built around three primary goals:

### 1. Architectural Transparency

Every major GPU execution mechanism is represented by an explicit RTL
module.

### 2. Hardware-Level Understanding

The complete datapath and control flow can be studied without relying on
a high-level GPU framework.

### 3. Extensibility

The architecture provides a foundation on which more advanced GPU
features can be implemented incrementally.

---

# Author

**Mitanshu Dhameliya**

Department of Electronics and Communication Engineering

GitHub: [Mitanshu-0](https://github.com/Mitanshu-0)

Repository: [custom-simd-gpu](https://github.com/Mitanshu-0/custom-simd-gpu)

---

# Project Summary

```text
                     CUSTOM SIMD GPU
                           │
          ┌────────────────┴────────────────┐
          │                                 │
     WARP CONTROL                     SIMD DATAPATH
          │                                 │
   ┌──────┴──────┐                  ┌───────┴────────┐
   │ Warp Manager│                  │  Vector ALU    │
   │ Round Robin │                  │                │
   └──────┬──────┘                  │ Lane 0         │
          │                         │ Lane 1         │
   ┌──────▼──────┐                  │ Lane 2         │
   │ Per-Warp PC │                  │ Lane 3         │
   │ Active Mask │                  └───────┬────────┘
   │ Warp State  │                          │
   └──────┬──────┘                          │
          │                                 │
          └──────────────┬──────────────────┘
                         │
                  ┌──────▼──────┐
                  │  5-STAGE    │
                  │  PIPELINE   │
                  │             │
                  │ IF → ID     │
                  │ → EX → MEM  │
                  │ → WB        │
                  └──────┬──────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
            ▼            ▼            ▼
       Register      Scoreboard    Memory
         File        RAW Hazards   System
            │            │            │
            └────────────┴────────────┘
                         │
                         ▼
                  Architectural
                      State
```

**A SystemVerilog RTL implementation of a compact, parameterized
GPU-style parallel processor.**
