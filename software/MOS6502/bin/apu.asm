;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; APU code.
.segment "ZEROPAGE"
indx_lo:.byte $00
indx_hi:.byte $00

.segment "DATA"
waddr0:	.byte $00		;переменные для записи 
waddr1:	.byte $00		;адреса в регистры
waddr2:	.byte $00		;out1, out2, out3
ctrl:	.byte $00		;регистр управления out0
prom:	.byte $00		;количество блоков 16K program ROM
vrom:	.byte $00		;количество блоков 8K video ROM
ctrl1:	.byte $00		;байт управления маппером 1
ctrl2:	.byte $00		;байт управления маппером 2
mapper:	.byte $00		;тип маппера
raddr0:	.byte $00		;максимальный адрес 
raddr1:	.byte $00		;файла (количество
raddr2:	.byte $00		;прочитанных байт)
game:	.byte $00		;номер игры	
gamed:	.byte $00		;номер игры в двоично-десятичном формате
strta0:	.byte $00		;стартовый адрес игры
strta1:	.byte $00
strta2:	.byte $00
nexta0:	.byte $00		;адрес следующей игры
nexta1:	.byte $00
nexta2:	.byte $00
mins:	.byte $00		;переменные таймера
secs:	.byte $00

.segment "VRAM"			;8K буфер VRAM (отображается на 
vram:	.res 8192		;VRAM приставки)

.segment "IO"			;регистры ввода-вывода
;только запись
dig1:   .res 1			;самый левый разряд
dig2:   .res 1
dig3:   .res 1
dig4:   .res 1			;светодиодный
dig5:   .res 1			;индикатор
dig6:   .res 1
dig7:   .res 1
dig8:   .res 1			;самый правый разряд
out0:   .res 1			;регистр управления
out1:   .res 1			;регистр адреса (мл.)
out2:   .res 1			;регистр адреса (ср.)
out3:   .res 1			;регистр адреса (ст.)
;только чтение
in0:   .res 1			;состояние SD reader
in1:   .res 1			;регистр состояния
in2:   .res 1			;регистр чтения адреса
in3:   .res 1			;регистр чтения данных

.segment "CODE"
.proc irq_handler

    PHA         		; сохранить A
    TXA
    PHA         		; сохранить X

	LDA mins	
	BEQ nmi10
	JMP nmi20

nmi10:
	LDA secs	
	BEQ nmi11
	JMP nmi20

nmi11:
	LDA #$A1		;вывод заставки dendy
	STA dig1
	STA dig4
	LDA #$86
	STA dig2
	LDA #$AB
	STA dig3
	LDA #$8D
	STA dig5
	LDA #$FF
	STA dig6
	
	LDA ctrl		;блокировка кнопок
	ORA #$02
	STA ctrl
	STA out0
	
	JMP nmi30
	
nmi20:
	LDA mins
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig1

	LDA mins
	AND #$0F
	TAX
	LDA codegen, X
	STA dig2
	
	LDA #$BF
	STA dig3

	LDA secs
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig4

	LDA secs
	AND #$0F
	TAX
	LDA codegen, X
	STA dig5
	
	DEC secs		;декремент и
	LDA secs		;двоично-десятичная
	AND #$0F		;коррекция
	CMP #$0F
	BEQ nmi21
	
	JMP nmi25
	
nmi21:
	SEC
	LDA secs
	SBC #$06
	STA secs
	
	AND #$F0
	CMP #$F0
	BEQ nmi22
	
	JMP nmi25

nmi22:
	SEC
	LDA secs
	SBC #$A0
	STA secs

	DEC mins		;декремент и
	LDA mins		;двоично-десятичная
	AND #$0F		;коррекция
	CMP #$0F
	BEQ nmi23
	
	JMP nmi25
	
nmi23:
	SEC
	LDA mins
	SBC #$06
	STA mins
		
	AND #$F0
	CMP #$F0
	BEQ nmi24
	
	JMP nmi25
	
nmi24:
	SEC
	LDA mins
	SBC #$60
	STA mins
	
nmi25:
	LDA mins	
	BEQ nmi26
	JMP nmi30

nmi26:
	LDA secs	
	AND #$F0
	BEQ nmi27
	JMP nmi30

