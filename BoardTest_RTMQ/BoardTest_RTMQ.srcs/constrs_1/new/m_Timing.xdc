






create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list REFC/inst/rclk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 4 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {ppl_uut0/reg_pid0_out_rwire[0]} {ppl_uut0/reg_pid0_out_rwire[1]} {ppl_uut0/reg_pid0_out_rwire[30]} {ppl_uut0/reg_pid0_out_rwire[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 18 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {filter0_out[0]} {filter0_out[1]} {filter0_out[2]} {filter0_out[3]} {filter0_out[4]} {filter0_out[5]} {filter0_out[6]} {filter0_out[7]} {filter0_out[8]} {filter0_out[9]} {filter0_out[10]} {filter0_out[11]} {filter0_out[12]} {filter0_out[13]} {filter0_out[14]} {filter0_out[15]} {filter0_out[16]} {filter0_out[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 16 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {reg_aio0_out[0]} {reg_aio0_out[1]} {reg_aio0_out[2]} {reg_aio0_out[3]} {reg_aio0_out[4]} {reg_aio0_out[5]} {reg_aio0_out[6]} {reg_aio0_out[7]} {reg_aio0_out[8]} {reg_aio0_out[9]} {reg_aio0_out[10]} {reg_aio0_out[11]} {reg_aio0_out[12]} {reg_aio0_out[13]} {reg_aio0_out[14]} {reg_aio0_out[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {reg_pid0_out[0]} {reg_pid0_out[1]} {reg_pid0_out[2]} {reg_pid0_out[3]} {reg_pid0_out[4]} {reg_pid0_out[5]} {reg_pid0_out[6]} {reg_pid0_out[7]} {reg_pid0_out[8]} {reg_pid0_out[9]} {reg_pid0_out[10]} {reg_pid0_out[11]} {reg_pid0_out[12]} {reg_pid0_out[13]} {reg_pid0_out[14]} {reg_pid0_out[15]} {reg_pid0_out[16]} {reg_pid0_out[17]} {reg_pid0_out[18]} {reg_pid0_out[19]} {reg_pid0_out[20]} {reg_pid0_out[21]} {reg_pid0_out[22]} {reg_pid0_out[23]} {reg_pid0_out[24]} {reg_pid0_out[25]} {reg_pid0_out[26]} {reg_pid0_out[27]} {reg_pid0_out[28]} {reg_pid0_out[29]} {reg_pid0_out[30]} {reg_pid0_out[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {reg_pid0_k2[0]} {reg_pid0_k2[1]} {reg_pid0_k2[2]} {reg_pid0_k2[3]} {reg_pid0_k2[4]} {reg_pid0_k2[5]} {reg_pid0_k2[6]} {reg_pid0_k2[7]} {reg_pid0_k2[8]} {reg_pid0_k2[9]} {reg_pid0_k2[10]} {reg_pid0_k2[11]} {reg_pid0_k2[12]} {reg_pid0_k2[13]} {reg_pid0_k2[14]} {reg_pid0_k2[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 28 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {reg_pid0_out_rwire[2]} {reg_pid0_out_rwire[3]} {reg_pid0_out_rwire[4]} {reg_pid0_out_rwire[5]} {reg_pid0_out_rwire[6]} {reg_pid0_out_rwire[7]} {reg_pid0_out_rwire[8]} {reg_pid0_out_rwire[9]} {reg_pid0_out_rwire[10]} {reg_pid0_out_rwire[11]} {reg_pid0_out_rwire[12]} {reg_pid0_out_rwire[13]} {reg_pid0_out_rwire[14]} {reg_pid0_out_rwire[15]} {reg_pid0_out_rwire[16]} {reg_pid0_out_rwire[17]} {reg_pid0_out_rwire[18]} {reg_pid0_out_rwire[19]} {reg_pid0_out_rwire[20]} {reg_pid0_out_rwire[21]} {reg_pid0_out_rwire[22]} {reg_pid0_out_rwire[23]} {reg_pid0_out_rwire[24]} {reg_pid0_out_rwire[25]} {reg_pid0_out_rwire[26]} {reg_pid0_out_rwire[27]} {reg_pid0_out_rwire[28]} {reg_pid0_out_rwire[29]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {reg_pid0_out_bais[0]} {reg_pid0_out_bais[1]} {reg_pid0_out_bais[2]} {reg_pid0_out_bais[3]} {reg_pid0_out_bais[4]} {reg_pid0_out_bais[5]} {reg_pid0_out_bais[6]} {reg_pid0_out_bais[7]} {reg_pid0_out_bais[8]} {reg_pid0_out_bais[9]} {reg_pid0_out_bais[10]} {reg_pid0_out_bais[11]} {reg_pid0_out_bais[12]} {reg_pid0_out_bais[13]} {reg_pid0_out_bais[14]} {reg_pid0_out_bais[15]} {reg_pid0_out_bais[16]} {reg_pid0_out_bais[17]} {reg_pid0_out_bais[18]} {reg_pid0_out_bais[19]} {reg_pid0_out_bais[20]} {reg_pid0_out_bais[21]} {reg_pid0_out_bais[22]} {reg_pid0_out_bais[23]} {reg_pid0_out_bais[24]} {reg_pid0_out_bais[25]} {reg_pid0_out_bais[26]} {reg_pid0_out_bais[27]} {reg_pid0_out_bais[28]} {reg_pid0_out_bais[29]} {reg_pid0_out_bais[30]} {reg_pid0_out_bais[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 16 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {reg_pid0_k0[0]} {reg_pid0_k0[1]} {reg_pid0_k0[2]} {reg_pid0_k0[3]} {reg_pid0_k0[4]} {reg_pid0_k0[5]} {reg_pid0_k0[6]} {reg_pid0_k0[7]} {reg_pid0_k0[8]} {reg_pid0_k0[9]} {reg_pid0_k0[10]} {reg_pid0_k0[11]} {reg_pid0_k0[12]} {reg_pid0_k0[13]} {reg_pid0_k0[14]} {reg_pid0_k0[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {u_reg_pid0_out[0]} {u_reg_pid0_out[1]} {u_reg_pid0_out[2]} {u_reg_pid0_out[3]} {u_reg_pid0_out[4]} {u_reg_pid0_out[5]} {u_reg_pid0_out[6]} {u_reg_pid0_out[7]} {u_reg_pid0_out[8]} {u_reg_pid0_out[9]} {u_reg_pid0_out[10]} {u_reg_pid0_out[11]} {u_reg_pid0_out[12]} {u_reg_pid0_out[13]} {u_reg_pid0_out[14]} {u_reg_pid0_out[15]} {u_reg_pid0_out[16]} {u_reg_pid0_out[17]} {u_reg_pid0_out[18]} {u_reg_pid0_out[19]} {u_reg_pid0_out[20]} {u_reg_pid0_out[21]} {u_reg_pid0_out[22]} {u_reg_pid0_out[23]} {u_reg_pid0_out[24]} {u_reg_pid0_out[25]} {u_reg_pid0_out[26]} {u_reg_pid0_out[27]} {u_reg_pid0_out[28]} {u_reg_pid0_out[29]} {u_reg_pid0_out[30]} {u_reg_pid0_out[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 16 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {reg_pid0_k1[0]} {reg_pid0_k1[1]} {reg_pid0_k1[2]} {reg_pid0_k1[3]} {reg_pid0_k1[4]} {reg_pid0_k1[5]} {reg_pid0_k1[6]} {reg_pid0_k1[7]} {reg_pid0_k1[8]} {reg_pid0_k1[9]} {reg_pid0_k1[10]} {reg_pid0_k1[11]} {reg_pid0_k1[12]} {reg_pid0_k1[13]} {reg_pid0_k1[14]} {reg_pid0_k1[15]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
