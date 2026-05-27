/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-14 22:55:49
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-15 17:11:22
 * @Description: 2D架构优先编码器的多路选择器模块，默认会将高位1内容输出
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module priority_encoder_mux #(
    parameter MUX_INPUT_NUM    = 4,
    parameter MUX_INPUT_WIDTH  = 16,
    parameter MUX_DOR_WIDTH    = MUX_INPUT_NUM,
    parameter MUX_OUTPUT_WIDTH = MUX_INPUT_WIDTH
) (
    input  wire  [MUX_DOR_WIDTH-1:0]                 mux_dor,
    input  wire  [MUX_INPUT_NUM*MUX_INPUT_WIDTH-1:0] mux_data_in,
    output wire  [MUX_OUTPUT_WIDTH-1:0]              mux_data_out
);

    // 共有NUM个input
    // 共有$clog2(NUM) 级 MUX2 array
    
    localparam MUX2_LEVEL_MAX = $clog2(MUX_INPUT_NUM);

    wire  [MUX_INPUT_NUM*MUX_INPUT_WIDTH-1:0] level_mux2_out[MUX2_LEVEL_MAX:0];
    
    genvar current_level, level_mux2_num, level_mux2_index;
    genvar i;
    generate
        // 输入数据为level 0
        for (i = 0; i < MUX_INPUT_NUM; i = i + 1) begin
            assign level_mux2_out[0][i * MUX_INPUT_WIDTH +: MUX_INPUT_WIDTH] = mux_data_in[i * MUX_INPUT_WIDTH +: MUX_INPUT_WIDTH];
        end

        for (current_level = 1; current_level <= MUX2_LEVEL_MAX; current_level = current_level + 1) begin : gen_level_loop

            localparam LEVEL_MUX2_NUM = MUX_INPUT_NUM / (2 ** current_level);   // 当前 level 的 mux2 数量
            localparam DOR_SEL_WIDTH = 2 ** (current_level - 1);                // 当前 level 使用的 dor 选择宽度（mux2的数据来自多少dor）

            for (level_mux2_index = 0; level_mux2_index < LEVEL_MUX2_NUM; level_mux2_index = level_mux2_index + 1) begin : gen_level_mux2_index_loop

                // 根据不同的sel信号，选择上一个level的不同input
                // 最后的level_mux2_ou是如下形状
                // level: 0 1 2
                //        -
                //        -
                //        - -
                // lsb -> - - - <- 输出
                // mux主体
                
                assign level_mux2_out[current_level][level_mux2_index * MUX_INPUT_WIDTH +: MUX_INPUT_WIDTH] =
                    (|(mux_dor[(level_mux2_index * 2 + 1) * DOR_SEL_WIDTH +: DOR_SEL_WIDTH]) == 1'b1) ? 
                        level_mux2_out[current_level - 1][(level_mux2_index * 2 + 1) * MUX_INPUT_WIDTH +: MUX_INPUT_WIDTH] :
                        level_mux2_out[current_level - 1][(level_mux2_index * 2    ) * MUX_INPUT_WIDTH +: MUX_INPUT_WIDTH];
            end
        end

        // output assignment
        assign mux_data_out = level_mux2_out[MUX2_LEVEL_MAX][0 +: MUX_OUTPUT_WIDTH];
    endgenerate
endmodule
`resetall