nmi27:
	LDA secs	
	AND #$01
	BEQ nmi28
		
	LDA ctrl		;beep on
	ORA #$01
	STA ctrl
	STA out0
	
	JMP nmi30
	
nmi28:
	LDA ctrl		;beep off
	AND #$FE
	STA ctrl
	STA out0
	
nmi30:	
	PLA
    TAX         	;восстановить X
    PLA         	;восстановить A
	
	RTI
.endproc

.proc nmi_handler
	RTI
.endproc

.proc reset_handler
	SEI
	CLD
	JMP main
.endproc

;знакогенератор семисегментного индикатора
codegen:
.byte $C0, $F9, $A4, $B0, $99, $92, $82, $F8, $80, $90, $88, $83, $C6, $A1, $86, $8E
;      0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F 

.proc main
	
	LDA #$00		;обнуляем outreg0
	STA ctrl	
	STA out0
	STA strta0		;обнуляем стартовый адрес
	STA strta1
	STA strta2
	STA nexta0		;обнуляем стартовый адрес
	STA nexta1
	STA nexta2
	
	STA secs		;задаем начальное состояние 
	LDA #$01		;таймера 01:00
	STA mins		
	
	LDA #$01
	STA game
	STA gamed
	
met1:	
	LDA in0			;читаем состояние контроллера SD
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig1		;выводим его в поз. 1 и 2
	
	LDA in0
	AND #$0F
	TAX
	LDA codegen, X
	STA dig2	
	
	LDA #$00		;выбираем для чтения младший байт адреса записи
	STA out0
	
	LDA in2			;читаем младший байт адреса записи
	STA raddr0
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig7		;выводим его в поз. 7 и 8
	
	LDA in2
	AND #$0F
	TAX
	LDA codegen, X
	STA dig8	

	LDA #$40		;выбираем для чтения средний байт адреса записи
	STA out0
	
	LDA in2			;читаем средний байт адреса записи
	STA raddr1
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig5		;выводим его в поз. 5 и 6
	
	LDA in2
	AND #$0F
	TAX
	LDA codegen, X
	STA dig6
	
	LDA #$80		;выбираем для чтения старший байт адреса записи
	STA out0
	
	LDA in2			;читаем старший байт адреса записи
	STA raddr2
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig3		;выводим его в поз. 3 и 4
	
	LDA in2
	AND #$0F
	TAX
	LDA codegen, X
	STA dig4

	LDA in1			;проверяем установку бита окончания чтения SD
	AND #$03
	CMP #$03
	BEQ met2		;если да, то переход на met2, иначе
	
	JMP met1		;переход на met1

;разбираем файл
met2:	
	LDA #$FF		;гасим индикаторы
	STA dig1
	STA dig2	
	STA dig3
	STA dig4
	STA dig5
	STA dig6
	STA dig7
	STA dig8	

new:
	LDA in1
	AND #$C0
	CMP #$C0
	BEQ met41
	
	JMP new

met41:	
	LDA #$00
	STA ctrl
	STA out0
	
	LDA strta0
	STA waddr0
	LDA strta1
	STA waddr1
	LDA strta2
	STA waddr2		
	
;читаем сигнатуру	
	JSR rd_byte		;чтение байта по адресу 0
	CMP #$4E
	BEQ met31	
	
	LDX #$01
	JMP error
	
met31:
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 1
	CMP #$45
	BEQ met32	
		
	LDX #$02
	JMP error
	
met32:
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 2
	CMP #$53
	BEQ met33	
	
	LDX #$03
	JMP error

met33:
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 3
	CMP #$1A
	BEQ met34	
	
	LDX #$04
	JMP error	

met34:
	LDA ctrl		;включаем звуковой сигнал
	ORA #$03		;и светодиод
	STA ctrl
	STA out0
		
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 4
	STA prom		;сохраняем значение в переменной prom
	AND #$0F		;выводим его на дисплей
	TAX
	LDA codegen, X
	STA dig2
	
	LDA prom
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig1		;выводим в поз. 1 и 2
	
	LDA prom		;проверяем на допустимость
	BEQ met36
	SEC
	SBC #$01	
	BEQ met37
	SEC
	SBC #$01	
	BEQ met38
	
	LDX #$05
	JMP error			

