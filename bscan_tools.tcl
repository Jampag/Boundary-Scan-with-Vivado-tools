# ============================================================
# Date : 2026 april 2
# Version: 1.0
# Vivado tested:
# 	System Debugger (XSDB) v2024.2
# 	Xilinx hw_server v2024.2
# ============================================================

# ---------- CONFIG ----------
set ::BSCAN(target) 2
set ::BSCAN(url) tcp:localhost:3121

# JTAG instruction register length 
set ::BSCAN(irlen) 6
set ::BSCAN(br_len) 339

# Standard opcodes (HEX) 
set ::BSCAN(op_sample) 01
set ::BSCAN(op_extest) 26
set ::BSCAN(op_idcode) 09
set ::BSCAN(op_bypass) 3F


# =========================================
# BSCAN TOOLS LOADER (always connect + print targets)
# =========================================
# ---------- VERSION ----------
set ::BSCAN(version) "1.0"

proc ::c_title {s} { return "\033\[1;36m$s\033\[0m" }
proc ::c_sec   {s} { return "\033\[1;33m$s\033\[0m" }
proc ::c_cmd   {s} { return "\033\[1;32m$s\033\[0m" }
proc ::c_dim   {s} { return "\033\[2m$s\033\[0m" }

# Print a short banner after source
proc bscan_banner {} {
    set ver "UNKNOWN"
    if {[info exists ::BSCAN(version)]} { set ver $::BSCAN(version) }

    set url "?"
    if {[info exists ::BSCAN(url)]} { set url $::BSCAN(url) }

    set tgt "?"
    if {[info exists ::BSCAN(target)]} { set tgt $::BSCAN(target) }

    set irlen "?"
    if {[info exists ::BSCAN(irlen)]} { set irlen $::BSCAN(irlen) }

    set brlen "?"
    if {[info exists ::BSCAN(br_len)] && $::BSCAN(br_len) ne ""} { set brlen $::BSCAN(br_len) }

    set sample "??"
    if {[info exists ::BSCAN(op_sample)]} { set sample $::BSCAN(op_sample) }

    set extest "??"
    if {[info exists ::BSCAN(op_extest)]} { set extest $::BSCAN(op_extest) }

    set idcode "??"
    if {[info exists ::BSCAN(op_idcode)]} { set idcode $::BSCAN(op_idcode) }

    set bypass "??"
    if {[info exists ::BSCAN(op_bypass)]} { set bypass $::BSCAN(op_bypass) }
	
    puts [::c_title "BSCAN Tools v$ver"]
    puts [::c_dim   "Default: IRLEN=$irlen  BR_LEN=$brlen  SAMPLE=$sample  EXTEST=$extest  IDCODE=$idcode  BYPASS=$bypass"]
    
    puts [::c_sec "Quick commands:"]
    puts "  [::c_cmd bscan_load] <path>/device.bsd"
    puts "      Load BSDL, opcodes, length..."
    puts "  [::c_cmd bscan_idcode]"
    puts "      sequence: Run-Test/Idle -> Shift-IR(IDCODE) -> Capture-DR -> Shift-DR -> Run-Test/Idle"
    
    puts ""
    puts [::c_sec "Read:"]
    puts "      sequence: Run-Test/Idle -> Shift-IR(SAMPLE) -> Capture-DR -> Shift-DR -> Run-Test/Idle"
    puts "  [::c_cmd bscan_input]"
    puts "  [::c_cmd bscan_input] <columns>"
    puts "  [::c_cmd bscan_input] -reg"
    puts "  [::c_cmd bscan_input] -port <NAME>"
    puts "  [::c_cmd bscan_input] -function <observe_only|input|output2|output3|controlr>"
	puts "  [::c_cmd bscan_input] -noreset"
	puts "      Capture without TAP reset (keeps TAP state)."
	puts "      Example:"
	puts "        bscan_input"
	puts "        bscan_input 5"
	puts "        bscan_input -port CCLK_A8"
	puts "        bscan_input -function input"
	puts "        bscan_input 5 -port IO_L5 -function output3"
	puts "        bscan_input -reg"
	puts "        bscan_input -noreset"	
    puts ""
    puts [::c_sec "Drive:"]
    puts "      sequence: Run-Test/Idle -> Shift-IR(EXTEST) -> Shift-DR -> Run-Test/Idle"
    puts "  [::c_cmd bscan_output] <reg> <0|1|T> ... -s"
    puts "  [::c_cmd bscan_output] <pin> <0|1|Z|T> ... -n -s"
    puts "      T = toggle output (requires -count N)"
	puts "      Example:"
	puts "        bscan_output 210 0 211 1 -s"
	puts "        bscan_output M12 1 M11 0 -n -s"
	puts "        bscan_output M12 T -n -count 10 -s"	
    
    puts ""
    puts [::c_sec "MGT:"]
    puts "      sequence: Run-Test/Idle -> Shift-IR(TRAIN/PULSE) -> Shift-DR -> Run-Test/Idle"
    puts "  [::c_cmd bscan_output_mgt] <pin|reg> <0|1> -s -t"
    puts "  [::c_cmd bscan_output_mgt] <pin|reg> <0|1> -s -p"
    puts "      -t = TRAIN opcode, -p = PULSE opcode (if supported)"

    puts ""
    puts [::c_sec "MGT train test:"]
    puts "  [::c_cmd run_mgt_test] <cols> -count <N> -idle <M> -r <reg> <0|1> ?<reg> <0|1>...? -sample <reg> ?<reg>...? ?-p? ?-t?"
    puts "      <cols>   : columns per output row (1 = one per line)."
    puts "      -count   : number of train iterations."
    puts "      -idle    : RTI cycles between drive and sample"
	puts "      -r       : override bits of initial SAMPLE frame."
    puts "      -sample  : regs to monitor"
    puts "      -p       : use PULSE opcode."
    puts "      -t       : use TRAIN opcode (default)."
    puts ""
    puts "      sequence: SAMPLE -> Shift-IR(TRAIN/PULSE) -> (Shift-DR -> Run-Test/Idle*k ->"
    puts "                  -> Shift-IR(SAMPLE) -> Capture-DR -> Shift-DR -> Run-Test/Idle)*N"
	puts ""
	puts "      NOTE: use highest stable JTAG clock (high TCK recommended)."	
	puts ""
    puts "      example:"
    puts "        run_mgt_test 2 -count 10 -idle 50 -r 372 1 -sample 370 371"
    puts "        run_mgt_test 1 -count 100 -idle 200 -r 372 1 -sample 371 -p"
   
    puts ""
    puts [::c_sec "Drive + Capture:"]
    puts "      sequence: SAMPLE(base) -> Shift-IR(EXTEST) -> Shift-DR -> Run-Test/Idle*k -> Capture-DR -> Shift-DR -> Run-Test/Idle"
    puts "  [::c_cmd bscan_output_capture] -s <reg|pin> <val> <reg|pin> <val> ..."
    puts "  [::c_cmd bscan_output_capture] <columns> -s <reg|pin> <val> <reg|pin> <val> ..."
    puts "      options:"
    puts "        -r <reg...>        read specific registers"
    puts "        -reg               print all as reg:value (with colors)"
    puts "        -port <name>       filter by port"
    puts "        -function <type>   filter by cell function"
    puts "        -idle <N>          idle cycles before capture"
    puts "      note:"
    puts "        <columns> is optional, default is 10"
	puts "      usage:"
    puts "    	  Drives selected outputs then captures inputs while remaining in EXTEST."
    puts "    	  Useful for detecting shorts, opens and stuck pins on DC nets."
	puts "      example:"
	puts "        bscan_output_capture -s 318 0 319 1 -r 320 323"
	puts "        bscan_output_capture 5 -s IO_C10 1 IO_D10 Z"
	puts "        bscan_output_capture -s IO_M12 1 -port IO_M12 -function input"
	puts "        bscan_output_capture -s 318 0 319 1 -idle 50 -reg"	

    puts ""
    puts [::c_sec "Capacitive Test:"]
    puts "      sequence: preload -> Shift-IR(EXTEST) -> Shift-DR(release Z) -> N x {Capture-DR -> Shift-DR -> Run-Test/Idle*gap}"
    puts "  [::c_cmd bscan_cap_test] <pin> -n ?options?"
    puts "      options:"
    puts "        -count <N>         number of samples (default 10)"
    puts "        -gap <N>           JTAG clocks between samples"
    puts "      usage:"
    puts "        Capacitive connection test using boundary scan."
    puts "        Drive pin to 0/1, release to Z, then sample repeatedly."
    puts "      timing:"
    puts "        Tsample ~= (BR_LEN + gap) / fJTAG"
    puts "      examples:"
    puts "        bscan_output IO_M11 1 -n -s"
    puts "        bscan_cap_test IO_M11 -n -count 10 -gap 0"
    puts ""
    puts "        bscan_output IO_M11 0 -n -s"
    puts "        bscan_cap_test IO_M11 -n -count 80 -gap 100"

    puts ""
    puts [::c_sec "SPI via Boundary Scan:"]
    puts "      sequence: Shift-IR(EXTEST) -> Shift-DR(frames) -> Capture-DR(MISO) -> Shift-DR(frames)"
    puts "  [::c_cmd bscan_spi_cfg] SCK=<pin> MOSI=<pin> MISO=<pin|x> CS=<pin> ?CPOL=0|1? ?CPHA=0|1?"
    puts "  [::c_cmd bscan_spi] -w <byte> ?<byte> ...? ?-r <n>?"
    puts "      setup:"
    puts "        1) configure SPI pins with bscan_spi_cfg"
    puts "        2) perform transfer with bscan_spi"
    puts "      SPI mode:"
    puts "        CPOL=<0|1>         clock polarity (default 0)"
    puts "        CPHA=<0|1>         clock phase    (default 0)"
	puts "    	  PRE_IDLE=<usec>      delay after preset apply before CS low"
	puts "        CS_SETUP_IDLE=<usec> delay after CS low before first clock"
	puts "    	  SET_0=<pin>          drive pins to 0 during SPI"
	puts "    	  SET_1=<pin>          drive pins to 1 during SPI"
	puts "  	notes:"
	puts "   	 PRE_IDLE and CS_SETUP_IDLE are delays in microseconds (no TCK toggling)."
	puts "    	 Preset pins remain driven (not Z) for the entire SPI sequence."
    puts "      options:"
    puts "        -w <byte>...       write byte(s) (hex)"
    puts "        -r <n>             read n bytes"
    puts "      examples:"
	puts "        bscan_spi_cfg -clear"
    puts "        bscan_spi_cfg SCK=IO_M10 MOSI=IO_M11 MISO=IO_M12 CS=IO_M13"
	puts "        bscan_spi_cfg SET_0=IO_M12 SET_1=IO_C12"
    puts "        bscan_spi -w 0x90"
    puts "      example SNOR read ID:"
	puts "        bscan_spi_cfg SCK=CCLK_A8 MISO=IO_B12 MOSI=IO_B11 CS=IO_C11 CPOL=0 CPHA=0"
    puts "        bscan_spi -w 0x90 0x00 0x00 0x00 -r 2"
    puts ""
    puts [::c_sec "I2C via Boundary Scan:"]
    puts "      sequence: Shift-IR(EXTEST) -> Shift-DR(frames) -> Capture-DR(ACK/SDA) -> Shift-DR(frames)"
    puts "  [::c_cmd bscan_i2c_cfg] SCL=<pin> SDA=<pin>"
    puts "  [::c_cmd bscan_i2cdetect] <addr> -w|-r"
    puts "  [::c_cmd bscan_i2cset] <addr> <reg> ?<byte> ...?"
    puts "  [::c_cmd bscan_i2cget] <addr> <n> -r|-w"
    puts "  [::c_cmd bscan_i2cget] <addr> <reg> <n> -r|-w ?-rs?"
    puts "      setup:"
    puts "        1) configure I2C pins with bscan_i2c_cfg"
    puts "        2) detect device with bscan_i2cdetect"
    puts "        3) access registers with bscan_i2cset / bscan_i2cget"
    puts "      protocol:"
    puts "        bscan_i2cdetect    START + ADDR(W|R) + ACK/NACK + STOP"
    puts "        bscan_i2cset       START + ADDR(W) + REG + DATA... + STOP"
    puts "        bscan_i2cget       START + ADDR(W|R) + DATA... + STOP"
    puts "        bscan_i2cget reg   START + ADDR(W|R) + REG + DATA... + STOP"
    puts "        bscan_i2cget -rs   START + ADDR(W) + REG + REPEATED START + ADDR(W|R) + DATA... + STOP"
    puts "      options:"
    puts "        -w                 use address with write bit"
    puts "        -r                 use address with read bit"
    puts "        -rs                use repeated start on register read"
    puts "      examples:"
    puts "        bscan_i2c_cfg SCL=IO_A13 SDA=IO_A12"
    puts "        bscan_i2cdetect 0x48 -w"
    puts "        bscan_i2cdetect 0x48 -r"
    puts "        bscan_i2cset 0x48 0x01"
    puts "        bscan_i2cset 0x48 0x01 0x80"
    puts "        bscan_i2cget 0x48 1 -r"
    puts "        bscan_i2cget 0x48 1 -w"
    puts "        bscan_i2cget 0x48 0x00 1 -r"
    puts "        bscan_i2cget 0x48 0x00 1 -w"
    puts "        bscan_i2cget 0x48 0x00 2 -r -rs"	
    puts "  [::c_cmd bscan_i2cscan] -w|-r"
    puts "      Scan I2C bus (0x00..0x7F) using address detect."
    puts "      note:"
    puts "        uses bscan_i2cdetect internally (one line per address)"
    puts "      examples:"
    puts "        bscan_i2c_cfg SCL=IO_A13 SDA=IO_A12"
	puts "        bscan_i2cscan -w"
    puts "        bscan_i2cscan -r"

    puts ""
    puts [::c_sec "Output3 Scan:"]
    puts "      sequence: Shift-IR(EXTEST) -> Shift-DR(drive pin=1) -> Capture-DR(all input) ->"
    puts "                Shift-DR(drive pin=0) -> Capture-DR(all input)"
    puts "  [::c_cmd bscan_output3_scan] ?<pin> <pin> ...? ?-exclude {<pin> <pin> ...}?"
    puts "      options:"
    puts "        -exclude {<pin>...} exclude the listed pins from monitoring"
	puts "        -include {<pin>...} monitor only the listed pins"
    puts "      usage:"
    puts "        Test output3 pins by driving 1 and 0, then capture all input cells."
    puts "        Reports whether the selected pin follows correctly and whether"
    puts "        other pins move together (FOLLOW), useful to detect shorts/coupling."
	puts "        PASS:    pin follows correctly and no other pins move."
	puts "        WARNING: pin follows correctly but other pins move together (FOLLOW)."
	puts "        FAIL:    pin does not follow correctly (drive error)."	
    puts "      note:"
    puts "        Multiple pins can be passed in the test list."
    puts "        Multiple pins can also be excluded using a Tcl list in braces."
    puts "      examples:"
    puts "        bscan_output3_scan"
    puts "        bscan_output3_scan IO_A13"
    puts "        bscan_output3_scan IO_A13 IO_M12"
    puts "        bscan_output3_scan -exclude {IO_D1}"
    puts "        bscan_output3_scan -exclude {IO_D1 CCLK_A8 DONE_P9}"
    puts "        bscan_output3_scan IO_A13 IO_M12 -exclude {IO_D1}"
    puts "        bscan_output3_scan IO_A13 IO_M12 -exclude {IO_D1 CCLK_A8}"
	puts "        bscan_output3_scan IO_A13 IO_M12 -include {IO_A13 IO_M12 IO_M11}"

    puts ""
    puts [::c_sec "Advanced:"]
    puts "  [::c_cmd parray] ::BSCAN"
    puts "      Show current parameters."
    
    puts ""
    puts [::c_sec "Manual override:"]
    puts "  You can manually change parameters if needed."
    puts "  Example:"
    puts "      set BSCAN(irlen) 10"
    puts "      set BSCAN(br_len) 2048"
    
    puts ""
    puts "  Legend: IR=Instruction Register, DR=Data Register, k=RTI cycles, N=iterations"
	puts "  JTAG scan state flow:"
	puts "	  drshift : IDLE -> SELECT-DR -> CAPTURE-DR -> SHIFT-DR -> EXIT1-DR -> UPDATE-DR -> IDLE"
	puts "	  irshift : IDLE -> SELECT-DR -> SELECT-IR -> CAPTURE-IR -> SHIFT-IR -> EXIT1-IR -> UPDATE-IR -> IDLE"
    puts ""
    puts [::c_sec "Help:"]
    puts "   [::c_cmd bscan]"
	
	
}

proc bscan {args} {
	bscan_banner
}


# ---------- CONNECT (always) ----------
proc bscan_connect {} {
    connect -url $::BSCAN(url)
	set chain_j [jtag targets]
	puts [::c_sec "BSCAN JTAG chain"]
	puts $chain_j 
    jtag targets -set $::BSCAN(target)
    jtag lock
    puts "BSCAN connected url=$::BSCAN(url) target=$::BSCAN(target)"
	bscan_banner
}

# ---------- CREATE SEQUENCE ----------
proc bscan_seq_new {} {
    set seq [jtag sequence]
    set ::ACTIVE_SEQ $seq
    return $seq
}

# ---------- DELETE SEQUENCE ----------
proc bscan_seq_del {} {
    if {[info exists ::ACTIVE_SEQ]} {
        catch {$::ACTIVE_SEQ delete}
        unset ::ACTIVE_SEQ
        puts "Sequence closed"
    }
}

# ---------- AUTO CONNECT ON SOURCE (always) ----------
bscan_connect

puts "BSCAN tools ready."

# Swap byte order: AABBCCDD -> DDCCBBAA
proc _swap32_bytes {hex8} {
    set h [string toupper $hex8]
    # normalizza a 8 hex
    if {[string length $h] < 8} {
        set h [format "%08s" $h]
        regsub -all { } $h 0 h
    }
    # DD CC BB AA
    return "[string range $h 6 7][string range $h 4 5][string range $h 2 3][string range $h 0 1]"
}

