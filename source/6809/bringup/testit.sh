# /bin/sh
asmx -l -b 8000h-ffffh -e -C 6809 test.asm
ls -la *.bin
