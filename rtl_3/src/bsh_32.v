/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 14:32:30
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 22:44:29
 * @Description: 桶形移位器组合逻辑
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module bsh_32 #(
    parameter DATA_WIDTH            = 32,
    parameter SH_WIDTH              = $clog2(DATA_WIDTH)
) (
    input  wire [DATA_WIDTH-1:0]    data_in,
    // 位移方向，0:左移，1:右移
    input  wire                     dir,
    // 位移值
    input  wire [SH_WIDTH-1:0]      sh,
    output wire [DATA_WIDTH-1:0]    data_out
);
    
    // 扩展数据
    wire [DATA_WIDTH*2-1:0] data_ext = {data_in, data_in};
    
    // 移位逻辑
    assign data_out = dir ? 
        data_ext[DATA_WIDTH + sh -1 -: DATA_WIDTH] :    // 右移，最低位找高位
        data_ext[DATA_WIDTH - sh    +: DATA_WIDTH] ;    // 左移

    
endmodule
`resetall