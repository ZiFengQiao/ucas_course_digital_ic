/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-11-14 00:14:26
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-11-15 17:20:31
 * @Description: 用于32位输入的优先编码器, PE32(4, 8)，默认高位优先
 */
`resetall
`timescale 1ns / 1ps
`default_nettype none

module priority_encoder_32 #(
    parameter DATA_IN_WIDTH         = 32,
    parameter POS_OUT_WIDTH         = $clog2(DATA_IN_WIDTH),
    // 1'b1表示将输入反转，反转优先级
    parameter DATA_IN_REVERSE       = 1'b0,
    // 1'b1表示位置由高位向低位编码
    parameter POS_DIRECTION         = 1'b1,
    parameter POS_DEFAULT           = {1'b1, {POS_OUT_WIDTH{1'b0}}}
) (
    input  wire [DATA_IN_WIDTH-1:0] data_in,
    output wire [POS_OUT_WIDTH:0]   pos_out
);
    // TOP PE 参数
    localparam TOP_PE_WIDTH         = 8;                            // TOP PE的输入宽度
    localparam TOP_OR_WIDTH         = DATA_IN_WIDTH / TOP_PE_WIDTH; // TOP将数据分成几块
    localparam TOP_POS_WIDTH        = $clog2(TOP_PE_WIDTH);         // 块间对应的编码位数
    localparam TOP_POS_OFFSET       = $clog2(TOP_OR_WIDTH);         // 块内对应的编码位数
    
    wire [TOP_PE_WIDTH-1:0]         pe_top_dor;
    wire [TOP_POS_WIDTH-1:0]        pe_top_pos_out;
    wire                            pe_top_pos_valid;

    // BOTTOM PE 参数
    localparam BOTTOM_PE_WIDTH      = 4;                            // BOTTOM PE的输入宽度， 等于块内宽度
    localparam BOTTOM_POS_WIDTH     = $clog2(BOTTOM_PE_WIDTH);
    wire [BOTTOM_POS_WIDTH-1:0]     pe_bottom_pos_out;

    // MUX 参数
    localparam MUX_INPUT_NUM        = TOP_PE_WIDTH;
    localparam MUX_INPUT_WIDTH      = BOTTOM_PE_WIDTH;
    wire [MUX_INPUT_WIDTH-1:0]      mux_data_out;
    
    // 输入数据预处理， pre processed
    wire [DATA_IN_WIDTH-1:0]        data_in_pp;

    // 循环变量
    genvar i;

    // pp
    generate
        if (DATA_IN_REVERSE) begin
            // 翻转输入数据
            for (i = 0; i < DATA_IN_WIDTH; i = i + 1) begin : gen_reverse_loop
                assign data_in_pp[i] = data_in[DATA_IN_WIDTH - 1 - i];
            end
        end
        else begin
            assign data_in_pp = data_in;
        end
    endgenerate

    // DOR
    generate
        for (i = 0; i < TOP_PE_WIDTH; i = i + 1) begin
            assign pe_top_dor[i] = |data_in_pp[i*TOP_OR_WIDTH +: TOP_OR_WIDTH];
        end
    endgenerate

    // top pe
    priority_encoder_8 #(
        .POS_DIRECTION     (POS_DIRECTION),
        .VALID_ENABLE      (1'b1)
    ) pe_8_inst_0 (
        .data_in           (pe_top_dor),
        .pos_out           (pe_top_pos_out),
        .pos_valid         (pe_top_pos_valid)
    );

    // mux
    priority_encoder_mux # (
        .MUX_INPUT_NUM     (MUX_INPUT_NUM),
        .MUX_INPUT_WIDTH   (MUX_INPUT_WIDTH)
    )
    priority_encoder_mux_inst (
        .mux_dor           (pe_top_dor),
        .mux_data_in       (data_in_pp),
        .mux_data_out      (mux_data_out)
    );

    // bottom pe
    priority_encoder_4 #(
        .POS_DIRECTION     (POS_DIRECTION),
        .VALID_ENABLE      (0)
    ) u_priority_encoder_4 (
        .data_in           (mux_data_out),
        .pos_out           (pe_bottom_pos_out),
        .pos_valid         ()
    );

    // output
    assign pos_out = pe_top_pos_valid ? {1'b0, pe_top_pos_out, pe_bottom_pos_out} : POS_DEFAULT;           
endmodule
`resetall