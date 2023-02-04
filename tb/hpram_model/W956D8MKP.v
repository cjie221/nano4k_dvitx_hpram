/***********************************************************************************************
|*Company             : Winbond Electronics Corp. ("WINBOND")
|*Model Type          : Verilog Model
|*Product             : hyperbus PSRAM
|*Part Number         : W956D8MKP_hyperbus
|*Speed option        : up to 200MHz
|$Revision            : 1.6
|$Date                : 1   : 2018/4/30
|                     : 1.1 : 2018/05/22
|                     : 1.2 : 2018/05/29
|                     : 1.3 : 2018/05/31
|                     : 1.4 : 2018/06/06 
|                     : 1.5 : 2018/06/12 
|                     : 1.6 : 2018/07/17 
|*Revision History    : 1   : initial create 
|                     : 1.1 : a. To modify the HSM/PASR register bit  
|                           : b. To modify the register read out 
|                     : 1.2 : To modify the code base on JD's feedback   
|                     : 1.3:  To modify hybrid 128 address 
|                     : 1.4 : To modify the code base on the feedback form JD 20180606
|                     : 1.5 : To modify DPD   
|                     : 1.6: to add reset registers to default value for DPD and reset　    
***********************************************************************************************
|*Disclaimer :
|This model software code and all related notes or documentation (collectively "Software") is 
|provided "AS IS" without warranty of any kind. You bear the risk of using it. 
|Winbond Electronics Corp.("WINBOND") hereunder DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, 
|INCLUDING BUT NOT LIMITED TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
|OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. WINBOND DOES NOT WARRANT THAT THE 
|OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. FURTHERMORE, WINBOND DOES NOT MAKE 
|ANY WARRANTIES REGARDING THE USE OR THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS 
|CORRECTNESS, ACCURACY, RELIABILITY, OR OTHERWISE. IN NO EVENT SHALL WINBOND, ITS SUBSIDIARY 
|COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, INDIRECT, CONSEQUENTIAL, INCIDENTAL, 
|OR SPECIAL DAMAGES (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, 
|BUSINESS INTERRUPTION, OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE THE
|SOFTWARE, EVEN IF WINBOND HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
| 
|*Copyright :
|Copyright C 2018 Winbond Electronics Corp. All rights reserved.
***********************************************************************************************/
/**********************************************************************************************
| file structure:
| 		include: Config-AC.v (file that contains all AC/DC parameters used by the model)
|		  Codes  : DRAM functions and IO timing checking
**********************************************************************************************/

/**********************************************************************************************
================================================================================
======================   Read Me   =============================================
================================================================================
1. File Descriptions:
================================================================================
W956D8MKP_hyperbus.v                       - Verilog model file
W956D8MKP_hyperbus_sim.v                   - test bench
Config-AC.v                      - AC parameters file


note:
1. To compile the mdoel, if you want to use the OP voltage 3V, please add the define
   +define+DC3V, else the model will be operated with the 1.8V AC parameters	  

2. If you want to use DCARS feature, you have to add +define+DCARS

	  
================================================================================  
**********************************************************************************************/

 
// TIME_UNIT/PRECISION at the simulation
`timescale 1ns/1ps
module W956D8MKP_hyperbus(
	adq, 		//Data, address multiplex bus ----------------------[inout]
	clk,		//Clock---------------------[input] 
	clk_n,      //Clock_n-------------------[input] 
	psc,		 
	psc_n,      
	csb,		
	rwds,        
	VCC,
	VSS,
	resetb,
	die_stack
); 

//Including AC parameters & Size parameters
`include "Config-AC.v"

	inout	[ADQ_BITS-1 : 0] adq;
	input	clk;
	input	clk_n;
	input	psc;
	input	psc_n;
	input	csb;
	inout   rwds; 
	
	input  resetb;
	input  [1:0] die_stack;
	
	//power/gnd input
	input	VCC;
	input	VSS;
	//input	VCCQ;
	//input	VSSQ;
	
	wire	clk_in   = clk;
	wire	clk_n_in = clk_n;
    reg     clk_diff;
	
	wire	psc_in   = psc;
	wire	psc_n_in = psc_n;

	
	wire	csb_in = csb;
  
    wire	csb_n_in;
    assign  csb_n_in =~csb;
	
	wire    rwds_in = rwds;
  
    wire    resetb_in = resetb;

	
    //rwds buffer
    reg       rwds_out;
    reg       rwds_out_en;
	reg       rwds_out_toggle;
	assign    rwds  = (rwds_out_en) ? rwds_out:1'bz;  //rwds out    
  
  
    reg     additionanl_latency;
   
