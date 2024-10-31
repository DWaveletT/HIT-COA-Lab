module my_regfile (
    input clk,
    input we,
    input [4:0] raddr1,
    input [4:0] raddr2,
    input [4:0] waddr ,
    output [31:0] rdata1,
    output [31:0] rdata2,
    input [31:0] wdata
);
    reg [31:0] data[0:31];

    integer i;

    initial begin
        for(i = 0;i < 32;i = i + 1) begin
            data[i] <= 0;
        end
    end

    always @(posedge clk) begin
        if(we) begin
            data[waddr] <= wdata;
        end
    end
    assign rdata1 = waddr == raddr1 ? wdata : data[raddr1];
    assign rdata2 = waddr == raddr2 ? wdata : data[raddr2];
endmodule