# Decodifica IDC# IEEE 1149.1 fields: version(4) | part_number(16) | manufacturer(11) | required(1)
# IEEE 1149.1 IDCODE decode (vendor-neutral)
# Fields: version(4) | part_number(16) | manufacturer(11) | required(1)
# NOTE: XSDB may return byte-swapped words; we canonicalize with _swap32_bytes.
proc idcode_decode_ieee {id_hex} {
    regsub -nocase {^0x} $id_hex "" id_hex
    set raw [string toupper $id_hex]

    # XSDB often returns byte-swapped: canonicalize
    set canon [_swap32_bytes $raw]
    scan $canon %x id

    set required     [expr {$id & 1}]
    set manufacturer [expr {($id >> 1)  & 0x7FF}]
    set part16       [expr {($id >> 12) & 0xFFFF}]
    set version      [expr {($id >> 28) & 0xF}]

    puts " IDCODE raw   = 0x$raw"
    puts " IDCODE canon = 0x$canon (byte-swapped)"
    puts "  required(LSB)   = $required required by 1149.1"
    puts [format "  version         = %d (0x%X)" $version $version]
    puts [format "  part_number     = %d (0x%04X)" $part16 $part16]
    #puts [format "  manufacturer    = %d (0x%03X)" $manufacturer $manufacturer]
	
	set mhex  [format "0x%03X" $manufacturer]
	set mname [jedec_mfr_name_from_11bit $manufacturer]
	puts [format "  manufacturer    = %d (%s) %s" $manufacturer $mhex $mname]
	
	
}


# Legge IDCODE via JTAG e lo decodifica + stampa attesi da BSDL se disponibili
proc bscan_idcode {} {

    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE

    $seq irshift -hex $::BSCAN(irlen) $::BSCAN(op_idcode)
    $seq drshift -capture 32

    set raw_id [$seq run -hex -single]
    $seq delete

    # Canonicalize XSDB byte order for display
    regsub -nocase {^0x} $raw_id "" raw_id
    set raw_id [string toupper $raw_id]
    set canon [_swap32_bytes $raw_id]

    
	puts $::BSCAN(idcode_register_hex_str)
	puts "JTAG read:"
    puts " IDCODE = 0x$canon"
    # Decode using raw value (decoder will canonicalize internally)
    idcode_decode_ieee $raw_id
    return
}

# =========================================
# Print only BSDL
# =========================================
# =========================================
# bscan_file: parse BSDL (simple Xilinx format)
# Prints: BOUNDARY_LENGTH, IRLEN, SAMPLE/EXTEST/IDCODE/BYPASS in HEX
# =========================================
# Comando unico: imposta il BSDL attivo + stampa/aggiorna config
proc bscan_load {bsdl_path} {
    set ::BSCAN(bsdl) $bsdl_path
    bscan_file $bsdl_path
    return
}

proc _bin2hex {bin} {
   regsub -all {\s+} $bin "" bin
   set pad [expr {(4 - ([string length $bin] % 4)) % 4}]
   if {$pad > 0} { set bin "[string repeat 0 $pad]$bin" }
   set hex ""
   for {set i 0} {$i < [string length $bin]} {incr i 4} {
       set nib [string range $bin $i [expr {$i+3}]]
       # Convert 4-bit binary nibble to int in a portable way
       set v 0
       if {[catch {scan $nib %b v}]} {
           # fallback manual if %b is not available
           set v 0
           foreach ch [split $nib ""] {
               set v [expr {$v*2 + ($ch eq "1")}]
           }
       }
       append hex [format %X $v]
   }
   regsub {^0+} $hex "" hex
   if {$hex eq ""} { set hex "0" }
   return [string toupper $hex]
}
proc _find_opcode_hex {txt name} {
   set bin ""
   # More robust regex for BSDL: "NAME (010101)"
   set re [format {\"?%s\"?[[:space:]]*\(([01]+)\)} [string toupper $name]]
   if {[regexp -nocase $re $txt -> bin]} {
       set h [_bin2hex $bin]
       # pad to expected hex width: ceil(nbits/4)
       set nbits [string length $bin]
       set nhex  [expr {int( ($nbits + 3) / 4 )}]
       while {[string length $h] < $nhex} {
           set h "0$h"
       }
       return [string toupper $h]
   }
   return "??"
}

proc bscan_file {bsdl_path} {
    set f [open $bsdl_path r]
    set txt [read $f]
    close $f

    # BOUNDARY_LENGTH
    set bl "NOT FOUND"
    if {[regexp -nocase {BOUNDARY_LENGTH\s+of\s+\w+\s*:\s*entity\s+is\s+([0-9]+)} $txt -> bl]} {}
    if {[regexp -nocase {attribute\s+BOUNDARY_LENGTH\s+of\s+\w+\s*:\s*entity\s+is\s+([0-9]+)} $txt -> bl]} {}

    # IRLEN (INSTRUCTION_LENGTH)
    set irlen "NOT FOUND"
    if {[regexp -nocase {INSTRUCTION_LENGTH\s+of\s+\w+\s*:\s*entity\s+is\s+([0-9]+)} $txt -> irlen]} {}
    if {[regexp -nocase {attribute\s+INSTRUCTION_LENGTH\s+of\s+\w+\s*:\s*entity\s+is\s+([0-9]+)} $txt -> irlen]} {}

    # Opcodes (Xilinx style: NAME (bits))
    set sample [_find_opcode_hex $txt "SAMPLE"]
    # PRELOAD è spesso "Same as SAMPLE"
    if {$sample eq "??"} { set sample [_find_opcode_hex $txt "PRELOAD"] }

    set extest [_find_opcode_hex $txt "EXTEST"]
    set idcode [_find_opcode_hex $txt "IDCODE"]
    set bypass [_find_opcode_hex $txt "BYPASS"]
	set train [_find_opcode_hex $txt "EXTEST_TRAIN"]
	set pulse [_find_opcode_hex $txt "EXTEST_PULSE"]

    # ---------------------------------
    # Override default opcodes only if found
    # ---------------------------------
    if {$bl ne "NOT FOUND"} { set ::BSCAN(br_len) $bl }
	if {$sample ne "??"} { set ::BSCAN(op_sample) $sample }
    if {$extest ne "??"} { set ::BSCAN(op_extest) $extest }
    if {$idcode ne "??"} { set ::BSCAN(op_idcode) $idcode }
    if {$bypass ne "??"} { set ::BSCAN(op_bypass) $bypass }
    if {$irlen ne "NOT FOUND"} { set ::BSCAN(irlen) $irlen }
    if {$train ne "??"}  { set ::BSCAN(op_train) $train }
    if {$pulse ne "??"}  { set ::BSCAN(op_pulse) $pulse }


    puts " BSDL: $bsdl_path"
	puts " BOUNDARY_LENGTH = $bl IRLEN=$irlen SAMPLE=$sample EXTEST=$extest IDCODE=$idcode BYPASS=$bypass TRAIN=$train PULSE=$pulse"

    # ---------------------------------
    
	# ---------------------------------
	# IDCODE_REGISTER (IEEE 1149.1)
	#   - find "IDCODE_REGISTER" declaration up to ';'
	#   - concatenate all quoted bitstrings
	#   - convert each quoted part to hex when pure 0/1; otherwise return the first non-binary char
	#   - decode standard fields: 4/16/11/1
	# ---------------------------------
	set idc_pos [string first "IDCODE_REGISTER" $txt]
	if {$idc_pos < 0} {
		set low [string tolower $txt]
		set idc_pos [string first "idcode_register" $low]
	}
	
	if {$idc_pos >= 0} {
    set idc_end [string first ";" $txt $idc_pos]
    if {$idc_end > $idc_pos} {
        set idc_block [string range $txt $idc_pos $idc_end]

        # remove VHDL comments ('--' to end-of-line)
        regsub -all {\-\-[^\r\n]*} $idc_block "" idc_block

        # extract all quoted strings between double-quotes
        set parts {}
        set start2 0
        set re2 {\"([^\"]+)\"}
        while {[regexp -indices -start $start2 $re2 $idc_block mm gg]} {
            set s2 [lindex $gg 0]
            set e2 [lindex $gg 1]
            set p [string range $idc_block $s2 $e2]
            regsub -all {\s+} $p "" p
            lappend parts $p
            set start2 [expr {[lindex $mm 1] + 1}]
        }

        # helper: binary->hex; if any char != 0/1 return that char (first found)
        proc ::_idc_bits_to_hex_or_char {bits} {
            set b [string toupper $bits]
            regsub -all {\s+} $b "" b
            if {$b eq ""} { return "" }
            if {[regexp {[^01]} $b bad]} { return $bad }
            scan $b %b v
            return [format %X $v]
        }

        if {[llength $parts] > 0} {
            set idc_bits [join $parts ""]

            set hex_parts {}
            foreach p $parts {
                lappend hex_parts "0x[_idc_bits_to_hex_or_char $p]"
            }
            puts [format "  IDCODE_REGISTER parts = %s" [join $hex_parts " & "]]

            # Display-only: replace X with 0 in the concatenated bitstring (keeps other prints unchanged)
		set idc_bits_disp [string map {X 0 x 0} $idc_bits]
		# For the bits line, always show a numeric hex (computed from disp bits)
		set idc_hex_disp "0"
		if {[regexp {^[01]+$} $idc_bits_disp]} {
			scan $idc_bits_disp %b _idc_tmp
			set idc_hex_disp [format "%08X" $_idc_tmp]
		} else {
			# Should not happen after X->0, but keep safe
			set idc_hex_disp "????????"
		}
		puts [format "  IDCODE_REGISTER bits  = %s (0x%s)" $idc_bits_disp $idc_hex_disp]
		set ::BSCAN(idcode_register_hex_str) [format " IDCODE_bsdl = (0x%s)" $idc_hex_disp]
		
            if {[string length $idc_bits] == 32} {
                set v_bits [string range $idc_bits 0 3]
                set p_bits [string range $idc_bits 4 19]
                set m_bits [string range $idc_bits 20 30]
                set r_bit  [string index $idc_bits 31]

                set v_hex "0x[_idc_bits_to_hex_or_char $v_bits]"
                set p_hex "0x[_idc_bits_to_hex_or_char $p_bits]"
                set m_hex "0x[_idc_bits_to_hex_or_char $m_bits]"
                set r_hex [_idc_bits_to_hex_or_char $r_bit]

                set ::BSCAN_EXPECT(idcode_hex)        "0x$idc_hex_disp"
                set ::BSCAN_EXPECT(required)         $r_hex
                set ::BSCAN_EXPECT(version_hex)      $v_hex
                set ::BSCAN_EXPECT(part_hex)         $p_hex
                set ::BSCAN_EXPECT(manufacturer_hex) $m_hex

                puts [format "  IDCODE std: ver=%s part=%s mfg=%s req=%s" $v_hex $p_hex $m_hex $r_hex]
            }
        }
    }
}


	return
}

# Cache: index -> "TYPE|PORT|FUNC"
proc bscan_build_cell_cache {} {
   if {![info exists ::BSCAN(bsdl)] || [string trim $::BSCAN(bsdl)] eq ""} {
       puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
       return 0
   }
   set path [string trim $::BSCAN(bsdl)]
   if {[catch {open $path r} f]} {
       puts "ERROR: cannot open BSDL file: $path"
       puts "DETAIL: $f"
       return 0
   }
   set txt [read $f]
   close $f
   # reset cache
   catch {array unset ::BSCAN_CELL}
   array set ::BSCAN_CELL {}
   # Match inside the quoted BSDL strings:
   # "   0 (BC_2, *, controlr, 1),"
   # "   1 (BC_2, CCLK_A8, output3, X, 0, 1, Z),"
   # "2312 (AC_2, MGTYTXP0_127, OUTPUT2, X),"
   #
   # Capture: idx, type, port, func
   set re {"\s*([0-9]+)\s*\(\s*([A-Za-z]{2}_[0-9]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,}
   set start 0
   while {[regexp -indices -start $start $re $txt m idxi typei porti funci]} {
       set idx  [string trim [string range $txt [lindex $idxi 0]  [lindex $idxi 1]]]
       set typ  [string trim [string range $txt [lindex $typei 0] [lindex $typei 1]]]
       set port [string trim [string range $txt [lindex $porti 0] [lindex $porti 1]]]
       set fun  [string trim [string range $txt [lindex $funci 0] [lindex $funci 1]]]
       # normalize
       set typ  [string toupper [string trim $typ]]
       set port [string toupper [string trim $port]]
       set fun  [string tolower [string trim $fun]]
       set ::BSCAN_CELL($idx) "$typ|$port|$fun"
       set start [expr {[lindex $m 1] + 1}]
   }
   set ::BSCAN_CELL_READY 1
   return 1
}
# Return "TYPE|PORT|FUNC" or "" if missing
proc bscan_cell_info {idx} {
   if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
       if {![bscan_build_cell_cache]} { return "" }
   }
   if {[info exists ::BSCAN_CELL($idx)]} {
       return $::BSCAN_CELL($idx)
   }
   return ""
}
# =========================================
# Print boundary input register table
#
# -reg : print only idx:value (no BSDL lookup, no filters)
# no -reg : print idx:value TYPE,PORT,FUNC
#
# Filters (only when NOT -reg):
#   -port <PORTNAME>
#   -function <FUNCNAME>
#
# Examples:
# bscan_input
# bscan_input 5
# bscan_input -port IO_M12
# bscan_input 5 -port IO_M12 -function output3
# bscan_input -reg
# ========================================= "
proc bscan_input {args} {
   # defaults
   set perline 10
   set filter_port ""
   set filter_func ""
   set reg_only 0
   set do_reset 1
   # parse args
   set ai 0
   while {$ai < [llength $args]} {
       set a [lindex $args $ai]
       if {$ai == 0 && [string is integer -strict $a]} {
           set perline $a
           incr ai
           continue
       }
       switch -- $a {
           -port {
               incr ai
               if {$ai >= [llength $args]} { puts "ERROR: -port needs value"; return }
               set filter_port [string toupper [string trim [lindex $args $ai]]]
           }
           -function {
               incr ai
               if {$ai >= [llength $args]} { puts "ERROR: -function needs value"; return }
               set filter_func [string tolower [string trim [lindex $args $ai]]]
           }
           -reg {
               set reg_only 1
           }
           -noreset {
               set do_reset 0
           }		   
           default {
               puts "ERROR: unknown arg '$a' (use: bscan_input ?N? ?-port P? ?-function F? ?-reg? ?-noreset?)"
               return
           }
       }
       incr ai
   }
   # need boundary length
   if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq "NOT FOUND" || [string trim $::BSCAN(br_len)] eq ""} {
       puts "ERROR: ::BSCAN(br_len) not set. Run: bscan_load <file.bsd> first."
       return
   }
   set br_len $::BSCAN(br_len)
   # if not -reg, ensure cache exists
   if {!$reg_only} {
       if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
           if {![bscan_build_cell_cache]} { return }
       }
   }
   # acquire SAMPLE + CAPTURE
   set seq [jtag sequence]
   if {$do_reset} {
       $seq state RESET
   }
   $seq state IDLE
   set irlen $::BSCAN(irlen)
   set op_sample [format %02X [expr "0x$::BSCAN(op_sample)"]]
   $seq irshift -state IDLE -hex $irlen $op_sample
   $seq drshift -state IDLE -capture $br_len
   set data [$seq run -bits -single]
   $seq delete
   # trim
   if {[string length $data] > $br_len} {
       set data [string range $data 0 [expr {$br_len-1}]]
   }
   set n [string length $data]
   # prev snapshot
   if {![info exists ::PREV_DATA] || [string length $::PREV_DATA] != $n} {
       set ::PREV_DATA $data
   }
   # colors (bit only)
   proc ::c_orange {s} { return "\033\[38;5;208m$s\033\[0m" }
   proc ::c_cyan   {s} { return "\033\[36m$s\033\[0m" }
   set line ""
   set count 0
   for {set idx 0} {$idx < $n} {incr idx} {
       # filtering only when NOT -reg
       set suffix ""
       if {!$reg_only} {
           set info [bscan_cell_info $idx]
           if {$info eq ""} {
               continue
           }
           set parts [split $info "|"]
           set typ  [string toupper [string trim [lindex $parts 0]]]
           set port [string toupper [string trim [lindex $parts 1]]]
           set fun  [string tolower [string trim [lindex $parts 2]]]
           # apply filters
           if {$filter_port ne "" && $port ne $filter_port} { continue }
           if {$filter_func ne "" && $fun  ne $filter_func} { continue }
           set suffix " $typ,$port,$fun"
       }
       # value + color
       set cur  [string index $data $idx]
       set prev [string index $::PREV_DATA $idx]
       if {$cur ne $prev} {
           set v [::c_cyan $cur]
       } elseif {$cur eq "0"} {
           set v [::c_orange $cur]
       } else {
           set v $cur
       }
       # format:
       # -reg: idx:value
       # else: idx:value TYPE,PORT,FUNC
       append line [format "%d:%s%s" $idx $v $suffix]
       incr count
       if {$count == $perline} {
           puts $line
           set line ""
           set count 0
       } else {
           append line " | "
       }
   }
   # leftover line
   if {[string trim $line] ne ""} {
       if {[string match "* | " $line]} {
           set line [string range $line 0 end-3]
       }
       puts $line
   }
   set ::PREV_DATA $data
   return
}


# Build map: cell index -> "port,function" ONLY for BC_2 lines
proc bscan_parse_bc2_map {} {

    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Use: bscan_load <file.bsd> (or set ::BSCAN(bsdl))"
        return 0
    }

    set f [open $::BSCAN(bsdl) r]
    set txt [read $f]
    close $f

    array unset ::BSCAN_BC2_MAP
    array set ::BSCAN_BC2_MAP {}

    # Match lines like:
    # "   2 (BC_2, CCLK_A8, input, X)," &
    # captures: idx, port, func
    set re {"\s*([0-9]+)\s*\(BC_2,\s*([^,]+),\s*([^,]+),}
    set start 0
    while {[regexp -indices -start $start $re $txt m idxi porti funci]} {
        set idx  [string range $txt [lindex $idxi 0]  [lindex $idxi 1]]
        set port [string trim [string range $txt [lindex $porti 0] [lindex $porti 1]]]
        set func [string trim [string range $txt [lindex $funci 0] [lindex $funci 1]]]
        set ::BSCAN_BC2_MAP($idx) "$port,$func"
        set start [expr {[lindex $m 1] + 1}]
    }

    set ::BSCAN_BC2_READY 1
    return 1
}
# "

proc bscan_output {args} {
   # parse flags: -s apply, -n name mode, -count N, -start 0/1
   set do_send 0
   set name_mode 0
   set count ""          ;# if set -> toggle mode
   set start_level 1
   set tokens {}
   set i 0
   while {$i < [llength $args]} {
       set a [lindex $args $i]
       if {$a eq "-s"} {
           set do_send 1
       } elseif {$a eq "-n"} {
           set name_mode 1
       } elseif {$a eq "-count"} {
           incr i
           if {$i >= [llength $args]} { puts "ERROR: -count needs value"; return }
           set count [lindex $args $i]
       } elseif {$a eq "-start"} {
           incr i
           if {$i >= [llength $args]} { puts "ERROR: -start needs 0 or 1"; return }
           set start_level [lindex $args $i]
       } else {
           lappend tokens $a
       }
       incr i
   }
   # validate pairs
   if {[llength $tokens] < 2 || ([llength $tokens] % 2) != 0} {
       puts "ERROR: usage:"
       puts "  bscan_output <reg> <val> ?<reg> <val>... ?-s? ?-count N?"
       puts "  bscan_output <PIN> <val> ?<PIN> <val>... ?-n? ?-s? ?-count N?"
       puts "  val: 0 | 1 | Z (name-mode) | T (toggle with -count)"
       return
   }
   # if -count used: must be integer > 0 and requires -s
   if {$count ne ""} {
       if {![string is integer -strict $count] || $count <= 0} {
           puts "ERROR: -count must be a positive integer"
           return
       }
       if {!$do_send} {
           puts "ERROR: -count requires -s (apply)"
           return
       }
       if {$start_level ne "0" && $start_level ne "1"} {
           puts "ERROR: -start must be 0 or 1"
           return
       }
   }
   # need boundary length
   if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq "NOT FOUND" || $::BSCAN(br_len) eq ""} {
       puts "ERROR: ::BSCAN(br_len) not set. Run: bscan_load <file.bsd> (or bscan_file <file.bsd>)"
       return
   }
   set br_len $::BSCAN(br_len)
   # =========================================================
   # 1) acquire SAMPLE + CAPTURE  (AS REQUESTED)
   # =========================================================
   set seq [jtag sequence]
   $seq state RESET
   $seq state IDLE
   set irlen $::BSCAN(irlen)
   set op_sample [format %02X [expr "0x$::BSCAN(op_sample)"]]
   $seq irshift -state IDLE -hex $irlen $op_sample
   $seq drshift -state IDLE -capture $br_len
   set data [$seq run -bits -single]
   if {[string length $data] > $br_len} {
       set data [string range $data 0 [expr {$br_len-1}]]
   }
   # =========================================================
   # 2) Apply pairs (regs) OR pin names (-n)
   #    Support T only when -count is used
   # =========================================================
   set toggle_regs {}         ;# reg indices to toggle (reg-mode)
   set toggle_outidx {}       ;# output3 indices to toggle (name-mode)
   set toggle_ctl_fix {}      ;# list of {ctlidx enable} to keep driver enabled (name-mode)
   if {!$name_mode} {
       # reg mode: tokens = {reg val reg val ...}
       for {set k 0} {$k < [llength $tokens]} {incr k 2} {
           set reg [lindex $tokens $k]
           set val [string toupper [lindex $tokens [expr {$k+1}]]]
           if {![string is integer -strict $reg] || $reg < 0 || $reg >= $br_len} {
               puts "ERROR: invalid reg '$reg' (0..[expr {$br_len-1}])"
               catch {$seq delete}
               return
           }
           if {$val eq "T"} {
               if {$count eq ""} {
                   puts "ERROR: val 'T' requires -count N"
                   catch {$seq delete}
                   return
               }
               lappend toggle_regs $reg
               # don't set now; set per-frame
               continue
           }
           if {$val ne "0" && $val ne "1"} {
               puts "ERROR: invalid val '$val' for reg $reg (must be 0 or 1, or T with -count)"
               catch {$seq delete}
               return
           }
           set data [string replace $data $reg $reg $val]
       }
   } else {
       # name mode: tokens = {PIN val PIN val ...} where val is 0/1/Z/T
       for {set k 0} {$k < [llength $tokens]} {incr k 2} {
           set pin [lindex $tokens $k]
           set val [string toupper [lindex $tokens [expr {$k+1}]]]
           if {$val ne "0" && $val ne "1" && $val ne "Z" && $val ne "T"} {
               puts "ERROR: invalid value '$val' for pin $pin (use 0,1,Z or T with -count)"
               catch {$seq delete}
               return
           }
           if {$val eq "T" && $count eq ""} {
               puts "ERROR: val 'T' requires -count N"
               catch {$seq delete}
               return
           }
           set info [bscan_get_output3_cells $pin]
           if {$info eq ""} {
               puts "ERROR: pin $pin not found as output3 in BSDL (only output3 supported)"
               catch {$seq delete}
               return
           }
           lassign $info port outidx ctlidx disval
           # control enable is NOT disval
           set enable [expr {$disval eq "1" ? 0 : 1}]
           if {$val eq "Z"} {
               # Hi-Z: control = disval
               set data [string replace $data $ctlidx $ctlidx $disval]
               # output don't care
           } elseif {$val eq "T"} {
               # Toggle output3: force driver enabled, toggle outidx per-frame
               set data [string replace $data $ctlidx $ctlidx $enable]
               lappend toggle_outidx $outidx
               lappend toggle_ctl_fix $ctlidx $enable
           } else {
               # Drive 0/1: control = enable, output = val
               set data [string replace $data $ctlidx $ctlidx $enable]
               set data [string replace $data $outidx $outidx $val]
           }
       }
   }
   # if no -s, return modified image (no print)
   if {!$do_send} {
       catch {$seq delete}
       return
   }
   # =========================================================
   # 3) EXTEST + DRUPDATE
   #    If -count: queue N DRUPDATE frames toggling regs/outidx
   # =========================================================
   set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]
   $seq state RESET
   $seq state IDLE
   $seq irshift -state IDLE -hex $irlen $op_extest
   $seq state IDLE
   if {$count eq ""} {
       # single apply (original behavior)
       $seq drshift -state IDLE -bits $br_len $data
       $seq state IDLE
       set _ [$seq run -bits -single]
       catch {$seq delete}
       return
   }
   # toggle mode: buffer frames (NO puts inside loop)
   for {set f 0} {$f < $count} {incr f} {
       set level [expr {($f % 2) == 0 ? $start_level : (1-$start_level)}]
       set frame_data $data
       # reg-mode toggles
       foreach r $toggle_regs {
           set frame_data [string replace $frame_data $r $r $level]
       }
       # name-mode toggles (output3 only)
       foreach o $toggle_outidx {
           set frame_data [string replace $frame_data $o $o $level]
       }
       # (optional safety) re-assert control enables each frame for toggled pins
       # keeps things deterministic if anything stomps bits (shouldn't, but cheap)
       for {set t 0} {$t < [llength $toggle_ctl_fix]} {incr t 2} {
           set cidx [lindex $toggle_ctl_fix $t]
           set en   [lindex $toggle_ctl_fix [expr {$t+1}]]
           set frame_data [string replace $frame_data $cidx $cidx $en]
       }
       $seq drshift -state IDLE -bits $br_len $frame_data
   }
   $seq state IDLE
   set _ [$seq run -bits -single]
   catch {$seq delete}
   return
}


