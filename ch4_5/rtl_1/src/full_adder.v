/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 15:20:10
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-07 17:34:23
 * @Description: 1bit, 全加器
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module full_adder (
    input  wire  a,
    input  wire  b,
    input  wire  cin,
    output wire  sum,
    output wire  cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule
`resetall