//------------------------------------------------------------------------------------
	// DQ control
	//data out
	reg		dout_enable;
	reg		[ADQ_BITS-1:0]    data_out;
	wire	[ADQ_BITS-1:0]    adq_in = adq;
	
    assign  adq =(dout_enable) ? data_out : {ADQ_BITS{1'bz}} ;
	
	
	reg	[21:0] addr_in;  
    reg	[21:0] addr_in_start;   
	reg	[21:0] addr_in_hybrid;   
	reg        addr_wrap_complete; 
    reg        addr_latch_1st;
  	
	// Data Out
	reg		[15:0] data_out_buff;	            // for the task "mem_read"
	
	reg     refresh;
	reg     [5:0] refresh_cntr; //v1p3
	
    reg   [7:0] burst_length;
	
	// Memory Array
	reg     [15:0] memory [0:(1<<22)-1]; //8Mx8
    reg     [15:0]  write_mem_word;
	
	integer i;
   
	reg			VCC_up_flag;
	reg			VCCQ_up_flag;
	reg			powerup_on;

	reg         [15:0] ID_REG0;
	reg         [15:0] ID_REG1;
	reg         [15:0] CONFIG_REG0;
	reg         [15:0] CONFIG_REG1;
	
	//sr0 bit parameters
	reg         latency_type;
	reg[3:0]    latency_code;  
	
	
	//chip enable/disable and initial register setting flag  
    reg     device_work;
	reg     chip_en;
	reg     non_negclk;
	
	//command/address phase and data phase strating/stop flag
	//cmd que
	reg [10:0]  addr_cmd_count;
	
	//ca bits
	reg [47:0]   ca_cmd_in;
	reg [15:0]   ca0;
	reg [15:0]   ca1;
	reg [15:0]   ca2;
	
	reg  [9:0]  latency_cycle_count;
	reg  latency_cycle_count_start;
	reg  latency_count_end=0;
	reg  write_latency_count_end=0;
	reg  read_latency_count_end=0;
	reg  target_space=1'bz;
	
	//DPD mode
	reg   dpd_en;
	reg   dpd_out; 
	reg   dpd_csb_neg;
	reg   dpd_csb_pos1;
	reg   dpd_csb_pos2;
	realtime  t_dpd_csb_neg;
	realtime  t_dpd_csb_pos1;
	realtime  t_dpd_csb_pos2;
	realtime  dly;
	
	//hybrid sleep mode
	reg   hybrid_sleep_en;
	reg   hybrid_sleep_enter;
	reg   hybrid_sleep_cs_Low_again;							 
	reg   exit_sleep_flag1;
	reg   exit_sleep_flag2;
	realtime  t_exit_sleep_csb_low_start;
	realtime  t_exit_sleep_to_work_start;
	realtime  t_start_sleep_csb_high_start;
	reg  int_clk;
	
	//read/write start/stop 
	reg [20:0] write_data_count;
	reg [20:0] read_data_count;
	
	reg  write_start;
	reg  read_start;
	reg  write_cmd;
	reg  read_cmd;
	wire  ins_addr_phase = (addr_cmd_count<7) & chip_en;
	wire  in_data_phase  = write_latency_count_end && chip_en;
	
	
	reg [10:0] ce_clock;
	
	reg [5:0] latency_count;
	
	//display frequency
	reg df;
	
	reg resetb_en;
	reg resetb_en_out;
	
	//power supply
	realtime	t_VCC_on;
	realtime	t_VCCQ_on;
	
	
	//reset time
	realtime    t_resetb_pos;
	realtime    t_resetb_neg;
	
	//timing parametrs check
	realtime  tCE_fall;
    realtime  tCE_high; 
	realtime  tACC_start;
	
	realtime  tck_i;
	realtime  ck_pos;
	realtime  ck_neg;
	realtime  the_first_pos_clk; 
	
	
	
	realtime  tck_pos;
	realtime  tck_neg;
	
	
	real      op_frequency;
	
	//command flag
	reg flag_read_reg;
	reg flag_write_reg;
	reg flag_read_mem;
	reg flag_write_mem;
	
	

  	//differential clk
	reg            		     	diff_ck;
    
	
    reg        clk_in_dly;
    reg        clk_n_in_dly;
	
	reg        rwds_out_data_pos;
	reg        rwds_out_data_neg;
	reg        rwds_start_1st;
	
	
	
	wire     f_hybrid_wrap_address =  ~CONFIG_REG0[2] && ~ca_cmd_in[45] && chip_en ;
	wire     f_legacy_wrap_address =  CONFIG_REG0[2]  && ~ca_cmd_in[45] && chip_en ;
	wire     f_linear_address      =  ca_cmd_in[45] && chip_en ;
	reg      hybrid_wrap_complete; 
	
	
   initial
    begin : file_io_open
        reg [ADDR_BITS - 1 : 0] addr_init;
        reg [ADQ_BITS*2 - 1 : 0] data;
        //string _char;
        integer in, fio_status;

       
         // Preload section
        `ifdef mem_init
        in = $fopen("mem_init.txt","r");
        while (! $feof(in)) begin
            fio_status = $fscanf(in, "%h  %h", addr_init, data);
            if (fio_status != -1) begin // Check for blank line or EOF
                mem_write (addr_init, data);
                // Next 4 lines are for debug only
                //$display ("MEMORY_WRITE: addr_init = 0x%h, Data = %h", addr_init, data);
                data = 'hx; // This is to reset data to verify memory_read
                mem_read(addr_init, data);
                // $display ("MEMORY_READ: addr_init = 0x%h, Data = %h", addr_init, data);
              
            end
        end
        $fclose(in);
       
    `endif
    end
   
   
   
	initial begin
		$timeformat (-9, 3, " ns", 1);
		VCC_up_flag = HIZ;
		VCCQ_up_flag = HIZ;
		powerup_on = LOW;
		
        rwds_out=1'bz;
		rwds_out_en=0;
		rwds_out_toggle=0;
		
		chip_en=0;
		resetb_en=0;
		resetb_en_out=0;
		
		addr_cmd_count=0;
		additionanl_latency=0;
		
		ca_cmd_in = 48'hxxxxxx | 48'h200000000000;
		
		write_data_count = 0;
		read_data_count = 0;
		read_start = 0;
		write_start =  0;
		
		read_cmd = 0;
		write_cmd =  0;
		
		latency_cycle_count=0;
		latency_count=0;
		
		dout_enable = 1'b0;
		addr_in = 'hxxxxxx;
		
		non_negclk = 0;
		
		//v1p3
	
		refresh=0;
		refresh_cntr=0;
		
		latency_type = 0; //defaul , variable
		
		ce_clock=0;
		
        dpd_csb_neg=0;
	    dpd_csb_pos1=0;
	    dpd_csb_pos2=0;
		
		df=0;
		latency_cycle_count_start=0;
		
		hybrid_wrap_complete=0;
		
		hybrid_sleep_en=0;
		hybrid_sleep_enter=0;
		hybrid_sleep_cs_Low_again=0;					  
		exit_sleep_flag1=0;
		exit_sleep_flag2=0;
		int_clk=0;
		
		dpd_en=0;
		dpd_out=0;
		
		device_work=1;
		
		flag_read_reg=0;
	    flag_write_reg=0;
	    flag_read_mem=0;
	    flag_write_mem=0;
	
	    t_resetb_pos=0;
		t_resetb_neg=0;
		
	    clk_in_dly=0;
	    clk_n_in_dly=0;
		rwds_start_1st=0;
		
		rwds_out_data_pos=0;
	    rwds_out_data_neg=0;
		
        addr_wrap_complete=0;
	    addr_latch_1st=1;
		
	end

	
	// create different types of messages
 /*  task $display;
    input [8*256:1] msg;
  begin
  `ifndef display_no_debug
    $display("%t DEBUG! : %0s", $realtime, msg);
  `endif
  end
  endtask

  task $display;
    input [8*256:1] msg;
  begin
  `ifndef display_no_info
    $display("%t INFO! : %0s", $realtime, msg);
  `endif
  end
  endtask

  task $display;
    input [8*256:1] msg;
  begin
  `ifndef display_no_warn
    $display("%t WARNING! : %0s", $realtime, msg);
  `endif
  end
  endtask

  task $display;
          input [8*256:1] msg;
  begin
  `ifndef display_no_error
    $display("%t ERROR! : %0s", $realtime, msg);
  `endif
  end
  endtask */
	
		
	always @(posedge clk_in)  
	begin
      diff_ck    <= clk_in;
      clk_in_dly        <= #(tCKDS_min)      1;
	  clk_n_in_dly      <= #(tCKDS_min)      0;
	  rwds_out_data_pos <= #(tCKDS_min-0.1)  1;
	  rwds_out_data_neg <= #(tCKDS_min-0.1)  0;
   end
 
    always @(negedge clk_in) 
	  begin
         //diff_ck           <= ~clk_n_in;
	     clk_in_dly        <= #(tCKDS_min)      0;
	     clk_n_in_dly      <= #(tCKDS_min)      1;
	     rwds_out_data_pos <= #(tCKDS_min-0.1)  0;
	     rwds_out_data_neg <= #(tCKDS_min-0.1)  1;
      end
  
	
	/*-------------------
		Power-up check
	--------------------*/
	always @(VCC ) begin
		if(VCC) begin
			t_VCC_on = $realtime;
			VCC_up_flag = HIGH;
			#0.1;
			
			$display(" ============> VCC ON ");
		end
		else begin
			VCC_up_flag = LOW;
			powerup_on = LOW;
		end
	
	end
	
	
	always @(csb_in or clk_in ) 
	begin		   
			   if( ($realtime - t_VCC_on >= tVCS)  && VCC_up_flag==HIGH && powerup_on==LOW)
			   begin
			     $display("");
			     $display("------------------------------------------------------");
			     $display("Device is ready for normal operation!");
				 `ifdef DC3V
                 $display("The Device is operated on 3V!");
			     `else
				 $display("The Device is operated on 1.8V!");
				 `endif

				 `ifdef DCARS
   				 $display("The Device is operated on DCARS!");
  				 `endif

				 $display("------------------------------------------------------");
				 powerup_on=HIGH;
			   end	 
	end

	
    //monitor reset
	always @(resetb_in) begin
		if(resetb_in)
		begin
		   if($realtime!=0)
		    begin
		     t_resetb_pos = $realtime;
			
			 
			
			 if( $realtime - t_resetb_neg < tRP)
			 $display("RESET# tRP violation");
			  #0.1;
			  
			  
			 if(!powerup_on)
			 resetb_en_out <= #tVCS 1'b1;
		    end	 
		end 
		
		else if(!resetb_in)
		begin
			 t_resetb_neg = $realtime;
			 resetb_en_out=0;
			 
			 #0.1;
			 $display($psprintf("rsetb neg time %t, RESET all the config register to default",t_resetb_neg));
			 
			 if(dpd_en)
			 $display($psprintf("rsetb neg time %t, RESET DPD mode",t_resetb_neg));
			 
			 
			 resetb_en=1'b1;
		     
			 //reset registers to default setting
		     //CONFIG_REG0 = DEFAULT_CONFIG_REG0;
			 //CONFIG_REG1 = DEFAULT_CONFIG_REG1;
			 
			 reg_conf(DEFAULT_CONFIG_REG0,0);
			 reg_conf(DEFAULT_CONFIG_REG1,1);
			
			 
			 
			 device_work=0; 
			 
			 //dpd mode clear
		     dpd_en=1'b0;  //disable DPD 
			 dpd_csb_neg=1'b0;
		     dpd_csb_pos1=1'b0;
	         dpd_csb_pos2=1'b0; 
		     dpd_out     =1'b0;
			  
			 dly = tRPH;
			 
			 if(powerup_on)
			 resetb_en_out <= #tRPH 1'b1;
			
    		 refresh=0; //v1p3
			 
			 rwds_start_1st=0;
			 rwds_out_data_pos=0;
	         rwds_out_data_neg=0;
				 hybrid_sleep_cs_Low_again=0;				
		end 
	end
	
	
	always @(resetb_en_out)
	begin
	      if(resetb_en_out && resetb_en)
		  begin
		   $display("Exit Reset Mode to Standby!");
		   device_work=1'b1;
		   resetb_en=1'b0;
		   resetb_en_out <= #1 1'b0;
	      end 
	end 
	
	/*--------------------------
		registers default value setting
	---------------------------*/
	always @(posedge powerup_on) 
	begin
			reg_conf(DEFAULT_CONFIG_REG0,0);
			reg_conf(DEFAULT_CONFIG_REG1,1);
			
			ID_REG0	    = DEFAULT_ID_REG0;	
			ID_REG1   	= DEFAULT_ID_REG1;	
			
			
			$display("==>The default values for ID_REG0, ID_REG1, CONFIG_REG0, CONFIG_REG1");
			$display($psprintf("==>ID_REG0     : (0x%h) (16'b%b)",ID_REG0,ID_REG0));
			$display($psprintf("==>ID_REG1     : (0x%h) (16'b%b)",ID_REG1,ID_REG1));
			$display($psprintf("==>CONFIG_REG0 : (0x%h) (16'b%b)",CONFIG_REG0,CONFIG_REG0));
			$display($psprintf("==>CONFIG_REG1 : (0x%h) (16'b%b)",CONFIG_REG1,CONFIG_REG1));
			
		    $display("==>Display Default Registers Setting !");
			
			`ifndef display_no_info
			display_regConf(ID0_READ);
			display_regConf(ID1_READ);
			display_regConf(CR0_READ);
			display_regConf(CR1_READ);
		    `endif	
     
	end

	//always #(6/2.0)   int_clk=(hybrid_sleep_enter)?(~int_clk): int_clk;  
	always #(5/2.0)   int_clk=~int_clk; 
	
	
	
	//exit sleep mode 
	always @(int_clk)
	begin
	     if(csb_in==1'b1)
		 begin
		    if(hybrid_sleep_enter && hybrid_sleep_cs_Low_again)
			begin
			   if($realtime - t_exit_sleep_csb_low_start < tCSHS_min && !exit_sleep_flag1)
			      $display("\nIn Hybrid sleep Mode csb low period is violated the spec!");
			   
			   if($realtime - t_exit_sleep_csb_low_start > tCSHS_min && !exit_sleep_flag1)
			   begin
			      $display($psprintf("Hybrid Sleep Mode exit!,t_exit_sleep_csb_low_start: %t, $realtime - t_exit_sleep_csb_low_start : %t ",t_exit_sleep_csb_low_start, $realtime - t_exit_sleep_csb_low_start  ));
			      exit_sleep_flag1=1; 
				  t_exit_sleep_to_work_start = $realtime;
				  hybrid_sleep_enter=0;
				  CONFIG_REG1[5]=1'b0; //clear the register
			   end
			end
	     end
		 
		 if(exit_sleep_flag1)
		 begin
		      if($realtime - t_exit_sleep_csb_low_start > tEXTHS_max && !exit_sleep_flag2)
		      begin
		           exit_sleep_flag2=1;
                   exit_sleep_flag1=0;  
                   $display($psprintf("Sleep Mode exit and The device has been waited for tEXTHS_max (%t), the device can accept command input now!",tEXTHS_max));
			       device_work=1;
					hybrid_sleep_cs_Low_again=0;			   
  			  end
		 end
		 
		 
	end
	
	always @(negedge csb_in)
	begin
	      if(hybrid_sleep_enter)
			begin
			 if($realtime - t_start_sleep_csb_high_start < tHSIN)
			   $display($psprintf("csb goes Low in Hybrid sleep mode, but the csb high period is smaller than tHSIN, duration is %fns, spec is %fns",$realtime - t_start_sleep_csb_high_start, tHSIN ));
			   
			 t_exit_sleep_csb_low_start = $realtime;
			 $display($psprintf("exit_sleep_csb_low_start: %t!", t_exit_sleep_csb_low_start));
		     
	         hybrid_sleep_cs_Low_again=1;    	     
		   end
	  		  
		   
	      if(device_work!=1 && powerup_on)
	      $display("The device is in hybrid sleep mode or DPD mode or reset mode, it can not accept any command.");
		  
		  if(device_work!=1 && powerup_on!=1 )
	      $display("The device is not Power Up yet.");
		  
		  if(dpd_en && dpd_csb_pos1)
	      begin
		     dpd_csb_neg=1'b1; 
	         t_dpd_csb_neg = $realtime;
			 $display("DPD mode, CE# low start for exit DPD!");
		     
			 if($realtime - t_dpd_csb_pos1 < tDPDIN)
		     $display($psprintf("IN DPD , tDPDIN smaller spec, real tDPDIN: %t,spec %t !",$realtime - t_dpd_csb_pos1, tDPDIN));
			 
			 CONFIG_REG0[15]=1'b1; //clear DPD register 
			 
			 
			reg_conf(DEFAULT_CONFIG_REG0,0);
			reg_conf(DEFAULT_CONFIG_REG1,1);
			
			 
	      end
	end
	
	
	
	//enter hybrid sleep mode after received enter sleep command
	always@(posedge csb_in)
	begin
	   
	    tCE_high = $realtime;
	   
	   if(hybrid_sleep_en)
	   begin
	      hybrid_sleep_enter=1; //real enter
		  hybrid_sleep_en=0;
		  t_start_sleep_csb_high_start = $realtime;
		  $display("csb high, Enter hybrid Sleep Mode!");
          device_work=0; 
	   end
	   
	   //enter DPD mode
	   if(dpd_en && (dpd_csb_neg==0) )
	   begin
	       dpd_csb_pos1=1'b1;
		   t_dpd_csb_pos1= $realtime;
		   $display("ENTER DPD!");
		   #1;
           device_work=0; //stop latch command and clear all th ecommand transaction setting   		   
	   end
	   
	   //exit DPD
	   else if(dpd_en && dpd_csb_pos1)
	   begin
	       dpd_csb_pos2=1'b1;
		   t_dpd_csb_pos2= $realtime;
		   
		  						
		   $display("Exit DPD start, it still needs tEXTDPD to standby mode !");
		   
		   
		   if($realtime - t_dpd_csb_neg < tCSDPD_min)
		   $display($psprintf("IN DPD , tCSDPD_min violation, real tCSDPD_min: %t,spec %t !", $realtime - t_dpd_csb_neg, tCSDPD_min));
		   
		   dly= tEXTDPD;

           dpd_out <= #(dly) 1'b1 ; 		   
          
	   end
	   
	end
	
	
	always @(dpd_out)
	begin
	      if(dpd_out && dpd_en)
		  begin
		   $display("Exit DPD Mode to Satndby!");
		   device_work=1'b1;
		   dpd_csb_neg=1'b0;
		   dpd_csb_pos1=1'b0;
	       dpd_csb_pos2=1'b0; 
		   dpd_en=1'b0;
		   dpd_out <= #1 1'b0;
			 hybrid_sleep_cs_Low_again=0;					 
	      end 
	end 
	
	//chip enable
	always @(clk_in or csb_in or  resetb_in)
	begin
	if(device_work) //not in reset or sleep mode or dpd mode
    begin	
	    if(!csb_in)
		begin
		  if(chip_en==0)
		  begin
		      $display("/**********************************************************************");
			  $display("Start CA_CMD latch! "); 
	          
			  if($realtime - tCE_high < tCSHI )
			      $display($psprintf("tCSHI violation. The CE High period is %t, it should be larger than %t",$realtime- tCE_high, tCSHI));
			
			  
                 
			  chip_en = 1;  
			  tCE_fall = $realtime;
			
			  rwds_out_en <= #(tDSV)  1; 
			  
			  
			  
			  if(latency_type==Variable)
			  begin
			     refresh_cntr=refresh_cntr+1;
			  
		       
			    if(refresh_cntr%5==0)
     		       refresh=1; 
				
			     if(refresh)
                 begin
                    case (CONFIG_REG0[7:4])
					4'b0000: latency_count =  10;
			        4'b0001: latency_count =  12;
					4'b0010: latency_count =  14;
                    4'b1110: latency_count =  6;		
                    4'b1111: latency_count =  8;				
					endcase 
                 end				 
                 else
                  begin				 
			        case (CONFIG_REG0[7:4])
					4'b0000: latency_count =  5;
			        4'b0001: latency_count =  6;
					4'b0010: latency_count =  7;
                    4'b1110: latency_count =  3;		
                    4'b1111: latency_count =  4;			
			        endcase 
			      end
			  end
			  
			  
			  
			  
              if( (CONFIG_REG0[3]== Fixed )||( (CONFIG_REG0[3]== Variable ) && refresh )) //have additional latency
			  begin
			    //$display("%t ==> Config0 fixed type!", $realtime); 
			    rwds_out<= #(tDSV)1;
				additionanl_latency=1;
			  end
			  else    //does not have additional latency
			  begin
			    //$display("%t ==> Config0 variable type!", $realtime); 
			    rwds_out <= #(tDSV)0;
				additionanl_latency=0;
			  end
			  
			  $display($psprintf("Chip Enable (%b) ", chip_en));
			  
			  
			  
			  
			  ce_clock = 0;
			  
			 
			  read_cmd  <= 0;
			  write_cmd <= 0;
		  end 
    	end
	
	    else if(csb_in || !resetb_in )
		begin
		  if(chip_en==1)
		  begin
		      if( !resetb_in )
			  $display("RESET Low to reset all the internal signals and counters");
			   
		      chip_en               = 0;  
			  addr_cmd_count        = 0;
		  	 			
			 //write/read
			  write_data_count = 0;
			  read_data_count = 0;
			  
			  additionanl_latency=0;
			 
			  dout_enable = 0;
			 
  			  read_start = 0;
			  write_start = 0;
			  
			  addr_in = 'hxxxxxx;

			  non_negclk = 0;
			  rwds_out_toggle= 0;
			  rwds_out_en = 0;
			  
		           
			  
			 // tCE_high = $realtime;
			  
			  exit_sleep_flag2=0;
              exit_sleep_flag1=0;
			  
			  if(!dpd_en)
			  if($realtime- tCE_fall > tCSM)
			      $display($psprintf("tCSM violation. The CE LOW period is %t, it should be smaller than %t",$realtime- tCE_fall, tCSM));
			  
				  
			    
			  write_cmd    = 0;
			  read_cmd     = 0;
			  
			  
			  latency_cycle_count_start =0;
			  latency_cycle_count=0;
			  latency_count_end=0;
			  write_latency_count_end=0;
			  read_latency_count_end=0;
			  
			  flag_read_reg  = 0;
			  flag_write_reg = 0;
			  flag_read_mem  = 0;
			  flag_write_mem = 0;
			  
			  df=0;
		
			  refresh=0;
			  hybrid_wrap_complete=0;
			  rwds_start_1st=0;
			  rwds_out_data_pos=0;
	          rwds_out_data_neg=0;
		
		
		      addr_wrap_complete=0;
			  addr_latch_1st=1;
			 hybrid_sleep_cs_Low_again=0;					 
			  
			  $display($psprintf("Chip disable (%b), addr_cmd_count %d, tCSM LOW period is %t",chip_en, addr_cmd_count, $realtime- tCE_fall ));
			  $display("**********************************************************************/");	  
			  
	      end 
    	end
	   end
      else
	  begin
	    //if(csb_in==0)
	    
	  end
       	   
	 
	end

//commadn latch and address latch at pos clock
`ifdef DCARS
always @(posedge psc_in)
begin
        if (chip_en)
		begin
		    if(latency_count_end) //RWDS followed PSC
			begin
			  if(ca0[15]==1)
			  begin
			     rwds_out       <=  #(`tPSCRWDS_min)1;
                 rwds_out_en    <=  #(`tPSCRWDS_min)1;
			  end
			end  
		end //end  if(chip_en)
end   
`endif

always @(posedge clk_in)
begin
        if (chip_en)
		begin
		    non_negclk = 1; //not neg edge clock first 
		   
		   ck_pos <= $realtime;
		   tck_i = $realtime - tck_pos;
		  		
		  		
		   addr_cmd_count = addr_cmd_count+1;
		  
		   if(addr_cmd_count<=6)
		   cmd_decode(addr_cmd_count, adq_in);
		  
		   if(addr_cmd_count==1)      //1th clock edge(pos)
		   begin
		      ca0[15:8] = adq_in[7:0];
		      $display($psprintf("pos clk, addr_cmd_count :%d,  adq_in: (0x%h) ",addr_cmd_count,adq_in[7:0]));
			  the_first_pos_clk = $realtime;
			  
		   end
           else if (addr_cmd_count==3) //3rd clock edge(pos)			 
		   begin
			  ca1[15:8] = adq_in[7:0];
		       $display($psprintf("pos clk, addr_cmd_count :%d,  adq_in: (0x%h) ",addr_cmd_count,adq_in[7:0]));
			
		   end
    	
           else if (addr_cmd_count==5) //5rd clock edge(pos)			 
		   begin
			  ca2[15:8] = adq_in[7:0];
		       $display($psprintf("pos clk, addr_cmd_count :%d,  adq_in: (0x%h) ", addr_cmd_count,adq_in[7:0]));
			
		   end
    	
    	   else if (addr_cmd_count==7) //7rd clock edge(pos) , just display			 
		   begin
		     
			 
			 //address assign
			 addr_in ={ca_cmd_in[HiAddrBit:16], ca_cmd_in[2:0]};
			 
			 $display($psprintf("pos clk, addr_cmd_count :%d,  cmd_in(0x%h) : ca0 (0x%h), ca1 (0x%h), ca2 (0x%h), addr_in: 'h%h ", addr_cmd_count,ca_cmd_in, ca0,ca1,ca2, addr_in));
            
			if(addr_latch_1st)
			 begin
					      addr_in_start = addr_in;
						  addr_latch_1st=0;
						  
					     // $display($psprintf("write mem : pos clok: 1st latch addr: 0x%h", addr_in_start));
				
			 end
			
			 if(addr_in > 22'h3fffff)
			  $display($psprintf("The address space(0x%h) is larger than 22'h3fffff",addr_in));
			
			 if(flag_write_reg)              
			       write_register(0);	


             display_linear_wrap;
				   
           end
          

    			
		   if(addr_cmd_count > 2)
		   begin
  		        //$display("%t ==>INFO! tck_l is %t, ck_pos is %t, tck_i is %t, tCL_MIN *tck_i is %t, addr_cmd_count %d", $realtime,  $realtime -tck_neg, ck_pos, tck_i, tCL_MIN *tck_i, addr_cmd_count);
		        //if( $realtime -tck_neg < tCL_MIN *tck_i)
		        //$display("%t ==>ERROR! tCL is smaller than tCL_MIN, tCL is %t, tck_i is %t, tCL_MIN *tck_i is %t", $realtime,  $realtime -tck_neg, tck_i, tCL_MIN *tck_i);
		  
		       // if( $realtime -tck_neg > tCL_MAX *tck_i)
		        // $display("%t ==>ERROR! tCL is larger than tCL_MAX, tCL is %t, tck_i is %t, tCL_MAX *tck_i is %t", $realtime,  $realtime -tck_neg, tck_i, tCL_MAX *tck_i);
		   end
		  
            tck_pos = $realtime; 
		 
		 
		    if( $realtime - tCE_fall < tCSS)
			 $display($psprintf("tCSS violation, the real period is %t, tCSS spec is %t ",$realtime - tCE_fall, tCSS));
		        
		 
		    if(latency_count_end) //trigger for read
			begin
			  if(ca0[15]==1'b1)
			  begin
			  `ifndef DCARS 
			    rwds_out       <=  #(tCKDS_min)1;
                rwds_out_en    <=  #(tCKDS_min)1;
			  `endif
			    rwds_out_toggle<=  #(tCKDS_min-0.2)1;
	            dout_enable    <=  #(tCKDS_min)1;
			  end
			  else if(flag_write_mem) //write mem
			  begin
			   rwds_out_en    <=  #(tCKDS_min)0;
			   dout_enable    <=  #(tCKDS_min)0;
			   rwds_out_toggle <=  #(tCKDS_min-0.2)0;
			  end
			end  
		   
		end //end  if(chip_en)
		
		else
		begin
		ce_clock = ce_clock+1;
		end
end   
	
//commadn latch and address latch at neg edge clock
 always @(negedge clk_in)
 begin
        if (chip_en && non_negclk)
		begin
			 if(latency_cycle_count_start)
			 latency_cycle_count = latency_cycle_count+1;
			
             if(latency_cycle_count==latency_code)
			 begin
			    if( $realtime -tACC_start < tACC)
			        $display($psprintf("tACC violation, the real tACC %t, tACC spec : %t", $realtime -tACC_start, tACC ));
		     end
			 
			 if(latency_cycle_count == latency_count)
			 begin
			    if(read_cmd)
				begin
			    read_latency_count_end=1;
				latency_count_end=1;
				end
				else if(flag_write_mem)
			    write_latency_count_end= #0.1 1;
			 end
			 
			 else if(latency_cycle_count == latency_count+1)
			 begin
			    latency_count_end=0;
			 end
			 
			 ck_neg = $realtime;
			
			 addr_cmd_count =addr_cmd_count+1;

			 if(addr_cmd_count<=6)
		     cmd_decode(addr_cmd_count, adq_in);
			 
		     if(addr_cmd_count==2)      //2th clock,			 
		     begin
			   ca0[7:0] = adq_in[7:0];
		       $display($psprintf("neg clk, addr_cmd_count :%d,  adq_in: (0x%h) ", addr_cmd_count,adq_in[7:0]));
			 end
		 
		     else if(addr_cmd_count==4) //4th clock, 			 
		     begin
			   ca1[7:0] = adq_in[7:0];
		       
			   $display($psprintf("neg clk, addr_cmd_count :%d,  adq_in: (0x%h) ", addr_cmd_count,adq_in[7:0]));
			

			   df=1;
			   
			   latency_cycle_count_start=1;
			   
			   if(tCE_high!=0)
			   if($realtime - tCE_high < tRWR)
                $display($psprintf("tRWR violation, the period is %t, tRWR spec is %t,tCE_high: %t ", $realtime -tCE_high, tRWR, tCE_high));
		   			
               tACC_start = $realtime;
			  
			   //$display($psprintf("tACC start time %t",tACC_start));
		   		 
			
			 end
			 
			 
			 else if(addr_cmd_count==6) 			 
		     begin
			   ca2[7:0] = adq_in[7:0];
		       $display($psprintf("neg clk, addr_cmd_count :%d,  adq_in: (0x%h) ",addr_cmd_count,adq_in[7:0]));
			
			   ca_cmd_in = {ca0,ca1,ca2}; 
			
               
			   if(read_cmd)
			   begin
			        if(additionanl_latency)
			           rwds_out <=  #(tCKDSR_max) 0;
			        else
			           rwds_out <=  #(tCKDS_max) 0;
			   end		   
			   else
			   rwds_out_en<= #(tDSZ)  0; //write
			   
			   
			   /*
			   if(read_cmd)
			   rwds_out <=  #(tCKDSR_max) 0;
			   else
			   rwds_out_en<= #(tCKDSR_max)  0; //write
			   */
			   
			 end
			 
			 else if(addr_cmd_count==8) 			 
		     begin
			     if(flag_write_reg)
			      write_register(1);
				 
				  
			 end
			 
			   

		   
		     if(addr_cmd_count > 2)
			  begin
			     //if( $realtime -tck_pos < tCH_MIN *tck_i)
		           //  $display("%t ==>ERROR! tCH is smaller than tCH_MIN, tCH is %t, tck_i is %t, tCH_MIN *tck_i is %t", $realtime,  $realtime -tck_pos, tck_i, tCH_MIN *tck_i);
		        // if( $realtime -tck_pos > tCH_MAX *tck_i)
		           //   $display("%t ==>ERROR! tCH is larger than tCH_MAX, tCH is %t, tck_i is %t, tCH_MAX *tck_i is %t", $realtime,  $realtime -tck_pos, tck_i, tCH_MAX *tck_i);
			
			 end
			
             tck_neg = $realtime;
			 
			
			 
	    end //end if chip_en		 
		
		
		
end	//end always

//hyperram write mem, datalatch
always @(clk_in)
begin
        if (chip_en)
		begin
		    if(write_latency_count_end)
			begin
			     if(clk_in)
				 begin
				       //$display($psprintf("write mem : pos clok: data_high_byte: 0x%h , data mask: %d",adq, rwds_in));
				
				      // if(addr_latch_1st)
					  // begin
					  //    addr_in_start = addr_in;
						//  addr_latch_1st=0;
						  
					     // $display($psprintf("write mem : pos clok: 1st latch addr: 0x%h", addr_in_start));
				
					   //end
					   
				       if(!rwds_in)
						memory[addr_in][15:8]= adq;
				  end
			     else
				 begin
			     					
			           // $display($psprintf("write mem :  neg clok: data_low_byte: 0x%h, data mask: %d ", adq, rwds_in));
					  
					
					   if(!rwds_in)
					   memory[addr_in][7:0]= adq; 
					
					   $display($psprintf("memory Write ,      addr in : 'h%h,  data in: 'h%h",addr_in,memory[addr_in]));
					   
					   addr_process;
					

					   
			     end
			end
			else if(read_latency_count_end)
			begin
			     if(clk_in)
				 begin
				        if (ca_cmd_in[47:46] == 2'b10) //read mem
			            mem_read(addr_in, data_out_buff); 
			     end
			
			end
		end	
end




always @(df)
begin
   if(df)
   begin
     op_frequency= (1.0/tck_i)*1000;
     $display("============================================================================= ");
     $display($psprintf("    The clock frequency is %f MHz, tck_i is %t    , LC: %d          ",op_frequency, tck_i, latency_code));
	 $display("============================================================================= ");
   
	 LC_check;
	 
   end
end




task write_register;
     input clk_edge; //0:pos, 1:neg
begin
    	 if(write_cmd )  //register write
              begin
                      if( target_space== register_space)
					  begin
                           if( ca_cmd_in == CR0_WRITE)
						   begin
						     if(clk_edge==0) 
						      CONFIG_REG0[15:8]  = adq_in[7:0];
							 else
							 begin
							  CONFIG_REG0[15:0]  = {CONFIG_REG0[15:8],adq_in[7:0]};
							 
						     $display("============================================================================= ");
                             $display($psprintf("                 Write CR0:  0x%h                                                ",CONFIG_REG0));
	                         $display("============================================================================= ");
   
							 reg_conf(CONFIG_REG0,0);
							 
	                         end 
	 
						   end
                           else if(ca_cmd_in == CR1_WRITE)  						   
						   begin
						     if(clk_edge==0) 
						      CONFIG_REG1[15:8]  = adq_in[7:0];
							 else
							 begin
							  CONFIG_REG1[7:0]  = adq_in[7:0];
							
						 	 $display("============================================================================= ");
                             $display($psprintf("                 Write CR1:  0x%h                                                ",CONFIG_REG1));
	                         $display("============================================================================= ");
   
							 reg_conf(CONFIG_REG1,1);
							 end
							 
						   end
                      end
              end 
     
				  
	
end
endtask

task LC_check;
begin
    
	if(latency_code==3) // ~ 83MHz
	begin
	   if(op_frequency > 85)
       begin
         $display($psprintf("LC setting error(LC=%d),the op frequency:%fMHz, the allowed maxi op frequency is 85MHz", latency_code,op_frequency));
       end   	   
	end
	else if(latency_code==4) // ~ 100MHz
	begin
	   if(op_frequency > 104)
       begin
         $display($psprintf("LC setting error(LC=%d),the op frequency:%fMHz, the allowed maxi op frequency is 104MHz", latency_code,op_frequency));
       end   	   
	end
	
    else if(latency_code==5) // ~ 133MHz
	begin
	   if(op_frequency > 133)
       begin
       
	    $display($psprintf("LC setting error(LC=%d),the op frequency:%fMHz, the allowed maxi op frequency is 133MHz", latency_code,op_frequency));
    
	   end   	   
	end
	
	else if(latency_code==6) // ~ 166MHz
	begin
	   if(op_frequency > 166)
       begin
         $display($psprintf("LC setting error(LC=%d),the op frequency:%fMHz, the allowed maxi op frequency is 166MHz", latency_code,op_frequency));
       end   	   
	end
	
	else if(latency_code==7) // ~ 133MHz
	begin
	   if(op_frequency > 200)
       begin
         $display($psprintf("LC setting error(LC=%d),the op frequency:%fMHz, the allowed maxi op frequency is 200MHz", latency_code,op_frequency));
       end   	   
	end
	
end
endtask


task cmd_decode;
input [2:0] i;
input [7:0] cmd;
begin
   //cmd decode
			  case (i)
			   1:
			        begin
				        $display("CMD: latch CA[47:40]");
						$display($psprintf("CA[47:40]:8'b%b", cmd));
						if (cmd[7]==1)
						begin
                        write_cmd    = 0;
						read_cmd     = 1;
						end
						else
						begin
						write_cmd    = 1;
						read_cmd     = 0;
						end
						
						
						if (cmd[6]==1)
						begin
                          target_space= register_space; //register
						  if(cmd[7]==1) 
						  begin
						     flag_read_reg  = 1;
							 flag_write_reg = 0;
							 flag_read_mem  = 0;
							 flag_write_mem = 0;
						  end	 
						  else if(cmd[7]==0) 
						  begin
						     flag_read_reg  = 0;
							 flag_write_reg = 1;
							 flag_read_mem  = 0;
							 flag_write_mem = 0;
						  end
						end
						else
						begin
						  target_space= memory_space; //memory
						  if(cmd[7]==1) 
						  begin
						     flag_read_reg  = 0;
							 flag_write_reg = 0;
							 flag_read_mem  = 1;
							 flag_write_mem = 0;
						  end	 
						  else if(cmd[7]==0) 
						  begin
						     flag_read_reg  = 0;
							 flag_write_reg = 0;
							 flag_read_mem  = 0;
							 flag_write_mem = 1;
						  end
						end
						
                 	end
			   2:
			        begin
					    $display("CMD: latch CA[39:32]");
						$display($psprintf("CA[39:32]:8'b%b", cmd));
			       
			        end
			   
			   3:
			        begin
					    $display("CMD: latch CA[31:24]");
						$display($psprintf("CA[31:24]:8'b%b", cmd));
					end
			   4:
			        begin
			            $display("CMD: latch CA[23:16]");
						$display($psprintf("CA[23:16]:8'b%b", cmd));
			        end
			    5:
			        begin
					    $display("CMD: latch CA[15:8]");
						$display($psprintf("CA[15:8]:8'b%b", cmd));
			         
			        end

                 6:
			        begin
					    $display("CMD: latch CA[7:0]");
						$display($psprintf("CA[7:0]:8'b%b", cmd));
					  end 					
			   endcase 
			

end
endtask	


task addr_process;
begin
    if(f_linear_address)
	begin
	  addr_in = addr_in+1;
	end
	else if(f_hybrid_wrap_address)
	begin
	      addr_in=addr_in+1;
		  
		  if(!hybrid_wrap_complete )
		  begin
		    if (addr_in % (burst_length/2) == 0)
               addr_in= addr_in - burst_length/2;
			
           case (burst_length)
            128:		   
            if(addr_in[6:0]==addr_in_start[6:0])
			begin
			   $display($psprintf("hybrid wrap address complete, burst_length:%d, addr_in[6:0]:0x%h", burst_length,addr_in[6:0])); 
			   addr_in = { addr_in[21:6]+1,6'b000000};
			   hybrid_wrap_complete=1'b1;
			end 
			
			64:		   
            if(addr_in[5:0]==addr_in_start[5:0])
			begin
			   $display($psprintf("hybrid wrap address complete, burst_length:%d, addr_in[5:0]:0x%h", burst_length,addr_in[5:0])); 
			   addr_in = { addr_in[21:5]+1,5'b00000};
			   hybrid_wrap_complete=1'b1;
			end 
			
			32:		   
            if(addr_in[4:0]==addr_in_start[4:0])
			begin
			   $display($psprintf("hybrid wrap address complete, burst_length:%d, addr_in[4:0]:0x%h", burst_length,addr_in[4:0])); 
			   addr_in = { addr_in[21:4]+1,4'b0000};
			   hybrid_wrap_complete=1'b1;
			end 
			
			16:		   
            if(addr_in[3:0]==addr_in_start[3:0])
			begin
			   $display($psprintf("hybrid wrap address complete, burst_length:%d, addr_in[3:0]:0x%h", burst_length,addr_in[3:0])); 
			   addr_in = { addr_in[21:3]+1,3'b000};
			   hybrid_wrap_complete=1'b1;
			end 
			
		   endcase	
		  end	   
	
	end
	else if(f_legacy_wrap_address)
	begin
	    addr_in=addr_in+1;
		  if (addr_in % (burst_length/2) == 0)
            addr_in= addr_in - burst_length/2;
	
	end
end
endtask


task dq_proess;
begin
     read_data_count = read_data_count+1; 
 
     if (ca_cmd_in[47:46] == 2'b10) //read mem 
     begin
	    if(rwds_out_data_pos)
		begin
           data_out = data_out_buff[15:8];
		  // $display($psprintf("Read Data, read_data_count : %d, addrss : 0x%h, data out : 0x%h , rwds_out : %d",read_data_count, addr_in, data_out, rwds_out_data_pos)); 
		end
		
        else if(rwds_out_data_neg)
		begin
               data_out =data_out_buff[7:0];
              // $display($psprintf("Read Data, read_data_count : %d, addrss : 0x%h, data out : 0x%h , rwds_out : %d",read_data_count, addr_in, data_out, rwds_out_data_pos)); 
			    
	           addr_process;
					  		   
                 					   
		end
        else
		data_out=8'hXX;
    end
   
    else if (ca_cmd_in[47:46] == 2'b11) //read rgister 
    begin
        if(rwds_out_data_pos)
		begin
			if(read_data_count%2==1)
			begin
			     if(ca_cmd_in[45]==1'b0)
				 ca_cmd_in[45]=1'b1;
				 
			     case (ca_cmd_in)
			     ID0_READ: data_out = ID_REG0[15:8] ;
			     ID1_READ: data_out = ID_REG1[15:8] ;
			     CR0_READ: data_out = CONFIG_REG0[15:8] ;
				 CR1_READ: data_out = CONFIG_REG1[15:8] ;
				 
				 MIR0_READ: data_out  = MIR_REG0[15:8] ;
				 MIR1_READ: data_out  = MIR_REG1[15:8] ;
			     MIR2_READ: data_out  = MIR_REG2[15:8] ;
				 MIR3_READ: data_out  = MIR_REG3[15:8] ;
				 MIR4_READ: data_out  = MIR_REG4[15:8] ;
				 MIR5_READ: data_out  = MIR_REG5[15:8] ;
				 MIR6_READ: data_out  = MIR_REG6[15:8] ;
				 MIR7_READ: data_out  = MIR_REG7[15:8] ;
			     MIR8_READ: data_out  = MIR_REG8[15:8] ;
				 MIR9_READ: data_out  = MIR_REG9[15:8] ;
				 MIR10_READ: data_out = MIR_REG10[15:8] ;
				 MIR11_READ: data_out = MIR_REG11[15:8] ;
				 MIR12_READ: data_out = MIR_REG12[15:8] ;
				 MIR13_READ: data_out = MIR_REG13[15:8] ;
			     MIR14_READ: data_out = MIR_REG14[15:8] ;
				 MIR15_READ: data_out = MIR_REG15[15:8] ;
				 MIR16_READ: data_out = MIR_REG16[15:8] ;
				 MIR17_READ: data_out = MIR_REG17[15:8] ;
				 
				 
				 endcase
				$display($psprintf("Read Register, read_data_count :%d, address : 0x%h, registe out (8'b%b) (0x%h) ",read_data_count, ca_cmd_in, data_out, data_out)); 
			 
			end
		end
		
        else if(rwds_out_data_neg)
		begin
			if(read_data_count%2==0)
			begin
			  if(ca_cmd_in[45]==1'b0)
				 ca_cmd_in[45]=1'b1;
				 
		      case (ca_cmd_in)
			     ID0_READ: data_out = ID_REG0[7:0] ;
			     ID1_READ: data_out = ID_REG1[7:0] ;
			     CR0_READ: data_out = CONFIG_REG0[7:0] ;
				 CR1_READ: data_out = CONFIG_REG1[7:0] ;
				 
				 MIR0_READ: data_out  = MIR_REG0[7:0] ;
				 MIR1_READ: data_out  = MIR_REG1[7:0] ;
			     MIR2_READ: data_out  = MIR_REG2[7:0] ;
				 MIR3_READ: data_out  = MIR_REG3[7:0] ;
				 MIR4_READ: data_out  = MIR_REG4[7:0] ;
				 MIR5_READ: data_out  = MIR_REG5[7:0] ;
				 MIR6_READ: data_out  = MIR_REG6[7:0] ;
				 MIR7_READ: data_out  = MIR_REG7[7:0] ;
			     MIR8_READ: data_out  = MIR_REG8[7:0] ;
				 MIR9_READ: data_out  = MIR_REG9[7:0] ;
				 MIR10_READ: data_out = MIR_REG10[7:0] ;
				 MIR11_READ: data_out = MIR_REG11[7:0] ;
				 MIR12_READ: data_out = MIR_REG12[7:0] ;
				 MIR13_READ: data_out = MIR_REG13[7:0] ;
			     MIR14_READ: data_out = MIR_REG14[7:0] ;
				 MIR15_READ: data_out = MIR_REG15[7:0] ;
				 MIR16_READ: data_out = MIR_REG16[7:0] ;
				 MIR17_READ: data_out = MIR_REG17[7:0] ;
				 
				 
			 endcase
			$display($psprintf("Read Register, read_data_count :%d, address : 0x%h, registe out (8'b%b) (0x%h) ", read_data_count, ca_cmd_in, data_out, data_out)); 
		      
			`ifndef display_no_info
				  //display_regConf(ca_cmd_in);
				  //display_regConf(INDEX_CONFIG_REG1);
			`endif
			
			end
			 
		   
		 
		 end
        else
		data_out=8'hXX;
   
    end
 
 

end
endtask	

`ifdef DCARS
 always @ (posedge psc_in)
    begin
	     if (rwds_out_toggle) 
         begin
                  if(rwds_out==1'b0 && rwds_out_en)
 				     rwds_out<=  #(`tPSCRWDS_min) 1'b1;
				  if(rwds_out==1'b1 && rwds_out_en)
 				     rwds_out <=  #(`tPSCRWDS_min)1'b0;
				
         end  
    end	
	
	
	always @ (negedge psc_in)
    begin
	     if (rwds_out_toggle && rwds_start_1st ) 
         begin
                  if(rwds_out==1'b0 && rwds_out_en)
 				     rwds_out <=  #(`tPSCRWDS_min)1'b1;
				  if(rwds_out==1'b1 && rwds_out_en)
 				     rwds_out <=  #(`tPSCRWDS_min)1'b0;
	     end 

	end	
   
    always @ (posedge clk_n_in_dly)
    begin
	     if (rwds_out_toggle) 
         begin
         		  rwds_start_1st=1;
				  dq_proess;
         end  
    end	
	
	
	always @ (posedge clk_in_dly)
    begin
		 if (rwds_out_toggle) 
      		 dq_proess;
	end	
   
`else
 always @ (posedge clk_n_in_dly)
    begin
	     if (rwds_out_toggle) 
         begin
                  if(rwds_out==1'b0 && rwds_out_en)
 				     rwds_out <= 1'b1;
				  if(rwds_out==1'b1 && rwds_out_en)
 				     rwds_out <= 1'b0;
				  
				  rwds_start_1st=1;
				  
				  dq_proess;
         end  
    end	
	
	
	always @ (posedge clk_in_dly)
    begin
	     if (rwds_out_toggle && rwds_start_1st ) 
         begin
                  if(rwds_out==1'b0 && rwds_out_en)
 				     rwds_out <= 1'b1;
				  if(rwds_out==1'b1 && rwds_out_en)
 				     rwds_out <= 1'b0;
	     end 

		 if (rwds_out_toggle) 
      		 dq_proess;
	end	
`endif
	
	
// Write to Memory
task mem_write;
	input [21:0] addr_in;
	input [15:0]  write_dq_in;
	begin
	$display($psprintf("memory Write task,      addr in : 'h%h,  data in: 'h%h",addr_in,write_dq_in ));
    memory[addr_in] = write_dq_in; 
	end
endtask

// Read from Memory
task mem_read;
     input [21:0] addr_in;
     output [15:0] read_data_out;
	
	begin
	read_data_out =  memory[addr_in];
    if(flag_read_mem)
	$display($psprintf("memory read task,              addr in: 'h%h, data out : 'h%h", addr_in,read_data_out ));
	end
endtask

task erase_mem;
        //input  [2:0] density
        input  [2:0]    pasr ;
        reg    [full_mem_bits : 0] k;
        begin

            if (pasr == 0) begin
			
            end else if (pasr == 1) begin
                for (k = 22'h3fffff; k > 22'h1fffff; k = k - 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end
            end else if (pasr == 2) begin
                for (k = 22'h3fffff; k > 22'hfffff; k = k - 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end
            end else if (pasr == 3) begin
                for (k = 22'h3fffff; k > 22'h7ffff; k = k - 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end
				
			 end else if (pasr == 4) begin
                 for (k = 0; k <= {(full_mem_bits){1'b1}}; k = k + 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
                 end
				
            end else if (pasr == 5) begin
                 for (k = 0; k <  22'h200000; k = k + 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end
			
            end else if (pasr == 6) begin
                 for (k = 0; k <  22'h300000; k = k + 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end
			
             end else if (pasr == 7) begin
                 for (k = 0; k <  22'h380000; k = k + 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
					//$display("%t ==>INFO,ERASE memory: k: 0x%h, memory:0x%h", $realtime,k,memory[k] );
					
                end  
			
            end else begin
                for (k = 0; k <= {(full_mem_bits){1'b1}}; k = k + 1) begin
                    memory[k] = {WORD_BITS{1'bx}};
                end
                $display ("%t ERROR: illegal PASR setting.\n  All Data will be lost.\n", $realtime);
            end
       end
endtask




// Register Configuration
task reg_conf;
	input [15:0] reg_in;
	input  reg_id;
begin
       if(reg_id==0)
	   begin
			CONFIG_REG0	= reg_in;	
			
			
			case (reg_in[1:0])
					2'b00: 
					      begin
						        burst_length = 128;
					      end
			        2'b01: 
					      begin
						        burst_length = 64;
						  end		
                    2'b10: 
					      begin 
						        burst_length = 16;	
						  end		
                    2'b11: 
					      begin 
						        burst_length = 32;   
						  end		
			endcase 
			
            latency_type =  reg_in[3]; 
			
            //latency_code =  reg_in[7:4]; 			
			
			
			case (reg_in[7:4])
					4'b0000: latency_code = 5;
			        4'b0001: latency_code = 6;
					4'b0010: latency_code = 7;
                    4'b1110: latency_code = 3;		
                    4'b1111: latency_code = 4;		
			endcase 
				
		
			if( reg_in[3] == fixed_type)
			begin
				case (reg_in[7:4])
					4'b0000: latency_count = 10;
			        4'b0001: latency_count = 12;
					4'b0010: latency_count = 14;
                    4'b1110: latency_count = 6;		
                    4'b1111: latency_count = 8;		
			    endcase 
			end
			else if( reg_in[3] == variable_type) 
			begin
			        case (reg_in[7:4])
					4'b0000: latency_count = 5;
			        4'b0001: latency_count = 6;
					4'b0010: latency_count = 7;
                    4'b1110: latency_count = 3;		
                    4'b1111: latency_count = 4;	
					endcase
				
			end
			
			if(reg_in[15]==1'b0)
			begin
			   dpd_en=1;   
			   $display($psprintf("Write Config Register0, CR0[15]=0, set DPD mode ")); 
			   erase_mem(3'b100); //erase all memory cell
			   
			   //device_work=0; //stop latch command
			   //chip_en=0;
			end
			
			
		end	
	
	   else if(reg_id==1)
	   begin
			CONFIG_REG1	= reg_in;	
			if(reg_in[5]==1'b1) //hybrid sleep mode
			begin
			   hybrid_sleep_en=1;   
			   $display($psprintf("Write Register, CR1[5]=1, set hybrid sleep mode ")); //1.2
		       
		    end
			
			erase_mem(reg_in[4:2]);
			
	   end		
end
endtask

task display_linear_wrap;
begin
                case({ca_cmd_in[45], CONFIG_REG0[2]})
					2'b10:
						begin
							$display("burst==>linear burst!");
						end
					2'b11:
						begin
							$display("burst==>linear burst!");
						end
					
				   	2'b00:
						begin
							$display("burst==>Hybrid Wrap burst!");
						end
					2'b01:
						begin
							$display("burst==>Legacy Wrap burst!");
						end
				     
				endcase
end
endtask

task display_regConf;
	input [47:0] reg_id;
begin
     
	$display("*--------------------------------------------------------------------");
	case(reg_id)
		ID0_READ:
			begin
			       $display("==>ID_REG0 display, ID_REG0 :(0x%h) (16'b%b)",ID_REG0, ID_REG0 );
				   $display("==>Manufacturer: Winbond (4'b%b)",ID_REG0[3:0] );
				   $display("==>Density     : col addr bits :%dbits",ID_REG0[7:4]+1);
				   $display("==>Density     : row addr bits :%dbits",ID_REG0[12:8]+1); 
				   $display("==>MCP die addr : die%d  (2'b%b)",ID_REG0[15:14], ID_REG0[15:14] ); 
				   
			end
		ID1_READ:
			begin
			       $display("==>ID_REG1 display, ID_REG1 :(0x%h) (16'b%b)",ID_REG1, ID_REG1);
				   $display("==>Device Type: Hyperbus HyperRAM 2.0 (4'b%b)",ID_REG1[3:0] );
				  
			end
		CR0_READ:
			begin
			     $display("==>CONFIG_REG0 display, CONFIG_REG0 :(0x%h) (16'b%b)",CONFIG_REG0, CONFIG_REG0);
				
				case(CONFIG_REG0[1:0])
					2'b00:
						begin
							$display("==>Burst Length: 128 bytes!");
						end
					2'b01:
						begin
							$display("==>Burst Length: 64 bytes!");
						end
				   	2'b10:
						begin
							$display("==>Burst Length: 16 bytes!");
						end
					2'b11:
						begin
							$display("==>Burst Length: 32 bytes!");
						end
				 		
				endcase
				
				case({ca_cmd_in[45], CONFIG_REG0[2]})
					2'b10:
						begin
							$display("==>linear burst!");
						end
					2'b11:
						begin
							$display("==>linear burst!");
						end
					
				   	2'b00:
						begin
							$display("==>Hybrid Wrap burst!");
						end
					2'b01:
						begin
							$display("==>Legacy Wrap burst!");
						end
				     
				endcase
				
			    
				case(CONFIG_REG0[3])
					1'b0:
						begin
							$display("==>Variable latency!");
						end
					1'b1:
						begin
							$display("==>Fixed latency!");
						end
					
				endcase
				
				
				case(CONFIG_REG0[7:4])
				4'b0000: $display("==>Latency clocks: 5");
				4'b0001: $display("==>Latency clocks: 6");
				4'b0010: $display("==>Latency clocks: 7");
				4'b1110: $display("==>Latency clocks: 3");
				4'b1111: $display("==>Latency clocks: 4");
				default: $display("==>wrong setting for Latency clocks");
				endcase  
				
				case(CONFIG_REG0[14:12])
				3'b000: $display("==>34 ohms");
				3'b001: $display("==>115 ohms");
				3'b010: $display("==>67 ohms");
				3'b011: $display("==>46 ohms");
				3'b100: $display("==>34 ohms");
				3'b101: $display("==>27 ohms");
				3'b110: $display("==>22 ohms");
				3'b111: $display("==>19 ohms");
				default: $display("==>reserved");
				endcase  
				
			
		
		    case(CONFIG_REG0[15])
					1'b0:
						begin
							$display("==>Enter Deep Powerdown!");
						end
					1'b1:
						begin
							$display("==>Normal Operation!");
						end
					
			endcase
         end
		 
		 
		 CR1_READ:
			begin
			     $display("==>CONFIG_REG1 display, CONFIG_REG1 :(0x%h) (16'b%b)",CONFIG_REG1, CONFIG_REG1);
				
				case(CONFIG_REG1[1:0])
					
					2'b00:
						begin
							$display("==>refresh interval - 2 times!");
						end
					2'b01:
						begin
							$display("==>refresh interval - 4 times!");
						end
				    2'b10:
						begin
							$display("==>refresh interval - TBD times!");
						end
					2'b11:
						begin
							$display("==>refresh interval - 1.5 times!");
						end
				 	
				    default: $display("==>wrong setting for refresh interval ");		
				endcase
				
				
				
				case(CONFIG_REG1[4:2])
					
					3'b000:
						begin
							$display("==>PASR: FULL!");
						end
					3'b001:
						begin
							$display("==>PASR: bottom 1/2 array!");
						end
				    3'b010:
						begin
							$display("==>PASR: bottom 1/4 array!");
						end
					3'b011:
						begin
							$display("==>PASR: bottom 1/8 array!");
						end
					3'b100:
						begin
							$display("==>PASR: NONE!");
						end	
					
				 	3'b101:
						begin
							$display("==>PASR: top 1/2 array!");
						end
				    3'b110:
						begin
							$display("==>PASR: top 1/4 array!");
						end
					3'b111:
						begin
							$display("==>PASR: top 1/8 array!");
						end	
				    default: $display("==>wrong setting for PASR");		
				endcase
				
				
				case(CONFIG_REG1[5])
					1'b0:
						begin
							$display("==>not in hybrid Sleep mode!");
						end
					1'b1:
						begin
							$display("==>enter hybrid Sleep mode!");
						end
					
				endcase
			    
				case(CONFIG_REG1[6])
				    1'b1:
						begin
							$display("==>master clock type -- single ednded!");
						end
					1'b0:
						begin
							$display("==>master clock type -- differential!");
						end
					
				endcase
				
				
         end
	endcase	 
	 $display("--------------------------------------------------------------------*/");
	
end
endtask


specify
 
  specparam  tIS1  = 0.5; //ns
  specparam  tIH1  = 0.5; //ns
  
  $setuphold(posedge clk_in &&& in_data_phase,   rwds,   tIS1, tIH1);
  $setuphold(negedge clk_in &&& in_data_phase,   rwds,   tIS1, tIH1);
  $setuphold(posedge clk_in &&& in_data_phase,   adq,   tIS1, tIH1);
  $setuphold(negedge clk_in &&& in_data_phase,   adq,   tIS1, tIH1);
  $setuphold(posedge clk_in &&& ins_addr_phase  ,   adq,   tIS1, tIH1);
  $setuphold(negedge clk_in &&& ins_addr_phase  ,   adq,   tIS1, tIH1);
  
endspecify
  
endmodule
//========================================================End of module 