# Cache parsing per OUTPUT3: IO_<PIN> -> out_idx, ctl_idx, disval
proc bscan_parse_output3_map {} {
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd>"
        return 0
    }

    set f [open $::BSCAN(bsdl) r]
    set txt [read $f]
    close $f

    array unset ::BSCAN_OUT3_OUT
    array unset ::BSCAN_OUT3_CTL
    array unset ::BSCAN_OUT3_DISVAL

    # Match righe tipo:
    # " 211 (BC_2, IO_M12, output3, X, 210, 1, Z),"
    # catturo: outidx, port, ctlidx, disval
    set re {"\s*([0-9]+)\s*\(BC_2,\s*([^,]+),\s*output3,\s*[^,]+,\s*([0-9]+),\s*([01]),\s*Z\)}
    set start 0
    while {[regexp -indices -start $start $re $txt m outi porti ctli disi]} {
        set outidx [string range $txt [lindex $outi 0]  [lindex $outi 1]]
        set port   [string trim [string range $txt [lindex $porti 0] [lindex $porti 1]]]
        set ctlidx [string range $txt [lindex $ctli 0]  [lindex $ctli 1]]
        set disval [string range $txt [lindex $disi 0]  [lindex $disi 1]]

        set ::BSCAN_OUT3_OUT($port) $outidx
        set ::BSCAN_OUT3_CTL($port) $ctlidx
        set ::BSCAN_OUT3_DISVAL($port) $disval

        set start [expr {[lindex $m 1] + 1}]
    }

    set ::BSCAN_OUT3_READY 1
    return 1
}

# Dato "M12" o "IO_M12" o "DONE_P9" ritorna: {port outidx ctlidx disval} oppure ""
proc bscan_get_output3_cells {pinname} {
    if {![info exists ::BSCAN_OUT3_READY] || $::BSCAN_OUT3_READY != 1} {
        if {![bscan_parse_output3_map]} { return "" }
    }

    set p [string toupper $pinname]

    # 1) prova nome esatto
    if {[info exists ::BSCAN_OUT3_OUT($p)]} {
        return [list $p $::BSCAN_OUT3_OUT($p) $::BSCAN_OUT3_CTL($p) $::BSCAN_OUT3_DISVAL($p)]
    }

    # 2) se non è già prefissato, prova anche IO_<name>
    if {![string match "IO_*" $p]} {
        set p2 "IO_$p"
        if {[info exists ::BSCAN_OUT3_OUT($p2)]} {
            return [list $p2 $::BSCAN_OUT3_OUT($p2) $::BSCAN_OUT3_CTL($p2) $::BSCAN_OUT3_DISVAL($p2)]
        }
    }

    return ""
}

# Mappa solo OUTPUT2: PORT -> cell index
proc bscan_parse_output2_map {} {
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd>"
        return 0
    }

    set f [open $::BSCAN(bsdl) r]
    set txt [read $f]
    close $f

    array unset ::BSCAN_OUT2_MAP
    array set ::BSCAN_OUT2_MAP {}

    # Esempio:
    # "2312 (AC_2, MGTYTXP0_127, OUTPUT2, X),"
    set re {"\s*([0-9]+)\s*\(AC_2,\s*([^,]+),\s*OUTPUT2,\s*X\)}
    set start 0
    while {[regexp -indices -start $start $re $txt m idxi porti]} {
        set idx  [string range $txt [lindex $idxi 0]  [lindex $idxi 1]]
        set port [string trim [string range $txt [lindex $porti 0] [lindex $porti 1]]]
        set ::BSCAN_OUT2_MAP([string toupper $port]) $idx
        set start [expr {[lindex $m 1] + 1}]
    }

    set ::BSCAN_OUT2_READY 1
    return 1
}

proc bscan_get_output2_reg {pinname} {
    if {![info exists ::BSCAN_OUT2_READY] || $::BSCAN_OUT2_READY != 1} {
        if {![bscan_parse_output2_map]} { return "" }
    }
    set p [string toupper $pinname]
    if {![info exists ::BSCAN_OUT2_MAP($p)]} {
        return ""
    }
    return $::BSCAN_OUT2_MAP($p)
}

proc bscan_output_mgt {args} {
   # flags
   set do_send 0
   set use_train 0
   set use_pulse 0
   set idle_count 1
   set tokens {}
   # parsing args (supporta: -s, -t, -p, -count N)
   for {set ai 0} {$ai < [llength $args]} {incr ai} {
       set a [lindex $args $ai]
       if {$a eq "-s"} {
           set do_send 1
       } elseif {$a eq "-t"} {
           set use_train 1
       } elseif {$a eq "-p"} {
           set use_pulse 1
       } elseif {$a eq "-count"} {
           incr ai
           if {$ai >= [llength $args]} {
               puts "ERROR: -count requires a number"
               return
           }
           set idle_count [lindex $args $ai]
           if {![string is integer -strict $idle_count] || $idle_count < 1} {
               puts "ERROR: -count must be an integer >= 1"
               return
           }
       } else {
           lappend tokens $a
       }
   }
   if {$use_train && $use_pulse} {
       puts "ERROR: use only one of -t and -p"
       return
   }
   # validate basic
   if {[llength $tokens] < 2 || ([llength $tokens] % 2) != 0} {
       puts "ERROR: usage:"
       puts "  bscan_output_mgt <reg> <val> ?<reg> <val>...? -s ?-t|-p? ?-count N?"
       puts "  bscan_output_mgt <pin> <val> ?<pin> <val>...? -s ?-t|-p? ?-count N?"
       return
   }
   # need boundary length
   if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq "" || $::BSCAN(br_len) eq "NOT FOUND"} {
       puts "ERROR: ::BSCAN(br_len) not set. Run bscan_load <file.bsd>"
       return
   }
   set br_len $::BSCAN(br_len)
   # -------------------------
   # 1) SAMPLE + CAPTURE
   # -------------------------
   set seq [jtag sequence]
   $seq state RESET
   $seq state IDLE
   set irlen $::BSCAN(irlen)
   set op_sample [format %02X [expr "0x$::BSCAN(op_sample)"]]
   $seq irshift -state IDLE -hex $irlen $op_sample
   $seq drshift -state IDLE -capture $br_len
   set data [$seq run -bits -single]
   if {[string length $data] > $br_len} {
       set data [string range $data 0 [expr {$br_len-1}]]
   }
   # -------------------------
   # 2) set registers (OUTPUT2)
   # reg numerico oppure pin name (solo OUTPUT2)
   # -------------------------
   for {set i 0} {$i < [llength $tokens]} {incr i 2} {
       set key [lindex $tokens $i]
       set val [string toupper [lindex $tokens [expr {$i+1}]]]
       # OUTPUT2: accetto solo 0/1
       if {$val ne "0" && $val ne "1"} {
           puts "ERROR: value '$val' is invalid (OUTPUT2 supports only 0/1)"
           catch {$seq delete}
           return
       }
       # se numerico => reg
       if {[string is integer -strict $key]} {
           set reg $key
       } else {
           # pin => trova reg OUTPUT2
           set reg [bscan_get_output2_reg $key]
           if {$reg eq ""} {
               puts "ERROR: pin '$key' not found as OUTPUT2 (AC_2) in the BSDL"
               catch {$seq delete}
               return
           }
       }
       if {$reg < 0 || $reg >= $br_len} {
           puts "ERROR: reg '$reg' out of range (0..[expr {$br_len-1}])"
           catch {$seq delete}
           return
       }
       set data [string replace $data $reg $reg $val]
   }
   # se non -s, ritorna solo immagine preparata (silenzioso)
   if {!$do_send} {
       catch {$seq delete}
       return $data
   }
   # -------------------------
   # 3) scegli istruzione: EXTEST / TRAIN / PULSE
   # -------------------------
   set op $::BSCAN(op_extest)
   if {$use_train} {
       if {[info exists ::BSCAN(op_train)] && $::BSCAN(op_train) ne "" && $::BSCAN(op_train) ne "??"} {
           set op $::BSCAN(op_train)
       } else {
           set op "3D"
       }
   } elseif {$use_pulse} {
       if {[info exists ::BSCAN(op_pulse)] && $::BSCAN(op_pulse) ne "" && $::BSCAN(op_pulse) ne "??"} {
           set op $::BSCAN(op_pulse)
       } else {
           set op "3C"
       }
   }
   # -------------------------
   # 4) APPLY: IR + DRUPDATE + IDLE(count) + RUN
   # -------------------------
   $seq irshift -state IRUPDATE -hex $irlen $op
   $seq state IDLE
   $seq drshift -state DRUPDATE -bits $br_len $data
   # Ultimo IDLE ripetuto N volte (utile per TRAIN: mantiene attivo mentre arrivano TCK)
   for {set k 0} {$k < $idle_count} {incr k} {
       $seq state IDLE
   }
   # eseguo (il ritorno non ti serve sempre; lo lasciamo per compatibilità)
   $seq run -bits -single
   catch {$seq delete}
   return
}
# =========================================
# bscan_output_capture
#
# Scrive (EXTEST) e poi cattura (CAPTURE-DR) restando in EXTEST.
# - usa SAMPLE (01) SOLO per costruire la base image "sicura"
# - applica le modifiche -s alla base image
# - passa a EXTEST (26), fa DRUPDATE, attende -idle, poi CAPTURE
#
# Sintassi:
#   bscan_output_capture ?N? -s <key val> ?<key val>...? ?-r <reg...>? ?-port P? ?-function F? ?-idle N?
#
# Dove <key> può essere:
#   - numero (registro): val deve essere 0/1
#   - nome pin (solo OUTPUT3): val può essere 0/1/Z   (es: IO_C10 1)
#
# Esempi:
#   bscan_output_capture -s 318 0 319 1 321 1 -r 320 323 -idle 50
#   bscan_output_capture 12 -s IO_C10 1 IO_D10 Z -port IO_C10 -function input
#   bscan_output_capture -port IO_C10 -function input   ;# solo lettura (no -s), stampa filtrata
# =========================================
proc bscan_output_capture {args} {
    # defaults
    set perline 10
    set filter_port ""
    set filter_func ""
    set idle 0
    set set_tokens {}
    set read_regs {}
    set mode ""
    set do_reg 0

    # --- parse args ---
    set ai 0
    while {$ai < [llength $args]} {
        set a [lindex $args $ai]

        # primo argomento numerico = colonne per riga (stile bscan_input)
        if {$ai == 0 && [string is integer -strict $a]} {
            set perline $a
            incr ai
            continue
        }

        switch -- $a {
            -s {
                set mode "s"
            }
            -r {
                set mode "r"
            }
            -idle {
                incr ai
                if {$ai >= [llength $args]} { puts "ERROR: -idle needs value"; return }
                set idle [lindex $args $ai]
                if {![string is integer -strict $idle] || $idle < 0} {
                    puts "ERROR: -idle must be an integer >= 0"
                    return
                }
            }
            -port {
                incr ai
                if {$ai >= [llength $args]} { puts "ERROR: -port needs value"; return }
                set filter_port [string toupper [lindex $args $ai]]
            }
            -function {
                incr ai
                if {$ai >= [llength $args]} { puts "ERROR: -function needs value"; return }
                set filter_func [string tolower [lindex $args $ai]]
            }
            -reg {
                set do_reg 1
            }
            default {
                if {$mode eq "s"} {
                    lappend set_tokens $a
                } elseif {$mode eq "r"} {
                    lappend read_regs $a
                } else {
                    puts "ERROR: arg '$a' out of context. Use: -s ... -r ... -port ... -function ... -idle ..."
                    return
                }
            }
        }
        incr ai
    }

    # --- sanity: -s deve essere a coppie se presente
    if {[llength $set_tokens] > 0 && ([llength $set_tokens] % 2) != 0} {
        puts "ERROR: -s requires pairs <reg/pin val>"
        return
    }

    # 0) need boundary length
    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq "NOT FOUND" || $::BSCAN(br_len) eq ""} {
        puts "ERROR: ::BSCAN(br_len) not set. Run: bscan_load <file.bsd>"
        return
    }
    set br_len $::BSCAN(br_len)

    # 0b) BSDL/cache solo quando serve:
    # - serve per risolvere pin name in -s (output3)
    # - serve per applicare filtri -port / -function quando NON usi -r
    set need_bsdl 0

    # pin-name in -s?
    for {set i 0} {$i < [llength $set_tokens]} {incr i 2} {
        set key [lindex $set_tokens $i]
        if {![string is integer -strict $key]} {
            set need_bsdl 1
            break
        }
    }

    # filtri attivi?
    if {$filter_port ne "" || $filter_func ne ""} {
        set need_bsdl 1
    }

    # se serve BSDL/cache, allora verifica e build cache
    if {$need_bsdl} {
        if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
            puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
            return
        }
        if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
            if {![bscan_build_cell_cache]} { return }
        }
    }

    # 1) SAMPLE + CAPTURE base image
    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    set irlen $::BSCAN(irlen)
    set op_sample [format %02X [expr "0x$::BSCAN(op_sample)"]]
    $seq irshift -state IDLE -hex $irlen $op_sample
    $seq drshift -state IDLE -capture $br_len
    set base [$seq run -bits -single]
    catch {$seq delete}

    if {[string length $base] > $br_len} {
        set base [string range $base 0 [expr {$br_len-1}]]
    }

    # 2) Applica -s alla base image (reg numerici 0/1 oppure pin output3 0/1/Z)
    set img $base
    for {set i 0} {$i < [llength $set_tokens]} {incr i 2} {
        set key [lindex $set_tokens $i]
        set val [string toupper [lindex $set_tokens [expr {$i+1}]]]

        if {[string is integer -strict $key]} {
            # REG mode
            if {$key < 0 || $key >= $br_len} {
                puts "ERROR: invalid reg '$key' (0..[expr {$br_len-1}])"
                return
            }
            if {$val ne "0" && $val ne "1"} {
                puts "ERROR: invalid val '$val' for reg $key (must be 0 or 1)"
                return
            }
            set img [string replace $img $key $key $val]
        } else {
            # PIN mode (solo OUTPUT3)
            if {$val ne "0" && $val ne "1" && $val ne "Z"} {
                puts "ERROR: invalid value '$val' for pin $key (use 0,1,Z)"
                return
            }
            set info [bscan_get_output3_cells $key]
            if {$info eq ""} {
                puts "ERROR: pin $key not found as output3 in BSDL (only output3 is supported by name in -s)"
                return
            }
            lassign $info port outidx ctlidx disval

            # enable = NOT disval
            set enable [expr {$disval eq "1" ? 0 : 1}]

            if {$val eq "Z"} {
                # Hi-Z
                set img [string replace $img $ctlidx $ctlidx $disval]
            } else {
                # Drive 0/1
                set img [string replace $img $ctlidx $ctlidx $enable]
                set img [string replace $img $outidx $outidx $val]
            }
        }
    }

    # 3) EXTEST + DRUPDATE + IDLE* + CAPTURE (restando in EXTEST)
    set seq [jtag sequence]
	$seq state RESET
    $seq state IDLE
    set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]
    $seq irshift -state IDLE -hex $irlen $op_extest
    $seq state IDLE
    $seq drshift -state IDLE -bits $br_len $img

    for {set k 0} {$k < $idle} {incr k} {
        $seq state IDLE
    }

    $seq drshift -state IDLE -capture $br_len
    set cap [$seq run -bits -single]
    catch {$seq delete}

    if {[string length $cap] > $br_len} {
        set cap [string range $cap 0 [expr {$br_len-1}]]
    }
    
    # prev: inizializza la prima volta (serve per colori e "changed")
    if {![info exists ::PREV_DATA_OC] || [string length $::PREV_DATA_OC] != [string length $cap]} {
        set ::PREV_DATA_OC $cap
    }	

    # ---- Colori ANSI (definiti una sola volta, usabili anche nel ramo -reg)
    if {![llength [info procs ::c_orange]]} {
        proc ::c_orange {s} { return "\033\[38;5;208m$s\033\[0m" }
    }
    if {![llength [info procs ::c_cyan]]} {
        proc ::c_cyan {s} { return "\033\[36m$s\033\[0m" }
    }

    # 4) Output:
    #    - se -r presente: ritorna solo quei registri
    #    - se -r assente: stampa "tutti" con filtri stile bscan_input
