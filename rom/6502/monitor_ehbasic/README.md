<b>Monitor + EhBASIC ROM</b>
<p>
This is the ROM image that combines the Monitor/Debugger and EhBASIC. This is a 32KB image and can be used to program a 27256 or 28C256. 
<p>
This image is intended for use with the 16550 UART board.
<p>
If your ROM address space is only 16KB, you will need to extract the top 16KB of the image to program your device.
<p>
BASIC can be launched by (G)oing to location $c100 from the Monitor. This is the cold start address.
<p>
The BASIC warm start address is at $c103. 
<p>
To return to the Monitor, enter the SYS command.
<p>

