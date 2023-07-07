;====================================================================
; Main.asm file generated by New Project wizard
;
; Created:   Sun May 7 2023
; Processor: AT89C51
; Compiler:  ASEM-51 (Proteus)
;====================================================================

$NOMOD51
$INCLUDE (8051.MCU)

;====================================================================
; DEFINITIONS
;====================================================================
v_TimeOutCountDown_empty	EQU	5
v_TimeOutCountDown_Low_Medium	 EQU	5 ;delay time moi level = 2 phut 
v_BuzzerOutCountDown  EQU 1 ; coi hu 1 phut roi tat 1 phut
v_DemXung_1 EQU 20 ; 1 xung 50ms => 20 = 1s 
v_DemXung_2 EQU 10 ; dung ra cho nay la 60 de ket hop lai thanh 1 phut, nhung lau qua giam con 10 de mo phong
v_ChangeMode EQU 60 ; thoi gian tu dong chuyen mode in ra man hinh; 60 => 3s
v_DutyCycle		EQU	1 ;neu o day = 2 co nghia la 2 chu ki muc thap roi toi 2 chu ki muc cao (luon = 50%)
v_DisplayCount		EQU		60 ; so lan in ra cua moi mode, xong thi doi mode
v_TH0	EQU		0ECh
v_TL0	EQU		078h
v_TH1	EQU		03Ch
v_TL1	EQU		0B0h
;====================================================================
; VARIABLES
;====================================================================
;register
;bank 0
r_Level							EQU		R0
r_TimeOutCount			EQU		R1
r_DemXung_1				EQU		R2
r_DemXung_2				EQU		R3
r_DisplayCount					EQU		R4
r_PrintStringIndex			EQU		R5
;bank 1
; R6 R7 da dung cho ham delay

;RAM - bit
b_LCD_RS					EQU		P3.0
b_LCD_E						EQU		P3.1
b_Button_1					EQU		P3.2
;b_Xung							EQU		P3.5
b_BuzzerOn				EQU		P3.6 ;bit
b_MotorControl				EQU		P3.7 ; bit off = 0, on = 1
b_MotorMode			EQU		01h ;bit: 0 binh thuong, 1 nhanh
b_DisplayOn		EQU	02h;tat bit nay khi in ra "COUTINUE"
b_DisplayMode				EQU		3h ;bit: 0 hien thi level va motor bat hay tat, 1 hien thi toc do cua motor
b_TimeOut				EQU		04h ;bit
b_TimerCountDownOn 	EQU		05h; khi co nay bat len thi bat dau dem nguoc bien timeOutCount
;b_StartBuzzerOutCountDown 	EQU		05h; khi co nay bat len thi bat dau dem nguoc bien BuzzerTimerOutCount	
b_MotorOn				EQU		06h ; bit off = 0, on = 1
;RAM - byte
OldLevel						EQU		30h
;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================
org	800h
s_LEVEL:	DB	"LEVEL: \"
s_HIGH:	DB	"HIGH\"
s_LOW: 	DB	"LOW\"
s_MEDIUM:	DB	"MEDIUM\"
s_EMPTY:		DB	"EMPTY\"
s_MOTOR:	DB	"MOTOR: \"
s_ON:	DB	"ON\"
s_OFF:		DB	"OFF\"
s_ERROR:	DB	"ERROR\"
s_Speed:		DB		"SPEED: \"    
s_NORMAL:		DB	"NORMAL\"
s_COUTINUE:	DB	"COUTINUE?\"
      ; Reset Vector
      org   0000h
      jmp   Start
      org	000bh
      jmp	ISR_Timer0
      org	001bh
      jmp	ISR_Timer1
      org	003h
      jmp	NgatNgoai0
;====================================================================
; CODE SEGMENT
;====================================================================

      org   0100h
Start:	
		mov P1, #0
		mov SP, #50h ;
;cho nay khong thua, neu xoa di khoi khoi dong coi se hu 1 ti.
		clr b_MotorOn
		clr b_BuzzerOn
		clr b_TimeOut
		setb	b_DisplayOn

		mov	r_DemXung_1, #v_DemXung_1
		mov	r_DemXung_2, #v_DemXung_2
		mov	r_DisplayCount,  #v_ChangeMode
        mov IE, #08bh	;cho phep timer0, timer1, ngat ngoai 0
        mov tmod, #11h	;chon che do 1 cho timer 0, chon che do 1 cho timer1.
		mov TH0, #v_TH0	;set gia tri ban dau cho byte cao cua timer0
		mov TL0, #v_TL0 ;set gia tri ban dau cho byte thap cua timer0
        mov TH1, #v_TH1	;set gia tri ban dau cho byte cao cua timer0
        mov TL1, #v_TL1 ;set gia tri ban dau cho byte thap cua timer0  
		setb PT0 ;uu tien ngat timer0
        setb IT0 ;ngat ngoai theo canh
        setb TR1 ;bat timer1.
        setb TR0 ;bat timer0.
        ;Function to prepare the LCD  and get it ready
        ;for using 2 lines and 5X7 matrix of LCD
        mov A, #038h
        acall lcd_cmd
        acall	Delay
        ;turn display ON, cursor OFF
        mov A, #00ch
        acall lcd_cmd     
        acall	Delay
        ;clear screen
        mov A, #001h
        acall lcd_cmd
		mov A, #5
		acall Delay
		mov A, P1
		mov	r_Level, A
