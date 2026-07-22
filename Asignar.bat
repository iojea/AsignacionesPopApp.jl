@echo off
cd /d C:\Users\Admin\Documents\Jorge\AsignacionesPopApp.jl
julia --project=. -e "using AsignacionesPopApp; AsignacionesPopApp.main(String[])"
pause