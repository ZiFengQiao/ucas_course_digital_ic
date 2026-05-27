#==================================Env Vars===================================
# set TIME_UNIT 1
# set CYCLE200M [expr 5 * $TIME_UNIT]
# set CYCLE8M [expr 125 * $TIME_UNIT]

#==================================Design Env=================================
#------------------------------Operating Conditions---------------------------
#GUIDANCE: the worst case: P(1), V(LOW), T(HIGH) for stricter constraint.
#set_operating_conditions -max ssg0p81v125c(default)

#-------------------------System Interface Characteristics--------------------
#An AND2 cell with minimum drving strength for stricter constraints.
# set_driving_cell -lib_cell AN2D0BWP7T30P140 [all_inputs]




#---------------------------------Wire Load Model-----------------------------
#GUIDANCE: WLM selection does not matter, it is not accurate.
#set auto_wire_load_selection true(default)

#==================================Design Rule Constr=========================
#GUIDANCE: use the default
#set_max_transition  0.25 [current_design]
#set_max_fanout      32   [current_design]
#set_max_capacitance 0.5  [current_design]

#==============================Design Optimiz Constr=========================
#--------------------------------Clock Definition------------------------------
create_clock -name clk -period 1 [get_ports clk]
set_dont_touch_network [get_clocks clk]
set_ideal_network [get_ports clk] -no_propagate

set_clock_uncertainty -hold 0.053 [all_clocks]
set_clock_transition 0.15 [all_clocks]
set_input_transition 0.2 [remove_from_collection [all_inputs] [all_clocks]]

#If real clock, set infinite drive strength to avoid automatic buffer insertion.
set_drive 0 [get_ports [list clk]]


#--------------------------------I/O Constraint-----------------------------
#rst_ports
set rst_inputs [get_ports rst_n]
set_ideal_network $rst_inputs
set_false_path -from $rst_inputs


set_dont_touch_network [all_inputs]
set_dont_touch_network [all_outputs]

set_load -pin_load 0.002 [all_outputs]
#set_fanout_load 4 [all_outputs]
set_input_delay -max 0.6 -clock clk [all_inputs]
set_output_delay -max 0.8 -clock –source_latency_included clk [all_outputs]



# #ports in clk0 domain
# set clk0_ports [get_ports [list \
#     clk0_port0 \
#     clk0_port1 \
# ]]
# set clk0_inputs [get_ports $clk0_ports -filter "port_direction == in"]
# set clk0_outputs [get_ports $clk0_ports -filter "port_direction == out"]
# set_input_delay -max [expr $CYCLE200M * 0.6] -clock [get_clocks clk0] $clk0_inputs -add_delay
# set_output_delay -max [expr $CYCLE200M * 0.3] -clock [get_clocks clk0] $clk0_outputs -add_delay

#---------------------------------Timing Exceptions-----------------------------
#
# set false_ports [get_ports [list \
#     false_port0 \
#     false_port1 \
# ]]
# set false_inputs [get_ports $false_ports -filter "port_direction == in"]
# set false_outputs [get_ports $false_ports -filter "port_direction == out"]

# set_false_path -from [get_ports $false_inputs]
# set_false_path -to [get_ports $false_outputs]
