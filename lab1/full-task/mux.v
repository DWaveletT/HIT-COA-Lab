module my_mux(
    input[31:0] d0,
    input[31:0] d1,
    input select,
    output[31:0] out
);
    assign out = select ? d1 : d0;
endmodule