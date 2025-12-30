/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 21:56:52
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-29 11:38:21
 * @Description: 8x8 Matrix Zigzag Scan Module
 *               Serial input -> Buffer -> Zigzag output via ROM address mapping
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module mat_scan #(
    parameter  DATA_WIDTH         = 10,
    parameter  MAT_N              = 8
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   vld_in,
    input  wire  [DATA_WIDTH-1:0] din,
    output wire                   vld_out,
    output wire  [DATA_WIDTH-1:0] dout
);

    // ========================================================================
    // 参数定义
    // ========================================================================
    localparam DATA_NUM   = MAT_N * MAT_N;
    localparam ADDR_WIDTH = $clog2(DATA_NUM);

    // 状态机状态
    localparam S_IDLE  = 2'b00;
    localparam S_WRITE = 2'b01;
    localparam S_READ  = 2'b10;

    // ========================================================================
    // Zigzag 地址映射 ROM
    // 计算 Zigzag 地址

    reg [ADDR_WIDTH-1:0] zigzag_addr [0:DATA_NUM-1];
    integer i, x, y;
    initial begin
        x = 0; y = 0;
        for (i = 0; i < DATA_NUM; i = i + 1) begin
            zigzag_addr[i] = y * MAT_N + x; // 将二维坐标转为线性地址
            
            // 判断当前的坐标和 (x+y) 是偶数还是奇数
            if ((x + y) % 2 == 0) begin
                // 偶数向上移动 (右上)
                if (x == MAT_N-1) begin
                    y = y + 1; // 碰到右边界，向下移                    
                end
                else if (y == 0) begin
                    x = x + 1; // 碰到上边界，向右移                    
                end
                else begin
                    x = x + 1;
                    y = y - 1;
                end
            end 
            else begin
                // 奇数向下移动 (左下)
                if (y == MAT_N-1) begin
                    x = x + 1; // 碰到下边界，向右移
                end
                else if (x == 0) begin
                    y = y + 1; // 碰到左边界，向下移
                end
                else begin
                    x = x - 1;
                    y = y + 1;
                end
            end
        end

        // 打印结果验证
        for (i = 0; i < 64; i = i + 1) begin
            $display("Index %d -> Addr %d", i, zigzag_addr[i]);
        end
    end

    // ========================================================================
    // 状态机
    reg [1:0] st_curr;
    reg [1:0] st_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st_curr <= S_IDLE;
        end else begin
            st_curr <= st_next;
        end
    end

    // 数据缓存，SRAM
    (* ramstyle = "block" *)
    reg [DATA_WIDTH-1:0] data_buf [0:DATA_NUM-1];
    reg                  data_buf_wr_en;          // 写使能
    reg [ADDR_WIDTH-1:0] data_buf_wr_ptr_q;
    reg [ADDR_WIDTH-1:0] data_buf_wr_ptr_d;

    reg                  data_buf_rd_en;          // 读使能
    reg [ADDR_WIDTH-1:0] data_buf_rd_ptr_q;
    reg [ADDR_WIDTH-1:0] data_buf_rd_ptr_d;

    // 状态机转移逻辑
    always @(*) begin
        st_next = st_curr;
        case (st_curr)
            S_IDLE: begin
                data_buf_wr_en = 1'b0;
                data_buf_wr_ptr_d = 'd0;

                data_buf_rd_en = 1'b0;
                data_buf_rd_ptr_d = 'd0;

                if (vld_in) begin
                    // 写一拍数据
                    st_next = S_WRITE;
                    
                    data_buf_wr_ptr_d = 'd1;
                    data_buf_wr_en    = 1'b1;
                end
                else begin
                    st_next = S_IDLE;
                end
            end
            S_WRITE: begin
                data_buf_wr_en = 1'b1;
                data_buf_wr_ptr_d = data_buf_wr_ptr_q;

                data_buf_rd_en = 1'b0;
                data_buf_rd_ptr_d = 'd0;

                if (vld_in) begin
                    data_buf_wr_ptr_d = data_buf_wr_ptr_q + 1;

                    if (data_buf_wr_ptr_q == DATA_NUM - 1) begin
                        // 写满，转读状态
                        st_next = S_READ;

                        // 写最后一拍数据，清空写指针
                        data_buf_wr_ptr_d = 'd0;

                        // 读数据，更新读指针
                        data_buf_rd_en    = 1'b1;
                        data_buf_rd_ptr_d = 'd1;
                    end
                    else begin
                        st_next = S_WRITE;
                    end
                end
            end
            S_READ: begin
                data_buf_wr_en = 1'b0;
                data_buf_wr_ptr_d = 'd0;

                data_buf_rd_en = 1'b1;
                data_buf_rd_ptr_d = data_buf_rd_ptr_q + 1;
                
                if (data_buf_rd_ptr_q == DATA_NUM - 1) begin
                    // 最后一拍，清空读指针
                    data_buf_rd_ptr_d = 'd0;

                    if (vld_in) begin
                        // 读完且有新数据，转写状态
                        // 其实该配合vld, rdy使用
                        st_next = S_WRITE;
                        
                        data_buf_wr_en    = 1'b1;
                        data_buf_wr_ptr_d = 'd1;
                    end
                    else begin
                        st_next = S_IDLE;
                    end
                end
                else begin
                    st_next = S_READ;
                end
            end
            default: begin
                st_next = S_IDLE;

                data_buf_wr_en    = 1'b0;
                data_buf_wr_ptr_d = 'd0;
                data_buf_rd_en    = 1'b0;
                data_buf_rd_ptr_d = 'd0;
            end
        endcase
    end

    // ========================================================================
    // 写指针时序逻辑
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buf_wr_ptr_q <= {ADDR_WIDTH{1'b0}};
        end else begin
            data_buf_wr_ptr_q <= data_buf_wr_ptr_d;
        end
    end

    // ========================================================================
    // 读指针时序逻辑
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buf_rd_ptr_q <= {ADDR_WIDTH{1'b0}};
        end else begin
            data_buf_rd_ptr_q <= data_buf_rd_ptr_d;
        end
    end

    // ========================================================================
    // 数据缓存写入逻辑
    // ========================================================================
    always @(posedge clk) begin
        if (data_buf_wr_en) begin
            data_buf[data_buf_wr_ptr_q] <= din;
        end
    end

    // ========================================================================
    // 输出逻辑
    // ========================================================================
    reg                   vld_out_q;
    reg [DATA_WIDTH-1:0]  dout_q;

    // Zigzag 读取地址
    wire [ADDR_WIDTH-1:0] rd_addr;
    assign rd_addr = zigzag_addr[data_buf_rd_ptr_q];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vld_out_q <= 1'b0;
        end else begin
            vld_out_q <= data_buf_rd_en;
        end
    end

    always @(posedge clk) begin
        if (data_buf_rd_en) begin
            dout_q <= data_buf[rd_addr];
        end
    end

    assign vld_out = vld_out_q;
    assign dout    = dout_q;

    // ========================================================================
    // 调试信息
    // ========================================================================
    initial begin
        $display("================================================================================");
        $display("[mat_scan] Configuration:");
        $display("[mat_scan]   DATA_WIDTH = %0d bits", DATA_WIDTH);
        $display("[mat_scan]   MAT_N   = %0d x %0d", MAT_N, MAT_N);
        $display("[mat_scan]   DATA_NUM   = %0d elements", DATA_NUM);
        $display("[mat_scan]   Latency    = %0d cycles (write) + %0d cycles (read)", DATA_NUM, DATA_NUM);
        $display("================================================================================");
    end

endmodule
`resetall