if {[llength $read_regs] > 0} {
    set out {}
    foreach r $read_regs {
        if {![string is integer -strict $r] || $r < 0 || $r >= $br_len} {
            puts "ERROR: reg read '$r' out of range (0..[expr {$br_len-1}])"
            return
        }

        set cur  [string index $cap $r]
        set prev [string index $::PREV_DATA_OC $r]

        if {$cur ne $prev} {
            set v [::c_cyan $cur]
        } elseif {$cur eq "0"} {
            set v [::c_orange $cur]
        } else {
            set v $cur
        }

        lappend out "${r}:$v"
    }

    # aggiorna prev DOPO la lettura
    set ::PREV_DATA_OC $cap
	puts [join $out " "]
	return
}

    # Se richiesto, stampa in formato -reg (reg:value) come bscan_input -reg (con colori)
    if {$do_reg} {
        set n [string length $cap]

        # prev per evidenziare i cambi
        if {![info exists ::PREV_DATA_OC] || [string length $::PREV_DATA_OC] != $n} {
            set ::PREV_DATA_OC $cap
        }

        set line ""
        set count 0

        for {set idx 0} {$idx < $n} {incr idx} {

            # Se ci sono filtri, applicali usando la cache celle (serve bscan_load)
            if {$filter_port ne "" || $filter_func ne ""} {
                set info [bscan_cell_info $idx]  ;# "TYPE|PORT|FUNC" oppure ""
                if {$info eq ""} { continue }
                set parts [split $info "|"]
                set p2 [string toupper [lindex $parts 1]]
                set f2 [string tolower [lindex $parts 2]]

                if {$filter_port ne "" && $p2 ne $filter_port} { continue }
                if {$filter_func ne "" && $f2 ne $filter_func} { continue }
            }

            set cur  [string index $cap $idx]
            set prev [string index $::PREV_DATA_OC $idx]

            if {$cur ne $prev} {
                set v [::c_cyan $cur]
            } elseif {$cur eq "0"} {
                set v [::c_orange $cur]
            } else {
                set v $cur
            }

            append line [format "%d:%s" $idx $v]

            incr count
            if {$count == $perline} {
                puts $line
                set line ""
                set count 0
            } else {
                append line " | "
            }
        }

        if {[string trim $line] ne ""} {
            if {[string match "* | " $line]} { set line [string range $line 0 end-3] }
            puts $line
        }

        # aggiorna prev DOPO la stampa
        set ::PREV_DATA_OC $cap
        return
    }

    set n [string length $cap]
    if {![info exists ::PREV_DATA_OC] || [string length $::PREV_DATA_OC] != $n} {
        set ::PREV_DATA_OC $cap
    }

    set line ""
    set count 0

    for {set idx 0} {$idx < $n} {incr idx} {

        # label da cache
        set info [bscan_cell_info $idx]  ;# "TYPE|PORT|FUNC" o ""
        if {$info eq ""} {
            # se non abbiamo info, filtri non applicabili -> se filtri attivi, skip
            if {$filter_port ne "" || $filter_func ne ""} { continue }
            set label ""
        } else {
            set parts [split $info "|"]
            set typ  [lindex $parts 0]
            set p2   [string toupper [lindex $parts 1]]
            set f2   [string tolower [lindex $parts 2]]

            if {$filter_port ne "" && $p2 ne $filter_port} { continue }
            if {$filter_func ne "" && $f2 ne $filter_func} { continue }

            set label "$typ,$p2,$f2"
        }

        # value + color (delta vs precedente)
        set cur  [string index $cap $idx]
        set prev [string index $::PREV_DATA_OC $idx]
        if {$cur ne $prev} {
            set v [::c_cyan $cur]
        } elseif {$cur eq "0"} {
            set v [::c_orange $cur]
        } else {
            set v $cur
        }

        if {$label ne ""} {
            append line [format "%d:%s %s" $idx $v $label]
        } else {
            append line [format "%d:%s" $idx $v]
        }

        incr count
        if {$count == $perline} {
            puts $line
            set line ""
            set count 0
        } else {
            append line " | "
        }
    }

    if {[string trim $line] ne ""} {
        if {[string match "* | " $line]} { set line [string range $line 0 end-3] }
        puts $line
    }

    # aggiorna prev DOPO la stampa (così il "changed" funziona alla chiamata successiva)
    set ::PREV_DATA_OC $cap

    return
}
proc run_mgt_test {cols args} {

    # -------------------------
    # Validate cols (first arg)
    # -------------------------
    if {![string is integer -strict $cols] || $cols < 1} {
        return -code error "first arg <cols> must be integer >= 1"
    }

    # -------------------------
    # Parse args
    # -------------------------
    set iterations ""
    set idle_cycles ""
    set drive_tokens {}
    set sample_regs {}
    set mode "train"  ;# default as original

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -- $a {
            -count {
                incr i
                if {$i >= [llength $args]} { return -code error "missing value after -count" }
                set iterations [lindex $args $i]
            }
            -idle {
                incr i
                if {$i >= [llength $args]} { return -code error "missing value after -idle" }
                set idle_cycles [lindex $args $i]
            }
            -r {
                incr i
                while {$i < [llength $args]} {
                    set x [lindex $args $i]
                    if {[string match "-*" $x]} { incr i -1 ; break }
                    set reg $x
                    incr i
                    if {$i >= [llength $args]} { return -code error "-r requires <reg> <val> pairs" }
                    set val [lindex $args $i]
                    lappend drive_tokens $reg $val
                    incr i
                }
            }
            -sample {
                incr i
                while {$i < [llength $args]} {
                    set x [lindex $args $i]
                    if {[string match "-*" $x]} { incr i -1 ; break }
                    lappend sample_regs $x
                    incr i
                }
            }
            -p { set mode "pulse" }
            -t { set mode "train" }
            default {
                return -code error "unknown arg '$a' (use: <cols> -count N -idle M -r <reg val...> -sample <reg...> ?-p? ?-t?)"
            }
        }
        incr i
    }

    # -------------------------
    # Validate basics
    # -------------------------
    if {$iterations eq ""}  { return -code error "missing -count <iterations>" }
    if {$idle_cycles eq ""} { return -code error "missing -idle <idle_cycles>" }

    if {![string is integer -strict $iterations] || $iterations < 1} {
        return -code error "iterations must be >= 1"
    }
    if {![string is integer -strict $idle_cycles] || $idle_cycles < 0} {
        return -code error "idle_cycles must be >= 0"
    }

    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq ""} {
        return -code error "::BSCAN(br_len) not set"
    }
    if {![info exists ::BSCAN(irlen)] || $::BSCAN(irlen) eq ""} {
        return -code error "::BSCAN(irlen) not set"
    }

    set br_len $::BSCAN(br_len)
    set irlen  $::BSCAN(irlen)

    # Validate -r pairs
    if {[llength $drive_tokens] == 0} {
        return -code error "missing -r <reg> <val> ..."
    }
    if {([llength $drive_tokens] % 2) != 0} {
        return -code error "-r requires <reg> <val> pairs"
    }
    for {set k 0} {$k < [llength $drive_tokens]} {incr k 2} {
        set reg [lindex $drive_tokens $k]
        set val [string toupper [lindex $drive_tokens [expr {$k+1}]]]
        if {![string is integer -strict $reg] || $reg < 0 || $reg >= $br_len} {
            return -code error "drive reg '$reg' out of range (0..[expr {$br_len-1}])"
        }
        if {$val ne "0" && $val ne "1"} {
            return -code error "drive value for reg $reg must be 0 or 1"
        }
        lset drive_tokens [expr {$k+1}] $val
    }

    # Validate -sample regs
    if {[llength $sample_regs] == 0} {
        return -code error "missing -sample <reg...>"
    }
    set seen {}
    set uniq {}
    foreach r $sample_regs {
        if {![string is integer -strict $r] || $r < 0 || $r >= $br_len} {
            return -code error "sample reg '$r' out of range (0..[expr {$br_len-1}])"
        }
        if {[lsearch -exact $seen $r] < 0} {
            lappend seen $r
            lappend uniq $r
        }
    }
    set sample_regs $uniq

    # -------------------------
    # Select drive opcode (structure unchanged)
    # -------------------------
    if {$mode eq "pulse"} {
        if {![info exists ::BSCAN(op_pulse)] || $::BSCAN(op_pulse) eq ""} {
            return -code error "::BSCAN(op_pulse) not set (needed for -p)"
        }
        set op_drive [format %02X [expr "0x$::BSCAN(op_pulse)"]]
    } else {
        # default TRAIN as original (3D). If ::BSCAN(op_train) exists, use it.
        if {[info exists ::BSCAN(op_train)] && $::BSCAN(op_train) ne ""} {
            set op_drive [format %02X [expr "0x$::BSCAN(op_train)"]]
        } else {
            set op_drive "3D"
        }
    }

    # SAMPLE opcode stays exactly like your original (01)
    set op_sample "01"

    # -------------------------
    # Counters per sampled reg
    # -------------------------
    array set cnt0 {}
    array set cnt1 {}
    foreach r $sample_regs {
        set cnt0($r) 0
        set cnt1($r) 0
    }

    set seq [jtag sequence]

    # --- SAMPLE iniziale (unchanged sequence) ---
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IRUPDATE -hex $irlen $op_sample
    $seq drshift -state IDLE -capture $br_len
    set data [$seq run -bits -single]

    if {[string length $data] > $br_len} {
        set data [string range $data 0 [expr {$br_len-1}]]
    }

    # apply -r forcing AFTER first sample (replaces old fixed "force 372")
    for {set k 0} {$k < [llength $drive_tokens]} {incr k 2} {
        set reg [lindex $drive_tokens $k]
        set val [lindex $drive_tokens [expr {$k+1}]]
        set data [string replace $data $reg $reg $val]
    }

    # --- put TRAIN/PULSE once (unchanged structure) ---
    $seq irshift -state IRUPDATE -hex $irlen $op_drive
    $seq state IDLE

    for {set it 0} {$it < $iterations} {incr it} {

        # apply vector (unchanged)
        $seq drshift -state DRUPDATE -bits $br_len $data

        # generate many consecutive IDLE cycles (unchanged)
        for {set k 0} {$k < $idle_cycles} {incr k} {
            $seq state IDLE
        }

        # fast SAMPLE (unchanged structure)
        $seq irshift -state IRUPDATE -hex $irlen $op_sample
        $seq drshift -state IDLE -capture $br_len
        set out_data [$seq run -bits -single]

        # update counters for requested regs
        foreach r $sample_regs {
            set b [string index $out_data $r]
            if {$b eq "1"} {
                incr cnt1($r)
            } else {
                incr cnt0($r)
            }
        }

        # back to TRAIN/PULSE (unchanged)
        $seq irshift -state IRUPDATE -hex $irlen $op_drive
        $seq state IDLE
    }

    catch {$seq delete}

    # -------------------------
    # Print report (orange zeros) in <cols> columns
    # -------------------------
    set ORANGE "\033\[38;5;208m"
    set RESET  "\033\[0m"

    set fields {}
    foreach r $sample_regs {
        set z $cnt0($r)
        set o $cnt1($r)
        if {$z == 0} { set z "${ORANGE}$z${RESET}" }
        if {$o == 0} { set o "${ORANGE}$o${RESET}" }
        lappend fields [format "%d(0): %s %d(1): %s" $r $z $r $o]
    }

    set line ""
    set n 0
    foreach f $fields {
        if {$line ne ""} { append line " | " }
        append line $f
        incr n
        if {$n == $cols} {
            puts $line
            set line ""
            set n 0
        }
    }
    if {$line ne ""} { puts $line }

}

