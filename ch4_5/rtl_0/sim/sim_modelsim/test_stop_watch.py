'''
Author: Wang, Qiaoyu
Date: 2025-12-09 00:00:00
LastEditors: Wang, Qiaoyu
LastEditTime: 2025-12-10 00:05:24
Description: Stop Watch Testbench
'''

import os
import cocotb
import pytest
import random
import cocotb_test.simulator

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.regression import TestFactory


class TB():
    def __init__(self, dut):
        self.dut = dut
        
        # 接口
        self.clk = dut.clk
        self.rst_n = dut.rst_n
        self.clear = dut.clear
        self.start_stop = dut.start_stop
        
        # 输出
        self.hr_h = dut.hr_h
        self.hr_l = dut.hr_l
        self.min_h = dut.min_h
        self.min_l = dut.min_l
        self.sec_h = dut.sec_h
        self.sec_l = dut.sec_l
    
    def get_time_value(self):
        hr = self.hr_h.value.integer * 10 + self.hr_l.value.integer
        min = self.min_h.value.integer * 10 + self.min_l.value.integer
        sec = self.sec_h.value.integer * 10 + self.sec_l.value.integer
        return hr, min, sec
    
    def format_time(self):
        hr, min, sec = self.get_time_value()
        return f"{hr:02d}:{min:02d}:{sec:02d}"

    async def reset(self):
        self.rst_n.value = 0
        self.clear.value = 0
        self.start_stop.value = 0
        await ClockCycles(self.clk, 10)
        self.rst_n.value = 1
        await ClockCycles(self.clk, 5)

    async def press_button(self, button, duration=5):
        button.value = 0
        await ClockCycles(self.clk, 2)
        button.value = 1
        await ClockCycles(self.clk, duration)
        button.value = 0
        await ClockCycles(self.clk, 2)

async def run_test_pause(dut):
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())
    await tb.reset()

    await tb.press_button(dut.start_stop)                     
    
    # 计时2秒
    await ClockCycles(dut.clk, 200)                             
    hr, min, sec = tb.get_time_value()
    dut._log.info(f"After 2 seconds: {tb.format_time()}")
    assert sec == 2, f"Expected 2 seconds, got {sec}"
    
    # 暂停
    dut._log.info("Pressing Start/Stop to pause...")
    await tb.press_button(dut.start_stop)    
    
    # 等待一段时间，时间应该不变
    await ClockCycles(dut.clk, 200)
    hr2, min2, sec2 = tb.get_time_value()
    dut._log.info(f"After pause (should be same): {tb.format_time()}")
    assert sec2 == sec, f"Time should not change when paused, got {sec2}"
    
    # 恢复计时
    dut._log.info("Pressing Start/Stop to resume...")
    await tb.press_button(dut.start_stop)    
    
    # 再计时1秒
    await ClockCycles(dut.clk, 100)
    hr3, min3, sec3 = tb.get_time_value()
    dut._log.info(f"After resume 1 second: {tb.format_time()}")
    assert sec3 == 3, f"Expected 3 seconds, got {sec3}"

async def run_test_clear(dut):
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())
    await tb.reset()
    
    # 启动并计时3秒
    await tb.press_button(dut.start_stop)    
    await ClockCycles(dut.clk, 300)
    hr, min, sec = tb.get_time_value()
    dut._log.info(f"Before clear: {tb.format_time()}")
    assert sec == 3, f"Expected 3 seconds"
    
    # 按下Clear按钮
    dut._log.info("Pressing Clear button...")
    await tb.press_button(dut.clear)    
    
    # 检查是否清零
    await ClockCycles(dut.clk, 10)
    hr, min, sec = tb.get_time_value()
    dut._log.info(f"After clear: {tb.format_time()}")
    assert hr == 0 and min == 0 and sec == 0, f"Should be cleared to 00:00:00"
    
    # 等待一段时间，应该保持停止状态
    await ClockCycles(dut.clk, 200)
    hr2, min2, sec2 = tb.get_time_value()
    assert sec2 == 0, f"Should remain stopped after clear"

async def run_test(dut):
    """
    测试小时计数：
    1. 等待随机时间（模拟秒、分、时的组合）
    2. 验证小时是否正确计数
    """
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())
    await tb.reset()
    
    # 生成随机的目标时间 (0-23小时范围)
    target_hour = random.randint(1, 5)      # 为了加快仿真，只测试1-5小时
    target_minute = random.randint(0, 59)
    target_second = random.randint(0, 59)
    
    # 计算需要的总时钟周期数
    total_seconds = target_hour * 3600 + target_minute * 60 + target_second
    total_clocks = total_seconds * 100

    dut._log.info(f"Target time: {target_hour:02d}:{target_minute:02d}:{target_second:02d}")
    dut._log.info(f"Total seconds to count: {total_seconds}")
    dut._log.info(f"Total clock cycles: {total_clocks}")
    
    # 启动计时
    await tb.press_button(dut.start_stop)
    await ClockCycles(dut.clk, 5)

    # 从这里开始准确计时目标时间
    await ClockCycles(dut.clk, total_clocks)
    
    # 获取实际时间
    hr, min, sec = tb.get_time_value()
    dut._log.info(f"Actual time: {tb.format_time()}")
    
    # 验证时间
    assert hr  == target_hour, f"Hour mismatch: expected {target_hour}, got {hr}"
    assert min == target_minute, f"Minute mismatch: expected {target_minute}, got {min}"
    assert sec == target_second, f"Second mismatch: expected {target_second}, got {sec}"
    
    dut._log.info(f"Time count test passed! {target_hour:02d}:{target_minute:02d}:{target_second:02d}")

if cocotb.SIM_NAME:
    # 测试
    tf_basic = TestFactory(run_test)
    tf_basic.generate_tests()
    
    tf_pause = TestFactory(run_test_pause)
    tf_pause.generate_tests()
    
    tf_clear = TestFactory(run_test_clear)
    tf_clear.generate_tests()
    

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'src'))


def test_stop_watch(request):
    dut = "stop_watch"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
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

