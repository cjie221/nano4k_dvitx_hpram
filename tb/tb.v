//---------------------------------------------------------------------
// File name  : tb.v
// Module name: tb
// Created by : 
// ---------------------------------------------------------------------
// Release history
// ----------------------------------------------------------------------------------
// Ver:    |  Author    | Mod. Date    | Changes Made:
// ----------------------------------------------------------------------------------
// V1.0    | Caojie     | 07/17/19     | Initial version 
// ----------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb();

//========================================================
//parameters
parameter BMP_VIDEO_FORMAT		   = "WxH_xHz"; //video format
parameter BMP_SERIAL_CLK_PERIOD	   = 2.694; //unit: ns   (371.25MHz)1000/371.25~=2.694ns
parameter BMP_PIXEL_CLK_PERIOD	   = BMP_SERIAL_CLK_PERIOD*5; //unit: ns
parameter BMP_PIXEL_CLK_FREQ	   = 1000.0/BMP_PIXEL_CLK_PERIOD;//pixel clock frequency, unit: MHz
parameter BMP_WIDTH				   = 160;
parameter BMP_HEIGHT			   = 120;
parameter BMP_OPENED_NAME		   = "../../tb/pic/img160.bmp";
parameter BMP_REPEAT			   = 1'b1;  //0:bmp increase  , 1:bmp repeat 
parameter BMP_LINK				   = 1'b0;  //0:单像素；1:双像素
								   
parameter BMP_OUTPUTED_WIDTH	   = BMP_WIDTH;
parameter BMP_OUTPUTED_HEIGHT	   = BMP_HEIGHT;
parameter BMP_OUTPUTED_NAME		   = "../../tb/pic/out0_001.bmp";
parameter BMP_OUTPUTED_NUMBER	   = 16'd3;

//-------------------------------------------------
parameter HPRAM_REF_CLK_PERIOD = 37.037; //unit: ns   (27MHz)1000/27~=37.037ns

//=======================================================
reg  serial_clk;  //x5
wire pixel_clock; //x1

reg  hpram_ref_clk;      //

reg  rst_n;

reg  rd_gen ;

//------------
//dirver
wire	   vsync; 
wire	   hsync; 
wire	   data_valid; 
wire [7:0] data0_r; 
wire [7:0] data0_g;
wire [7:0] data0_b;

//-------------------------
//frame buffer in
wire        ch0_vfb_clk_in ;
wire        ch0_vfb_vs_in  ;
wire        ch0_vfb_de_in  ;
wire [15:0] ch0_vfb_data_in;

//-------------------
//syn_code
wire        syn_off0_re;  // ofifo read enable signal
wire        syn_off0_vs;
wire        syn_off0_hs;
            
wire        off0_syn_de  ;
wire [15:0] off0_syn_data;

//-------------------------------------
//Hyperram
wire        dma_clk  ; 

wire        memory_clk;
wire        mem_pll_lock  ;

wire          cmd           ;
wire          cmd_en        ;
wire [21:0]   addr          ;//[ADDR_WIDTH-1:0]
wire [31:0]   wr_data       ;//[DATA_WIDTH-1:0]
wire [3:0]    data_mask     ;
wire          rd_data_valid ;
wire [31:0]   rd_data       ;//[DATA_WIDTH-1:0]
wire          init_calib     ;

//-------------------------------------------------
//memory interface
wire [0:0]  O_hpram_ck;
wire [0:0]  O_hpram_ck_n;
wire [0:0]  IO_hpram_rwds;
wire [7:0]  IO_hpram_dq;
wire [0:0]  O_hpram_reset_n;
wire [0:0]  O_hpram_cs_n;

//----------------  
//config
wire  [15:0] data_valid_xst_o;
wire  [15:0] data_valid_xed_o;
wire  [15:0] data_valid_yst_o;
wire  [15:0] data_valid_yed_o;
wire  [15:0] hor_sync_time_o ;
wire  [15:0] ver_sync_time_o ;
wire  [15:0] hor_total_time_o;
wire  [15:0] ver_total_time_o;

//------------------------------------------
//rgb data
wire        rgb_vs     ;
wire        rgb_hs     ;
wire        rgb_de     ;
wire [23:0] rgb_data   ; 

//--------------------------
wire 	   tmds_clk_p  ;
wire 	   tmds_clk_n  ;
wire [2:0] tmds_data_p ;//{r,g,b}
wire [2:0] tmds_data_n ;