Loop:
		clr b_MotorOn
		clr b_BuzzerOn
		clr b_TimeOut
		clr b_TimerCountDownOn
		setb	b_DisplayOn
		isLevel0:
		;acall Display
		; if level != 0 check again, if equal 0 then do the true branch
		mov	A, r_Level
		jnz	isLevel0  ;level != 0, check again
		; level = 0 branch		
		setb b_MotorOn ;turn motor on
		; oldLevel = level
		Label_1:
		mov	OldLevel, r_Level
		
		;start timer to count
		cjne	r_Level, #0, LevelNotEmpty
		mov r_TimeOutCount, #v_TimeOutCountDown_empty
		jmp setTimeOut
		LevelNotEmpty:
		mov r_TimeOutCount, #v_TimeOutCountDown_Low_Medium
		setTimeOut:
		mov	r_DemXung_1, #v_DemXung_1
		mov	r_DemXung_2, #v_DemXung_2
		clr	b_TimeOut
		setb	b_TimerCountDownOn

		; oldLevel < Level
		CheckLevel:
		mov A, r_Level
		cjne	A, OldLevel, notEqual_1
		jmp FALSE_1
		notEqual_1:
		jnc TRUE_1	
		FALSE_1:
		;neu timeout thi bat coi hu... Neu khong thi nhay ve CheckLevel
		jnb b_TimeOut, CheckLevel
		;timeout, bat coi hu va tat may bom
		; bat coi hu
		clr b_MotorOn
		setb b_BuzzerOn
		mov	r_TimeOutCount,  #v_BuzzerOutCountDown  ;set gia cho bo dem
		mov	r_DemXung_1, #v_DemXung_1
		mov	r_DemXung_2, #v_DemXung_2
		clr	b_TimeOut
		setb b_TimerCountDownOn ;bat dau dem nguoc

		;print "countinue?"
       ;clear screen
        mov A, #001h
        acall lcd_cmd
		mov A, #5
		acall Delay

		clr	b_DisplayOn ;tat che do in level, motor, speed 
		;in ra dong chu "COUTINUE?"
		mov	DPTR, #s_COUTINUE 
		acall PrintString


		;wait until buzzer timer out	
		;CheckBuzzerTimerOut:
		
		;jnb	b_TimeOut, CheckBuzzerTimerOut  ;check co time out
		;clr	b_BuzzerOn
;		ASK

		clr IE0 ;tat ngat ngoai 0, chuyen nut bam sang hoi coutinue
		;cho nguoi dung bam tiep tuc de khoi dong lai chuong trinh
		ASK:
		;nguoi dung co the tat coi som
		jnb	b_TimeOut, ChuaTatCoi
		clr b_BuzzerOn
		ChuaTatCoi:
		jb	b_Button_1, ASK
		;nguoi dung muon tiep tuc, bat lai cho phep ngat, tat coi va nhay ve Loop
		clr b_BuzzerOn	;tat coi som neu nguoi dung bam tiep tuc truoc khi time out.
		setb	IE0 ;bat lai ngat ngoai 0 (normal/high speed)
		jmp Loop
		TRUE_1:
		;if level = 111b thi tat may bom, neu khong thi nhay ve Label_1
		cjne	r_Level, #7, Label_1
		;tat may bom sau do nhay ve Loop
		clr b_MotorOn
		jmp Loop
		EXIT_1:
jmp Loop

Delay:
      mov	R6, A
      LoopD0:
      mov	R7, #100
      LoopD1:
      NOP
      djnz	R7, LoopD1
      NOP
      djnz	R6, LoopD0
      ret

lcd_cmd:
		push 224 ;luu gia tri cua thanh ghi A vao stack
      mov	P2, A
      clr	b_LCD_RS
      setb	b_LCD_E
		mov A, #1
      acall Delay
      clr	b_LCD_E
		pop 224 ;phuc hoi gia tri ban dau cua A
      ret

