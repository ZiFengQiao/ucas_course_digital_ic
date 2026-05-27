/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 15:15:42
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-08 16:07:53
 * @Description: 1bit的华莱士树单元，支持添加半加器
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module wallace_tree_1b #(
    parameter DATA_NUM          = 32,        // 输入操作数的数量
    parameter CARRY_ONE_ENABLE  = 1,         // 等量1进位使能
    // 进位位数量（对应加法器单元个数），默认情况下需要n-2个加法器（每次压缩-1, 最终减小到2），适配乘法，需要额外一个半加器
    // 半加器 2->2, 不压缩，仅额外引入计算
    // 启用时，添加一个半加器，进位位共有N-2个，否则进位位为N-3个(不算最后一级的全加器)
    parameter CARRY_NUM         = CARRY_ONE_ENABLE ? DATA_NUM - 2 : DATA_NUM - 3
) (
    input  wire [DATA_NUM-1:0]  data_in,    // 输入数据
    output wire                 sum,        // 输出本位和
    output wire                 cout,       // 输出本位进位
    input  wire [CARRY_NUM-1:0] casc_cin,   // 级联输入进位
    output wire [CARRY_NUM-1:0] casc_cout   // 级联输出进位
);

    // 1 bit的wallace树基本单元
    // n个1bit数相加，除最后一层外
    
    // 计算需要的层数
    function integer calc_num2layer;
        input integer curr_num;
        input integer start_num;
        integer temp;
        begin
            calc_num2layer = 0;
            temp = start_num;
            while (temp > curr_num) begin
                temp = temp - temp / 3;
                calc_num2layer = calc_num2layer + 1;
            end
        end
    endfunction

    function integer calc_adder_total;
        input integer layer_num;
        integer temp;
        integer layer;
        begin
            calc_adder_total = 0;
            layer = 0;
            temp = DATA_NUM;
            while (temp > 2 && layer < layer_num) begin
                calc_adder_total = calc_adder_total + temp / 3;
                temp = temp - temp / 3;
                layer = layer + 1;
            end
        end
    endfunction

    // 最后一个，向上有2个空余数的层数，添加一个half adder
    function integer calc_half_adder_layer;
        input integer data_num;
        integer temp;
        integer layer;
        begin
            layer = 0;
            temp = data_num;
            calc_half_adder_layer = 0;
            while (temp > 2) begin
                if (temp % 3 == 2) begin
                    calc_half_adder_layer = layer;
                end
                layer = layer + 1;
                temp = temp - temp / 3;
            end
        end
    endfunction
    localparam LAYERS = calc_num2layer(2, DATA_NUM);

    // 顶层调试信息
    initial begin
        $display("========================================");
        $display("Wallace Tree 1-bit Configuration:");
        $display("  DATA_NUM         = %0d", DATA_NUM);
        $display("  CARRY_NUM        = %0d", CARRY_NUM);
        $display("  CARRY_ONE_ENABLE = %0d", CARRY_ONE_ENABLE);
        $display("  LAYERS           = %0d", LAYERS);
        $display("  LAYER_HALF_ADDER = %0d", CARRY_ONE_ENABLE ? calc_half_adder_layer(DATA_NUM) : 0);
        $display("========================================");
    end

    wire [DATA_NUM-1:0]         sum_net[0:LAYERS];
    assign                      sum_net[0] = data_in;
    
    // 生成Wallace树的各层
    genvar num;
    genvar sum_idx;
    generate
        localparam LAYER_HALF_ADDER = CARRY_ONE_ENABLE ? calc_half_adder_layer(DATA_NUM) : 0;

        for (num = DATA_NUM; num >= 3; num = num - num / 3) begin : gen_wallace_layers
            localparam LAYER_IDX = calc_num2layer(num, DATA_NUM);
            localparam LAYER_HELF_ADDER_TRUE = CARRY_ONE_ENABLE && (LAYER_IDX == LAYER_HALF_ADDER);

            localparam LAYER_SIN_NUM   = num;
            localparam LAYER_ADDER_MAX = num / 3;
            
            localparam LAYER_CIN_NUM   = LAYER_HELF_ADDER_TRUE ? LAYER_ADDER_MAX + 1 : LAYER_ADDER_MAX;
            localparam LAYER_SOUT_NUM  = num - LAYER_ADDER_MAX;
            localparam LAYER_COUT_NUM  = LAYER_HELF_ADDER_TRUE ? LAYER_ADDER_MAX + 1 : LAYER_ADDER_MAX;

            wire [LAYER_SIN_NUM-1:0]   layer_bits_in;
            wire [LAYER_SOUT_NUM-1:0]  layer_bits_out;
            wire [LAYER_CIN_NUM-1:0]   layer_cin;
            wire [LAYER_COUT_NUM-1:0]  layer_cout;
            
            // 连接sum
            assign layer_bits_in = sum_net[LAYER_IDX];
            assign sum_net[LAYER_IDX + 1] = layer_bits_out;

            // 调试信息：打印每层的参数
            initial begin
                $display("=== Wallace Tree Layer %0d ===", LAYER_IDX);
                $display("  num = %0d", num);
                $display("  LAYER_SIN_NUM         = %0d", LAYER_SIN_NUM);
                $display("  LAYER_SOUT_NUM        = %0d", LAYER_SOUT_NUM);
                $display("  LAYER_ADDER_MAX       = %0d", LAYER_ADDER_MAX);
                $display("  LAYER_CIN_NUM         = %0d", LAYER_CIN_NUM);
                $display("  LAYER_COUT_NUM        = %0d", LAYER_COUT_NUM);
                $display("  LAYER_HELF_ADDER_TRUE = %0d", LAYER_HELF_ADDER_TRUE);
                $display("  LAYER_CARRY_OFFSET    = %0d", LAYER_CARRY_OFFSET);
                $display("  LAYER_CARRY_WIDTH     = %0d", LAYER_CARRY_WIDTH);
            end
            
            localparam LAYER_CARRY_OFFSET = CARRY_ONE_ENABLE && (LAYER_IDX > LAYER_HALF_ADDER) ? calc_adder_total(LAYER_IDX) + 1: calc_adder_total(LAYER_IDX);
            localparam LAYER_CARRY_WIDTH  = LAYER_HELF_ADDER_TRUE ? LAYER_ADDER_MAX + 1 : LAYER_ADDER_MAX;

            // 连接进位（将级联进位split）
            // 最后一级，没有进位输入，进位输出放到cout
            if (LAYER_IDX == LAYERS - 1) begin
                assign cout = layer_cout[0];
            end
            else begin
                assign layer_cin = casc_cin[LAYER_CARRY_OFFSET +: LAYER_CARRY_WIDTH];
                assign casc_cout[LAYER_CARRY_OFFSET +: LAYER_CARRY_WIDTH] = layer_cout;
            end

            // 计算输出sum
            localparam SUM_FROM_ADDER_IDX_MAX  = LAYER_ADDER_MAX;
            localparam SUM_FROM_INPUT_IDX_MAX  = LAYER_HELF_ADDER_TRUE ? SUM_FROM_ADDER_IDX_MAX + num - (LAYER_ADDER_MAX * 3) - 1: SUM_FROM_ADDER_IDX_MAX + num - (LAYER_ADDER_MAX * 3);
            localparam SUM_FROM_CIN_IDX_MAX    = LAYER_SOUT_NUM;
            localparam SUM_FROM_HALF_ADDER_IDX = SUM_FROM_ADDER_IDX_MAX;

            for (sum_idx = 0; sum_idx < LAYER_SOUT_NUM; sum_idx = sum_idx + 1) begin : gen_layer_sum
                // 生成所有的输出位
                if (sum_idx < SUM_FROM_ADDER_IDX_MAX) begin
                    // 全加器生成位
                    full_adder u_fa (
                        .a       (layer_bits_in[sum_idx*3]),
                        .b       (layer_bits_in[sum_idx*3 + 1]),
                        .cin     (layer_bits_in[sum_idx*3 + 2]),
                        .sum     (layer_bits_out[sum_idx]),
                        .cout    (layer_cout[sum_idx])
                    );
                end
                else if (sum_idx < SUM_FROM_INPUT_IDX_MAX) begin
                    // 这里是对temp % 2的passthrough
                    // 如果启用了半加器，则一定不会走到这里
                    // 来自sum的pass through
                    if (LAYER_HELF_ADDER_TRUE) begin
                        // 来自 input 的半加器结果 2 -> 1
                        // 半加器是 num % 3 == 2 的位置
                        full_adder u_ha (
                            .a       (layer_bits_in[sum_idx*3]),
                            .b       (layer_bits_in[sum_idx*3 + 1]),
                            .cin     (1'b0),
                            .sum     (layer_bits_out[sum_idx]),
                            .cout    (layer_cout[sum_idx])
                        );
                    end
                    else begin
                        assign layer_bits_out[sum_idx] = layer_bits_in[(SUM_FROM_ADDER_IDX_MAX * 3) + (sum_idx - SUM_FROM_ADDER_IDX_MAX)];
                    end
                end
                else begin
                    // 来自cin的pass through
                    assign layer_bits_out[sum_idx] = layer_cin[sum_idx - SUM_FROM_INPUT_IDX_MAX];
                end
            end
        end
    endgenerate
    assign sum = sum_net[LAYERS][0];
endmodule
`resetall