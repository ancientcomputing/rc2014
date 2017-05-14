<b>Monitor for the 8085 CPU Board for RC2014</b>
<p>
This is a simple machine language monitor for the 8085 CPU Board for the RC2014 system.
<p>
It is based on the Monitor/Debugger for the Z80 CPU.
<p>
Source code for the monitor is found in 2 files:
<br>- rc2014/source/mon32K.asm
<br>- rc2014/source/16x550_revb/bios_32K_16x550.asm
<p>
To build the binary, you need to change the source files so that #define CPU8080 is 1 instead of 0.
<p>
You then concatenate the 2 resulting *.rom files e.g.<br>
<i>   cat bios32K_16x550.rom mon32K.rom > mon8080.rom</i> 
<p>
Hardware requirements:
<br>- 8085 CPU Board
<br>- 16550 UART Board (both original and RevB versions)
<br>- RC2014 Switcheable ROM Board
<p>
Note that the RC2014 Pageable ROM board does not work because of the paging circuitry. To get the Pageable ROM board to work, you will need to remove the 74HCT138 and 74HC393 chips, then solder a link from pin 3 of the 74HC393 chip to ground.
<p>
NEW: Added support to read from an input port or write to an output port.
