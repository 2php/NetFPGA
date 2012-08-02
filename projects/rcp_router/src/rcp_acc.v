
module rcp_acc (
		//-- interface to rcp_parser
		input                        is_rcp,
		input [15:0] 		     rcp_out_port,		
		input [15:0] 		     rcp_rtt,
		input [7:0] 		     rcp_proto,
		input [15:0] 		     rcp_packet_length,
		
		input                        rcp_out_port_vld,
		input                        rcp_rtt_vld,
		input                        rcp_proto_vld,
		input                        rcp_packet_length_vld,

		//-- interface to rcp_regs
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_rcp,

		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_rcp,
		
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_rcp,

		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_L,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_H,
		output reg  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_rcp,

		//-- misc
		input                       reset,
		input                       clk);

   //-------------wire/reg
   
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0]	    temp_mac_0_rtt;
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0]	    temp_mac_0_length;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]	    temp_mac_0_is_rcp;

   reg [2*`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_1_rtt;
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_1_length;
   reg [`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_1_is_rcp;   
   
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_2_rtt;
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_2_length;
   reg [`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_2_is_rcp;   

   reg [2*`CPCI_NF2_DATA_WIDTH-1:0] 	    temp_mac_3_rtt;
   reg [2*`CPCI_NF2_DATA_WIDTH-1:0]	    temp_mac_3_length;
   reg [`CPCI_NF2_DATA_WIDTH-1:0]	    temp_mac_3_is_rcp;


   reg 					    rcp_packet_length_vld_delay_1;
   reg 					    rcp_packet_length_vld_delay_2;
   reg 					    rcp_packet_length_vld_delay_3;
   

   //-------------logic

   always @(posedge clk) begin
      if (reset)
	rcp_packet_length_vld_delay_1 <= 0;
      else
	rcp_packet_length_vld_delay_1 <= rcp_packet_length_vld;      
   end
   
   always @(posedge clk) begin
      if (reset)
	rcp_packet_length_vld_delay_2 <= 0;
      else
	rcp_packet_length_vld_delay_2 <= rcp_packet_length_vld_delay_1;      
   end
   
   always @(posedge clk) begin
      if (reset)
	rcp_packet_length_vld_delay_3 <= 0;
      else
	rcp_packet_length_vld_delay_3 <= rcp_packet_length_vld_delay_2;      
   end
   
   // mac 0
   always @(posedge clk)
     begin
	if (reset) begin
	   temp_mac_0_rtt <= 0;
	   temp_mac_0_length<= 0;
	   temp_mac_0_is_rcp <= 0;
	end
	else if (is_rcp & (rcp_out_port== 16'h0001))begin
	   if(rcp_rtt_vld) begin
	     temp_mac_0_rtt <= temp_mac_0_rtt + rcp_rtt;
	      temp_mac_0_is_rcp <= temp_mac_0_is_rcp + 1;
	   end
	   if(rcp_packet_length_vld_delay_3)
	     temp_mac_0_length <= temp_mac_0_length + rcp_packet_length;
	end // else: !if(reset)  
     end // always @ (posedge clk)

   always @(*)
     begin
	mac_0_rtt_L        <= temp_mac_0_rtt[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_0_rtt_H        <= temp_mac_0_rtt[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_0_num_byte_L   <= temp_mac_0_length[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_0_num_byte_H   <= temp_mac_0_length[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_0_num_rcp      <= temp_mac_0_is_rcp[`CPCI_NF2_DATA_WIDTH-1:0];
     end

   // mac 1
   always @(posedge clk)
     begin
	if (reset) begin
	   temp_mac_1_rtt <= 0;
	   temp_mac_1_length<= 0;
	   temp_mac_1_is_rcp <= 0;
	end
	else if (is_rcp & (rcp_out_port == 16'h0004))begin
	   if(rcp_rtt_vld) begin
	      temp_mac_1_rtt <= temp_mac_1_rtt + rcp_rtt;
	      temp_mac_1_is_rcp <= temp_mac_1_is_rcp + 1;
	   end
	   if(rcp_packet_length_vld_delay_3)
	     temp_mac_1_length <= temp_mac_1_length + rcp_packet_length;
	end // else: !if(reset)  
     end // always @ (posedge clk)
   always @(*)
     begin
	mac_1_rtt_L        <= temp_mac_1_rtt[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_1_rtt_H        <= temp_mac_1_rtt[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_1_num_byte_L   <= temp_mac_1_length[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_1_num_byte_H   <= temp_mac_1_length[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_1_num_rcp      <= temp_mac_1_is_rcp[`CPCI_NF2_DATA_WIDTH-1:0];
     end


   // mac 2
   always @(posedge clk)
     begin
	if (reset) begin
	   temp_mac_2_rtt <= 0;
	   temp_mac_2_length<= 0;
	   temp_mac_2_is_rcp <= 0;
	end
	else if (is_rcp & (rcp_out_port == 16'h0010))begin
	   if(rcp_rtt_vld) begin
	     temp_mac_2_rtt <= temp_mac_2_rtt + rcp_rtt;
	      temp_mac_2_is_rcp <= temp_mac_2_is_rcp + 1;
	   end
	   if(rcp_packet_length_vld_delay_3)
	     temp_mac_2_length <= temp_mac_2_length + rcp_packet_length;

	end // else: !if(reset)  
     end // always @ (posedge clk)
   
   always @(*)
     begin
	mac_2_rtt_L        <= temp_mac_2_rtt[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_2_rtt_H        <= temp_mac_2_rtt[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_2_num_byte_L   <= temp_mac_2_length[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_2_num_byte_H   <= temp_mac_2_length[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_2_num_rcp      <= temp_mac_2_is_rcp[`CPCI_NF2_DATA_WIDTH-1:0];
     end


   // mac 3
   always @(posedge clk)
     begin
	if (reset) begin
	   temp_mac_3_rtt <= 0;
	   temp_mac_3_length<= 0;
	   temp_mac_3_is_rcp <= 0;
	  
	end
	else if (is_rcp & (rcp_out_port == 16'h0040))begin
	   if(rcp_rtt_vld) begin
	     temp_mac_3_rtt <= temp_mac_3_rtt + rcp_rtt;
	      temp_mac_3_is_rcp <= temp_mac_3_is_rcp + 1;
	   end
	   if(rcp_packet_length_vld_delay_3)
	     temp_mac_3_length <= temp_mac_3_length + rcp_packet_length;
	end // else: !if(reset)  
     end // always @ (posedge clk)

   always @(*)
     begin
	mac_3_rtt_L        <= temp_mac_3_rtt[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_3_rtt_H        <= temp_mac_3_rtt[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_3_num_byte_L   <= temp_mac_3_length[`CPCI_NF2_DATA_WIDTH-1:0];
	mac_3_num_byte_H   <= temp_mac_3_length[2*`CPCI_NF2_DATA_WIDTH-1:`CPCI_NF2_DATA_WIDTH];
	mac_3_num_rcp      <= temp_mac_3_is_rcp[`CPCI_NF2_DATA_WIDTH-1:0];
     end


endmodule // rcp_acc
