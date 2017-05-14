<b>Real Retro UART Board</b>
<p>
Designed for RC2014.
<p>
Takes ancient UART devices like the 6402, AY-3-1015 and other similar UARTs from the 1970s and early 1980s.
<p>
No programming needed to set up the UART. Everything is in hardware and hardwired for 8 bits, 1 stop, 1 start and no parity. A 74LS92 counter divides the 1.8432MHz oscillator output to give a blistering 9600 baudrate.
<p>
Port addresses hardwired to 40h-5Fh. Actual addresses used are 40h which is the transmit and receive buffers (write and read respectively), and 41h which is the UART status: Bit 0 is high when a received byte is available and Bit 1 is high when the transmitter is empty and ready to take in a new byte for transmission.
<p>
Tested using the new 8085 Monitor and manually running the I/O routines to send an receive characters. A new 8085 Monitor will be available to take advantage of this board.
<p>
As usual the board is available for order from OSH Park:
<p>
<a href="https://www.oshpark.com/shared_projects/QPsbgDI0"><img src="https://www.oshpark.com/assets/badge-5b7ec47045b78aef6eb9d83b3bac6b1920de805e9a0c227658eac6e19a045b9c.png" alt="Order from OSH Park"></img></a>
<p>
Viva Real Retro!!
