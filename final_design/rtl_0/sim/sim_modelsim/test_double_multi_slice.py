'''
Author: Wang, Qiaoyu
Date: 2026-02-28 20:06:35
LastEditors: Wang, Qiaoyu
LastEditTime: 2026-03-01 20:59:28
Description: 切片穷举仿真验证
'''


import os
import struct
import cocotb
import random
import cocotb_test.simulator
import pytest

import json

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.regression import TestFactory
from cocotb.result import TestError

# 辅助函数：将浮点数转换为64位整数表示
def float_to_int64(f):
    return struct.unpack('<Q', struct.pack('<d', f))[0]

# 辅助函数：将64位整数表示转换为浮点数
def int64_to_float(i):
    return struct.unpack('<d', struct.pack('<Q', i))[0]

# 多线程
def get_exponent_range(worker_id, num_workers=32):
    # 将 11 位指数空间 (0-2047) 平分给 16 个线程
    total_exponents = 2048
    per_worker = total_exponents // num_workers
    start = worker_id * per_worker
    end = start + per_worker - 1
    return start, end

def compose_float64(exponent: int, mantissa: int, sign=0):
    # 确保输入在合法范围内
    sign &= 0x1
    exponent &= 0x7FF
    mantissa &= 0xFFFFFFFFFFFFF
    
    # 拼装：符号位左移63位 | 指数位左移52位 | 尾数位
    return (sign << 63) | (exponent << 52) | mantissa

def random_mantissa():
    return random.getrandbits(52)

def log_failure_to_json(worker_id, test_idx, data_a, data_b, expected, result):
    """
    每个线程写入独立的文件，格式为 JSON Lines
    """
    # 构造文件名：例如 failed_cases_gw0.json
    filename = f"failed_cases_{worker_id}.json"
    
    # 构造单条记录
    failure_entry = {
        "id": f"{worker_id}_{test_idx}",
        "data_a": hex(data_a) if isinstance(data_a, int) else data_a,
        "data_b": hex(data_b) if isinstance(data_b, int) else data_b,
        "expected": hex(expected) if isinstance(expected, int) else expected,
        "result": hex(result) if isinstance(result, int) else result
    }

    # 直接追加写入，无需加锁，性能极高
    with open(filename, "a", encoding="utf-8") as f:
        f.write(json.dumps(failure_entry) + "\n")

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

async def run_test_random_pipeline_slice(dut, slice_idx, iteration):
    """流水线随机测试：利用流水线吞吐量进行大量随机测试"""
    # 获取切片索引作为随机种子，确保并行测试时生成不同的随机数序列
    random.seed(slice_idx)

    dut._log.info(f"Running slice {slice_idx} with seed {slice_idx}")

    test_vectors = []
    
    tb = TB(dut)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    # -----------------------------------------------------
    # 发送与接收协程
    # -----------------------------------------------------
    # 发送协程：源源不断生成数据并发送
    async def sender():
        for i in range(iteration):
            
            exp_start, exp_end = get_exponent_range(slice_idx, num_workers=16)

            exp_a = random.randint(exp_start, exp_end)
            exp_b = random.randint(0, 2047)
            
            val_a = compose_float64(exp_a, random_mantissa())
            val_b = compose_float64(exp_b, random_mantissa())

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

        tb.vld_in.value = 0
    
    # 接收协程：接收并验证
    async def receiver():

        recv_count = 0
        while recv_count < iteration:
            await RisingEdge(tb.clk)
            if tb.vld_out.value == 1:
                result = tb.data_c.value.integer
                
                # 从队列头部取出对应的期望值 (FIFO)
                if not test_vectors:
                     dut._log.error("Received data but no expected vector found!")
                     break
                
                expected, f_a, f_b, f_expected = test_vectors.pop(0)

                try:
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
                except:
                    log_failure_to_json(slice_idx, recv_count, f_a, f_b, f_expected, result)
                    raise TestError
                
                recv_count += 1

    # 并行启动
    send_task = cocotb.start_soon(sender())
    recv_task = cocotb.start_soon(receiver())
    
    # 等待完成
    await recv_task
    
if cocotb.SIM_NAME:
    # 注册测试
    slice_idx = int(os.getenv("SLICE_IDX"))

    tf_random = TestFactory(run_test_random_pipeline_slice)
    tf_random.add_option("slice_idx", [slice_idx])
    tf_random.add_option("iteration", [2**14])

    tf_random.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))

# 使用 pytest parametrize 生成多个切片测试用例
@pytest.mark.parametrize("slice_idx", range(32)) # 将测试分为 32 个切片
def test_double_multi(request, slice_idx):
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

    extra_env = {
        f'PARAM_{k}': str(v) for k, v in parameters.items()
    }
    # 传递切片索引到仿真环境
    extra_env['SLICE_IDX'] = str(slice_idx)

    sim_build = os.path.join(tests_dir, "sim_build",
        f"{request.node.name.replace('[', '-').replace(']', '')}_slice_{slice_idx}")

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


