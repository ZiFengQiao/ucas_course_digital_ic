TOPLEVEL_LANG = verilog

SIM ?= questa
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps
COCOTB_RESOLVE_X = ZEROS

RTL_DIR = ../../src

DUT      = stop_watch
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

VERILOG_SOURCES += $(RTL_DIR)/$(DUT).v

# module parameters

# questa通过-g/-G传递parameter参数
SIM_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-g $(TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	@rm -rf vsim.wlf
	@rm -rf transcript
	@rm -rf results.xml