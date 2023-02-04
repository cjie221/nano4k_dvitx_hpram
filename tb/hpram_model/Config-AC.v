
parameter MHz166 = 6.0;
parameter MHz133 = 7.5;
parameter MHz104 = 9.6;
parameter MHz85  = 11.76;
parameter MHz200 = 5.0;

`define  clk_period 5


`ifdef T200
parameter  tCK= MHz200; //
`else `ifdef T166
parameter  tCK= MHz166; //
`else `ifdef T133
parameter  tCK= MHz133; //
`else `ifdef T104
parameter  tCK= MHz104; //
`else `ifdef T85
parameter  tCK= MHz85; //
`else
parameter  tCK= `clk_period; //

`endif `endif  `endif `endif `endif


parameter  tCH_MIN= 0.45; //clocks
parameter  tCH_MAX= 0.55; //clocks
parameter  tCL_MIN= 0.45; //clocks
parameter  tCL_MAX= 0.55; //clocks




parameter LOW	= 0;
parameter HIGH	= 1;
parameter HIZ	= 'bz;
parameter XX	= 'bx;

parameter ENABLE = 1'b1;
parameter DISABLE = 1'b0;

parameter READY = 1'b1;
parameter NOTREADY = 1'b0;
	

parameter ADQ_BITS	= 8;
parameter WORD_BITS	= 16;
parameter ADDR_BITS	= 22;




parameter TEST_DELAY = 0.1;
parameter refresh_cycle = 4e3;	// optional value



parameter Fixed  = 1'b1;
parameter fixed_type  = 1'b1;
parameter Variable  = 1'b0;
parameter variable_type  = 1'b0;


parameter full_mem_bits= 22;

//hyperram
parameter tCSHI =6 ; //ns
parameter tRWR =35 ; //ns
parameter tCSS=4 ; //ns

`ifdef DC3V
parameter tDSV=6.5 ; //ns
`else
parameter tDSV=5 ; //ns
`endif

parameter tIS= 0.5; //ns
parameter tIH= 0.5 ; //ns
parameter tACC =35 ; //ns

parameter tCKD_min =1 ; //ns

`define tPSCRWDS_min 1.5 //ns

`ifdef DC3V
parameter tCKD_max     =6.5 ; //ns
parameter tPSCRWDS_max =6.5 ; //ns
`else
parameter tCKD_max      =5.0 ; //ns
parameter tPSCRWDS_max =5.5 ; //ns
`endif



parameter tCKDI_min =0 ; //ns

`ifdef DC3V
parameter tCKDI_max =4.6 ; //ns
`else
parameter tCKDI_max =4.2 ; //ns
`endif


parameter tDV =1.5 ; //ns
parameter tCKDS_min =1 ; //ns


`ifdef DC3V
parameter tCKDS_max =6.5 ; //ns
`else
parameter tCKDS_max =5.0 ; //ns
`endif


parameter tCKDSR_min =1 ; //ns
parameter tCKDSR_max =8 ; //ns

parameter tDSS_min =-0.4 ; //ns
parameter tDSS_max =0.4 ; //ns
parameter tDSH_min =-0.4 ; //ns
parameter tDSH_max =0.4 ; //ns

parameter  tCSH_MIN = 0.0; //ns
parameter  tCSH_MAX = 0.0; //ns



`ifdef DC3V
parameter tDSZ=6.5 ; //ns
`else
parameter tDSZ=5 ; //ns
`endif






`ifdef DC3V
parameter tOZ=6.5 ; //ns
`else
parameter tOZ=5 ; //ns
`endif


