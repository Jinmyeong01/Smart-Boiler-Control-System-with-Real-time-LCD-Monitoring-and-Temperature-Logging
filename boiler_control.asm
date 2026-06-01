.MODEL SMALL
.STACK 100H

MOTOR_PORT      EQU     00H     ; 보일러 모터 제어 포트
LCD_CMD_PORT    EQU     10H     ; LCD 명령어 제어 포트
LCD_DATA_PORT   EQU     12H     ; LCD 텍스트 출력 포트

.DATA
    CURRENT_TEMP    DB  25      ; 현재 온도
    TARGET_HIGH     DB  30      ; 상한 온도
    TARGET_LOW      DB  18      ; 하한 온도
    BOILER_STATUS   DB  0       ; 보일러 상태 (0:OFF, 1:ON)
    T_COUNTER       DB  0       ; 타이머 인터럽트 카운터
    
    TEMP_LOG        DB  10 DUP(0) 
    LOG_INDEX       DW  0       
    AVG_TEMP        DB  0       

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX                  

    ; --- 1. 타이머 인터럽트(IVT) 등록 ---
    CLI                         
    XOR AX, AX
    MOV ES, AX                  
    MOV DI, 0020H       
    LEA AX, TIMER_ISR           
    MOV ES:[DI], AX     
    MOV AX, CS                  
    MOV ES:[DI+2], AX   
    STI                         

    ; --- 2. LCD 초기화 프로시저 호출 ---
    CALL INIT_LCD


MAIN_LOOP:
    INT 08H                     ; [테스트용] 타이머 인터럽트 강제 발생

    ; --- 핵심 조건문 및 분기 로직 ---
    MOV AL, CURRENT_TEMP
    
    CMP AL, TARGET_HIGH         ; 조건 1: 현재 온도 >= 상한 온도(30도)
    JGE TURN_OFF_BOILER         ; 보일러 끄는 구역으로 분기
    
    CMP AL, TARGET_LOW          ; 조건 2: 현재 온도 <= 하한 온도(18도)
    JLE TURN_ON_BOILER          ; 보일러 켜는 구역으로 분기

    ; --- LCD 실시간 모니터링 로직 ---
    ; 루프가 돌 때마다 LCD 화면에 현재 온도를 지속적으로 업데이트합니다.
    CALL CALCULATE_AVERAGE
    CALL DISPLAY_STATUS_LCD

    JMP MAIN_LOOP               

; --- 보일러 정지 제어 분기 ---
TURN_OFF_BOILER:
    MOV BOILER_STATUS, 0        ; 내부 상태 변수 변경
    MOV AL, 00H                 ; 모터 OFF 신호
    OUT MOTOR_PORT, AL          ; 실제 하드웨어 포트로 명령 송신!
    CALL DISPLAY_STATUS_LCD
    JMP MAIN_LOOP

; --- 보일러 가동 제어 분기 ---
TURN_ON_BOILER:
    MOV BOILER_STATUS, 1        ; 내부 상태 변수 변경
    MOV AL, 01H                 ; 모터 ON 신호 (가동)
    OUT MOTOR_PORT, AL          ; 실제 하드웨어 포트로 명령 송신!
    CALL DISPLAY_STATUS_LCD
    JMP MAIN_LOOP

MAIN ENDP


INIT_LCD PROC
    ; LCD를 켜고 8비트 모드로 설정하는 초기화 명령을 내보냅니다.
    MOV AL, 38H                 ; 기능 설정 (8비트, 2줄, 5x7 도트)
    OUT LCD_CMD_PORT, AL
    MOV AL, 0CH                 ; 화면 ON, 커서 OFF
    OUT LCD_CMD_PORT, AL
    RET
INIT_LCD ENDP

DISPLAY_STATUS_LCD PROC
    PUSH AX
    
    ; 1. LCD 첫 번째 줄 첫 칸으로 커서 이동 명령어 전송
    MOV AL, 80H                 
    OUT LCD_CMD_PORT, AL
    
    ; 2. 현재 온도를 LCD 데이터 포트로 전송
    MOV AL, CURRENT_TEMP        
    ; 원래는 숫자를 아스키코드('2', '5')로 변환해야 하지만 
    ; 일단 포트에 데이터가 찍히는지 테스트하기 위해 변수 값을 바로 쏩니다.
    OUT LCD_DATA_PORT, AL       
    
    POP AX
    RET
DISPLAY_STATUS_LCD ENDP


TIMER_ISR PROC
    PUSH AX                     
    PUSH BX
    PUSH SI
    PUSH DS
    
    MOV AX, @DATA               
    MOV DS, AX
    
    INC T_COUNTER               

    MOV SI, LOG_INDEX           
    MOV AL, CURRENT_TEMP        
    MOV TEMP_LOG[SI], AL        
    
    INC SI
    CMP SI, 10
    JNE SAVE_INDEX              
    XOR SI, SI                  
SAVE_INDEX:
    MOV LOG_INDEX, SI           

    MOV AL, 20H
    OUT 20H, AL         
    
    POP DS                      
    POP SI
    POP BX
    POP AX
    IRET                        
TIMER_ISR ENDP


CALCULATE_AVERAGE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    XOR AX, AX                  ; 합계를 누적할 AX 초기화
    MOV CX, 10                  ; 루프 10번 반복 설정
    XOR SI, SI                  ; 배열 인덱스(SI) 0으로 초기화

SUM_LOOP:
    XOR BX, BX
    MOV BL, TEMP_LOG[SI]        ; 배열에서 온도 값을 하나 꺼냄
    ADD AX, BX                  ; 누적 합계 계산
    INC SI
    LOOP SUM_LOOP

    ; --- 평균 내기 (총합 / 10) ---
    MOV CL, 10
    DIV CL                      ; 총합(AX)을 10으로 나눔. 몫은 AL에 들어감
    MOV AVG_TEMP, AL            ; 최종 평균값(몫)을 변수에 저장

    POP SI
    POP CX
    POP BX
    POP AX
    RET
CALCULATE_AVERAGE ENDP

END MAIN