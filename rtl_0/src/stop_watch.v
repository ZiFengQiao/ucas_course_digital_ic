/*
 * @Description: 跑表时序逻辑电路
 * @Features: 
 *   - 时分秒显示 (HH:MM:SS)
 *   - Clear按钮：清零并停止
 *   - Start/Stop按钮：开始/暂停切换
 *   - 系统时钟：10MHz
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none
`define SIM_MODE

module stop_watch (
    input  wire        clk,          // 10MHz系统时钟
    input  wire        rst_n,        // 异步复位，低电平有效
    input  wire        clear,        // 上升沿有效
    input  wire        start_stop,   // 上升沿有效
    // 时显示输出
    output wire [3:0]  hr_h,         // 小时十位
    output wire [3:0]  hr_l,         // 小时个位
    // 分显示输出
    output wire [3:0]  min_h,        // 分钟十位
    output wire [3:0]  min_l,        // 分钟个位
    // 秒显示输出
    output wire [3:0]  sec_h,        // 秒十位
    output wire [3:0]  sec_l         // 秒个位
);
    // 10MHz时钟分频到1Hz (每秒产生一个脉冲)
    // 10,000,000个时钟周期 = 1秒
    
    `ifdef SIM_MODE
        localparam CNT_1S = 100;            // 仿真加速
    `else
        localparam CNT_1S = 100_000_000;
    `endif

    // 按键信号视为异步信号，打拍
    // 如果进行消抖，需要额外分频一个时钟周期在5ms左右的消抖采样时钟
    reg  clear_reg1, clear_reg2, clear_sync_reg1, clear_sync_reg2;
    reg  start_stop_reg1, start_stop_reg2, start_stop_sync_reg1, start_stop_sync_reg2;

    reg  sig_clear_reg;
    wire sig_clear = sig_clear_reg;

    wire sig_start_stop = start_stop_sync_reg1 & ~start_stop_sync_reg2;

    // 运行状态
    reg  status_run_q;   // 1: 计时中, 0: 暂停
    
    // 1秒计数器
    reg [23:0] cnt_1s;
    wire       tick_1s;  // 1秒脉冲
    
    // 时分秒寄存器
    reg [3:0]  sec_l_reg;
    reg [3:0]  sec_h_reg;
    reg [3:0]  min_l_reg;
    reg [3:0]  min_h_reg;
    reg [3:0]  hr_l_reg;
    reg [3:0]  hr_h_reg;
    
    // 按键同步
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_reg1 <= 1'b0;
            clear_reg2 <= 1'b0;
            clear_sync_reg1 <= 1'b0;
            clear_sync_reg2 <= 1'b0;
            start_stop_reg1 <= 1'b0;
            start_stop_reg2 <= 1'b0;
            start_stop_sync_reg1 <= 1'b0;
            start_stop_sync_reg2 <= 1'b0;
        end
        else begin
            // Clear按钮同步
            clear_reg1 <= clear;
            clear_reg2 <= clear_reg1;
            clear_sync_reg1 <= clear_reg2;
            clear_sync_reg2 <= clear_sync_reg1;
            // Start/Stop按钮同步
            start_stop_reg1 <= start_stop;
            start_stop_reg2 <= start_stop_reg1;
            start_stop_sync_reg1 <= start_stop_reg2;
            start_stop_sync_reg2 <= start_stop_sync_reg1;
        end
    end
    
    // clear信号拖尾
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sig_clear_reg <= 1'b0;
        end
        else begin
            if (clear_sync_reg1 & ~clear_sync_reg2) begin
                sig_clear_reg <= 1'b1;
            end
            else if (~clear_sync_reg1 & ~clear_sync_reg2) begin
                sig_clear_reg <= 1'b0;
            end
            else begin
                sig_clear_reg <= sig_clear_reg;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_run_q <= 1'b0;
        end
        else begin
            if (sig_clear) begin
                status_run_q <= 1'b0;
            end
            else if (sig_start_stop) begin
                status_run_q <= ~status_run_q;
            end
        end
    end
    
    // cnt_1s
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1s <= 24'd0;
        end
        else begin
            if (sig_clear || !status_run_q) begin
                cnt_1s <= 24'd0;
            end
            else if (cnt_1s >= CNT_1S - 1) begin
                cnt_1s <= 24'd0;
            end
            else begin
                cnt_1s <= cnt_1s + 1'b1;
            end
        end
    end
    
    assign tick_1s = (cnt_1s == CNT_1S - 1) && status_run_q;
    
    // sec_l_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_l_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                sec_l_reg <= 4'd0;
            end
            else if (tick_1s) begin
                if (sec_l_reg >= 4'd9) begin
                    sec_l_reg <= 4'd0;
                end
                else begin
                    sec_l_reg <= sec_l_reg + 1'b1;
                end
            end
        end
    end

    // sec_h_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_h_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                sec_h_reg <= 4'd0;
            end
            else if (tick_1s && sec_l_reg >= 4'd9) begin
                if (sec_h_reg >= 4'd5) begin
                    sec_h_reg <= 4'd0;
                end
                else begin
                    sec_h_reg <= sec_h_reg + 1'b1;
                end
            end
        end
    end
    
    // min_l_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_l_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                min_l_reg <= 4'd0;
            end
            else if (tick_1s && sec_l_reg >= 4'd9 && sec_h_reg >= 4'd5) begin
                if (min_l_reg >= 4'd9) begin
                    min_l_reg <= 4'd0;
                end
                else begin
                    min_l_reg <= min_l_reg + 1'b1;
                end
            end
        end
    end
    
    // min_h_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_h_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                min_h_reg <= 4'd0;
            end
            else if (tick_1s && sec_l_reg >= 4'd9 && sec_h_reg >= 4'd5 && min_l_reg >= 4'd9) begin
                if (min_h_reg >= 4'd5) begin
                    min_h_reg <= 4'd0;
                end
                else begin
                    min_h_reg <= min_h_reg + 1'b1;
                end
            end
        end
    end
    
    // hr_l_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hr_l_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                hr_l_reg <= 4'd0;
            end
            else if (tick_1s && sec_l_reg >= 4'd9 && sec_h_reg >= 4'd5 && 
                         min_l_reg >= 4'd9 && min_h_reg >= 4'd5) begin
                if (hr_h_reg >= 4'd2 && hr_l_reg >= 4'd3) begin
                    hr_l_reg <= 4'd0;
                end
                else if (hr_l_reg >= 4'd9) begin
                    hr_l_reg <= 4'd0;
                end
                else begin
                    hr_l_reg <= hr_l_reg + 1'b1;
                end
            end
        end
    end
    
    // hr_h_reg
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hr_h_reg <= 4'd0;
        end
        else begin
            if (sig_clear) begin
                hr_h_reg <= 4'd0;
            end
            else if (tick_1s && sec_l_reg >= 4'd9 && sec_h_reg >= 4'd5 && 
                         min_l_reg >= 4'd9 && min_h_reg >= 4'd5) begin
                if (hr_h_reg >= 4'd2 && hr_l_reg >= 4'd3) begin
                    hr_h_reg <= 4'd0;
                end
                else if (hr_l_reg >= 4'd9) begin
                    hr_h_reg <= hr_h_reg + 1'b1;
                end
            end
        end
    end
    
    assign sec_l = sec_l_reg;
    assign sec_h = sec_h_reg;
    assign min_l = min_l_reg;
    assign min_h = min_h_reg;
    assign hr_l  = hr_l_reg;
    assign hr_h  = hr_h_reg;

endmodule
`resetall
