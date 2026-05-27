/*
 * @Author: Wang, Qiaoyu
 * @Date: 2026-01-27 15:44:27
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-27 15:45:40
 * @Description: PE 4-bit, 输出独热码
 */



`resetall
`timescale 1ns / 1ps
`default_nettype none

module pe_4 #(
) (
    input  wire  [3:0] in,
    input  wire  [3:0] out
);

    reg  [3:0] out_temp;
    
    always @(*) begin
        casex (in)
            4'bxxx1: out_temp = 4'b0001;
            4'bxx10: out_temp = 4'b0010;
            4'bx100: out_temp = 4'b0100;
            4'b1000: out_temp = 4'b1000; 
            default: out_temp = 4'b0000;
        endcase
    end

    assign out = out_temp;
endmodule
`resetall