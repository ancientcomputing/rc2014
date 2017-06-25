<b>16550 UART Board for RC2014</b>
<p>
This is RevC of the 16550 UART Board, designed for RC2014 systems.
<p>
Unlike earlier versions, this board takes the PLCC version of the 16550. I have successfully tested it with a TL16C550CFN from Mouser (part: 595-TL16C550CFN).
<p>
Also, as you can see from the Mouser part number, PLCC versions of the 16C550 are still commercially available. The DIP/DIL-40 versions are no longer so.
<p>
The use of a 16C550 in a 6502 system is important (vs the 16550 version) because the 6502 BIOS enables autoflow control. This provides a means of throttling the byte stream from your PC when you are uploading an Intel Hex file.
<p>
The other major change is the use of a 74HCT138 to give you more addressing options. This allows you to use more than one board in a system: you just need to make sure that each board uses a different port address. Of course, the software needs to be appropriately modified to access port addresses other than C0H which is the default one.
<p>
Finally, the PLCC socket is a standard part and can be ordered from Mouser (part: 806-PX-44LCC) or Jameco.
