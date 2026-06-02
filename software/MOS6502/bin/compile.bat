ca65.exe apu.asm
ld65.exe apu.o -t nes -o apu.bin 
bin2mif.exe 8 apu.bin
@pause