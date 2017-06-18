# /bin/sh
asmx -l -b 8000h-f000h -e -C 6502 basic.asm
ls -la *.bin
