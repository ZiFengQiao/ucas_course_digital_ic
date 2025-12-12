/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-17 15:45:21
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-07 23:41:46
 * @Description: 4-bit Carry Out Logic
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module cla_c4 #(
) (
    input  wire [3:0]   i_p,
    input  wire [3:0]   i_g,
    input  wire         i_cin,
    output wire         o_p,
    output wire         o_g,
    output wire [2:0]   o_cout
);
    // 进位传递输出
    assign o_p = &i_p;
    // 进位生成输出
    assign o_g = i_g[3] | (i_p[3] & i_g[2]) | (i_p[3] & i_p[2] & i_g[1]) | (i_p[3] & i_p[2] & i_p[1] & i_g[0]);
    // 各级进位输出
    assign o_cout[0] = i_g[0] | (i_p[0] & i_cin);
    assign o_cout[1] = i_g[1] | (i_p[1] & i_g[0]) | (i_p[1] & i_p[0] & i_cin);
    assign o_cout[2] = i_g[2] | (i_p[2] & i_g[1]) | (i_p[2] & i_p[1] & i_g[0]) | (i_p[2] & i_p[1] & i_p[0] & i_cin);
endmodule
`resetall