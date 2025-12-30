/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 16:24:12
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-28 21:35:32
 * @Description: 32x8-bit Unsigned Integer Sorter using Bitonic Sort Network
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module bitonic_sort #(
    parameter  DATA_WIDTH = 8,
    parameter  DATA_NUM   = 32,
    parameter  ASCEND     = 1    // 1: 升序, 0: 降序
) (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  vld_in,
    input  wire  [DATA_NUM*DATA_WIDTH-1:0] din_array,
    output wire  vld_out,
    output wire  [DATA_NUM*DATA_WIDTH-1:0] dout_array
);

    // 双调排序网络 (Bitonic Sort Network)
    // 对于 N=32 个元素，需要 log2(N) = 5 个组
    // 组1: 16个 2元素 merge (交替升序/降序)
    // 组2: 8个 4元素 merge (交替升序/降序)
    // 组3: 4个 8元素 merge (交替升序/降序)
    // 组4: 2个 16元素 merge (交替升序/降序)
    // 组5: 1个 32元素 merge (全升序)
    localparam GROUP_NUM = $clog2(DATA_NUM);  // 5

    // 顶层配置信息
    initial begin
        $display("================================================================================");
        $display("[bitonic_sort] Configuration:");
        $display("[bitonic_sort]   DATA_WIDTH     = %0d bits", DATA_WIDTH);
        $display("[bitonic_sort]   DATA_NUM       = %0d elements", DATA_NUM);
        $display("[bitonic_sort]   GROUP_NUM      = %0d groups", GROUP_NUM);
        $display("[bitonic_sort]   Total I/O bits = %0d bits", DATA_NUM * DATA_WIDTH);
        $display("[bitonic_sort]   Pipeline depth = %0d cycles", (GROUP_NUM * (GROUP_NUM + 1)) / 2 + GROUP_NUM);
        $display("================================================================================");
    end

    // 组间连接信号
    wire [DATA_NUM*DATA_WIDTH-1:0] group_data_in  [0:GROUP_NUM];
    wire                           group_valid_in [0:GROUP_NUM];
    wire [DATA_NUM*DATA_WIDTH-1:0] group_data_out [0:GROUP_NUM-1];
    wire                           group_valid_out[0:GROUP_NUM-1];

    // 输入连接
    assign group_data_in[0]  = din_array;
    assign group_valid_in[0] = vld_in;

    // ========================================================================
    // 生成 5 个组，每个组包含多个 bitonic_merge 单元
    // ========================================================================
    genvar grp, blk;
    generate
        for (grp = 0; grp < GROUP_NUM; grp = grp + 1) begin : gen_group
            localparam MERGE_SIZE = 2 << grp;                    // 2, 4, 8, 16, 32
            localparam MERGE_NUM  = DATA_NUM / MERGE_SIZE;       // 16, 8, 4, 2, 1

            // 调试信息：打印组参数
            initial begin
                $display("[bitonic_sort] Group %0d: MERGE_SIZE=%0d, MERGE_NUM=%0d", grp, MERGE_SIZE, MERGE_NUM);
            end

            // 每个组内的 merge 单元
            for (blk = 0; blk < MERGE_NUM; blk = blk + 1) begin : gen_merge
                // 全局ASCEND控制，默认ASCEND=1, 保持升序
                localparam BLOCK_ASCEND = (~(blk % 2)) ^ (~ASCEND);

                // 调试信息：打印每个merge单元参数
                initial begin
                    $display("[bitonic_sort]   Group %0d, Block %0d: ASCEND=%0d, data_range=[%0d:%0d]", 
                             grp, blk, BLOCK_ASCEND, 
                             blk*MERGE_SIZE*DATA_WIDTH, (blk+1)*MERGE_SIZE*DATA_WIDTH-1);
                end

                wire                          merge_din_valid;
                wire [MERGE_SIZE*DATA_WIDTH-1:0] merge_din;
                wire                          merge_dout_valid;
                wire [MERGE_SIZE*DATA_WIDTH-1:0] merge_dout;

                // 从组输入中提取当前 merge 单元的数据
                assign merge_din_valid = group_valid_in[grp];
                assign merge_din = group_data_in[grp][blk*MERGE_SIZE*DATA_WIDTH +: MERGE_SIZE*DATA_WIDTH];

                bitonic_merge #(
                    .DATA_NUM   (MERGE_SIZE),
                    .DATA_WIDTH (DATA_WIDTH),
                    .ASCEND     (BLOCK_ASCEND)
                ) u_bitonic_merge (
                    .clk             (clk),
                    .rst_n           (rst_n),
                    .din_array_valid (merge_din_valid),
                    .din_array       (merge_din),
                    .dout_array_valid(merge_dout_valid),
                    .dout_array      (merge_dout)
                );

                // 将 merge 单元的输出连接到组输出
                assign group_data_out[grp][blk*MERGE_SIZE*DATA_WIDTH +: MERGE_SIZE*DATA_WIDTH] = merge_dout;
            end

            // 取第一个 merge 单元的 valid 作为组输出 valid（所有 merge 单元延迟相同）
            assign group_valid_out[grp] = gen_merge[0].merge_dout_valid;

            // 组间连接：当前组输出连接到下一组输入
            if (grp < GROUP_NUM - 1) begin : gen_group_connect
                assign group_data_in[grp+1]  = group_data_out[grp];
                assign group_valid_in[grp+1] = group_valid_out[grp];
            end
            
        end
    endgenerate

    // ========================================================================
    // 输出
    // ========================================================================
    assign vld_out    = group_valid_out[GROUP_NUM-1];
    assign dout_array = group_data_out[GROUP_NUM-1];

endmodule
`resetall
