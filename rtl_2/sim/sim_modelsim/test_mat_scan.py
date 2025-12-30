'''
Author: Wang, Qiaoyu
Date: 2025-12-08 22:50:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-29 11:10:15
Description: Cocotb testbench for mat_scan (8x8 Matrix Zigzag Scan Module)
'''

import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory


def generate_zigzag_order(mat_n=8):
    """生成 Zigzag 扫描顺序的地址映射表"""
    zigzag_addr = []
    x, y = 0, 0
    data_num = mat_n * mat_n
    
    for _ in range(data_num):
        zigzag_addr.append(y * mat_n + x)
        
        if (x + y) % 2 == 0:
            # 偶数向上移动 (右上)
            if x == mat_n - 1:
                y = y + 1
            elif y == 0:
                x = x + 1
            else:
                x = x + 1
                y = y - 1
        else:
            # 奇数向下移动 (左下)
            if y == mat_n - 1:
                x = x + 1
            elif x == 0:
                y = y + 1
            else:
                x = x - 1
                y = y + 1
    
    return zigzag_addr


class TB():
    def __init__(self, dut):
        self.dut = dut
        # 接口
        self.clk = dut.clk
        self.rst_n = dut.rst_n
        self.vld_in = dut.vld_in
        self.din = dut.din
        self.vld_out = dut.vld_out
        self.dout = dut.dout

        self._data_width = len(self.din)
        self._mat_n = int(os.getenv("PARAM_MAT_N", 8))
        self._data_num = self._mat_n * self._mat_n

    async def reset(self):
        """复位 DUT"""
        self.rst_n.value = 0
        self.vld_in.value = 0
        self.din.value = 0
        await ClockCycles(self.clk, 5)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 2)

    async def send_matrix(self, data_list):
        """发送一个矩阵的数据（按行顺序）"""
        for data in data_list:
            self.vld_in.value = 1
            self.din.value = data
            await RisingEdge(self.clk)
        self.vld_in.value = 0
        self.din.value = 0

    async def receive_output(self):
        """接收 zigzag 输出数据"""
        output_data = []
        while len(output_data) < self._data_num:
            await RisingEdge(self.clk)
            if self.vld_out.value == 1:
                output_data.append(int(self.dout.value))
        return output_data


async def run_test_zigzag(dut):
    """测试 Zigzag 扫描功能"""
    tb = TB(dut)
    mat_n = tb._mat_n
    data_num = tb._data_num

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    # 生成测试数据：按行顺序存储的矩阵数据 (0, 1, 2, ..., 63)
    input_data = list(range(data_num))
    
    # 生成期望的 zigzag 输出顺序
    zigzag_addr = generate_zigzag_order(mat_n)
    expected_output = [input_data[addr] for addr in zigzag_addr]

    dut._log.info(f"Input data (row order): {input_data[:16]}...")
    dut._log.info(f"Zigzag address order: {zigzag_addr[:16]}...")
    dut._log.info(f"Expected output: {expected_output[:16]}...")

    # 发送数据并接收输出
    send_task = cocotb.start_soon(tb.send_matrix(input_data))
    output_data = await tb.receive_output()
    await send_task

    dut._log.info(f"Actual output: {output_data[:16]}...")

    # 验证输出
    for i, (expected, actual) in enumerate(zip(expected_output, output_data)):
        assert expected == actual, \
            f"Mismatch at index {i}: expected {expected}, got {actual}"

    dut._log.info("Test PASSED: Zigzag scan output is correct!")


async def run_test_random_data(dut):
    """使用随机数据测试 Zigzag 扫描"""
    tb = TB(dut)
    mat_n = tb._mat_n
    data_num = tb._data_num
    max_val = (1 << tb._data_width) - 1

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    # 生成随机测试数据
    input_data = [random.randint(0, max_val) for _ in range(data_num)]
    
    # 生成期望的 zigzag 输出顺序
    zigzag_addr = generate_zigzag_order(mat_n)
    expected_output = [input_data[addr] for addr in zigzag_addr]

    dut._log.info(f"Random input data: {input_data[:8]}...")
    dut._log.info(f"Expected output: {expected_output[:8]}...")

    # 发送数据并接收输出
    send_task = cocotb.start_soon(tb.send_matrix(input_data))
    output_data = await tb.receive_output()
    await send_task

    dut._log.info(f"Actual output: {output_data[:8]}...")

    # 验证输出
    for i, (expected, actual) in enumerate(zip(expected_output, output_data)):
        assert expected == actual, \
            f"Mismatch at index {i}: expected {expected}, got {actual}"

    dut._log.info("Test PASSED: Random data zigzag scan is correct!")


async def run_test_continuous(dut):
    """测试连续发送多个矩阵"""
    tb = TB(dut)
    mat_n = tb._mat_n
    data_num = tb._data_num
    max_val = (1 << tb._data_width) - 1
    num_matrices = 3

    # 启动时钟
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # 复位
    await tb.reset()

    zigzag_addr = generate_zigzag_order(mat_n)

    for matrix_idx in range(num_matrices):
        # 生成测试数据
        base_val = matrix_idx * 100
        input_data = [(base_val + i) % (max_val + 1) for i in range(data_num)]
        expected_output = [input_data[addr] for addr in zigzag_addr]

        dut._log.info(f"Matrix {matrix_idx}: sending data starting with {input_data[0]}")

        # 发送数据并接收输出
        send_task = cocotb.start_soon(tb.send_matrix(input_data))
        output_data = await tb.receive_output()
        await send_task

        # 验证输出
        for i, (expected, actual) in enumerate(zip(expected_output, output_data)):
            assert expected == actual, \
                f"Matrix {matrix_idx}, index {i}: expected {expected}, got {actual}"

        dut._log.info(f"Matrix {matrix_idx}: PASSED")

    dut._log.info("Test PASSED: Continuous matrices zigzag scan is correct!")


# 注册测试
if cocotb.SIM_NAME:
    factory = TestFactory(run_test_zigzag)
    factory.generate_tests()

    factory_random = TestFactory(run_test_random_data)
    factory_random.generate_tests()

    factory_continuous = TestFactory(run_test_continuous)
    factory_continuous.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))


@pytest.mark.parametrize("mat_n", [8, 16])
@pytest.mark.parametrize("data_width", [8, 16])
def test_mat_scan(request, data_width, mat_n):
    dut = "mat_scan"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}
    parameters['DATA_WIDTH'] = data_width
    parameters['MAT_N'] = mat_n

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

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

