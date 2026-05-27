'''
Author: Wang, Qiaoyu
Date: 2025-12-08 22:50:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-08 22:50:22
Description: 
'''

import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.triggers import Timer
from cocotb.regression import TestFactory
from cocotb.types import LogicArray, Range


class TB():
    def __init__(self, dut):
        self.dut = dut
        self._data_width = len(dut.data_a)
        self._result_width = len(dut.sum)
        self._cout_valid = self._result_width == self._data_width

        # 接口
        self.data_a = dut.data_a
        self.data_b = dut.data_b
        self.cin    = dut.cin
        self.sum    = dut.sum
        self.cout   = dut.cout

async def run_test_unsigned(dut):
    tb = TB(dut)

    for _ in range(2 ** 12):
        a = random.randint(0, 2**tb._data_width - 1)
        b = random.randint(0, 2**tb._data_width - 1)
        cin = random.randint(0, 1)

        tb.data_a.value = a
        tb.data_b.value = b
        tb.cin.value    = cin

        await Timer(2, "ns")

        expected_sum = (a + b + cin) & ((1 << tb._result_width) - 1)
        expected_cout = (a + b + cin) >> tb._data_width

        assert tb.sum.value.integer == expected_sum, f"SUM mismatch: {tb.sum.value.integer} != {expected_sum}"

        if tb._cout_valid:
            assert tb.cout.value.integer == expected_cout, f"COUT mismatch: {tb.cout.value.integer} != {expected_cout}"

async def run_test_signed(dut):
    tb = TB(dut)

    for _ in range(2 ** 12):
        max_val = 2**(tb._data_width - 1) - 1
        min_val = - (2**(tb._data_width - 1))

        a = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))
        b = LogicArray(random.randint(min_val, max_val), Range(tb._data_width-1, "downto", 0))
        cin = random.randint(0, 1)

        tb.data_a.value = a.signed_integer
        tb.data_b.value = b.signed_integer
        tb.cin.value    = cin

        await Timer(2, "ns")

        expected_sum = LogicArray((a.signed_integer + b.signed_integer + cin) % 2**tb._result_width, Range(tb._result_width-1, "downto", 0))

        assert tb.sum.value.signed_integer == expected_sum.signed_integer, f"SUM mismatch: {tb.sum.value.signed_integer} != {expected_sum}"
        # 补码下，cout没有意义，不检查

if cocotb.SIM_NAME:

    if (os.getenv("PARAM_DATA_EXTEND") == "1") and (os.getenv("PARAM_DATA_SIGNED") == "1"):
        tf = TestFactory(run_test_signed)
        tf.generate_tests()
    elif (os.getenv("PARAM_DATA_EXTEND") == "1") and (os.getenv("PARAM_DATA_SIGNED") == "0"):
        tf = TestFactory(run_test_unsigned)
        tf.generate_tests()
    else:
        tf = TestFactory(run_test_unsigned)
        tf.generate_tests()

        tf = TestFactory(run_test_signed)
        tf.generate_tests()

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))

@pytest.mark.parametrize("data_width", [32, 64, 128])
@pytest.mark.parametrize(("data_extend", "data_signed"), [(True, False), (True, True), (False, False)])
def test_cla_adder(request, data_width, data_extend, data_signed):

    dut = "cla_adder"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, "cla_c4.v"),
        os.path.join(rtl_dir, "full_adder.v"),
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

    parameters['DATA_WIDTH']  = data_width
    parameters['DATA_EXTEND'] = int(data_extend)
    parameters['DATA_SIGNED'] = int(data_signed)

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

