module cpu(
    input           clk,                // 时钟信号
    input           resetn,             // 低有效复位信号

    output          inst_sram_en,       // 指令存储器读使能
    output[31:0]    inst_sram_addr,     // 指令存储器读地址
    input[31:0]     inst_sram_rdata,    // 指令存储器读出的数据

    output          data_sram_en,       // 数据存储器端口读/写使能
    output[3:0]     data_sram_wen,      // 数据存储器写使能
    output[31:0]    data_sram_addr,     // 数据存储器读/写地址
    output[31:0]    data_sram_wdata,    // 写入数据存储器的数据
    input[31:0]     data_sram_rdata,    // 数据存储器读出的数据

    // 供自动测试环境进行CPU正确性检查
    output[31:0]    debug_wb_pc,        // 当前正在执行指令的PC
    output          debug_wb_rf_wen,    // 当前通用寄存器组的写使能信号
    output[4:0]     debug_wb_rf_wnum,   // 当前通用寄存器组写回的寄存器编号
    output[31:0]    debug_wb_rf_wdata   // 当前指令需要写回的数据
);

    // ========== IF_ID =============
    reg[31:0] IF_ID_PC;

    wire[31:0] IF_ID_IR;
    wire[31:0] IF_ID_NP;
    wire[31:0] IF_ID_JP;
    // ==============================

    // ========== ID_EX =============
    reg[31:0] ID_EX_NP;
    reg[31:0] ID_EX_IR;
    reg[31:0] ID_EX_R1;
    reg[31:0] ID_EX_R2;
    reg[31:0] ID_EX_IM;
    reg[31:0] ID_EX_JP;
    reg[31:0] ID_EX_PC;
    // ==============================

    // ========== EX_MEM ============
    reg[31:0] EX_MEM_RS;
    reg[31:0] EX_MEM_RG;
    reg[31:0] EX_MEM_IR;
    reg[31:0] EX_MEM_PC;
    // ==============================

    // ========== MEM_WB ============
    reg[31:0]  MEM_WB_RS;
    reg[31:0]  MEM_WB_IR;
    wire[31:0] MEM_WB_MM;
    reg[31:0]  MEM_WB_PC;
    // ==============================

    // ========== 解决冲突 ===========
    wire stall;
    wire sig1_ex_mem_rs;
    wire sig1_mem_wb_mm;
    wire sig1_mem_wb_rs;
    wire sig2_ex_mem_rs;
    wire sig2_mem_wb_mm;
    wire sig2_mem_wb_rs;

    wire jump_test;
    wire[31:0] jump_address;

    wire is_jump;
    wire do_jump;
    // ==============================

    initial begin
        IF_ID_PC = -4;
    end

    // ============ IF ==============
    wire[31:0] nPC;

    assign inst_sram_en   = !stall && resetn;
    assign inst_sram_addr = nPC;

    my_predictor my_predictor(
        .clk(clk),
        .rst(rst),

        .is_jump(is_jump),
        .do_jump(do_jump),
        .jump_test(jump_test),
        .jump_address(jump_address),

        .ID_IR(IF_ID_IR),
        .EX_IR(ID_EX_IR),
        .ID_PC(IF_ID_PC),
        .EX_PC(ID_EX_PC),
        .nPC(nPC)
    );
    /*
        根据当前处于 ID 阶段的 IR 和 PC 值，预测下一个 PC 值。
        因为我们要榨干 CPU 的效率，于是在取得 IR 的时钟沿我们就得立即计算下一条指令
        的地址并且装进 inst_sram_addr 里面。于是 nPC 只能是组合逻辑实现。
        然而一开始的 inst_sram_addr 必须要为 0，IF_ID 里啥也没装所以不应该据此计算
        nPC。
        于是我们干脆把 IF_ID_PC 初始值赋值为 -4 算了。
    */

    assign IF_ID_IR = {32{resetn}} & inst_sram_rdata;
    assign IF_ID_JP = {32{resetn}} & nPC;
    assign IF_ID_NP = {32{resetn}} & (IF_ID_PC + 4);

    always @(posedge clk) begin
        if(!stall) begin    // 没有冲突信号再读取下一条
            IF_ID_PC <= resetn ? nPC : -4;
        end
    end
    // ==============================

    // ============ ID ==============

    conflict conflict(  // 组合逻辑检测是否有冲突信号
        .IR1( IF_ID_IR),
        .IR2( ID_EX_IR),
        .IR3(EX_MEM_IR),
        .IR4(MEM_WB_IR),
        .stall(stall),
        .sig1_ex_mem_rs(sig1_ex_mem_rs),
        .sig1_mem_wb_rs(sig1_mem_wb_rs),
        .sig1_mem_wb_mm(sig1_mem_wb_mm),
        .sig2_ex_mem_rs(sig2_ex_mem_rs),
        .sig2_mem_wb_rs(sig2_mem_wb_rs),
        .sig2_mem_wb_mm(sig2_mem_wb_mm)
    );

    wire          we;   // 寄存器堆读使能（写回使能）
    wire[ 5:0] waddr;   // 寄存器堆写地址
    wire[31:0] wdata;   // 寄存器堆写数据

    wire[31:0] regfile_rdata1;
    wire[31:0] regfile_rdata2;

    my_regfile my_regfile(
        .clk   (clk),
        .we    (we),
        .raddr1(IF_ID_IR[25:21]),
        .raddr2(IF_ID_IR[20:16]),
        .waddr (waddr),
        .wdata (wdata),
        .rdata1(regfile_rdata1),
        .rdata2(regfile_rdata2)
    );
    // 每个上升沿读入数据到 ID_EX.R1 和 ID_EX.R2 里

    wire[31:0] extend_imm;
    my_extend my_extend(
        .A     (IF_ID_IR[15: 0]),   // 低 16 位做符号扩展
        .B     (extend_imm)
    );

    always @(posedge clk) begin
        ID_EX_NP <= {32{resetn}} & IF_ID_NP;
        ID_EX_PC <= {32{resetn}} & IF_ID_PC;
        if (stall) begin    // 如果有冲突信号，先往后传 NOP
            ID_EX_IR <= 0;
            ID_EX_R1 <= 0;
            ID_EX_R2 <= 0;
            ID_EX_JP <= 0;
            ID_EX_IM <= 0;
        end else begin
            ID_EX_R1 <= {32{resetn & !jump_test}} & regfile_rdata1;
            ID_EX_R2 <= {32{resetn & !jump_test}} & regfile_rdata2;
            ID_EX_IR <= {32{resetn & !jump_test}} & IF_ID_IR;
            ID_EX_JP <= {32{resetn & !jump_test}} & IF_ID_JP;
            ID_EX_IM <= {32{resetn & !jump_test}} & extend_imm;
        end
    end
    // ==============================

    // ============ EX ==============
    wire[31:0] alu_a, reg_a;
    wire[31:0] alu_b, reg_b;

    assign reg_a =      // 检查是从 ID_EX.R1 里获取，还是定向获取
        sig1_ex_mem_rs ? EX_MEM_RS :
        sig1_mem_wb_rs ? MEM_WB_RS :
        sig1_mem_wb_mm ? MEM_WB_MM :
        ID_EX_R1;

    assign reg_b =      // 检查是从 ID_EX.R2 里获取，还是定向获取
        sig2_ex_mem_rs ? EX_MEM_RS :
        sig2_mem_wb_rs ? MEM_WB_RS :
        sig2_mem_wb_mm ? MEM_WB_MM :
        ID_EX_R2;

    wire mux1_select, mux2_select;

    my_mux EX_MUX1(
        .d0(ID_EX_NP),
        .d1(reg_a),
        .select(mux1_select),
        .out(alu_a)
    );  // 从 PC 和 R1 里选一个
    assign mux1_select =
        (ID_EX_IR[31:26] == 6'b000000) |    // 运算指令需要 R1
        (ID_EX_IR[31:26] == 6'b101011) |    // 存数指令需要 R1
        (ID_EX_IR[31:26] == 6'b100011) |    // 取数指令需要 R1
        (ID_EX_IR[31:26] == 6'b111110);

    my_mux EX_MUX2(
        .d0(ID_EX_IM),
        .d1(reg_b),
        .select(mux2_select),
        .out(alu_b)
    );  // 从 R2 和 IM 里选一个
    assign mux2_select =
        (ID_EX_IR[31:26] == 6'b000000) |    // 运算指令需要 R2
        (ID_EX_IR[31:26] == 6'b111110);     // 比较指令需要 R2

    wire[31:0] alu_result;
    wire[ 5:0] alu_card = 
        ({6{ID_EX_IR[31:26] == 6'b000000}} & ID_EX_IR[5:0]) |     // 运算操作运算码为后五位
        ({6{ID_EX_IR[31:26] == 6'b111110}} & 6'b111110)  |     // 比较指令特殊指定操作码
        ({6{ID_EX_IR[31:26] == 6'b101011}} & 6'b100000)  |     // 存数指令做加法
        ({6{ID_EX_IR[31:26] == 6'b100011}} & 6'b100000);       // 取数指令做加法
    my_alu EX_ALU(      // 选出来的结果做运算
        .A(alu_a),
        .B(alu_b),
        .F(alu_result),
        .Shft(ID_EX_IR[10: 6]),
        .Card(alu_card)
    );
    
    my_zero my_zero(
        .R1(reg_a),     // 注意可能需要定向获取
        .R2(reg_b),
        .IR(ID_EX_IR),
        .is_jump(is_jump),
        .do_jump(do_jump)
    );

    assign jump_address =
        do_jump ? (
            ({32{ID_EX_IR[31:26] == 6'b000010}} & { ID_EX_NP[31:28], ID_EX_IR[25:0], 2'b00 }) |
            ({32{ID_EX_IR[31:26] == 6'b111111}} & ((ID_EX_IM << 2) + ID_EX_NP))
        ) : ID_EX_NP;
    
    assign jump_test = is_jump && (jump_address != ID_EX_JP);
        // 如果跳转地址和实际地址不同，则预测不符，需要清空 ID 里的指令

    always @(posedge clk) begin
        EX_MEM_RG <= {32{resetn}} & reg_b;
        EX_MEM_IR <= {32{resetn}} & (
            {32{!(ID_EX_IR[31:26] == 6'b000000 && ID_EX_IR[5:0] == 6'b001010 && reg_b != 0)}}
        ) & ID_EX_IR;
            // 如果是 MOVZ 指令并且 R2 为 0 就不继续执行
        EX_MEM_RS <= {32{resetn}} & (
            ({32{ID_EX_IR[31:26] == 6'b000000}} & alu_result) |  // 运算指令使用 ALU
            ({32{ID_EX_IR[31:26] == 6'b100011}} & alu_result) |  // 取数指令使用 ALU
            ({32{ID_EX_IR[31:26] == 6'b101011}} & alu_result) |  // 存数指令使用 ALU
            ({32{ID_EX_IR[31:26] == 6'b111110}} & alu_result)    // 比较指令使用 ALU
        );

        EX_MEM_PC <= {32{resetn}} & ID_EX_PC;
    end
    // ==============================

    // =========== MEM ==============
    assign data_sram_addr  = EX_MEM_RS;     // 写地址为运算结果
    assign data_sram_wdata = EX_MEM_RG;     // 写数据为寄存器值
    assign data_sram_wen   = EX_MEM_IR[31:26] == 6'b101011;     // 只有存数指令写存
    assign data_sram_en    =
        (EX_MEM_IR[31:26] == 6'b100011) |       // 取数指令访存
        (EX_MEM_IR[31:26] == 6'b101011);        // 存数指令访存
    
    assign MEM_WB_MM = {32{resetn}} & data_sram_rdata;
    // 在下个上升沿才能从 SRAM 里面读出数据
        
    always @(posedge clk) begin
        MEM_WB_IR <= {32{resetn}} & EX_MEM_IR;
        MEM_WB_RS <= {32{resetn}} & EX_MEM_RS;
        
        MEM_WB_PC <= {32{resetn}} & EX_MEM_PC;
    end
    // ==============================

    // ============ WB ==============
    wire mux3_select;

    my_mux WB_MUX(
        .d0(MEM_WB_RS),         // 读结果
        .d1(MEM_WB_MM),         // 读内存
        .select(mux3_select),
        .out(wdata)
    );
    assign waddr =
        ({32{MEM_WB_IR[31:26] == 6'b100011}} & MEM_WB_IR[20:16]) |  // 取数指令写回 IR[20:16]
        ({32{MEM_WB_IR[31:26] == 6'b000000}} & MEM_WB_IR[15:11]) |  // 运算指令写回 IR[15:11]
        ({32{MEM_WB_IR[31:26] == 6'b111110}} & MEM_WB_IR[15:11]);   // 比较指令写回 IR[15:11]
    assign mux3_select =
        (MEM_WB_IR[31:26] == 6'b100011);        // 只有取数指令写回访存结果
    assign we =
        ((MEM_WB_IR[31:26] == 6'b000000) |      // 运算指令要写回
         (MEM_WB_IR[31:26] == 6'b100011) |      // 取数指令要写回
         (MEM_WB_IR[31:26] == 6'b111110) ) &    // 比较指令要写回
        (waddr != 0);                           // 不能写入 r0 寄存器
    // ==============================

    assign debug_wb_pc = MEM_WB_PC;         // 写回的 PC 值
    assign debug_wb_rf_wen   = we;          // 写回使能
    assign debug_wb_rf_wnum  = waddr;       // 写回地址
    assign debug_wb_rf_wdata = wdata;       // 写回数据

endmodule