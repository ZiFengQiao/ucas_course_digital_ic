/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-30 00:27:37
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2025-12-30 00:30:32
 * @Description: Top module connecting AHB SRAM Controller with Altera SRAM
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module sram_ctr_ahb_top #(
    parameter DATA_WIDTH            = 32,
    parameter ADDR_WIDTH            = 32,
    parameter SRAM_ADDR_WIDTH       = 12,
    parameter SRAM_MAX_DEPTH        = 4096,
    parameter INIT_FILE             = ""
) (
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,

    // AHB Slave Interface
    input  wire [1:0]               htrans,
    input  wire [2:0]               hsize,
    input  wire [2:0]               hburst,
    input  wire [ADDR_WIDTH-1:0]    haddr,
    input  wire                     hwrite,
    input  wire [DATA_WIDTH-1:0]    hwdata,
    output wire [DATA_WIDTH-1:0]    hrdata,
    output wire                     hready,
    output wire [1:0]               hresp
);

    // ========================================================================
    // Internal Signals - SRAM Interface
    // ========================================================================
    wire                            sram_csn;
    wire                            sram_wen;
    wire [SRAM_ADDR_WIDTH-1:0]      sram_addr;
    wire [DATA_WIDTH-1:0]           sram_wdata;
    wire [DATA_WIDTH-1:0]           sram_rdata;

    // ========================================================================
    // AHB SRAM Controller Instance
    // ========================================================================
    sram_ctr_ahb #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .ADDR_WIDTH                 (ADDR_WIDTH),
        .SRAM_ADDR_WIDTH            (SRAM_ADDR_WIDTH)
    ) u_sram_ctr_ahb (
        // Clock and Reset
        .hclk                       (clk),
        .hresetn                    (rst_n),
        // AHB Slave Interface
        .htrans                     (htrans),
        .hsize                      (hsize),
        .hburst                     (hburst),
        .haddr                      (haddr),
        .hwrite                     (hwrite),
        .hwdata                     (hwdata),
        .hrdata                     (hrdata),
        .hready                     (hready),
        .hresp                      (hresp),
        // SRAM Interface
        .sram_csn                   (sram_csn),
        .sram_wen                   (sram_wen),
        .sram_a                     (sram_addr),
        .sram_d                     (sram_wdata),
        .sram_q                     (sram_rdata)
    );

    // ========================================================================
    // Altera SRAM Instance
    // ========================================================================
    altera_sram #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .ADDR_WIDTH                 (SRAM_ADDR_WIDTH),
        .MAX_DEPTH                  (SRAM_MAX_DEPTH),
        .INIT_FILE                  (INIT_FILE)
    ) u_altera_sram (
        // Clock and Reset
        .clk                        (clk),
        .rst_n                      (rst_n),

        // SRAM Interface
        .sram_cs_en_n               (sram_csn),
        .sram_wr_en_n               (sram_wen),
        .sram_addr                  (sram_addr),
        .sram_wdata                 (sram_wdata),
        .sram_rdata                 (sram_rdata)
    );

endmodule
`resetall