<b>Simple ROM/RAM Board for RC2014</b>
<p>
This is a simple ROM+RAM board that full outfit an RC2014 system with memory.
<p>
Instead of ROM and RAM on separate boards, I wanted to combine them in order to reduce the number of boards needed to put together a basic system. 
<p>
The design is also very basic. Rather than trying to boil the ocean, I elected to assume the basic 32KB-32KB ROM-RAM split that is very common today among SBC designs.
<p>
The only "fancy" features are:
<br>1. Ability to select between 27256 EPROM and 28C256 EEPROM devices.
<br>2. The ability to put RAM at the top of memory à la Z80/8080 or RAM at the bottom of memory à la 6502/680x. Conversely, ROM will be at the bottom or top of memory respectively.
<p>
Fellow modders can make use of the board as a switchable ROM/RAM board by swapping in a "PAGE" signal to the A15 input of the 74HCT139.
<p>
Boards can be ordered from OSH Park at the following link:
<p>
<a href="https://www.oshpark.com/shared_projects/Yfu9JolG"><img src="https://www.oshpark.com/assets/badge-5b7ec47045b78aef6eb9d83b3bac6b1920de805e9a0c227658eac6e19a045b9c.png" alt="Order from OSH Park"></img></a>
<p>

