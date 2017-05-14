<b>ROMs for the RC2014</b>
<p>
rom.rom - BASIC ROM using a modified bas32K.asm and int32K.asm
<p>
mon.rom - Monitor/Debugger for the RC2014. This can replace the original BASIC ROM that comes with the RC2014. 
<p>
monbas.rom - Monitor/Debugger and BASIC in one ROM. This takes up 16KB of ROM space, from 0000h to 3FFFh. You will need to either tweak the standard RC2014 or use the paged ROM board set up appropriately.
<p>
You will boot into the Monitor/Debugger. To go to BASIC, use the G command in the Monitor: G 1000 to cold start BASIC, or G1003 to warm start BASIC.
<p>
To get back to the Monitor, use the "monitor" keyword in BASIC.
<p>
mon8080.rom - Monitor for the 8085 CPU Board
<p>
