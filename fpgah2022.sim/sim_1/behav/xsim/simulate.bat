@echo off
REM ****************************************************************************
REM Vivado (TM) v2022.1 (64-bit)
REM
REM Filename    : simulate.bat
REM Simulator   : Xilinx Vivado Simulator
REM Description : Script for simulating the design by launching the simulator
REM
REM Generated by Vivado on Sat Nov 26 20:47:46 +0100 2022
REM SW Build 3526262 on Mon Apr 18 15:48:16 MDT 2022
REM
REM IP Build 3524634 on Mon Apr 18 20:55:01 MDT 2022
REM
REM usage: simulate.bat
REM
REM ****************************************************************************
REM simulate design
echo "xsim msim_behav -key {Behavioral:sim_1:Functional:msim} -tclbatch msim.tcl -view F:/home/nathan/workspaces/fpgah2022/sources/fpgah2022/msim_behav.wcfg -log simulate.log"
call xsim  msim_behav -key {Behavioral:sim_1:Functional:msim} -tclbatch msim.tcl -view F:/home/nathan/workspaces/fpgah2022/sources/fpgah2022/msim_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
