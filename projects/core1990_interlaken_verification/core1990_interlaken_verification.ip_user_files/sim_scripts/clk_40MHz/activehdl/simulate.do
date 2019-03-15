onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+clk_40MHz -L xil_defaultlib -L xpm -L work -L unisims_ver -L unimacro_ver -L secureip -O5 work.clk_40MHz work.glbl

do {wave.do}

view wave
view structure

do {clk_40MHz.udo}

run -all

endsim

quit -force