//-------------------------
wire        rx0_pclk   ;
wire        rx0_vsync  ;
wire        rx0_hsync  ;
wire        rx0_de     ;
wire [7:0]  rx0_r      ; 
wire [7:0]  rx0_g      ; 
wire [7:0]  rx0_b      ; 

//-----------------
//monitor rgb input
wire		m_clk;
wire		m_vs_rgb;  
wire		m_hs_rgb;  
wire		m_de_rgb;  
wire [7:0]  m_data0_r;
wire [7:0]  m_data0_g;
wire [7:0]  m_data0_b;
wire [7:0]  m_data1_r;
wire [7:0]  m_data1_g;
wire [7:0]  m_data1_b;

//=====================================================
GSR GSR(.GSRI(1'b1));

//==============================================  
initial begin
  $fsdbDumpfile("tb.fsdb");
  $fsdbDumpvars;
end

//=====================================================
//clk
initial
  begin
	serial_clk	     = 1'b0;
    hpram_ref_clk    = 1'b0;
  end

always  #(BMP_SERIAL_CLK_PERIOD/2.0) serial_clk = ~serial_clk;
always  #(HPRAM_REF_CLK_PERIOD/2.0) hpram_ref_clk = ~hpram_ref_clk;


//=====================================================
//rst_n
initial
  begin
	rst_n=1'b0;
	
	#2000;
	rst_n=1'b1;
end

//==================================================
//video driver
driver #
(
	.BMP_VIDEO_FORMAT	(BMP_VIDEO_FORMAT   ),
	.BMP_PIXEL_CLK_FREQ (BMP_PIXEL_CLK_FREQ ),
	.BMP_WIDTH		    (BMP_WIDTH	        ),
	.BMP_HEIGHT		    (BMP_HEIGHT	        ),
	.BMP_OPENED_NAME	(BMP_OPENED_NAME    )
)
driver_inst
(
	.link_i	       (BMP_LINK   ), //0,单像素；1，双像素
	.repeat_en     (BMP_REPEAT ),
	.video_gen_en  (init_calib ),
	.pixel_clock   (pixel_clock),
	.vsync	       (vsync	   ),//negative 
	.hsync	       (hsync	   ),//negative 
	.data_valid    (data_valid ),
	.data0_r       (data0_r	   ), 
	.data0_g       (data0_g	   ),
	.data0_b       (data0_b	   ), 
	.data1_r       (     	   ), 
	.data1_g       (     	   ),
	.data1_b       (     	   )
);

//==============================================   
    assign ch0_vfb_clk_in  = pixel_clock;       
    assign ch0_vfb_vs_in   = vsync;  //negative
    assign ch0_vfb_de_in   = data_valid;  
    assign ch0_vfb_data_in = {data0_r[7:3],data0_g[7:2],data0_b[7:3]}; // RGB565

//=====================================================
//SRAM 控制模块 
Video_Frame_Buffer_Top Video_Frame_Buffer_Top_inst
( 
    .I_rst_n            (init_calib       ),//init_calib       ),//rst_n            ),
    .I_dma_clk          (dma_clk          ),   //sram_clk         ),
    .I_wr_halt          (1'd0             ), //1:halt,  0:no halt
    .I_rd_halt          (1'd0             ), //1:halt,  0:no halt
    // video data input         
    .I_vin0_clk         (ch0_vfb_clk_in   ),
    .I_vin0_vs_n        (ch0_vfb_vs_in    ),//negative 
    .I_vin0_de          (ch0_vfb_de_in    ),
    .I_vin0_data        (ch0_vfb_data_in  ),
    .O_vin0_fifo_full   (                 ),
    // video data output          
    .I_vout0_clk        (pixel_clock      ),
    .I_vout0_vs_n       (syn_off0_vs      ),//negative 
    .I_vout0_de         (syn_off0_re      ),
    .O_vout0_den        (off0_syn_de      ),
    .O_vout0_data       (off0_syn_data    ),
    .O_vout0_fifo_empty (                 ),
    // ddr write request
    .O_cmd              (cmd              ),
    .O_cmd_en           (cmd_en           ),
    .O_addr             (addr             ),//[ADDR_WIDTH-1:0]
    .O_wr_data          (wr_data          ),//[DATA_WIDTH-1:0]
    .O_data_mask        (data_mask        ),
    .I_rd_data_valid    (rd_data_valid    ),
    .I_rd_data          (rd_data          ),//[DATA_WIDTH-1:0]
    .I_init_calib       (init_calib       )
); 

//================================================
//HyperRAM ip
hpram_pllvr hpram_pllvr_inst
(
    .clkout(memory_clk    ), //output clkout
    .lock  (mem_pll_lock  ), //output lock
    .clkin (hpram_ref_clk )  //input clkin
);

HyperRAM_Memory_Interface_Top HyperRAM_Memory_Interface_Top_inst
(
    .clk            (hpram_ref_clk  ),
    .memory_clk     (memory_clk     ),
    .pll_lock       (mem_pll_lock   ),
    .rst_n          (rst_n          ),  //rst_n
    .O_hpram_ck     (O_hpram_ck     ),
    .O_hpram_ck_n   (O_hpram_ck_n   ),
    .IO_hpram_rwds  (IO_hpram_rwds  ),
    .IO_hpram_dq    (IO_hpram_dq    ),
    .O_hpram_reset_n(O_hpram_reset_n),
    .O_hpram_cs_n   (O_hpram_cs_n   ),
    .wr_data        (wr_data        ),
    .rd_data        (rd_data        ),
    .rd_data_valid  (rd_data_valid  ),
    .addr           (addr           ),
    .cmd            (cmd            ),
    .cmd_en         (cmd_en         ),
    .clk_out        (dma_clk        ),
    .data_mask      (data_mask      ),
    .init_calib     (init_calib     )
);

//-------------------------------------------------------------
//hyperram model
wire VCC;
initial
begin
force tb.O_hpram_cs_n = 1'b1;// force testbench.O_cs_n[1:0] = 2'b11;
#63575;
release tb.O_hpram_cs_n;
end

assign VCC = O_hpram_reset_n;

W956D8MKP_hyperbus hpram_mode0
(
	.resetb           (O_hpram_reset_n),
	.clk              (O_hpram_ck     ),
	.clk_n            (O_hpram_ck_n   ),
	.csb              (O_hpram_cs_n   ),
	.adq              (IO_hpram_dq    ),
	.rwds             (IO_hpram_rwds  ),
	.VCC              (VCC),
	.VSS              (1'b0),
	.psc              (),		 
	.psc_n            (), 
	.die_stack        () 	
);

//==============================================
//begin to read data after delay some time
localparam HTOTAL = BMP_LINK ? ((BMP_WIDTH+160)/2) : (BMP_WIDTH+160);
localparam VTOTAL = BMP_HEIGHT+50;  
initial 
begin
	rd_gen = 1'b0 ;
    @(posedge init_calib)
        #(BMP_PIXEL_CLK_PERIOD*HTOTAL*VTOTAL+10000);//ns
        rd_gen=1'b1;
end 

//================================================
//config
config_m#
(
	.OUTPUT_VIDEO_FORMAT   (BMP_VIDEO_FORMAT      ),
	.OUTPUT_PIXEL_CLK_FREQ (BMP_PIXEL_CLK_FREQ    ),
	.OUTPUT_HOR_RESOLUTION (BMP_OUTPUTED_WIDTH    ),
	.OUTPUT_VER_RESOLUTION (BMP_OUTPUTED_HEIGHT   )
)
config_m_inst
(
    .link_i           (BMP_LINK        ),
	.data_valid_xst_o (data_valid_xst_o), 
	.data_valid_xed_o (data_valid_xed_o), 
	.data_valid_yst_o (data_valid_yst_o), 
	.data_valid_yed_o (data_valid_yed_o),
	.hor_sync_time_o  (hor_sync_time_o ),
	.ver_sync_time_o  (ver_sync_time_o ),
	.hor_total_time_o (hor_total_time_o), 
	.ver_total_time_o (ver_total_time_o)  
);

//---------------------------------------------------
//generate synchronous timing
sync_gen1x sync_gen1x_inst
(
    //-------
    .cpu2out_xst_reg   (data_valid_xst_o),
    .cpu2out_xed_reg   (data_valid_xed_o), 
    .cpu2out_yst_reg   (data_valid_yst_o), 
    .cpu2out_yed_reg   (data_valid_yed_o),
    .cpu2out_fxed_reg  (16'd0),  
    .cpu2out_fyed_reg  (16'd0), 
    .cpu2out_hsync_reg (hor_sync_time_o ) ,
    .cpu2out_vsync_reg (ver_sync_time_o ) , 
    .cpu2out_hed_reg   (hor_total_time_o) ,
    .cpu2out_ved_reg   (ver_total_time_o) ,
    .hor_res0          (data_valid_xed_o-data_valid_xst_o+1'b1),
    .ver_res0          (data_valid_yed_o-data_valid_yst_o+1'b1),
    //-------  video   
    .off0_re           (syn_off0_re     ),
    .pout_de           (                ),//unused 
    .pout_hs           (syn_off0_hs     ),//negative 
    .pout_vs           (syn_off0_vs     ),//negative  
    .vs_sel            (1'b0            ),                            
    .e_vs              (1'b0            ),         
    .pxl_clk           (pixel_clock         ),
    .rst_b             (rd_gen          )
);

assign rgb_data    = {off0_syn_data[15:11],3'd0,off0_syn_data[10:5],2'd0,off0_syn_data[4:0],3'd0};//{r,g,b}
assign rgb_vs      = syn_off0_vs;
assign rgb_hs      = syn_off0_hs;
assign rgb_de      = off0_syn_de;


//======================================================
//RGB to DVI
CLKDIV u_clkdiv
(.RESETN(rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pixel_clock)//clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";
defparam u_clkdiv.GSREN="false";

DVI_TX_Top DVI_TX_Top_inst
(
	.I_rst_n       (rst_n         ),   //asynchronous reset, low active
	.I_serial_clk  (serial_clk    ),
	.I_rgb_clk     (pixel_clock   ),   //pixel clock
	.I_rgb_vs      (rgb_vs        ),   
	.I_rgb_hs      (rgb_hs        ),            
	.I_rgb_de      (rgb_de        ),  
	.I_rgb_r       (rgb_data[23:16]    ), 
	.I_rgb_g       (rgb_data[15: 8]    ), 
	.I_rgb_b       (rgb_data[ 7: 0]    ),
	.O_tmds_clk_p  (tmds_clk_p    ),
	.O_tmds_clk_n  (tmds_clk_n    ),
	.O_tmds_data_p (tmds_data_p   ),  //{r,g,b}
	.O_tmds_data_n (tmds_data_n   )
);

//======================================================
//DVI to RGB  
DVI_RX_Top DVI_RX_Top_inst
(
	.I_rst_n         (rst_n         ),// active low 
	.I_tmds_clk_p    (tmds_clk_p    ),  
	.I_tmds_clk_n    (tmds_clk_n    ),  
	.I_tmds_data_p   (tmds_data_p   ),  //{r,g,b}
	.I_tmds_data_n   (tmds_data_n   ),
    .O_pll_phase     (              ), 
	.O_pll_phase_lock(              ),    
	.O_rgb_clk       (rx0_pclk      ),
	.O_rgb_vs        (rx0_vsync     ),
	.O_rgb_hs        (rx0_hsync     ),
	.O_rgb_de        (rx0_de        ),
	.O_rgb_r         (rx0_r         ),
	.O_rgb_g         (rx0_g         ),
	.O_rgb_b         (rx0_b         )
);

//======================================================
//monitor
assign m_clk     = rx0_pclk       ;
assign m_vs_rgb  = rx0_vsync      ;
assign m_hs_rgb  = rx0_hsync      ;
assign m_de_rgb  = rx0_de         ;
assign m_data0_r = rx0_r          ;
assign m_data0_g = rx0_g          ;
assign m_data0_b = rx0_b          ;
assign m_data1_r = 8'd0           ;
assign m_data1_g = 8'd0           ;
assign m_data1_b = 8'd0           ;

monitor#
(
  .BMP_OUTPUTED_WIDTH  (BMP_OUTPUTED_WIDTH ),
  .BMP_OUTPUTED_HEIGHT (BMP_OUTPUTED_HEIGHT),
  .BMP_OUTPUTED_NAME   (BMP_OUTPUTED_NAME  ),
  .BMP_OUTPUTED_NUMBER (BMP_OUTPUTED_NUMBER)
)
monitor_inst
(
  .link_i	    (BMP_LINK	), //0,单像素；1，双像素
  .video2bmp_en (rst_n		),
  .pixel_clock  (m_clk		), 
  .vsync		(m_vs_rgb	), //负极性	   
  .hsync		(m_hs_rgb	), //负极性	   
  .data_valid   (m_de_rgb	), 
  .data0_r	    (m_data0_r	),	
  .data0_g	    (m_data0_g	),
  .data0_b	    (m_data0_b	),
  .data1_r	    (m_data1_r	),	
  .data1_g	    (m_data1_g	),
  .data1_b	    (m_data1_b	)
);
		  
endmodule
