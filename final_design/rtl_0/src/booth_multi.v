/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-08 15:25:51
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-02-27 22:57:34
 * @Description: booth乘法器
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module booth_multi #(
    parameter DATA_WIDTH            = 64
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     vld_in,
    input  wire  [DATA_WIDTH-1:0]   data_a,
    input  wire  [DATA_WIDTH-1:0]   data_b,
    output wire  [2*DATA_WIDTH-1:0] data_c,
    output wire                     vld_out
);
    initial begin
        if (DATA_WIDTH % 2 != 0) begin
            $error("DATA_WIDTH must be even number");
            $finish;
        end
    end
    localparam PARTIAL_NUM = DATA_WIDTH / 2;

    // vld sync 
    reg  [2:0] vld_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vld_sync <= 'd0;
        end else begin
            vld_sync <= {vld_sync[1:0], vld_in};
        end
    end
    assign vld_out = vld_sync[2];

    // 3 stage pipeline register
    // 1. booth encode output
    wire [2*DATA_WIDTH*PARTIAL_NUM-1:0] partial_products_d; 
    reg  [2*DATA_WIDTH*PARTIAL_NUM-1:0] partial_products_q;
    wire [PARTIAL_NUM-1:0]              partial_products_add_one_vector_d;
    reg  [PARTIAL_NUM-1:0]              partial_products_add_one_vector_q;
    // 2. wallace tree output
    // 保留stage 1的未处理的剩余进位1传递给stage3
    wire [1:0]                          partial_add_one_remain_d;
    reg  [1:0]                          partial_add_one_remain_q;
    wire [2*DATA_WIDTH-1:0]             wallace_sum_out_d;
    reg  [2*DATA_WIDTH-1:0]             wallace_sum_out_q;
    wire [2*DATA_WIDTH-1:0]             wallace_carry_out_d;
    reg  [2*DATA_WIDTH-1:0]             wallace_carry_out_q;
    // 3. cla adder output
    wire [2*DATA_WIDTH-1:0]             cla_sum_d;
    reg  [2*DATA_WIDTH-1:0]             cla_sum_q;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            partial_products_q <= 'd0;
            partial_products_add_one_vector_q <= 'd0;
            partial_add_one_remain_q <= 'd0;
            wallace_sum_out_q <= 'd0;
            wallace_carry_out_q <= 'd0;
            cla_sum_q <= 'd0;
        end else begin
            partial_products_q <= partial_products_d;
            partial_products_add_one_vector_q <= partial_products_add_one_vector_d;
            partial_add_one_remain_q <= partial_add_one_remain_d;
            wallace_sum_out_q <= wallace_sum_out_d;
            wallace_carry_out_q <= wallace_carry_out_d;
            cla_sum_q <= cla_sum_d;
        end
    end


    // 部分积结果
    // 部分积符号扩展到2*DATA_WIDTH位
    // Booth编码，生成部分积
    booth_encoder #(
        .DATA_A_WIDTH        (DATA_WIDTH),
        .DATA_B_WIDTH        (DATA_WIDTH)
    ) u_booth_encoder (
        .data_a              (data_a),
        .data_b              (data_b),
        .partial_products    (partial_products_d),
        .partial_products_add_one_vector (partial_products_add_one_vector_d)
    );
    
    // Wallace Tree，生成两个加数

    // 剩下两位1加数留到最后的超前进位加法器中处理
    wire [PARTIAL_NUM-3:0]   wallace_add_ones;

    assign {partial_add_one_remain_d, wallace_add_ones} = partial_products_add_one_vector_q;

    wallace_tree #(
        .DATA_NUM            (PARTIAL_NUM),
        .DATA_WIDTH          (2*DATA_WIDTH),
        .CARRY_ONE_ENABLE    (1)
    ) u_wallace_tree (
        .data_in             (partial_products_q),
        .cin                 (wallace_add_ones),
        .sum                 (wallace_sum_out_d),
        .cout                (wallace_carry_out_d)
    ); 

    // 超前进位加法器
    wire [2*DATA_WIDTH-1:0]  cla_data_a = wallace_sum_out_q;
    // 最后两个 加1
    wire [2*DATA_WIDTH-1:0]  cla_data_b = {wallace_carry_out_q[2*DATA_WIDTH-1:1], partial_add_one_remain_q[0]};
    wire                     cla_cin    = partial_add_one_remain_q[1];

    cla_adder #(
        .DATA_WIDTH          (2*DATA_WIDTH),
        .DATA_EXTEND         (0)
    ) u_cla_adder (
        .data_a              (cla_data_a),
        .data_b              (cla_data_b),
        .cin                 (cla_cin),
        .cout                (),
        .sum                 (cla_sum_d)
    );
    assign data_c = cla_sum_q;
endmodule
`resetall