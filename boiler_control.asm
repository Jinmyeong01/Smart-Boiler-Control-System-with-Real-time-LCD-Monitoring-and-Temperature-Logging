                         .MODEL SMALL
.STACK 100H

.DATA
    CURRENT_TEMP    DB  25      ; 현재 온도
    TARGET_HIGH     DB  30      ; 상한 온도
    TARGET_LOW      DB  18      ; 하한 온도
    BOILER_STATUS   DB  0       ; 보일러 상태 (0:OFF, 1:ON)
    T_COUNTER       DB  0       ; 타이머 인터럽트 카운터

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX                  

    ; --- 인터럽트 벡터 테이블(IVT) 등록 ---
    CLI                         
    XOR AX, AX
    MOV ES, AX                  
    MOV DI, 0020H       ; INT 08H의 주소 영역
    
    LEA AX, TIMER_ISR           
    MOV ES:[DI], AX     
    MOV AX, CS                  
    MOV ES:[DI+2], AX   
    STI                         

MAIN_LOOP:
    ; -------------------------------------------------------------
    ; [테스트용] 하드웨어 타이머 인터럽트가 터진 상황을 코드로 시뮬레이션
    ; -------------------------------------------------------------
    INT 08H                     
    
    ; --- 보일러 제어 로직 ---
    MOV AL, CURRENT_TEMP
    CMP AL, TARGET_HIGH
    JGE TURN_OFF_BOILER
    CMP AL, TARGET_LOW
    JLE TURN_ON_BOILER
    JMP MAIN_LOOP               

TURN_OFF_BOILER:
    MOV BOILER_STATUS, 0        
    JMP MAIN_LOOP

TURN_ON_BOILER:
    MOV BOILER_STATUS, 1        
    JMP MAIN_LOOP

MAIN ENDP

; --- 타이머 인터럽트 서비스 루틴 ---
TIMER_ISR PROC
    PUSH AX                     
    PUSH DS
    MOV AX, @DATA               
    MOV DS, AX
    
    INC T_COUNTER               ; 인터럽트가 호출될 때마다 1씩 증가!

    MOV AL, 20H
    OUT 20H, AL         
    POP DS                      
    POP AX
    IRET                        
TIMER_ISR ENDP

END MAIN