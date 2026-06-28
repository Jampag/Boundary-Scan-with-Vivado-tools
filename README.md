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
```tcl
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
```tcl
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
<img width="418" height="290" alt="image" src="https://github.com/user-attachments/assets/2ad8c16e-ace1-4438-8a18-c87f8109d743" />


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
 
Drives selected outputs then captures inputs while remaining in EXTEST. Useful for detecting shorts, opens and stuck pins on DC nets.
 
**Syntax:**
```tcl
bscan_output_capture -s <reg|pin> <val> <reg|pin> <val> ...
```
 
**Options:**
 
- `-r` <reg...> - Read specific registers
- `-reg` - Print all as reg:value (with colors)
- `-port` <name> - Filter by port
- `-function` <type> - Filter by cell function
- `-idle` <N> - Idle cycles before capture
- <columns> is optional, default is 10


### Examples

#### 1. Drive Pin and Readback Status
 
Using the [FPGA-Shield-Arduino-compatible](https://github.com/Jampag/FPGA-Shield-Arduino-compatible) board, control the on-board LED L1 by driving pin M12 then read M12 pin status:
 
```tcl
xsdb% bscan_output_capture -s IO_M12 1 -port IO_M12 -function input
212:1 BC_2,IO_M12,input
```
 
Drive the pin M12 to 1 then read M12 pin status is 1. Finally all pins return to input state.
 

#### 2. Detect Stuck Pin (Short to GND)
Now test for a stuck pin by connecting PMOD-N pin N10 to GND:

<img width="520" height="381" alt="image" src="https://github.com/user-attachments/assets/7b25a493-d873-430d-a9a5-a08dd21a9749" />



Drive the pin M12 at 1 then read M12 pin status, finally all pins return in input.
```tcl
bscan_output_capture -s IO_M12 1 -port IO_M12 -function input
212:0 BC_2,IO_M12,input
```
The M12 pin status is **stuck at 0** because it's shorted to ground. This diagnostic helps identify hardware faults like shorts, opens, and stuck pins on DC nets.


---

## All Available Functions
 
### Load Script
 
**bscan_load**
 
```tcl
bscan_load <path>/device.bsd
```
 
Load BSDL file and extract device parameters. Loads BSDL information: boundary length, IR length, opcodes, pin/register mapping.
 
---
 
### Read Device IDCODE
 
**bscan_idcode**
 
```tcl
bscan_idcode
```
 
Read device identification code.
 
Sequence: Run-Test/Idle → Shift-IR(IDCODE) → Capture-DR → Shift-DR → Run-Test/Idle
 
---
 
### Boundary Input Read
 
```tcl
bscan_input
```
 
Capture and read I/O pin states in the Boundary chain. Captures all I/O pins with optional filtering by port or function type. Supports raw mode (-reg) and stateless operation (-noreset).
 
Sequence: Run-Test/Idle → Shift-IR(SAMPLE) → Capture-DR → Shift-DR → Run-Test/Idle
 
---
 
### Boundary Output (Drive)
 
```tcl
bscan_output <reg> <0|1|T> [<reg> <value> ...] [-s]
bscan_output <pin> <0|1|Z|T> [<pin> <value> ...] -n [-s]
```
 
Drive output pins to specific logic levels. Register Mode: 0 = write 0, 1 = write 1, T = toggle (requires -count N). Pin-Name Mode: 0 = drive low, 1 = drive high, Z = high impedance, T = toggle.
 
Options: -s (apply to device), -n (pin-name mode), -count N (toggle frames)
 
Sequence: Run-Test/Idle → Shift-IR(EXTEST) → Shift-DR → Run-Test/Idle
 
---
 
### Boundary Output + Capture
 
**bscan_output_capture**
 
```tcl
bscan_output_capture [columns] -s <reg|pin> <val> [<reg|pin> <val> ...] [options]
```
Drives selected outputs then captures inputs while remaining in EXTEST.
Useful for detecting shorts, opens and stuck pins on DC nets.

Sequence: SAMPLE → modify registers → EXTEST → Shift-DR → optional IDLE → Capture-DR
 
---
 
### MGT Output Control
 
```tcl
bscan_output_mgt <reg|pin> <0|1> [-s] [-t|-p] [-count N]
```
 
Control high-speed transceiver (MGT/OUTPUT2) pins. Used for MGT TX pins. Supports TRAIN (-t) and PULSE (-p) opcodes.
 
Sequence: Run-Test/Idle → Shift-IR(TRAIN/PULSE) → Shift-DR → Run-Test/Idle
 
---
 
### MGT Stress / Train Tests
 
**run_mgt_test**
 
Execute repeated MGT training tests with register sampling.
 
```tcl
run_mgt_test <columns> -count <N> -idle <M> -r <reg> <0|1> [...] -sample <reg> [...] [-p] [-t]
```
 
Performs N iterations of MGT TRAIN/PULSE with M idle cycles between drive and sample. Use highest stable JTAG frequency (30 MHz typical).
 
Sequence: SAMPLE → loop N times: (Shift-IR(TRAIN/PULSE) → Shift-DR → IDLE*M → SAMPLE → Capture-DR → Shift-DR)
 
---
 
### Capacitive Net Test
 
Test capacitive coupling and pin loading.
 
```tcl
bscan_cap_test <pin> -n [-count <N>] [-gap <N>]
```

Used to detect if a net is connected to an external device or passive component by observing the decay or persistence of the voltage when the pin is released to high impedance.

Drive pin to 0/1, release to high-impedance (Z), then sample repeatedly to detect capacitive decay.

Typical use cases
- detect open nets
- detect presence of pull-up / pull-down resistors
- detect capacitive loading of traces
- verify solder connection of pins connected to non-JTAG devices
 
Sequence: EXTEST → Shift-DR (release to Z) → repeat N times: (Capture-DR → Shift-DR → IDLE*gap)
 
---
 
### SPI Configuration
 
Configure SPI interface pins for boundary scan SPI.
 
```tcl
bscan_spi_cfg SCK=<pin> MOSI=<pin> MISO=<pin> CS=<pin> [CPOL=0|1] [CPHA=0|1]
bscan_spi_cfg SET_0=<pin> SET_1=<pin>
bscan_spi_cfg -clear
```
 
Setup pins and SPI mode parameters (clock polarity, phase). Supports timing delays (PRE_IDLE, CS_SETUP_IDLE in microseconds).
 
---
 
### SPI Transaction
 
Perform SPI read/write transactions.
 
```tcl
bscan_spi -w <byte> [<byte> ...] [-r <n>]
```
 
Write bytes via MOSI and optionally read bytes from MISO. Requires prior configuration with bscan_spi_cfg.
 
Sequence: EXTEST → repeat for each bit: (Shift-DR drive → Shift-DR clock → Capture-DR sample MISO → Shift-DR)
 
---
 
### I2C Configuration
 
Configure I2C interface pins for boundary scan I2C.
 
```tcl
bscan_i2c_cfg SCL=<pin> SDA=<pin>
```
 
Setup SCL and SDA pins for I2C transactions via boundary scan.
 
---
 
### I2C Device Detect
 
Detect I2C device presence at specified address.
 
```tcl
bscan_i2cdetect <addr> -w|-r
```
 
Sends START + ADDR + STOP to check device presence. Use -w for write bit, -r for read bit.
 
---
 
### I2C Register Write
 
Write data to I2C device register.
 
```tcl
bscan_i2cset <addr> <reg> [<byte> ...]
```
 
Writes register/data bytes to I2C device at specified address.
 
---
 
### I2C Register Read

Read data from I2C device.
 
```tcl
bscan_i2cget <addr> <n> -r|-w
bscan_i2cget <addr> <reg> <n> -r|-w [-rs]
```
 
Read N bytes from address (with optional register offset). Use -rs for repeated START on register read.
 
---
 
### I2C Bus Scan
 
Scan entire I2C bus for connected devices.
 
```tcl
bscan_i2cscan -w|-r
```
 
Scan addresses 0x00..0x7F to discover all connected I2C devices. Requires prior configuration with bscan_i2c_cfg.
 
---
 
### Output3 Pin Scan

 
Test output3 (tri-state) pins for shorts and coupling.
 
```tcl
bscan_output3_scan [<pin> <pin> ...] [-exclude {<pin> ...}] [-include {<pin> ...}]
```
Tests OUTPUT3 pins by driving 1 and 0, then capturing all input cells. It reports whether the selected pin follows correctly and whether other pins move together (FOLLOW), useful to detect shorts/coupling.

Sequence: EXTEST → Shift-DR(drive=1) → Capture-DR → Shift-DR(drive=0) → Capture-DR
 
---


## General Reference

### Help 

```tcl
bscan
```
or
[readme.txt](https://github.com/Jampag/Boundary-Scan-with-Vivado-tools/blob/main/readme.txt)


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

## License

This project is licensed under the GNU General Public License v3.0 (GPL v3).

See the full license at: https://www.gnu.org/licenses/gpl-3.0.html
