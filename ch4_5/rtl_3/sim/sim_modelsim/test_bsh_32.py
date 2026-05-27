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
        # 接口
        self.data_a = dut.data_in
        self.sh = dut.sh
        self.dir = dut.dir
        self.data_out = dut.data_out

        self._data_width = len(self.data_a)


async def run_test(dut):
    tb = TB(dut)

    test_data = random.randint(0, 2**tb._data_width - 1)

    for sh in range(tb._data_width):
        for dir in [0, 1]:
            tb.data_a.value = test_data
            tb.sh.value = sh
            tb.dir.value = dir

            await Timer(1, "ps")

            # 循环移位（rotate）
            # dir == 0: 左循环移位，dir == 1: 右循环移位
            if dir == 0:
                # 左循环移位：高位循环到低位
                expected = ((test_data << sh) | (test_data >> (tb._data_width - sh))) & (2**tb._data_width - 1)
            else:
                # 右循环移位：低位循环到高位
                expected = ((test_data >> sh) | (test_data << (tb._data_width - sh))) & (2**tb._data_width - 1)

            assert tb.data_out.value.integer == expected, f"Rotate failed for data={bin(test_data)}, sh={sh}, dir={dir}: got {tb.data_out.value.binstr}, expected {bin(expected)}"

if cocotb.SIM_NAME:
    tf = TestFactory(run_test)
    tf.generate_tests()

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))

@pytest.mark.parametrize("data_width", [32, 64, 128])
def test_bsh_32(request, data_width):
    dut = "bsh_32"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
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
        simulation_args=["-voptargs=\"+acc\""],
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )

