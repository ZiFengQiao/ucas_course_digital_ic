/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-15 00:44:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-08 17:05:58
 * @Description: booth乘法器, 16x16位补码乘法
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module mul_tc_16_16 #(
    parameter DATA_WIDTH            = 16,
    parameter PRODUCT_WIDTH         = 2 * DATA_WIDTH
) (
    input  wire [DATA_WIDTH-1:0]    a,
    input  wire [DATA_WIDTH-1:0]    b,
    output wire [PRODUCT_WIDTH-1:0] product
);

    // booth乘法器
    booth_multi #(
        .DATA_WIDTH       (DATA_WIDTH)
    ) u_booth_multi (
        .data_a           (a),
        .data_b           (b),
        .product          (product)
    );
endmodule
`resetall