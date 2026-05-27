'''
Author: Wang, Qiaoyu
Date: 2025-12-28 21:30:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-28 21:47:27
Description: Bitonic Sort Testbench
'''

import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory


class TB():
    def __init__(self, dut):
        self.dut = dut
        
        # 从环境变量或默认值获取参数
        self.data_width = int(os.getenv("PARAM_DATA_WIDTH", 8))
        self.data_num = int(os.getenv("PARAM_DATA_NUM", 32))
        self.ascend = int(os.getenv("PARAM_ASCEND", 1))
        
        # 计算流水线深度: sum(1..GROUP_NUM) = GROUP_NUM*(GROUP_NUM+1)/2
        self.group_num = self.data_num.bit_length() - 1  # log2(DATA_NUM)
        self.pipeline_depth = (self.group_num * (self.group_num + 1)) // 2
        
        # 接口
        self.clk = dut.clk
        self.rst_n = dut.rst_n
        self.vld_in = dut.vld_in
        self.din_array = dut.din_array
        self.vld_out = dut.vld_out
        self.dout_array = dut.dout_array

    def pack_array(self, data_list):
        """将数据列表打包成位向量"""
        result = 0
        for i, val in enumerate(data_list):
            result |= (val & ((1 << self.data_width) - 1)) << (i * self.data_width)
        return result

    def unpack_array(self, packed_data):
        """将位向量解包成数据列表"""
        mask = (1 << self.data_width) - 1
        return [(packed_data >> (i * self.data_width)) & mask for i in range(self.data_num)]

    def expected_sort(self, data_list):
        """计算期望的排序结果"""
        return sorted(data_list, reverse=(self.ascend == 0))

    async def reset(self):
        """复位DUT"""
        self.rst_n.value = 0
        self.vld_in.value = 0
        self.din_array.value = 0
        await ClockCycles(self.clk, 10)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 5)

    async def send_data(self, data_list):
        """发送一组数据"""
        packed = self.pack_array(data_list)
        self.din_array.value = packed
        self.vld_in.value = 1
        await RisingEdge(self.clk)
        self.vld_in.value = 0

    async def wait_result(self):
        """等待输出有效并返回结果"""
        while True:
            await RisingEdge(self.clk)
            if self.vld_out.value == 1:
                return self.unpack_array(self.dout_array.value.integer)

    async def sort_and_check(self, data_list):
        """发送数据，等待结果，并检查"""
        expected = self.expected_sort(data_list)
        await self.send_data(data_list)
        result = await self.wait_result()
        return result, expected


async def run_test_basic(dut):
    """基本功能测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 测试用例
    test_cases = [
        # 已排序
        list(range(tb.data_num)),
        # 逆序
        list(range(tb.data_num - 1, -1, -1)),
        # 全相同
        [128] * tb.data_num,
        # 交替
        [i % 2 * 255 for i in range(tb.data_num)],
        # 边界值
        [0] * (tb.data_num // 2) + [255] * (tb.data_num // 2),
    ]
    
    for i, data in enumerate(test_cases):
        result, expected = await tb.sort_and_check(data)
        dut._log.info(f"Test case {i}: input={data[:8]}... result={result[:8]}... expected={expected[:8]}...")
        assert result == expected, f"Test case {i} failed: {result} != {expected}"
    
    dut._log.info("Basic test passed!")


async def run_test_random(dut):
    """随机测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    max_val = (1 << tb.data_width) - 1
    num_tests = 100
    random.seed(42)
    
    for i in range(num_tests):
        data = [random.randint(0, max_val) for _ in range(tb.data_num)]
        result, expected = await tb.sort_and_check(data)
        
        if result != expected:
            dut._log.error(f"Test {i} failed!")
            dut._log.error(f"  Input:    {data}")
            dut._log.error(f"  Result:   {result}")
            dut._log.error(f"  Expected: {expected}")
            assert False, f"Random test {i} failed"
        
        if (i + 1) % 20 == 0:
            dut._log.info(f"Random test progress: {i + 1}/{num_tests}")
    
    dut._log.info(f"Random test passed! ({num_tests} tests)")


