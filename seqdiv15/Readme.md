<!--
 * @Author: Wang, Qiaoyu
 * @Date: 2026-01-27 16:03:27
 * @LastEditors: Wang, Qiaoyu
 * @LastEditTime: 2026-01-27 16:19:22
 * @Description: 
-->
# 中国科学院大学《高等数字集成电路分析与设计》2025秋季学期考题回忆

2025年秋季学期考题回忆，考试时间两个半小时。

## 简单题
1. VLSI降低静态功耗、动态功耗的方法；

2. 比较三种存储资源，DFF、SRAM、DRAM的优缺点；

3. 6bit二进制转格雷码; 6bit格雷码转二进制; 转化为格雷码后汉明距离不变的5bit二进制;

4. setup slack 、 hold slack 计算； 若违例，合法频率是多少；

5. 支持重叠，不定长度的序列检测的FSM状态转移图。检测序列 1(01)*1， 合法序列如 11, 1011, 101011 
   
6. 描述IEEE754 双精度浮点数的格式；比较定点和浮点硬件设计的优缺点；

7. 简述同步开关噪声（SSN）和地弹（Ground Bounce）；如何减小影响；

8. -2025的原码和补码； 2025的基4 Booth编码结果；

## 设计题

1. （手写verilog）设计16bit低位优先的仲裁器。（原文描述为，输出lsb之后的序列，高位为0）如输入1111_0000_0100_0100 输出0000_0000_0000_0100 
``` verilog
`resetall
`timescale 1ns / 1ps
`default_nettype none

module lowbit #(
) (
    input  wire  [15:0] request,
    input  wire  [15:0] grant
);

    wire [3:0]  request_or;
    wire [15:0] pe4_out;
    wire [3:0]  block_grant;
    
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_request_or
            assign request_or[i] = |request[i*4 +: 4];

            pe_4 u_pe4 (
                .in(request[i*4 +: 4]),
                .out(pe4_out[i*4 +: 4])
            );
        end
        pe_4 u_pe4_block (
            .in(request_or),
            .out(block_grant)
        );
    endgenerate
    
    assign grant = (block_grant[0]) ? (pe4_out[3:0] << 0) :
                   (block_grant[1]) ? (pe4_out[7:4] << 4) :
                   (block_grant[2]) ? (pe4_out[11:8] << 8) :
                   (block_grant[3]) ? (pe4_out[15:12] << 12) :
                   16'b0;
endmodule
`resetall

`resetall
`timescale 1ns / 1ps
`default_nettype none

module pe_4 #(
) (
    input  wire  [3:0] in,
    input  wire  [3:0] out
);

    reg  [3:0] out_temp;
    
    always @(*) begin
        casex (in)
            4'bxxx1: out_temp = 4'b0001;
            4'bxx10: out_temp = 4'b0010;
            4'bx100: out_temp = 4'b0100;
            4'b1000: out_temp = 4'b1000; 
            default: out_temp = 4'b0000;
        endcase
    end

    assign out = out_temp;
endmodule
`resetall
```


2. 8bit的cla，要求描述电路结构、核心算法，不要求具体verilog。

3. (手写verilog) 时序逻辑，判断输入序列对应的值是否能整除15，复位后每一拍输入都视为有效，且输入为序列的最低位。
   
``` verilog
`resetall
`timescale 1ns / 1ps
`default_nettype none

module seqdiv15 #(
) (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  din,
    output wire  res
);

    reg  [3:0] remain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remain <= 4'b0;
        end
        else begin
            if (din) begin
                remain <= remain ^ 4'b1111;
            end
            else begin
                remain <= remain;
            end
        end
    end
    assign res = (remain == 4'b0);
endmodule
`resetall
```

# 中国科学院大学《计算机体系结构》2025秋季学期考题回忆

胡老师的计算机体系结构，考试时间两个小时

题量很大，课后题基础上并不难，没有考软流水。

1. 课后题，给了一个$-(1.0101) * 2^{-130}$小数，写出对应的单精度和双精度IEEE754十六进制。
（具体的小数尾码记不得了，但2的幂次没错，为-130，上来就是写单精度的非规格数）

2. 课后题，A、B、C三台机器，运行同一程序P,指令数分别是$6 \times 10^{10}$，$4 \times 10^{10}$，$2 \times 10^{10}$， 时间分别是30s, 20s, 10s，计算MIPS；谁的性能最好，为什么？

3. 课后题，fo4 延迟。

4. 课后题，Verilog, 32bit的CLA。

5. 课后题，晶体管电路，6输入的归或电路，要求电源或地到输出的级联不超过3级。

6. 课后题，VIPT, 页着色位；tag位。

7. 课后题，寄存器堆所需要的最少寄存器数量。

8. 课后题，循环展开，乘加操作，3次展开；Not Taken计算结果平均周期。

9. 课后题，Tomasulo算法，根据待发射指令，推断后续寄存器、ROB、结果总线的情况。

10. 课后题PLUS, TLB例外，为三层循环的矩阵乘法，LRU替换，涉及TLB抖动。

11. 课后题，MSI协议，额外有Cache状态CLEAN/DIRTY和操作向量。

