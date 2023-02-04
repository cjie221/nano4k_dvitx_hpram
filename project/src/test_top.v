
module test_top
(
	input             I_clk           , //27Mhz
	input             I_rst_n         , //KEY1
    output     [0:0]  O_hpram_ck      ,
    output     [0:0]  O_hpram_ck_n    ,
    inout      [0:0]  IO_hpram_rwds   ,
    inout      [7:0]  IO_hpram_dq     ,
    output     [0:0]  O_hpram_reset_n ,
    output     [0:0]  O_hpram_cs_n    ,
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n   ,
	output     [0:0]  O_led           
);

//==================================================
reg  [31:0] run_cnt;
wire        running;

//--------------------------
wire        tp0_vs_in  ;
wire        tp0_hs_in  ;
wire        tp0_de_in  ;
wire [ 7:0] tp0_data_r ;
wire [ 7:0] tp0_data_g ;
wire [ 7:0] tp0_data_b ;

reg         vs_r;
reg  [9:0]  cnt_vs;

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

//-------------------------------------------------
//memory interface
wire          cmd           ;
wire          cmd_en        ;
wire [21:0]   addr          ;//[ADDR_WIDTH-1:0]
wire [31:0]   wr_data       ;//[DATA_WIDTH-1:0]
wire [3:0]    data_mask     ;
wire          rd_data_valid ;
wire [31:0]   rd_data       ;//[DATA_WIDTH-1:0]
wire          init_calib     ;


//------------------------------------------
//rgb data
wire        rgb_vs     ;
wire        rgb_hs     ;
wire        rgb_de     ;
wire [23:0] rgb_data   ;  


//------------------------------------
//HDMI TX
wire serial_clk;
wire pll_lock;

wire tx_rst_n;

wire pix_clk;

//===================================================
//LED test
always @(posedge I_clk or negedge I_rst_n) //I_clk
begin
	if(!I_rst_n)
		run_cnt <= 32'd0;
	else if(run_cnt >= 32'd27_000_000)
		run_cnt <= 32'd0;
	else
		run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd13_500_000) ? 1'b1 : 1'b0;

assign  O_led[0] = running;

