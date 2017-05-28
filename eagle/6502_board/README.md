<b>6502 CPU Board for the RC2014</b>
<p>
These are the EAGLE files for the RC2014 6502 CPU Board.
<p>
Connect JP1 if you are using the Western Design Center 65C02 chip. This is the the VPB line.
<p>The A15 line selects the inverted A15 signal from the 6502. This allows you to use the standard RC2014 memory and I/O boards by inverting the 2 halves of the memory space.
<p>
The I/O space is decoded by the 74HCT688 and is mapped as a 256-byte block to the start of 0C000H.
<p>
Compatibility:
<br>TBD
