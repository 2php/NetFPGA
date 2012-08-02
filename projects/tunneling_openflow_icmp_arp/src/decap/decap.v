///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id$
//
// Module: decap.v
// Project: NF2.1 Tunneling OpenFlow Switch
// Author: Jad Naous <jnaous@stanford.edu>
// Description: Removes the first CROP_LENGTH 64-bit words of the packet
//              if the IP protocol matches ENCAP_IP_PROT
//
///////////////////////////////////////////////////////////////////////////////

module decap
  #(parameter DATA_WIDTH         = 64,
    parameter CTRL_WIDTH         = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH  = 2,
    parameter CROP_LENGTH        = 5)

   (// --- data path interface
    output reg [DATA_WIDTH-1:0]        out_data,
    output reg [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                         out_wr,
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
    input                              reset);

   `LOG2_FUNC
   `CEILDIV_FUNC

   //------------------ Internal Parameters --------------------------
   localparam ETH_TYPE_POS = 16;
   localparam ETH_TYPE_IP  = 16'h0800;

   localparam IP_PROTO_POS = 0;

   localparam NUM_PREPROCESS_STATES         = 4;
   localparam PREPROCESS_SKIP_MODULE_HDRS   = 1,
              PREPROCESS_CHECK_ETHERTYPE    = 2,
              PREPROCESS_CHECK_IP_PROTO     = 4,
              PREPROCESS_WAIT_EOP           = 8;

   localparam NUM_PROCESS_STATES            = 5;
   localparam PROCESS_WAIT_PREPROCESS       = 1,
              PROCESS_CROP_PACKET           = 2,
              PROCESS_WAIT_EOP              = 4,
              PROCESS_SEND_LAST_WORD        = 8,
              PROCESS_WAIT_EOP_NORM         = 16;


   //---------------------- Wires/Regs -------------------------------
   wire [CTRL_WIDTH-1:0] input_fifo_ctrl;
   wire [DATA_WIDTH-1:0] input_fifo_data;
   reg                   input_fifo_rd_en;

   reg                   ip_proto_exists;
   reg                   preprocess_fifo_wr_en;
   reg                   preprocess_fifo_rd_en;

   reg                   pkt_decapsulated;
   reg                   pkt_untouched;
   reg                   pkt_count;
   wire [31:0]           decap_enable_reg;
   wire [31:0]           ip_proto_reg;

   reg [NUM_PREPROCESS_STATES-1:0] preprocess_state, preprocess_state_nxt;

   reg [NUM_PROCESS_STATES-1:0]    process_state_nxt, process_state;
   reg                             out_wr_nxt;

   reg [log2(CROP_LENGTH)-1:0]     count_nxt, count;

   reg [CTRL_WIDTH-1:0]            input_fifo_ctrl_int_nxt, input_fifo_ctrl_int;
   reg [DATA_WIDTH-1:0]            input_fifo_data_int_nxt, input_fifo_data_int;

   reg [CTRL_WIDTH-1:0]            out_ctrl_nxt;
   reg [DATA_WIDTH-1:0]            out_data_nxt;

   reg [15:0]                      src_port_decoded;
   reg                             src_port_rewrite;
   wire                            src_port_rewrite_dout;
   reg [15:0]                      src_port_held;
   reg [15:0]                      src_port_held_nxt;

   //----------------------- Modules ---------------------------------

   fallthrough_small_fifo
     #(.WIDTH            (DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS   (3)) input_fifo
       (
        .din             ({in_ctrl, in_data}),
        .wr_en           (in_wr),

        .rd_en           (input_fifo_rd_en),

        .dout            ({input_fifo_ctrl, input_fifo_data}),
        .full            (),
        .nearly_full     (input_fifo_almost_full),
        .empty           (input_fifo_empty),

        .reset           (reset),
        .clk             (clk)
        );

   fallthrough_small_fifo
     #(.WIDTH            (2),
       .MAX_DEPTH_BITS   (2)) preprocess_fifo
       (
        .din             ({src_port_rewrite, ip_proto_exists}),
        .wr_en           (preprocess_fifo_wr_en),

        .rd_en           (preprocess_fifo_rd_en),

        .dout            ({src_port_rewrite_dout, ip_proto_exists_dout}),
        .full            (),
        .nearly_full     (),
        .empty           (preprocess_fifo_empty),

        .reset           (reset),
        .clk             (clk)
        );

   generic_regs
     #( .UDP_REG_SRC_WIDTH     (UDP_REG_SRC_WIDTH),
        .TAG                   (`DECAP_BLOCK_ADDR),
        .REG_ADDR_WIDTH        (`DECAP_REG_ADDR_WIDTH),
        .NUM_COUNTERS          (3),
        .NUM_SOFTWARE_REGS     (2),
        .NUM_HARDWARE_REGS     (0),
        .COUNTER_INPUT_WIDTH   (1)) generic_regs
       (
        .reg_req_in            (reg_req_in),
        .reg_ack_in            (reg_ack_in),
        .reg_rd_wr_L_in        (reg_rd_wr_L_in),
        .reg_addr_in           (reg_addr_in),
        .reg_data_in           (reg_data_in),
        .reg_src_in            (reg_src_in),

        .reg_req_out           (reg_req_out),
        .reg_ack_out           (reg_ack_out),
        .reg_rd_wr_L_out       (reg_rd_wr_L_out),
        .reg_addr_out          (reg_addr_out),
        .reg_data_out          (reg_data_out),
        .reg_src_out           (reg_src_out),

        // --- counters interface
        .counter_updates       ({pkt_decapsulated, pkt_untouched, pkt_count}),
        .counter_decrement     (3'b0),

        // --- SW regs interface
        .software_regs         ({ip_proto_reg, decap_enable_reg}),

        // --- HW regs interface
        .hardware_regs         (),

        .clk                   (clk),
        .reset                 (reset));

   //------------------------ Logic ----------------------------------

   assign in_rdy = !input_fifo_almost_full;
   assign enable_decap = |(decap_enable_reg[15:0] & src_port_decoded) &&
            src_port_held[15:4] == 'h0;

   /* decode source port */
   always @(*) begin
      src_port_decoded = 0;
      src_port_decoded[src_port_held[3:0]] = 1'b1;
   end

   /******************* Preprocessor ****************/

   /* This state machine (preprocessor) checks fo the existence of
    * the IP protocol ENCAP_IP_PROT */
   always @(*) begin
      preprocess_state_nxt    = preprocess_state;
      preprocess_fifo_wr_en   = 0;
      ip_proto_exists         = 0;
      src_port_held_nxt       = src_port_held;
      src_port_rewrite        = 0;
      case (preprocess_state)
         PREPROCESS_SKIP_MODULE_HDRS: begin
	    if (in_wr && in_ctrl == `IO_QUEUE_STAGE_NUM)
               src_port_held_nxt = in_data[`IOQ_SRC_PORT_POS + 15:`IOQ_SRC_PORT_POS];
            if (in_wr && in_ctrl == 0) begin
               if(enable_decap) begin
                  preprocess_state_nxt   = PREPROCESS_CHECK_ETHERTYPE;
               end
               else begin
                  preprocess_state_nxt   = PREPROCESS_WAIT_EOP;
                  preprocess_fifo_wr_en  = 1'b1;
               end
            end
         end

         PREPROCESS_CHECK_ETHERTYPE: begin
            if (in_wr) begin
               if(in_data[ETH_TYPE_POS + 15:ETH_TYPE_POS] == ETH_TYPE_IP) begin
                  preprocess_state_nxt   = PREPROCESS_CHECK_IP_PROTO;
               end
               else begin
                  preprocess_state_nxt   = PREPROCESS_WAIT_EOP;
                  src_port_rewrite       = 1'b1;
                  preprocess_fifo_wr_en  = 1'b1;
               end
            end // if (in_wr)
         end // case: CHECK_ETHERTYPE

         PREPROCESS_CHECK_IP_PROTO: begin
            if (in_wr) begin
               preprocess_state_nxt   = PREPROCESS_WAIT_EOP;
               if(in_data[IP_PROTO_POS + 7:IP_PROTO_POS] == ip_proto_reg[7:0]) begin
                  ip_proto_exists         = 1'b1;
                  preprocess_fifo_wr_en   = 1'b1;
               end
               else begin
                  src_port_rewrite        = 1'b1;
                  ip_proto_exists         = 1'b0;
                  preprocess_fifo_wr_en   = 1'b1;
               end
            end // if (in_wr)
         end // case: CHECK_IP_PROTO

         PREPROCESS_WAIT_EOP: begin
            if(in_wr && in_ctrl != 0) begin
               preprocess_state_nxt   = PREPROCESS_SKIP_MODULE_HDRS;
            end
         end
      endcase // case(preprocess_state)
   end // always @ (*)


   always @(posedge clk) begin
      if(reset) begin
         preprocess_state    <= PREPROCESS_SKIP_MODULE_HDRS;
      end
      else begin
         preprocess_state    <= preprocess_state_nxt;
      end // else: !if(reset)
      src_port_held          <= src_port_held_nxt;
   end // always @ (posedge clk)



          /******************* Processor ****************/

   /* This state machine (processor) will crop the first
    * CROP_LENGTH words of the packet if ENCAP_IP_PROT is found */
   always @(*) begin
      process_state_nxt       = process_state;
      preprocess_fifo_rd_en   = 0;
      input_fifo_rd_en        = 0;
      out_wr_nxt              = 0;

      pkt_untouched           = 0;
      pkt_decapsulated        = 0;
      pkt_count               = 0;

      count_nxt               = count;
      out_ctrl_nxt            = input_fifo_ctrl;
      out_data_nxt            = input_fifo_data;

      input_fifo_ctrl_int_nxt    = input_fifo_ctrl_int;
      input_fifo_data_int_nxt    = input_fifo_data_int;
      
      case (process_state)

         PROCESS_WAIT_PREPROCESS: begin
            count_nxt   = 1;
            if(!preprocess_fifo_empty && !input_fifo_empty && out_rdy) begin
               /* fix the lengths in the module headers */
               if(input_fifo_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  /* if we need to crop */
                  if(ip_proto_exists_dout) begin
                     out_data_nxt[`IOQ_BYTE_LEN_POS + 12:`IOQ_BYTE_LEN_POS]   = input_fifo_data[`IOQ_BYTE_LEN_POS + 15:`IOQ_BYTE_LEN_POS] - 38;
                     out_data_nxt[`IOQ_WORD_LEN_POS + 9:`IOQ_WORD_LEN_POS]    = ceildiv((out_data_nxt[`IOQ_BYTE_LEN_POS + 12:`IOQ_BYTE_LEN_POS]),8);
                  end

                  out_data_nxt[`IOQ_SRC_PORT_POS + 15:`IOQ_SRC_PORT_POS]   = input_fifo_data[`IOQ_SRC_PORT_POS + 15:`IOQ_SRC_PORT_POS] + {12'b0, src_port_rewrite_dout, 3'b0};
                  out_wr_nxt                                               = 1'b1;
                  input_fifo_rd_en                                         = 1'b1;
               end
               /* if packet has started then cut out the first word */
               else if (input_fifo_ctrl == 0) begin
                  if(ip_proto_exists_dout) begin
                     process_state_nxt       = PROCESS_CROP_PACKET;
                     pkt_decapsulated        = 1'b1;
                  end
                  else begin
                     process_state_nxt       = PROCESS_WAIT_EOP_NORM;
                     pkt_untouched           = 1'b1;
                     out_wr_nxt              = 1'b1;
                  end
                  input_fifo_rd_en        = 1'b1;
                  preprocess_fifo_rd_en   = 1'b1;
               end
               /* otherwise wait till packet starts and pass through the module headers */
               else begin
                  out_wr_nxt         = 1'b1;
                  input_fifo_rd_en   = 1'b1;
               end
            end
         end // case: PROCESS_WAIT_PREPROCESS

         /* remove words */
         PROCESS_CROP_PACKET: begin
            if(!input_fifo_empty) begin
               count_nxt          = count + 1'b1;
               input_fifo_rd_en   = 1'b1;
               if(count > CROP_LENGTH-2) begin
                  input_fifo_ctrl_int_nxt = input_fifo_ctrl;
                  input_fifo_data_int_nxt = input_fifo_data;
                  process_state_nxt = PROCESS_WAIT_EOP;
               end
            end
         end // case: PROCESS_CROP_PACKET

         /* send the rest of the packet */
         PROCESS_WAIT_EOP: begin
            if(!input_fifo_empty && out_rdy) begin
               input_fifo_rd_en   = 1'b1;
               out_wr_nxt         = 1'b1;

               input_fifo_ctrl_int_nxt = input_fifo_ctrl;
               input_fifo_data_int_nxt = input_fifo_data;

               out_ctrl_nxt = {input_fifo_ctrl_int[1:0], input_fifo_ctrl[7:2]};
               out_data_nxt = {input_fifo_data_int[15:0], input_fifo_data[63:16]};

               /* if end-of-pkt reached */
               if(input_fifo_ctrl[7:2] != 0) begin
                  pkt_count           = 1'b1;
                  process_state_nxt   = PROCESS_WAIT_PREPROCESS;
               end
               else if(input_fifo_ctrl[1:0] != 0) begin
                  process_state_nxt   = PROCESS_SEND_LAST_WORD;
               end
            end
         end // case: PROCESS_WAIT_EOP

         /* send the last word of the packet */
         PROCESS_SEND_LAST_WORD: begin
            if(out_rdy) begin
               out_wr_nxt         = 1'b1;

               out_ctrl_nxt = {input_fifo_ctrl_int[1:0], 6'b0};
               out_data_nxt = {input_fifo_data_int[15:0], 48'b0};

               pkt_count           = 1'b1;
               process_state_nxt   = PROCESS_WAIT_PREPROCESS;
            end
         end // case: PROCESS_SEND_LAST_WORD

         /* send the rest of the normal packet */
         PROCESS_WAIT_EOP_NORM: begin
            if(!input_fifo_empty && out_rdy) begin
               input_fifo_rd_en   = 1'b1;
               out_wr_nxt         = 1'b1;

               /* if end-of-pkt reached */
               if(input_fifo_ctrl != 0) begin
                  pkt_count           = 1'b1;
                  process_state_nxt   = PROCESS_WAIT_PREPROCESS;
               end
            end
         end // case: PROCESS_WAIT_EOP_NORM

         /* send the last word of the packet */
      endcase // case(process_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         process_state    <= PROCESS_WAIT_PREPROCESS;
         out_wr           <= 0;
         out_data         <= 0;
         out_ctrl         <= 1;
         count            <= 1;
         input_fifo_ctrl_int <= 1;
         input_fifo_data_int <= 0;
      end
      else begin
         process_state    <= process_state_nxt;
         out_wr           <= out_wr_nxt;
         out_data         <= out_data_nxt;
         out_ctrl         <= out_ctrl_nxt;
         count            <= count_nxt;
         input_fifo_ctrl_int <= input_fifo_ctrl_int_nxt;
         input_fifo_data_int <= input_fifo_data_int_nxt;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // decap



