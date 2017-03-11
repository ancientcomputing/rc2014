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
<p>
Monitor commands are:<br>
?              Print this help<br>
D XXXX         Dump memory from XXXX<br>
E XXXX         Edit memory starting at XXXX<br>
G XXXX         Go execute from XXXX<br>
I XX           Input from I/O<br>
O XX YY        Output to I/O<br>
V              Version<br>
W XXXX         Set workspace XXXX<br>
:sHLtD...C     UPLOAD Intel HEX file, ':' is part of file<p>
Some Intel HEX files do not correctly set the memory address: the first address is set to 0000H instead of the ORG value in your source. If that is the case, use the W command to set the RAM address where you want to load your code from the HEX file. Then upload the file.
<p>
Uploading an Intel HEX file is implicit. You can open up the file in a text edit, select the contents of the file to copy, then paste it in your terminal console window. The leading ":" of the HEX file is correctly interpreted and the monitor will start handling the rest of the hex data.
<p>
If you are using Serial on the Mac, you can use the "Send Text File" option to upload an Intel HEX file.

