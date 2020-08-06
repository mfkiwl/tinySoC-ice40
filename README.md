# tinySoC
tinySoC is a small system on a chip consisting of an 8-bit CPU, an 80 column VGA graphics card, GPIO and counter/timer peripherals, all implemented on an ice40 FPGA.

## The CPU
![datapath](resources/datapath.jpg)
The CPU is an 8-bit RISC core, with a Harvard architecture. It has a 16-bit wide instruction memory, an 8-bit wide data memory, and both have a 16-bit address. The CPU has 16 general purpose 8-bit registers along with a 4-bit status register. The processor is not fully pipelined, but does fetch the next instruction while executing the current one. Most instructions execute in a single clock cycle, but a few take two or three.

## The GPU
![gpu](resources/gpu.jpg)
The GPU operates in a monochrome 80 column text mode, and outputs a VGA signal at a resolution of 640 by 480 at 60 frames per second. The GPU contains an ASCII buffer which the user can write to in order to display messages on the screen. A control register allows the user to set the text to one of 7 colours, and to enable an interrupt to the CPU which fires every time a frame finishes and enters the blanking period.

## The Instruction Set
![instruction set part 1](resources/instruction_set_part_1.jpg)
![instruction set part 2](resources/instruction_set_part_2.jpg)

## The Assembler

The assembler is case insensitive.

### Comments
Comments begin with semicolons.
```assembly
ldi r0, 1 ; This is a comment
```

### Constants
Constants are in decimal by default, but hexadecimal and binary are also supported. Constants can also be negative and are stored in two's complement form.
```assembly
ldi r0, 10     ; Decimal constant
ldi r0, 0x0A   ; Hexadecimal constant
ldi r0, 0b1010 ; Binary constant
ldi r0, -10    ; A negative constant
```

### Label Definitions
Label definitions may be any string ending with a colon, as long as the string is not in the form of a constant or is one of the reserved keywords

```assembly
        .code
        ldi r0, 10
loop:   adi r0, -1
        jnz loop
        hlt
```

### Directives

#### .org
Sets the origin to the given address. Only forward movement of the origin is permitted.
```assembly
        .code
        ldi r0, 1
        out r0, 0
        jmp foo
        
        .org 0x0B
foo:    out r0, 1
        hlt
        
;***************************************************************************************
Address        Label          Code                     Source                      
------------------------------------------------------------------------
0x0000                        0b0000000000010001       LDI R0, 1                                         
0x0001                        0b0000000000000100       OUT R0, 0                                         
0x0002                        0b0000000010111000       JMP FOO                                           
0x0003                        0b0000000000001011                                                         
0x000B         FOO:           0b0000000000010100       OUT R0, 1                                         
0x000C                        0b0000000011110000       HLT
```
