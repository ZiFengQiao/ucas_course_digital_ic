/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 16:24:12
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-28 21:38:23
 * @Description: 32x8-bit Unsigned Integer Sorter using Bitonic Sort Network
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module sort_32_u8 #(
    parameter  DATA_WIDTH                  = 8,
    parameter  DATA_NUM                    = 32
) (
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire                            vld_in,
    input  wire  [DATA_NUM*DATA_WIDTH-1:0] din_array,
    output wire                            vld_out,
    output wire  [DATA_NUM*DATA_WIDTH-1:0] dout_array
);
    bitonic_sort # (
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_NUM(DATA_NUM),
        .ASCEND(1)
    )
    bitonic_sort_inst (
        .clk(clk),
        .rst_n(rst_n),
        .vld_in(vld_in),
        .din_array(din_array),
        .vld_out(vld_out),
        .dout_array(dout_array)
    );
endmodule
`resetall
