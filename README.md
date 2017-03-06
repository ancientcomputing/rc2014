# RC2014
I have a couple of Spencer Owen's RC2014 Z80-based projects (see http://rc2014.co.uk).
<p>
Since I'm a modder at heart, I've gone ahead and modified some of the Z80 software.
This repo holds my changes.
<p>
The original code is at searle.hostei.com/grant
<p>
The primary changes are to use a RAM-based interrupt vector table for all RST xx calls and hardware interrupts.
<p>
This gives us more flexibility in swapping in alternative serial IRQ handlers, and console I/O for BASIC.
<p>
Some minor changes were made so that the ZASM cross-assembler worked.
<p>
The primary RC2014 Github repo is at: https://github.com/RC2014Z80/RC2014
