/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 23:10:07
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 00:56:09
 * @Description: 变参，超前进位加法器
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module cla_adder #(
    parameter DATA_WIDTH           = 32,
    // 是否扩展一位以避免溢出
    parameter DATA_EXTEND          = 1,
    // 启用扩展一位时，是否为有符号数加法
    // 有符号加法需要先扩展到33位，再相加
    // 无符号加法直接32bit加法，cout作为第33位
    parameter DATA_SIGNED          = 1,
    parameter OUTPUT_WIDTH         = DATA_EXTEND ? (DATA_WIDTH + 1) : DATA_WIDTH
) (
    input  wire [DATA_WIDTH-1:0]   data_a,
    input  wire [DATA_WIDTH-1:0]   data_b,
    input  wire                    cin,
    // 使用DATA_EXTEND时，cout无效
    output wire                    cout,
    output wire [OUTPUT_WIDTH-1:0] sum
);

    localparam BLOCK_SIZE = 4;
    
    initial begin
        if (DATA_WIDTH % BLOCK_SIZE != 0) begin
            $error("DATA_WIDTH must be multiple of %0d", BLOCK_SIZE);
            $finish;
        end
    end

    // 总的layer数量
    function integer calc_layer_num;
        input integer width;
        begin
            calc_layer_num = 0;
            while (width > 1) begin
                width = width / BLOCK_SIZE;
                calc_layer_num = calc_layer_num + 1;
            end
        end
    endfunction

    // 每层的block数量
    function integer calc_layer_block_num;
        input integer layer;
        begin
            calc_layer_block_num = DATA_WIDTH / (BLOCK_SIZE ** (layer + 1));
            calc_layer_block_num = calc_layer_block_num > 0 ? calc_layer_block_num : 1;
        end
    endfunction

    localparam LAYER_NUM = calc_layer_num(DATA_WIDTH);

    // PG网络
    wire  [DATA_WIDTH-1:0]    p_net   [0:LAYER_NUM];
    wire  [DATA_WIDTH-1:0]    g_net   [0:LAYER_NUM];
    assign p_net[0] = data_a | data_b;
    assign g_net[0] = data_a & data_b;

    // carry网络
    wire  [DATA_WIDTH-1:0]    cout_net;
    assign cout_net[0] = cin;


    initial begin
        $display("CLA Adder Configuration:");
        $display("  DATA_WIDTH: %0d", DATA_WIDTH);
        $display("  DATA_EXTEND: %0d", DATA_EXTEND);
        $display("  DATA_SIGNED: %0d", DATA_SIGNED);
        $display("  OUTPUT_WIDTH: %0d", OUTPUT_WIDTH);
        $display("  BLOCK_SIZE: %0d", BLOCK_SIZE);
        $display("  LAYER_NUM: %0d", LAYER_NUM);
    end
    genvar layer_idx, block_idx;
    genvar cout_idx;
    generate
        // 生成每一层的CLA块
        for (layer_idx = 0; layer_idx < LAYER_NUM; layer_idx = layer_idx + 1) begin : gen_layers
            localparam LAYER_BLOCK_NUM_PREV   = calc_layer_block_num(layer_idx - 1);
            localparam LAYER_BLOCK_NUM        = calc_layer_block_num(layer_idx);
            localparam BLOCK_OFFSET_PREV      = BLOCK_SIZE ** layer_idx;
            localparam BLOCK_OFFSET           = BLOCK_SIZE ** (layer_idx + 1);
            localparam BLOCK_OFFSET_NEXT      = BLOCK_SIZE ** (layer_idx + 2);

            for (block_idx = 0; block_idx < LAYER_BLOCK_NUM; block_idx = block_idx + 1) begin : gen_blocks
                wire [3:0]  i_p    = p_net[layer_idx][block_idx * BLOCK_OFFSET +: 4];
                wire [3:0]  i_g    = g_net[layer_idx][block_idx * BLOCK_OFFSET +: 4];
                wire        o_p;
                wire        o_g;
                wire        i_cin  = cout_net[block_idx * BLOCK_OFFSET];
                wire [2:0]  o_cout;
                
                localparam OUT_PG_POSITION = (block_idx / 4) * BLOCK_OFFSET_NEXT + (block_idx % 4);
                assign p_net[layer_idx + 1][OUT_PG_POSITION] = o_p;
                assign g_net[layer_idx + 1][OUT_PG_POSITION] = o_g;
                
                // 最后一层的cla, 做cout调整
                localparam LAYER_BLOCK_WIDTH = LAYER_BLOCK_NUM_PREV >= 4 ? 4 : LAYER_BLOCK_NUM_PREV;
                for (cout_idx = 0; cout_idx < LAYER_BLOCK_WIDTH - 1; cout_idx = cout_idx + 1) begin
                    // block定位c0的位置，定位的是cin的位置
                    // count_idx * prev定位的是该模块cout的权值
                    // 两种权值来自两层，所有使用两种offset
                    // count_idx + 1是跳过最低位
                    assign cout_net[block_idx * BLOCK_OFFSET + (cout_idx+1) * BLOCK_OFFSET_PREV] = o_cout[cout_idx];
                end

                cla_c4 u_cla_c4 (
                    .i_p    (i_p),
                    .i_g    (i_g),
                    .i_cin  (i_cin),
                    .o_p    (o_p),
                    .o_g    (o_g),
                    .o_cout (o_cout)
                );

                initial begin
                    $display("Layer %0d, Block %0d:", layer_idx, block_idx);
                    $display("  BLOCK_OFFSET_PREV: %0d", BLOCK_OFFSET_PREV);
                    $display("  BLOCK_OFFSET: %0d", BLOCK_OFFSET);
                    $display("  BLOCK_OFFSET_NEXT: %0d", BLOCK_OFFSET_NEXT);
                    $display("  OUT_PG_POSITION: %0d", OUT_PG_POSITION);
                end
            end

            if (LAYER_BLOCK_NUM < 4 && LAYER_BLOCK_NUM > 1) begin : gen_last_layer_cout
                // 倒数第二层，调整p, g, 置位默认的0
                for (block_idx = LAYER_BLOCK_NUM; block_idx < 4; block_idx = block_idx + 1) begin
                    localparam OUT_PG_POSITION = (block_idx / 4) * BLOCK_OFFSET_NEXT + (block_idx % 4);
                    assign p_net[layer_idx + 1][OUT_PG_POSITION] = 1'b1;    // 默认传递进位（把后续的进位向前传）
                    assign g_net[layer_idx + 1][OUT_PG_POSITION] = 1'b0;    // 默认不产生数据
                end
            end
        end
    endgenerate


    wire [DATA_WIDTH-1:0] fa_cout_net;
    // 全加器输出
    genvar bit_idx;
    generate
        for (bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx = bit_idx + 1) begin : gen_sum_bits
            full_adder u_full_adder (
                .a      (data_a[bit_idx]),
                .b      (data_b[bit_idx]),
                .cin    (cout_net[bit_idx]),
                .sum    (sum[bit_idx]),
                .cout   (fa_cout_net[bit_idx])
            );
        end
    endgenerate
    assign cout = fa_cout_net[DATA_WIDTH-1];

    // 扩展位处理
    generate
        if (DATA_EXTEND) begin : gen_data_extend
            wire data_a_ext_msb = DATA_SIGNED ? data_a[DATA_WIDTH-1] : 1'b0;
            wire data_b_ext_msb = DATA_SIGNED ? data_b[DATA_WIDTH-1] : 1'b0;

            // 利用pg产生cin
            // 额外多产生一级延迟
            localparam LAST_LAYER_BLOCK_NUM = calc_layer_block_num(LAYER_NUM-1);
            
            // 使用最后一级输出的PG，计算进位位
            wire msb_p_in = p_net[LAYER_NUM][0];
            wire msb_g_in = g_net[LAYER_NUM][0];
            wire cin_msb = msb_g_in | (msb_p_in & cout_net[0]);

            wire sum_msb;

            full_adder u_full_adder (
                .a      (data_a_ext_msb),
                .b      (data_b_ext_msb),
                .cin    (cin_msb),
                .sum    (sum_msb),
                .cout   ()
            );
            assign sum[OUTPUT_WIDTH-1] = sum_msb;
        end
    endgenerate
endmodule
`resetall