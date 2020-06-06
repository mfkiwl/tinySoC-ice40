module control(input wire clk,
               input wire [15:0] iMemOut,
               input wire carryFlag,
               input wire zeroFlag,
               input wire negativeFlag,
               output reg [1:0] regFileSrc,
               output reg [3:0] regFileOutBSelect,
               output reg regFileWriteEnable,  
               output reg regFileIncPair,        
               output reg regFileDecPair,            
               output reg aluSrcASelect,
               output reg [1:0] aluSrcBSelect,
               output reg [3:0] aluMode,
               output reg [1:0] dMemDataSelect,
               output reg dMemAddressSelect,
               output reg dMemWriteEn,
               output reg dMemReadEn,
               output reg [1:0] statusRegSrcSelect,
               output reg flagEnable,
               output reg [2:0] iMemAddrSelect,
               output reg iMemReadEnable,
               output reg pcWriteEn
);

    reg [2:0] state;
    reg [2:0] nextState;
    always @(posedge clk) begin
        state <= nextState;
    end

    reg condition;
    always @(*) begin
        case(iMemOut[15:13])
        3'b000:    condition = 1'b1;
        3'b001:    condition = (carryFlag);
        3'b010:    condition = (~carryFlag);
        3'b011:    condition = (zeroFlag);
        3'b100:    condition = (~zeroFlag);
        3'b101:    condition = (negativeFlag);
        3'b110:    condition = (~negativeFlag);
        3'b111:    condition = 1'b1;
        endcase 
    end

    always @(*) begin
        if(state[0] == 1'b0) begin
            // [Type R-I]
            if(iMemOut[0] == 1'b1 && (iMemOut[3:1] < 3'b111)) begin
                regFileSrc = 2'b00;                 // aluOut
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect. Doesnt really matter
                regFileWriteEnable = 1'b1;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file
                aluSrcBSelect = 2'b10;              // From immediate 8-bit data
                aluMode = {0,iMemOut[3:1]};
                dMemDataSelect = 2'b10;             // aluOut
                dMemAddressSelect = 1'b0;           // {12'b0,iMemOut[15:12]}
                dMemWriteEn = 1'd0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b1;
                iMemAddrSelect = 3'b001;
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'd1;
                nextState = 3'b000;
            end
            // [Type R-L] : IN
            else if(iMemOut[2:0] == 3'b010) begin
                regFileSrc = 2'b00;                 // aluOut
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect. Doesnt really matter
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file. Doesnt really matter
                aluSrcBSelect = 2'b00;              // regFileOutB
                aluMode = 4'b0000;                  // Pass B
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b1;           // {8'd0,iMemOut[11:4]};
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b1;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut, pcPlusOne
                if(state[2:1] == 2'b00) begin
                    regFileWriteEnable = 1'b0;
                    iMemReadEnable = 1'b0;
                    pcWriteEn = 1'b0;
                    nextState = 3'b010;
                end
                else begin
                    regFileWriteEnable = 1'b1;
                    iMemReadEnable = 1'b1;
                    pcWriteEn = 1'b1;
                    nextState = 3'b000;
                end
            end
            // [Type R-L] : OUT
            else if(iMemOut[2:0] == 3'b100) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file
                aluSrcBSelect = 2'b00;              // regFileOutB
                aluMode = 4'b0000;                  // Pass B
                dMemDataSelect = 2'b10;             // aluOut
                dMemAddressSelect = 1'b1;           // {8'd0,iMemOut[11:4]};
                dMemWriteEn = 1'b1;
                dMemReadEn = 1'b1;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut, pcPlusOne
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
            // [Type R-R] and [Type R]
            else if(iMemOut[7:3] > 5'b00000 && iMemOut[7:3] < 5'b01101 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut
                regFileOutBSelect = iMemOut[11:8];  // SSSS, or in the case of Type R, just 0000
                regFileWriteEnable = 1'b1;
                regFileIncPair = 1'b0;            
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // regFileOutA
                aluSrcBSelect = 2'b00;              // regFileOutB
                aluMode = iMemOut[6:3];
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, but doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b1;
                iMemReadEnable = 1'b1;
                iMemAddrSelect = 3'b001;            // pcOut
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
            // [Type R-RP]
            else if(iMemOut[7:3] >= 5'b01101 && iMemOut[7:3] < 5'b10011 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                         // aluOut
                regFileOutBSelect = (iMemOut[11:9]*2);      // PPP
                regFileWriteEnable = iMemOut[7];
                aluSrcASelect = 1'b1;               // regFileOutA
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                  // Pass A
                dMemDataSelect = 2'b10;             // aluOut
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}
                dMemWriteEn = ~iMemOut[7];
                dMemReadEn = iMemOut[7];
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut
                if(~iMemOut[7]) begin
                    iMemReadEnable = 1'b1;
                    pcWriteEn = 1'b1;
                    nextState = 3'b000;
                end
                else begin
                    if(state == 3'b000) begin
                        iMemReadEnable = 1'b0;
                        pcWriteEn = 1'b0;
                        nextState = 3'b001;
                    end
                    else begin
                        iMemReadEnable = 1'b1;
                        pcWriteEn = 1'b1;
                        nextState = 3'b000;
                    end
                end
                if(iMemOut[7:3] == 01101 || iMemOut[7:3] == 10000) begin
                    regFileIncPair = 1'b0;
                    regFileDecPair = 1'b0;
                end
                else if(iMemOut[7:3] == 01110 || iMemOut[7:3] == 10001) begin
                    regFileIncPair = 1'b1;
                    regFileDecPair = 1'b0;
                end
                else begin
                    regFileIncPair = 1'b0;
                    regFileDecPair = 1'b1;
                end
            end
            // [Type RP]
            else if(iMemOut[7:3] == 5'b10011 || iMemOut[7:3] == 5'b10100 || iMemOut[7:3] == 5'b10101 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                         // aluOut, doesnt really matter
                regFileOutBSelect = (iMemOut[11:9]*2);      // PPP
                regFileWriteEnable = 1'b0;
                aluSrcASelect = 1'b1;                       // regFileOutA, doesnt really matter
                aluSrcBSelect = 2'b00;                      // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                          // Pass A, doesnt really matter
                dMemDataSelect = 2'b10;                     // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;                   // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b1;
                statusRegSrcSelect = 2'b00;                 // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                if(iMemOut[7:3] == 5'b10011) begin
                    regFileIncPair = 1'b1;
                    regFileDecPair = 1'b0;
                    iMemAddrSelect = 3'b001;                    // pcOut
                end
                else if(iMemOut[7:3] == 5'b10100) begin
                    regFileIncPair = 1'b0;
                    regFileDecPair = 1'b1;
                    iMemAddrSelect = 3'b001;                    // pcOut
                end
                else begin
                    regFileIncPair = 1'b0;
                    regFileDecPair = 1'b0;
                    if(condition) begin
                        iMemAddrSelect = 3'b100;                // {regFileOutC, regFileOutB}
                    end
                    else begin
                        iMemAddrSelect = 3'b001;                // pcOut
                    end
                end
                nextState = 1'b000;
            end
            // JMP
            else if(iMemOut[7:3] == 5'b10110) begin
                regFileSrc = 2'b00;                             // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12];             // same as inSelect
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b0;                           // From zero-extended status register
                aluSrcBSelect = 2'b00;                          // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                              // pass A
                dMemDataSelect = 2'b10;                         // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;                       // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;                     // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                if(condition) begin
                    iMemAddrSelect = 3'b001;                    // pcOut
                    nextState = 3'b001;
                end
                else begin
                    iMemAddrSelect = 3'b000;                    // pcPlusOne
                    nextState = 3'b000;
                end
            end
            // CALL
            else if(iMemOut[7:3] == 5'b10111 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = 4'b1110;        // lower SP reg
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file, doesnt really matter
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b0000;                  // Pass B, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, SP
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                dMemDataSelect = 2'b01;             // From LSBs of the PC
                iMemReadEnable = 1'b1;
                if(condition) begin                 // If the call condition is met
                    regFileDecPair = 1'b1;          // Deincrement the SP
                    dMemWriteEn = 1'b1;             // Write the LSBs of the PC to the stack
                    iMemAddrSelect = 3'b001;        // pcOut, read the address we need to jump to
                    pcWriteEn = 1'b0;               // Dont write to the PC because we still need to get the MSBs
                    nextState = 3'b010;
                end
                else begin                          // If the call condition is not met
                    regFileDecPair = 1'b0;
                    dMemWriteEn = 1'b0;
                    iMemAddrSelect = 3'b000;        // pcPlusOne
                    pcWriteEn = 1'b1;
                    nextState = 3'b000;
                end
            end
            // RET
            else if(iMemOut[7:3] == 5'b11000 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = 4'b1110;        // lower SP reg
                regFileWriteEnable = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b0000;                  // Pass B, doesnt really matter
                dMemDataSelect = 2'b10;             // aluOut
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, SP
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b1;                  // Pop the return address
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                if(state == 3'b000) begin
                    if(condition) begin
                        regFileIncPair = 1'b1;      // Increment the SP
                        iMemAddrSelect = 3'b011;    // iMemOut
                        iMemReadEnable = 1'b0;
                        pcWriteEn = 1'b0;
                        nextState = 3'b010;
                    end
                    else begin
                        regFileIncPair = 1'b0;
                        iMemReadEnable = 1'b1;
                        iMemAddrSelect = 3'b001;    // pcOut
                        pcWriteEn = 1'b1;
                        nextState = 3'b000;
                    end
                end
                else begin
                    regFileIncPair = 1'b1;          // Increment the SP
                    iMemAddrSelect = 3'b011;        // iMemOut
                    iMemReadEnable = 1'b1;
                    pcWriteEn = 1'b1;
                    nextState = 3'b000;
                end
            end
            // PUS
            else if(iMemOut[7:3] == 5'b11001 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = 4'b1110;        // lower SP reg
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b1;
                aluSrcASelect = 1'b0;               // From zero-extended status register
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                  // pass A
                dMemDataSelect = 2'b10;             // aluOut
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}
                dMemWriteEn = 1'b1;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
            // POS
            else if(iMemOut[7:3] == 5'b11010 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = 4'b1110;        // lower SP reg
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b1;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b0;               // From zero-extended status register, doesnt really matter
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                  // pass A
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b1;
                statusRegSrcSelect = 2'b10;         // dMemOut[3:0]
                flagEnable = 1'b1;
                iMemAddrSelect = 3'b001;            // pcOut
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
            // SSR and CSR
            else if(iMemOut[7:3] == 5'b11011 || iMemOut[7:3] == 5'b11100 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect. Doesnt really matter
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b0;               // From zero-extended status register
                aluSrcBSelect = 2'b01;              // {4'd0,iMemOut[11:8]}, immediate 4-bit mask
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b01;         // ALU output
                flagEnable = 1'b1;
                iMemAddrSelect = 3'b001;            // pcOut
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
                if(iMemOut[7:3] == 5'b1101) begin
                    aluMode = 4'b0010;  // OR
                end
                else begin
                    aluMode = 4'b0001;  // AND
                end
            end
            // HLT
            else if(iMemOut[7:3] == 5'b11101 && iMemOut[2:0] == 3'b000) begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect. Doesnt really matter
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // regFileOutA
                aluSrcBSelect = 2'b00;              // regFileOutB
                aluMode = 4'b0000;                  // Pass B, doesnt really matter
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut
                iMemReadEnable = 1'b0;
                pcWriteEn = 1'b0;
                nextState = 3'b000;
            end
            // NOP   
            else begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12]; // same as inSelect. Doesnt really matter
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b1;               // regFileOutA
                aluSrcBSelect = 2'b00;              // regFileOutB
                aluMode = 4'b0000;                  // Pass B, doesnt really matter
                dMemDataSelect = 2'b10;             // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;         // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b001;            // pcOut
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end     
        end
        else begin
            if(state == 3'b001) begin
                regFileSrc = 2'b00;                             // aluOut, doesnt really matter
                regFileOutBSelect = iMemOut[15:12];             // same as inSelect
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                regFileDecPair = 1'b0;
                aluSrcASelect = 1'b0;                           // From zero-extended status register
                aluSrcBSelect = 2'b00;                          // regFileOutB, doesnt really matter
                aluMode = 4'b1101;                              // pass A
                dMemDataSelect = 2'b10;                         // aluOut, doesnt really matter
                dMemAddressSelect = 1'b0;                       // {regFileOutC,regFileOutB}, doesnt really matter
                dMemWriteEn = 1'b0;
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;                     // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                iMemAddrSelect = 3'b011;                        // iMemOut
                iMemReadEnable = 1'b1;
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
            else begin
                regFileSrc = 2'b00;                 // aluOut, doesnt really matter
                regFileOutBSelect = 4'b1110;        // lower SP reg
                regFileWriteEnable = 1'b0;
                regFileIncPair = 1'b0;
                aluSrcASelect = 1'b1;               // From the register file, doesnt really matter
                aluSrcBSelect = 2'b00;              // regFileOutB, doesnt really matter
                aluMode = 4'b0000;                  // Pass B, doesnt really matter
                dMemAddressSelect = 1'b0;           // {regFileOutC,regFileOutB}, SP
                dMemReadEn = 1'b0;
                statusRegSrcSelect = 2'b00;                     // ALU flags out and save interrupt enable status
                flagEnable = 1'b0;
                dMemDataSelect = 2'b00;         // From MSBs of the PC
                iMemReadEnable = 1'b1;          // read the instruction at the address we call to
                regFileDecPair = 1'b1;          // Deincrement the SP
                dMemWriteEn = 1'b1;             // Write the MSBs of the PC to the stack
                iMemAddrSelect = 3'b011;        // iMemOut, the address of the place we call to
                pcWriteEn = 1'b1;
                nextState = 3'b000;
            end
        end
    end
endmodule