proc bscan_cap_test {pin args} {

    set auto_name 0
    set count 10
    set gap_clocks 0
    set debug 0

    # -----------------------------
    # parse args
    # -----------------------------
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]

        if {$a eq "-n"} {
            set auto_name 1

        } elseif {$a eq "-count"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -count needs value"
                return
            }
            set count [lindex $args $i]
            if {![string is integer -strict $count] || $count < 1} {
                puts "ERROR: -count must be integer >= 1"
                return
            }

        } elseif {$a eq "-gap"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -gap needs value"
                return
            }
            set gap_clocks [lindex $args $i]
            if {![string is integer -strict $gap_clocks] || $gap_clocks < 0} {
                puts "ERROR: -gap must be integer >= 0"
                return
            }

        } else {
            puts "ERROR: unknown arg '$a'"
            puts "usage:"
            puts "  bscan_cap_test <pin> -n ?-count N? ?-gap N? "
            return
        }

        incr i
    }

    if {!$auto_name} {
        puts "ERROR: use -n mode"
        puts "usage:"
        puts "  bscan_cap_test <pin> -n ?-count N? ?-gap N? "
        return
    }

    # -----------------------------
    # checks
    # -----------------------------
    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq ""} {
        puts "ERROR: ::BSCAN(br_len) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(irlen)] || $::BSCAN(irlen) eq ""} {
        puts "ERROR: ::BSCAN(irlen) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(op_extest)] || $::BSCAN(op_extest) eq ""} {
        puts "ERROR: ::BSCAN(op_extest) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
        return
    }

    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    set br_len $::BSCAN(br_len)
    set irlen  $::BSCAN(irlen)
    set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]

    # -----------------------------
    # trova tripletta output3 + input
    # -----------------------------
    set info [bscan_get_output3_cells $pin]
    if {$info eq ""} {
        puts "ERROR: pin $pin not found as output3 in BSDL"
        return
    }

    lassign $info port outidx ctlidx disval

    set inpidx ""
    for {set idx 0} {$idx < $br_len} {incr idx} {
        set ci [bscan_cell_info $idx]
        if {$ci eq ""} { continue }

        set parts [split $ci "|"]
        set p [string toupper [lindex $parts 1]]
        set f [string tolower [lindex $parts 2]]

        if {$p eq $port && $f eq "input"} {
            set inpidx $idx
            break
        }
    }

    if {$inpidx eq ""} {
        puts "ERROR: no INPUT cell found for port $port"
        return
    }

    # -----------------------------
    # build explicit Z image
    # IMPORTANT:
    #   do NOT RESET
    #   do NOT rely on SAMPLE
    #   create a full DR image and force:
    #     CTL = disval  -> Z
    #   everything else = 0
    #
    # this guarantees the pin is explicitly put in Z
    # -----------------------------
    set img_z [string repeat 1 $br_len]
    

    puts $port
    puts "  OUT=$outidx CTL=$ctlidx IN=$inpidx disval=$disval GAP=$gap_clocks"
    # -------------------------------------------------
    # Sampling frequency estimation
    # -------------------------------------------------
    
    set br_len $::BSCAN(br_len)
    set f_jtag [jtag frequency]
    
    # samples per second
    set fsample [expr {double($f_jtag) / ($br_len + $gap_clocks)}]
    
    # sample period in seconds
    set tsample [expr {1.0 / $fsample}]
    
    # total acquisition time in seconds
    set ttotal [expr {$count * $tsample}]
    
    # pretty print frequency
    if {$fsample >= 1000000.0} {
        set fsample_str [format "%.2f MHz" [expr {$fsample / 1000000.0}]]
    } elseif {$fsample >= 1000.0} {
        set fsample_str [format "%.2f kHz" [expr {$fsample / 1000.0}]]
    } else {
        set fsample_str [format "%.2f Hz" $fsample]
    }
    
    # pretty print sampling period
    if {$tsample < 1e-6} {
        set tsample_str [format "%.2f ns" [expr {$tsample * 1e9}]]
    } elseif {$tsample < 1e-3} {
        set tsample_str [format "%.2f us" [expr {$tsample * 1e6}]]
    } else {
        set tsample_str [format "%.2f ms" [expr {$tsample * 1e3}]]
    }
    
    # pretty print acquisition time
    if {$ttotal < 1e-6} {
        set ttotal_str [format "%.2f ns" [expr {$ttotal * 1e9}]]
    } elseif {$ttotal < 1e-3} {
        set ttotal_str [format "%.2f us" [expr {$ttotal * 1e6}]]
    } elseif {$ttotal < 1.0} {
        set ttotal_str [format "%.2f ms" [expr {$ttotal * 1e3}]]
    } else {
        set ttotal_str [format "%.2f s" $ttotal]
    }
    
    puts "  sampling period : $tsample_str ( $fsample_str ) || acquisition time : $ttotal_str"

    # -----------------------------
    # single sequence, NO RESET
    #
    # assume user has already done:
    #   bscan_output <pin> <0|1> -n -s
    #
    # now:
    #   enter EXTEST
    #   apply Z
    #   N x (capture, reapply Z)
    # -----------------------------
    set seq [jtag sequence]
	$seq state RESET

    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_extest

    # first apply Z
    $seq drshift -state IDLE -bits $br_len $img_z

    if {$gap_clocks > 0} {
        $seq state IDLE $gap_clocks
    }

    for {set k 0} {$k < $count} {incr k} {
        $seq drshift -state IDLE -capture $br_len

        if {$k < ($count - 1)} {
            $seq drshift -state IDLE -bits $br_len $img_z
            if {$gap_clocks > 0} {
                $seq state IDLE $gap_clocks
            }
        }
    }

    set raw [$seq run -bits]
    catch {$seq delete}

    set samples {}
    set idx 0

    foreach frame $raw {
        set cap $frame
        set n [string length $cap]

        if {$n > $br_len} {
            set cap [string range $cap 0 [expr {$br_len - 1}]]
        } elseif {$n < $br_len} {
            append cap [string repeat 0 [expr {$br_len - $n}]]
        }

        set bit [string index $cap $inpidx]
        lappend samples $bit

        incr idx
    }

    if {[llength $samples] > $count} {
        set samples [lrange $samples 0 [expr {$count - 1}]]
    }

    # -------------------------------------------------
	# -------------------------------------------------
	# Colorized samples
	# 1 = green
	# 0 = orange
	# transition = dark green
	# -------------------------------------------------
	
	set green "\033\[92m"
	set darkgreen "\033\[32m"
	set orange "\033\[33m"
	set reset "\033\[0m"
	
	set prev ""
	set out ""
	
	foreach s $samples {
	
		if {$prev ne "" && $s ne $prev} {
			append out "${darkgreen}$s${reset} "
		} elseif {$s eq "1"} {
			append out "${green}1${reset} "
		} else {
			append out "${orange}0${reset} "
		}
	
		set prev $s
	}
	
	puts "samples : $out"
}

proc bscan_spi_cfg {args} {

    # defaults
    if {![info exists ::BSCAN_SPI(CPOL)]} {
        set ::BSCAN_SPI(CPOL) 0
    }
    if {![info exists ::BSCAN_SPI(CPHA)]} {
        set ::BSCAN_SPI(CPHA) 0
    }
    if {![info exists ::BSCAN_SPI(PRESET_LIST)]} {
        set ::BSCAN_SPI(PRESET_LIST) {}
    }
    if {![info exists ::BSCAN_SPI(PRE_IDLE)]} {
        set ::BSCAN_SPI(PRE_IDLE) 0
    }
    if {![info exists ::BSCAN_SPI(CS_SETUP_IDLE)]} {
        set ::BSCAN_SPI(CS_SETUP_IDLE) 0
    }

    if {[llength $args] == 0} {
        puts "usage:"
        puts "  bscan_spi_cfg SCK=<pin> MISO=<pin|x> MOSI=<pin> CS=<pin> ?CPOL=0|1? ?CPHA=0|1?"
        puts "  bscan_spi_cfg ?SET_0=<pin>? ?SET_1=<pin>? ..."
        puts "  bscan_spi_cfg ?PRE_IDLE=<n>? ?CS_SETUP_IDLE=<n>?"
        puts "  bscan_spi_cfg -clear"
        return
    }

    # clear previous config
    if {[llength $args] == 1 && [string equal -nocase [lindex $args 0] "-clear"]} {
        catch {unset ::BSCAN_SPI}
        puts "SPI configuration cleared"
        return
    }

    # checks
    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq ""} {
        puts "ERROR: ::BSCAN(br_len) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    set br_len $::BSCAN(br_len)

    # temp raw names
    array set raw {}
    set preset0 {}
    set preset1 {}

    foreach a $args {
        if {![regexp {^([^=]+)=(.+)$} $a -> key val]} {
            puts "ERROR: invalid argument '$a' (use KEY=VALUE)"
            return
        }

        set key [string toupper [string trim $key]]
        set val [string trim $val]

        switch -- $key {
            SCK  { set raw(SCK)  $val }
            MISO { set raw(MISO) $val }
            MOSI { set raw(MOSI) $val }
            CS   { set raw(CS)   $val }

            SET_0 { lappend preset0 [string toupper $val] }
            SET_1 { lappend preset1 [string toupper $val] }

            PRE_IDLE {
                if {![string is integer -strict $val] || $val < 0} {
                    puts "ERROR: PRE_IDLE must be integer >= 0"
                    return
                }
                set ::BSCAN_SPI(PRE_IDLE) $val
            }

            CS_SETUP_IDLE {
                if {![string is integer -strict $val] || $val < 0} {
                    puts "ERROR: CS_SETUP_IDLE must be integer >= 0"
                    return
                }
                set ::BSCAN_SPI(CS_SETUP_IDLE) $val
            }

            CPOL {
                if {$val ne "0" && $val ne "1"} {
                    puts "ERROR: CPOL must be 0 or 1"
                    return
                }
                set ::BSCAN_SPI(CPOL) $val
            }

            CPHA {
                if {$val ne "0" && $val ne "1"} {
                    puts "ERROR: CPHA must be 0 or 1"
                    return
                }
                set ::BSCAN_SPI(CPHA) $val
            }

            default {
                puts "ERROR: unknown parameter '$key'"
                return
            }
        }
    }

    # ------------------------------------------------------------
    # resolve OUTPUT3-style pins: SCK, MOSI, CS
    # ------------------------------------------------------------
    foreach sig {SCK MOSI CS} {
        if {![info exists raw($sig)] || $raw($sig) eq ""} {
            continue
        }

        set pin $raw($sig)

        set info [bscan_get_output3_cells $pin]
        if {$info eq ""} {
            puts "ERROR: pin $pin not found as output3 in BSDL"
            return
        }

        lassign $info port outidx ctlidx disval

        set ::BSCAN_SPI(${sig}_PIN)    $port
        set ::BSCAN_SPI(${sig}_OUT)    $outidx
        set ::BSCAN_SPI(${sig}_CTL)    $ctlidx
        set ::BSCAN_SPI(${sig}_DISVAL) $disval
    }

    # ------------------------------------------------------------
    # resolve MISO input cell
    # and, if available, also resolve MISO output3/controlr
    # so we can force it to Z during SPI reads
    # ------------------------------------------------------------
    if {[info exists raw(MISO)]} {
        if {[string tolower $raw(MISO)] eq "x"} {
            set ::BSCAN_SPI(MISO_PIN) x
            set ::BSCAN_SPI(MISO_IN)  x
            catch {unset ::BSCAN_SPI(MISO_OUT)}
            catch {unset ::BSCAN_SPI(MISO_CTL)}
            catch {unset ::BSCAN_SPI(MISO_DISVAL)}
        } else {
            set pin [string toupper $raw(MISO)]
            set inpidx ""

            for {set idx 0} {$idx < $br_len} {incr idx} {
                set ci [bscan_cell_info $idx]
                if {$ci eq ""} { continue }

                set parts [split $ci "|"]
                set port [string toupper [lindex $parts 1]]
                set func [string tolower [lindex $parts 2]]

                if {$port eq $pin && $func eq "input"} {
                    set inpidx $idx
                    break
                }
            }

            if {$inpidx eq ""} {
                puts "ERROR: input cell for pin $pin not found in BSDL"
                return
            }

            set ::BSCAN_SPI(MISO_PIN) $pin
            set ::BSCAN_SPI(MISO_IN)  $inpidx

            # optional: if MISO also has output3/controlr, save it
            set info [bscan_get_output3_cells $pin]
            if {$info ne ""} {
                lassign $info port outidx ctlidx disval
                set ::BSCAN_SPI(MISO_OUT)    $outidx
                set ::BSCAN_SPI(MISO_CTL)    $ctlidx
                set ::BSCAN_SPI(MISO_DISVAL) $disval
            } else {
                catch {unset ::BSCAN_SPI(MISO_OUT)}
                catch {unset ::BSCAN_SPI(MISO_CTL)}
                catch {unset ::BSCAN_SPI(MISO_DISVAL)}
            }
        }
    }

    foreach req {
        SCK_PIN SCK_OUT SCK_CTL SCK_DISVAL
        MOSI_PIN MOSI_OUT MOSI_CTL MOSI_DISVAL
        CS_PIN CS_OUT CS_CTL CS_DISVAL
        MISO_PIN MISO_IN
    } {
        if {![info exists ::BSCAN_SPI($req)] || $::BSCAN_SPI($req) eq ""} {
            puts "ERROR: incomplete SPI configuration. Set SCK= MISO= MOSI= CS= first."
            return
        }
    }

    # ------------------------------------------------------------
    # collect/resolve preset pins
    # ------------------------------------------------------------
    set existing {}
    foreach p $::BSCAN_SPI(PRESET_LIST) {
        lassign $p outidx ctlidx disval val pin
        lappend existing "$pin:$val"
    }

    foreach pin $preset0 {
        if {[lsearch -exact $existing "$pin:1"] >= 0} {
            puts "ERROR: pin $pin already configured in SET_1"
            return
        }
        if {[lsearch -exact $existing "$pin:0"] >= 0} {
            continue
        }

        set info [bscan_get_output3_cells $pin]
        if {$info eq ""} {
            puts "ERROR: preset pin $pin not found as output3 in BSDL"
            return
        }

        lassign $info port outidx ctlidx disval
        lappend ::BSCAN_SPI(PRESET_LIST) [list $outidx $ctlidx $disval 0 $port]
        lappend existing "$port:0"
    }

    foreach pin $preset1 {
        if {[lsearch -exact $existing "$pin:0"] >= 0} {
            puts "ERROR: pin $pin already configured in SET_0"
            return
        }
        if {[lsearch -exact $existing "$pin:1"] >= 0} {
            continue
        }

        set info [bscan_get_output3_cells $pin]
        if {$info eq ""} {
            puts "ERROR: preset pin $pin not found as output3 in BSDL"
            return
        }

        lassign $info port outidx ctlidx disval
        lappend ::BSCAN_SPI(PRESET_LIST) [list $outidx $ctlidx $disval 1 $port]
        lappend existing "$port:1"
    }

    foreach p $::BSCAN_SPI(PRESET_LIST) {
        lassign $p outidx ctlidx disval val pin
        foreach sig {SCK MOSI CS MISO} {
            if {[info exists ::BSCAN_SPI(${sig}_PIN)] && [string equal -nocase $pin $::BSCAN_SPI(${sig}_PIN)]} {
                puts "ERROR: preset pin $pin conflicts with SPI signal $sig"
                return
            }
        }
    }

    puts "SPI configuration:"
    puts "  SCK  = $::BSCAN_SPI(SCK_PIN)  OUT=$::BSCAN_SPI(SCK_OUT)  CTL=$::BSCAN_SPI(SCK_CTL)  disval=$::BSCAN_SPI(SCK_DISVAL)"
    puts "  MOSI = $::BSCAN_SPI(MOSI_PIN) OUT=$::BSCAN_SPI(MOSI_OUT) CTL=$::BSCAN_SPI(MOSI_CTL) disval=$::BSCAN_SPI(MOSI_DISVAL)"
    puts "  CS   = $::BSCAN_SPI(CS_PIN)   OUT=$::BSCAN_SPI(CS_OUT)   CTL=$::BSCAN_SPI(CS_CTL)   disval=$::BSCAN_SPI(CS_DISVAL)"

    if {$::BSCAN_SPI(MISO_PIN) eq "x"} {
        puts "  MISO = x"
    } else {
        puts "  MISO = $::BSCAN_SPI(MISO_PIN) IN=$::BSCAN_SPI(MISO_IN)"
        if {[info exists ::BSCAN_SPI(MISO_CTL)]} {
            puts "         OUT=$::BSCAN_SPI(MISO_OUT) CTL=$::BSCAN_SPI(MISO_CTL) disval=$::BSCAN_SPI(MISO_DISVAL) (forced Z during read)"
        }
    }

    puts "  CPOL = $::BSCAN_SPI(CPOL)"
    puts "  CPHA = $::BSCAN_SPI(CPHA)"
    puts "  PRE_IDLE = $::BSCAN_SPI(PRE_IDLE)"
    puts "  CS_SETUP_IDLE = $::BSCAN_SPI(CS_SETUP_IDLE)"
    if {[llength $::BSCAN_SPI(PRESET_LIST)] > 0} {
        puts "  PRESETS:"
        foreach p $::BSCAN_SPI(PRESET_LIST) {
            lassign $p outidx ctlidx disval val pin
            puts "    $pin = $val   OUT=$outidx CTL=$ctlidx disval=$disval"
        }
    }
}
proc bscan_spi {args} {

    # ------------------------------------------------------------
    # checks
    # ------------------------------------------------------------
    foreach k {
        SCK_OUT SCK_CTL SCK_DISVAL
        MOSI_OUT MOSI_CTL MOSI_DISVAL
        CS_OUT CS_CTL CS_DISVAL
        MISO_IN
        CPOL CPHA
    } {
        if {![info exists ::BSCAN_SPI($k)]} {
            puts "ERROR: SPI not configured. Run bscan_spi_cfg first."
            return
        }
    }

    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq ""} {
        puts "ERROR: ::BSCAN(br_len) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(irlen)] || $::BSCAN(irlen) eq ""} {
        puts "ERROR: ::BSCAN(irlen) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(op_extest)] || $::BSCAN(op_extest) eq ""} {
        puts "ERROR: ::BSCAN(op_extest) not set. Run bscan_load <file.bsd>"
        return
    }

    if {$::BSCAN_SPI(CPOL) ne "0" || $::BSCAN_SPI(CPHA) ne "0"} {
        puts "ERROR: current implementation supports only CPOL=0 CPHA=0"
        return
    }

    set br_len $::BSCAN(br_len)
    set irlen  $::BSCAN(irlen)
    set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]

    set sck_out  $::BSCAN_SPI(SCK_OUT)
    set sck_ctl  $::BSCAN_SPI(SCK_CTL)
    set sck_dis  $::BSCAN_SPI(SCK_DISVAL)

    set mosi_out $::BSCAN_SPI(MOSI_OUT)
    set mosi_ctl $::BSCAN_SPI(MOSI_CTL)
    set mosi_dis $::BSCAN_SPI(MOSI_DISVAL)

    set cs_out   $::BSCAN_SPI(CS_OUT)
    set cs_ctl   $::BSCAN_SPI(CS_CTL)
    set cs_dis   $::BSCAN_SPI(CS_DISVAL)

    set miso_idx $::BSCAN_SPI(MISO_IN)

    set sck_en  [expr {$sck_dis  eq "1" ? 0 : 1}]
    set mosi_en [expr {$mosi_dis eq "1" ? 0 : 1}]
    set cs_en   [expr {$cs_dis   eq "1" ? 0 : 1}]

    set pre_idle 0
    if {[info exists ::BSCAN_SPI(PRE_IDLE)]} {
        set pre_idle $::BSCAN_SPI(PRE_IDLE)
    }

    set cs_setup_idle 0
    if {[info exists ::BSCAN_SPI(CS_SETUP_IDLE)]} {
        set cs_setup_idle $::BSCAN_SPI(CS_SETUP_IDLE)
    }

    # optional: if MISO also has output3/controlr, keep it in Z
    set have_miso_z 0
    set miso_ctl -1
    set miso_disval 1
    if {[info exists ::BSCAN_SPI(MISO_CTL)]} {
        set have_miso_z 1
        set miso_ctl    $::BSCAN_SPI(MISO_CTL)
        set miso_disval $::BSCAN_SPI(MISO_DISVAL)
    }

    # ------------------------------------------------------------
    # parse args
    # syntax:
    #   bscan_spi -w 0x90 0x00 0x00 0x00 -r 2
    # ------------------------------------------------------------
    set write_bytes {}
    set read_count 0

    set mode ""
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]

        if {$a eq "-w"} {
            set mode "w"
            incr i
            continue
        } elseif {$a eq "-r"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -r needs byte count"
                return
            }
            set read_count [lindex $args $i]
            if {![string is integer -strict $read_count] || $read_count < 0} {
                puts "ERROR: -r must be integer >= 0"
                return
            }
            set mode "r"
            incr i
            continue
        }

        if {$mode eq "w"} {
            set tok [string toupper $a]
            if {![regexp {^0X[0-9A-F]{1,2}$} $tok]} {
                puts "ERROR: invalid write byte '$a' (use 0x00..0xFF)"
                return
            }
            scan $tok %x b
            lappend write_bytes $b
        } else {
            puts "ERROR: unexpected token '$a'"
            return
        }

        incr i
    }

    if {$read_count > 0 && [string tolower $miso_idx] eq "x"} {
        puts "ERROR: MISO=x, cannot read"
        return
    }

    # ------------------------------------------------------------
    # build base frame with presets
    # ------------------------------------------------------------
    set frame_base [string repeat 1 $br_len]
    if {[info exists ::BSCAN_SPI(PRESET_LIST)]} {
        foreach p $::BSCAN_SPI(PRESET_LIST) {
            lassign $p outidx ctlidx disval val pin
            set en [expr {$disval eq "1" ? 0 : 1}]
            set frame_base [string replace $frame_base $ctlidx $ctlidx $en]
            set frame_base [string replace $frame_base $outidx $outidx $val]
        }
    }

    proc __bscan_spi_mkframe {base \
                              sck_ctl sck_en sck_out sck_val \
                              mosi_ctl mosi_en mosi_out mosi_val \
                              cs_ctl cs_en cs_out cs_val \
                              have_miso_z miso_ctl miso_disval} {
        set frame $base

        set frame [string replace $frame $sck_ctl  $sck_ctl  $sck_en]
        set frame [string replace $frame $mosi_ctl $mosi_ctl $mosi_en]
        set frame [string replace $frame $cs_ctl   $cs_ctl   $cs_en]

        set frame [string replace $frame $sck_out  $sck_out  $sck_val]
        set frame [string replace $frame $mosi_out $mosi_out $mosi_val]
        set frame [string replace $frame $cs_out   $cs_out   $cs_val]

        if {$have_miso_z} {
            set frame [string replace $frame $miso_ctl $miso_ctl $miso_disval]
        }

        return $frame
    }

    # ------------------------------------------------------------
    # prebuild all useful frames
    # naming = CS SCK MOSI
    # ------------------------------------------------------------
    set frame_idle [__bscan_spi_mkframe \
        $frame_base \
        $sck_ctl $sck_en $sck_out 0 \
        $mosi_ctl $mosi_en $mosi_out 0 \
        $cs_ctl $cs_en $cs_out 1 \
        $have_miso_z $miso_ctl $miso_disval]

    set frame_000 [__bscan_spi_mkframe \
        $frame_base \
        $sck_ctl $sck_en $sck_out 0 \
        $mosi_ctl $mosi_en $mosi_out 0 \
        $cs_ctl $cs_en $cs_out 0 \
        $have_miso_z $miso_ctl $miso_disval]

    set frame_010 [__bscan_spi_mkframe \
        $frame_base \
        $sck_ctl $sck_en $sck_out 1 \
        $mosi_ctl $mosi_en $mosi_out 0 \
        $cs_ctl $cs_en $cs_out 0 \
        $have_miso_z $miso_ctl $miso_disval]

    set frame_001 [__bscan_spi_mkframe \
        $frame_base \
        $sck_ctl $sck_en $sck_out 0 \
        $mosi_ctl $mosi_en $mosi_out 1 \
        $cs_ctl $cs_en $cs_out 0 \
        $have_miso_z $miso_ctl $miso_disval]

    set frame_011 [__bscan_spi_mkframe \
        $frame_base \
        $sck_ctl $sck_en $sck_out 1 \
        $mosi_ctl $mosi_en $mosi_out 1 \
        $cs_ctl $cs_en $cs_out 0 \
        $have_miso_z $miso_ctl $miso_disval]

    # ------------------------------------------------------------
    # one single EXTEST sequence
    # ------------------------------------------------------------
    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_extest

    # prepare and assert CS low
    $seq drshift -state IDLE -bits $br_len $frame_idle

    if {$pre_idle > 0} {
        $seq delay $pre_idle
    }

    $seq drshift -state IDLE -bits $br_len $frame_000

    if {$cs_setup_idle > 0} {
        $seq delay $cs_setup_idle
    }

    # ------------------------------------------------------------
    # write bytes
    # bit 0 => 000 -> 010 -> 000
    # bit 1 => 001 -> 011 -> 001
    # ------------------------------------------------------------
    foreach wb $write_bytes {
        for {set bitidx 7} {$bitidx >= 0} {incr bitidx -1} {
            set bit [expr {($wb >> $bitidx) & 1}]

            if {$bit == 0} {
                $seq drshift -state IDLE -bits $br_len $frame_000
                $seq drshift -state IDLE -bits $br_len $frame_010
                $seq drshift -state IDLE -bits $br_len $frame_000
            } else {
                $seq drshift -state IDLE -bits $br_len $frame_001
                $seq drshift -state IDLE -bits $br_len $frame_011
                $seq drshift -state IDLE -bits $br_len $frame_001
            }
        }
    }

    # ------------------------------------------------------------
    # read bytes
    # for each bit:
    #   000 -> 010 -> capture -> 010 -> 000
    # ------------------------------------------------------------
    # "-capture" drshift performs a full DR scan cycle:
    # IDLE -> SELECT-DR -> CAPTURE-DR (sample boundary register / MISO)
    # -> SHIFT-DR (shift captured data to TDO while shifting frame_010 from TDI)
    # -> EXIT1-DR -> UPDATE-DR (apply frame_010 to the boundary register) -> IDLE
    set total_bits [expr {$read_count * 8}]
    for {set bitn 0} {$bitn < $total_bits} {incr bitn} {
        $seq drshift -state IDLE -bits $br_len $frame_000
        $seq drshift -state IDLE -bits $br_len $frame_010
        $seq drshift -state IDLE -capture -bits $br_len $frame_010
        $seq drshift -state IDLE -bits $br_len $frame_010
        $seq drshift -state IDLE -bits $br_len $frame_000
    }

    # release CS
    $seq drshift -state IDLE -bits $br_len $frame_idle
    $seq state IDLE

    set raw [$seq run -bits]
    catch {$seq delete}
    rename __bscan_spi_mkframe ""

    # ------------------------------------------------------------
    # parse capture results
    # ------------------------------------------------------------
    set rx_bits {}
    foreach cap $raw {
        set n [string length $cap]
        if {$n > $br_len} {
            set cap [string range $cap 0 [expr {$br_len - 1}]]
        } elseif {$n < $br_len} {
            append cap [string repeat 1 [expr {$br_len - $n}]]
        }
        lappend rx_bits [string index $cap $miso_idx]
    }

    if {[llength $rx_bits] > $total_bits} {
        set rx_bits [lrange $rx_bits 0 [expr {$total_bits - 1}]]
    }

    # ------------------------------------------------------------
    # pack bits into bytes
    # ------------------------------------------------------------
    if {$read_count > 0} {
        set rx_bytes {}
        set pos 0

        for {set n 0} {$n < $read_count} {incr n} {
            set v 0
            for {set b 0} {$b < 8} {incr b} {
                if {$pos >= [llength $rx_bits]} {
                    set bit 0
                } else {
                    set bit [lindex $rx_bits $pos]
                }
                set v [expr {($v << 1) | ($bit eq "1" ? 1 : 0)}]
                incr pos
            }
            lappend rx_bytes $v
        }

        set out {}
        foreach b $rx_bytes {
            lappend out [format "0x%02X" $b]
        }
        puts [join $out " "]
    }
}
# -----------------------------------------------------------------------------
# I2C helper: build one frame starting from a base boundary-register image.
#
# Modes:
#   L = drive low  (OUT=0, CTL=enable)
#   Z = release    (OUT=0, CTL=disable=disval)
#
# Note:
#   For OUTPUT3 pins, disval is the CTL value that disables the driver.
#   Therefore:
#       enable  = !disval
#       disable =  disval
# -----------------------------------------------------------------------------
proc __bscan_i2c_mkframe {base \
                          sda_out sda_ctl sda_disval sda_mode \
                          scl_out scl_ctl scl_disval scl_mode} {

    set frame $base

    # SDA
    if {$sda_mode eq "L"} {
        set sda_enable [expr {$sda_disval ? 0 : 1}]
        set frame [string replace $frame $sda_ctl $sda_ctl $sda_enable]
        set frame [string replace $frame $sda_out $sda_out 0]
    } else {
        # Z
        set frame [string replace $frame $sda_ctl $sda_ctl $sda_disval]
        set frame [string replace $frame $sda_out $sda_out 0]
    }

    # SCL
    if {$scl_mode eq "L"} {
        set scl_enable [expr {$scl_disval ? 0 : 1}]
        set frame [string replace $frame $scl_ctl $scl_ctl $scl_enable]
        set frame [string replace $frame $scl_out $scl_out 0]
    } else {
        # Z
        set frame [string replace $frame $scl_ctl $scl_ctl $scl_disval]
        set frame [string replace $frame $scl_out $scl_out 0]
    }

    return $frame
}


