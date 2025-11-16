/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-14 00:39:34
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-15 17:18:32
 * @Description: 用于8位输入的优先编码器，默认高位优先，默认从低位到高位编号
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module priority_encoder_8 #(
    parameter DATA_IN_WIDTH         = 8,
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
            8'b1???????: pos_out_d = POS_DIRECTION ? 3'b000 : 3'b111;
            8'b01??????: pos_out_d = POS_DIRECTION ? 3'b001 : 3'b110;
            8'b001?????: pos_out_d = POS_DIRECTION ? 3'b010 : 3'b101;
            8'b0001????: pos_out_d = POS_DIRECTION ? 3'b011 : 3'b100;
            8'b00001???: pos_out_d = POS_DIRECTION ? 3'b100 : 3'b011;
            8'b000001??: pos_out_d = POS_DIRECTION ? 3'b101 : 3'b010;
            8'b0000001?: pos_out_d = POS_DIRECTION ? 3'b110 : 3'b001;
            8'b00000001: pos_out_d = POS_DIRECTION ? 3'b111 : 3'b000;
            default:     pos_out_d = 'b0;
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