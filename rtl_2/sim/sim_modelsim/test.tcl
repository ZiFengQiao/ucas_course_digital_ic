# parameter settings
set RTL_DIR "../../src"
set RTL_DIR_TB "../tb_src"
set TOP_ENTITY "tb_async_fifo"

# source
source ./common_files.tcl

# body
transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

set design_files [get_design_files $RTL_DIR]
puts "Design Files: $design_files"

set design_files_tb [get_design_files $RTL_DIR_TB]
puts "Testbench Files: $design_files_tb"

set rtl_files [concat $design_files $design_files_tb]

foreach rtl_file $rtl_files {
    vlog -work rtl_work $rtl_file
}

set rnd_seed [clock seconds]

vsim -t 1ps -L rtl_work -L work +SEED=${rnd_seed} -voptargs="+acc" $TOP_ENTITY

do wave.do

run -all
