'''
Author: Wang, Qiaoyu
Date: 2025-11-15 15:40:10
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-11-15 15:42:57
Description: 
'''

import logging

from cocotb.triggers import Timer
from cocotb.regression import TestFactory

class TB:
    def __init__(self, dut):
        self.log = logging.getLogger("cocotb.tb.bcd")
        self.dut = dut
        self._threads = []

async def run_test(dut):
    tb = TB(dut)

    dut._log.info("Test start")
    dut.bin_in = 0
    await Timer(10, "ns")

    for value in range(2**8 - 1):
        dut.bin_in.value = value
        await Timer(2, units="ns")
        bcd_out = tb.dut.bcd_out.value.integer

        ref_bcd_result = [
            (value // 100) % 10,
            (value // 10) % 10,
            (value % 10)
        ]

        dut_bcd_result = [
            (bcd_out >> 8) & 0xF,
            (bcd_out >> 4) & 0xF,
            bcd_out & 0xF
        ]

        assert ref_bcd_result == dut_bcd_result, f"BCD conversion error: bin_in={value}, expected BCD={ref_bcd_result}, got BCD={dut_bcd_result}"
        tb.log.info(f"bin_in={value}, BCD={dut_bcd_result} - OK")

tf = TestFactory(run_test)
tf.generate_tests()
