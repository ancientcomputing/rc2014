bios32K_sio.asm - BIOS source file to enable support for SMBaker's Z80 SIO card. You will be able to run the Monitor/Debugger and BASIC from the SIO card instead of the 68B50 ACIA.
<p>
This replaces the int32K.asm BIOS source file.
<p>
To build, assemble this file to its binary, then rename it to int32K.rom. Then run romit3.sh or romit2.sh from the /tools folder.
<p>
For ready-built images, check out the /rom/sio folder.
<p>
SIO card configuration:
<br>
- Address 20H. To change, edit sio_base in the source file
<br>- Serial port A
<br>- IE tied to Vcc
<br>- 1.8432MHz oscillator for a baudrate of 115200
<p>
Note that interrupts are enabled and used.
<p>
Many thanks to Mario Blunk for his excellent tutorial on how to tame the Z80 SIO: How To Program the Z80 Periphery Tutorial

