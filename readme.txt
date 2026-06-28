==============================
 BSCAN TOOLS QUICK GUIDE
==============================

General Workflow
----------------
1. Connect the JTAG cable.
2. Start the Vivado hardware server:
      hw_server.bat
3. Start XSDB:
      xsdb.bat
4. Load the BSDL description:
      bscan_load <device>.bsd
5. Use the commands described below.

Important Notes
---------------
Use forward slash "/" in paths (NOT backslash "\")
Example:
    source C:/scripts/bscan_tools.tcl


LOAD SCRIPT
-----------
source <path>/bscan_tools.tcl


LOAD BSDL FILE
--------------
bscan_load <path>/device.bsd

Loads:
	- boundary length
	- IR length
	- opcodes
	- pin/register mapping

==================================================
READ DEVICE IDCODE
==================================================
	bscan_idcode

==================================================
BOUNDARY INPUT READ
==================================================

Syntax
------
	bscan_input [columns] [filters]

Default
-------
	bscan_input

Examples
--------
	bscan_input 5
	bscan_input -port CCLK_A8
	bscan_input -function input
	bscan_input 5 -port IO_L5 -function output3

Raw mode (no BSDL lookup)
--------------------------
	bscan_input -reg
	bscan_input 5 -reg

Filters
-------
	-port <name>
	-function <type>


No-reset mode
-------------
	bscan_input -noreset
	bscan_input 5 -noreset
	bscan_input -port IO_L5 -noreset

Sequence
--------
    Run-Test/Idle
      -> Shift-IR(SAMPLE)
      -> Capture-DR
      -> Shift-DR
      -> Run-Test/Idle


==================================================
BOUNDARY DRIVE (BC_2 CELLS)
==================================================

Register mode
-------------
	bscan_output <reg> <value> [<reg> <value> ...]

Example
-------
	bscan_output 210 0 211 1 183 0 184 1 -s


Pin-name mode
-------------
	bscan_output <pin> <value> [<pin> <value> ...] -n

Example
-------
	bscan_output M12 1 M11 0 -n -s


Register mode:
    0 = write 0
    1 = write 1
    T = toggle output (requires -count N)

Pin-name mode:
    0 = drive low
    1 = drive high
    Z = high impedance (tri-state)
    T = toggle output (requires -count N)


Options
-------
	-s apply to device
	-n interpret arguments as pin names
	-count N generate N toggle frames

Notes
-----
Multiple pins or registers can be written in one command
Without -s command only prepares data


Sequence
--------

    RESET -> Run-Test/Idle
      -> Shift-IR(EXTEST)
      -> Shift-DR
      -> Run-Test/Idle


==================================================
OUTPUT + CAPTURE (WRITE AND READ IN ONE STEP)
==================================================


Drives outputs and captures the boundary chain afterward.
Useful for detecting shorts, opens, and stuck pins.


Syntax
------
	bscan_output_capture [columns] -s <reg|pin> <val> [<reg|pin> <val> ...] [options]


Examples
--------
	bscan_output_capture -s 318 0 319 1 321 1 -r 320 323
	bscan_output_capture 5 -s IO_C10 1 IO_D10 Z
	bscan_output_capture -s IO_C10 1 -port IO_D10 -function input
	bscan_output_capture -s 318 0 319 1 -reg


Write Arguments
---------------
	-s <key> <value>

	<key> can be:
	- register index
	- pin name (OUTPUT3 cells only)

	Values:
	0 = drive low
	1 = drive high
	Z = high impedance (only OUTPUT3 pins)


Read Options
------------
	-r <reg> [reg ...]
		Returns only selected registers.

	-reg
		Prints captured data as register:value pairs.


If -r is NOT used:
------------------
	All registers are printed
	(with same filters as bscan_input)


Filters
-------
	-port <name>
	-function <type>

Examples:
	-function input
	-function observe_only
	-port IO_C10


Formatting
----------
	First numeric argument sets columns per line.

Example:
	bscan_output_capture 5 -s IO_C10 1


Idle Delay
----------
	-idle <N>

	Adds N IDLE states between update and capture.

Useful when:
	- signal needs settling time
	- testing long traces
	- AC coupled nets

Operation Sequence
------------------
Internally the command performs:

1) SAMPLE -> copies safe boundary image
2) modify selected registers
3) EXTEST
4) DRUPDATE -> apply outputs
5) optional IDLE delay
6) CAPTURE -> read boundary

Operation Sequence
------------------

    SAMPLE -> capture safe boundary image
    modify selected registers
    EXTEST
    Shift-DR -> apply outputs and return to Run-Test/Idle
    optional IDLE delay
    Capture-DR -> read boundary while remaining in EXTEST

