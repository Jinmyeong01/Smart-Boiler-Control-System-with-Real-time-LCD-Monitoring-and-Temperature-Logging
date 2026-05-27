.MODEL SMALL
.STACK 100H

.DATA
    CURRENT_TEMP    DB  25      ; 현재 온도
    TARGET_HIGH     DB  30      ; 상한 온도
    TARGET_LOW      DB  18      ; 하한 온도
    BOILER_STATUS   DB  0       ; 보일러 상태 (0:OFF, 1:ON)
    T_COUNTER       DB  0       ; 타이머 인터럽트 카운터
    
    ; --- [Extension 관련 변수 추가] ---
    TEMP_LOG        DB  10 DUP(0) ; 온도를 저장할 10바이트 크기의 배열 (0으로 초기화)
    LOG_INDEX       DW  0       ; 배열의 현재 저장 위치를 가리키는 인덱스 (포인터)
    AVG_TEMP        DB  0       ; 계산된 평균 온도가 저장될 변수

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX
    MOV ES, AX                  

    ; --- 인터럽트 벡터 테이블(IVT) 등록 ---
    CLI                         
    XOR AX, AX
    MOV ES, AX                  
    MOV DI, 0020H       
    
    LEA AX, TIMER_ISR           
    MOV ES:[DI], AX     
    MOV AX, CS                  
    MOV ES:[DI+2], AX   
    STI                         

MAIN_LOOP:
    INT 08H                     ; [테스트용] 타이머 인터럽트 강제 발생

    ; --- 보일러 제어 로직 ---
    MOV AL, CURRENT_TEMP
    CMP AL, TARGET_HIGH
    JGE TURN_OFF_BOILER
    CMP AL, TARGET_LOW
    JLE TURN_ON_BOILER

    ; --- [Extension: 평균 온도 계산 호출] ---
    CALL CALCULATE_AVERAGE

    JMP MAIN_LOOP               

TURN_OFF_BOILER:
    MOV BOILER_STATUS, 0        
    JMP MAIN_LOOP

TURN_ON_BOILER:
    MOV BOILER_STATUS, 1        
    JMP MAIN_LOOP

MAIN ENDP

; =========================================================================
; 1. 타이머 인터럽트 서비스 루틴 (Data Logging 기능 추가)
; =========================================================================
TIMER_ISR PROC
    PUSH AX                     
    PUSH BX
    PUSH SI
    PUSH DS
    
    MOV AX, @DATA               
    MOV DS, AX
    
    INC T_COUNTER               

    ; --- [핵심: 현재 온도를 TEMP_LOG 배열에 기록] ---
    MOV SI, LOG_INDEX           ; 현재 인덱스(0~9)를 SI 레지스터로 복사
    MOV AL, CURRENT_TEMP        ; 현재 온도를 AL에 로드
    MOV TEMP_LOG[SI], AL        ; TEMP_LOG[SI] 위치에 온도 저장!
    
    ; 인덱스 증가 및 오버플로우 방지 (10개까지만 저장하고 다시 0으로 돌아옴)
    INC SI
    CMP SI, 10
    JNE SAVE_INDEX              
    XOR SI, SI                  
SAVE_INDEX:
    MOV LOG_INDEX, SI           

    ; 인터럽트 종료 신호
    MOV AL, 20H
    OUT 20H, AL         
    
    POP DS                      
    POP SI
    POP BX
    POP AX
    IRET                        
TIMER_ISR ENDP

; =========================================================================
; 2. Extension: 배열에 저장된 온도들의 평균값을 구하는 프로시저
; =========================================================================
CALCULATE_AVERAGE PROC
    PUSH AX
    PUSH CX
    PUSH SI
    
    XOR AX, AX                  ; 합계를 누적할 AX 초기화 (AH=0, AL=0)
    MOV CX, 10                  ; 데이터 개수 (10번 반복)
    XOR SI, SI                  ; 배열 인덱스 0부터 시작
    
SUM_LOOP:
    XOR BX, BX
    MOV BL, TEMP_LOG[SI]        ; 배열에서 온도 값을 하나씩 가져옴
    ADD AX, BX                  ; AX = AX + BX (온도 누적 합산)
    INC SI                      ; 다음 칸으로 이동
    LOOP SUM_LOOP               ; CX가 0이 될 때까지 반복
    
    ; --- 평균 내기 (합산 값 / 10) ---
    MOV CL, 10
    DIV CL                      ; AL = AX / 10 (몫은 AL, 나머지는 AH에 저장됨)
    MOV AVG_TEMP, AL            ; 최종 평균값(몫)을 AVG_TEMP 변수에 저장!
    
    POP SI
    POP CX
    POP AX
    RET
CALCULATE_AVERAGE ENDP

END MAIN