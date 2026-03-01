'''
Author: Wang, Qiaoyu
Date: 2026-03-01 16:49:27
LastEditors: Wang, Qiaoyu
LastEditTime: 2026-03-01 16:53:20
Description: 三阶段流水线booth 乘法器仿真测试
'''


import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.types import LogicArray, Range
from cocotb.result import TestError

class TB():
    def __init__(self, dut):
        self.dut = dut
        # 接口
        self.clk = dut.clk
        self.rst = dut.rst
        self.vld_in = dut.vld_in
        self.vld_out = dut.vld_out
        self.data_a = dut.data_a
        self.data_b = dut.data_b
        self.data_c = dut.data_c

        self._data_width = len(self.data_a)
        self._result_width = len(self.data_c)

async def run_test_signed(dut):
    tb = TB(dut)
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    tb.rst.value = 1
    tb.vld_in.value = 0
    tb.data_a.value = 0
    tb.data_b.value = 0
    await RisingEdge(tb.clk)
    await RisingEdge(tb.clk)
    tb.rst.value = 0
    await RisingEdge(tb.clk)

    for _ in range(2 ** 10):
        max_val = 2**(tb._data_width - 1) - 1
        min_val = - (2**(tb._data_width - 1))

        a = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))
        b = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))

        tb.data_a.value = a.signed_integer
        tb.data_b.value = b.signed_integer
        tb.vld_in.value = 1

        await RisingEdge(tb.clk)
        tb.vld_in.value = 0
        
        while tb.vld_out.value != 1:
            await RisingEdge(tb.clk)

        expected_product = LogicArray((a.signed_integer * b.signed_integer) % 2**tb._result_width, Range(tb._result_width-1, "downto", 0))

        dut_result = tb.data_c.value.signed_integer
        expected_result = expected_product.signed_integer
        assert dut_result == expected_result, f"product mismatch: {dut_result} != {expected_result}"

async def run_test_pipeline(dut):
    """
    Test pipeline behavior by driving inputs every cycle
    """
    tb = TB(dut)
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    tb.rst.value = 1
    tb.vld_in.value = 0
    tb.data_a.value = 0
    tb.data_b.value = 0
    await RisingEdge(tb.clk)
    await RisingEdge(tb.clk)
    tb.rst.value = 0
    await RisingEdge(tb.clk)

    expected_results = []
    
    # Number of transactions to run
    num_transactions = 2**10
    
    # Monitor coroutine
    async def monitor():
        received_count = 0
        while received_count < num_transactions:
            await RisingEdge(tb.clk)
            if tb.vld_out.value == 1:
                if not expected_results:
                    raise TestError("Received output but no expected result available")
                
                expected = expected_results.pop(0)
                dut_result = tb.data_c.value.signed_integer
                
                assert dut_result == expected, f"Pipeline mismatch: {dut_result} != {expected}"
                received_count += 1
    
    monitor_task = cocotb.start_soon(monitor())

    # Driver loop
    for _ in range(num_transactions):
        max_val = 2**(tb._data_width - 1) - 1
        min_val = - (2**(tb._data_width - 1))

        a = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))
        b = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))

        tb.data_a.value = a.signed_integer
        tb.data_b.value = b.signed_integer
        tb.vld_in.value = 1
        
        # Calculate expected result
        expected_product = LogicArray((a.signed_integer * b.signed_integer) % 2**tb._result_width, Range(tb._result_width-1, "downto", 0))
        expected_results.append(expected_product.signed_integer)

        # Wait for next clock edge (simulate full throughput)
        await RisingEdge(tb.clk)
    
    tb.vld_in.value = 0
    
    # Wait for monitor to finish
    await monitor_task


if cocotb.SIM_NAME:
    tf = TestFactory(run_test_signed)
    tf.generate_tests()
    
    tf_pipeline = TestFactory(run_test_pipeline)
    tf_pipeline.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))

@pytest.mark.parametrize("data_width", [16, 32, 64, 128])
def test_booth_multi(request, data_width):
    dut = "booth_multi"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, "cla_c4.v"),
        os.path.join(rtl_dir, "full_adder.v"),
        os.path.join(rtl_dir, "cla_adder.v"),
        os.path.join(rtl_dir, "wallace_tree_1b.v"),
        os.path.join(rtl_dir, "wallace_tree.v"),
        os.path.join(rtl_dir, "booth_3b.v"),
        os.path.join(rtl_dir, "booth_encoder.v"),
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['DATA_WIDTH']  = data_width

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

