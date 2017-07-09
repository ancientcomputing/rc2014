<b>BIOS source code for 16550 UART RevB Board</b>
<p>
Small change to uart_base for port address c0h.
<p>
Added CPU8080 assemble-time conditional for the 8085 CPU Board.
<p>
Added POLLED assemble-time conditional to enable polled mode UART instead of using interrupts.
<p>
To assemble for the 8085 CPU Board, change the #define for CPU8080 to 1.
<p>
To assemble for the Z80 CPU, change the #define for CPU8080 to 0. Of course, a binary for the 8080 will run on the Z80 CPU :)
<p>
