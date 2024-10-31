`define ADD     6'b100000       // 加
`define SUB     6'b100010       // 减
`define AND     6'b100100       // 与
`define OR      6'b100101       // 或
`define XOR     6'b100110       // 异或
`define MOVZ    6'b001010       // 条件移动
`define SLL     6'b000000       // 移位
`define CMP     6'b111110       // 比较

module my_alu(
    input [31:0] A,     // 输入 A
    input [31:0] B,     // 输入 B
    input [5:0] Card,   // 操作指令
    input [4:0] Shft,    // 移位指令
    output [31:0] F     // 输出 F
    );
    
    wire [31:0]  add_result = A + B;
    wire [31:0]  sub_result = A - B;
    wire [31:0]  and_result = A & B;
    wire [31:0]   or_result = A | B;
    wire [31:0]  xor_result = A ^ B;
    wire [31:0] movz_result = A;
    wire [31:0]  sll_result = B << Shft;

    wire [31:0]  cmp_result = {
        22'b0,
        !(A <= B),
        !($signed(A) <= $signed(B)),
        !(A <  B),
        !($signed(A) <  $signed(B)),
        !(A == B),
        A <= B,
        $signed(A) <= $signed(B),
        A <  B,
        $signed(A) <  $signed(B),
        A == B
    };
    // wire [31:0] cmp_result = { A[15:0], B[15:0] };

    assign F =
        ({32{Card ==  `ADD}} &  add_result) |
        ({32{Card ==  `SUB}} &  sub_result) |
        ({32{Card ==  `AND}} &  and_result) |
        ({32{Card ==   `OR}} &   or_result) |
        ({32{Card ==  `XOR}} &  xor_result) |
        ({32{Card == `MOVZ}} & movz_result) |
        ({32{Card ==  `SLL}} &  sll_result) |
        ({32{Card ==  `CMP}} &  cmp_result);
endmodule
