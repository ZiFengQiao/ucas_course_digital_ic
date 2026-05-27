'''
Author: Wang, Qiaoyu
Date: 2025-12-09 00:00:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-28 16:23:06
Description: Unsigned 32-bit Square Root Testbench
'''

import os
import math
import cocotb
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory


class TB():
    def __init__(self, dut):
        self.dut = dut
        
        # 接口
        self.clk = dut.clk
        self.rst_n = dut.rst_n
        self.vld_in = dut.vld_in
        self.x = dut.x
        
        # 输出
        self.vld_out = dut.vld_out
        self.y = dut.y
        
        # 流水线深度
        self.pipeline_depth = 16

    async def reset(self):
        self.rst_n.value = 0
        self.vld_in.value = 0
        self.x.value = 0
        await ClockCycles(self.clk, 10)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 5)

    async def send_data(self, value):
        """发送一个数据到DUT"""
        self.x.value = value
        self.vld_in.value = 1
        await RisingEdge(self.clk)
        self.vld_in.value = 0

    async def wait_result(self):
        """等待输出有效并返回结果"""
        while True:
            await RisingEdge(self.clk)
            if self.vld_out.value == 1:
                return self.y.value.integer

    async def calc_sqrt(self, value):
        """发送数据并等待结果"""
        await self.send_data(value)
        result = await self.wait_result()
        return result


async def run_test_basic(dut):
    """基本功能测试：测试一些简单的值"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 测试用例: (输入值, 期望输出)
    test_cases = [
        (0, 0),
        (1, 1),
        (2, 1),
        (3, 1),
        (4, 2),
        (9, 3),
        (16, 4),
        (25, 5),
        (100, 10),
        (255, 15),
        (256, 16),
        (1000, 31),
        (65535, 255),
        (65536, 256),
    ]
    
    for x_val, expected in test_cases:
        result = await tb.calc_sqrt(x_val)
        dut._log.info(f"sqrt({x_val}) = {result}, expected = {expected}")
        assert result == expected, f"sqrt({x_val}): expected {expected}, got {result}"
    
    dut._log.info("Basic test passed!")


async def run_test_perfect_squares(dut):
    """测试完全平方数"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 测试 0 到 65535 的所有完全平方数
    for i in range(0, 65536):
        x_val = i * i
        if x_val > 0xFFFFFFFF:  # 超出32位范围
            break
        expected = i
        result = await tb.calc_sqrt(x_val)
        if result != expected:
            dut._log.error(f"sqrt({x_val}) = {result}, expected = {expected}")
            assert False, f"Perfect square test failed for {i}^2 = {x_val}"
    
    dut._log.info("Perfect squares test passed!")


async def run_test_boundary(dut):
    """边界测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 边界测试用例
    test_cases = [
        (0, 0),                           # 最小值
        (1, 1),                           # 1
        (0xFFFFFFFF, 65535),              # 最大32位值, sqrt(4294967295) = 65535
        (0xFFFE0001, 65535),              # 65535^2 = 4294836225
        (0xFFFE0000, 65534),              # 65535^2 - 1
        (0xFFFC0004, 65534),              # 65534^2 = 4294705156
    ]
    
    for x_val, expected in test_cases:
        result = await tb.calc_sqrt(x_val)
        dut._log.info(f"sqrt({x_val:#010x}) = {result}, expected = {expected}")
        assert result == expected, f"sqrt({x_val}): expected {expected}, got {result}"
    
    dut._log.info("Boundary test passed!")


async def run_test_random(dut):
    """随机测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 随机测试1000个数
    num_tests = 1000
    random.seed(42)  # 固定种子以便复现
    
    for i in range(num_tests):
        x_val = random.randint(0, 0xFFFFFFFF)
        expected = int(math.isqrt(x_val))  # Python 3.8+ 整数平方根
        result = await tb.calc_sqrt(x_val)
        
        if result != expected:
            dut._log.error(f"Test {i}: sqrt({x_val}) = {result}, expected = {expected}")
            assert False, f"Random test failed for x = {x_val}"
        
        if (i + 1) % 100 == 0:
            dut._log.info(f"Random test progress: {i + 1}/{num_tests}")
    
    dut._log.info(f"Random test passed! ({num_tests} tests)")


async def run_test_pipeline(dut):
    """流水线测试：连续发送多个数据"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 准备测试数据
    test_values = [i * i for i in range(100)]  # 0, 1, 4, 9, 16, ...
    expected_results = list(range(100))         # 0, 1, 2, 3, 4, ...
    
    results = []
    send_idx = 0
    recv_idx = 0
    
    # 启动发送协程
    async def sender():
        nonlocal send_idx
        for val in test_values:
            tb.x.value = val
            tb.vld_in.value = 1
            await RisingEdge(tb.clk)
            send_idx += 1
        tb.vld_in.value = 0
    
    cocotb.start_soon(sender())
    
    # 等待足够的时钟周期接收所有结果
    timeout = len(test_values) + tb.pipeline_depth + 10
    for _ in range(timeout):
        await RisingEdge(tb.clk)
        if tb.vld_out.value == 1:
            results.append(tb.y.value.integer)
            recv_idx += 1
            if recv_idx >= len(test_values):
                break
    
    # 验证结果
    assert len(results) == len(expected_results), \
        f"Expected {len(expected_results)} results, got {len(results)}"
    
    for i, (got, expected) in enumerate(zip(results, expected_results)):
        if got != expected:
            dut._log.error(f"Pipeline test[{i}]: sqrt({test_values[i]}) = {got}, expected = {expected}")
            assert False, f"Pipeline test failed at index {i}"
    
    dut._log.info(f"Pipeline test passed! ({len(results)} values)")


if cocotb.SIM_NAME:
    # 注册测试
    tf_basic = TestFactory(run_test_basic)
    tf_basic.generate_tests()
    
    tf_perfect = TestFactory(run_test_perfect_squares)
    tf_perfect.generate_tests()
    
    tf_boundary = TestFactory(run_test_boundary)
    tf_boundary.generate_tests()
    
    tf_random = TestFactory(run_test_random)
    tf_random.generate_tests()
    
    tf_pipeline = TestFactory(run_test_pipeline)
    tf_pipeline.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))


def test_sqrt_u32(request):
    dut = "sqrt_u32"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        simulator="questa",
        waves=True,
        simulation_args=["-voptargs=\"+acc\""],
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )


