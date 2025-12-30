PROJECT_NAME ?= sram_ctr_ahb_top
SYN ?= 1
SIM ?= 0
QPF_FILE = $(PROJECT_NAME).qpf
QSF_FILE = $(PROJECT_NAME).qsf

TOP_ENTITY = sram_ctr_ahb_top

RTL_PATH = $(abspath ../../src)
# LIB_PATH = $(abspath ../../lib)

RTL_FILES += $(RTL_PATH)/sram_ctr_ahb_top.v
RTL_FILES += $(RTL_PATH)/altera_sram.v
RTL_FILES += $(RTL_PATH)/sram_ctr_ahb.v

# IP_TCL_FILES += ./src/pll_sys.tcl
# IP_FILES += pll_sys.ip
# IP_TCL_FILES = 
# IP_FILES = 
ASSIGN_FILES = $(wildcard ./qsf/*.qsf)

OUTPUT_FILES = *.ip *.qpf *.qsf *.qws quartus.* \
				./dni ./qdb ./output_files \
				./support_logic ./simulation ./$(basename $(IP_FILES))

main: project_init generate_logic

project_init:
	@if test -e $(QPF_FILE); then \
		echo "Project already exists."; \
	else \
		echo "Create quartus project: $(PROJECT_NAME)"; \
		quartus_sh --prepare $(PROJECT_NAME); \
	fi

	@echo "set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files" >> $(QSF_FILE)
	@echo "set_global_assignment -name TOP_LEVEL_ENTITY $(TOP_ENTITY)" >> $(QSF_FILE)

	@for file in $(RTL_FILES); do \
		echo "set_global_assignment -name VERILOG_FILE $$file" >> $(QSF_FILE); \
	done

	@for file in $(ASSIGN_FILES); do \
		cat $$file >> $(QSF_FILE); \
	done

$(IP_FILES): project_init
	@for file in $(IP_TCL_FILES); do \
		qsys-script --script=$$file --quartus-project=$(PROJECT_NAME); \
	done

generate_ip_files: $(IP_FILES)
	@for file in $(IP_FILES); do \
		qsys-generate $$file --simulation=VERILOG --quartus-project=$(PROJECT_NAME); \
		if [ $$SYN ]; then \
		    qsys-generate $$file --block-symbol-file --synthesis=VERILOG; \
    		echo "Generated synthesis files"; \
		fi; \
	done

# todo: 实现自动生成support logic
generate_logic: generate_ip_files
	quartus_ipgenerate $(PROJECT_NAME) -c $(PROJECT_NAME) --run_default_mode_op

	quartus_syn --read_settings_files=on --write_settings_files=off $(PROJECT_NAME) -c $(PROJECT_NAME) --quick_elab

	quartus_tlg --read_settings_files=on --write_settings_files=off --skip_quick_elaboration $(PROJECT_NAME) -c $(PROJECT_NAME)

syn_logic: generate_logic
	
	quartus_syn --read_settings_files=on --write_settings_files=off --analysis_and_elaboration $(PROJECT_NAME) -c $(PROJECT_NAME) --synthesis 

generate_sim_script: generate_logic
	ip-make-simscript \
	--output-directory=./cocotb/ \
	--spd=$(shell find . -name "*.spd" -print | tr '\n' ',') \
	--modelsim-flow=TRADITIONAL \
	--simulator=MODELSIM \
	--use-relative-paths --quiet

SIM_FILES = ./cocotb/common ./cocotb/mentor
clean:
	@rm -rf $(OUTPUT_FILES) *.log
	@rm -rf $(SIM_FILES)
