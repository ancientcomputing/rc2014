# /bin/sh
asmx -l -b f000h-ffffh -e -C 6502 sbc.asm
ls -la *.bin
cat ../ehbasic/basic.asm.bin sbc.asm.bin > monbas6502.rom
ls -lat mon*.rom
