'''
Author: Wang, Qiaoyu
Date: 2025-11-15 15:40:10
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-11-15 15:42:57
Description: 
'''

import logging

import random
from cocotb import start_soon
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb.regression import TestFactory

class TB:

    # 模拟 6 depth 的寄存器
    _local_reg_lst = [0 for _ in range(6)]
    _target_seq = [
        "111000",
        "101110"
    ]
    def __init__(self, dut):
        self.log = logging.getLogger("cocotb.tb.seq")
        self.dut = dut
        self.rst_n = dut.rst_n
        self.clk = dut.clk

        self._t_clock = Clock(self.dut.clk, 10, units="ns")
        self._threads = [start_soon(self._t_clock.start())]

        self._in_rst = False

        self.dut.din_vld.value = 0
        self.dut.din.value = 0

    async def reset(self):
        self._in_rst = True

        self.rst_n.value = 0
        await ClockCycles(self.clk, 5)
        self.rst_n.value = 1
        await RisingEdge(self.clk)
        self._in_rst = False

        # 初始化寄存器
        self._local_reg_lst = [0 for _ in range(6)]

    def soft_seq_detector(self, din_vld, din) -> bool:
        # 软件模拟检测
        if not din_vld:
            return False
        else:
            self._local_reg_lst.pop(0)
            self._local_reg_lst.append(din)

            reg_str = ''.join(str(bit) for bit in self._local_reg_lst)

            for seq in self._target_seq:
                if reg_str == seq:
                    return True
            return False

async def run_test(dut, vld_pct = 0.7, test_seq = "001110001101110000"):
    tb = TB(dut)
    await tb.reset()

    dut._log.info("Test start")

    async def result_check_next(idx):
        await RisingEdge(tb.clk)
        dut_result = tb.dut.result.value
        assert dut_result == 1, f"DUT result check failed at index {idx}, expected 1, got {int(dut_result)}"
        tb.log.info(f"DUT result check passed at index {idx}")

    soft_result_lst = []
    for idx, bit in enumerate(test_seq):

        # 等待信号有效
        while random.random() > vld_pct:
            tb.dut.din_vld.value = 0
            await RisingEdge(tb.clk)

        tb.dut.din_vld.value = 1
        tb.dut.din.value = int(bit)
        await RisingEdge(tb.clk)    # 数据送入

        soft_result = tb.soft_seq_detector(1, int(bit))

        # 检测下一个周期输出结果是否正确
        if soft_result:
            start_soon(result_check_next(idx))
    # 等待一个周期
    await RisingEdge(tb.clk)

tf = TestFactory(run_test)
tf.add_option("test_seq", ["001110001101110000"])
tf.generate_tests()