//===========================================================================
//testpattern
testpattern testpattern_inst
(
    .I_pxl_clk   (I_clk              ),//pixel clock
    .I_rst_n     (tx_rst_n           ),//low active 
    .I_mode      ({1'b0,cnt_vs[8:7]} ),//data select
    .I_sqr_width (16'd30             ),
    .I_single_r  (8'd0               ),
    .I_single_g  (8'd255             ),                  //40MHz      //65MHz      //74.25MHz
    .I_single_b  (8'd0               ),                  //800x600    //1024x768   //1280x720    
    .I_h_total   (16'd1650           ),//hor total time  // 16'd1056  // 16'd1344  // 16'd1650  
    .I_h_sync    (16'd40             ),//hor sync time   // 16'd128   // 16'd136   // 16'd40    
    .I_h_bporch  (16'd220            ),//hor back porch  // 16'd88    // 16'd160   // 16'd220   
    .I_h_res     (16'd1280           ),//hor resolution  // 16'd800   // 16'd1024  // 16'd1280  
    .I_v_total   (16'd750            ),//ver total time  // 16'd628   // 16'd806   // 16'd750    
    .I_v_sync    (16'd5              ),//ver sync time   // 16'd4     // 16'd6     // 16'd5     
    .I_v_bporch  (16'd20             ),//ver back porch  // 16'd23    // 16'd29    // 16'd20    
    .I_v_res     (16'd720            ),//ver resolution  // 16'd600   // 16'd768   // 16'd720    
    .I_hs_pol    (1'b1               ),//HS polarity , 0:negetive ploarity，1：positive polarity
    .I_vs_pol    (1'b1               ),//VS polarity , 0:negetive ploarity，1：positive polarity
    .O_de        (tp0_de_in          ),   
    .O_hs        (tp0_hs_in          ),
    .O_vs        (tp0_vs_in          ),
    .O_data_r    (tp0_data_r         ),   
    .O_data_g    (tp0_data_g         ),
    .O_data_b    (tp0_data_b         )
);

always@(posedge I_clk)
begin
    vs_r<=tp0_vs_in;
end

always@(posedge I_clk or negedge tx_rst_n)
begin
    if(!tx_rst_n)
        cnt_vs<=0;
    else if(vs_r && !tp0_vs_in) //vs24 falling edge
        cnt_vs<=cnt_vs+1'b1;
end 

//==============================================   
    assign ch0_vfb_clk_in  = I_clk;       
    assign ch0_vfb_vs_in   = ~tp0_vs_in;  //negative
    assign ch0_vfb_de_in   = tp0_de_in;  
    assign ch0_vfb_data_in = {tp0_data_r[7:3],tp0_data_g[7:2],tp0_data_b[7:3]}; // RGB565

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
    .I_vin0_vs_n        (ch0_vfb_vs_in    ),
    .I_vin0_de          (ch0_vfb_de_in    ),
    .I_vin0_data        (ch0_vfb_data_in  ),
    .O_vin0_fifo_full   (                 ),
    // video data output          
    .I_vout0_clk        (pix_clk          ),
    .I_vout0_vs_n       (~syn_off0_vs     ),
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
    .clkin (I_clk         )  //input clkin
);

HyperRAM_Memory_Interface_Top HyperRAM_Memory_Interface_Top_inst
(
    .clk            (I_clk          ),
    .memory_clk     (memory_clk     ),
    .pll_lock       (mem_pll_lock   ),
    .rst_n          (I_rst_n        ),  //rst_n
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

//================================================
wire out_de;
syn_gen syn_gen_inst
(                                   
    .I_pxl_clk   (pix_clk         ),//40MHz      //65MHz      //74.25MHz   
    .I_rst_n     (tx_rst_n        ),//800x600    //1024x768   //1280x720      
    .I_h_total   (16'd1650        ),// 16'd1056  // 16'd1344  // 16'd1650   
    .I_h_sync    (16'd40          ),// 16'd128   // 16'd136   // 16'd40    
    .I_h_bporch  (16'd220         ),// 16'd88    // 16'd160   // 16'd220    
    .I_h_res     (16'd1280        ),// 16'd800   // 16'd1024  // 16'd1280   
    .I_v_total   (16'd750         ),// 16'd628   // 16'd806   // 16'd750     
    .I_v_sync    (16'd5           ),// 16'd4     // 16'd6     // 16'd5       
    .I_v_bporch  (16'd20          ),// 16'd23    // 16'd29    // 16'd20       
    .I_v_res     (16'd720         ),// 16'd600   // 16'd768   // 16'd720     
    .I_rd_hres   (16'd1280        ),
    .I_rd_vres   (16'd720         ),
    .I_hs_pol    (1'b1            ),//HS polarity , 0:负极性，1：正极性
    .I_vs_pol    (1'b1            ),//VS polarity , 0:负极性，1：正极性
    .O_rden      (syn_off0_re     ),
    .O_de        (out_de          ),   
    .O_hs        (syn_off0_hs     ),
    .O_vs        (syn_off0_vs     )
);

localparam N = 5; //delay N clocks
                          
reg  [N-1:0]  Pout_hs_dn   ;
reg  [N-1:0]  Pout_vs_dn   ;
reg  [N-1:0]  Pout_de_dn   ;

always@(posedge pix_clk or negedge tx_rst_n)
begin
    if(!tx_rst_n)
        begin                          
            Pout_hs_dn  <= {N{1'b1}};
            Pout_vs_dn  <= {N{1'b1}}; 
            Pout_de_dn  <= {N{1'b0}}; 
        end
    else 
        begin                          
            Pout_hs_dn  <= {Pout_hs_dn[N-2:0],syn_off0_hs};
            Pout_vs_dn  <= {Pout_vs_dn[N-2:0],syn_off0_vs}; 
            Pout_de_dn  <= {Pout_de_dn[N-2:0],out_de}; 
        end
end


//==============================================================================
//TMDS TX
    assign rgb_data    = off0_syn_de ? {off0_syn_data[15:11],3'd0,off0_syn_data[10:5],2'd0,off0_syn_data[4:0],3'd0} : 24'h0000ff;//{r,g,b}
    assign rgb_vs      = Pout_vs_dn[4];//syn_off0_vs;
    assign rgb_hs      = Pout_hs_dn[4];//syn_off0_hs;
    assign rgb_de      = Pout_de_dn[4];//off0_syn_de;

Gowin_PLLVR u_Gowin_PLLVR
(.clkin     (I_clk     )     //input clk 
,.clkout    (serial_clk)     //output clk 
,.lock      (pll_lock  )     //output lock
);

assign tx_rst_n = I_rst_n & pll_lock;

CLKDIV u_clkdiv
(.RESETN(tx_rst_n)
,.HCLKIN(serial_clk) //clk  x5
,.CLKOUT(pix_clk)    //clk  x1
,.CALIB (1'b1)
);
defparam u_clkdiv.DIV_MODE="5";

DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (tx_rst_n   ),  //asynchronous reset, low active
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),  //pixel clock
    .I_rgb_vs      (rgb_vs        ),  
    .I_rgb_hs      (rgb_hs        ),        
    .I_rgb_de      (rgb_de        ),  
    .I_rgb_r       (rgb_data[23:16]    ),  
    .I_rgb_g       (rgb_data[15: 8]    ),  
    .I_rgb_b       (rgb_data[ 7: 0]    ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),  //{r,g,b}
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule