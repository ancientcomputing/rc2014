<b>6502 CPU Board for the RC2014</b>
<p>
These are the EAGLE files for the RC2014 6502 CPU Board.
<p>
Connect JP1 if you aren't using the Western Design Center 65C02 chip. This is the VPB output on the WDC chip, but on other 65(C)02 chips this has to be connected to GND.
<p>The A15 line selects the inverted A15 signal from the 6502. This allows you to use the standard RC2014 memory and I/O boards by inverting the 2 halves of the memory space: ROM sits at top of memory and RAM at the bottom of memory.
<p>
The I/O space is decoded by the 74HCT688 and is mapped as a 256-byte block to the start of 0C000H. You will map the Z80 I/O addresses to the 6502 I/O space by adding 0C000H.
<p>
Compatibility:
<br>TBD
<p>
You can have boards made at OSH Park at the following link:
<p>
<a href="https://www.oshpark.com/shared_projects/rd7Y9iEE"><img src="https://www.oshpark.com/assets/badge-5b7ec47045b78aef6eb9d83b3bac6b1920de805e9a0c227658eac6e19a045b9c.png" alt="Order from OSH Park"></img></a>
<p>
Otherwise, you can order the RevB boards on <a href="https://www.tindie.com/products/9916/">Tindie</a>.
