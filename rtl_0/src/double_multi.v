/*
 * @Author: Wang, Qiaoyu
 * @Date: 2026-02-27 13:34:52
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-03-01 19:33:21
 * @Description: ieee754 double precision floating point multiplier
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module double_multi #(
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         vld_in,
    input  wire [63:0]  data_a,
    input  wire [63:0]  data_b,
    output wire [63:0]  data_c,
    output wire         vld_out
);  

    reg  [4:0] vld_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vld_sync <= 'd0;
        end else begin
            vld_sync <= {vld_sync[3:0], vld_in};
        end
    end
    assign vld_out = vld_sync[4];


    // 解包
    wire         a_sign = data_a[63];
    wire  [10:0] a_exp  = data_a[62:52];
    wire  [51:0] a_man  = data_a[51:0];

    wire         b_sign = data_b[63];
    wire  [10:0] b_exp  = data_b[62:52];
    wire  [51:0] b_man  = data_b[51:0];

    // 5级流水线
    // 侵入式修改booth 乘法器流水线
    // stage 1: pre processing, 符号位计算，阶码计算，尾数预处理，异常标记
    // stage 1-3: 尾数乘法， 53*53, 将尾数预处理与booth乘法器的第一级，booth编码放到一拍
    // stage 4: 规格化与 Sticky Bit
    // stage 5: 舍入与异常封装
    
    // stage 1: 解包， 1bit 符号位， 11bit阶码， 52bit尾数
    // stage 1: booth 乘法器第一拍， booth编码
    reg          s1_sign_d, s1_sign_q;
    reg  [12:0]  s1_exp_d, s1_exp_q; // 扩展1bit避免乘法溢出
    // 尾数预处理，隐含1位，扩展1bit避免乘法溢出
    reg  [52:0]  s1_a_ma;
    reg  [52:0]  s1_b_ma;
    // zlc计算， 进行MSB预测
    wire [5:0]   s1_a_ma_zlc_cnt_d, s1_b_ma_zlc_cnt_d;
    reg  [5:0]   s1_a_ma_zlc_cnt_q, s1_b_ma_zlc_cnt_q;
    wire         s1_a_ma_zlc_cnt_vld_d, s1_b_ma_zlc_cnt_vld_d;
    reg          s1_a_ma_zlc_cnt_vld_q, s1_b_ma_zlc_cnt_vld_q;

    always @(*) begin
        // 计算符号位
        s1_sign_d = a_sign ^ b_sign;
        // 计算阶码
        s1_exp_d  = {1'b0, (a_exp == 'd0) ? 1'b1 : a_exp}
            + {1'b0, (b_exp == 'd0) ? 1'b1 : b_exp}
            - 11'd1023;
        // 根据阶码补全尾数的隐含1位和扩展位
        s1_a_ma   = {|a_exp, a_man};
        s1_b_ma   = {|b_exp, b_man};
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s1_sign_q <= 1'b0;
            s1_exp_q  <= 12'h0;
            s1_a_ma_zlc_cnt_q <= 6'd0;
            s1_a_ma_zlc_cnt_vld_q <= 1'd0;
            s1_b_ma_zlc_cnt_q <= 6'd0;
            s1_b_ma_zlc_cnt_vld_q <= 1'd0;
        end else begin
            s1_sign_q <= s1_sign_d;
            s1_exp_q  <= s1_exp_d;
            s1_a_ma_zlc_cnt_q <= s1_a_ma_zlc_cnt_d;
            s1_a_ma_zlc_cnt_vld_q <= s1_a_ma_zlc_cnt_vld_d;
            s1_b_ma_zlc_cnt_q <= s1_b_ma_zlc_cnt_d;
            s1_b_ma_zlc_cnt_vld_q <= s1_b_ma_zlc_cnt_vld_d;
        end
    end

    // stage 1-4: 异常结果标志
    reg         zero_temp;
    reg         inf_temp;
    reg [3:0]   flag_res_is_zero;
    reg [3:0]   flag_res_is_nan;
    reg [3:0]   flag_res_is_inf;


    integer i;
    always @(*) begin
        zero_temp = ((a_exp == 11'd0) && (a_man == 52'd0)) || ((b_exp == 11'd0) && (b_man == 52'd0));
        inf_temp = ((a_exp == 11'h7FF) && (a_man == 52'd0)) || ((b_exp == 11'h7FF) && (b_man == 52'd0));
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flag_res_is_zero <= 'd0;
            flag_res_is_nan  <= 'd0;
            flag_res_is_inf  <= 'd0;
        end else begin
            //stage 1
            flag_res_is_zero[0] <= zero_temp;
            flag_res_is_inf[0]  <= inf_temp;

            // inf * zero 结果是nan
            flag_res_is_nan[0]  <= ((a_exp == 11'h7FF) && (a_man != 52'd0))
                || ((b_exp == 11'h7FF) && (b_man != 52'd0))
                || (zero_temp & inf_temp);
            
            // stage 2-4，打拍
            for (i = 1; i < 4; i = i + 1) begin
                flag_res_is_zero[i] <= flag_res_is_zero[i-1];
                flag_res_is_inf[i]  <= flag_res_is_inf[i-1];
                flag_res_is_nan[i]  <= flag_res_is_nan[i-1];
            end
        end
    end


    // stage 1: 64 bit zlc
    lzc # (
        .WIDTH(53)
    )
    lzc_inst_a (
        .data_in(s1_a_ma),
        .cnt_valid(s1_a_ma_zlc_cnt_vld_d),
        .cnt(s1_a_ma_zlc_cnt_d)
    );

    lzc # (
        .WIDTH(53)
    )
    lzc_inst_b (
        .data_in(s1_b_ma),
        .cnt_valid(s1_b_ma_zlc_cnt_vld_d),
        .cnt(s1_b_ma_zlc_cnt_d)
    );

    // stage 1-3: 尾数乘法， 53*53, 使用64bit的booth乘法器
    wire  [105:0] s3_ma_product; // 106bit，乘积最高位可能是1，最低位可能是0

    booth_multi # (
        .DATA_WIDTH(64)
    )
    booth_multi_inst (
        .clk       (clk),
        .rst       (rst),
        .vld_in    (vld_sync[1]),
        .data_a    ({11'b0, s1_a_ma}),
        .data_b    ({11'b0, s1_b_ma}),
        .data_c    (s3_ma_product),
        .vld_out   ()
    );

    // stage 2: 得到初步偏移量预测值, 纠正阶码
    reg         s2_sign_reg;
    reg [12:0]  s2_exp_reg;
    reg [6:0]   s2_shift_pre_d, s2_shift_pre_q;

    always @(*) begin
        // 预测偏移为前导0相加
        s2_shift_pre_d = 'd0;
        if (s1_a_ma_zlc_cnt_vld_q && s1_b_ma_zlc_cnt_vld_q) begin
            s2_shift_pre_d = s1_a_ma_zlc_cnt_q + s1_b_ma_zlc_cnt_q;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s2_sign_reg    <= 1'b0;
            s2_exp_reg     <= 13'd0;
            s2_shift_pre_q <= 7'd0;
        end else begin
            s2_sign_reg    <= s1_sign_q;
            s2_exp_reg     <= s1_exp_q;
            s2_shift_pre_q <= s2_shift_pre_d;
        end
    end

    // stage 3: 同步
    reg         s3_sign_reg;
    reg [6:0]   s3_shift_pre_reg;
    // exp 预测值
    reg [12:0]  s3_exp_pre_d, s3_exp_pre_q;
    reg [7:0]   s3_subnormal_shr_d, s3_subnormal_shr_q; // 7bit 以保证符号数

    always @(*) begin
        s3_exp_pre_d = s2_exp_reg - {1'b0, s2_shift_pre_q}; // 拓展为符号数
        s3_subnormal_shr_d = 0;

        if ($signed(s2_exp_reg) < 0 && $signed(s2_exp_reg) > -13'd53) begin
            s3_subnormal_shr_d = - $signed(s2_exp_reg);
            
            s3_exp_pre_d = 'sd0;
        end

    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 传递
            s3_sign_reg <= 1'b0;
            s3_shift_pre_reg <= 'd0;
            // 计算
            s3_exp_pre_q <= 'd0;
            s3_subnormal_shr_q <= 'd0;
            // // 边界预测
            // flag_res_overflow <= 'd0;
            // flag_res_underflow <= 'd0;
        end else begin
            // 传递
            s3_sign_reg <= s2_sign_reg;
            s3_shift_pre_reg <= s2_shift_pre_q;
            // 计算
            s3_exp_pre_q <= s3_exp_pre_d;
            s3_subnormal_shr_q <= s3_subnormal_shr_d;
        end
    end

    // Stage 4: Normalize & Sticky
    //          路径1, 输出为规格数
    //          路径2, 输出为非规格数
    reg         s4_sign_reg;
    reg [12:0]  s4_exp_pre_reg;

    
    // stage 4: 路径2, 非规格数，右移
    reg         s4_is_sub_temp;
    reg         s4_is_sub_reg;
    reg         s4_is_renorm_reg, s4_is_renorm_temp;
    reg         s4_drop_reduce_or_reg;

    // stage 4: 路径1
    reg [105:0] s4_prod_reg;
    reg [105:0] s4_prod_temp_path_0, s4_prod_temp_path_1;

    always @(*) begin
        // subnormal judge
        s4_is_sub_temp = (s3_subnormal_shr_q > 0);
        s4_is_renorm_temp = (s3_exp_pre_q == 'd0) && !s4_is_sub_temp; // 需要重新规格化的条件：预测阶码为0且不是非规格数
        // shift of 2 path
        s4_prod_temp_path_0 = s3_ma_product << s3_shift_pre_reg;
        s4_prod_temp_path_1 = s3_ma_product >> s3_subnormal_shr_q;
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s4_sign_reg <= 1'b0;
            s4_prod_reg <= 0;
            s4_exp_pre_reg <= 0;
            s4_is_sub_reg <= 'd0;
            s4_drop_reduce_or_reg <= 'd0;
            s4_is_renorm_reg <= 'd0;
        end else begin
            s4_sign_reg <= s3_sign_reg;
            // exp
            s4_exp_pre_reg <= s3_exp_pre_q;
            // product
            s4_prod_reg <= s4_is_sub_temp ? s4_prod_temp_path_1 : s4_prod_temp_path_0;
            s4_is_sub_reg <= s4_is_sub_temp;
            s4_is_renorm_reg <= s4_is_renorm_temp;
            // shift drop reduce
            s4_drop_reduce_or_reg <= | (s3_ma_product << (106 - s3_subnormal_shr_q)); // 计算被右移丢弃的位是否有1，用于sticky bit
        end
    end

    // stage 5: 舍入与异常封装
    reg [63:0]  data_c_reg;
    // =========================================================
    // 双路径并行计算

    // --- 路径 A: 假设 MSB 在第 105 位 (无需额外左移) ---
    wire [51:0] s5_f_a         = s4_prod_reg[104:53];
    wire        s5_l_a         = s4_prod_reg[53];
    wire        s5_g_a         = s4_prod_reg[52];
    wire        s5_r_a         = s4_prod_reg[51];
    wire        s5_s_a         = |s4_prod_reg[50:0] || (s4_is_sub_reg && s4_drop_reduce_or_reg); // Sticky Bit A
    wire        s5_round_up_a  = s5_g_a & (s5_r_a | s5_s_a | s5_l_a);

    // 并行加法 A
    wire [52:0] s5_f_rnd_a     = {1'b0, s5_f_a} + s5_round_up_a;
    wire        s5_rnd_ovf_a   = s5_f_rnd_a[52];
    wire [12:0] s5_exp_norm_a  = s4_exp_pre_reg + 1'b1;                 // 阶码加一

    // 结果 A 封装， 舍入后溢出处理
    wire [51:0] s5_final_f_a   = s5_rnd_ovf_a ? 52'b0 : s5_f_rnd_a[51:0];
    
    wire [12:0] s5_final_exp_a = s5_rnd_ovf_a ? (s5_exp_norm_a + 1'b1) : 
                                 s4_is_sub_reg ? s4_exp_pre_reg : s5_exp_norm_a;

    // --- 路径 B: 假设 MSB 在第 104 位 (需要额外左移 1 位) ---
    // 注意：此时 L,G,R,S 位都要跟着左移一位提取
    wire [51:0] s5_f_b         = s4_prod_reg[103:52];
    wire        s5_l_b         = s4_prod_reg[52];
    wire        s5_g_b         = s4_prod_reg[51];
    wire        s5_r_b         = s4_prod_reg[50];
    wire        s5_s_b         = |s4_prod_reg[49:0]; // Sticky Bit B
    wire        s5_round_up_b  = s5_g_b & (s5_r_b | s5_s_b | s5_l_b);

    // 并行加法 B
    wire [52:0] s5_f_rnd_b     = {1'b0, s5_f_b} + s5_round_up_b;
    wire        s5_rnd_ovf_b   = s5_f_rnd_b[52];
    wire [12:0] s5_exp_norm_b  = s4_exp_pre_reg;            // 阶码不变

    // 结果 B 封装， 舍入后溢出处理
    wire [51:0] s5_final_f_b   = s5_rnd_ovf_b ? 52'b0 : s5_f_rnd_b[51:0];
    wire [12:0] s5_final_exp_b = s5_rnd_ovf_b ? (s5_exp_norm_b + 1'b1) : s5_exp_norm_b;


    // 根据最高位选择，当默认输出是向右位移的非规格数时，路径A（完成隐含的向右移位，对应非规格数的实际阶码为1）
    wire s5_exp_select         = s4_prod_reg[105] || s4_is_sub_reg;
    // 重新进行规格化时，最高位不是1, 选择通道a的尾码（省略通道1对阶码的增加， 因为非规格数冲规格化为规格数需要两次阶码+1）
    wire s5_f_select           = s4_prod_reg[105] || s4_is_sub_reg || (!s4_prod_reg[105] && s4_is_renorm_reg && !s5_rnd_ovf_b);

    wire [12:0] s5_mux_exp     = s5_exp_select ? s5_final_exp_a : s5_final_exp_b;
    wire [51:0] s5_mux_f       = s5_f_select   ? s5_final_f_a   : s5_final_f_b;

    // 异常封装与最终输出Mux
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_c_reg <= 64'd0;
        end else begin
            if (flag_res_is_nan[3]) begin
                // NaN: 指数全1，尾数不为0 (Quiet NaN)
                data_c_reg <= {s4_sign_reg, 11'h7FF, 1'b1, 51'd0};
            end 
            else if (flag_res_is_zero[3] || $signed(s5_mux_exp) < 0) begin
                // Zero: 下溢到底
                data_c_reg <= {s4_sign_reg, 11'd0, 52'd0};
            end 
            else if (flag_res_is_inf[3] || (s5_mux_exp >= 12'd2047)) begin
                // Infinity: 指数全1，尾数全0
                data_c_reg <= {s4_sign_reg, 11'h7FF, 52'd0};
            end 
            else if (s4_is_sub_reg && s5_mux_exp == 12'd0) begin
                // 非规格化数: 指数位 0，尾数不补隐含1
                data_c_reg <= {s4_sign_reg, 11'd0, s5_mux_f};
            end 
            else begin
                // 规格化数封装
                data_c_reg <= {s4_sign_reg, s5_mux_exp[10:0], s5_mux_f};
            end
        end
    end

    assign data_c = data_c_reg;
endmodule
`resetall
