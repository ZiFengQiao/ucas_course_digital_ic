/*
 * @Author: Wang, Qiaoyu
 * @Date: 2025-12-29 23:48:48
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-03 14:49:52
 * @Description: Altera Simple Dual Port RAM Wrapper
 *               Port A: Write only
 *               Port B: Read only
 */


`resetall
`timescale 1ns / 1ps
`default_nettype none

module altera_sram #(
    parameter DATA_WIDTH     = 8,
    parameter ADDR_WIDTH     = 11,
    parameter MAX_DEPTH      = 2048,
    parameter INIT_FILE      = ""
) (
    // Clock and Reset
    input  wire                      clk,
    input  wire                      rst_n,

    // SRAM Interface
    input  wire                      sram_cs_en_n,   // sram chip select, low active
    input  wire                      sram_wr_en_n,   // sram write enable, low active
    input  wire [ADDR_WIDTH-1:0]     sram_addr,      // sram addr
    input  wire [DATA_WIDTH-1:0]     sram_wdata,     // write data
    output wire [DATA_WIDTH-1:0]     sram_rdata      // read data
);
    // ========================================================================
    // Internal Signals
    // ========================================================================
    wire clk_en;
    wire aclr;
    wire wr_en;
    wire rd_en;

    assign clk_en = 1'b1;
    assign aclr   = ~rst_n;

    // cs_en_n = 0 且 wr_en_n = 0 时写入
    assign wr_en  = ~sram_cs_en_n & ~sram_wr_en_n;
    // cs_en_n = 0 且 wr_en_n = 1 时读取
    assign rd_en  = ~sram_cs_en_n &  sram_wr_en_n;

    // ========================================================================
    // Altera Simple Dual Port RAM Instance
    // ========================================================================
    simple_dual_port_ram #(
        // Clock Enable Settings
        .IN_CLOCK_EN_A                      ("NORMAL"),
        .IN_CLOCK_EN_B                      ("NORMAL"),
        .OUT_CLOCK_EN_B                     ("NORMAL"),

        // Port A Parameters (Write)
        .DATA_WIDTH_A                       (DATA_WIDTH),
        .ADDR_WIDTH_A                       (ADDR_WIDTH),
        .BYTE_EN_WIDTH_A                    (DATA_WIDTH/8),

        // Port B Parameters (Read)
        .DATA_WIDTH_B                       (DATA_WIDTH),
        .ADDR_WIDTH_B                       (ADDR_WIDTH),

        // Output Register Settings
        .OUT_DATA_REG_CLK_B                 ("UNREGISTERED"),
        .ADDR_REG_CLK_B                     ("CLOCK0"),
        .RDCONTROL_REG_B                    ("CLOCK0"),
        .BYTEENA_REG_B                      ("CLOCK0"),

        // Clear Settings
        .OUT_DATA_ACLR_B                    ("CLEAR0"),
        .OUT_DATA_SCLR_B                    ("CLEAR0"),
        .ADDR_ACLR_B                        ("CLEAR0"),

        // Mixed Port Read-During-Write Mode
        .READ_DURING_WRITE_MODE_MIXED_PORTS ("DONT_CARE"),

        // Memory Initialization
        .INIT_FILE                          (INIT_FILE),
        .INIT_FILE_LAYOUT                   ("PORT_A"),

        // Memory Size
        .MAX_DEPTH                          (MAX_DEPTH),
        .BYTE_SIZE                          (8)
    ) u_simple_dual_port_ram (
        // Clocks
        .clock0                             (clk),
        .clock1                             (1'b0),

        // Clock Enables
        .clocken0                           (clk_en),
        .clocken1                           (1'b0),

        // Asynchronous/Synchronous Clears
        .aclr0                              (aclr),
        .aclr1                              (1'b0),
        .sclr                               (1'b0),

        // Port A - Write Interface
        .data_a                             (sram_wdata),
        .address_a                          (sram_addr),
        .wren_a                             (wr_en),
        .byteena_a                          ({(DATA_WIDTH/8){1'b1}}),
        .addressstall_a                     (1'b0),

        // Port B - Read Interface
        .address_b                          (sram_addr),
        .rden_b                             (rd_en),
        .q_b                                (sram_rdata),
        .addressstall_b                     (1'b0)
    );
endmodule
`resetall