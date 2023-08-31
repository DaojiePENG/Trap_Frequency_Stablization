set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

# -------------------------------------------------------------

set_property IOSTANDARD LVCMOS33 [get_ports SW]
set_property IOSTANDARD LVCMOS33 [get_ports IO_SMA]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LMK_SPI[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LMK_SPI[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LMK_SPI[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LMK_SPI[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports XCLK]
set_property IOSTANDARD LVCMOS33 [get_ports {ROM_SPI[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ROM_SPI[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ROM_SPI[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ROM_SPI[0]}]

set_property IOSTANDARD LVDS_25 [get_ports SYSCLK_P]

# -------------------------------------------------------------

set_property PACKAGE_PIN L23 [get_ports SW]

# J2
set_property PACKAGE_PIN P20 [get_ports IO_SMA]

set_property PACKAGE_PIN K26 [get_ports {LED[0]}]
set_property PACKAGE_PIN M20 [get_ports {LED[1]}]
set_property PACKAGE_PIN L20 [get_ports {LED[2]}]
set_property PACKAGE_PIN L24 [get_ports {LED[3]}]
set_property PACKAGE_PIN L25 [get_ports {LED[4]}]
set_property PACKAGE_PIN M24 [get_ports {LED[5]}]
set_property PACKAGE_PIN M25 [get_ports {LED[6]}]
set_property PACKAGE_PIN L22 [get_ports {LED[7]}]

# LMK_SPI[3:0] = {MISO, MOSI, SCLK, CSEL}
set_property PACKAGE_PIN N19 [get_ports {LMK_SPI[0]}]
set_property PACKAGE_PIN P23 [get_ports {LMK_SPI[1]}]
set_property PACKAGE_PIN P24 [get_ports {LMK_SPI[2]}]
set_property PACKAGE_PIN P19 [get_ports {LMK_SPI[3]}]

set_property PACKAGE_PIN M21 [get_ports XCLK]
set_property PACKAGE_PIN N21 [get_ports SYSCLK_P]

# ROM_SPI[3:0] = {MISO, MOSI, SCLK, CSEL}
set_property PACKAGE_PIN Y21 [get_ports {ROM_SPI[0]}]
set_property PACKAGE_PIN V22 [get_ports {ROM_SPI[1]}]
set_property PACKAGE_PIN Y23 [get_ports {ROM_SPI[2]}]
set_property PACKAGE_PIN V21 [get_ports {ROM_SPI[3]}]





