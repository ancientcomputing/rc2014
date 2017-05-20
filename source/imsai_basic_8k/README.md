<b>Adaptation of the IMSAI 8K BASIC for RC2014</b>
<p>
The problem with the version of BASIC that ships with the RC2014 is that it was written for the Z80. So it will not work with the 8085 CPU Board.
<p>
On the other hand, the IMSAI 8K BASIC was written for the original 8080-based IMSAI computers and are therefore fully code-compatible with the 8085.
<p>
This is a very basic adaptation of the original IMSAI 8K BASIC source code to work with the RC2014. In particular, changes were made to use the RC2014 BIOS for input/output functions. Also, the original code assumed that BASIC had access to all the RST locations which is doesn't work for the RC2014.
<p>
The source code here assumes that the BASIC binary is loaded into RAM at 9000H.
<p>
You can assemble the source with the following zasm command:
<br>zasm --asm8080 -u -x basic8k.asm 
<p>
This will generate an Intel HEX file which you can load into RAM.
<p>
Note: There are at least a couple of versions of this BASIC floating around. I started off with the KJL version and added in the couple of fixes that Udo Munk made.