met38:
	LDA ctrl		;устанавливаем блокировку 
	ORA #$20		;адреса ADDR[14] для одностраничного
	STA ctrl		;образа

met37:	
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 5
	STA vrom		;сохраняем значение в переменной vrom
	AND #$0F		;выводим его на дисплей
	TAX
	LDA codegen, X
	STA dig4
		
	LDA vrom
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig3		;выводим в поз. 3 и 4
	
	SEC				;проверяем на допустимость
	LDA vrom
	SBC #$01	
	BEQ met35

met36:	
	LDX #$06
	JMP error
	
met35:	
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 6
	STA ctrl1
	AND #$0F		;выводим его на дисплей
	TAX
	LDA codegen, X
	STA dig6
	
	LDA ctrl1
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig5		;выводим в поз. 5 и 6
	
	LDA ctrl1		;устанавливаем бит отражения
	AND #$01
	BEQ met39
	
	LDA ctrl
	ORA #$10
	STA ctrl	
	
met39:	
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 7
	STA ctrl2
	AND #$F0
	STA mapper
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig7		;выводим в поз. 7 и 8
	
	LDA ctrl2
	AND #$0F
	TAX
	LDA codegen, X
	STA dig8	
	
	LDA ctrl1	
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	
	ORA mapper		;сохраняем тип маппера
	STA mapper
	BEQ met48
	
	LDX #$07
	JMP error		;если не 0 то ошибка

;читаем VROM	
met48:
	LDA waddr0		;вычисляем адрес начала
	CLC				;области VROM
	ADC #$09
	STA waddr0
	LDA waddr1
	ADC #$40
	STA waddr1
	LDA waddr2
	ADC #$00
	STA waddr2

met42:		
	DEC prom
	BEQ met45
	
	CLC
	LDA waddr1
	ADC #$40
	STA waddr1
	LDA waddr2
	ADC #$00
	STA waddr2
	
met45:	
	LDX #$00		;обнуляем счетные регистры
	LDY #$00
	
	LDA #<vram		;настраиваем индексный адрес
	STA indx_lo
	LDA #>vram
	STA indx_hi
	
met43:		
	JSR rd_byte		;чтение байта
	STA (indx_lo),Y	;запись байта
	
	JSR inc_addr
	INY				;счетчик по элемету страницы
	BEQ met40
	
	JMP met43	
	
met40:
	INC indx_hi
	INX
	TXA	 
	CMP #$20
	BEQ met60
	
	JMP met43

met60:
	LDA waddr0		;сохраняем адрес 
	STA nexta0		;начала следующего ROM
	LDA waddr1
	STA nexta1
	LDA waddr2
	STA nexta2
	
	LDA strta0		;устанавливаем адрес 
	CLC				;начала ROM
	ADC #$10
	STA out1
	LDA strta1
	ADC #$00
	STA out2
	LDA strta2
	ADC #$00	
	STA out3	
	
	LDA ctrl		;снимаем nes_rst	
	ORA #$04
	AND #$FC
	STA ctrl
	STA out0

	LDA #$A1		;вывод заставки
	STA dig1
	STA dig4
	LDA #$86
	STA dig2
	LDA #$AB
	STA dig3
	LDA #$8D
	STA dig5
	LDA #$FF
	STA dig6
	
	LDA gamed		;вывод номера игры
	AND #$F0
	LSR A
	LSR A
	LSR A
	LSR A
	TAX
	LDA codegen, X
	STA dig7		;выводим его в поз. 7 и 8
	
	LDA gamed
	AND #$0F
	TAX
	LDA codegen, X
	STA dig8	

; бесконечный цикл	
forever:
	CLI

	LDA in1			;проверяем кнопку +
	AND #$40
	BEQ met72
	
	LDA in1			;проверяем кнопку -
	AND #$80
	BEQ met71
	
	LDA in1			;проверяем монетоприемник
	AND #$08
	BEQ for10

	JMP forever
	
for10:	
	JMP met90
	
; обработка кнопки +	
met72:
	INC game		;инкремент и
	LDA game		;проверка на 100
	CMP #$64
	BEQ	met74
	
	LDA nexta2		;проверка на
	CMP raddr2		;максимальный адрес
	BEQ met79
	BPL met74	
	JMP met81

