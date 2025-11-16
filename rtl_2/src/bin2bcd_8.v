/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-15 00:44:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-16 19:24:22
 * @Description: shift-add algorithms 8位无符号数转换为BCD码
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module bin2bcd_8 #(
    parameter BIN_IN_WIDTH          = 8,
    parameter BCD_OUT_WIDTH         = 10
) (
    input  wire [BIN_IN_WIDTH-1:0]  bin_in,
    output wire [BCD_OUT_WIDTH-1:0] bcd_out
);

    integer i;
    reg [19:0] bcd_temp;

    always @(*) begin
        // 初始化, 直接移位三次
        bcd_temp = {9'b0, bin_in, 3'b0};
        // 逐位移位法
        for (i = 0; i < 5; i = i + 1'b1) begin
            // 如果BCD的每一部分 > 4，加3
            if (bcd_temp[11:8] > 4)
                bcd_temp[11:8] = bcd_temp[11:8] + 3;
            if (bcd_temp[15:12] > 4)
                bcd_temp[15:12] = bcd_temp[15:12] + 3;
            if (bcd_temp[19:16] > 4)
                bcd_temp[19:16] = bcd_temp[19:16] + 3;
            // 左移1位
            bcd_temp = {bcd_temp[18:0], 1'b0};
        end
    end
    
    // 输出
    assign bcd_out = bcd_temp[BIN_IN_WIDTH +: BCD_OUT_WIDTH];
endmodule
`resetall