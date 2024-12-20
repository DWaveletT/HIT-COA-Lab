module cache (
    input            clk             ,  // 时钟
    input            resetn          ,  // 低有效复位信号

    //  Sram-Like 接口信号，用于 CPU 访问 Cache
    input             cpu_req      ,    // 由 CPU 发送至 Cache
    input      [31:0] cpu_addr     ,    // 由 CPU 发送至 Cache
    output reg [31:0] cache_rdata  ,    // 由 Cache 返回给 CPU
    output            cache_addr_ok,    // 由 Cache 返回给 CPU
    output reg        cache_data_ok,    // 由 Cache 返回给 CPU

    //  AXI接口信号，用于Cache访问主存
    output reg [3 :0] arid   ,          // Cache 向主存发起读请求时使用的 AXI 信道的 id 号
    output reg [31:0] araddr ,          // Cache 向主存发起读请求时所使用的地址
    output reg        arvalid,          // Cache 向主存发起读请求的请求信号
    input             arready,          // 读请求能否被接收的握手信号

    input      [3 :0] rid    ,          //主存向 Cache 返回数据时使用的 AXI 信道的 id 号
    input      [31:0] rdata  ,          //主存向 Cache 返回的数据
    input             rlast  ,          //是否是主存向 Cache 返回的最后一个数据
    input             rvalid ,          //主存向 Cache 返回数据时的数据有效信号
    output reg        rready            //标识当前的 Cache 已经准备好可以接收主存返回的数据
);

    // ======= IF1/IF2 =========
    
    wire[31:0] way0_rdata;
    wire[31:0] way1_rdata;
    reg[19:0]  way0_tag;
    reg[19:0]  way1_tag;
    reg        way0_valid;
    reg        way1_valid;
    reg        way0_replace;
    reg        way1_replace;
    reg[31:0]  req_addr;
    reg        flag, get;

    // =========================

    // ======== BRAMs ==========

    wire[9:0]  ram0_raddr;
    wire       ram0_ren;
    reg[9:0]   ram0_waddr;
    reg[31:0]  ram0_wdata;
    reg[0:0]   ram0_wen;

    wire[9:0]  ram1_raddr;
    wire       ram1_ren;
    reg[9:0]   ram1_waddr;
    reg[31:0]  ram1_wdata;
    reg[0:0]   ram1_wen;

    blk_mem_gen_0 ram0(
        .clka(clk),
        .clkb(clk),
        .addra(ram0_waddr),
        .addrb(ram0_raddr),
        .wea(ram0_wen),
        .enb(ram0_ren),
        .dina(ram0_wdata),
        .doutb(way0_rdata)
    );

    blk_mem_gen_0 ram1(
        .clka(clk),
        .clkb(clk),
        .addra(ram1_waddr),
        .addrb(ram1_raddr),
        .wea(ram1_wen),
        .enb(ram1_ren),
        .dina(ram1_wdata),
        .doutb(way1_rdata)
    );

    // =========================

    // CPU 发送数据请求时从 BRAM0 里面尝试获取
    assign ram0_ren = cpu_req && resetn && ~stall;
    assign ram1_ren = cpu_req && resetn && ~stall;

    // Tag 数组
    // [21] 是 replace
    // [20] 是 valid
    // [19:0] 是 tag
    reg[21:0] tags0[127:0];
    reg[21:0] tags1[127:0];

    genvar i;
    generate
        for(i = 0;i < 128;i = i + 1) begin
            initial begin
                tags0[i] <= 0;
                tags1[i] <= 0;
            end
        end
    endgenerate

    // 解析 CPU 传来的地址
    wire[19:0] tag;
    wire[ 6:0] ind;
    wire[ 4:0] off;

    assign tag = cpu_addr[31:12];
    assign ind = cpu_addr[11: 5];
    assign off = cpu_addr[ 4: 0];

    assign ram0_raddr = { ind, off[ 4: 2] };
    assign ram1_raddr = { ind, off[ 4: 2] };

    wire hit0, hit1;
    reg  finish;

    assign stall = flag && (~hit0 && ~hit1 && ~finish);

    // ========== IF1 ==========

    assign cache_addr_ok = ~stall && resetn;

    // =========================

    // ========== IF2 ==========

    reg[2:0] state;         // CPU 与主存数据通信时的状态

    wire[19:0] req_tag;
    wire[ 6:0] req_ind;
    wire[ 4:0] req_off;

    assign req_tag = req_addr[31:12];
    assign req_ind = req_addr[11: 5];
    assign req_off = req_addr[ 4: 0];

    assign hit0 = (way0_valid && way0_tag == req_tag);
    assign hit1 = (way1_valid && way1_tag == req_tag);
    assign override = !way1_valid || way1_replace;

    wire[9:0] nram0_waddr = ram0_waddr + 1;
    wire[9:0] nram1_waddr = ram1_waddr + 1;

    always @(posedge clk) begin
		if(resetn) begin
			if(~stall) begin
				way0_tag     <= tags0[ind][19:0];
				way1_tag     <= tags1[ind][19:0];
				way0_valid   <= tags0[ind][20];
				way1_valid   <= tags1[ind][20];
				way0_replace <= tags0[ind][21];
				way1_replace <= tags1[ind][21];
				req_addr     <= cpu_addr;
				flag         <= 1;
			end
			if(flag) begin
				case (state)
					0: begin    // 开始向 AR 请求数据

						if(hit0 || hit1) begin       // 命中
							cache_data_ok <= 1;
							cache_rdata   <= hit0 ? way0_rdata : way1_rdata;

							// 更新替换标记位
							tags0[req_ind][21] = hit1;
							tags1[req_ind][21] = hit0;
						end else begin              // 未命中
							arvalid <= 1;
							araddr  <= { req_tag, req_ind, 5'b00000 };
							arid    <= 0;

							cache_data_ok <= 0;     // 告诉 CPU 数据还没准备好

							if(override) begin  // 写入 1 路
								ram1_waddr <= { req_ind, 3'b000 } - 1;
								tags1[req_ind] <= { 1'b0, 1'b1, req_tag };
							end else begin      // 写入 0 路
								ram0_waddr <= { req_ind, 3'b000 } - 1;
								tags0[req_ind] <= { 1'b0, 1'b1, req_tag };
							end

							state <= 1;         // 进入地址握手状态
						end
					end
					1: begin
						if(arready) begin   // 握手成功，进入数据握手状态
							arvalid <= 0;
							rready  <= 1;
							state   <= 2;
						end
					end
					2: begin
						if(rvalid) begin
							if(override) begin      // 替换 1 路
								ram1_wen <= 1;
								ram1_wdata <= rdata;
								ram1_waddr <= nram1_waddr;

								if(nram1_waddr == { req_ind, req_off[ 4: 2] } ) begin
									cache_rdata <= rdata;
								end
							end else begin          // 替换 0 路
								ram0_wen <= 1;
								ram0_wdata <= rdata;
								ram0_waddr <= nram0_waddr;
								
								if(nram0_waddr == { req_ind, req_off[ 4: 2] } ) begin
									cache_rdata <= rdata;
								end
							end

							if(rlast) begin // 数据传输完毕
								rready <= 0;
								state  <= 3;

							end
						end
					end
					3: begin                // 花一帧时间等待 RAM 写入完毕
						ram0_wen <= 0;
						ram1_wen <= 0;
						finish <= 1;

						state <= 4;
					end
					4: begin                // 花一帧时间等待 RAM 读取地址 
						cache_data_ok <= 1;
						finish <= 0;

						state <= 0;
					end
				endcase
			end
		end else begin
			cache_data_ok <= 0;
			arvalid <= 0;
			rready  <= 0;
			way0_tag <= 0;
			way1_tag <= 0;
			way0_valid <= 0;
			way1_valid <= 0;
			way0_replace <= 0;
			way1_replace <= 0;
			req_addr <= 0;
			flag <= 0;
			get  <= 0;

			ram0_wen <= 0;
			ram1_wen <= 0;

			finish <= 0;
			state <= 0;
		end
    end
    // =========================

endmodule