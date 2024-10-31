module my_predictor (
    input clk,
    input rst,

    input jump_test,
    input is_jump,
    input do_jump,
    input[31:0] jump_address,

    input[31:0] ID_IR,      // 正在 ID 阶段的 IR
    input[31:0] EX_IR,      // 正在 EX 阶段的 IR
    input[31:0] ID_PC,      // 正在 ID 阶段的 PC
    input[31:0] EX_PC,      // 正在 EX 阶段的 PC

    output[31:0] nPC
);
    reg[65:0] BBT[63:0];
    // [31:00]: old PC
    // [63:32]: new PC
    // [65:64]: status (00 / 01 / 10 / 11)

    integer i;
    initial begin
        for(i = 0;i < 64;i = i + 1) begin
            BBT[i] = 0;
        end
    end
    
    wire ID_jump_inst = (ID_IR[31:26] == 6'b111111 || ID_IR[31:26] == 6'b000010);   // 是跳转指令
    wire EX_jump_inst = is_jump;                                                    // 是跳转指令
    
    wire predict_success =
        ID_jump_inst && BBT[ID_PC[7:2]][31: 0] == ID_PC && (
            BBT[ID_PC[7:2]][65:64] == 2'b11 ||
            BBT[ID_PC[7:2]][65:64] == 2'b10
        );

    always @(posedge clk) begin
        if(!rst) begin                                  // 重置
            for(i = 0;i < 64;i = i + 1) begin
                BBT[i] <= 0;
            end
        end else 
        if(EX_jump_inst) begin                   // 根据 EX 内的指令更新表

            if(BBT[EX_PC[7:2]][31: 0] != EX_PC) begin   // 第一次碰到，初始化
                BBT[EX_PC[7:2]][31: 0] <= EX_PC;
                BBT[EX_PC[7:2]][63:32] <= jump_address;
                BBT[EX_PC[7:2]][65:64] <= 2'b00;        // 初始默认失败
            end else begin
                if(!do_jump) begin                      // 跳转失败
                    case (BBT[EX_PC[7:2]][65:64])
                        // 2'b00: BBT[EX_PC[7:2]][65:64] <= 2'b00;
                        2'b01: BBT[EX_PC[7:2]][65:64] <= 2'b00;
                        2'b10: BBT[EX_PC[7:2]][65:64] <= 2'b01;
                        2'b11: BBT[EX_PC[7:2]][65:64] <= 2'b10;
                    endcase
                    BBT[EX_PC[7:2]][63:32] <= jump_address;
                                        // 更新正确的跳转地址
                    
                end else begin                          // 跳转成功
                    case (BBT[EX_PC[7:2]][65:64])
                        2'b00: BBT[EX_PC[7:2]][65:64] <= 2'b01;
                        2'b01: BBT[EX_PC[7:2]][65:64] <= 2'b10;
                        2'b10: BBT[EX_PC[7:2]][65:64] <= 2'b11;
                        // 2'b11: BBT[EX_PC[7:2]][65:64] <= 2'b11;
                    endcase
                end
            end
        end
    end

    assign nPC = jump_test ? jump_address : ( predict_success ? BBT[ID_PC[7:2]][63:32] : ID_PC + 4 );
endmodule