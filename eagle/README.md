<b>Eagle files for RC2014 add-on boards</b>
<p>
<b>16550 board (TESTED)</b>: Simple board for 16550, 16C550 and similar UART devices. Can be used with 1.8432MHz or 7.3728MHz oscillators. Note that pin 1 (GND) of the FTDI connector is on the left (looking at the board with the bus connector at the bottom).
<p>
The port address starts at 80H. A new BIOS is available. See source/16x550. Binaries are at rom/16x550.
<p>
There is no option to power the system from the FTDI header.
<p>
<b>16550 board Rev B (TESTED)</b>: A variant of the 16550 board implementation. Using 74HCT03 open collector gates, particularly to drive the /INT line. This means that other peripherals can also drive the /INT line. 
<p>
The port address starts at C0H. A new BIOS will be made available for this. For the impatient, just change the uart_base value to 0c0h from 80h.
<p>
<b>z80_board (TESTED)</b>: This is an opinionated implementation of a CPU module for the RC2014. It is designed for the v1.0 bus but may work for the Pro/v2 bus. The opinionated parts of the design is a bona fide reset circuit (the firmware should start up on power up), and the use of a crystal oscillator.
<p>
The crystal oscillator can be connected to the RC2014 bus or not. The decoupling of the Z80's clock from the bus clock means that you are no longer bounded by the requirements of the UART baudrate. You will be able to run the Z80 at 20MHz (assuming you have the 20MHz part and that the bus doesn't impact the high frequency signals too much).
<p>
This Z80 board is compatible with other RC2014 modules. If you plan to use this with the 68B50 ACIA module, you will have to use a 7.3728MHz oscillator and short the CLOCK jumper.
<p>
<b>8085_board (TESTED)</b>: Use another CPU with the RC2014! The 8085 is the step-sibling of the Z80. This implementation exposes the SID/SOD lines to an FTDI header so that you can run with a serial terminal without the use of a UART card. A 6.144MHz crystal is recommended for compatibility with the Tiny Basic found <a href="https://github.com/ancientcomputing/8080_8085/tree/master/Tiny_Basic">here</a>.
<p>
A Monitor can also be found in the <a href="https://github.com/ancientcomputing/rc2014/tree/master/rom/8085rom/">8085 folder</a>.
<p>
<b>Real Retro 3KB RAM board aka rr3kram (TESTED)</b>: Remember when 3KB was a lot of memory? The Real Retro 3KB RAM board tries to relive that experience. It uses 3 pairs of 2114 RAM chips to deliver a massive 3KB of memory.
<p>
With 200ns devices, it will even work with the Z80 CPU+ board equiped with a blistering fast 14MHz Z80.
<p>
The original board design had disconnected A0, A1 lines which have now been fixed.   
<p>
<b>Real Retro UART board (TESTED)</b>
<p>
A basic UART board using ancient UART devices like the 6402, AY-3-1015 or similar.
<p>
<b>Simple ROM/RAM board (TESTED)</b>
<p>
A simple board providing 32KB of RAM and 32KB of ROM. Usable with EPROM or EEPROM. Switchable to allow ROM at the top of memory or at the bottom of memory. This provides for compatibility with 6502 or 680x CPU boards.
<p>
<b>6502 CPU Board (TESTED)</b>
<p>
Run the 6502 microprocessor on the RC2014!
<p>
The 6502, along with the Z80, powered much of the home computer industry in the late 1970s and 1980s.
<p>
My blog <a href="https://ancientcomputing.blogspot.com">ancientcomputing.blogspot.com</a> has a number of articles that cover how the 6502 bus was made to work on the RC2014 bus and which RC2014 boards can work (with or without minor modifications) with the 6502 CPU board.
<p>
<b>6502 CPU Board RevB (TESTED)</b>
<p>
The RevB version of the 6502 CPU board gives you the option of inverting the A14 address line as well. You can use it with the RC2014 64KB RAM card to build a system with 48KB of usable RAM.
<hr>
<p>
<b>IMPORTANT</b>: These designs unless described otherwise are at the prototype stage as of now. I have put in the initial board orders at OSH Park and have not tested any of the designs. If you do find errors, please flag them!
<p>
kicadis are encouraged to convert the files to kicad format with the sole requirement that the converted files are made freely available aka "open source"...
<p>
Copyright Ben Chong and freely licensed back to the community.