# -----------------------------------------------------------------------------
# I2C configuration
#
# Usage:
#   bscan_i2c_cfg
#   bscan_i2c_cfg SCL=<pin> SDA=<pin>
#
# Notes:
#   - With no args, it prints current config if present, otherwise usage.
#   - Uses existing helpers from bscan_tools.tcl:
#       bscan_build_cell_cache
#       bscan_get_output3_cells
#       bscan_cell_info
# -----------------------------------------------------------------------------
proc bscan_i2c_cfg {args} {

    # no args -> print current config if available
    if {[llength $args] == 0} {
        if {[info exists ::BSCAN_I2C(SCL_PIN)]} {
            puts "I2C current configuration:"
            puts "  SCL=$::BSCAN_I2C(SCL_PIN) OUT=$::BSCAN_I2C(SCL_OUT) CTL=$::BSCAN_I2C(SCL_CTL) DISVAL=$::BSCAN_I2C(SCL_DISVAL)"
            puts "  SDA=$::BSCAN_I2C(SDA_PIN) OUT=$::BSCAN_I2C(SDA_OUT) CTL=$::BSCAN_I2C(SDA_CTL) IN=$::BSCAN_I2C(SDA_IN) DISVAL=$::BSCAN_I2C(SDA_DISVAL)"
            return
        } else {
            puts "usage:"
            puts "  bscan_i2c_cfg SCL=<pin> SDA=<pin>"
            return
        }
    }

    catch {unset ::BSCAN_I2C}

    # checks like other bscan_* cfg procs
    if {![info exists ::BSCAN(br_len)] || $::BSCAN(br_len) eq ""} {
        puts "ERROR: ::BSCAN(br_len) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd>"
        return
    }
    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    set br_len $::BSCAN(br_len)

    # parse args
    array set raw {}
    foreach a $args {
        if {![regexp {^([^=]+)=(.+)$} $a -> key val]} {
            puts "ERROR: invalid argument '$a' (use KEY=VALUE)"
            return
        }
        set key [string toupper [string trim $key]]
        set val [string trim $val]

        switch -- $key {
            SCL { set raw(SCL) $val }
            SDA { set raw(SDA) $val }
            default {
                puts "ERROR: unknown parameter '$key'"
                return
            }
        }
    }

    foreach req {SCL SDA} {
        if {![info exists raw($req)] || $raw($req) eq ""} {
            puts "ERROR: missing $req"
            return
        }
    }

    # resolve SCL and SDA as OUTPUT3 pins
    foreach sig {SCL SDA} {
        set pin $raw($sig)

        set info [bscan_get_output3_cells $pin]
        if {$info eq ""} {
            puts "ERROR: pin $pin not found as output3 in BSDL"
            return
        }

        # expected: {port outidx ctlidx disval}
        lassign $info port outidx ctlidx disval

        if {$disval eq ""} {
            set disval 1
        }

        set ::BSCAN_I2C(${sig}_PIN)    $port
        set ::BSCAN_I2C(${sig}_OUT)    $outidx
        set ::BSCAN_I2C(${sig}_CTL)    $ctlidx
        set ::BSCAN_I2C(${sig}_DISVAL) $disval
    }

    # resolve SDA input cell
    set sda_pin $::BSCAN_I2C(SDA_PIN)
    set sda_in  ""

    for {set idx 0} {$idx < $br_len} {incr idx} {
        set ci [bscan_cell_info $idx]
        if {$ci eq ""} { continue }

        set parts [split $ci "|"]
        set port [string toupper [lindex $parts 1]]
        set func [string tolower [lindex $parts 2]]

        if {$port eq $sda_pin && $func eq "input"} {
            set sda_in $idx
            break
        }
    }

    if {$sda_in eq ""} {
        puts "ERROR: input cell for pin $sda_pin not found in BSDL"
        return
    }

    set ::BSCAN_I2C(SDA_IN) $sda_in

    puts "I2C configured:"
    puts "  SCL=$::BSCAN_I2C(SCL_PIN) OUT=$::BSCAN_I2C(SCL_OUT) CTL=$::BSCAN_I2C(SCL_CTL) DISVAL=$::BSCAN_I2C(SCL_DISVAL)"
    puts "  SDA=$::BSCAN_I2C(SDA_PIN) OUT=$::BSCAN_I2C(SDA_OUT) CTL=$::BSCAN_I2C(SDA_CTL) IN=$::BSCAN_I2C(SDA_IN) DISVAL=$::BSCAN_I2C(SDA_DISVAL)"
}

# -----------------------------------------------------------------------------
# I2C detect (7-bit address, READ detect only)
#
# Usage:
#   bscan_i2cdetect 0x50
#
# Sequence:
#   IDLE
#   START
#   send (addr<<1 | 1), MSB first
#   release SDA on 9th bit
#   capture ACK on SDA input
#   STOP
#
# Return:
#   1 = ACK
#   0 = NACK
# -----------------------------------------------------------------------------
proc bscan_i2cdetect {addr mode} {

    if {![info exists ::BSCAN_I2C(SCL_OUT)]} {
        puts "ERROR: I2C not configured. Run bscan_i2c_cfg first."
        return
    }

    if {$mode ne "-w" && $mode ne "-r"} {
        puts "ERROR: specify -w or -r"
        return
    }

    # parse address
    if {![string is integer -strict $addr]} {
        if {[scan $addr %i parsed] != 1} {
            puts "ERROR: invalid address '$addr'"
            return
        }
        set addr $parsed
    }

    if {$addr < 0 || $addr > 127} {
        puts "ERROR: address must be 0..127"
        return
    }

    set br_len     $::BSCAN(br_len)
    set irlen      $::BSCAN(irlen)
    set op_sample  [format %02X [expr "0x$::BSCAN(op_sample)"]]
    set op_extest  [format %02X [expr "0x$::BSCAN(op_extest)"]]

    set scl_out    $::BSCAN_I2C(SCL_OUT)
    set scl_ctl    $::BSCAN_I2C(SCL_CTL)
    set scl_disval $::BSCAN_I2C(SCL_DISVAL)

    set sda_out    $::BSCAN_I2C(SDA_OUT)
    set sda_ctl    $::BSCAN_I2C(SDA_CTL)
    set sda_in     $::BSCAN_I2C(SDA_IN)
    set sda_disval $::BSCAN_I2C(SDA_DISVAL)

    # ------------------------------------------------------------
    # base frame (SAMPLE)
    # ------------------------------------------------------------
    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_sample
    $seq drshift -state IDLE -capture $br_len
    set base [$seq run -bits -single]
    catch {$seq delete}

    if {[string length $base] > $br_len} {
        set base [string range $base 0 [expr {$br_len - 1}]]
    } elseif {[string length $base] < $br_len} {
        append base [string repeat 1 [expr {$br_len - [string length $base]}]]
    }

    # ------------------------------------------------------------
    # frames
    # ------------------------------------------------------------
    set frame_idle   [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval Z]
    set frame_start1 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval Z]
    set frame_start2 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval L]

    set frame_00 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval L]
    set frame_01 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval Z]
    set frame_10 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval L]
    set frame_11 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval Z]

    set frame_ack_lo [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval L]
    set frame_ack_hi [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval Z]

    set frame_stop1 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval L]
    set frame_stop2 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval L $scl_out $scl_ctl $scl_disval Z]
    set frame_stop3 [__bscan_i2c_mkframe $base $sda_out $sda_ctl $sda_disval Z $scl_out $scl_ctl $scl_disval Z]

    # ------------------------------------------------------------
    # build sequence
    # ------------------------------------------------------------
    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_extest

    # start
    $seq drshift -state IDLE -bits $br_len $frame_idle
    $seq drshift -state IDLE -bits $br_len $frame_start1
    $seq drshift -state IDLE -bits $br_len $frame_start2

    # select R/W
    if {$mode eq "-w"} {
        set byte [expr {($addr << 1) | 0}]
    } else {
        set byte [expr {($addr << 1) | 1}]
    }

    # send byte
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]

        if {$bit == 0} {
            $seq drshift -state IDLE -bits $br_len $frame_00
            $seq drshift -state IDLE -bits $br_len $frame_01
            $seq drshift -state IDLE -bits $br_len $frame_00
        } else {
            $seq drshift -state IDLE -bits $br_len $frame_10
            $seq drshift -state IDLE -bits $br_len $frame_11
            $seq drshift -state IDLE -bits $br_len $frame_10
        }
    }

    # ACK
    $seq drshift -state IDLE -bits $br_len $frame_ack_lo
    $seq drshift -state IDLE -bits $br_len $frame_ack_hi
    $seq drshift -state IDLE -capture -bits $br_len $frame_ack_hi
    $seq drshift -state IDLE -bits $br_len $frame_ack_lo

    # STOP
    $seq drshift -state IDLE -bits $br_len $frame_stop1
    $seq drshift -state IDLE -bits $br_len $frame_stop2
    $seq drshift -state IDLE -bits $br_len $frame_stop3
    $seq state IDLE

    set raw [$seq run -bits]
    catch {$seq delete}

    set ack_frame [lindex $raw end]
    set sda_sample [string index $ack_frame $sda_in]

	proc ::c_green {txt} {
		return "\033\[32m${txt}\033\[0m"
	}
	
	proc ::c_orange {txt} {
		return "\033\[38;5;208m${txt}\033\[0m"
	}

	if {$sda_sample eq "0"} {
		puts [format "0x%02X %s : %s (%d)" \
			$addr \
			$mode \
			[::c_green "ACK"] \
			1]
		#return 1
	} else {
		puts [format "0x%02X %s : %s (%d)" \
			$addr \
			$mode \
			[::c_orange "NACK"] \
			0]
		#return 0
	}
}

