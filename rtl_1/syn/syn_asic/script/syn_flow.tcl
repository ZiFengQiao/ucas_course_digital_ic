#--------------------------Specify Libraries--------------------------
# set mem_link_library "$MEM_LINK_PATH/T22SRF2HD256X16M2K2H_ssgwct0p81vn40c.db"
set mem_link_library ""
# set synthetic_library "dw_foundation.sldb"

set TSMC40_TGTLIB "./lib/NLDM/tcbn40lpbwp_200a/tcbn40lpbwpbc.db"
set TSMC90_TGTLIB "/home/techlib/tsmc90/aci/sc-x/synopsys/slow.db"

set target_library $TSMC40_TGTLIB

# set target_library "/home/techlib/tsmc90/aci/sc-x/synopsys/slow.db"
set link_library "* $target_library $mem_link_library"
#set search_path "$TAR_PATH $MEM_LINK_PATH"

set_host_options -max_cores 16

set TOP top

file mkdir log
file mkdir rpt
file mkdir output

set_svf ./output/${TOP}.svf


#--------------------------Prepare Filelist---------------------------
set FILE_LIST ""
set f [open "./script/filelist.f" r]
while {![eof $f]} {
    gets $f line
    append FILE_LIST "$line "
}
echo $FILE_LIST
close $f

define_design_lib work -path ./analyzed
analyze -format sverilog $FILE_LIST
# analyze -library work -autoread ./script/filelist_1.f -define {SYN_DC}
redirect -tee ./log/${TOP}_elab.log {elaborate -library work $TOP}
current_design $TOP



#--------------------------Read Designs------------------------------
# analyze -format sverilog $FILE_LIST
# elaborate $TOP

#------------------------Set Current Design--------------------------
#current_design $TOP(auto)

#--------------------------Link Designs------------------------------
#link(auto)

#-------------------------------SDC----------------------------------
source ./script/top_sdc.tcl

#--------------------Map and Optimize the Design---------------------
redirect -tee ./log/${TOP}_cple.log \
{compile_ultra -no_autoungroup -no_boundary_optimization -no_seq_output_inversion -incremental}



#---------------Check the Synthesized Design for Consistency---------
check_design -summary > ./rpt/check_design.rpt



optimize_netlist -area
uniquify -force


#---------------------Report Timing and Area-------------------------
report_timing -max_paths 1000 -transition_time -capacitance -nets > ./rpt/timing.rpt
report_area -hierarchy > ./rpt/hier_area.rpt
report_area > ./rpt/area.rpt
report_power > ./rpt/power.rpt

#----------------------Save Design Database--------------------------
change_names -rules sverilog -hierarchy

write_file -format verilog -h -o ./output/design_netlist.v
write_sdc ./output/${TOP}.sdc
write_sdf ./output/${TOP}.sdf
set_svf -off




