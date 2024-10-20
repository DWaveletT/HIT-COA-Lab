module conflict (
    input[31:0] IR1,    // 当前条指令，IF/ID
    input[31:0] IR2,    // 上一条指令，ID/EX
    input[31:0] IR3,    // 上二条指令，EX/MEM
    input[31:0] IR4,    // 上三条指令，MEM/WB
    output stall,
    output sig1_ex_mem_rs,
    output sig1_mem_wb_rs,
    output sig1_mem_wb_mm,
    output sig2_ex_mem_rs,
    output sig2_mem_wb_rs,
    output sig2_mem_wb_mm
);
    // 暂停
    assign stall =
        (IR2[31:26] == 6'b100011 && (IR1[31:26] == 6'b000000 || IR1[31:26] == 6'b111110) && IR2[20:16] == IR1[25:21]) |
        (IR2[31:26] == 6'b100011 && (IR1[31:26] == 6'b000000 || IR1[31:26] == 6'b111110) && IR2[20:16] == IR1[20:16]) |
        (IR2[31:26] == 6'b100011 && IR2[20:16] == IR1[25:21]);
    
    // 从 EX/MEM.RS 定向替代 ID/EX.R1
    assign sig1_ex_mem_rs = (IR2[25:21] != 5'b00000) &&
        (IR3[31:26] == 6'b000000 && IR2[25:21] == IR3[15:11]) | // 运算指令
        (IR3[31:26] == 6'b111110 && IR2[25:21] == IR3[15:11]);  // 比较指令

    // 从 EX/MEM.RS 定向替代 ID/EX.R2
    assign sig2_ex_mem_rs = (IR2[20:16] != 5'b00000) &&
        (IR3[31:26] == 6'b000000 && IR2[20:16] == IR3[15:11]) | // 运算指令
        (IR3[31:26] == 6'b111110 && IR2[20:16] == IR3[15:11]);  // 比较指令
    
    // 从 EX/MEM.RS 定向替代 ID/EX.R1
    assign sig1_mem_wb_rs = (IR2[25:21] != 5'b00000) &&
        (IR4[31:26] == 6'b000000 && IR2[25:21] == IR4[15:11]) | // 运算指令
        (IR4[31:26] == 6'b111110 && IR2[25:21] == IR4[15:11]);  // 比较指令

    // 从 EX/MEM.RS 定向替代 ID/EX.R2
    assign sig2_mem_wb_rs = (IR2[20:16] != 5'b00000) &&
        (IR4[31:26] == 6'b000000 && IR2[20:16] == IR4[15:11]) | // 运算指令
        (IR4[31:26] == 6'b111110 && IR2[20:16] == IR4[15:11]);  // 比较指令

    // 从 EX/MEM.MM 定向替代 ID/EX.R1
    assign sig1_mem_wb_mm = (IR2[25:21] != 5'b00000) &&
        (IR4[31:26] == 6'b100011 && IR2[25:21] == IR4[20:16]);  // 取数指令

    // 从 EX/MEM.MM 定向替代 ID/EX.R2
    assign sig2_mem_wb_mm = (IR2[20:16] != 5'b00000) &&
        (IR4[31:26] == 6'b100011 && IR2[20:16] == IR4[20:16]);  // 取数指令
endmodule