proc ::c_green {txt} {
    return "\033\[32m${txt}\033\[0m"
}

proc ::c_orange {txt} {
    return "\033\[38;5;208m${txt}\033\[0m"
}

proc ::c_gray {txt} {
    return "\033\[90m${txt}\033\[0m"
}

proc __bscan_i2c_tok {byte ack} {
    if {$ack eq "ACK"} {
        set col [::c_green "ACK"]
    } elseif {$ack eq "NACK"} {
        set col [::c_orange "NACK"]
    } else {
        set col [::c_gray "--"]
    }
    return [format "%s(%s)" $byte $col]
}

proc __bscan_i2c_mkframe {base \
                          sda_out sda_ctl sda_disval sda_mode \
                          scl_out scl_ctl scl_disval scl_mode} {

    set frame $base

    if {$sda_mode eq "L"} {
        set sda_enable [expr {$sda_disval ? 0 : 1}]
        set frame [string replace $frame $sda_ctl $sda_ctl $sda_enable]
        set frame [string replace $frame $sda_out $sda_out 0]
    } else {
        set frame [string replace $frame $sda_ctl $sda_ctl $sda_disval]
        set frame [string replace $frame $sda_out $sda_out 0]
    }

    if {$scl_mode eq "L"} {
        set scl_enable [expr {$scl_disval ? 0 : 1}]
        set frame [string replace $frame $scl_ctl $scl_ctl $scl_enable]
        set frame [string replace $frame $scl_out $scl_out 0]
    } else {
        set frame [string replace $frame $scl_ctl $scl_ctl $scl_disval]
        set frame [string replace $frame $scl_out $scl_out 0]
    }

    return $frame
}

proc __bscan_i2c_get_base_and_frames {} {

    if {![info exists ::BSCAN_I2C(SCL_OUT)]} {
        error "I2C not configured. Run bscan_i2c_cfg first."
    }

    set br_len     $::BSCAN(br_len)
    set irlen      $::BSCAN(irlen)
    set op_sample  [format %02X [expr "0x$::BSCAN(op_sample)"]]

    set scl_out    $::BSCAN_I2C(SCL_OUT)
    set scl_ctl    $::BSCAN_I2C(SCL_CTL)
    set scl_disval $::BSCAN_I2C(SCL_DISVAL)

    set sda_out    $::BSCAN_I2C(SDA_OUT)
    set sda_ctl    $::BSCAN_I2C(SDA_CTL)
    set sda_in     $::BSCAN_I2C(SDA_IN)
    set sda_disval $::BSCAN_I2C(SDA_DISVAL)

    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_sample
    $seq drshift -state IDLE -capture $br_len
    set base [$seq run -bits -single]
    catch {$seq delete}

    if {$base eq ""} {
        error "failed to capture base boundary-register image"
    }
    if {[string length $base] > $br_len} {
        set base [string range $base 0 [expr {$br_len - 1}]]
    } elseif {[string length $base] < $br_len} {
        append base [string repeat 1 [expr {$br_len - [string length $base]}]]
    }

    array set F {}
    set F(idle) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    set F(start1) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval Z]

    set F(start2) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval L]

    set F(00) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval L]

    set F(01) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval Z]

    set F(10) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval L]

    set F(11) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    set F(ack_lo) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval L]

    set F(ack_hi) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    set F(stop1) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval L]

    set F(stop2) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval Z]

    set F(stop3) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    # read data bit: slave drives SDA, master releases SDA
    set F(read_lo) $F(ack_lo)
    set F(read_hi) $F(ack_hi)

    # master ACK after read byte
    set F(ackm_lo) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval L]

    set F(ackm_hi) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval Z]

    # master NACK after read byte
    set F(nack_lo) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval L]

    set F(nack_hi) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    # repeated start
    set F(rs0) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval L]

    set F(rs1) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval Z \
        $scl_out $scl_ctl $scl_disval Z]

    set F(rs2) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval Z]

    set F(rs3) [__bscan_i2c_mkframe $base \
        $sda_out $sda_ctl $sda_disval L \
        $scl_out $scl_ctl $scl_disval L]

    return [list $base [array get F] $sda_in]
}

proc __bscan_i2c_emit_start {seq br_len frames} {
    array set F $frames
    $seq drshift -state IDLE -bits $br_len $F(idle)
    $seq drshift -state IDLE -bits $br_len $F(start1)
    $seq drshift -state IDLE -bits $br_len $F(start2)
}

proc __bscan_i2c_emit_rstart {seq br_len frames} {
    array set F $frames
    $seq drshift -state IDLE -bits $br_len $F(rs0)
    $seq drshift -state IDLE -bits $br_len $F(rs1)
    $seq drshift -state IDLE -bits $br_len $F(rs2)
    $seq drshift -state IDLE -bits $br_len $F(rs3)
}

proc __bscan_i2c_emit_stop {seq br_len frames} {
    array set F $frames
    $seq drshift -state IDLE -bits $br_len $F(stop1)
    $seq drshift -state IDLE -bits $br_len $F(stop2)
    $seq drshift -state IDLE -bits $br_len $F(stop3)
}

proc __bscan_i2c_emit_write_byte {seq br_len frames byte} {
    array set F $frames
    for {set i 7} {$i >= 0} {incr i -1} {
        set bit [expr {($byte >> $i) & 1}]
        if {$bit == 0} {
            $seq drshift -state IDLE -bits $br_len $F(00)
            $seq drshift -state IDLE -bits $br_len $F(01)
            $seq drshift -state IDLE -bits $br_len $F(00)
        } else {
            $seq drshift -state IDLE -bits $br_len $F(10)
            $seq drshift -state IDLE -bits $br_len $F(11)
            $seq drshift -state IDLE -bits $br_len $F(10)
        }
    }
    $seq drshift -state IDLE -bits $br_len $F(ack_lo)
    $seq drshift -state IDLE -bits $br_len $F(ack_hi)
    $seq drshift -state IDLE -capture -bits $br_len $F(ack_hi)
    $seq drshift -state IDLE -bits $br_len $F(ack_lo)
}

proc __bscan_i2c_emit_read_byte {seq br_len frames last} {
    array set F $frames
    for {set i 0} {$i < 8} {incr i} {
        $seq drshift -state IDLE -bits $br_len $F(read_lo)
        $seq drshift -state IDLE -bits $br_len $F(read_hi)
        $seq drshift -state IDLE -capture -bits $br_len $F(read_hi)
        $seq drshift -state IDLE -bits $br_len $F(read_lo)
    }
    if {$last} {
        $seq drshift -state IDLE -bits $br_len $F(nack_lo)
        $seq drshift -state IDLE -bits $br_len $F(nack_hi)
        return NACK
    } else {
        $seq drshift -state IDLE -bits $br_len $F(ackm_lo)
        $seq drshift -state IDLE -bits $br_len $F(ackm_hi)
        return ACK
    }
}

proc __bscan_i2c_ack_from_capture {cap sda_in} {
    set bit [string index $cap $sda_in]
    expr {$bit eq "0" ? "ACK" : "NACK"}
}

proc __bscan_i2c_byte_from_caps {caps sda_in} {
    set v 0
    foreach c $caps {
        set b [string index $c $sda_in]
        set v [expr {($v << 1) | ($b eq "1" ? 1 : 0)}]
    }
    return $v
}

proc bscan_i2cset {addr reg args} {

	# data opzionali
	set data_bytes {}
	foreach d $args {
		if {![string is integer -strict $d]} {
			if {[scan $d %i parsed] != 1} { error "invalid data byte '$d'" }
			set d $parsed
		}
		lappend data_bytes [expr {$d & 0xFF}]
	}

    if {![string is integer -strict $addr]} {
        if {[scan $addr %i parsed] != 1} { error "invalid address '$addr'" }
        set addr $parsed
    }
    if {![string is integer -strict $reg]} {
        if {[scan $reg %i parsed] != 1} { error "invalid register '$reg'" }
        set reg $parsed
    }

    set data_bytes {}
    foreach d $args {
        if {![string is integer -strict $d]} {
            if {[scan $d %i parsed] != 1} { error "invalid data byte '$d'" }
            set d $parsed
        }
        lappend data_bytes [expr {$d & 0xFF}]
    }

    lassign [__bscan_i2c_get_base_and_frames] base frames sda_in
    array set F $frames

    set br_len    $::BSCAN(br_len)
    set irlen     $::BSCAN(irlen)
    set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]

    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_extest

    __bscan_i2c_emit_start $seq $br_len $frames

    set addrw [expr {(($addr & 0x7F) << 1) | 0}]
    __bscan_i2c_emit_write_byte $seq $br_len $frames $addrw
    __bscan_i2c_emit_write_byte $seq $br_len $frames [expr {$reg & 0xFF}]

    foreach d $data_bytes {
        __bscan_i2c_emit_write_byte $seq $br_len $frames $d
    }

    __bscan_i2c_emit_stop $seq $br_len $frames
    $seq state IDLE

    set raw [$seq run -bits]
    catch {$seq delete}

    # expected captures: addr/reg/data...
    set caps $raw
    set idx 0
    set toks {}

    if {[llength $caps] < [expr {2 + [llength $data_bytes]}]} {
        puts "ERROR: insufficient capture frames"
        return 0
    }

    set ack [__bscan_i2c_ack_from_capture [lindex $caps $idx] $sda_in]
    lappend toks [__bscan_i2c_tok [format "0x%02X(W)" $addr] $ack]
    incr idx

    set reg_ack [__bscan_i2c_ack_from_capture [lindex $caps $idx] $sda_in]
    lappend toks [__bscan_i2c_tok [format "0x%02X" [expr {$reg & 0xFF}]] $reg_ack]
    incr idx

    set ok [expr {$ack eq "ACK" && $reg_ack eq "ACK"}]

    foreach d $data_bytes {
        if {$ok && $idx < [llength $caps]} {
            set da [__bscan_i2c_ack_from_capture [lindex $caps $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X" $d] $da]
            if {$da ne "ACK"} { set ok 0 }
            incr idx
        } else {
            lappend toks [__bscan_i2c_tok [format "0x%02X" $d] --]
        }
    }

    puts [join $toks "  "]
    
}

proc bscan_i2cget {args} {

    set use_rs 0
    set addr_mode ""

    if {[llength $args] < 3} {
        puts "usage:"
        puts "  bscan_i2cget <addr> <nbyte> -r|-w"
        puts "  bscan_i2cget <addr> <reg> <nbyte> -r|-w ?-rs?"
        return
    }

    # parse trailing options
    set posargs {}
    foreach a $args {
        switch -- $a {
            -rs {
                set use_rs 1
            }
            -r {
                set addr_mode r
            }
            -w {
                set addr_mode w
            }
            default {
                lappend posargs $a
            }
        }
    }

    if {$addr_mode eq ""} {
        error "missing -r or -w"
    }

    if {[llength $posargs] == 2} {
        # form: <addr> <nbyte> -r|-w
        set addr  [lindex $posargs 0]
        set nbyte [lindex $posargs 1]
        set use_reg 0

    } elseif {[llength $posargs] == 3} {
        # form: <addr> <reg> <nbyte> -r|-w ?-rs?
        set addr  [lindex $posargs 0]
        set reg   [lindex $posargs 1]
        set nbyte [lindex $posargs 2]
        set use_reg 1

    } else {
        puts "usage:"
        puts "  bscan_i2cget <addr> <nbyte> -r|-w"
        puts "  bscan_i2cget <addr> <reg> <nbyte> -r|-w ?-rs?"
        return
    }

    if {![string is integer -strict $addr]} {
        if {[scan $addr %i parsed] != 1} { error "invalid address '$addr'" }
        set addr $parsed
    }

    if {$use_reg} {
        if {![string is integer -strict $reg]} {
            if {[scan $reg %i parsed] != 1} { error "invalid register '$reg'" }
            set reg $parsed
        }
    }

    if {![string is integer -strict $nbyte]} {
        if {[scan $nbyte %i parsed] != 1} { error "invalid nbyte '$nbyte'" }
        set nbyte $parsed
    }
    if {$nbyte < 1} {
        error "nbyte must be >= 1"
    }

    lassign [__bscan_i2c_get_base_and_frames] base frames sda_in
    array set F $frames

    set br_len    $::BSCAN(br_len)
    set irlen     $::BSCAN(irlen)
    set op_extest [format %02X [expr "0x$::BSCAN(op_extest)"]]

    set seq [jtag sequence]
    $seq state RESET
    $seq state IDLE
    $seq irshift -state IDLE -hex $irlen $op_extest

    __bscan_i2c_emit_start $seq $br_len $frames

    if {$addr_mode eq "r"} {
        set addr_byte_mode [expr {(($addr & 0x7F) << 1) | 1}]
        set addr_tag "(R)"
    } else {
        set addr_byte_mode [expr {(($addr & 0x7F) << 1) | 0}]
        set addr_tag "(W)"
    }

    if {!$use_reg} {
        # --------------------------------------------------
        # no register:
        # START + ADDR(mode) + READ...
        # --------------------------------------------------
        __bscan_i2c_emit_write_byte $seq $br_len $frames $addr_byte_mode

    } else {
        # --------------------------------------------------
        # with register:
        # default: START + ADDR(mode) + REG + READ...
        # with -rs: START + ADDR(W) + REG + REPEATED START + ADDR(mode) + READ...
        # --------------------------------------------------
        if {$use_rs} {
            set addrw [expr {(($addr & 0x7F) << 1) | 0}]
            __bscan_i2c_emit_write_byte $seq $br_len $frames $addrw
            __bscan_i2c_emit_write_byte $seq $br_len $frames [expr {$reg & 0xFF}]
            __bscan_i2c_emit_rstart $seq $br_len $frames
            __bscan_i2c_emit_write_byte $seq $br_len $frames $addr_byte_mode
        } else {
            __bscan_i2c_emit_write_byte $seq $br_len $frames $addr_byte_mode
            __bscan_i2c_emit_write_byte $seq $br_len $frames [expr {$reg & 0xFF}]
        }
    }

    set data_master_acks {}
    for {set i 0} {$i < $nbyte} {incr i} {
        lappend data_master_acks [__bscan_i2c_emit_read_byte $seq $br_len $frames [expr {$i == $nbyte-1}]]
    }

    __bscan_i2c_emit_stop $seq $br_len $frames
    $seq state IDLE

    set raw [$seq run -bits]
    catch {$seq delete}

    set toks {}
    set data_list {}
    set idx 0

    if {!$use_reg} {
        # captures:
        # 0 = ACK for ADDR(mode)
        # then 8 captures per data byte
        if {[llength $raw] < [expr {1 + 8*$nbyte}]} {
            puts "ERROR: insufficient capture frames"
            return {}
        }

        set addr_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
        lappend toks [__bscan_i2c_tok [format "0x%02X%s" $addr $addr_tag] $addr_ack]
        incr idx

        if {$addr_ack ne "ACK"} {
            for {set i 0} {$i < $nbyte} {incr i} {
                lappend toks [__bscan_i2c_tok "--" --]
            }
            puts [join $toks "  "]
            return {}
        }

        for {set i 0} {$i < $nbyte} {incr i} {
            set caps [lrange $raw $idx [expr {$idx+7}]]
            set val [__bscan_i2c_byte_from_caps $caps $sda_in]
            lappend data_list [format "0x%02X" $val]
            lappend toks [__bscan_i2c_tok [format "0x%02X" $val] [lindex $data_master_acks $i]]
            incr idx 8
        }

        puts [join $toks "  "]
        return $data_list

    } else {
        if {$use_rs} {
            # captures:
            # 0 = ACK for ADDR(W)
            # 1 = ACK for REG
            # 2 = ACK for ADDR(mode)
            # then 8 captures per data byte
            if {[llength $raw] < [expr {3 + 8*$nbyte}]} {
                puts "ERROR: insufficient capture frames"
                return {}
            }

            set addrw_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X(W)" $addr] $addrw_ack]
            incr idx

            set reg_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X" [expr {$reg & 0xFF}]] $reg_ack]
            incr idx

            set addrm_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X%s" $addr $addr_tag] $addrm_ack]
            incr idx

            if {$addrw_ack ne "ACK" || $reg_ack ne "ACK" || $addrm_ack ne "ACK"} {
                for {set i 0} {$i < $nbyte} {incr i} {
                    lappend toks [__bscan_i2c_tok "--" --]
                }
                puts [join $toks "  "]
                return {}
            }

        } else {
            # captures:
            # 0 = ACK for ADDR(mode)
            # 1 = ACK for REG
            # then 8 captures per data byte
            if {[llength $raw] < [expr {2 + 8*$nbyte}]} {
                puts "ERROR: insufficient capture frames"
                return {}
            }

            set addrm_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X%s" $addr $addr_tag] $addrm_ack]
            incr idx

            set reg_ack [__bscan_i2c_ack_from_capture [lindex $raw $idx] $sda_in]
            lappend toks [__bscan_i2c_tok [format "0x%02X" [expr {$reg & 0xFF}]] $reg_ack]
            incr idx

            if {$addrm_ack ne "ACK" || $reg_ack ne "ACK"} {
                for {set i 0} {$i < $nbyte} {incr i} {
                    lappend toks [__bscan_i2c_tok "--" --]
                }
                puts [join $toks "  "]
                return {}
            }
        }

        for {set i 0} {$i < $nbyte} {incr i} {
            set caps [lrange $raw $idx [expr {$idx+7}]]
            set val [__bscan_i2c_byte_from_caps $caps $sda_in]
            lappend data_list [format "0x%02X" $val]
            lappend toks [__bscan_i2c_tok [format "0x%02X" $val] [lindex $data_master_acks $i]]
            incr idx 8
        }

        puts [join $toks "  "]
        return $data_list
    }
}

proc bscan_i2cscan {mode} {

    if {$mode ne "-w" && $mode ne "-r"} {
        puts "usage:"
        puts "  bscan_i2cscan -w|-r"
        return
    }

    puts ""
    puts [::c_sec "I2C scan $mode:"]

    set found 0

    for {set addr 0} {$addr < 128} {incr addr} {
        set rc [bscan_i2cdetect $addr $mode]

        if {$rc eq ""} {
            set rc 0
        }

        if {$rc} {
            incr found
        }
    }

    puts ""
    puts [format "devices found: %d" $found]
}

# ------------------------------------------------------------
# Capture stdout produced by a script that uses "puts"
# Returns all captured text as a single string
# ------------------------------------------------------------
proc __bscan_capture_puts {script} {
    set ::__BSCAN_PUTS_BUF ""

    # salva puts originale
    if {[llength [info commands __bscan_real_puts]] == 0} {
        rename puts __bscan_real_puts
    }

    # wrapper puts: cattura stdout, lascia passare gli altri canali
    proc puts {args} {
        if {[llength $args] == 1} {
            append ::__BSCAN_PUTS_BUF [lindex $args 0] "\n"
            return
        }

        if {[llength $args] == 2} {
            set a0 [lindex $args 0]
            set a1 [lindex $args 1]

            if {$a0 eq "-nonewline"} {
                append ::__BSCAN_PUTS_BUF $a1
                return
            }

            # puts <channel> <string>
            if {$a0 eq "stdout" || $a0 eq "stderr"} {
                append ::__BSCAN_PUTS_BUF $a1 "\n"
                return
            }

            __bscan_real_puts {*}$args
            return
        }

        if {[llength $args] == 3} {
            set a0 [lindex $args 0]
            set a1 [lindex $args 1]
            set a2 [lindex $args 2]

            # puts -nonewline stdout "..."
            if {$a0 eq "-nonewline" && ($a1 eq "stdout" || $a1 eq "stderr")} {
                append ::__BSCAN_PUTS_BUF $a2
                return
            }

            __bscan_real_puts {*}$args
            return
        }

        __bscan_real_puts {*}$args
    }

    set rc [catch {uplevel 1 $script} err opts]
    set out $::__BSCAN_PUTS_BUF

    # ripristina puts originale
    rename puts {}
    rename __bscan_real_puts puts
    unset ::__BSCAN_PUTS_BUF

    if {$rc} {
        return -options $opts $err
    }

    return $out
}

# ------------------------------------------------------------
# Return first captured input value for a pin after driving it
# Uses bscan_output_capture and parses its printed output
#
# Return:
#   "0" / "1" on success
#   ""        if not found
# ------------------------------------------------------------
proc __bscan_capture_pin_value {pin driveval} {
    set pin_u [string toupper $pin]

    set txt [__bscan_capture_puts [list \
        bscan_output_capture -s $pin_u $driveval -port $pin_u -function input]]

    foreach line [split $txt "\n"] {
        set s [string trim $line]
        if {$s eq ""} { continue }

        # prendi tutto quello che viene dopo il primo :
        set p [string first ":" $s]
        if {$p < 0} { continue }

        set tail [string range $s [expr {$p+1}] end]

        # rimuovi codici ANSI colore tipo ESC[36m ... ESC[0m
        regsub -all {\x1b\[[0-9;]*m} $tail "" tail

        # trim finale
        set tail [string trim $tail]

        # il primo carattere utile dopo ":" deve essere 0 o 1
        if {[regexp {^([01])} $tail -> bit]} {
            return $bit
        }
    }

    return ""
}
# ------------------------------------------------------------
# Test output3 pins one-by-one and print report:
# TEST: IO_P5      = PASS -> SET_1=PASS SET_0=PASS
#
# Usage:
#   bscan_test_output3
#   bscan_test_output3 IO_P5
#   bscan_test_output3 P5
#   bscan_test_output3 IO_P5 IO_M12 DONE_P9
# ------------------------------------------------------------
proc bscan_test_output3 {args} {

    # sanity
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
        return
    }

    if {![info exists ::BSCAN_OUT3_READY] || $::BSCAN_OUT3_READY != 1} {
        if {![bscan_parse_output3_map]} { return }
    }

    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    # costruisci lista pin da testare
    set pin_list {}

    if {[llength $args] == 0} {
        foreach p [lsort [array names ::BSCAN_OUT3_OUT]] {
            lappend pin_list $p
        }
    } else {
        foreach a $args {
            set info [bscan_get_output3_cells $a]
            if {$info eq ""} {
                puts "ERROR: pin $a not found as output3 in BSDL"
                continue
            }
            lassign $info port outidx ctlidx disval
            if {[lsearch -exact $pin_list $port] < 0} {
                lappend pin_list $port
            }
        }
    }

    if {[llength $pin_list] == 0} {
        puts "ERROR: no output3 pins to test"
        return
    }

    foreach pin $pin_list {
        set bit1 [__bscan_capture_pin_value $pin 1]
        set bit0 [__bscan_capture_pin_value $pin 0]

        set set1 [expr {$bit1 eq "1" ? "PASS" : "FAIL"}]
        set set0 [expr {$bit0 eq "0" ? "PASS" : "FAIL"}]

        set overall [expr {($set1 eq "PASS" && $set0 eq "PASS") ? "PASS" : "FAIL"}]

		# colora FAIL con lo stesso arancione usato da bscan_input
		set set1_c    [expr {$set1   eq "FAIL" ? [::c_orange $set1]   : $set1}]
		set set0_c    [expr {$set0   eq "FAIL" ? [::c_orange $set0]   : $set0}]
		set overall_c [expr {$overall eq "FAIL" ? [::c_orange $overall] : $overall}]
		
		puts [format "TEST: %-10s = %s -> SET_1=%s SET_0=%s" \
			$pin $overall_c $set1_c $set0_c]


    }
}

proc bscan_test_output3 {args} {

    # sanity
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
        return
    }

    if {![info exists ::BSCAN_OUT3_READY] || $::BSCAN_OUT3_READY != 1} {
        if {![bscan_parse_output3_map]} { return }
    }

    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    # parse args
    set exclude_list {}
    set user_pins {}

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]

        if {$a eq "-exclude"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -exclude requires a pin list"
                return
            }
            set exclude_list [lindex $args $i]
        } else {
            lappend user_pins $a
        }
        incr i
    }

    # normalizza exclude usando il nome reale del port
    set exclude_norm {}
    foreach x $exclude_list {
        set info [bscan_get_output3_cells $x]
        if {$info ne ""} {
            lassign $info port outidx ctlidx disval
            lappend exclude_norm $port
        } else {
            lappend exclude_norm [string toupper $x]
        }
    }
    set exclude_list $exclude_norm

    # build pin list
    set pin_list {}

    if {[llength $user_pins] == 0} {
        foreach p [lsort [array names ::BSCAN_OUT3_OUT]] {
            lappend pin_list $p
        }
    } else {
        foreach a $user_pins {
            set info [bscan_get_output3_cells $a]
            if {$info eq ""} {
                puts "ERROR: pin $a not found as output3 in BSDL"
                continue
            }
            lassign $info port outidx ctlidx disval
            if {[lsearch -exact $pin_list $port] < 0} {
                lappend pin_list $port
            }
        }
    }

    # apply exclude
    if {[llength $exclude_list] > 0} {
        set tmp {}
        foreach p $pin_list {
            if {[lsearch -exact $exclude_list $p] >= 0} {
                continue
            }
            lappend tmp $p
        }
        set pin_list $tmp
    }

    if {[llength $pin_list] == 0} {
        puts "ERROR: no output3 pins to test"
        return
    }

    # run test
    foreach pin $pin_list {
        set bit1 [__bscan_capture_pin_value $pin 1]
        set bit0 [__bscan_capture_pin_value $pin 0]

        set set1 [expr {$bit1 eq "1" ? "PASS" : "FAIL"}]
        set set0 [expr {$bit0 eq "0" ? "PASS" : "FAIL"}]

        set overall [expr {($set1 eq "PASS" && $set0 eq "PASS") ? "PASS" : "FAIL"}]

        set set1_c    [expr {$set1 eq "FAIL" ? [::c_orange $set1] : $set1}]
        set set0_c    [expr {$set0 eq "FAIL" ? [::c_orange $set0] : $set0}]
        set overall_c [expr {$overall eq "FAIL" ? [::c_orange $overall] : $overall}]

        puts [format "TEST: %-10s = %s -> SET_1=%s SET_0=%s" \
            $pin $overall_c $set1_c $set0_c]
    }
}