met79:
	LDA nexta1
	CMP raddr1
	BEQ met80
	BPL met74
	JMP met81
	
met80:
	LDA nexta0
	CMP raddr0
	BEQ met74
	BPL met74

met81:	
	INC gamed		;инкремент и
	LDA gamed		;двоично-десятичная
	AND #$0F		;коррекция
	CMP #$0A
	BEQ met75
	
	JMP met78
	
met75:
	CLC
	LDA gamed
	ADC #$06
	STA gamed

met78:
	LDA nexta0		;загрузка следующего
	STA strta0		;адреса образа
	LDA nexta1
	STA strta1
	LDA nexta2
	STA strta2
	
	JMP new
	
met74:
	DEC game
	JMP forever
	
; обработка кнопки -	
met71:	
	DEC game		;декремент и
	BEQ met73		;проверка на 0
	
	DEC gamed		;декремент и
	LDA gamed		;двоично-десятичная
	AND #$0F		;коррекция
	CMP #$0F
	BEQ met76
	
	JMP met77
	
met76:
	SEC
	LDA gamed
	SBC #$06
	STA gamed

met77:	
	LDA #$00
	STA out0
	STA ctrl
	
	LDA strta0
	STA waddr0
	LDA strta1
	STA waddr1
	LDA strta2
	STA waddr2

met83:	
	JSR dec_addr
	JSR rd_byte
	
	CMP #$4E
	BEQ met82
	JMP met83
	
met82:	
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 1
	CMP #$45
	BEQ met84	
	JMP met83
	
met84:
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 2
	CMP #$53
	BEQ met85	
	JMP met83

met85:
	JSR inc_addr	;инкремент адреса
	JSR rd_byte		;чтение байта по адресу 3
	CMP #$1A
	BEQ met86	
	JMP met83	
	
met86:
	LDA waddr0
	AND #$F0
	STA strta0	
	LDA waddr1	
	STA strta1
	LDA waddr2
	STA strta2
	
	JMP new
	
met73:
	INC game
	JMP forever	
	
; обработка монетоприемника
met90:
	CLC				;добавляем одну минуту на
	LDA mins		;каждый импульс
	ADC #$01
	STA mins
	AND #$0F
	CMP #$0A
	BMI met92
	
	CLC
	LDA mins
	ADC #$06
	STA mins
	
met92:
	LDA mins
	CMP #$61
	BMI met91

	LDA #$60		;максимум - 60 минут
	STA mins
	
met91:
	LDA in1
	AND #$08
	BEQ met91
	
	LDA ctrl		;разблокировка кнопок
	AND #$FD
	STA ctrl
	STA out0
	
	JMP forever		;бесконечный цикл
	
; вывод сообщения об ошибке	
error:
	LDA codegen, X	;вывод сообщения
	STA dig8		;об ошибке и его номера
	
	LDX #$0E
	LDA codegen, X
	STA dig5
	
	LDX #$11
	LDA codegen, X
	STA dig6
	STA dig7
	
forever1:
	JMP forever1	

.endproc

; процедура чтения байта (прочитанный байт в аккумуляторе )
.proc	rd_byte
	LDA waddr0		;установка адреса
	STA out1
	LDA waddr1
	STA out2
	LDA waddr2
	STA out3	
	
	LDA ctrl		;запрос чтения байта
	ORA #$08
	STA out0
	AND #$F7
	STA out0

metrd1:	
	LDA in1			;проверяем бит валидности
	AND #$04
	BEQ metrd1		;если нет, то ждем
	LDA in3			;читаем байт
	
	RTS				;возврат из процедуры
.endproc

; процедура инкремента адреса на 1
.proc	inc_addr
	INC waddr0
	BEQ metinc1	
	RTS

metinc1:
	INC waddr1
	BEQ metinc2	
	RTS

metinc2:
	INC waddr2	
	RTS

.endproc

; процедура декремента адреса на 16
.proc	dec_addr
	SEC	
	LDA waddr0
	AND #$F0
	SBC #$10
	STA waddr0
	
	LDA waddr1
	SBC #$00
	STA waddr1

	LDA waddr2
	SBC #$00
	STA waddr2
	
	RTS

.endproc

; вектора прерываний
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "STARTUP"