;******************************************************************************
        .define dir_reg, 0x00
        .define port_reg, 0x01
        .define pin_reg, 0x02

        .define prescaler_l, 0x03
        .define prescaler_h, 0x04
        .define count_ctrl, 0x05

        .define gpu_addr, 0x2000
        .define gpu_ctrl_reg, 0x80

        .define gpu_isr_vector, 0x0020
        .define top_isr_vector, 0x0030
;******************************************************************************         
        .code
                
        ldi r14, 0xff                   ; set stack pointer

        ldi r0, 0b00011000
        out r0, gpu_ctrl_reg

        ldi r2, gpu_addr[l]
        ldi r3, gpu_addr[h]

        ldi r0, 1
        out r0, dir_reg                 ; set pin 1 to output

        ldi r0, 36
        out r0, prescaler_l             ; set LSBs of prescaler

        ldi r0, 244
        out r0, prescaler_h             ; set MSPs of prescaler

        ldi r0, 0b00010010
        out r0, count_ctrl              ; set pwm mode, set top interrupt

        ldi r5, 0

        ssr 8                           ; enable interrupts
loop:   jmp loop                        ; loop and wait for interrupt
;******************************************************************************
        .org top_isr_vector
isr:    in r0, port_reg                 ; read pin register
        xoi r0, 1                       ; toggle the led bit
        out r0, port_reg                ; write to the port register
        jz exit
        adi r5, 1
        mov r12, r5
        call numToStr
        ldi r2, gpu_addr[l]
        ldi r3, gpu_addr[h]
exit:   ssr 8                           ; enable interrupts
        ret
;******************************************************************************
numToStr:
        mov r13, r12
        srl r13
        srl r13
        srl r13
        srl r13
        cpi r13, 0x09
        jn alpha1
        adi r13, 48
        jmp print1
alpha1: adi r13, 55
print1: sri r13, p2
        ani r12, 0x0f
        cpi r12, 0x09
        jn alpha2
        adi r12, 48
        jmp print2
alpha2: adi r12, 55
print2: sri r12, p2
        ret
;******************************************************************************