`ifdef LA_85C
parameter tCSM=1000 ; //ns, larger than 85C
`else
parameter tCSM=4000 ; //ns, less than 85C
`endif

parameter tRP = 200 ; //ns, 
parameter tRH = 200 ; //ns, 
parameter tRPH = 400 ; //ns, 

parameter tVCS = 150000 ; //ns, 

parameter tDMV = 0 ; //ns,


//hybrid sleep 
parameter  tHSMXC_min=60; //ns
parameter  tHSMX_max=70000; //ns


parameter  tHSIN      = 3000; //ns
parameter  tCSHS_min  =   60; //ns
parameter  tCSHS_max  = 3000; //ns
parameter  tEXTHS_max = 100000; //ns


//DPD
parameter  tDPDIN      = 10000;  //10us
parameter  tDPDCSL     = 200;    //200ns
parameter  tDPDOUT_MAX = 150000; //150us
parameter  tCSDPD_min  = 200;    //200ns
parameter  tCSDPD_max  = 3000;   
parameter  tEXTDPD   = 150000;   




parameter memory_space=0;
parameter register_space=1;
parameter HiAddrBit = 34;



parameter DEFAULT_ID_REG0      = 16'b00_0_01100_1000_0110;     //0xC86, 8 columns address, 12 row address 

parameter DEFAULT_ID_DIE0_REG0      = 16'b00_0_01100_1000_0110;     //0x0C86, 8 columns address, 12 row address 
parameter DEFAULT_ID_DIE1_REG0      = 16'b01_0_01100_1000_0110;     //0x4C86, 8 columns address, 12 row address 
parameter DEFAULT_ID_DIE2_REG0      = 16'b10_0_01100_1000_0110;     //0x8C86, 8 columns address, 12 row address 
parameter DEFAULT_ID_DIE3_REG0      = 16'b11_0_01100_1000_0110;     //0xCC86, 8 columns address, 12 row address 

parameter DEFAULT_ID_REG1      = 16'b00000000_0000_0001;      //0x01



parameter DEFAULT_CONFIG_REG0  = 16'b1_000_1111_0010_1_1_11;  //0x8f2f
parameter DEFAULT_CONFIG_REG1  = 16'b11111111_1_1_0_000_10;    //0xffC2

parameter INDEX_ID_REG0     =0;
parameter INDEX_ID_REG1     =1;
parameter INDEX_CONFIG_REG0 =2;
parameter INDEX_CONFIG_REG1 =3;

parameter ID0_READ = 48'hE0_00_00_00_00_00;
parameter ID1_READ = 48'hE0_00_00_00_00_01;
parameter CR0_READ = 48'hE0_00_01_00_00_00;
parameter CR0_WRITE= 48'h60_00_01_00_00_00;
parameter CR1_READ = 48'hE0_00_01_00_00_01;
parameter CR1_WRITE= 48'h60_00_01_00_00_01;

parameter MIR0_READ = 48'hE0_00_02_00_00_00;
parameter MIR1_READ = 48'hE0_00_02_00_00_01;
parameter MIR2_READ = 48'hE0_00_02_00_00_02;
parameter MIR3_READ = 48'hE0_00_02_00_00_03;
parameter MIR4_READ = 48'hE0_00_02_00_00_04;
parameter MIR5_READ = 48'hE0_00_02_00_00_05;
parameter MIR6_READ = 48'hE0_00_02_00_00_06;
parameter MIR7_READ = 48'hE0_00_02_00_00_07;
parameter MIR8_READ = 48'hE0_00_02_00_00_08;
parameter MIR9_READ = 48'hE0_00_02_00_00_09;
parameter MIR10_READ = 48'hE0_00_02_00_00_0A;
parameter MIR11_READ = 48'hE0_00_02_00_00_0B;
parameter MIR12_READ = 48'hE0_00_02_00_00_0C;
parameter MIR13_READ = 48'hE0_00_02_00_00_0D;
parameter MIR14_READ = 48'hE0_00_02_00_00_0E;
parameter MIR15_READ = 48'hE0_00_02_00_00_0F;
parameter MIR16_READ = 48'hE0_00_02_00_00_10;
parameter MIR17_READ = 48'hE0_00_02_00_00_11;


//CR0
//CR0[15] 
parameter CR0_B15_ENETR_DPD=0;
parameter CR0_B15_NORMAL=1;

//CR0[14:12] 
parameter CR0_B14_12_drive_34_ohms    =3'b000; //default
parameter CR0_B14_12_drive_115_ohms   =3'b001;
parameter CR0_B14_12_drive_67_ohms    =3'b010;
parameter CR0_B14_12_drive_46_ohms    =3'b011;
parameter CR0_B14_12_drive_34_2_ohms  =3'b100; 
parameter CR0_B14_12_drive_27_ohms    =3'b101;
parameter CR0_B14_12_drive_22_ohms    =3'b110;
parameter CR0_B14_12_drive_19_ohms    =3'b111;

//CR0[7:4] 
parameter CR0_B7_4_LC5 =4'b0000;
parameter CR0_B7_4_LC6 =4'b0001; 
parameter CR0_B7_4_LC7 =4'b0010;
parameter CR0_B7_4_LC3 =4'b1110;
parameter CR0_B7_4_LC4 =4'b1111;

//CR0[3] 
parameter CR0_B3_VARIABLE_LATENCY=1'b0;
parameter CR0_B3_FIXED_LATENCY=1'b1;//default

//CR0[2] 
parameter CR0_B2_HYBRID_WRAP_BURST=1'b0;
parameter CR0_B2_LEGACY_WRAP_BURST=1'b1;

//CR0[1:0] 
parameter CR0_B1_0_BL_128 =2'b00;
parameter CR0_B1_0_BL_64  =2'b01;
parameter CR0_B1_0_BL_16  =2'b10;
parameter CR0_B1_0_BL_32  =2'b11; //default;

//CR1
//CR1[6] 
parameter CR1_B6_CLOCK_DIFF =1'b0;
parameter CR1_B6_CLOCK_SING =1'b1;

//CR1[5] 
parameter CR1_B5_NOT_IN_HALF_SLEEP =1'b0;
parameter CR1_B5_ENTER_HALF_SLEEP  =1'b1;


//CR1[4:2] 
parameter CR1_B4_2_FULL     =3'b000;
parameter CR1_B4_2_BOT_HALF =3'b001;
parameter CR1_B4_2_BOT_QRTR =3'b010;
parameter CR1_B4_2_BOT_OCTR =3'b011;
parameter CR1_B4_2_NONE     =3'b100;
parameter CR1_B4_2_TOP_HALF =3'b101;
parameter CR1_B4_2_TOP_QRTR =3'b110;
parameter CR1_B4_2_TOP_OCTR =3'b111;




//CR1[1:0] 
parameter CR1_B1_0_TBD_TIMES =2'b10;
parameter CR1_B1_0_1P5_TIMES =2'b11;
parameter CR1_B1_0_2_TIMES   =2'b00;
parameter CR1_B1_0_4_TIMES   =2'b01;




//MIR
parameter MIR_REG0   = 16'h1127;
parameter MIR_REG1   = 16'h2287;
parameter MIR_REG2   = 16'h3345;
parameter MIR_REG3   = 16'h4443;
parameter MIR_REG4   = 16'h5527;
parameter MIR_REG5   = 16'h6687;
parameter MIR_REG6   = 16'hXXXX;
parameter MIR_REG7   = 16'hXXXX;
parameter MIR_REG8   = 16'hXXXX;
parameter MIR_REG9   = 16'hXXXX;
parameter MIR_REG10  = 16'hXXXX;
parameter MIR_REG11  = 16'hDD88;
parameter MIR_REG12  = 16'hEE34;
parameter MIR_REG13  = 16'hFF17;
parameter MIR_REG14  = 16'h1277;
parameter MIR_REG15  = 16'hXXXX;
parameter MIR_REG16  = 16'hXXXX;
parameter MIR_REG17  = 16'hXXXX;

