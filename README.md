# BSCAN Tools

## Introduction

BSCAN Tools is a suite of Tcl functions for testing and diagnostics of integrated circuits via **Boundary Scan** (IEEE 1149.1 JTAG standard). It allows you to access and control I/O pins without direct contact with the circuit, using only the JTAG chain.

**No licenses or paid software required.** JTAG Boundary communication is established via **XSDB** (Xilinx System Debugger), included free with the Vivado suite. It is compatible with **any device conforming to the IEEE 1149.1 standard**, not just Xilinx devices.

JTAG connection can be established with:
- **Digilent HS3** - Professional JTAG Programmer/Debugger
- **FT232H Breakout Board** - Cost-effective and versatile solution based on FTDI

### What is Boundary Scan?

**Boundary Scan** is an industrial test standard (IEEE 1149.1 JTAG) integrated into devices that allows you to:

- **Read the state** of I/O pins (input/output)
- **Drive outputs** to specific logic levels
- **Detect short circuits, open circuits**, and stuck pins
- **Communicate via SPI or I2C** through chip pins
- **Test high-speed components** (MGT, transceivers)
- **Identify the device** via IDCODE

---

## General Workflow

1. **Download the bscan_tools.tcl file** from [Boundary-Scan-with-Vivado-tools](https://github.com/Jampag/Boundary-Scan-with-Vivado-tools/blob/main/bscan_tools.tcl)
2. **Connect the JTAG cable**
3. Start the Vivado hardware server: `hw_server.bat`
4. Start XSDB: `xsdb.bat`
5. Load the BSDL description: `bscan_load <device>.bsd`
6. Use the commands below

### Important Notes

- Use **forward slashes "/" in paths**, not backslashes
  ```tcl
  source C:/scripts/bscan_tools.tcl
  ```
- Test operations require a stable JTAG frequency (30 MHz typical for stress tests)
- Ctrl+C interrupts infinite loops

---

## Loading

### Load Script
```tcl
source <path>/bscan_tools.tcl
```

Upon successful loading, the following output will be printed:
```
xsdb% source D:/tmp/bscan_tools.tcl
BSCAN JTAG chain
  1  Digilent JTAG-HS3 2102xxxxxxxx
     2  xc7s15 (idcode 03620093 irlen 6 fpga)
BSCAN connected url=tcp:localhost:3121 target=2
BSCAN Tools v1.0
Default: IRLEN=6  BR_LEN=339  SAMPLE=01  EXTEST=26  IDCODE=09  BYPASS=3F
Quick commands:
  bscan_load <path>/device.bsd
  --snip
```

### Load BSDL File
```tcl
bscan_load <path>/device.bsd
```

Example output:
```
xsdb% bscan_load D:/tmp/xc7s15_ftgb196.bsd
 BSDL: D:/tmp/xc7s15_ftgb196.bsd
 BOUNDARY_LENGTH = 339 IRLEN=6 SAMPLE=01 EXTEST=26 IDCODE=09 BYPASS=3F TRAIN=3D PULSE=3C
  IDCODE_REGISTER parts = 0xX & 0x1B & 0x20 & 0x49 & 0x1
  IDCODE_REGISTER bits  = 00000011011000100000000010010011 (0x03620093)
  IDCODE std: ver=0xX part=0x3620 mfg=0x49 req=1
xsdb%
```

Automatically loads:
- Boundary register length (BR_LEN)
- Instruction register length (IR_LEN)
- JTAG opcodes (SAMPLE, EXTEST, IDCODE, BYPASS)
- Pin/register mapping

---

## Device Reading

### READ DEVICE IDCODE

Reads the IDCODE of the connected device. The IDCODE is a unique number that identifies the chip and its version. Useful for verifying the JTAG connection and device identification during initial debugging.

**Syntax:**
```tcl
bscan_idcode
```

**TAP Sequence:**
```
Run-Test/Idle 
  → Shift-IR(IDCODE) 
  → Capture-DR 
  → Shift-DR 
  → Run-Test/Idle
```

**Example:**
```tcl
xsdb% bscan_idcode
 IDCODE_bsdl = (0x03620093)
JTAG read:
 IDCODE = 0x03620093
 IDCODE raw   = 0x93006203
 IDCODE canon = 0x03620093 (byte-swapped)
  required(LSB)   = 1 required by 1149.1
  version         = 0 (0x0)
  part_number     = 13856 (0x3620)
  manufacturer    = 73 (0x049) Xilinx
```

---

## Boundary Chain Reading

### BOUNDARY INPUT READ

Reads the status of all I/O pins by capturing a snapshot of the Boundary chain. Each Boundary cell captures the value present on the pin at that moment. Useful for real-time monitoring of pin status and anomaly detection.

**Syntax:**
```tcl
bscan_input [columns] [filters]
```

#### Default Usage

```tcl
bscan_input
```
Reads all pins, prints 10 columns per line.

---

### Examples

#### 1. Real-world Example:

Using the [FPGA-Shield-Arduino-compatible](https://github.com/Jampag/FPGA-Shield-Arduino-compatible) board,Read the state of pin E2 of PMOD-E (which corresponds to the IO_B13 pin) after removing any connections:

```tcl
xsdb% bscan_input -port IO_B13
304:1 BC_2,IO_B13,output3 | 305:1 BC_2,IO_B13,input
```
The "305:1 BC_2,IO_B13,input" is high status because the pull-up is are enabled

Output will show the current state of the D1 pin on the Arduino shield.

---

#### Standard Reading (10 columns)
```tcl
bscan_input
```
Output:
```
Register  Value
0         1
1         0
2         1
...
```

#### 3. Reading with N Columns
```tcl
bscan_input 5
```
Prints 5 values per line for more compact visualization.

#### 4. Filter by Port Name
```tcl
bscan_input -port CCLK_A8
```
Reads only pins belonging to the `CCLK_A8` port.

#### 5. Filter by Function Type
```tcl
bscan_input -function input
```
Reads only **input** pins (cells with `input` function).

Available types:
- `input` - inputs
- `output3` - tri-state outputs
- `output2` - MGT outputs (transceivers)
- `observe_only` - passive observation
- `controlr` - control

#### 6. Combined Reading (Multiple Filters)
```tcl
bscan_input 5 -port IO_L5 -function output3
```
Reads 5 columns, filtering by `IO_L5` port and `output3` type.

#### 7. Raw Mode (Without BSDL Lookup)
```tcl
bscan_input -reg
```
Prints raw boundary register data as `register:value` pairs, without interpreting BSDL pin names. Useful when BSDL is not loaded or you want low-level output.

```tcl
bscan_input 5 -reg
```
Same raw format but with 5 columns.

#### 8. Reading Without TAP Reset
```tcl
bscan_input -noreset
```
Performs capture **maintaining the current TAP state** instead of resetting. Useful for sequential tests that require consistent TAP state.

```tcl
bscan_input 5 -noreset
bscan_input -port IO_L5 -noreset
```

---

### Internal JTAG Sequence

```
Run-Test/Idle
  → Shift-IR(SAMPLE)      [loads SAMPLE opcode]
  → Capture-DR            [acquires boundary at next clock cycle]
  → Shift-DR              [transfers bits via JTAG chain]
  → Run-Test/Idle         [returns to idle]
```

---

### Use Cases

| Scenario | Command |
|----------|---------|
| Monitor everything in real-time | `bscan_input` |
| Test only IO_L5 group | `bscan_input -port IO_L5` |
| Find all inputs | `bscan_input -function input` |
| Low-level debugging | `bscan_input -reg` |
| Sequential test (no TAP reset) | `bscan_input -noreset` |

---

## General Reference

### Internal Configuration

Display internal configuration variables:
```tcl
parray ::BSCAN
```

Shows:
- Loaded opcodes
- Boundary length
- Instruction register length
- Parsed BSDL information

### Manual Override
```tcl
set ::BSCAN(irlen) 10
set ::BSCAN(br_len) 2048
```

---

## TAP Glossary

| Term | Description |
|------|-------------|
| **Test-Logic-Reset** | TAP reset state |
| **Run-Test/Idle** | Idle execution state |
| **Shift-IR** | Shift in instruction register |
| **Capture-DR** | Load selected data register |
| **Shift-DR** | Serial data transfer |
| **Update-DR** | Latch shifted data |

---

## Legend

- **IR** = Instruction Register
- **DR** = Data Register  
- **BR_LEN** = Boundary Register Length
- **JTAG** = Joint Test Action Group (IEEE 1149.1)
- **BSDL** = Boundary Scan Description Language
- **TCK** = Test Clock
- **TMS** = Test Mode Select
- **TDI** = Test Data In
- **TDO** = Test Data Out

---

## Debug & Troubleshooting

**Problem:** BSDL fails to load  
**Solution:** Verify the path (use `/` not `\`) and correct BSDL format

**Problem:** IDCODE not recognized  
**Solution:** Check JTAG connection and ensure cable is properly connected

**Problem:** bscan_input prints "???"  
**Solution:** Load a BSDL file first with `bscan_load`

---

## References

- [IEEE 1149.1 JTAG Standard](https://en.wikipedia.org/wiki/JTAG)
- Xilinx Vivado XSDB Documentation
- [BSDL Format Specification](https://standards.ieee.org/standard/1149_1-2013.html)

---

**Version:** 1.0  
**Tested:** Vivado System Debugger (XSDB) v2024.2 | Xilinx hw_server v2024.2  
**Created:** April 2026  
**License:** Provided as-is for diagnostic and testing purposes
