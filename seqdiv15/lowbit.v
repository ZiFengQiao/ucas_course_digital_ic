/*
 * @Author: Wang, Qiaoyu
 * @Date: 2026-01-27 15:43:21
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-27 15:50:06
 * @Description: 16bit lowbit, 低位优先仲裁器
 */



`resetall
`timescale 1ns / 1ps
`default_nettype none

module lowbit #(
) (
    input  wire  [15:0] request,
    input  wire  [15:0] grant
);

    wire [3:0]  request_or;
    wire [15:0] pe4_grant;
    wire [3:0]  block_grant;
    
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_request_or
            assign request_or[i] = |request[i*4 +: 4];

            pe_4 u_pe4 (
                .in(request[i*4 +: 4]),
                .out(pe4_grant[i*4 +: 4])
            );
        end
        pe_4 u_pe4_block (
            .in(request_or),
            .out(block_grant)
        );
    endgenerate
    
    assign grant = (block_grant[0]) ? (pe4_grant[3:0] << 0) :
                   (block_grant[1]) ? (pe4_grant[7:4] << 4) :
                   (block_grant[2]) ? (pe4_grant[11:8] << 8) :
                   (block_grant[3]) ? (pe4_grant[15:12] << 12) :
                   16'b0;
endmodule
`resetall


