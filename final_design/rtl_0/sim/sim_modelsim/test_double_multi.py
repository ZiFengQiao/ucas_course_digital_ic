'''
Author: Wang, Qiaoyu
Date: 2026-02-27 00:00:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2026-03-01 19:10:38
Description: IEEE 754 Double Precision Floating Point Multiplier Testbench
'''

import os
import struct
import cocotb
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory

# 辅助函数：将浮点数转换为64位整数表示
def float_to_int64(f):
    return struct.unpack('<Q', struct.pack('<d', f))[0]

# 辅助函数：将64位整数表示转换为浮点数
def int64_to_float(i):
    return struct.unpack('<d', struct.pack('<Q', i))[0]

class TB():
    def __init__(self, dut):
        self.dut = dut
        
        # 接口
        self.clk = dut.clk
        self.rst = dut.rst
        self.vld_in = dut.vld_in
        self.data_a = dut.data_a
        self.data_b = dut.data_b
        
        # 输出
        self.vld_out = dut.vld_out
        self.data_c = dut.data_c
        
        # 流水线深度 (根据 double_multi.v，vld_sync 是 5 级)
        self.pipeline_depth = 5

    async def reset(self):
        self.rst.value = 1
        self.vld_in.value = 0
        self.data_a.value = 0
        self.data_b.value = 0
        await ClockCycles(self.clk, 10)
        self.rst.value = 0
        await ClockCycles(self.clk, 5)

    async def send_data(self, val_a, val_b):
        """发送数据到DUT"""
        self.data_a.value = val_a
        self.data_b.value = val_b
        self.vld_in.value = 1
        await RisingEdge(self.clk)
        self.vld_in.value = 0

    async def wait_result(self):
        """等待输出有效并返回结果"""
        while True:
            await RisingEdge(self.clk)
            if self.vld_out.value == 1:
                return self.data_c.value.integer

    async def calc_mult(self, val_a, val_b):
        """发送数据并等待结果"""
        await self.send_data(val_a, val_b)
        result = await self.wait_result()
        return result

async def run_test_basic(dut):
    """基本功能测试：测试一些简单的浮点数乘法"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 测试用例: (输入A, 输入B, 期望输出)
    test_cases_float = [
        (1.0, 1.0, 1.0),
        (2.0, 3.0, 6.0),
        (-2.0, 3.0, -6.0),
        (-2.0, -3.0, 6.0),
        (1.5, 2.5, 3.75),
        (0.0, 5.0, 0.0),
        (10.0, 0.0, 0.0),
        (0.5, 0.5, 0.25),
        (123.456, 789.012, 123.456 * 789.012),
        (2.642966852498251e-10, 1.075470832704261e-308, 2.842434e-318),
        (8.21156540017073e-309, 1.4696350683289971e-08, 1.20680045e-316),
        (3.795090764082576e-243, 4.836626748247212e-66, 1.8355437501587733e-308),
        (5.506085958230775e-141, 3.112641639162244e-168, 1.7138472422395656e-308),
        (1.4471033241642726e-12, 3.48018306028487e-309, 5.035e-321)
    ]
    
    for f_a, f_b, f_expected in test_cases_float:
        val_a = float_to_int64(f_a)
        val_b = float_to_int64(f_b)
        expected = float_to_int64(f_expected)
        
        result = await tb.calc_mult(val_a, val_b)
        
        # 允许最后一位有误差 (1 ULP)
        diff = abs(result - expected)
        
        dut._log.info(f"{f_a} * {f_b} = {int64_to_float(result)} (Expected: {f_expected})")
        assert diff <= 1, f"Failed: {f_a} * {f_b}. Expected {expected:#018x}, got {result:#018x}"
    
    dut._log.info("Basic test passed!")

async def run_test_special_values(dut):
    """特殊值测试：Inf, NaN, Zero"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    INF = float('inf')
    NINF = float('-inf')
    NAN = float('nan')
    
    test_cases_float = [
        (INF, 2.0, INF),
        (NINF, 2.0, NINF),
        (INF, -2.0, NINF),
        (INF, 0.0, NAN),      # Inf * 0 = NaN
        (NAN, 2.0, NAN),
        (2.0, NAN, NAN),
        (0.0, 0.0, 0.0),
    ]
    
    for f_a, f_b, f_expected in test_cases_float:
        val_a = float_to_int64(f_a)
        val_b = float_to_int64(f_b)
        
        result = await tb.calc_mult(val_a, val_b)
        f_result = int64_to_float(result)
        
        # NaN 比较特殊，不能用 ==
        if str(f_expected) == 'nan':
            assert str(f_result) == 'nan', f"Failed: {f_a} * {f_b}. Expected NaN, got {f_result}"
        else:
            assert f_result == f_expected, f"Failed: {f_a} * {f_b}. Expected {f_expected}, got {f_result}"
            
        dut._log.info(f"{f_a} * {f_b} = {f_result} (Expected: {f_expected})")
    
    dut._log.info("Special values test passed!")

