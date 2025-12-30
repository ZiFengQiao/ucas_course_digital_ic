/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 19:52:51
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-28 19:54:17
 * @Description: 
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module sort_unit #(
    parameter DATA_WIDTH = 8,
    parameter ASCEND     = 1  // 1: 升序, 0: 降序
) (
    input  wire  [DATA_WIDTH-1:0] i_a,
    input  wire  [DATA_WIDTH-1:0] i_b,
    output wire  [DATA_WIDTH-1:0] o_a,
    output wire  [DATA_WIDTH-1:0] o_b
);
    // 比较并交换单元
    // 根据ASCEND参数决定排序方向
    generate
        if (ASCEND) begin : gen_ascend
            assign o_a = (i_a <= i_b) ? i_a : i_b;
            assign o_b = (i_a <= i_b) ? i_b : i_a;
        end
        else begin : gen_descend
            assign o_a = (i_a >= i_b) ? i_a : i_b;
            assign o_b = (i_a >= i_b) ? i_b : i_a;
        end
    endgenerate
endmodule
`resetall