#!/bin/bash -f
# ****************************************************************************
# Vivado (TM) v2018.1 (64-bit)
#
# Filename    : elaborate.sh
# Simulator   : Xilinx Vivado Simulator
# Description : Script for elaborating the compiled design
#
# Generated by Vivado on Fri Mar 15 16:00:36 CET 2019
# SW Build 2188600 on Wed Apr  4 18:39:19 MDT 2018
#
# Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
#
# usage: elaborate.sh
#
# ****************************************************************************
ExecStep()
{
"$@"
RETVAL=$?
if [ $RETVAL -ne 0 ]
then
exit $RETVAL
fi
}
ExecStep xelab -wto 0c60939e885346d3a17bd940637aeb3f --incr --debug typical --relax --mt 8 -L gtwizard_ultrascale_v1_7_3 -L xil_defaultlib -L work -L interlaken_v2_4_0 -L fifo_generator_v13_2_2 -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot Core199_verification_behav work.Core199_verification work.glbl -log elaborate.log