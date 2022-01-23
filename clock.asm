;
; CLOCK YEP
;
; Created: 2021-12-02 11:35:30
; Author : Lawli
;
	jmp		CONFIG

	.org	OC1Aaddr
	jmp		TIME_TICK
	.org	INT_VECTORS_SIZE

	.equ	FN_SET =	0b00101000		
	.equ	DISP_SET =	0b00001111	
	.equ	LCD_CLR =	0b00000001	
	.equ	E_MODE =	0b00000110	
	.equ	SECOND_TICKS = 62500 - 1	



;Set limits on time units
TIME_LIMITS:
	.db		10,6,10,6,10,3,$00,$00

	.dseg
TIME:
	.byte	6
TIME_LINE:
	.byte	17

	.cseg
;
;
;-----------------------------------------------------------------
; set stack and configuration
CONFIG:
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16
	
	call	INIT
	call	LCD_INIT

	;Sets zeros in SRAM before using the location TIME
	ldi		XH,HIGH(TIME)
	ldi		XL,LOW(TIME)
	call	SET_ZERO	

	;Set time to 23:59:45
	call	SET_TIME
	call	TIMER1_INIT
	sei
	jmp		MAIN



MAIN:
	call	TIME_FORMAT
	call	LINE_PRINT
	jmp		MAIN



;ONLY SUBRUTINES BELOW THIS LINES
; -------------------------------------------------------------------

SET_ZERO:
	push	r16
	push	r17

	ldi		r17,0
	ldi		r16,6
SET_ZERO_LOOP:
	st		X+,r17
	dec		r16
	brne	SET_ZERO_LOOP

	pop		r17
	pop		r16
	ret

;set "time" routine for debugging purposes
SET_TIME:
	ldi		XH,HIGH(TIME)
	ldi		XL,LOW(TIME)

	ldi		r16,5			;DIGIT 0
	st		X+,r16

	ldi		r16,4			;DIGIT 1
	st		X+,r16

	ldi		r16,9			;DIGIT 2
	st		X+,r16

	ldi		r16,5			;DIGIT 3
	st		X+,r16

	ldi		r16,3			;DIGIT 4
	st		X+,r16

	ldi		r16,2			;DIGIT 5
	st		X+,r16

	ret

;call INIT
; ----Init. Pinnar on D0-D7 out, B3-B0 out (one extra but whatever)

INIT:
	ldi		r16,$FF
	out		DDRD, r16
	ldi		r16, $0F
	out		DDRB, r16
	ret


BACKLIGHT_ON:
	sbi		PORTB,2
	ret

BACKLIGHT_OFF:
	cbi		PORTB,2
	ret

;
;Chnage LINE to point to other memory location
LINE_PRINT:
	call	LCD_HOME
	ldi		ZH,HIGH(TIME_LINE)
	ldi		ZL,LOW(TIME_LINE)
	call	LCD_PRINT
	ret

TIMER1_INIT:
	ldi		r16,(1<<WGM12)|(1<<CS12)
	sts		TCCR1B,r16
	ldi		r16,HIGH(SECOND_TICKS)
	sts		OCR1AH,r16
	ldi		r16,LOW(SECOND_TICKS)
	sts		OCR1AL,r16
	ldi		r16,(1<<OCIE1A)
	sts		TIMSK1,r16
	ret
;
;
;Fills the entire row on display. Outside clock is empty spaces.
TIME_FORMAT:
	push	r16
	push	r17
	push	r18
	push	XH
	push	XL
	push	ZH
	push	ZL

	ldi		XH,HIGH(TIME)
	ldi		XL,LOW(TIME)
	adiw	X,5
	ldi		ZH,HIGH(TIME_LINE)
	ldi		ZL,LOW(TIME_LINE)
	;adiw	ZH:ZL,1

	ldi		r18,3
FORMAT_LOOP_OUTER:
	ldi		r17,2
FORMAT_LOOP_INNER:
	ld		r16,X
	sbiw	XH:XL,1
	subi	r16,-$30
	st		Z+,r16
	dec		r17
	brne	FORMAT_LOOP_INNER
	ldi		r16,':'
	st		Z+,r16
	dec		r18
	brne	FORMAT_LOOP_OUTER

	sbiw	ZH:ZL,1
	ldi		r17,8
	ldi		r16, ' '
