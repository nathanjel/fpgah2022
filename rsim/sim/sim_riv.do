vsim +access +r tb.tb_top -t ps \
-L altera_mf_ver \
-L hackathon \
-L tb

add wave sim:/tb_top/dut_top/mac_wrapper/mac_rx/MAC

do waves.do
run 200us