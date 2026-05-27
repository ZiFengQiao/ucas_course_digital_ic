import os
import cocotb
import pytest
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, FallingEdge
from cocotb.regression import TestFactory

import random

class TB():
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.clk
        cocotb.start_soon(Clock(self.clk, 10, units="ns").start())

        self.rst_n = dut.rst_n

        self.din = dut.din
        self.res = dut.res

    async def reset(self):
        self.rst_n.value = 0
        await ClockCycles(self.clk, 5)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 2)

async def run_test(dut):
    tb = TB(dut)
    tb.din.value = 0
    await tb.reset()

    value = 0

    # 同步到上升沿
    await RisingEdge(tb.clk)
    
    for i in range(32):
        # 检查上一拍输出
        await FallingEdge(tb.clk) 
        din = int(random.random() < 0.5)

        res = tb.res.value.integer

        assert res == (value%15 == 0), f"error, value = {value}"

        value = (value << 1) + din
        # 产生新的输入
        tb.din.value = din
        await RisingEdge(tb.clk)
    
if cocotb.SIM_NAME:
    factory = TestFactory(run_test)
    factory.generate_tests()


tests_dir = os.path.dirname(__file__)
rtl_dir = tests_dir

# @pytest.mark.parametrize()
def test_seqdiv15(request):
    dut = "seqdiv15"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ]

    parameters = {}

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
