Real Retro 3KB RAM board for RC2014
<p>
Uses 2114 static RAM chips. Each chip has 1KBx4 of memory. You will need at least 2 chips for 1KB of RAM.
<p>
Starting address is 8000H. Not fully decoded as A13 is not connected. I decided to save on an OR gate.
<p>
Device pairing:<br>
IC1 & IC4<br>
IC2 & IC5<br>
IC3 & IC6<br>
<p>
Jumpers:<br>
Populate all JP1 for address starting at 8000H<br>
Populate all JP2 for address starting at 9000H
<p>
200ns RAM chips work with a Z80 CPU running at 14MHz. 450ns RAM chips may not work with a 7MHz Z80 CPU.
<p>
This version fixes the missing A0 and A1 lines in the original release.
<p>
Copyright Ben Chong and licensed freely back to the community.
