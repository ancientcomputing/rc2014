<b>6502 Monitor/Debugger for the RC2014</b>
<p>
This is a simple 6502 Monitor/Debugger for the RC2014 6502 CPU Board.
<p>
This is derived from Daryl Rictor's monitor program (5.1.1 Lite), but heavily modified to provide a similar user interface as the RC2014 Z80 Monitor/Debugger.
<p>
The rights of Daryl and Ross Archer (who wrote the Intel HEX uploader) are respected. Daryl's website is at: <a href="http://sbc.rictor.org/">http://sbc.rictor.org/</a>. A webpage with Ross' original code is <a href="http://6502.org/source/monitors/intelhex/intelhex.htm">here</a>.
<p>
Changes to the original code are copyright Ben Chong and freely licensed to the community.
<p>
A user guide will "soon" be available...
In the meantime, typing '?' will show a list of commands.
<p>
The implementation of the Monitor/Debugger uses a BIOS approach to abstract the serial console code. The files 16C550.asm, 6850.asm and rruart.asm are the source files that are specific to each type of supported UART. The file sbc.asm allows you to select the UART.
<p>
Please check <a href="http://ancientcomputing.blogspot.com/2017/06/a-6502-cpu-for-rc2014-part-2b.html">this</a> blog article to see how you can get the RC2014 serial I/O card to work with the 6502 CPU.
<p>
The reset.asm file lists the APIs that can be called from other programs: input_char, check_input and output_char are serial console functions. You can invoke them usin the "jsr" command. The monitor entry point is at $ff00.
<p>
If you want to implement your own interrupt handling routines, check out irq_vector and nmi_vector in the sbcmon.asm source file. Be aware that with the IRQ handler, the X and A registers are already pushed onto the stack (check this out in reset.asm).
