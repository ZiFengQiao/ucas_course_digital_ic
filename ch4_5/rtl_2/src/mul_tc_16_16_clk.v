/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-15 00:44:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-12 00:40:51
 * @Description: booth乘法器, 16x16位补码乘法
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module mul_tc_16_16_clk #(
    parameter DATA_WIDTH            = 16,
    parameter PRODUCT_WIDTH         = 2 * DATA_WIDTH
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire [DATA_WIDTH-1:0]    a,
    input  wire [DATA_WIDTH-1:0]    b,
    output wire [PRODUCT_WIDTH-1:0] product
);

    // booth乘法器
    // 输入/输出寄存器
    reg  [DATA_WIDTH-1:0]    a_r;
    reg  [DATA_WIDTH-1:0]    b_r;
    wire [PRODUCT_WIDTH-1:0] product_w;
    reg  [PRODUCT_WIDTH-1:0] product_r;

    // 使用寄存的输入驱动 booth 乘法器，输出再寄存
    booth_multi #(
        .DATA_WIDTH       (DATA_WIDTH)
    ) u_booth_multi (
        .data_a           (a_r),
        .data_b           (b_r),
        .product          (product_w)
    );

    // 同步寄存 inputs 和输出
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_r <= {DATA_WIDTH{1'b0}};
            b_r <= {DATA_WIDTH{1'b0}};
            product_r <= {PRODUCT_WIDTH{1'b0}};
        end else begin
            a_r <= a;
            b_r <= b;
            product_r <= product_w;
        end
    end

    // 输出为寄存后的product
    assign product = product_r;
endmodule
`resetall