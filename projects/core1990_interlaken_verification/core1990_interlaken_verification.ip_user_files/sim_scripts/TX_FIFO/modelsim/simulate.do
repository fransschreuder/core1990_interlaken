onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc" -t 1ps -L xil_defaultlib -L xpm -L fifo_generator_v13_2_2 -L work -L unisims_ver -L unimacro_ver -L secureip -lib work work.TX_FIFO work.glbl

do {wave.do}

view wave
view structure
view signals

do {TX_FIFO.udo}

run -all

quit -force
