/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 15:15:42
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 21:36:19
 * @Description: 位宽不为1的华莱士树模块
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module wallace_tree #(
    parameter DATA_NUM                      = 8,        // 输入操作数的数量
    parameter DATA_WIDTH                    = 16,       // 每个操作数的位宽
    // 是否启用匹配booth乘法器的等量1进位
    // 启用时，添加一个半加器，进位位共有N-2个，否则进位位为N-3个(不算最后一级的全加器)
    parameter CARRY_ONE_ENABLE              = 1,
    parameter CARRY_IN_WIDTH                = CARRY_ONE_ENABLE ? DATA_NUM - 2 : DATA_NUM - 3
) (
    input  wire [DATA_NUM*DATA_WIDTH-1:0]   data_in,    // 输入数据数组
    input  wire [CARRY_IN_WIDTH-1:0]        cin,        // 进位输入, 所有进位权值为最低位
    output wire [DATA_WIDTH-1:0]            sum,        // 和输出
    output wire [DATA_WIDTH-1:0]            cout        // 进位输出
);
    wire  [DATA_NUM-1:0] data_bit_array[DATA_WIDTH-1:0];

    genvar bit_idx;
    genvar data_idx;
    generate
        // 输入数据位分离
        // 数据排列方式
        // data_0 = data_in[0 +: DATA_WIDTH]
        for (bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1) begin : gen_bit_array
            for (data_idx = 0; data_idx < DATA_NUM; data_idx = data_idx + 1) begin : gen_data_array
                assign data_bit_array[bit_idx][data_idx] = data_in[data_idx*DATA_WIDTH + bit_idx];
            end
        end
    endgenerate

    // wallace_tree进位输出
    wire  [DATA_WIDTH-1:0] cout_temp;
    // 级联进位连线net
    wire  [CARRY_IN_WIDTH-1:0] casc_carry_net[DATA_WIDTH:0];
    assign                     casc_carry_net[0] = cin;
    
    // 每一位的wallace树单元例化
    generate
        for (bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1) begin
            // 每一位的wallace树单元
            wire [DATA_NUM-1:0]         i_bit_array_1b = data_bit_array[bit_idx];
            wire                        o_sum_1b;     
            wire                        o_cout_1b;
            wire [CARRY_IN_WIDTH-1:0]   i_casc_cin_1b  = casc_carry_net[bit_idx];
            wire [CARRY_IN_WIDTH-1:0]   o_casc_cout_1b;

            assign sum[bit_idx] = o_sum_1b;
            assign cout_temp[bit_idx] = o_cout_1b;
            assign casc_carry_net[bit_idx+1] = o_casc_cout_1b;
            wallace_tree_1b #(
                .DATA_NUM           (DATA_NUM),
                .CARRY_ONE_ENABLE   (CARRY_ONE_ENABLE)
            ) wallace_tree_1b_inst (
                .data_in    (i_bit_array_1b), // 取每一位的数据
                .sum        (o_sum_1b),
                .cout       (o_cout_1b),
                .casc_cin   (i_casc_cin_1b),
                .casc_cout  (o_casc_cout_1b)
            );
        end
    endgenerate

    // cout错位输出（进位权值提升一位）
    assign cout = {cout_temp[DATA_WIDTH-2:0], 1'b0};
endmodule
`resetall