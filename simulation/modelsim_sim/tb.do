
quit -sim

vlib work  

#mapping work library to current directory
#vmap [-help] [-c] [-del] [<logical_name>] [<path>]
vmap work  

#compile all .v files to work library
#-work <path>       Specify library WORK
#-vlog01compat      Ensure compatibility with Std 1364-2001
#-incr              Enable incremental compilation
#"rtl/*.v"          rtl directory all .v files, support relative path, need to add ""
#vlog

vlog -novopt ../../project/src/gowin_pllvr/hpram_pllvr.v

vlog -novopt ../../project/src/dvi_tx/dvi_tx.vo

vlog -novopt ../../project/src/video_frame_buffer/video_frame_buffer.vo

vlog -novopt  \
+incdir+../../project/src/hyperram_memory_interface/temp/HYPERRAM/ \
../../project/src/hyperram_memory_interface/hyperram_memory_interface.vo

vlog -novopt  \
+incdir+../../tb/hpram_model/ \
../../tb/hpram_model/W956D8MKP.v

#testbench
vlog -novopt ../../tb/config/*.v
vlog -novopt ../../tb/syn_code/*.v
vlog -novopt ../../tb/driver/*.v
vlog -novopt ../../tb/monitor/*.v
vlog -novopt ../../tb/prim_sim.v
vlog -novopt ../../tb/dvi_rx/dvi_rx.vo

vlog -novopt ../../tb/tb.v

#complie all .vhd files
#-work <path>       Specify library WORK
#-93                Enable support for VHDL 1076-1993
#-2002              Enable support for VHDL 1076-2002
#vcom

#simulate testbench top file
#-L <libname>                     Search library for design units instantiated from Verilog and for VHDL default component binding
#+nowarn<CODE | Number>           Disable specified warning message  (Example: +nowarnTFMPC)                      
#-t [1|10|100]fs|ps|ns|us|ms|sec  Time resolution limit VHDL default: resolution setting from .ini file) 
#                                 (Verilog default: minimum time_precision in the design)
#-novopt                          Force incremental mode (pre-6.0 behavior)

vsim +nowarnTFMPC -L work  -novopt -l tb.log work.tb 

#generate wave log format(WLF)......
log -r /*

#open wave window
view wave

#add simulation singals
onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {input paramters}
add wave -noupdate -radix ascii       /tb/BMP_VIDEO_FORMAT   
add wave -noupdate                    /tb/BMP_PIXEL_CLK_FREQ 
add wave -noupdate -radix unsigned    /tb/BMP_WIDTH      
add wave -noupdate -radix unsigned    /tb/BMP_HEIGHT     
add wave -noupdate -radix ascii       /tb/BMP_OPENED_NAME
add wave -noupdate -radix unsigned    /tb/BMP_REPEAT      
add wave -noupdate -radix unsigned    /tb/BMP_LINK 
                                                      
add wave -noupdate -divider {output paramters}        
add wave -noupdate -radix unsigned    /tb/BMP_OUTPUTED_WIDTH   
add wave -noupdate -radix unsigned    /tb/BMP_OUTPUTED_HEIGHT  
add wave -noupdate -radix ascii       /tb/BMP_OUTPUTED_NAME 
add wave -noupdate -radix unsigned    /tb/BMP_OUTPUTED_NUMBER   

add wave -noupdate -divider {sram control signals}
add wave -noupdate                    /tb/init_calib
add wave -noupdate                    /tb/hpram_ref_clk 
add wave -noupdate                    /tb/memory_clk
add wave -noupdate                    /tb/pll_lock         
add wave -noupdate                    /tb/cmd                       
add wave -noupdate                    /tb/cmd_en                 
add wave -noupdate -radix hexadecimal /tb/addr                   
add wave -noupdate -radix hexadecimal /tb/wr_data               
add wave -noupdate -radix hexadecimal /tb/data_mask       
add wave -noupdate                    /tb/rd_data_valid             
add wave -noupdate -radix hexadecimal /tb/rd_data  

add wave -noupdate -divider {driver_inst output}
add wave -noupdate                    /tb/rst_n
add wave -noupdate                    /tb/pixel_clock
add wave -noupdate                    /tb/vsync
add wave -noupdate                    /tb/hsync
add wave -noupdate                    /tb/data_valid
add wave -noupdate -radix hexadecimal /tb/data0_r
add wave -noupdate -radix hexadecimal /tb/data0_g
add wave -noupdate -radix hexadecimal /tb/data0_b
add wave -noupdate -radix unsigned    /tb/driver_inst/u_video_gen/u_video_gen_syn/Vs_cnt
add wave -noupdate -radix unsigned    /tb/driver_inst/u_video_gen/u_video_gen_syn/Hs_cnt

add wave -noupdate -divider {VFB_inst output}
add wave -noupdate                    /tb/pixel_clock
add wave -noupdate                    /tb/syn_off0_re
add wave -noupdate                    /tb/syn_off0_vs
add wave -noupdate                    /tb/syn_off0_hs
add wave -noupdate                    /tb/off0_syn_de
add wave -noupdate -radix hexadecimal /tb/off0_syn_data

add wave -noupdate -divider {output channel signals}
add wave -noupdate                    /tb/serial_clk
add wave -noupdate                    /tb/tmds_clk_p 
add wave -noupdate                    /tb/tmds_clk_n        
add wave -noupdate                    /tb/tmds_data_p
add wave -noupdate                    /tb/tmds_data_n

add wave -noupdate -divider {output channel signals}
add wave -noupdate                    /tb/rx0_pclk 
add wave -noupdate                    /tb/rx0_vsync       
add wave -noupdate                    /tb/rx0_hsync
add wave -noupdate                    /tb/rx0_de   
add wave -noupdate                    /tb/rx0_r
add wave -noupdate                    /tb/rx0_g
add wave -noupdate                    /tb/rx0_b 

add wave -noupdate -divider {monitor input}
add wave -noupdate                    /tb/m_clk
add wave -noupdate                    /tb/m_vs_rgb
add wave -noupdate                    /tb/m_hs_rgb
add wave -noupdate                    /tb/m_de_rgb
add wave -noupdate -radix hexadecimal /tb/m_data0_r
add wave -noupdate -radix hexadecimal /tb/m_data0_g
add wave -noupdate -radix hexadecimal /tb/m_data0_b

add wave -noupdate -divider {monitor signal}
add wave -noupdate -radix unsigned    /tb/monitor_inst/u_video2bmp/bmp_outputed_number
add wave -noupdate                    /tb/monitor_inst/u_video2bmp/vs_i_fall

add wave -noupdate -divider {End signal}

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {912366093 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
update
WaveRestoreZoom {891247063 ps} {925431255 ps}

#set run time
run  -all



