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
;CONSTANT
;====================================================================
v_TimeOutCountDown_empty		EQU	2 ;10s
v_TimeOutCountDown_Low_Medium	EQU	4 ;20s
v_BuzzerOutCountDown  			EQU 1 ;còi hú 1 đơn vị thời gian của hệ thống (10s).

;timer có chu kì là 50ms
;định nghĩa 2 biến đếm kết hợp tạo thành 1 đơn vị thời gian cho hệ thống 
;(thực tế là 1 phút, nhưng để dễ mô phỏng giảm còn 10s).
v_DemXung			EQU 20 ;1 xung 50ms => 20 xung = 1s 
v_DemGiay			EQU 10 ;đúng ra chỗ này là 60s (1 đơn vị thời gian của hệ thống), nhưng đê dễ mô phỏng giảm còn 10.

v_DisplayCount		EQU 60 ;số lần in ra của mỗi mode. mỗi lần in cách nhau 50ms, vậy 60 <=> 3s
v_TH0				EQU 0FCh
v_TL0				EQU 018h
v_TH1				EQU 03Ch
v_TL1				EQU 0B0h

;====================================================================
; VARIABLES
;====================================================================

;register
;====================================================================
r_Level				EQU		R0
r_TimeOutCount		EQU		R1
r_DemXung			EQU		R2
r_DemGiay			EQU		R3
r_DisplayCount		EQU		R4
r_PrintStringIndex	EQU		R5
;R6 R7 đã dùng cho hàm delay

;RAM - bit
;====================================================================
b_LCD_RS				EQU		P3.0
b_LCD_E					EQU		P3.1
b_Button_1				EQU		P3.2 ;chân nối với nút nhấn.
b_BuzzerOn				EQU		P3.6 ;chân điều khiển còi báo.
b_MotorControl			EQU		P3.7 ;chân điều khiển motor.
b_MotorMode				EQU		01h ;0: normal. 1: high.

;bit bật tắt chế dộ hiển thị level, trạng thái và tốc độ của motor.
;tắt khi ở chế độ hiển thị "COUTINUE".
b_DisplayOn				EQU		02h

b_DisplayMode			EQU		3h ;chế độ hiển thị của lcd. 0: level + on/off. 1: speed.
b_TimeOut				EQU		04h ;cờ báo timeout.

;cờ kích hoạt chế độ hẹn giờ cho timer.
;Lưu ý timer trong hệ thống có nhiều mục đích sử dụng. hẹn giờ là 1 trong số đó.
b_TimerCountDownOn 		EQU		05h 

;bit bật tắt motor. Khác với b_MotorControl (chân điều khiển động cơ). 
;ví dụ khi motor bật b_MotorOn = 1, nhưng do băm xung nên b_MotorControl đảo liên tục.
b_MotorOn				EQU		06h

;RAM - byte
OldLevel				EQU		30h