FORMAT_FILL_SPACES:
	st		Z+,r16
	dec		r17
	brne	FORMAT_FILL_SPACES

	ldi		r16,$00				;Sets nullterminator
	st		Z,r16
	
	pop		ZL
	pop		ZH
	pop		XL
	pop		XH
	pop		r18
	pop		r17
	pop		r16
	ret

	
TIME_TICK:
	push	XH
	push	XL
	push	ZH
	push	ZL
	push	r18
	push	r17
	push	r16	
	push	r19	
	in		r17,SREG
	push	r17

	ldi		XH,HIGH(TIME)
	ldi		XL,LOW(TIME)
	ldi		ZH,HIGH(TIME_LIMITS*2)
	ldi		ZL,LOW(TIME_LIMITS*2)

	lpm		r17,Z
TICK_LOOP:
	ld		r16,X
	inc		r16
	cp		r16,r17
	brne	FINISH
	clr		r16
	st		X+,r16
	adiw	ZH:ZL,1
	lpm		r17,Z
	brne	TICK_LOOP

CHECK_RESET:
	adiw	ZH:ZL,1
	lpm		r17,Z
	cpi		r17,3		;If 2 then reset
	brne	FINISH_CONT
	clr		r16
	st		X+,r16
	jmp		FINISH_CONT

FINISH:
	cpi		r16,4
	breq	CHECK_RESET

FINISH_CONT:
	st		X,r16

	pop		r17
	out		SREG,r17
	pop		r19
	pop		r16
	pop		r17
	pop		r18
	pop		ZL
	pop		ZH
	pop		XL
	pop		XH
	reti

;
;DECREMENTS LOOP 256*256*2 (r16*r17*r18) times eqv. of
;24 ms at 16 MHz
WAIT:
	push	r18
	push	r17 
	push	r16

	ldi		r18, 1			;CHANGE TO INCREASE WAIT. 24 ms = 3.
D_3:
	ldi		r17, 0
D_2:
	ldi		r16, 0
D_1:
	dec		r16
	brne	D_1
	dec		r17
	brne	D_2
	dec		r18
	brne	D_3

	pop		r16
	pop		r17
	pop		r18
	ret
;
;Display configuration
LCD_INIT:
	; ----turn backlight on
	call	BACKLIGHT_ON
	; --- wait for LCD ready
	call	WAIT
	
	;
	; ----- First initiate 4-bit mode
	; 

	ldi		r16,$30
	call	LCD_WRITE4
	call	LCD_WRITE4
	call	LCD_WRITE4
	ldi		r16,$20
	call	LCD_WRITE4

	;
	; --- Now configure display
	;

	; --- Function set: 4-bit mode, 2 line, 5x8 font
	ldi		r16,FN_SET
	call	LCD_COMMAND

	; --- Display on, cursor on, cursor blink
	ldi		r16,DISP_SET
	call	LCD_COMMAND

	; --- Clear display
	ldi		r16,LCD_CLR
	call	LCD_COMMAND

	; --- Entry mode: Increment cursor, no shift
	ldi		r16,E_MODE
	call	LCD_COMMAND
	ret

;
;
;Writes 4 high bits
LCD_WRITE4:
	sbi		PORTB,1
	out		PORTD,r16
	cbi		PORTB,1
	call	WAIT
	ret
;
;Write all 8 bits in two calls
LCD_WRITE8:
	call	LCD_WRITE4
	swap	r16
	call	LCD_WRITE4
	ret
;
;Allow writing of ascii on display
LCD_ASCII:
	;sätt RS rätt
	sbi		PORTB,0
	call	LCD_WRITE8
	ret
;
;Allow commands on display
LCD_COMMAND:
	;sätt RS rätt
	cbi		PORTB,0
	call	LCD_WRITE8
	ret
;
;Set cursor on column 0
LCD_HOME:
	ldi		r16,0b00000010
	call	LCD_COMMAND
	ret
;
;Clear display
LCD_ERASE:
	ldi		r16,LCD_CLR
	call	LCD_COMMAND
	ret
;
;Print ascii OBS: SRAM ONLY
LCD_PRINT:
LOOPER:
	ld		r16,Z+
	call	LCD_ASCII
	ld		r16,Z		;Check if next value is nullterminator
	cpi		r16,0
	brne	LOOPER

	ret
