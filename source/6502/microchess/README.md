<b>Peter Jennings' MicroChess</b>
<p>
This is Peter Jennings well-known MicroChess for the 6502.
<p>
This version is adapted from Daryl Rictor's port at <a href="http://6502.org/source/games/uchess/uchess.htm">http://6502.org/source/games/uchess/uchess.htm</a>.
<p>
Peter Jennings' website is at <a href="http://www.benlo.com/microchess/index.html">http://www.benlo.com/microchess/index.html</a>.
<p>
Source code is reproduced with permission from Peter Jennings.
<p>
To use this, upload (using the 'U' Monitor command) the chess.asm.hex file. Then use the 'G' Monitor command to launch the program at address $1000.
<p>
You should see an ASCII rendition of the chess board. Press 'C' to restart the game.
<p>
Enter your move in the following way:
<p>
[XY] [AB]<br>
where XY is the 2 digit coords of the piece you want to move and AB is the 2 digit coords of where you want the piece to go.
<p>
Then hit <ENTER>
<p>
To get the computer to make its move, press 'P'.
<p>
<hr>
<p>
In today's world, this user interface may seem archaic, but remember that the original code was written for the KIM-1 that only had a 6-digit 7-segment display.
<p>
One of my goals is to make the user interface a little friendlier and more intuitive. I may use the ANSI terminal commands create a static screen instead of having the program dump a new chess board everytime you press a key.
