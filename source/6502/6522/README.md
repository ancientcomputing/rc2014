Test code for the RC2014 6522 board.

1. Run ./testit.sh to assemble using asmx
2. Load test.asm.hex via the monitor program (command U)
3. Run the test program at $2100 (G 2100)

This will play the chromatic scale repeatedly. Press any key to stop. 

The test routine will then play "Do Re Mi" and return to the monitor program.

A second test routine is available at $2100.