proc bscan_output3_scan {args} {

    # sanity
    if {![info exists ::BSCAN(bsdl)] || $::BSCAN(bsdl) eq ""} {
        puts "ERROR: ::BSCAN(bsdl) not set. Run bscan_load <file.bsd> first."
        return
    }

    if {![info exists ::BSCAN_OUT3_READY] || $::BSCAN_OUT3_READY != 1} {
        if {![bscan_parse_output3_map]} { return }
    }

    if {![info exists ::BSCAN_CELL_READY] || $::BSCAN_CELL_READY != 1} {
        if {![bscan_build_cell_cache]} { return }
    }

    # parse args
    set include_list {}
    set exclude_list {}
    set user_pins {}

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {$a eq "-include"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -include requires a pin list"
                return
            }
            set include_list [lindex $args $i]
        } elseif {$a eq "-exclude"} {
            incr i
            if {$i >= [llength $args]} {
                puts "ERROR: -exclude requires a pin list"
                return
            }
            set exclude_list [lindex $args $i]
        } else {
            lappend user_pins $a
        }
        incr i
    }

    # normalizza include usando il nome reale del port
    set include_norm {}
    foreach x $include_list {
        set info [bscan_get_output3_cells $x]
        if {$info ne ""} {
            lassign $info port outidx ctlidx disval
            lappend include_norm $port
        } else {
            lappend include_norm [string toupper $x]
        }
    }
    set include_list $include_norm

    # normalizza exclude usando il nome reale del port
    set exclude_norm {}
    foreach x $exclude_list {
        set info [bscan_get_output3_cells $x]
        if {$info ne ""} {
            lassign $info port outidx ctlidx disval
            lappend exclude_norm $port
        } else {
            lappend exclude_norm [string toupper $x]
        }
    }
    set exclude_list $exclude_norm

    # build pin list
    set pin_list {}

    if {[llength $user_pins] == 0} {
        foreach p [lsort [array names ::BSCAN_OUT3_OUT]] {
            lappend pin_list $p
        }
    } else {
        foreach a $user_pins {
            set info [bscan_get_output3_cells $a]
            if {$info eq ""} {
                puts "ERROR: pin $a not found as output3 in BSDL"
                continue
            }
            lassign $info port outidx ctlidx disval
            if {[lsearch -exact $pin_list $port] < 0} {
                lappend pin_list $port
            }
        }
    }

    # apply include
    if {[llength $include_list] > 0} {
        set tmp {}
        foreach p $pin_list {
            if {[lsearch -exact $include_list $p] < 0} {
                continue
            }
            lappend tmp $p
        }
        set pin_list $tmp
    }

    # apply exclude
    if {[llength $exclude_list] > 0} {
        set tmp {}
        foreach p $pin_list {
            if {[lsearch -exact $exclude_list $p] >= 0} {
                continue
            }
            lappend tmp $p
        }
        set pin_list $tmp
    }

    if {[llength $pin_list] == 0} {
        puts "ERROR: no output3 pins to test"
        return
    }
	
    # warning map: pin -> follower list
    catch {unset WARN_FOLLOW_MAP}
    set warn_pin_list {}	
    
	# lista pin con errore di drive (self-check fail)
    set fail_drive_list {}	

    foreach pin $pin_list {

        set pin_u [string toupper $pin]

        # ----------------------------
        # capture drive=1
        # ----------------------------
        set txt1 [__bscan_capture_puts [list \
            bscan_output_capture 5 -s $pin_u 1 -function input]]

        # ----------------------------
        # capture drive=0
        # ----------------------------
        set txt0 [__bscan_capture_puts [list \
            bscan_output_capture 5 -s $pin_u 0 -function input]]

        # ----------------------------
        # parse full capture
        # each line may contain many entries separated by |
        # example:
        # 208:0 ... | 209:1 ... | 212:1 BC_2,IO_M12,input
        # ----------------------------
        set cap1 [dict create]
        foreach line [split $txt1 "\n"] {
            set s [string trim $line]
            if {$s eq ""} { continue }

            regsub -all {\x1b\[[0-9;]*m} $s "" s

            foreach item [split $s "|"] {
                set item [string trim $item]
                if {$item eq ""} { continue }

                if {[regexp {^[0-9]+:([01])\s+[^,]+,([^,]+),input$} $item -> bit port]} {
                    dict set cap1 [string toupper [string trim $port]] $bit
                }
            }
        }

        set cap0 [dict create]
        foreach line [split $txt0 "\n"] {
            set s [string trim $line]
            if {$s eq ""} { continue }

            regsub -all {\x1b\[[0-9;]*m} $s "" s

            foreach item [split $s "|"] {
                set item [string trim $item]
                if {$item eq ""} { continue }

                if {[regexp {^[0-9]+:([01])\s+[^,]+,([^,]+),input$} $item -> bit port]} {
                    dict set cap0 [string toupper [string trim $port]] $bit
                }
            }
        }

        # self check
        set bit1 ""
        set bit0 ""

        if {[dict exists $cap1 $pin_u]} { set bit1 [dict get $cap1 $pin_u] }
        if {[dict exists $cap0 $pin_u]} { set bit0 [dict get $cap0 $pin_u] }

        set set1 [expr {$bit1 eq "1" ? "PASS" : "FAIL"}]
        set set0 [expr {$bit0 eq "0" ? "PASS" : "FAIL"}]
		
        # salva pin con errore di drive
        if {$set1 ne "PASS" || $set0 ne "PASS"} {
            lappend fail_drive_list $pin_u
        }		

        # followers: pins that read 1 with drive=1 and 0 with drive=0
        # exclude also pins present in -exclude
        set followers {}
        foreach p [lsort [dict keys $cap1]] {
            if {![dict exists $cap0 $p]} { continue }

            # non confrontare il pin stesso
            if {$p eq $pin_u} { continue }

            # non confrontare i pin esclusi
            if {[lsearch -exact $exclude_list $p] >= 0} { continue }

            # non confrontare i pin non presenti in -include
            if {[llength $include_list] > 0 && [lsearch -exact $include_list $p] < 0} { continue }

            set v1 [dict get $cap1 $p]
            set v0 [dict get $cap0 $p]

            if {$v1 eq "1" && $v0 eq "0"} {
                lappend followers $p
            }
        }

        if {[llength $followers] == 0} {
            set follow_str "x"
        } else {
            set follow_str [join $followers ", "]
        }
        # salva i casi con follower per il confronto finale bidirezionale
        if {[llength $followers] > 0} {
            set WARN_FOLLOW_MAP($pin_u) $followers
            lappend warn_pin_list $pin_u
        }

        # overall:
        # - FAIL    se self-check fallisce
        # - WARNING se self-check passa ma ci sono follower
        # - PASS    se self-check passa e non ci sono follower
        set overall "PASS"
        if {$set1 ne "PASS" || $set0 ne "PASS"} {
            set overall "FAIL"
        } elseif {[llength $followers] > 0} {
            set overall "WARNING"
        }

        set set1_c [expr {$set1 eq "FAIL" ? [::c_orange $set1] : $set1}]
        set set0_c [expr {$set0 eq "FAIL" ? [::c_orange $set0] : $set0}]

		# giallo come nel banner (ANSI 33)
		set C_YELLOW "\033\[33m"
		set C_RESET  "\033\[0m"
		
		if {$overall eq "FAIL"} {
			set overall_c [::c_orange $overall]
		} elseif {$overall eq "WARNING"} {
			set overall_c "${C_YELLOW}${overall}${C_RESET}"
		} else {
			set overall_c $overall
		}

        puts [format "ST: %-10s = %s -> SET_1=%s; SET_0=%s; FOLLOW=%s" \
            $pin_u $overall_c $set1_c $set0_c $follow_str]
    }
    puts ""

    # confronto finale warning <-> warning
    # se A segue B e B segue A, segnala FAIL bidirezionale
    set bidir_fail_pairs {}
    set bidir_fail_pins {}

    foreach a [lsort -unique $warn_pin_list] {
        if {![info exists WARN_FOLLOW_MAP($a)]} { continue }

        foreach b $WARN_FOLLOW_MAP($a) {
            if {![info exists WARN_FOLLOW_MAP($b)]} { continue }

            if {[lsearch -exact $WARN_FOLLOW_MAP($b) $a] >= 0} {
                # normalizza la coppia per non duplicarla
                if {[string compare $a $b] < 0} {
                    set pair "$a <-> $b"
                } else {
                    set pair "$b <-> $a"
                }

                if {[lsearch -exact $bidir_fail_pairs $pair] < 0} {
                    lappend bidir_fail_pairs $pair
                }
                if {[lsearch -exact $bidir_fail_pins $a] < 0} {
                    lappend bidir_fail_pins $a
                }
                if {[lsearch -exact $bidir_fail_pins $b] < 0} {
                    lappend bidir_fail_pins $b
                }
            }
        }
    }

    if {[llength $bidir_fail_pairs] == 0} {
        puts "SHORT_NETS: x"
    } else {
        puts [::c_orange "SHORT_NETS:"]
        foreach pair [lsort -unique $bidir_fail_pairs] {
            puts "  $pair"
        }
    }
    # ------------------------------------------------------------
    # FAIL DRIVE report
    # ------------------------------------------------------------
    set fail_drive_list [lsort -unique $fail_drive_list]

    if {[llength $fail_drive_list] == 0} {
        puts "FAIL_DRIVE = x"
    } else {
        puts [::c_orange "FAIL_DRIVE:"]
        puts "  [join $fail_drive_list {, }]"
    }

}

proc jedec_mfr_name_from_11bit {m11} {
    # m11: 11-bit JEDEC manufacturer identity from IDCODE (0..2047)
    if {![string is integer -strict $m11] || $m11 < 0 || $m11 > 2047} {
        return "Unknown"
    }

    # JEP106 packing used by IEEE 1149.1 IDCODE:
    # upper 4 bits = continuation/bank-1, lower 7 bits = manufacturer code
    set bank [expr {($m11 >> 7) + 1}]
    set dec  [expr {$m11 & 0x7F}]

    # table key format used in your generated/copied table: "bank,dec"
    set key "$bank,$dec"

    if {[info exists ::JEDEC_MFR($key)]} {
        return $::JEDEC_MFR($key)
    }
    return "Unknown"
}


# Auto-generated from Jedec-Standard_JEP106AV.pdf. 
# This is a copyrighted file, so the array has been truncated.
# Keys: bank,dec -> manufacturer name; also bank,hexbyte.
array set ::JEDEC_MFR {
  "1,1" "AMD"
  
}

array set ::JEDEC_MFR_HEX {
  "1,0x01" "AMD"
  }