;====================================================================
; STRINGS
;====================================================================
;dùng kí tự '\' làm kí tự kết thúc chuỗi.
org	800h
s_LEVEL:		DB	"LEVEL: \"
s_HIGH:			DB	"HIGH\"
s_LOW: 			DB	"LOW\"
s_MEDIUM:		DB	"MEDIUM\"
s_EMPTY:		DB	"EMPTY\"
s_MOTOR:		DB	"MOTOR: \"
s_ON:			DB	"ON\"
s_OFF:			DB	"OFF\"
s_ERROR:		DB	"ERROR\"
s_Speed:		DB		"SPEED: \"    
s_NORMAL:		DB	"NORMAL\"
s_COUTINUE:		DB	"COUTINUE?\"

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================
org 0000h
jmp	Start
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
	mov SP, #50h ;khởi tạo địa chỉ ban đầu cho stack.
	;chỗ này không thừa, nếu xóa đi lúc khởi động còi sẽ bị hú 1 tí.
	clr b_MotorOn
	clr b_BuzzerOn
	clr b_TimeOut
	setb b_DisplayOn

	mov	r_DemXung, #v_DemXung
	mov	r_DemGiay, #v_DemGiay
	mov	r_DisplayCount, #v_DisplayCount
	mov IE, #08bh	;cho phép ngắt ngoài 0, timer0, timer1.
	mov tmod, #11h	;chọn chế độ 1 cho timer 0 và timer 1.
	mov TH0, #v_TH0	;đặt giá trị ban đầu cho byte cao của timer0
	mov TL0, #v_TL0 ;đặt giá trị ban đầu cho byte thấp của timer0
	mov TH1, #v_TH1	;đặt giá trị ban đầu cho byte cao của timer1
	mov TL1, #v_TL1 ;đặt giá trị ban đầu cho byte thấp của timer1
	setb PT0 ;ưu tiên ngắt timer0
	setb IT0 ;ngắt ngoài theo cạnh
	setb TR1 ;bật timer1.
	setb TR0 ;bật timer0.

	;khởi tạo cho lcd
	;====================================================================
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
	; nếu level !0 thì kiểm tra lại, ngược lại thì thực hiện phần giải thuật khi level = 0.
	mov	A, r_Level
	jnz	isLevel0  ;level != 0, check again

	; level = 0 	
	;====================================================================	
	setb b_MotorOn ;bật máy bơm.

	Label_1:
	mov	OldLevel, r_Level
	
	;kiểm tra level và hẹn giờ tương ứng (empty: 20s, mức khác 40s).
	cjne	r_Level, #0, LevelNotEmpty
	mov r_TimeOutCount, #v_TimeOutCountDown_empty
	jmp setTimeOut
	LevelNotEmpty:
	mov r_TimeOutCount, #v_TimeOutCountDown_Low_Medium
	setTimeOut:
	mov	r_DemXung, #v_DemXung
	mov	r_DemGiay, #v_DemGiay
	clr	b_TimeOut
	setb b_TimerCountDownOn ;bật bộ hẹn giờ.

	;so sánh mức cũ và mức hiện tại
	;level > oldLevel <=> oldLevel < level
	CheckLevel:
	mov A, OldLevel
	subb A, r_Level
	jc	TRUE_1 ;nếu oldLevel < level thì nhảy.

	;oldLevel >= level =================================================
	;nếu timeout thì bật còi hú, ngược lại nhảy về CheckLevel.
	jnb b_TimeOut, CheckLevel

	;timeout ===========================================================
	;bật còi hú
	clr b_MotorOn
	setb b_BuzzerOn
	mov	r_TimeOutCount,  #v_BuzzerOutCountDown  ;đặt giá trị cho bộ đếm
	mov	r_DemXung, #v_DemXung
	mov	r_DemGiay, #v_DemGiay
	clr	b_TimeOut
	setb b_TimerCountDownOn ;bắt đầu hẹn giờ.

	;print "countinue?" ================================================
	;clear screen
	mov A, #001h
	acall lcd_cmd
	mov A, #5
	acall Delay

	clr	b_DisplayOn ;tắt chế độ in level, motor, speed 
	;in ra dòng chữ "COUTINUE?"
	mov	DPTR, #s_COUTINUE 
	acall PrintString

	;ASK ===============================================================
	clr IE0 ;tắt ngắt ngoài 0, chuyển nút bấm sang chế độ trả lời "COUTINUE?".
	;chờ người dùng nhấn nút để khởi động lại hệ thống.
	ASK:
	;người dùng có thể nhấn nút để tắt còi sớm (hoặc còi tự tắt sau 10s).
	jnb	b_TimeOut, ChuaTatCoi
	clr b_BuzzerOn
	ChuaTatCoi:
	jb	b_Button_1, ASK
	;người dùng muốn tiếp tục, bật lại cho phép ngắt, tắt còi và nhảy về Loop.
	clr b_BuzzerOn	;tắt còi sớm nếu người dùng bấm tiếp tục.
	setb	IE0 ;bật lại ngắt ngoài 0 (normal/high speed).
	jmp Loop
	TRUE_1:
	;nếu level = 7 (high) thì ngừng máy bơm và nhảy về Loop.
	;nếu khác high thì nhảy về Label_1 (so sánh oldLevel và level).
	cjne	r_Level, #7, Label_1
	;tắt máy bơm sau đó nhảy về Loop.
	clr b_MotorOn
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
	push 224 ;lưu giá trị của thanh ghi A vào stack
	mov	P2, A
	clr	b_LCD_RS
	setb	b_LCD_E
	mov A, #1
	acall Delay
	clr	b_LCD_E
	pop 224 ;phục hồi lại giá trị của A
	ret

