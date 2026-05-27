/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-08 15:25:51
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 20:44:56
 * @Description: booth乘法器
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module booth_multi #(
    parameter DATA_WIDTH            = 16

) (
    input  wire  [DATA_WIDTH-1:0]   data_a,
    input  wire  [DATA_WIDTH-1:0]   data_b,
    output wire  [2*DATA_WIDTH-1:0] product
);
    initial begin
        if (DATA_WIDTH % 2 != 0) begin
            $error("DATA_WIDTH must be even number");
            $finish;
        end
    end
    localparam PARTIAL_NUM = DATA_WIDTH / 2;

    // 部分积结果
    // 部分积符号扩展到2*DATA_WIDTH位
    genvar part_idx;
    generate
        // Booth编码，生成部分积
        wire [2*DATA_WIDTH*PARTIAL_NUM-1:0] partial_products;
        wire [PARTIAL_NUM-1:0]              partial_products_add_one_vector;

        booth_encoder #(
            .DATA_A_WIDTH        (DATA_WIDTH),
            .DATA_B_WIDTH        (DATA_WIDTH)
        ) u_booth_encoder (
            .data_a              (data_a),
            .data_b              (data_b),
            .partial_products    (partial_products),
            .partial_products_add_one_vector (partial_products_add_one_vector)
        );
        
        // Wallace Tree，生成两个加数
        wire [2*DATA_WIDTH-1:0]  wallace_sum_out;
        wire [2*DATA_WIDTH-1:0]  wallace_carry_out;
        // 剩下两位1加数留到最后的超前进位加法器中处理
        wire [PARTIAL_NUM-3:0]   wallace_add_ones = partial_products_add_one_vector[PARTIAL_NUM-3:0];

        wallace_tree #(
            .DATA_NUM            (PARTIAL_NUM),
            .DATA_WIDTH          (2*DATA_WIDTH),
            .CARRY_ONE_ENABLE    (1)
        ) u_wallace_tree (
            .data_in             (partial_products),
            .cin                 (wallace_add_ones),
            .sum                 (wallace_sum_out),
            .cout                (wallace_carry_out)
        ); 

        // 超前进位加法器
        wire [2*DATA_WIDTH-1:0]  cla_data_a = wallace_sum_out;
        // 最后两个 加1
        wire [2*DATA_WIDTH-1:0]  cla_data_b = {wallace_carry_out[2*DATA_WIDTH-1:1], partial_products_add_one_vector[PARTIAL_NUM-2]};
        wire                     cla_cin    = partial_products_add_one_vector[PARTIAL_NUM-1];
        wire [2*DATA_WIDTH-1:0]  cla_sum;

        cla_adder #(
            .DATA_WIDTH          (2*DATA_WIDTH),
            .DATA_EXTEND         (0)
        ) u_cla_adder (
            .data_a              (cla_data_a),
            .data_b              (cla_data_b),
            .cin                 (cla_cin),
            .cout                (),
            .sum                 (cla_sum)
        );
        assign product = cla_sum;
    endgenerate
endmodule
`resetall