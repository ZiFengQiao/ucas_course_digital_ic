/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-15 00:44:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-15 15:31:24
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
    localparam RESULT_WIDTH      = BCD_OUT_WIDTH + BIN_IN_WIDTH;
    localparam RESULT_LEVEL_MAX  = BIN_IN_WIDTH;
    localparam RESULT_BCD_NUM    = $ceil(BCD_OUT_WIDTH / 4);
    localparam RESULT_BCD_OFFSET = BIN_IN_WIDTH;

    // 每个stage拆分两步，两级中间结果，一级做加法，一级做移位
    // shift add算法
    // 时序逻辑（流水线）可以直接在adder结果打拍，或者每两个adder打拍
    wire [RESULT_WIDTH-1:0] result_net[2*RESULT_LEVEL_MAX-1:0];
    genvar stage_idx, step_idx, digit_idx;
    generate
        for (stage_idx = 0; stage_idx < RESULT_LEVEL_MAX; stage_idx = stage_idx + 1) begin
            for (step_idx = 0; step_idx < 2; step_idx = step_idx + 1) begin
                if (step_idx == 0) begin
                    // 进行加法
                    for (digit_idx = 0; digit_idx < RESULT_BCD_NUM; digit_idx = digit_idx + 1) begin
                        if (stage_idx >= 3) begin
                            // 确保已经移位进入了3个数字
                            // 进行4-bit条件加法
                            assign result_net[stage_idx][RESULT_BCD_OFFSET + digit_idx*4 +:4] = 
                                result_net[stage_idx][RESULT_BCD_OFFSET + digit_idx*4 +:4] > 4 ?
                                    result_net[stage_idx-1][RESULT_BCD_OFFSET + digit_idx*4 +:4] + 3 :
                                    result_net[stage_idx-1][RESULT_BCD_OFFSET + digit_idx*4];
                        end
                        else begin
                            assign result_net[stage_idx][RESULT_BCD_OFFSET + digit_idx*4 +:4] = 
                                result_net[stage_idx-1][RESULT_BCD_OFFSET + digit_idx*4 +:4];
                        end
                    end
                end
                else begin
                    // 进行移位
                    assign result_net[2*stage_idx+step_idx] = {result_net[2*stage_idx+step_idx-1][RESULT_WIDTH-2:0], 1'b0};
                end
            end
        end
    endgenerate
    
    // 输出
    assign bcd_out = result_net[2*RESULT_LEVEL_MAX-1][RESULT_BCD_OFFSET +: BCD_OUT_WIDTH];
endmodule
`resetall