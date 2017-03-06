Source
<p>
These are the source files.
<p>
int32K.asm - Original code by Grant Searle. This is the BIOS code for the RC2014. 
Modified to use jump tables instead of hardcoding RST and interrupt vectors. 
Other optimizations and adaptation for the zasm cross-assembler.
<p>
bas32K.asm - Original NASCOM BASIC. Modified by Grant Searle. Modified to leave space for jump tables at the beginning of the RAM space (8000h). Adapted for the zasm cross-assembler. Used correct RST call for sending a byte over serial.
<p>
mon32K.asm - Originally the monitor program for Lee Hart's Z80 Membership Card. Written by Josh Bensadon. 
Adapted to the RC2014. Hacked in a big way to remove all LED/matrix keyboard code. 
It now uses RST calls for console input/output via the BIOS code in int32K.asm. 
Disabled a bunch of other serial console commands as well. 
Works okay for dumping memory, modifying memory and jumping to execute from a given memory address. 
Intel HEX file upload feature doesn't work quite right yet aka it's work in progress.
