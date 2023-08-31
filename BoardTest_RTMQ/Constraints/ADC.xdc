# ADC0: J8, ADC1: J9

set_property IOSTANDARD LVCMOS33 [get_ports {DPOT_SPI[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DPOT_SPI[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DPOT_SPI[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports AD0_SMP]
set_property IOSTANDARD LVCMOS33 [get_ports AD0_OFL]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_CFG[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_CFG[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_CFG[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_CFG[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD0_DAT[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports AD1_SMP]
set_property IOSTANDARD LVCMOS33 [get_ports AD1_OFL]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_CFG[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_CFG[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_CFG[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_CFG[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {AD1_DAT[0]}]

# -------------------------------------------------------------

# DPOT_SPI[2:0] = {MOSI, SCLK, CSEL}
set_property PACKAGE_PIN P21 [get_ports {DPOT_SPI[0]}]
set_property PACKAGE_PIN N23 [get_ports {DPOT_SPI[1]}]
set_property PACKAGE_PIN N24 [get_ports {DPOT_SPI[2]}]

# -------------------------------------------------------------

set_property PACKAGE_PIN AA19 [get_ports AD0_SMP]
set_property PACKAGE_PIN W15 [get_ports AD0_OFL]

# AD0_CFG[3:0] = {MODE, RAND, DITH, SHDN}
set_property PACKAGE_PIN AF19 [get_ports {AD0_CFG[0]}]
set_property PACKAGE_PIN AF18 [get_ports {AD0_CFG[1]}]
set_property PACKAGE_PIN Y15 [get_ports {AD0_CFG[2]}]
set_property PACKAGE_PIN W14 [get_ports {AD0_CFG[3]}]

set_property PACKAGE_PIN AE18 [get_ports {AD0_DAT[0]}]
set_property PACKAGE_PIN AC18 [get_ports {AD0_DAT[1]}]
set_property PACKAGE_PIN AD18 [get_ports {AD0_DAT[2]}]
set_property PACKAGE_PIN AD17 [get_ports {AD0_DAT[3]}]
set_property PACKAGE_PIN AF17 [get_ports {AD0_DAT[4]}]
set_property PACKAGE_PIN AE17 [get_ports {AD0_DAT[5]}]
set_property PACKAGE_PIN AA18 [get_ports {AD0_DAT[6]}]
set_property PACKAGE_PIN AC17 [get_ports {AD0_DAT[7]}]
set_property PACKAGE_PIN AB17 [get_ports {AD0_DAT[8]}]
set_property PACKAGE_PIN AC16 [get_ports {AD0_DAT[9]}]
set_property PACKAGE_PIN AA17 [get_ports {AD0_DAT[10]}]
set_property PACKAGE_PIN AB16 [get_ports {AD0_DAT[11]}]
set_property PACKAGE_PIN Y17 [get_ports {AD0_DAT[12]}]
set_property PACKAGE_PIN Y18 [get_ports {AD0_DAT[13]}]
set_property PACKAGE_PIN Y16 [get_ports {AD0_DAT[14]}]
set_property PACKAGE_PIN AA15 [get_ports {AD0_DAT[15]}]

# -------------------------------------------------------------

set_property PACKAGE_PIN AC19 [get_ports AD1_SMP]
set_property PACKAGE_PIN AF20 [get_ports AD1_OFL]

# AD1_CFG[3:0] = {MODE, RAND, DITH, SHDN}
set_property PACKAGE_PIN AD20 [get_ports {AD1_CFG[0]}]
set_property PACKAGE_PIN AE21 [get_ports {AD1_CFG[1]}]
set_property PACKAGE_PIN AD19 [get_ports {AD1_CFG[2]}]
set_property PACKAGE_PIN AE20 [get_ports {AD1_CFG[3]}]

set_property PACKAGE_PIN AD26 [get_ports {AD1_DAT[0]}]
set_property PACKAGE_PIN AB21 [get_ports {AD1_DAT[1]}]
set_property PACKAGE_PIN AD25 [get_ports {AD1_DAT[2]}]
set_property PACKAGE_PIN AB22 [get_ports {AD1_DAT[3]}]
set_property PACKAGE_PIN AA20 [get_ports {AD1_DAT[4]}]
set_property PACKAGE_PIN AD24 [get_ports {AD1_DAT[5]}]
set_property PACKAGE_PIN AD23 [get_ports {AD1_DAT[6]}]
set_property PACKAGE_PIN AC21 [get_ports {AD1_DAT[7]}]
set_property PACKAGE_PIN AF25 [get_ports {AD1_DAT[8]}]
set_property PACKAGE_PIN AE23 [get_ports {AD1_DAT[9]}]
set_property PACKAGE_PIN AB20 [get_ports {AD1_DAT[10]}]
set_property PACKAGE_PIN AF23 [get_ports {AD1_DAT[11]}]
set_property PACKAGE_PIN AE22 [get_ports {AD1_DAT[12]}]
set_property PACKAGE_PIN AD21 [get_ports {AD1_DAT[13]}]
set_property PACKAGE_PIN AB19 [get_ports {AD1_DAT[14]}]
set_property PACKAGE_PIN AF22 [get_ports {AD1_DAT[15]}]





