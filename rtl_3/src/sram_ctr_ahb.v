/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-29 14:15:05
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-04 14:16:52
 * @Description: AHB Interface for SRAM Controller
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none
module sram_ctr_ahb #(
    parameter DATA_WIDTH                = 32,
    parameter ADDR_WIDTH                = 32,
    parameter SRAM_ADDR_WIDTH           = 12
) (
    input  wire                         hclk,       // clk, same as the sram clock
    input  wire                         hresetn,    // reset, low active
    // AHB Slave Interface
    input  wire [1:0]                   htrans,     // AHB Transaction Type, 00: IDLE, 01: BUSY, 10: NONSEQ, 11: SEQ
    input  wire [2:0]                   hsize,      // AHB Transfer Size, 000: 1 byte, 001: 2 byte, 010: 4 byte
    // 由于要求的SRAM接口并没有提供strobe信号，因此暂时不考虑byte/halfword的读写
    // 否则每一拍写入数据需要经过先读后写的操作。
    // 假设addr按照32bit对齐，size默认为010
    input  wire [2:0]                   hburst,     // AHB burst type
    input  wire [ADDR_WIDTH-1:0]        haddr,      // AHB address
    input  wire                         hwrite,     // AHB write signal
    input  wire [DATA_WIDTH-1:0]        hwdata,     // AHB write data
    output wire [DATA_WIDTH-1:0]        hrdata,     // AHB read data
    output wire                         hready,     // AHB ready signal
    output wire [1:0]                   hresp,      // AHB response
    // SRAM Interface
    output wire                         sram_csn,   // sram chip select, low active
    output wire                         sram_wen,   // sram write enable, low active
    output wire [SRAM_ADDR_WIDTH-1:0]   sram_a,     // sram addr
    output wire [DATA_WIDTH-1:0]        sram_d,     // write data
    input  wire [DATA_WIDTH-1:0]        sram_q      // read data
);
    // AHB
    localparam AHB_TRANS_NON_SEQ = 2'b10;
    localparam AHB_TRANS_SEQ     = 2'b11;
    // 读写控制
    reg [SRAM_ADDR_WIDTH-1:0]    mem_addr_d, mem_addr_q;    // 12
    reg                          mem_rd_en_d, mem_rd_en_q;  // 1
    reg                          mem_wr_en_d, mem_wr_en_q;  // 1
    reg [1:0]                    hresp_d, hresp_q;          // 2 -> 1, 低位不变，被优化掉了
    reg                          hready_d, hready_q;        // 1

    // sram ctrl
    assign sram_a   = mem_rd_en_d ? mem_addr_d : mem_addr_q;    // 超前读
    assign sram_csn = ~(mem_rd_en_d | mem_wr_en_q);             // 超前读，延迟写
    assign sram_wen = ~mem_wr_en_q;
    assign sram_d   = hwdata;

    assign hresp    = hresp_q;
    assign hready   = hready_q;
    assign hrdata   = mem_rd_en_q ? sram_q : {DATA_WIDTH{1'b0}};

    // 读数据保存
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            mem_addr_q  <= {SRAM_ADDR_WIDTH{1'b0}};
            mem_rd_en_q <= 1'b0;
            mem_wr_en_q <= 1'b0;
            hresp_q     <= 2'b00;
            hready_q    <= 1'b1;
        end
        else begin
            mem_addr_q  <= mem_addr_d;
            mem_rd_en_q <= mem_rd_en_d;
            mem_wr_en_q <= mem_wr_en_d;
            hresp_q     <= hresp_d;
            hready_q    <= hready_d;
        end
    end

    // 控制逻辑
    always @(*) begin
        mem_rd_en_d = 1'b0;
        mem_wr_en_d = 1'b0;
        
        hresp_d     = 2'b00;      // OKAY
        hready_d    = 1'b1;       // default ready
        mem_addr_d  = mem_addr_q; // default hold address
        
        if (htrans[1] == 1'b1 && hready_q) begin
            // ready 前，输入保持数据
            mem_addr_d = haddr[SRAM_ADDR_WIDTH-1:0];
            if (hwrite == 1'b1) begin
                mem_wr_en_d = 1'b1;
            end
            else begin
                mem_rd_en_d = 1'b1;
            end
        end

        if ((haddr >> SRAM_ADDR_WIDTH) > 0) begin
            // 地址越界
            // 2-cycle ERROR response
            mem_rd_en_d  = 1'b0;
            mem_wr_en_d  = 1'b0;
            hresp_d      = 2'b10; // ERROR
            hready_d     = 1'b0;
        end
    end
endmodule
`resetall