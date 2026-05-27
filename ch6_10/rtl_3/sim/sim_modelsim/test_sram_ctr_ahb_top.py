'''
Author: Wang, Qiaoyu
Date: 2025-12-08 22:50:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-30 23:00:31
Description: Cocotb testbench for sram_ctr_ahb_top
             Test AHB burst and single transfer with HSIZE = 010 (32-bit)
'''

import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from cocotb.regression import TestFactory


class TB():
    def __init__(self, dut):
        self.dut = dut
        # 接口
        self.clk = dut.clk
        self.rst_n = dut.rst_n

        # AHB Interface
        self.htrans = dut.htrans
        self.hsize = dut.hsize
        self.hburst = dut.hburst
        self.haddr = dut.haddr
        self.hwrite = dut.hwrite
        self.hwdata = dut.hwdata
        self.hrdata = dut.hrdata
        self.hready = dut.hready
        self.hresp = dut.hresp

        self._data_width = 32
        self._addr_width = 32

    async def reset(self):
        """复位 DUT"""
        self.rst_n.value = 0
        self.htrans.value = 0
        self.hsize.value = 0
        self.hburst.value = 0
        self.haddr.value = 0
        self.hwrite.value = 0
        self.hwdata.value = 0
        await ClockCycles(self.clk, 5)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 2)

    async def ahb_write_single(self, addr, data):
        """AHB Single Write Transaction"""
        # Address Phase
        self.htrans.value = 0b10  # NONSEQ
        self.hsize.value = 0b010  # 32-bit
        self.hburst.value = 0b000  # SINGLE
        self.haddr.value = addr
        self.hwrite.value = 1
        await RisingEdge(self.clk)

        # Data Phase
        self.htrans.value = 0b00  # IDLE
        self.hwdata.value = data
        
        # Wait for hready
        while self.hready.value != 1:
            await RisingEdge(self.clk)
        await RisingEdge(self.clk)

        # Clear
        self.hwrite.value = 0
        self.hwdata.value = 0

    async def ahb_read_single(self, addr):
        """AHB Single Read Transaction"""
        # Address Phase
        self.htrans.value = 0b10  # NONSEQ
        self.hsize.value = 0b010  # 32-bit
        self.hburst.value = 0b000  # SINGLE
        self.haddr.value = addr
        self.hwrite.value = 0
        await RisingEdge(self.clk)

        # Data Phase - wait for response
        self.htrans.value = 0b00  # IDLE
        
        # Wait for hready
        while self.hready.value != 1:
            await RisingEdge(self.clk)
        await RisingEdge(self.clk)

        # Read data
        rdata = int(self.hrdata.value)
        return rdata

    async def ahb_write_burst(self, start_addr, data_list, burst_type=0b011):
        """
        AHB Burst Write Transaction
        burst_type: 
            0b000 - SINGLE
            0b001 - INCR (undefined length)
            0b010 - WRAP4
            0b011 - INCR4
            0b100 - WRAP8
            0b101 - INCR8
            0b110 - WRAP16
            0b111 - INCR16
        """
        num_beats = len(data_list)
        addr = start_addr

        for i, data in enumerate(data_list):
            # Address Phase
            if i == 0:
                self.htrans.value = 0b10  # NONSEQ
            else:
                self.htrans.value = 0b11  # SEQ
            
            self.hsize.value = 0b010  # 32-bit
            self.hburst.value = burst_type
            self.haddr.value = addr
            self.hwrite.value = 1

            if i > 0:
                # Data phase for previous beat
                self.hwdata.value = data_list[i-1]

            await RisingEdge(self.clk)

            # Wait for hready
            while self.hready.value != 1:
                await RisingEdge(self.clk)

            # Increment address (32-bit aligned)
            addr += 4

        # Final data phase
        self.htrans.value = 0b00  # IDLE
        self.hwdata.value = data_list[-1]
        await RisingEdge(self.clk)

        # Wait for hready
        while self.hready.value != 1:
            await RisingEdge(self.clk)
        await RisingEdge(self.clk)

        # Clear
        self.hwrite.value = 0
        self.hwdata.value = 0

    async def ahb_read_burst(self, start_addr, num_beats, burst_type=0b011):
        """AHB Burst Read Transaction"""
        data_list = []
        addr = start_addr

        for i in range(num_beats):
            # Address Phase
            if i == 0:
                self.htrans.value = 0b10  # NONSEQ
            else:
                self.htrans.value = 0b11  # SEQ
            
            self.hsize.value = 0b010  # 32-bit
            self.hburst.value = burst_type
            self.haddr.value = addr
            self.hwrite.value = 0

            await RisingEdge(self.clk)

            # Wait for hready
            while self.hready.value != 1:
                await RisingEdge(self.clk)

            # Read data from previous beat (pipeline)
            if i > 0:
                data_list.append(int(self.hrdata.value))

            # Increment address (32-bit aligned)
            addr += 4

        # Final data phase
        self.htrans.value = 0b00  # IDLE
        await RisingEdge(self.clk)

        # Wait for hready
        while self.hready.value != 1:
            await RisingEdge(self.clk)

        # Read last data
        data_list.append(int(self.hrdata.value))

        return data_list


