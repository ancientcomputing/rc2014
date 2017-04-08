# RC2014
I have a couple of Spencer Owen's RC2014 Z80-based projects (see http://rc2014.co.uk).
<p>
Since I'm a modder at heart, I've gone ahead and modified some of the Z80 software.
This repo holds my changes.
<p>
The original code is at searle.hostei.com/grant
<p>
New changes for version 0.7.0 include support for a 255-byte receive buffer. This removes the need for character line delays in many cases when uploading programs and files.
<p>
The primary RC2014 Github repo is at: https://github.com/RC2014Z80/RC2014
<p>
<b>Serial Monitor/Debugger for the RC2014</b>
<p>
I have adapted to the RC2014, the original monitor program for Lee Hart's Z80 Membership Card. Check out the source code in the "source" folder and a ready-to-burn ROM image "mon.rom" under the "rom" folder. All original authorship rights are acknowledged in the source code.
<p>
The RC2014 monitor is a mostly full-function monitor that allows you to view and modify RAM contents, read/write I/O ports, upload Intel HEX files, execute programs, insert breakpoints (via the RST 30h instruction) and examine registers post breakpoint.
<p>
<hr>
<p>
Check out the documentation in the docs folder.
<p>
<hr>
<p>
Blog: http://ancientcomputing.blogspot.com

