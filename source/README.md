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
mon32K.asm - Monitor/Debugger for the RC2014.
<p>Adapted from the monitor program for Lee Hart's Z80 Membership Card. Written by Josh Bensadon. 
<p>
Hacked in a big way to remove all LED/matrix keyboard code. 
It now uses RST calls for console input/output via the BIOS code in int32K.asm. 
Disabled a bunch of other serial console commands as well. 
<p>
Monitor commands are:<br>
?              Print this help<br>
C              Continue from Breakpoint<br>
D XXXX         Dump memory from XXXX<br>
E XXXX         Edit memory from XXXX<br>
G XXXX         Go execute from XXXX<br>
I XX           Input from port XX<br>
O XX YY        Output YY to port XX<br>
R              Display registers from Breakpoint<br>
V              Version<br>
W XXXX         Set HEX file start address to XXXX<br>
:sHLtD...C     UPLOAD Intel HEX file, ':' is part of file
<p>
Some Intel HEX files do not correctly set the memory address: the first address is set to 0000H instead of the ORG value in the source code. If that is the case, use the W command to set the RAM address where you want to load your code from the HEX file. Then upload the file.
<p>
Uploading an Intel HEX file is implicit. You can open up the file in a text edit, select the contents of the file to copy, then paste it in your terminal console window. The leading ":" of the HEX file is correctly interpreted and the monitor will start handling the rest of the hex data.
<p>
If you are using Serial on the Mac, you can use the "Send Text File" option to upload an Intel HEX file.
<p>
The Breakpoint feature here is new. You basically instead a "RST 30H" instruction in the part of your code where you want to pause the program and examine registers.
<p>
When the Breakpoint is hit, the registers values will be shown. Press C to continue execution or ESC to return to the Monitor. When you are back in the Monitor, you can hit C to continue with your program, or R to see the register values at the Breakpoint.
<p>
If you are running a complex program and want to use the Breakpoint feature, please use your own stack i.e. set up the SP at the start of your program. The Breakpoint handler will restore SP to the Monitor stack.

