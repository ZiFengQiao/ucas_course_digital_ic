/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-14 00:39:25
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-15 17:19:21
 * @Description: 用于4位输入的优先编码器，默认高位优先，默认从高位到低位编号
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module priority_encoder_4 #(
    parameter DATA_IN_WIDTH         = 4,
    parameter POS_OUT_WIDTH         = $clog2(DATA_IN_WIDTH),
    // 1'b1表示编码位置由高位到低位，1'b0表示编码位置由低位到高位
    parameter POS_DIRECTION         = 1'b1,
    parameter VALID_ENABLE          = 1'b1,
    parameter VALID_WIDTH           = 1
) (
    input  wire [DATA_IN_WIDTH-1:0] data_in,
    output wire [POS_OUT_WIDTH-1:0] pos_out,
    output wire [VALID_WIDTH-1:0]   pos_valid
);

    reg  [POS_OUT_WIDTH-1:0] pos_out_d;

    // ---------------------------------------
    // block 0, combined logic
    // i: data_in
    // o: pos_out_d
    always @(*) begin
        pos_out_d   = 'b0;

        // pos_out
        casez (data_in)
            4'b1???: pos_out_d = POS_DIRECTION ? 2'b00 : 2'b11;
            4'b01??: pos_out_d = POS_DIRECTION ? 2'b01 : 2'b10;
            4'b001?: pos_out_d = POS_DIRECTION ? 2'b10 : 2'b01;
            4'b0001: pos_out_d = POS_DIRECTION ? 2'b11 : 2'b00;
            default: pos_out_d = 'b0;
        endcase
    end

    // ---------------------------------------
    // block 1, generated combined logic
    // i: data_in
    // o: pos_valid
    generate
        if (VALID_ENABLE) begin
            assign pos_valid = | data_in;
        end
        else begin
            assign pos_valid = 0;
        end
    endgenerate

    // assign out
    assign pos_out = pos_out_d;
endmodule
`resetall