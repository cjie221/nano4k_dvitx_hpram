// ---------------------------------------------------------------------
// File name         : sync_gen1x.v
// Module name       : sync_gen1x
// Module Description: 
// Created by: Caojie
// ---------------------------------------------------------------------
// Release history
// VERSION |   Date      | AUTHOR  |    DESCRIPTION
//   1.0   | 04-Jul-2015 | caojie  |  initial
// --------------------------------------------------------------------

module sync_gen1x(
    //-------
    input      [15:0]  cpu2out_xst_reg      ,
    input      [15:0]  cpu2out_xed_reg      ,
    input      [15:0]  cpu2out_yst_reg      , 
    input      [15:0]  cpu2out_yed_reg      ,
    input      [15:0]  cpu2out_fxed_reg     ,
    input      [15:0]  cpu2out_fyed_reg     ,
    input      [15:0]  cpu2out_hsync_reg    ,
    input      [15:0]  cpu2out_vsync_reg    , 
    input      [15:0]  cpu2out_hed_reg      ,
    input      [15:0]  cpu2out_ved_reg      ,           
    //--------
    input      [15:0]  hor_res0             ,
    input      [15:0]  ver_res0             ,
                    
    output reg         off0_re              ,
                       
    output reg         pout_de              ,   
    output reg         pout_hs              ,
    output reg         pout_vs              , 
                       
    input              vs_sel               ,  // 1: select external VS;   0:  select inside VS         
    input              e_vs                 ,         
    input              pxl_clk              ,
    input              rst_b 
    );
  
//====================================================
reg     [15:0] pd_v_cnt     ;
reg     [15:0] pd_h_cnt     ;

reg            pd_frame_clr ;
reg            e_vs0        ;
reg            e_vs1        ;
reg            e_vs2        ; 

//-----------------------------------------
wire           off0_re_w    ;

wire           pout_de_w    ;                          
wire           pout_hs_w    ;
wire           pout_vs_w    ;
   
//----------------------------------------------------------
always @(posedge pxl_clk or negedge rst_b)
begin 
  if(!rst_b)
    begin
      e_vs0 <= 1'b0; 
      e_vs1 <= 1'b0; 
      e_vs2 <= 1'b0; 
    end
  else
    begin
      e_vs0 <= e_vs;
      e_vs1 <= e_vs0;
      e_vs2 <= e_vs1;
    end
end

//---------------------------------------------------------------
//when external VS triggered, clear flag must wait until HS counter end
always@(posedge pxl_clk or negedge rst_b)
begin
  if(!rst_b)
    pd_frame_clr <= 1'b0;
  else if(~e_vs2 & e_vs1) //external VS rising edge
    pd_frame_clr <= 1'b1;
  else if(pd_frame_clr && (pd_h_cnt >= (cpu2out_hed_reg-1'b1)))
    pd_frame_clr <= 1'b0;
  else
    pd_frame_clr <= pd_frame_clr;
end

//-------------------------------------------------------
//VS select
always@(posedge pxl_clk or negedge rst_b)
begin
  if(!rst_b)
    pd_v_cnt <= 16'd0;
  else if(vs_sel)    //select external VS
    begin
      if(pd_frame_clr && (pd_h_cnt >= (cpu2out_hed_reg-1'b1)))
        pd_v_cnt <= 16'd0;
      else if(pd_h_cnt >= (cpu2out_hed_reg-1'b1))
        pd_v_cnt <=  pd_v_cnt + 1'b1;
      else
        pd_v_cnt <= pd_v_cnt;
    end
  else     //select inside VS
    begin
      if((pd_v_cnt >= (cpu2out_ved_reg-1'b1)) && (pd_h_cnt >= (cpu2out_hed_reg-1'b1)))
        pd_v_cnt <= 16'd0;
      else if(pd_h_cnt >= (cpu2out_hed_reg-1'b1))
        pd_v_cnt <=  pd_v_cnt + 1'b1;
      else
        pd_v_cnt <= pd_v_cnt;
    end
end

//-------------------------------------------------------------    
always @(posedge pxl_clk or negedge rst_b)
begin
    if(!rst_b)
      pd_h_cnt <=  16'd0; 
    else if(pd_h_cnt >= (cpu2out_hed_reg-1'b1))
      pd_h_cnt <=  16'd0 ; 
    else 
      pd_h_cnt <=  pd_h_cnt + 1'b1 ;           
end

//-------------------------------------------------------------
assign  pout_de_w = ((pd_h_cnt>=(cpu2out_xst_reg))&(pd_h_cnt<=cpu2out_xed_reg))&
                    ((pd_v_cnt>=(cpu2out_yst_reg))&(pd_v_cnt<=cpu2out_yed_reg)) ;
assign  pout_hs_w =  ~((pd_h_cnt>= cpu2out_fxed_reg ) & (pd_h_cnt<=(cpu2out_fxed_reg + cpu2out_hsync_reg-1'b1))) ;
assign  pout_vs_w =  ~((pd_v_cnt>= cpu2out_fyed_reg ) & (pd_v_cnt<=(cpu2out_fyed_reg + cpu2out_vsync_reg-1'b1))) ;  


//==============================================================================
assign  off0_re_w = ((pd_h_cnt>=cpu2out_xst_reg)&(pd_h_cnt<=(cpu2out_xst_reg+hor_res0-1'b1)))&
                    ((pd_v_cnt>=cpu2out_yst_reg)&(pd_v_cnt<=(cpu2out_yst_reg+ver_res0-1'b1)));            

//==============================================================================
//ÑÓÊ±1ÅÄÊä³ö
always@(posedge pxl_clk or negedge rst_b)
begin
  if(!rst_b)
    begin
      pout_de  <= 1'b0;                          
      pout_hs  <= 1'b1;
      pout_vs  <= 1'b1; 
      off0_re  <= 1'b0;
    end
  else 
    begin
      pout_de  <= pout_de_w;                          
      pout_hs  <= pout_hs_w;
      pout_vs  <= pout_vs_w; 
      off0_re  <= off0_re_w;
    end
end

endmodule       
              