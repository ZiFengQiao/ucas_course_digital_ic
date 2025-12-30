/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 15:36:46
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-28 15:56:45
 * @Description: Unsigned 32-bit Square Root Module
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module sqrt_u32 #(
    parameter DATA_WIDTH          = 32,
    parameter OUT_WIDTH           = DATA_WIDTH / 2
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   vld_in,
    input  wire  [DATA_WIDTH-1:0] x,
    output wire                   vld_out,
    output wire  [15:0]           y
);

    // 二进制逐位平方根算法
    // 对于32位输入，需要16次迭代，每次处理2位
    localparam ITER_NUM = OUT_WIDTH;  // 16次迭代

    // 流水线寄存器
    reg  [DATA_WIDTH-1:0] x_reg      [0:ITER_NUM-1];  // 输入数据寄存器
    reg  [OUT_WIDTH-1:0]  y_reg      [0:ITER_NUM-1];  // 结果寄存器
    reg  [DATA_WIDTH+1:0] rem_reg    [0:ITER_NUM-1];  // 余数寄存器 (需要额外2位)
    reg  [ITER_NUM-1:0]   vld_reg;                    // 有效信号流水线

    // 中间变量
    wire [DATA_WIDTH+1:0] rem_shift  [0:ITER_NUM-1];  // 移位后的余数
    wire [DATA_WIDTH+1:0] test_val   [0:ITER_NUM-1];  // 测试值
    wire                  cmp_result [0:ITER_NUM-1];  // 比较结果

    // 生成16级流水线
    genvar i;
    generate
        for (i = 0; i < ITER_NUM; i = i + 1) begin : gen_pipeline
            // 移位后的余数: 将上一级余数左移2位，并加入x的下两位
            if (i == 0) begin : gen_first_stage
                // 第一级：从x的最高2位开始
                assign rem_shift[i] = {32'b0, x[DATA_WIDTH-1:DATA_WIDTH-2]};
            end
            else begin : gen_other_stage
                // 其他级：余数左移2位，加入x的下两位
                assign rem_shift[i] = {rem_reg[i-1][DATA_WIDTH-1:0], x_reg[i-1][DATA_WIDTH-1-2*i -: 2]};
            end

            // 测试值: (y << 1) | 1，左移OUT_WIDTH位后加1
            // test_val = (y_reg << (OUT_WIDTH + 1)) | (1 << (OUT_WIDTH - i - 1))
            // 简化为: {y_reg, 01} 左对齐到当前位置
            if (i == 0) begin : gen_test_first
                assign test_val[i] = {{(DATA_WIDTH){1'b0}}, 2'b01};
            end
            else begin : gen_test_other
                assign test_val[i] = {{(DATA_WIDTH-2*i){1'b0}}, y_reg[i-1][i-1:0], 2'b01};
            end

            // 比较: 余数 >= 测试值
            assign cmp_result[i] = (rem_shift[i] >= test_val[i]);

            // 流水线寄存器更新
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_reg[i]   <= {DATA_WIDTH{1'b0}};
                    y_reg[i]   <= {OUT_WIDTH{1'b0}};
                    rem_reg[i] <= {(DATA_WIDTH+2){1'b0}};
                end
                else begin
                    if (i == 0) begin
                        // 第一级
                        if (vld_in) begin
                            x_reg[i] <= x;
                            if (cmp_result[i]) begin
                                y_reg[i]   <= {{(OUT_WIDTH-1){1'b0}}, 1'b1};
                                rem_reg[i] <= rem_shift[i] - test_val[i];
                            end
                            else begin
                                y_reg[i]   <= {OUT_WIDTH{1'b0}};
                                rem_reg[i] <= rem_shift[i];
                            end
                        end
                    end
                    else begin
                        // 其他级
                        if (vld_reg[i-1]) begin
                            x_reg[i] <= x_reg[i-1];
                            if (cmp_result[i]) begin
                                y_reg[i]   <= {y_reg[i-1][OUT_WIDTH-2:0], 1'b1};
                                rem_reg[i] <= rem_shift[i] - test_val[i];
                            end
                            else begin
                                y_reg[i]   <= {y_reg[i-1][OUT_WIDTH-2:0], 1'b0};
                                rem_reg[i] <= rem_shift[i];
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    // 有效信号流水线
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vld_reg <= {ITER_NUM{1'b0}};
        end
        else begin
            vld_reg <= {vld_reg[ITER_NUM-2:0], vld_in};
        end
    end

    // 输出赋值
    assign vld_out = vld_reg[ITER_NUM-1];
    assign y       = y_reg[ITER_NUM-1];
endmodule
`resetall