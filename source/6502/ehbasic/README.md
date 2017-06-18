<b>Enhanced BASIC</b>
<p>
This is a tweaked version of Lee Davison's Enhanced BASIC for the 6502 that has been adapted for the RC2014.
<p>
This version is meant to be used with the 6502 BIOS and Monitor/Debugger <a href="https://github.com/ancientcomputing/rc2014/tree/master/source/6502/monitor">here</a> and uses the BIOS serial I/O APIs as defined in the reset.asm file.
<p>
The code is still work-in-progress.
<p>
This work is derived from v2.22 of the EhBASIC that is hosted <a href="https://github.com/Klaus2m5/6502_EhBASIC_V2.22">here</a> by Klaus2m5.
<p>
Please note that EhBASIC is not meant for commercial (re)distribution. 
<p>
Key differences with the default version of EhBASIC are:
<br>
- SYS keyword to exit back to the Monitor/Debugger
<br>
- Cold start entry point at $c100
<br>
- Warm start entry point at $c103
<br>
- Hopefully clearer comments in the code if you need to change addresses around...

