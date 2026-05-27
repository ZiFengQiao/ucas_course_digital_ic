/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 23:07:49
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-11 22:54:30
 * @Description: 超前进位加法器封装
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module add_tc_16_16 #(
    parameter DATA_WIDTH         = 32
) (
    input  wire [DATA_WIDTH-1:0] data_a,
    input  wire [DATA_WIDTH-1:0] data_b,
    output wire [DATA_WIDTH:0]   sum 
);

    // 扩展一位的超前进位加法器
    cla_adder #(
        .DATA_WIDTH    (DATA_WIDTH),
        .DATA_EXTEND   (1),
        .DATA_SIGNED   (1)
    ) u_cla_adder (
        .data_a        (data_a),
        .data_b        (data_b),
        .cin           (1'b0),
        .cout          (),
        .sum           (sum)
    );
endmodule
`resetall