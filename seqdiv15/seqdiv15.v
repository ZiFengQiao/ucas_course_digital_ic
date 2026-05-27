/*
 * @Author: Wang, Qiaoyu
 * @Date: 2026-01-27 15:43:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-27 19:56:37
 * @Description: 考试题
 */



`resetall
`timescale 1ns / 1ps
`default_nettype none

module seqdiv15 #(
) (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  din,
    output wire  res
);

    reg  [3:0] remain_d, remain_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remain_q <= 4'b0;
        end
        else begin
            remain_q <= remain_d;
        end
    end

    reg [4:0] temp;
    always @(*) begin
        temp = {remain_q, din};
        if (temp >= 5'd15) begin
            remain_d = temp - 5'd15;
        end
        else begin
            remain_d = temp[3:0];
        end
    end

    assign res = (remain_q == 4'b0) ? 1'b1 : 1'b0;
endmodule
`resetall