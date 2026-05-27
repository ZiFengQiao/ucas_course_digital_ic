/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-15 00:11:49
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-16 18:52:16
 * @Description: 检测序列
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module seq_detector #(
    parameter SEQ_WIDTH = 6,
    parameter SEQ_0 = 6'b111000,
    parameter SEQ_1 = 6'b101110
) (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  din_vld,
    input  wire  din,
    output wire  result
);
    reg  [SEQ_WIDTH-1:0] shift_reg_q = 'b0, shift_reg_d;
    reg                  result_q = 'b0, result_d;
    wire [SEQ_WIDTH-1:0] seq_0, seq_1;
    // sample logic
    always @(*) begin
        shift_reg_d = shift_reg_q;
        if (din_vld) begin
            shift_reg_d = {shift_reg_q[SEQ_WIDTH-2:0], din};
        end
    end


    // !!!, 由于检测的两个SEQ都由1开始，不必进行vld打拍延迟
    //      若，检测的序列由0开始，则需要对din_vld打6拍的延迟，然后将vld_reg作用到result上
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg_q <= 'b0;
        end
        else begin
            shift_reg_q <= shift_reg_d;
        end
    end

    // 两个常量
    assign seq_0 = SEQ_0;
    assign seq_1 = SEQ_1;

    // detect logic
    always @(*) begin
        result_d = 1'b0;
        if (shift_reg_d == seq_0 || shift_reg_d == seq_1) begin
            result_d = 1'b1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= 1'b0;
        end
        else begin
            result_q <= result_d;
        end
    end

    assign result = result_q;
endmodule
`resetall