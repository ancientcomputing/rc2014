<b>Building Monitor/Debugger+EhBASIC ROM</b>
<p>
The shell scripts here are used to build the combo Monitor/Debugger and EhBASIC ROM image.
<p>
The assembler used here is asmx which can be found here: <a href="http://xi6.com/projects/asmx/">http://xi6.com/projects/asmx/</a>.
<p>
<b>buildit.sh</b> should be used in the same folder as the EhBASIC source code. It builds a binary for code in addresses $8000 to $f000. The actual EhBASIC code starts from $c100 (remember that I/O is from $c000 to $c0ff).
<p>
<b>buildrom.sh</b> should be used in the same folder as the monitor source code. It builds the monitor for code in addresses $f000 to $ffff. After that, it concatentes the EhBASIC binary with the monitor binary to produce a 32KB ROM image.

