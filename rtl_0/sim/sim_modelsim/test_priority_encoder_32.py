'''
Author: Wang, Qiaoyu
Date: 2025-11-15 15:40:10
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-11-16 23:22:30
Description: 
'''

import logging

import random
from cocotb import start_soon
from cocotb.triggers import Timer
from cocotb.queue import Queue
from cocotb.regression import TestFactory
from typing import Literal

class TB:
    def __init__(self, dut):
        self.log = logging.getLogger("cocotb.tb.pe32")
        self.dut = dut
        self._threads = []

    @staticmethod
    def soft_pe(data_in: int = 0, data_width = 32, prio: Literal['high', 'low'] = 'high', dir: Literal['left', 'right'] = 'left', default_value = 32) -> int:
        pos_out = 0
        data_in = data_in & (2**data_width - 1)

        if data_in == 0:
            return default_value

        # 默认按照从高位到低位进行位置编码，最后再修改

        if prio == 'high':
            for pos in range(data_width):
                if (data_in & ((0b1 << data_width-1) >> pos)):
                    # 从高往下遍历
                    pos_out = pos
                    break
        else:
            for pos in range(data_width):
                if (data_in & (0b1 << pos)):
                    # 从低往上遍历
                    pos_out = data_width - 1 - pos
                    break

        return pos_out if dir == 'left' else data_width - 1 - pos_out

async def run_test(dut, test_counts = 2**16):
    tb = TB(dut)

    dut._log.info("Test start")

    for _ in range(test_counts):
        # 随机数测试
        data_in = random.randint(0, 2**32 - 1)
        data_in = data_in & (1 << random.randint(0, 31))
        tb.dut.data_in.value = data_in
        await Timer(1, 'ns')
        pos_out = tb.dut.pos_out.value.integer
        soft_pos_out = tb.soft_pe(data_in, dir="left")

        assert pos_out == soft_pos_out, f"Mismatch for data_in={data_in:#0{10}x}: dut pos_out={pos_out}, soft pe pos_out={soft_pos_out}"
        tb.log.info(f"data_in={data_in:#0{10}x}: dut pos_out={pos_out}, soft pe pos_out={soft_pos_out}")

tf = TestFactory(run_test)
tf.add_option("test_counts", [2**16])
tf.generate_tests()
