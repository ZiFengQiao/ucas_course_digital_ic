/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 23:07:49
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-12 00:28:10
 * @Description: 超前进位加法器封装
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module add_tc_16_16_clk #(
    parameter DATA_WIDTH         = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [DATA_WIDTH-1:0] data_a,
    input  wire [DATA_WIDTH-1:0] data_b,
    output wire [DATA_WIDTH:0]   sum 
);

    // 扩展一位的超前进位加法器
    // 输入/输出寄存器
    // 将 module 的 data_a/data_b 寄存后送入加法器，
    // 并对加法器输出做一级寄存，形成同步接口
    reg  [DATA_WIDTH-1:0] data_a_r;
    reg  [DATA_WIDTH-1:0] data_b_r;
    wire [DATA_WIDTH:0]   sum_w;
    reg  [DATA_WIDTH:0]   sum_r;

    // 实例化加法器，使用寄存后的输入
    cla_adder #(
        .DATA_WIDTH    (DATA_WIDTH),
        .DATA_EXTEND   (1),
        .DATA_SIGNED   (1)
    ) u_cla_adder (
        .data_a        (data_a_r),
        .data_b        (data_b_r),
        .cin           (1'b0),
        .cout          (),
        .sum           (sum_w)
    );

    // 同步寄存 inputs 和输出
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_a_r <= {DATA_WIDTH{1'b0}};
            data_b_r <= {DATA_WIDTH{1'b0}};
            sum_r    <= {(DATA_WIDTH+1){1'b0}};
        end else begin
            data_a_r <= data_a;
            data_b_r <= data_b;
            sum_r    <= sum_w;
        end
    end

    // 输出为寄存后的和
    assign sum = sum_r;
endmodule
`resetall