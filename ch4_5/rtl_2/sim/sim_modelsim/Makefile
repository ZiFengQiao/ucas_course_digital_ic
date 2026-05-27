TOPLEVEL_LANG = verilog

SIM ?= questa
WAVES ?= 1

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps
COCOTB_RESOLVE_X = ZEROS

RTL_DIR = ../../src

DUT      = booth_multi
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

VERILOG_SOURCES += $(RTL_DIR)/cla_c4.v
VERILOG_SOURCES += $(RTL_DIR)/full_adder.v
VERILOG_SOURCES += $(RTL_DIR)/cla_adder.v
VERILOG_SOURCES += $(RTL_DIR)/booth_3b.v
VERILOG_SOURCES += $(RTL_DIR)/booth_encoder.v
VERILOG_SOURCES += $(RTL_DIR)/booth_multi.v
VERILOG_SOURCES += $(RTL_DIR)/wallace_tree_1b.v
VERILOG_SOURCES += $(RTL_DIR)/wallace_tree.v

# module parameters
export PARAM_DATA_WIDTH := 16

# questa通过-g/-G传递parameter参数
SIM_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-g $(TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	@rm -rf vsim.wlf
	@rm -rf transcript
	@rm -rf results.xml