async def run_test_duplicates(dut):
    """重复值测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    max_val = (1 << tb.data_width) - 1
    num_tests = 50
    random.seed(123)
    
    for i in range(num_tests):
        # 生成有大量重复值的数据
        unique_count = random.randint(1, min(10, tb.data_num))
        unique_vals = [random.randint(0, max_val) for _ in range(unique_count)]
        data = [random.choice(unique_vals) for _ in range(tb.data_num)]
        
        result, expected = await tb.sort_and_check(data)
        
        if result != expected:
            dut._log.error(f"Duplicates test {i} failed!")
            assert False, f"Duplicates test {i} failed"
        
        if (i + 1) % 10 == 0:
            dut._log.info(f"Duplicates test progress: {i + 1}/{num_tests}")
    
    dut._log.info(f"Duplicates test passed! ({num_tests} tests)")


async def run_test_pipeline(dut):
    """流水线测试：连续发送多组数据"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    max_val = (1 << tb.data_width) - 1
    num_inputs = 20
    random.seed(456)
    
    # 准备测试数据
    test_data = [[random.randint(0, max_val) for _ in range(tb.data_num)] for _ in range(num_inputs)]
    expected_results = [tb.expected_sort(data) for data in test_data]
    
    results = []
    send_idx = 0
    
    # 发送协程
    async def sender():
        nonlocal send_idx
        for data in test_data:
            tb.din_array.value = tb.pack_array(data)
            tb.vld_in.value = 1
            await RisingEdge(tb.clk)
            send_idx += 1
        tb.vld_in.value = 0
    
    cocotb.start_soon(sender())
    
    # 接收结果
    timeout = num_inputs + tb.pipeline_depth + 20
    for _ in range(timeout):
        await RisingEdge(tb.clk)
        if tb.vld_out.value == 1:
            results.append(tb.unpack_array(tb.dout_array.value.integer))
            if len(results) >= num_inputs:
                break
    
    # 验证结果
    assert len(results) == len(expected_results), \
        f"Expected {len(expected_results)} results, got {len(results)}"
    
    for i, (got, expected) in enumerate(zip(results, expected_results)):
        if got != expected:
            dut._log.error(f"Pipeline test[{i}] failed!")
            dut._log.error(f"  Input:    {test_data[i]}")
            dut._log.error(f"  Result:   {got}")
            dut._log.error(f"  Expected: {expected}")
            assert False, f"Pipeline test failed at index {i}"
    
    dut._log.info(f"Pipeline test passed! ({num_inputs} consecutive inputs)")


async def run_test_boundary(dut):
    """边界值测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    max_val = (1 << tb.data_width) - 1
    
    test_cases = [
        # 全0
        [0] * tb.data_num,
        # 全最大值
        [max_val] * tb.data_num,
        # 0和最大值交替
        [0 if i % 2 == 0 else max_val for i in range(tb.data_num)],
        # 只有两个不同的值
        [0] * (tb.data_num - 1) + [max_val],
        [max_val] * (tb.data_num - 1) + [0],
        # 递增
        [i % (max_val + 1) for i in range(tb.data_num)],
        # 递减
        [(tb.data_num - 1 - i) % (max_val + 1) for i in range(tb.data_num)],
    ]
    
    for i, data in enumerate(test_cases):
        result, expected = await tb.sort_and_check(data)
        
        if result != expected:
            dut._log.error(f"Boundary test {i} failed!")
            dut._log.error(f"  Input:    {data}")
            dut._log.error(f"  Result:   {result}")
            dut._log.error(f"  Expected: {expected}")
            assert False, f"Boundary test {i} failed"
    
    dut._log.info(f"Boundary test passed! ({len(test_cases)} tests)")


if cocotb.SIM_NAME:
    # 注册测试
    tf_basic = TestFactory(run_test_basic)
    tf_basic.generate_tests()
    
    tf_random = TestFactory(run_test_random)
    tf_random.generate_tests()
    
    tf_duplicates = TestFactory(run_test_duplicates)
    tf_duplicates.generate_tests()
    
    tf_pipeline = TestFactory(run_test_pipeline)
    tf_pipeline.generate_tests()
    
    tf_boundary = TestFactory(run_test_boundary)
    tf_boundary.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))


@pytest.mark.parametrize("data_num", [8, 16, 32, 64])
@pytest.mark.parametrize("data_width", [8])
@pytest.mark.parametrize("ascend", [1, 0])
def test_bitonic_sort(request, data_num, data_width, ascend):
    dut = "bitonic_sort"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, "sort_unit.v"),
        os.path.join(rtl_dir, "bitonic_merge.v"),
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {
        'DATA_NUM': data_num,
        'DATA_WIDTH': data_width,
        'ASCEND': ascend,
    }

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

