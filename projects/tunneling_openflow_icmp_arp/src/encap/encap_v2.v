/******************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 * filename:  encap_v2.v
 * author:    G. Adam Covington
 * Summary:   Adds an IP header to packets if the packet
 *            is not from a specified source port and the
 *            module is enabled.
 *
 * Warning: Needs ip_fixer to update length and checksum
 ******************************************************/

 module encap_v2
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter IOQ_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter ENCAP_BLOCK_TAG = `ENCAP_0_BLOCK_ADDR,
      parameter PKT_SRC_PORT_WIDTH = 16)

   (// --- data path interface
    output  [DATA_WIDTH-1:0]           out_data,
    output  [CTRL_WIDTH-1:0]           out_ctrl,
    output                             out_wr,
    input                              out_rdy,

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
    input                              reset
    );

   `CEILDIV_FUNC

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //---- Internal Parameters
   parameter MAX_PKT            = 2048;   // allow for 2K bytes
   parameter PKT_BYTE_CNT_WIDTH = log2(MAX_PKT);
   parameter PKT_WORD_CNT_WIDTH = log2(MAX_PKT/CTRL_WIDTH);

   //----
   parameter IDLE 			= 'h0;
   parameter OTHER_HDRS                 = 'h2;
   parameter HEADER_BYPASS              = 'h3;
   parameter HEADERS                    = 'h4;
   parameter DST_SRC 		        = 'h5;
   parameter SRC_TYPE_DATA              = 'h6;
   parameter ADD_IP_HDR_1               = 'h7;
   parameter ADD_IP_HDR_2               = 'h8;
   parameter ADD_IP_HDR_3               = 'h9;
   parameter WAIT_END_PKT               = 'hA;
   parameter SEND_LAST_WORD             = 'hB;
   parameter WAIT_END_PKT_NORM          = 'hC;
   
   parameter NUM_STATES 		= 13;

   reg [NUM_STATES-1:0] 		state;
   reg [NUM_STATES-1:0] 		next_state;

   //--- wires/ registers
   wire 			       in_fifo_nearly_full;
   wire 			       in_fifo_empty;
   reg 				       in_fifo_rd_en;

   reg 				       out_wr_int;

   wire [DATA_WIDTH-1:0] 	       in_fifo_data;
   wire [CTRL_WIDTH-1:0] 	       in_fifo_ctrl;

   reg [DATA_WIDTH-1:0]                in_fifo_data_int, in_fifo_data_int_nxt;
   reg [CTRL_WIDTH-1:0]                in_fifo_ctrl_int, in_fifo_ctrl_int_nxt;
   reg [DATA_WIDTH-1:0] 	       out_data_int;
   reg [CTRL_WIDTH-1:0] 	       out_ctrl_int;

   reg [PKT_SRC_PORT_WIDTH-1:0]        dst_port_reg;
   reg [PKT_SRC_PORT_WIDTH-1:0]        dst_port;

   wire [log2(NUM_OUTPUT_QUEUES)-1:0]  parsed_pkt_dst_port;
   wire [PKT_SRC_PORT_WIDTH-1:0]       parsed_pkt_src_port;
   wire [PKT_BYTE_CNT_WIDTH-1:0]       parsed_pkt_byte_length;
   wire [PKT_WORD_CNT_WIDTH-1:0]       parsed_pkt_word_length;
   reg [PKT_BYTE_CNT_WIDTH-1:0]        new_pkt_byte_length;
   reg [PKT_WORD_CNT_WIDTH-1:0]        new_pkt_word_length;
   reg [PKT_BYTE_CNT_WIDTH-1:0]        new_pkt_byte_length_reg;
   reg [PKT_WORD_CNT_WIDTH-1:0]        new_pkt_word_length_reg;

   reg 				       rd_dst_port;

   wire				       header_parser_rdy;

   reg 				       encap_pkt;

   wire [31:0]			       encap_enable; //global enable for the module
   wire [31:0] 			       encap_ports;  // four five bit sections the fifth bit is the enable for the specified port

   wire [31:0] 			       encap_src_ip;
   wire [31:0] 			       encap_dst_ip;
   wire [31:0] 			       encap_ttl_proto;
   wire [31:0] 			       encap_tos;
   wire [31:0] 			       encap_src_mac_hi;
   wire [31:0] 			       encap_src_mac_lo;
   wire [31:0] 			       encap_dst_mac_hi;
   wire [31:0] 			       encap_dst_mac_lo;
   wire [31:0]                         encap_tag;

   //------------------------- Local assignments -------------------------------

   assign in_rdy     = header_parser_rdy && !in_fifo_nearly_full;
   assign out_wr     = out_wr_int;
   assign out_data   = out_data_int;
   assign out_ctrl   = out_ctrl_int;

   encap_header_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_OUTPUT_QUEUES(NUM_OUTPUT_QUEUES))
   encap_header_parser
     (
       .parsed_dst_oq        (parsed_pkt_dst_port),
       .parsed_pkt_byte_len  (parsed_pkt_byte_length),
       .parsed_pkt_word_len  (parsed_pkt_word_length),
       .parsed_pkt_src_port  (parsed_pkt_src_port),
       .header_parser_rdy    (header_parser_rdy),
       .dst_oq_avail         (dst_port_avail),
       .rd_dst_oq            (rd_dst_port),
       .in_wr                (in_wr),
       .in_ctrl              (in_ctrl),
       .in_data              (in_data),
       .clk                  (clk),
       .reset                (reset));

   fallthrough_small_fifo
     #(.WIDTH    (DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS (4))encap_fifo_data

       (

        .din         ({in_ctrl, in_data}),            // Data in
        .wr_en       (in_wr),                         // Write enable
        .rd_en       (in_fifo_rd_en),                 // Read the next word

        .dout         ({in_fifo_ctrl, in_fifo_data}), // Data out
        .full         (),
        .nearly_full  (in_fifo_nearly_full),
        .empty        (in_fifo_empty),

        .reset        (reset),
        .clk          (clk)
        );

   //--- registers
   generic_regs
   #(
      .UDP_REG_SRC_WIDTH    (UDP_REG_SRC_WIDTH),
      .TAG                  (ENCAP_BLOCK_TAG),
      .REG_ADDR_WIDTH       (`ENCAP_REG_ADDR_WIDTH),
      .NUM_COUNTERS         (0),
      .NUM_SOFTWARE_REGS    (11),  
      .NUM_HARDWARE_REGS    (0),
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
    .counter_decrement(),   // if 1 then subtract the update, else add.

    // --- SW regs interface
    .software_regs    ({encap_dst_mac_lo, encap_dst_mac_hi, encap_src_mac_lo, encap_src_mac_hi, encap_tos, encap_ttl_proto, encap_dst_ip, encap_src_ip,
			encap_ports, encap_tag, encap_enable}), // signals from the software

    // --- HW regs interface
    .hardware_regs  (),

    .clk           (clk),
    .reset         (reset));

   //latch the state
   always @(posedge clk) begin
      if(reset) begin
         state <= IDLE;
      end
      else begin
         state <= next_state;
      end
   end

  //--- State Machine
  always @(*) begin
    //default assignments
    next_state    = state;

    in_fifo_rd_en = 0;
    out_data_int = in_fifo_data;
    out_ctrl_int = in_fifo_ctrl;
    out_wr_int = 0;
    rd_dst_port = 0;
    dst_port = dst_port_reg;
    new_pkt_word_length = new_pkt_word_length_reg;
    new_pkt_byte_length = new_pkt_byte_length_reg;
    in_fifo_data_int_nxt = in_fifo_data_int;
    in_fifo_ctrl_int_nxt = in_fifo_ctrl_int;
     
    case(state)
      IDLE: begin
	if (dst_port_avail) begin
	   rd_dst_port = 1;
	   dst_port = parsed_pkt_dst_port;

	   if (encap_enable[0]) begin
	      if (encap_pkt) begin
		 next_state = OTHER_HDRS;
		 new_pkt_byte_length = parsed_pkt_byte_length + 38; // number of bytes added
		 new_pkt_word_length = ceildiv(new_pkt_byte_length, 8);
	      end
	      else begin
		next_state = HEADER_BYPASS;
	      end
	   end
	   else begin
	      next_state = HEADER_BYPASS;
	   end
	end
      end // case: IDLE

      OTHER_HDRS: begin
	 if (in_fifo_ctrl == 0 && !in_fifo_empty ) begin
	    in_fifo_rd_en = 0;
	    out_wr_int = 0;
	    next_state = DST_SRC;
	 end
	 else if (!in_fifo_empty && out_rdy) begin
	    in_fifo_rd_en = 1;
	    out_wr_int = 1;

            // Modify the data if we have the length header
            if(in_fifo_ctrl==IOQ_STAGE_NUM) begin
               out_data_int[`IOQ_BYTE_LEN_POS + PKT_BYTE_CNT_WIDTH-1:`IOQ_BYTE_LEN_POS] = new_pkt_byte_length;
               out_data_int[`IOQ_WORD_LEN_POS + PKT_WORD_CNT_WIDTH-1:`IOQ_WORD_LEN_POS] = new_pkt_word_length;
            end
	 end
      end

      HEADER_BYPASS: begin
	if (!in_fifo_empty && out_rdy) begin
	   in_fifo_rd_en = 1;
	   out_wr_int = 1;
	end

	if (in_fifo_ctrl == 0) begin
	   next_state = WAIT_END_PKT_NORM;
	end
      end

      DST_SRC: begin
	 if (out_rdy) begin
	    out_data_int = {encap_dst_mac_hi[15:0], encap_dst_mac_lo, encap_src_mac_hi[15:0]};
	    out_wr_int = 1;

	    next_state = SRC_TYPE_DATA;
	 end
      end

      SRC_TYPE_DATA: begin
	 if (out_rdy) begin
	    out_data_int = {encap_src_mac_lo, 16'h0800, 4'b0100, 4'b0101, encap_tos[7:0]}; //Version, IHL, TOS
	    out_wr_int = 1;

	    next_state = ADD_IP_HDR_1;
	 end
      end

      ADD_IP_HDR_1: begin
	 if (out_rdy) begin
	    out_data_int = {16'b0, 16'b0, 3'b010, 13'b0, encap_ttl_proto[15:0]}; //total_length, ID, Flags, Fragment_offset
	    out_wr_int = 1;

	    next_state = ADD_IP_HDR_2;
         end
      end

      ADD_IP_HDR_2: begin
	 if (out_rdy) begin
	    out_data_int = {16'b0, encap_src_ip, encap_dst_ip[31:16]};
	    out_wr_int = 1;

	    next_state = ADD_IP_HDR_3;
	 end
      end

      ADD_IP_HDR_3: begin
	 if (!in_fifo_empty && out_rdy) begin
            in_fifo_rd_en = 1;
            out_wr_int = 1;
            out_data_int = {encap_dst_ip[15:0], encap_tag, in_fifo_data[63:48]};
            out_ctrl_int = {6'b0, in_fifo_ctrl[7:6]};
            in_fifo_data_int_nxt = in_fifo_data;
            in_fifo_ctrl_int_nxt = in_fifo_ctrl;
	    
	    next_state = WAIT_END_PKT;
         end
      end

      WAIT_END_PKT: begin
	 if (!in_fifo_empty && out_rdy) begin
	    in_fifo_rd_en = 1;
	    out_wr_int = 1;
            out_data_int = {in_fifo_data_int[47:0], in_fifo_data[63:48]};
            out_ctrl_int = {in_fifo_ctrl_int[5:0], in_fifo_ctrl[7:6]};
            in_fifo_data_int_nxt = in_fifo_data;
            in_fifo_ctrl_int_nxt = in_fifo_ctrl;

            if (in_fifo_ctrl[7:6] != 0) begin
               next_state = IDLE;
            end
            else if (in_fifo_ctrl[5:0] != 0) begin
               next_state = SEND_LAST_WORD;
            end
	 end
      end

      SEND_LAST_WORD: begin
	 if (out_rdy) begin
	    out_wr_int = 1;
            out_data_int = {in_fifo_data_int[47:0], 16'b0};
            out_ctrl_int = {in_fifo_ctrl_int[5:0], 2'b0};

            next_state = IDLE;
	 end
      end

      WAIT_END_PKT_NORM: begin
	 if (!in_fifo_empty && out_rdy) begin
	    in_fifo_rd_en = 1;
	    out_wr_int = 1;

            if (in_fifo_ctrl != 0) begin
               next_state = IDLE;
            end
	 end
      end

    endcase
  end // always @ (*)

  always @(posedge clk) begin
     if (reset) begin
        new_pkt_word_length_reg <= 0;
	new_pkt_byte_length_reg <= 0;
	dst_port_reg <= 0;
        in_fifo_data_int <= 0;
        in_fifo_ctrl_int <= 1;
     end
     else begin
	new_pkt_word_length_reg <= new_pkt_word_length;
	new_pkt_byte_length_reg <= new_pkt_byte_length;
	dst_port_reg <= dst_port;
        in_fifo_data_int <= in_fifo_data_int_nxt;
        in_fifo_ctrl_int <= in_fifo_ctrl_int_nxt;
     end
  end

  always @(*) begin
     encap_pkt = 0;

     if (encap_ports[PKT_SRC_PORT_WIDTH-1:0] != parsed_pkt_src_port) begin
	encap_pkt = 1;
     end
  end // always @ (*)

endmodule // encap
