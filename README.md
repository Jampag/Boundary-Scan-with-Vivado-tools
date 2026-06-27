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

<img width="323" height="450" alt="image" src="https://github.com/user-attachments/assets/445ea100-79ee-486d-a89f-565a5969be1d" />




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

## Boundary Scan READ

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

#### 1. Real-world Example: Arduino Shield Pin Reading

Using the [FPGA-Shield-Arduino-compatible](https://github.com/Jampag/FPGA-Shield-Arduino-compatible) board, read the state of pin E2 of PMOD-E (which corresponds to the IO_B13 pin) after removing any connections:

```tcl
xsdb% bscan_input -port IO_B13
304:1 BC_2,IO_B13,output3 | 305:1 BC_2,IO_B13,input
```

The "305:1 BC_2,IO_B13,input" is high status because the pull-up is enabled.

Now connect the pin E2 (IO_B13) to GND and read again:

```tcl
xsdb% bscan_input -port IO_B13 -function input
305:0 BC_2,IO_B13,input
```

The pin is now **0** (low) because it's connected to ground. Disconnect the pin from GND and read again—it should return to **1** (high) due to the pull-up resistor.

---

#### 2. Standard Reading (10 columns)
```tcl
bscan_input
```
Output:
```
xsdb% bscan_input
0:1 BC_2,*,controlr | 1:1 BC_2,CCLK_A8,output3 | 2:1 BC_2,CCLK_A8,input | 3:1 BC_2,M0_M7,input | 4:1 BC_2,M1_M8,input | 5:1 BC_2,M2_M9,input | 6:1 BC_2,CFGBVS_N7,input | 7:1 BC_2,*,internal | 8:1 BC_2,*,controlr | 9:0 BC_2,INIT_B_P8,output3
10:1 BC_2,INIT_B_P8,input | 11:0 BC_2,*,controlr | 12:0 BC_2,DONE_P9,output3 | 13:0 BC_2,DONE_P9,input | 14:0 BC_2,*,internal | 15:0 BC_2,*,internal | 16:0 BC_2,*,internal | 17:0 BC_2,*,internal | 18:0 BC_2,*,internal | 19:0 BC_2,*,internal
20:0 BC_2,*,internal | 21:0 BC_2,*,internal | 22:1 BC_2,*,controlr | 23:1 BC_2,IO_L5,output3 | 24:1 BC_2,IO_L5,input | 25:1 BC_2,*,controlr | 26:1 BC_2,IO_N4,output3 | 27:1 BC_2,IO_N4,input | 28:1 BC_2,*,controlr | 29:1 BC_2,IO_P5,output3
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

Example output:
```
xsdb% bscan_input 5 -reg
0:1 | 1:1 | 2:1 | 3:1 | 4:1
5:1 | 6:1 | 7:1 | 8:1 | 9:0
10:1 | 11:0 | 12:0 | 13:0 | 14:0
15:0 | 16:0 | 17:0 | 18:0 | 19:0
20:0 | 21:0 | 22:1 | 23:1 | 24:1
25:1 | 26:1 | 27:1 | 28:1 | 29:1
---snip
```

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

## Boundary OUTPUT

### BOUNDARY OUTPUT WRITE

Drives I/O pins to specific logic levels (0, 1, or high-impedance Z). Unlike `bscan_input` which reads pin states, `bscan_output` allows you to actively control output pins via the Boundary Scan chain. This is useful for testing output behavior, simulating signals, or controlling external circuits without dedicated control software.

**Syntax (Register Mode):**
```tcl
bscan_output <reg> <0|1|T> [<reg> <value> ...] [-s]
```

**Syntax (Pin-Name Mode):**
```tcl
bscan_output <pin> <0|1|Z|T> [<pin> <value> ...] -n [-s]
```

**Values:**

Register Mode:
- `0` - Write 0 to register
- `1` - Write 1 to register
- `T` - Toggle output (requires `-count N`)

Pin-Name Mode:
- `0` - Drive pin low
- `1` - Drive pin high
- `Z` - High impedance (tri-state/open-drain)
- `T` - Toggle output (requires `-count N`)

**Options:**

- `-s` - Apply changes to device (without `-s`, only prepares data in buffer)
- `-n` - Interpret arguments as pin names (default is register indices)
- `-count N` - Generate N toggle frames (required when using `T`)

### Examples

#### 1. Real-world Example: Control LEDs on Arduino Shield

Using the [FPGA-Shield-Arduino-compatible](https://github.com/Jampag/FPGA-Shield-Arduino-compatible) board, control the on-board LEDs by driving pins M12 and M11. This example turns ON LED L1 (M12) and turns OFF LED L2 (M11):

```tcl
xsdb% bscan_output M12 1 M11 0 -n -s
```

The LEDs on the Arduino shield should now reflect the state: L1 is ON (bright), L2 is OFF (dark).

#### 2. Drive Multiple Registers Using BSDL Mapping (Register Mode)

From the BSDL file, boundary registers are mapped to specific pins:
```
210 (BC_2, *, controlr, 1)              -- Control register
211 (BC_2, IO_M12, output3, X, 210, ...)  -- LED L1 output (PAD41)
212 (BC_2, IO_M12, input, X)              -- LED L1 input feedback
```


Drive multiple registers in one command to set control register and turn on L1:

```tcl
xsdb% bscan_output 210 0 211 1 -s
```
<img width="499" height="403" alt="image" src="https://github.com/user-attachments/assets/fe703829-abb5-44bd-8dde-da5cfc59ab45" />


This command:
- Sets control register 210 to 0 (default state)
- Sets output register 211 (IO_M12) to 1, turning ON LED L1
- All other registers remain in their default state

#### 3. Drive Multiple Pins by Name

Control multiple pins simultaneously:

```tcl
xsdb% bscan_output M12 1 M11 0 -n -s
```

#### 4. Set Pin to High-Impedance (Tri-State)

Release a pin to high-impedance state (available only in pin-name mode):

```tcl
xsdb% bscan_output M12 Z -n -s
```

#### 5. Toggle Pin Multiple Times

Generate a pulse train by toggling a pin 10 times:

```tcl
xsdb% bscan_output M12 T -n -count 10 -s
```

The LED flashing frequency depends on the JTAG clock speed. To check the current JTAG frequency:

To read:
```tcl
xsdb% jtag frequency
15000000
```

To modify the JTAG frequency and change the flashing speed:

```tcl
xsdb% jtag frequency 10000
```


### Internal JTAG Sequence

```
Run-Test/Idle
  → Shift-IR(EXTEST)      [loads EXTEST opcode for boundary control]
  → Shift-DR              [shifts in new output values]
  → Run-Test/Idle         [applies new values to pins]
```


---

## Boundary Scan OUTPUT READBACK

### BOUNDARY OUTPUT SET and READ
Drives selected outputs then captures inputs while remaining in EXTEST.
Useful for detecting shorts, opens and stuck pins on DC nets.

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