Important Behavior
------------------

CAPTURE overwrites boundary register contents.

The capture re-samples the boundary chain, therefore output bits in the
captured data may differ from the values previously written.


==================================================
MGT OUTPUT CONTROL (OUTPUT2 CELLS ONLY)
==================================================

Used for high-speed transceiver TX pins


Register mode
-------------
	bscan_output_mgt <reg> <value> [<reg> <value> ...]


Pin mode
--------
	bscan_output_mgt <pin> <value> [<pin> <value> ...]


Examples
--------

	bscan_output_mgt 2312 1 -s -t
	bscan_output_mgt MGTYTXP0_127 1 -s -t
	bscan_output_mgt MGTYTXP0_127 1 -s -t -count 10
	bscan_output_mgt 2312 1 -s -p
	bscan_output_mgt MGTYTXP0_127 1 -s

Options
-------

    -t   use TRAIN opcode 
		-count <n X IDLE>
    -p   use PULSE opcode -default

Sequence
--------

    RESET -> Run-Test/Idle
      -> Shift-IR(TRAIN/PULSE)
      -> Shift-DR
      -> Run-Test/Idle


==================================================
MGT STRESS / TRAIN TESTS
==================================================

Performs repeated MGT training tests while sampling selected registers.


Syntax
------
	run_mgt_test <columns> -count <N> -idle <M> -r <reg> <0|1> [<reg> <0|1> ...] -sample <reg> [reg ...] [-p] [-t]


Options
-------

    <cols>      number of columns per output line
    -count N    number of iterations
    -idle M     Run‑Test/Idle cycles between drive and sample
    -r          override bits of initial SAMPLE frame
    -sample     registers to monitor
    -p          use PULSE opcode
    -t          use TRAIN opcode (default)

Example
-------

    run_mgt_test 2 -count 10 -idle 50 -r 372 1 -sample 370 371
    run_mgt_test 1 -count 100 -idle 200 -r 372 1 -sample 371 -p

Operation Sequence
------------------

    Test-Logic-Reset
      -> Shift-IR(SAMPLE) -> Run-Test/Idle
      -> Capture-DR -> Run-Test/Idle
      -> Shift-IR(TRAIN/PULSE) -> Run-Test/Idle

    Repeat N times:

        Shift-DR
        -> Run-Test/Idle * M
        -> Shift-IR(SAMPLE) -> Run-Test/Idle
        -> Capture-DR -> Shift-DR -> Run-Test/Idle



Output
------
	Prints zero/one counters for monitored registers.
	

Timing Note
-----------
	Designed for high-speed JTAG operation.
	Use highest stable TCK (30 MHz typical).
	
	
	
==================================================
CAPACITIVE NET TEST (HIGH-Z RELEASE SAMPLING)
==================================================

Used to detect if a net is connected to an external device
or passive component by observing the decay or persistence
of the voltage when the pin is released to high impedance.

Typical use cases
-----------------
	- detect open nets
	- detect presence of pull-up / pull-down resistors
	- detect capacitive loading of traces
	- verify solder connection of pins connected to non-JTAG devices


General Concept
---------------
	1) Drive the pin to a known logic level
	2) Release the pin to High-Z
	3) Sample the boundary input cell repeatedly
	4) Observe the transition over time


Basic Workflow
--------------

Step 1 — drive the pin
    bscan_output <pin> <0|1> -n -s

	Example:
    bscan_output IO_M11 1 -n -s

Step 2 — run capacitive test
    bscan_cap_test <pin> -n -count <N> [-gap G]

	Example:
    bscan_cap_test IO_M11 -n -count 10 -gap 0

Sampling Timing
---------------

Approximate sampling interval:

    Tsample = (BR_LEN + gap) / fJTAG

Where:

    BR_LEN   boundary register length
    gap      additional IDLE cycles between samples
    fJTAG    JTAG clock frequency

Options
-------
    -count N
        number of samples to capture
        default = 10
    -gap G
        number of Run-Test/Idle cycles between samples


Example Test
------------

Drive HIGH then release:

    bscan_output IO_M11 1 -n -s
    bscan_cap_test IO_M11 -n -count 10 -gap 0


Drive LOW then release:

    bscan_output IO_M11 0 -n -s
    bscan_cap_test IO_M11 -n -count 50 -gap 100


Typical Results
---------------

	Connected to pull-up:
		samples : 1 1 1 1 1 1 1

	Connected to pull-down:
		samples : 0 0 0 0 0 0

	Capacitive decay example:
		samples : 1 1 1 0 0 0


