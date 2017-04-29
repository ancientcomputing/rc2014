bios32K_16x550.asm - BIOS source for 16x550 UART card for the RC2014. You can use the 16550/16C550 series of UARTs on this card. It replaces the default 68B50 ACIA that comes with the RC2014.
<p>
This file replaces the int32K.asm BIOS source file.
<p>
To build, assemble this file to its binary, then rename it to int32K.rom. Then run romit3.sh or romit2.sh from the /tools folder.
<p>
For ready-built images, check out the /rom/16x550 folder.
<p>
Assumptions: <br>
- 115200 baudrate with 1.8432MHz oscillator
<br>- Port address 80H
<p>