lcd_data:
		push 224 ;luu gia tri cua thanh ghi A vao stack
      mov	P2, A
      setb	b_LCD_RS
      setb	b_LCD_E
		mov A, #1
      acall Delay
      clr	b_LCD_E
		pop 224 ;phuc hoi gia tri ban dau cua A
      ret

Display:
;push cac thanh ghi vao stack
		push 224 ; day thanh ghi A vao stack
        ;clear screen
        mov A, #001h
        acall lcd_cmd

		mov A, #5
		acall Delay

		jb	b_DisplayMode, DisplayMode1
		;mode 0, in ra level hien tai
		mov	DPTR, #s_LEVEL
		lcall	PrintString
		mov A, r_Level
		cjne	A, #0b, notEmpty
		mov DPTR, #s_EMPTY
		jmp Print_1
		notEmpty:
		cjne	A, #1b, notLow
		mov DPTR, #s_LOW
		jmp Print_1
		notLow:
		cjne	A, #11b, notMedium
		mov DPTR, #s_MEDIUM
		jmp Print_1
		notMedium:
		cjne	A, #111b, notHigh
		mov DPTR, #s_HIGH
		jmp Print_1
		notHigh:
		mov DPTR, #s_ERROR		
		Print_1:
		acall	PrintString

		;in ra trang thai cua motor
        mov A, #0c0h ;xuong dong
        acall lcd_cmd
		mov A, #5
		acall Delay		
		mov	DPTR, #s_MOTOR
		acall PrintString
		jnb	b_MotorOn, PrintMotorOff
		mov	DPTR, #s_ON
		jmp Print_2
		PrintMotorOff:
		mov	DPTR, #s_OFF
		Print_2:
		acall PrintString
		jmp	ExitDisplay

		;in ra toc do cua motor
		DisplayMode1:
		mov DPTR, #s_SPEED
		acall PrintString
		jb	b_MotorMode, HighSpeed
		;Normal speed
		mov	DPTR, #s_NORMAL
		jmp Print_3
		HighSpeed:
		mov	DPTR, #s_HIGH
		Print_3:
		acall PrintString
		ExitDisplay:
;phuc hoi cac thanh ghi
		pop 224 ;Khoi phuc lai thanh ghi A
ret

PrintString:
		mov r_PrintStringIndex,  #0	
		PrintAgain:
		mov A, r_PrintStringIndex
		movc A, @A + DPTR
		cjne	A, #'\', Print
		jmp ExitPrintString
		Print:
		acall lcd_data
		inc r_PrintStringIndex
		jmp PrintAgain
		ExitPrintString:
ret

ISR_Timer1:
		push 224

		mov TH1, #v_TH1	;set gia tri ban dau cho byte cao cua timer1
		mov TL1, #v_TL1 ;set gia tri ban dau cho byte thap cua timer1
		;cpl	b_Xung

		mov	r_Level, P1 ;cap nhat level

		jnb	b_DisplayOn, KhongDoiDisplayMode  ;khi b_DisplayOn = 0, man hinh dang hien thi "COUTINUE"   nen khong dao mode
		acall Display
		djnz	r_DisplayCount, KhongDoiDisplayMode
		cpl	b_DisplayMode
		mov	r_DisplayCount,  #v_DisplayCount
		KhongDoiDisplayMode:

		;phan chuc nang countdown
		jnb b_TimerCountDownOn, NotCountDown  ;kiem tra xem co can dem nguoc hay khong.
		djnz	r_DemXung_1, notSecond
		djnz	r_DemXung_2, notMinute
		;minute is here
		djnz	r_TimeOutCount, notTimeOut
		setb	b_TimeOut ;dem xong, bat co time out
		clr b_TimerCountDownOn  ;xoa co nay, tat khong dem o chu ki sau
		notTimeOut:
		mov	r_DemXung_2, #v_DemXung_2
		notMinute:
		mov	r_DemXung_1, #v_DemXung_1
		notSecond:
		NotCountDown:

		pop 224
reti

ISR_Timer0:
		mov TH0, #v_TH0	;set gia tri ban dau cho byte cao cua timer0
		mov TL0, #v_TL0 ;set gia tri ban dau cho byte thap cua timer0
		;dieu kien dong co - bam xung
		jnb	b_MotorOn, MotorOff  
		;motor bat, kiem tra mode va bang xung
		jb	b_MotorMode, HighSpeedMode
		cpl	b_MotorControl
		jmp	ExitISR_Timer0
		HighSpeedMode:
		setb	b_MotorControl
		jmp	ExitISR_Timer0
		MotorOff:
		clr b_MotorControl
		ExitISR_Timer0:
reti

NgatNgoai0:
		cpl	b_MotorMode
reti
;====================================================================
      END
