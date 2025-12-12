/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-07 14:32:30
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-12 13:02:45
 * @Description: 桶形移位器组合逻辑，添加输入输出寄存器
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module bsh_32_clk #(
    parameter DATA_WIDTH            = 32,
    parameter SH_WIDTH              = $clog2(DATA_WIDTH)
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire [DATA_WIDTH-1:0]    data_in,
    // 位移方向，0:左移，1:右移
    input  wire                     dir,
    // 位移值
    input  wire [SH_WIDTH-1:0]      sh,
    output wire [DATA_WIDTH-1:0]    data_out
);
    
    // 寄存器化输入/输出
    reg  [DATA_WIDTH-1:0] data_in_r;
    reg                   dir_r;
    reg  [SH_WIDTH-1:0]   sh_r;
    reg  [DATA_WIDTH-1:0] data_out_r;

    // 扩展数据 (基于寄存输入)
    wire [DATA_WIDTH*2-1:0] data_ext = {data_in_r, data_in_r};

    // 移位逻辑（在时钟上寄存输出）
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_in_r  <= {DATA_WIDTH{1'b0}};
            dir_r      <= 1'b0;
            sh_r       <= {SH_WIDTH{1'b0}};
            data_out_r <= {DATA_WIDTH{1'b0}};
        end else begin
            // 采样输入
            data_in_r <= data_in;
            dir_r     <= dir;
            sh_r      <= sh;

            // 计算并寄存输出
            if (dir_r) begin
                // 右移，最低位找高位
                data_out_r <= data_ext[DATA_WIDTH + sh_r - 1 -: DATA_WIDTH];
            end else begin
                // 左移
                data_out_r <= data_ext[DATA_WIDTH - sh_r +: DATA_WIDTH];
            end
        end
    end

    assign data_out = data_out_r;

    
endmodule
`resetall