Sequence
--------

    RESET -> Run-Test/Idle
      -> Shift-IR(EXTEST)
      -> Shift-DR   (release pin to High-Z)
      -> Run-Test/Idle

    Repeat N times:

      -> Capture-DR (sample boundary input cell)
      -> Shift-DR
      -> Run-Test/Idle
      -> optional IDLE delay (-gap)

Important Notes
---------------

	The test relies on releasing the pin to High-Z and observing
	the input cell behavior.
	Only OUTPUT3 boundary cells are supported.
	The command internally uses EXTEST while sampling.


==================================================
SPI TRANSACTIONS VIA BOUNDARY SCAN
==================================================

Used to communicate with SPI devices (e.g. SPI NOR)
through the boundary scan chain.

Typical use cases
-----------------
    - read SPI flash ID
    - access configuration registers
    - verify SPI connectivity

General Concept
---------------
    1) Configure SPI pins through boundary scan
    2) Drive MOSI / SCK / CS frames using EXTEST
    3) Capture MISO bits from boundary input cell
    4) Assemble received bytes

Basic Workflow
--------------

Step 1 — configure SPI pins
    bscan_spi_cfg SCK=<pin> MOSI=<pin> MISO=<pin> CS=<pin> [CPOL=0|1] [CPHA=0|1]

    Examples:
    bscan_spi_cfg -clear
    bscan_spi_cfg SCK=IO_M10 MOSI=IO_M11 MISO=IO_M12 CS=IO_M13
    bscan_spi_cfg SET_0=IO_M12 SET_1=IO_C12

Step 2 — perform SPI transaction
    bscan_spi -w <byte>... [-r <n>]

    Example:
    bscan_spi -w 0x90

SPI Mode
--------
Supported modes:

    CPOL=<0|1>   clock polarity (default 0)
    CPHA=<0|1>   clock phase    (default 0)

Extra Preset / Delay Options
----------------------------
    PRE_IDLE=<usec>
        delay after preset apply before CS low

    CS_SETUP_IDLE=<usec>
        delay after CS low before first clock

    SET_0=<pin>
        drive selected pin(s) to 0 during SPI

    SET_1=<pin>
        drive selected pin(s) to 1 during SPI

Notes
-----
    PRE_IDLE and CS_SETUP_IDLE are delays in microseconds
    and do not toggle TCK.

    Preset pins remain driven (not Z) for the entire SPI sequence.

Example Test
------------

Read SPI NOR flash ID:

    bscan_spi_cfg SCK=IO_M10 MOSI=IO_M11 MISO=IO_M12 CS=IO_M13
    bscan_spi -w 0x90 0x00 0x00 0x00 -r 2

Example SNOR read ID:

    bscan_spi_cfg SCK=CCLK_A8 MISO=IO_B12 MOSI=IO_B11 CS=IO_C11 CPOL=0 CPHA=0
    bscan_spi -w 0x90 0x00 0x00 0x00 -r 2

Operation Sequence
------------------

    RESET -> Run-Test/Idle
      -> Shift-IR(EXTEST)

    Repeat for each bit:

      -> Shift-DR (drive frame)
      -> Shift-DR (clock high)
      -> Capture-DR (sample MISO)
      -> Shift-DR
      -> Run-Test/Idle


Important Notes
---------------
    SPI is implemented using EXTEST boundary scan frames.
    Each SPI bit requires multiple DR scans, therefore
    communication speed depends on the JTAG clock.

==================================================
I2C VIA BOUNDARY SCAN
==================================================

Used to communicate with I2C devices through the
boundary scan chain.

Basic Workflow
--------------

Step 1 — configure I2C pins
    bscan_i2c_cfg SCL=<pin> SDA=<pin>

    Example:
    bscan_i2c_cfg SCL=IO_A13 SDA=IO_A12

Step 2 — detect a device
    bscan_i2cdetect <addr> -w|-r

    Examples:
    bscan_i2cdetect 0x48 -w
    bscan_i2cdetect 0x48 -r

Step 3 — write register/data
    bscan_i2cset <addr> <reg> [<byte> ...]

    Examples:
    bscan_i2cset 0x48 0x01
    bscan_i2cset 0x48 0x01 0x80

Step 4 — read data
    bscan_i2cget <addr> <n> -r|-w
    bscan_i2cget <addr> <reg> <n> -r|-w [-rs]

    Examples:
    bscan_i2cget 0x48 1 -r
    bscan_i2cget 0x48 1 -w
    bscan_i2cget 0x48 0x00 1 -r
    bscan_i2cget 0x48 0x00 1 -w
    bscan_i2cget 0x48 0x00 2 -r -rs