async def run_test_subnormal(dut):
    """非规格化数 (Subnormal) 测试"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 构造一些非规格化数
    # Double exp = 0, mantissa != 0
    # 最小正非规格数: 0x0000000000000001 (2^-1074)
    # 最大非规格数: 0x000FFFFFFFFFFFFF (approx 2.2e-308)
    
    subnormals = [
        0x0000000000000001,
        0x0000000000000002,
        0x0008000000000000,
        0x000FFFFFFFFFFFFF,
        0x8000000000000001, # 负数
    ]
    
    # 构造一些小的规格化数，以便乘积落入非规格化范围
    small_normals = [
        0x0010000000000000, # 最小规格数 (2^-1022)
        0x0020000000000000, 
    ]
    
    test_pairs = []
    
    # Non-normal * Normal -> Non-normal / Zero
    for s in subnormals:
        for n in small_normals:
             test_pairs.append((s, n))
             test_pairs.append((n, s))
             
    # Non-normal * Non-normal -> Zero
    for s1 in subnormals:
        for s2 in subnormals:
            test_pairs.append((s1, s2))
            
    # Small Normal * Small Normal -> Subnormal
    # e.g. 2^-600 * 2^-500 = 2^-1100 (Subnormal)
    # 构造: exp = 500 (offset 1023 -> real -523) -> reg = 500
    val_small_1 = float_to_int64(1e-160) # approx 2^-531
    val_small_2 = float_to_int64(1e-160)
    test_pairs.append((val_small_1, val_small_2))

    
    for val_a, val_b in test_pairs:
        f_a = int64_to_float(val_a)
        f_b = int64_to_float(val_b)
        f_expected = f_a * f_b
        expected = float_to_int64(f_expected)
        
        result = await tb.calc_mult(val_a, val_b)
        
        diff = abs(result - expected)
        
        # 检查是否正确生成了非规格数 (Exp=0, Man!=0)
        is_result_subnormal = ((result & 0x7FF0000000000000) == 0) and ((result & 0xFFFFFFFFFFFFF) != 0)
        is_expect_subnormal = ((expected & 0x7FF0000000000000) == 0) and ((expected & 0xFFFFFFFFFFFFF) != 0)

        if diff > 1:
            dut._log.error(f"Subnormal Test: {f_a} * {f_b}\nGot: {int64_to_float(result)} ({result:#018x})\nExp: {f_expected} ({expected:#018x})")
            assert False, "Subnormal mismatch"
        
        dut._log.info(f"Subnormal Pass: {f_a:.4e} * {f_b:.4e} = {int64_to_float(result):.4e}")

    dut._log.info("Subnormal test passed!")

async def run_test_pipeline(dut):
    """流水线测试：连续发送多个数据"""
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # 准备测试数据
    test_values = [(random.uniform(-100.0, 100.0), random.uniform(-100.0, 100.0)) for _ in range(100)]
    expected_results = [float_to_int64(a * b) for a, b in test_values]
    
    results = []
    send_idx = 0
    recv_idx = 0
    
    # 启动发送协程
    async def sender():
        nonlocal send_idx
        for f_a, f_b in test_values:
            tb.data_a.value = float_to_int64(f_a)
            tb.data_b.value = float_to_int64(f_b)
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
            results.append(tb.data_c.value.integer)
            recv_idx += 1
            if recv_idx >= len(test_values):
                break
    
    # 验证结果
    assert len(results) == len(expected_results), \
        f"Expected {len(expected_results)} results, got {len(results)}"
    
    for i, (got, expected) in enumerate(zip(results, expected_results)):
        diff = abs(got - expected)
        if diff > 1:
            f_a, f_b = test_values[i]
            dut._log.error(f"Pipeline test[{i}]: {f_a} * {f_b} = {int64_to_float(got)}, expected = {int64_to_float(expected)}")
            assert False, f"Pipeline test failed at index {i}"
    
    dut._log.info(f"Pipeline test passed! ({len(results)} values)")

async def run_test_random_pipeline(dut):
    """流水线随机测试：利用流水线吞吐量进行大量随机测试"""
    global test_vectors
    test_vectors = []
    
    tb = TB(dut)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    num_tests = 2**14 
    
    dut._log.info(f"Starting infinite pipeline test (Target: {num_tests} vectors)...")

    # -----------------------------------------------------
    # 2. 发送与接收协程 (流式处理，不预先生成所有数据)
    # -----------------------------------------------------
    
    error_count = 0

    # 发送协程：源源不断生成数据并发送
    async def sender():
        for i in range(num_tests):
            val_a = random.getrandbits(64)
            val_b = random.getrandbits(64)
            
            # 实时计算 Golden Model
            try:
                f_a = int64_to_float(val_a)
                f_b = int64_to_float(val_b)
                f_expected = f_a * f_b
            except OverflowError:
                f_expected = float('inf') if (f_a * f_b) > 0 else float('-inf')
            
            expected = float_to_int64(f_expected)
            
            # 将期望结果存入队列，供接收端验证
            test_vectors.append((expected, f_a, f_b, f_expected))
            
            tb.data_a.value = val_a
            tb.data_b.value = val_b
            tb.vld_in.value = 1
            await RisingEdge(tb.clk)
            
            if i % 10000 == 0:
                dut._log.info(f"Sent {i}/{num_tests}")

        tb.vld_in.value = 0
    
    # 接收协程：接收并验证
    async def receiver():
        nonlocal error_count
        recv_count = 0
        while recv_count < num_tests:
            await RisingEdge(tb.clk)
            if tb.vld_out.value == 1:
                result = tb.data_c.value.integer
                
                # 从队列头部取出对应的期望值 (FIFO)
                if not test_vectors:
                     dut._log.error("Received data but no expected vector found!")
                     break
                
                expected, f_a, f_b, f_expected = test_vectors.pop(0)

                # 验证逻辑
                if (expected & 0x7FF0000000000000) == 0x7FF0000000000000 and (expected & 0xFFFFFFFFFFFFF) != 0:
                     # NaN Check
                     if not ((result & 0x7FF0000000000000) == 0x7FF0000000000000 and (result & 0xFFFFFFFFFFFFF) != 0):
                         dut._log.error(f"Test {recv_count}: {f_a} * {f_b}\nExpected NaN\nGot {int64_to_float(result)}")
                         assert False, f"Test {recv_count} Failed: Expected NaN"
                else:
                    diff = abs(result - expected)
                    if diff > 1:
                        if not (abs(f_expected) == float('inf') and abs(int64_to_float(result)) == float('inf')):
                             dut._log.error(f"Test {recv_count}: {f_a} * {f_b}\nRes: {result:#018x} ({int64_to_float(result)})\nExp: {expected:#018x} ({f_expected})")
                             assert False, f"Test {recv_count} Failed: Result mismatch"
                
                recv_count += 1
                if recv_count % 10000 == 0:
                     dut._log.info(f"Verified {recv_count}/{num_tests} results.")

    # 并行启动
    send_task = cocotb.start_soon(sender())
    recv_task = cocotb.start_soon(receiver())
    
    # 等待完成
    await recv_task
    
    dut._log.info(f"Random Pipeline test passed! ({num_tests} tests)")


if cocotb.SIM_NAME:
    # 注册测试
    tf_basic = TestFactory(run_test_basic)
    tf_basic.generate_tests()
    
    tf_special = TestFactory(run_test_special_values)
    tf_special.generate_tests()

    tf_subnormal = TestFactory(run_test_subnormal)
    tf_subnormal.generate_tests()
    
    tf_pipeline = TestFactory(run_test_pipeline)
    tf_pipeline.generate_tests()
    
    # tf_random = TestFactory(run_test_random_pipeline)
    # tf_random.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))


def test_double_multi(request):
    dut = "double_multi"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    # 需要包含所有依赖的子模块
    verilog_sources = [
        os.path.join(rtl_dir, "lzc.v"),
        os.path.join(rtl_dir, "booth_multi.v"),
        os.path.join(rtl_dir, "booth_encoder.v"),
        os.path.join(rtl_dir, "booth_3b.v"),
        os.path.join(rtl_dir, "wallace_tree.v"),
        os.path.join(rtl_dir, "wallace_tree_1b.v"),
        os.path.join(rtl_dir, "cla_adder.v"),
        os.path.join(rtl_dir, "cla_c4.v"),
        os.path.join(rtl_dir, "full_adder.v"),
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


