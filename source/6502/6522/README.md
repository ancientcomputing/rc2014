Test code for the RC2014 6522 board

This uses Timer 1 to generate audio by toggling PB7(pin 17) of the 6522.

PB7 is routed to a simple darlington circuit to drive a speaker. A possible circuit is one that is used in the Apple II (reproduced here for reference only).

1. Run ./testit.sh to assemble using asmx
2. Load test.asm.hex via the monitor program (command U)
3. Run the test program at $2100 (G 2100)

This will play the chromatic scale repeatedly. Press any key to stop. 

The test routine will then play "Do Re Mi" and return to the monitor program.

A second test routine is available at $2100.

