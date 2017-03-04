# rc2014
I have a couple of Spencer Owen's RC2014 Z80-based projects.
<p>
Since I'm a modder at heart, I've gone ahead and modified some of the Z80 software.
This repo holds my changes.
<p>
The originals are at searle.hostei.com/grant
<p>
The primary changes are to use a RAM-based interrupt vector table for all RST xx calls and hardware interrupts. Secondary changes are adaptation for use with the ZASM cross-assembler.
<p>
This gives us more flexibility in swapping in alternative serial IRQ handlers, and console I/O for BASIC. 
