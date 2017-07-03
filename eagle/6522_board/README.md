<b>6522 VIA Board for the RC2014</b>
<p>
These are the Eagle files for the 6522 VIA Board for the RC2014.
<p>
The board is designed to work with the 6502 CPU Board.
<p>
If you have the initial revision (revA) of the 6502 CPU board, be sure to link a wire from the R/W signal of the 6502 to pin 39 of the RC2014 bus connector. The 6522 takes the R/W signal from that pin. RevB of the 6502 CPU board does not need that change but you want to make sure that the R/W jumper is closed.
<p>
Be sure to use a 6522 that is speed matched to the 6502 CPU.
<p>
Check out some test code <a href="https://github.com/ancientcomputing/rc2014/tree/master/source/6502/6522">here</a>.
