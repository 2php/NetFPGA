
module rcp_parser #(parameter DATA_WIDTH = 64,
		    CTRL_WIDTH = 8		    
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              word_RCP_FRATE,
    input                              word_RCP_RTT,
    input                              word_RCP_FIRST,
    input                              word_RCP_THIRD,

    output reg                         is_rcp,
    output reg [15:0]                  rcp_out_port,
    output reg [31:0]                  rcp_frate,
    output reg [15:0]                  rcp_rtt,
    output reg [7:0]                   rcp_proto,
    output reg [15:0]                  rcp_packet_length,

    output reg                         rcp_out_port_vld,
    output reg                         rcp_frate_vld,
    output reg                         rcp_rtt_vld,
    output reg                         rcp_proto_vld,
    output reg                         rcp_packet_length_vld,
    
    // --- Misc    
    input                              reset,
    input                              clk
   );


    localparam RCP_TYPE = 8'hFE;

    //-------------wire/reg
    
    //-------------logic
   always @(posedge clk) begin
      if(reset) begin
         rcp_rtt <= 0;
         rcp_proto <= 0;
	 is_rcp <= 0;
	 rcp_packet_length <= 0;
	 
      end
      else begin
	 if (word_RCP_FRATE) begin
	    rcp_frate <= in_data[47:16];
	    rcp_frate_vld <= 1;	    
	 end
	 else
	   rcp_frate_vld <= 0;
	         
	 if (word_RCP_RTT)begin
	    rcp_rtt   <= in_data[47:32];
            rcp_proto <= in_data[31:24];
	    rcp_rtt_vld <= 1;
	    rcp_proto_vld <= 1;	    
	 end
	 else begin
	    rcp_rtt_vld <= 0;
	    rcp_proto_vld <= 0;	    
	 end
	 
	 if(word_RCP_FIRST) begin
	    rcp_packet_length <= in_data[15:0];
	    rcp_out_port <= in_data[63:48];
	    rcp_out_port_vld <= 1;
	    
	 end
	 else
	   rcp_packet_length_vld <= 0;
	 
	 
	 if(word_RCP_THIRD) begin
	    rcp_packet_length_vld <= 1;
	    if (in_data[7:0] == RCP_TYPE)
	      is_rcp <= 1;
	 end
         if(in_ctrl == 8'h01)
           is_rcp <= 0;       
      end // else: !if(reset)
      
   end // always @ (posedge clk)
   

endmodule // rcp_parser


