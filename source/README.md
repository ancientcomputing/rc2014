Source
<p>
These are the source files.
<p>
int32K.asm - original code by Grant Searle. Modified to use jump tables instead of hardcoding RST and interrupt vectors. Other optimizations and adaptation for the zasm cross-assembler.
<p>
bas32K.asm - original NASCOM BASIC. Modified by Grant Searle. Modified to leave space for jump tables at the beginning of the RAM space (8000h). Adapted for the zasm cross-assembler. Used correct RST call for sending a byte over serial.
<p>
mon32K.asm - Originally the monitor program for Lee Hart's Z80 Membership Card. Written by Josh Bensadon. 
Majorly hacked to remove all LED/matrix keyboard code. Disabled a bunch of other serial console commands as well. 
Works okay for dumping memory, modifying memory and jumping to execute from a given memory address. Intel HEX file upload feature doesn't work quite right yet.