async def run_test_single_write_read(dut):
    """测试单次写读操作"""
    tb = TB(dut)

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    dut._log.info("=== Test Single Write/Read ===")

    # 测试多个地址的单次写读
    test_cases = [
        (0x00, 0xDEADBEEF),
        (0x04, 0x12345678),
        (0x08, 0xCAFEBABE),
        (0x0C, 0xABCD1234),
    ]

    # 写入数据
    for addr, data in test_cases:
        await tb.ahb_write_single(addr, data)
        dut._log.info(f"Write: addr=0x{addr:08X}, data=0x{data:08X}")

    await ClockCycles(dut.clk, 2)

    # 读取并验证数据
    for addr, expected_data in test_cases:
        read_data = await tb.ahb_read_single(addr)
        dut._log.info(f"Read: addr=0x{addr:08X}, data=0x{read_data:08X}, expected=0x{expected_data:08X}")
        assert read_data == expected_data, \
            f"Data mismatch at addr 0x{addr:08X}: got 0x{read_data:08X}, expected 0x{expected_data:08X}"

    dut._log.info("Test Single Write/Read PASSED!")


async def run_test_burst_incr4(dut):
    """测试 INCR4 突发传输 (4 beats)"""
    tb = TB(dut)

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    dut._log.info("=== Test INCR4 Burst Write/Read ===")

    start_addr = 0x100
    write_data = [0x11111111, 0x22222222, 0x33333333, 0x44444444]

    # INCR4 突发写
    await tb.ahb_write_burst(start_addr, write_data, burst_type=0b011)
    dut._log.info(f"Burst Write INCR4: start_addr=0x{start_addr:08X}, data={[hex(d) for d in write_data]}")

    await ClockCycles(dut.clk, 2)

    # INCR4 突发读
    read_data = await tb.ahb_read_burst(start_addr, 4, burst_type=0b011)
    dut._log.info(f"Burst Read INCR4: start_addr=0x{start_addr:08X}, data={[hex(d) for d in read_data]}")

    # 验证
    for i, (expected, actual) in enumerate(zip(write_data, read_data)):
        assert expected == actual, \
            f"Data mismatch at beat {i}: got 0x{actual:08X}, expected 0x{expected:08X}"

    dut._log.info("Test INCR4 Burst PASSED!")


async def run_test_burst_incr8(dut):
    """测试 INCR8 突发传输 (8 beats)"""
    tb = TB(dut)

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    dut._log.info("=== Test INCR8 Burst Write/Read ===")

    start_addr = 0x200
    write_data = [0x10 + i for i in range(8)]

    # INCR8 突发写
    await tb.ahb_write_burst(start_addr, write_data, burst_type=0b101)
    dut._log.info(f"Burst Write INCR8: start_addr=0x{start_addr:08X}")

    await ClockCycles(dut.clk, 2)

    # INCR8 突发读
    read_data = await tb.ahb_read_burst(start_addr, 8, burst_type=0b101)
    dut._log.info(f"Burst Read INCR8: data={[hex(d) for d in read_data]}")

    # 验证
    for i, (expected, actual) in enumerate(zip(write_data, read_data)):
        assert expected == actual, \
            f"Data mismatch at beat {i}: got 0x{actual:08X}, expected 0x{expected:08X}"

    dut._log.info("Test INCR8 Burst PASSED!")


async def run_test_random(dut):
    """随机数据测试"""
    tb = TB(dut)

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    dut._log.info("=== Test Random Data ===")

    num_tests = 32
    test_data = {}

    # 随机写入
    for i in range(num_tests):
        addr = i * 4  # 32-bit aligned
        data = random.randint(0, 0xFFFFFFFF)
        test_data[addr] = data
        await tb.ahb_write_single(addr, data)

    await ClockCycles(dut.clk, 2)

    # 随机读取并验证
    for addr, expected_data in test_data.items():
        read_data = await tb.ahb_read_single(addr)
        assert read_data == expected_data, \
            f"Data mismatch at addr 0x{addr:08X}: got 0x{read_data:08X}, expected 0x{expected_data:08X}"

    dut._log.info(f"Test Random Data PASSED! ({num_tests} transactions)")


# 注册测试
if cocotb.SIM_NAME:
    factory_single = TestFactory(run_test_single_write_read)
    factory_single.generate_tests()

    factory_incr4 = TestFactory(run_test_burst_incr4)
    factory_incr4.generate_tests()

    factory_incr8 = TestFactory(run_test_burst_incr8)
    factory_incr8.generate_tests()

    factory_random = TestFactory(run_test_random)
    factory_random.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))
eda_dir = os.path.abspath("/opt/quartus/quartus/eda")

def test_sram_ctr_ahb_top(request):
    dut = "sram_ctr_ahb_top"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(eda_dir, "sim_lib/altera_lnsim.sv"),
        os.path.join(rtl_dir, "altera_sram.v"),
        os.path.join(rtl_dir, "sram_ctr_ahb.v"),
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}
    parameters['DATA_WIDTH']      = 32
    parameters['ADDR_WIDTH']      = 32
    parameters['SRAM_ADDR_WIDTH'] = 12
    parameters['SRAM_MAX_DEPTH']  = 2**12

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build")

    cocotb_test.simulator.run(
        simulator="questa",
        waves=True,
        sim_args=["-voptargs=\"+acc\""],
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )

