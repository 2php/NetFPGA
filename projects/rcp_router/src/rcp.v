 module rcp
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2)

   (// --- data path interface
    output   [DATA_WIDTH-1:0]        out_data,
    output   [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                          out_wr,
    input                               out_rdy,
    
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output                             in_rdy,

    // --- Register interface
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    // --- Misc
    
    input                              clk,
    input                              reset);
   
 
   //--------------------- Internal Parameter-------------------------
   
   //---------------------- Wires/Regs -------------------------------

   wire                         is_rcp;
   wire [15:0] 			rcp_out_port;
   wire [31:0] 			rcp_frate;
   wire [15:0] 			rcp_rtt;
   wire [7:0] 			rcp_proto;
   wire [15:0] 			rcp_packet_length;
   wire                         rcp_out_port_vld;
   wire                         rcp_frate_vld;
   wire                         rcp_rtt_vld;
   wire                         rcp_proto_vld;
   wire                         rcp_packet_length_vld;
   
   wire 			word_RCP_FRATE;
			

   wire [`CPCI_NF2_DATA_WIDTH-1:0] 			rcp_rate_0;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      rcp_rate_1;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      rcp_rate_2;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      rcp_rate_3;

   

   reg [DATA_WIDTH -1 :0] mid_data;
   
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_rcp;
   
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_rcp;
   
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_rcp;
   
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_L;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_H;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_rcp;


   // debuging registers
   reg [31:0] 			   num_words_in;
   reg [31:0] 			   num_words_out;
   reg [31:0] 			   num_packets_in;
   reg [31:0] 			   num_packets_out;
   
   //---------- Internal parameters -----------
   //localparam rcp_rate='h50;
   
   //---------------------- Logic ------------------------------------

   always @(posedge clk)begin
      if (reset)
	num_words_in <= 32'b0;
      else if(in_wr == 1'b1)
	num_words_in <= num_words_in +1;
   end

   always @(posedge clk)begin
      if (reset)
	num_words_out <= 32'b0;
      else if(out_wr == 1'b1)
	num_words_out <= num_words_out +1;
   end
   
   always @(posedge clk)begin
      if (reset)
	num_packets_in <= 32'b0;
      else if(in_ctrl == 8'hFF & in_wr)
	num_packets_in <= num_packets_in +1;
   end

   always @(posedge clk)begin
      if (reset)
	num_packets_out <= 32'b0;
      else if(out_ctrl == 8'hFF & out_wr)
	num_packets_out <= num_packets_out +1;
   end
   
   small_fifo
     #(.WIDTH    (DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS (3))rcp_fifo_data
       
       (
	
	.din         ({mid_data, in_ctrl}),       // Data in
	.wr_en       (fifo_wr),                  // Write enable
	
	.rd_en       (fifo_rd),                  // Read the next word
	
	.dout         ({out_data,out_ctrl}),     // Data out  
	.full         (rcp_data_full),
	.nearly_full  (rcp_data_nearly_full),
	.empty        (rcp_data_empty),
	
	.reset        (reset),
	.clk          (clk)
	);


   
   assign     fifo_wr = in_wr;
   assign     fifo_rd = out_rdy & !rcp_data_empty;
   assign     in_rdy = !rcp_data_nearly_full;

   
   always @(posedge clk) begin
      if(fifo_rd)
	out_wr <= 1;
      else
	out_wr <= 0;
   end

  always @(*)begin
	if (is_rcp & word_RCP_FRATE) begin
		if((rcp_out_port == 16'h 0001) & (in_data[47:16] > rcp_rate_0))
			mid_data = {in_data[63:48],rcp_rate_0,in_data[15:0]};
		else if ((rcp_out_port == 16'h 0004) & (in_data[47:16] > rcp_rate_1))
			mid_data = {in_data[63:48],rcp_rate_1,in_data[15:0]};
		else if ((rcp_out_port == 16'h 0010) & (in_data[47:16] > rcp_rate_2))
			mid_data = {in_data[63:48],rcp_rate_2,in_data[15:0]};
		else if ((rcp_out_port == 16'h 0040) & (in_data[47:16] > rcp_rate_3))
			mid_data = {in_data[63:48],rcp_rate_3,in_data[15:0]};
		else
			mid_data = in_data;
	end
	else
		mid_data = in_data;
  end
    //assign mid_data = (is_rcp & (in_data[47:16]>rcp_rate) & word_RCP_FRATE)? {in_data[63:48],rcp_rate,in_data[15:0]}:in_data;
   
   
   //-- controller to count the input packet words 
   rcp_parser_control
     #(.DATA_WIDTH  (DATA_WIDTH),
       .CTRL_WIDTH  (CTRL_WIDTH)
       )rcp_parser_control
       (// --- Interface to the previous stage
	.in_ctrl          (in_ctrl),
	.in_wr            (in_wr),
	
	// --- Interface to RCP parser
	.word_RCP_FRATE   (word_RCP_FRATE),
	.word_RCP_RTT     (word_RCP_RTT),
	.word_RCP_FIRST   (word_RCP_FIRST),
	.word_RCP_THIRD   (word_RCP_THIRD),
	// --- Misc
	
	.reset            (reset),
	.clk              (clk)
	);   
   
   
   //-- parses the header of the rcp packet

   rcp_parser #(.DATA_WIDTH  (DATA_WIDTH),
		.CTRL_WIDTH  (CTRL_WIDTH)		    
		) rcp_parser
     (// --- Interface to the previous stage
      .in_data             (in_data),
      .in_ctrl             (in_ctrl),
      
      // interface to rcp_parser_control
      .word_RCP_FRATE         (word_RCP_FRATE),
      .word_RCP_RTT           (word_RCP_RTT),
      .word_RCP_FIRST         (word_RCP_FIRST),
      .word_RCP_THIRD         (word_RCP_THIRD),
      
      // interface to accumulator
      .is_rcp                 (is_rcp),
      .rcp_out_port           (rcp_out_port),
      .rcp_frate              (rcp_frate),
      .rcp_rtt                (rcp_rtt),
      .rcp_proto              (rcp_proto),
      .rcp_packet_length      (rcp_packet_length),
      
      .rcp_out_port_vld       (rcp_out_port_vld),
      .rcp_frate_vld          (rcp_frate_vld),
      .rcp_rtt_vld            (rcp_rtt_vld),
      .rcp_proto_vld          (rcp_proto_vld),
      .rcp_packet_length_vld  (rcp_packet_length_vld),
      
      // --- Misc    
      .reset                  (reset),
      .clk                    (clk)
      );


   //-- accumulate rtt , num_bytes and number of rcp packets for each output port
   rcp_acc 
     rcp_acc(
	     //-- interface to rcp_parser
	     .is_rcp                (is_rcp),
	     .rcp_out_port          (rcp_out_port),		
	     .rcp_rtt               (rcp_rtt),
	     .rcp_proto             (rcp_proto),
	     .rcp_packet_length     (rcp_packet_length),
	     
	     .rcp_out_port_vld      (rcp_out_port_vld),
	     .rcp_rtt_vld           (rcp_rtt_vld),
	     .rcp_proto_vld         (rcp_proto_vld),
	     .rcp_packet_length_vld (rcp_packet_length_vld),
	     
	     //-- interface to rcp_regs
	     .mac_0_rtt_L           (mac_0_rtt_L),
	     .mac_0_rtt_H           (mac_0_rtt_H),
	     .mac_0_num_byte_L      (mac_0_num_byte_L),
	     .mac_0_num_byte_H      (mac_0_num_byte_H),
	     .mac_0_num_rcp         (mac_0_num_rcp),
	     
	     .mac_1_rtt_L           (mac_1_rtt_L),
	     .mac_1_rtt_H           (mac_1_rtt_H),
	     .mac_1_num_byte_L      (mac_1_num_byte_L),
	     .mac_1_num_byte_H      (mac_1_num_byte_H),
	     .mac_1_num_rcp         (mac_1_num_rcp),
	     
	     .mac_2_rtt_L           (mac_2_rtt_L),
	     .mac_2_rtt_H           (mac_2_rtt_H),
	     .mac_2_num_byte_L      (mac_2_num_byte_L),
	     .mac_2_num_byte_H      (mac_2_num_byte_H),
	     .mac_2_num_rcp         (mac_2_num_rcp),
	     
	     .mac_3_rtt_L           (mac_3_rtt_L),
	     .mac_3_rtt_H           (mac_3_rtt_H),
	     .mac_3_num_byte_L      (mac_3_num_byte_L),
	     .mac_3_num_byte_H      (mac_3_num_byte_H),
	     .mac_3_num_rcp         (mac_3_num_rcp),
	     
	     
	     //-- misc
	     .reset                 (reset),
	     .clk                   (clk));
   
   
   
   
   generic_regs
     #( 
	.UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
	.TAG                  (`RCP_BLOCK_ADDR),
	.REG_ADDR_WIDTH       (`RCP_REG_ADDR_WIDTH),  
	.NUM_COUNTERS         (0),
	.NUM_SOFTWARE_REGS    (4),
	.NUM_HARDWARE_REGS    (20),
	.COUNTER_INPUT_WIDTH  (0)
	) generic_regs
       (
	.reg_req_in      (reg_req_in),
	.reg_ack_in      (reg_ack_in),
	.reg_rd_wr_L_in  (reg_rd_wr_L_in),
	.reg_addr_in     (reg_addr_in),
	.reg_data_in     (reg_data_in),
	.reg_src_in      (reg_src_in),
	
	.reg_req_out     (reg_req_out),
	.reg_ack_out     (reg_ack_out),
	.reg_rd_wr_L_out (reg_rd_wr_L_out),
	.reg_addr_out    (reg_addr_out),
	.reg_data_out    (reg_data_out),
	.reg_src_out     (reg_src_out),

	// --- counters interface
	.counter_updates  (),   // all the counter updates are concatenated
	.counter_decrement(), // if 1 then subtract the update, else add.
	
	// --- SW regs interface
	.software_regs    ({rcp_rate_3, rcp_rate_2, rcp_rate_1, rcp_rate_0}), // signals from the software
	
	// --- HW regs interface
	.hardware_regs  ({
			  mac_3_num_byte_L, mac_3_num_byte_H,  mac_3_num_rcp, mac_3_rtt_L, mac_3_rtt_H,
			  mac_2_num_byte_L, mac_2_num_byte_H,  mac_2_num_rcp, mac_2_rtt_L, mac_2_rtt_H,
			  mac_1_num_byte_L, mac_1_num_byte_H,  mac_1_num_rcp, mac_1_rtt_L, mac_1_rtt_H,
			  mac_0_num_byte_L, mac_0_num_byte_H,  mac_0_num_rcp, mac_0_rtt_L, mac_0_rtt_H }),
	
	.clk           (clk),
	.reset         (reset));
   
   
   
endmodule // rcp


