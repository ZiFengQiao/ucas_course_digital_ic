/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 14:53:01
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-09 21:15:04
 * @Description: Booth 3-bit 编码模块
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module booth_3b #(
    parameter DATA_WIDTH            = 16,
    // 指定输出符号扩展后的宽度
    parameter BOOTH_WIDTH           = 32
) (
    // 输入数据a
    input  wire [DATA_WIDTH-1:0]    data_a,
    // 输入数据b的3bit
    input  wire [2:0]               data_b_3,
    // Booth编码输出，多一位
    output wire [BOOTH_WIDTH-1:0]   booth_a,
    // 取反加1位
    output wire                     booth_add_one
);
    initial begin
        if (BOOTH_WIDTH < DATA_WIDTH + 1) begin
            // 输入检查
            $error("Error: BOOTH_WIDTH must be greater than or equal to DATA_WIDTH + 1 (instance %m)");
            $finish;
        end
    end

    // Booth 3-bit编码原理：
    // 对于3bit的输入 data_b_3[2:0]，根据Booth编码规则进行编码
    // Booth编码表：
    // b[2:0] | 编码 (multiplier)
    // 000    | 0
    // 001    | +1
    // 010    | +1
    // 011    | +2
    // 100    | -2
    // 101    | -1
    // 110    | -1
    // 111    | 0
    
    localparam SIGN_EXTEND_WIDTH = BOOTH_WIDTH - DATA_WIDTH;
    
    wire [BOOTH_WIDTH-1:0]  data_a_extend = {{SIGN_EXTEND_WIDTH{data_a[DATA_WIDTH-1]}}, data_a};
    reg  [BOOTH_WIDTH-1:0]  booth_a_d;
    reg                     booth_add_one_d;
    always @(*) begin
        case (data_b_3)
            3'b000, 3'b111: begin
                // +0
                booth_a_d = {DATA_WIDTH{1'b0}};
                booth_add_one_d = 1'b0;
            end
            3'b001, 3'b010: begin
                // +1
                booth_a_d = data_a_extend;
                booth_add_one_d = 1'b0;
            end
            3'b011: begin
                // +2
                booth_a_d = data_a_extend << 1;
                booth_add_one_d = 1'b0;
            end
            3'b100: begin
                // -2
                booth_a_d = ~(data_a_extend << 1);
                booth_add_one_d = 1'b1;
            end
            3'b101, 3'b110: begin
                // -1
                booth_a_d = ~data_a_extend;
                booth_add_one_d = 1'b1;
            end
            default: begin
                booth_a_d = {BOOTH_WIDTH{1'b0}};
                booth_add_one_d = 1'b0;
            end
        endcase
    end

    assign booth_a       = booth_a_d;
    assign booth_add_one = booth_add_one_d;
endmodule
`resetall