Bus Scan
--------
    bscan_i2cscan -w|-r

    Examples:
    bscan_i2c_cfg SCL=IO_A13 SDA=IO_A12
    bscan_i2cscan -w
    bscan_i2cscan -r

Protocol Summary
----------------
    bscan_i2cdetect    START + ADDR(W|R) + ACK/NACK + STOP
    bscan_i2cset       START + ADDR(W) + REG + DATA... + STOP
    bscan_i2cget       START + ADDR(W|R) + DATA... + STOP
    bscan_i2cget reg   START + ADDR(W|R) + REG + DATA... + STOP
    bscan_i2cget -rs   START + ADDR(W) + REG + REPEATED START + ADDR(W|R) + DATA... + STOP

Options
-------
    -w    use address with write bit
    -r    use address with read bit
    -rs   use repeated start on register read

Operation Sequence
------------------
    Shift-IR(EXTEST) -> Shift-DR(frames) -> Capture-DR(ACK/SDA) -> Shift-DR(frames)

Notes
-----
    bscan_i2cscan scans addresses 0x00..0x7F using bscan_i2cdetect internally.


==================================================
OUTPUT3 SCAN
==================================================

Tests OUTPUT3 pins by driving 1 and 0, then capturing all input cells.
It reports whether the selected pin follows correctly and whether
other pins move together (FOLLOW), useful to detect shorts/coupling.

Syntax
------
    bscan_output3_scan [<pin> <pin> ...] [-exclude {<pin> <pin> ...}]

Options
-------
    -exclude {<pin>...}
        -exclude {<pin>...} exclude the listed pins from monitoring
	-include {<pin>...} monitor only the listed pins

Result Meaning
--------------
    PASS
        pin follows correctly and no other pins move

    WARNING
        pin follows correctly but other pins move together (FOLLOW)

    FAIL
        pin does not follow correctly (drive error)

Notes
-----
    Multiple pins can be passed in the test list.
    Multiple pins can also be excluded using a Tcl list in braces.

Examples
--------
    bscan_output3_scan
    bscan_output3_scan IO_A13
    bscan_output3_scan IO_A13 IO_M12
    bscan_output3_scan -exclude {IO_D1}
    bscan_output3_scan -exclude {IO_D1 CCLK_A8 DONE_P9}
    bscan_output3_scan IO_A13 IO_M12 -exclude {IO_D1}
    bscan_output3_scan IO_A13 IO_M12 -exclude {IO_D1 CCLK_A8}
    bscan_output3_scan IO_A13 IO_M12 -include {IO_A13 IO_M12 IO_M11}

Operation Sequence
------------------
    Shift-IR(EXTEST)
      -> Shift-DR(drive pin=1)
      -> Capture-DR(all input)
      -> Shift-DR(drive pin=0)
      -> Capture-DR(all input)


==================================================
DEBUG / INTERNAL STATE
==================================================

Show internal configuration variables:
    parray ::BSCAN

Displays:
- loaded opcodes
- boundary length
- IR length
- parsed BSDL info

Useful for debugging configuration or checking
that BSDL parsing succeeded.

Manual override example:
    set BSCAN(irlen) 10
    set BSCAN(br_len) 2048


==================================================
GENERAL NOTES
==================================================

Pin-name commands require BSDL loaded first
Ctrl+C stops infinite loops
If opcode missing in BSDL default values used
OUTPUT2 cells cannot be tri-stated
BC_2 cells support 0 / 1 / Z
JTAG Frequency read: jtag frequency
JTAG Frequency set:  jtag frequency <kHz>
For stress / MGT tests use highest stable TCK (30 MHz typical).

JTAG scan state flow:
 drshift : 
	IDLE -> SELECT-DR -> CAPTURE-DR -> SHIFT-DR -> EXIT1-DR -> UPDATE-DR -> IDLE
 irshift :
	IDLE -> SELECT-DR -> SELECT-IR -> CAPTURE-IR -> SHIFT-IR -> EXIT1-IR -> UPDATE-IR -> IDLE

IEEE 1149.1 TAP Terminology
---------------------------
Test-Logic-Reset  = TAP reset state
Run-Test/Idle     = idle execution state
Shift-IR          = shift instruction register
Capture-DR        = load selected data register
Shift-DR          = serial data transfer
Update-DR         = latch shifted data


==================================================

Legend: IR=Instruction Register, DR=Data Register, k=RTI cycles, N=iterations
