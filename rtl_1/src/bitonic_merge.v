/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-28 20:18:23
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-28 21:26:45
 * @Description: 
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module bitonic_merge #(
    parameter DATA_NUM                      = 32,
    parameter DATA_WIDTH                    = 8,
    parameter ASCEND                        = 1   // 1: 升序, 0: 降序
) (
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             din_array_valid,
    input  wire  [DATA_NUM*DATA_WIDTH-1:0]  din_array,
    output wire                             dout_array_valid,
    output wire  [DATA_NUM*DATA_WIDTH-1:0]  dout_array
);
    
    localparam STAGE_NUM = $clog2(DATA_NUM);  // 阶段数 = log2(DATA_NUM)
    localparam CAS_NUM = DATA_NUM / 2;        // 每阶段比较交换单元数 = DATA_NUM / 2

    // 顶层配置信息
    // 顶层配置信息
    initial begin
        $display("================================================================================");
        $display("[bitonic_merge] Configuration:");
        $display("[bitonic_merge]   DATA_WIDTH     = %0d bits", DATA_WIDTH);
        $display("[bitonic_merge]   DATA_NUM       = %0d elements", DATA_NUM);
        $display("[bitonic_merge]   STAGE_NUM      = %0d stages", STAGE_NUM);
        $display("[bitonic_merge]   ASCEND         = %0d", ASCEND);
        $display("================================================================================");
    end


    wire  [DATA_NUM*DATA_WIDTH-1:0] pipe_data_d [0:STAGE_NUM-1];

    reg   [DATA_NUM*DATA_WIDTH-1:0] pipe_data_q [0:STAGE_NUM-1];
    reg   [STAGE_NUM-1:0]           pipe_valid_q;

    genvar cas_idx;
    genvar block_idx;
    genvar stage_idx;
    generate
        for (stage_idx = 0; stage_idx < STAGE_NUM; stage_idx = stage_idx + 1) begin : gen_stages
            localparam CAS_STRIDE = 1 << (STAGE_NUM - 1 - stage_idx);  // 当前阶段比较交换单元跨度
            localparam BLOCK_NUM = DATA_NUM / (CAS_STRIDE * 2);        // 当前阶段块数

            // 调试信息：打印阶段参数
            initial begin
                $display("[bitonic_merge]   Stage %0d: CAS_STRIDE=%0d, BLOCK_NUM=%0d", 
                         stage_idx, CAS_STRIDE, BLOCK_NUM);
            end
            
            for (block_idx = 0; block_idx < BLOCK_NUM; block_idx = block_idx + 1) begin : gen_blocks
                localparam BLOCK_OFFSET = block_idx * CAS_STRIDE * 2;

                for (cas_idx = 0; cas_idx < CAS_STRIDE; cas_idx = cas_idx + 1) begin : gen_cas_units
                    
                    // 计算比较交换单元的输入输出索引
                    localparam idx_a = cas_idx + BLOCK_OFFSET;
                    localparam idx_b = cas_idx + BLOCK_OFFSET + CAS_STRIDE;

                    // 调试信息：打印比较交换单元索引
                    initial begin
                        $display("[bitonic_merge]     Stage %0d, Block %0d, CAS %0d: idx_a=%0d, idx_b=%0d",
                                 stage_idx, block_idx, cas_idx, idx_a, idx_b);
                    end

                    wire [DATA_WIDTH-1:0] i_a;
                    wire [DATA_WIDTH-1:0] i_b;
                    wire [DATA_WIDTH-1:0] o_a;
                    wire [DATA_WIDTH-1:0] o_b;

                    // 输入不缓存，输出缓存
                    if (stage_idx == 0) begin
                        assign i_a = din_array[(idx_a+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                        assign i_b = din_array[(idx_b+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                    end
                    else begin
                        assign i_a = pipe_data_q[stage_idx-1][(idx_a+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                        assign i_b = pipe_data_q[stage_idx-1][(idx_b+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                    end

                    sort_unit #(
                        .DATA_WIDTH (DATA_WIDTH),
                        .ASCEND     (ASCEND)
                    ) u_sort_unit (
                        .i_a        (i_a),
                        .i_b        (i_b),
                        .o_a        (o_a),
                        .o_b        (o_b)
                    );

                    assign pipe_data_d[stage_idx][(idx_a+1)*DATA_WIDTH-1 -: DATA_WIDTH] = o_a;
                    assign pipe_data_d[stage_idx][(idx_b+1)*DATA_WIDTH-1 -: DATA_WIDTH] = o_b;
                end
            end
        end
    endgenerate

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_valid_q <= {(STAGE_NUM){1'b0}};
            
            for (i = 0; i < STAGE_NUM; i = i + 1) begin
                pipe_data_q[i] <= {(DATA_NUM*DATA_WIDTH){1'b0}};
            end
        end else begin
            // 有效信号流水线
            pipe_valid_q <= pipe_valid_q << 1 | din_array_valid;

            // 数据流水线
            for (i = 0; i < STAGE_NUM; i = i + 1) begin
                pipe_data_q[i] <= pipe_data_d[i];
            end
        end
    end

    // stage_num级流水，输入不缓存，寄存器输出
    assign dout_array_valid = pipe_valid_q[STAGE_NUM-1];
    assign dout_array       = pipe_data_q[STAGE_NUM-1];
    
endmodule
`resetall