16550 UART Board Rev B
<p>
This is the Rev B version of the 16550 UART Board for the RC2014.
<p>
The top 3 changes are:
<br>- Use of port addresses C0H-FFH to avoid collision with the default 68B50 UART
<br>- Use of 74HCT03 open collector gates, particularly to drive the /INT signal line so that it can be shared with other devices that also drive the interrupt line.
<br>- Availability of the 16550's OP1 and OP2 lines to a pin header for general use e.g. to generate an audio signal or page switch RAM/ROM etc.
<p>
This design has been tested with a PC16550CN.
<p>
PCBs are available from OSH Park at:
<p>
<a href="https://www.oshpark.com/shared_projects/zJddwYAf"><img src="https://www.oshpark.com/assets/badge-5b7ec47045b78aef6eb9d83b3bac6b1920de805e9a0c227658eac6e19a045b9c.png" alt="Order from OSH Park"></img></a>

<p>
A BIOS will be available soon.
 
