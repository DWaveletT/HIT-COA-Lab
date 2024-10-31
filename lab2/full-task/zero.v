module my_zero (
    input[31:0] R1,
    input[31:0] R2,
    input[31:0] IR,
    output is_jump,
    output do_jump
);
    assign is_jump = (IR[31:26] == 6'b111111) || (IR[31:26] == 6'b000010);
    assign do_jump = (IR[31:26] == 6'b111111 && R1[IR[20:16]]) || (IR[31:26] == 6'b000010);
        // 位测试或者无条件
endmodule