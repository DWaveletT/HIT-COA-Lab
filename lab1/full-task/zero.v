module my_zero (
    input[31:0] R1,
    input[31:0] R2,
    input[31:0] IR,
    output J
);
    assign J = (IR[31:26] == 6'b111111 && R1[R2]) | (IR[31:26] == 6'b000010);
        // 位测试或者无条件
endmodule