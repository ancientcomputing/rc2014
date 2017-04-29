<b>Eagle files for RC2014 add-on boards</b>
<p>
16550 board (TESTED): simple board for 16550, 16C550 and similar UART devices. Can be used with 1.8432MHz or 7.3728MHz oscillators. Note that pin 1 (GND) of the FTDI connector is on the left (looking at the board with the bus connector at the bottom).
<p>
The port address starts at 80H. A new BIOS will be made available for this.
<p>
z80_board (TESTED): this is an opinionated implementation of a CPU module for the RC2014. It is designed for the v1.0 bus but may work for the Pro/v2 bus. The opinionated parts of the design is a bona fide reset circuit (the firmware should start up on power up), and the use of a crystal oscillator.
<p>
The crystal oscillator can be connected to the RC2014 bus or not. The decoupling of the Z80's clock from the bus clock means that you are no longer bounded by the requirements of the UART baudrate. You will be able to run the Z80 at 20MHz (assuming you have the 20MHz part and that the bus doesn't impact the high frequency signals too much).
<p>
8085_board: use another CPU with the RC2014. The 8085 is the step-sibling of the Z80. This implementation exposes the SID/SOD lines to an FTDI header so that you can run with a serial terminal without the use of a UART card. A 6.144MHz crystal is recommended for compatibility with the Tiny Basic found <a href="https://github.com/ancientcomputing/8080_8085/tree/master/Tiny_Basic">here</a>.
<p>
<b>IMPORTANT</b>: These designs unless described otherwise are at the prototype stage as of now. I have put in the initial board orders at OSH Park and have not tested any of the designs. If you do find errors, please flag them!
<p>
kicadis are encouraged to convert the files to kicad format with the sole requirement that the converted files are made freely available aka "open source"...
<p>
Copyright Ben Chong and freely licensed back to the community.