lcd_data:
	push 224 ;lưu giá trị của thanh ghi A vào stack
	mov	P2, A
	setb	b_LCD_RS
	setb	b_LCD_E
	mov A, #1
	acall Delay
	clr	b_LCD_E
	pop 224 ;phục hồi lại giá trị của A
	ret

Display:
	push 224 ;lưu giá trị của thanh ghi A vào stack
	;clear screen
	mov A, #001h
	acall lcd_cmd

	mov A, #5
	acall Delay

	jb	b_DisplayMode, DisplayMode1
	;mode 0 ==============================================
	;in ra level hiện tại.
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

	;in ra trạng thái của motor
	mov A, #0c0h ;kí tự xuống dòng
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

	DisplayMode1:
	;in ra tốc độ của motor ==============================
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

	pop 224 ;Khôi phục thanh ghi A
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

	mov TH1, #v_TH1	;đặt giá trị đếm ban đầu cho byte cao của timer1.
	mov TL1, #v_TL1 ;đặt giá trị đếm ban đầu cho byte thấp của timer1.
	;cpl	b_Xung

	mov	r_Level, P1 ;cập nhật level.

	jnb	b_DisplayOn, KhongDoiDisplayMode ;khi b_DisplayOn = 0, màn hình đang hiển thị "COUTINUE?" nên không đổi mode.
	acall Display ;gọi hàm hiển thị
	djnz	r_DisplayCount, KhongDoiDisplayMode
	cpl	b_DisplayMode
	mov	r_DisplayCount,  #v_DisplayCount
	KhongDoiDisplayMode:

	;phần chức năng hẹn giờ (timer) ==============================
	jnb b_TimerCountDownOn, NotCountDown  ;kiểm tra xem có đang hẹn giờ hay không.
	;đang hẹn giờ ================================================
	djnz	r_DemXung, notSecond
	djnz	r_DemGiay, notMinute
	;đếm xong 1 phút =============================================
	djnz	r_TimeOutCount, notTimeOut
	setb	b_TimeOut ;đếm xong, bật cờ timeout
	clr b_TimerCountDownOn  ;xóa cờ bật hẹn giờ, không đếm ở chu kì sau.
	notTimeOut:
	mov	r_DemGiay, #v_DemGiay
	notMinute:
	mov	r_DemXung, #v_DemXung
	notSecond:
	NotCountDown:
	pop 224
reti

ISR_Timer0:
	mov TH0, #v_TH0	;đặt giá trị đếm ban đầu cho byte cao của timer1.
	mov TL0, #v_TL0 ;đặt giá trị đếm ban đầu cho byte thấp của timer1.
	;điều khiển băm xung =========================================
	;mặc định xung 50% cho tốc độ normal, 100% cho high ==========
	jnb	b_MotorOn, MotorOff  
	;motor bật, kiểm tra mode và băm xung.
	jb	b_MotorMode, HighSpeedMode
	cpl	b_MotorControl ;băm xung 50%
	jmp	ExitISR_Timer0
	HighSpeedMode:
	setb	b_MotorControl ;băm xung 100%
	jmp	ExitISR_Timer0
	MotorOff:
	clr b_MotorControl ;tắt motor.
	ExitISR_Timer0:
reti

NgatNgoai0:
	cpl	b_MotorMode ;đảo mode.
reti
;====================================================================
      END
