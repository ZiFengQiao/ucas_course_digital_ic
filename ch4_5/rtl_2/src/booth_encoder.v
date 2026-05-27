/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-09 20:33:52
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 21:17:00
 * @Description: booth编码器，将数据a按数据b进行Booth编码，生成部分积
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module booth_encoder #(
    parameter DATA_A_WIDTH                      = 16,
    parameter DATA_B_WIDTH                      = 16,
    parameter PARTIAL_NUM                       = DATA_B_WIDTH / 2,             // 用B编码A
    parameter PARTIAL_WIDTH                     = DATA_A_WIDTH + DATA_B_WIDTH   // 每个部分积的宽度
) (
    input  wire [DATA_A_WIDTH-1:0]              data_a,
    input  wire [DATA_B_WIDTH-1:0]              data_b, 
    output wire [PARTIAL_WIDTH*PARTIAL_NUM-1:0] partial_products,
    output wire [PARTIAL_NUM-1:0]               partial_products_add_one_vector
);
    initial begin
        if (DATA_B_WIDTH % 2 != 0) begin
            $error("DATA_B_WIDTH must be even number");
            $finish;
        end
    end

    // 以data_b编码data_a
    // data_b扩展一位，最低位补0, 最低位为 2^{-1}
    wire [DATA_B_WIDTH:0] data_b_ext = {data_b, 1'b0};

    genvar part_idx;
    generate
        for (part_idx = 0; part_idx < PARTIAL_NUM; part_idx = part_idx + 1) begin : gen_booth_partial_product
            // 3-bit Booth编码
            localparam DATA_SHIFT_WIDTH = 2*part_idx + DATA_A_WIDTH;
            
            wire [DATA_SHIFT_WIDTH-1:0] data_a_shift = data_a << (2*part_idx);
            wire [2:0]                  booth_encode_3b = data_b_ext[2*part_idx +: 3];
            wire [PARTIAL_WIDTH-1:0]    partial_product_tmp;
            wire                        partial_product_add_one_tmp;

            // 移位，加权对应部分积
            assign partial_products[PARTIAL_WIDTH*part_idx +: PARTIAL_WIDTH] = partial_product_tmp;
            assign partial_products_add_one_vector[part_idx] = partial_product_add_one_tmp;

            // 编码模块将数据a进行符号位扩展
            // encoder负责移位a
            booth_3b #(
                .DATA_WIDTH       (DATA_SHIFT_WIDTH),
                .BOOTH_WIDTH      (PARTIAL_WIDTH)
            ) u_booth_3b_partial_product (
                .data_a           (data_a_shift),
                .data_b_3         (booth_encode_3b),
                .booth_a          (partial_product_tmp),
                .booth_add_one    (partial_product_add_one_tmp)
            );
        end
    endgenerate

endmodule
`resetall