'''
Author: Wang, Qiaoyu
Date: 2025-12-08 22:50:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-12 12:11:34
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
        # 接口
        self.data_a = dut.data_a
        self.data_b = dut.data_b
        self.product = dut.product

        self._data_width = len(self.data_a)
        self._result_width = len(self.product)

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

        await Timer(1, "ps")

        expected_product = LogicArray((a.signed_integer * b.signed_integer) % 2**tb._result_width, Range(tb._result_width-1, "downto", 0))

        dut_result = tb.product.value.signed_integer
        expected_result = expected_product.signed_integer
        assert dut_result == expected_result, f"product mismatch: {dut_result} != {expected_result}"

if cocotb.SIM_NAME:
    tf = TestFactory(run_test_signed)
    tf.generate_tests()

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

