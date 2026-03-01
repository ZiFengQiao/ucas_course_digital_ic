/*
 * @Author: Wang, Qiaoyu
 * @Date: 2026-02-27 16:13:18
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-02-28 16:12:45
 * @Description: lzc, 树状结构
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module lzc #(
    parameter WIDTH                     = 64 
) (
    input  wire [WIDTH-1:0]             data_in,
    output wire                         cnt_valid, // 如果输入全为0，则为0
    output wire [$clog2(WIDTH)-1:0]     cnt        // 前导零计数结果
);

    parameter LEVELS = WIDTH > 2 ? $clog2(WIDTH) : 1;       // 计算层级数：如果宽度大于2，则为宽度的log2，否则为1
    parameter W      = 2**LEVELS;                           // 计算扩展宽度：2的LEVELS次方，确保为2的幂次

    // 将输入信号扩展到W位，高位补0，确保输入为2的幂次宽度
    wire [W-1:0] input_padded = {data_in, {W-WIDTH{1'b0}}};

    wire [W/2-1:0] stage_valid[LEVELS-1:0];                 // 定义层级有效信号数组：每个层级有W/2个有效信号
    wire [W/2-1:0] stage_enc[LEVELS-1:0];                   // 定义层级编码信号数组：每个层级有W/2个编码信号


    // 生成树形结构
    // 每一级将两个bit编码为 1bit的有效信号（归或）
    //                    1bit的编码（enc, 对应优先级）
    generate
        genvar l, n;  // 定义生成变量l(层级)和n(位置)

        // 处理输入位：为每一对输入位生成有效位和编码位
        for (n = 0; n < W/2; n = n + 1) begin : loop_in
            // 检查每对输入位(n*2+1, n*2)中是否有至少一个为1
            // 每相邻两位组成一对
            assign stage_valid[0][n] = |input_padded[n*2+1:n*2];
            

            // 高位为1, 编码为0
            assign stage_enc[0][n] = input_padded[n*2+1] ? 1'b0 : 1'b1;
        end

        // 逐层压缩：将多层级的信号压缩到单个有效位和编码总线
        //          每一级都对编码进行相同操作，逐个添加 指向低位的0和指向高位的1, 最终压缩到只剩两位，得到结果
        for (l = 1; l < LEVELS; l = l + 1) begin : loop_levels
            for (n = 0; n < W/(2*2**l); n = n + 1) begin : loop_compress
                // 对每一层数据继续执行每2bit的树形压缩
                // 每一层是前一层两个节点的归或
                assign stage_valid[l][n] = |stage_valid[l-1][n*2+1:n*2];
                
                // 高位是1, 编码为0
                assign stage_enc[l][(n+1)*(l+1)-1:n*(l+1)] = 
                    stage_valid[l-1][n*2+1] ? 
                        {1'b0, stage_enc[l-1][(n*2+2)*l-1:(n*2+1)*l]} : // 选上层节点
                        {1'b1, stage_enc[l-1][(n*2+1)*l-1:(n*2+0)*l]};  // 选下节点
            end
        end
    endgenerate

    assign cnt_valid = stage_valid[LEVELS-1];
    // 如果全为0，通常输出为 WIDTH
    assign cnt       = stage_enc[LEVELS-1];

endmodule
`resetall
