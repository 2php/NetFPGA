///////////////////////////////////////////////////////////////////////////////
// $Id$
//
// Module: vlan_remover.v v3
// Project: NF2.1 VLAN tag handler
// Author: Jad Naous <jnaous@stanford.edu> / Tatsuya Yabe <tyabe@stanford.edu>
// Description: This module is for the designs/environments where packets for
//              actual NetFPGA ports are aggregated to one physical NetFPGA
//              port.
//              This module can be used as a wrapper module for actual designs
//              with vlan_adder(v2) module and output_aggregator module.
//              This module expects all the incoming packets have VLAN tags
//              corresponding to desired NetFPGA 'MAC' ports. 
//
//              It removes VLAN tag if existing and puts it in a module header.
//              If the source port of an incoming packet is CPU port, this
//              module won't touch the packet and forward it as is.
//              If VLAN tag doesn't exist, or if the tag value is different
//              from expected ones (register values), the packet will be dropped.
//              Recalculate byte_count and word_count in a module header when
//              VLAN tag is found in a packet.
//              Also, depending on the VLAN tag value, it rewrites SRCPORT field
//              of IOQ header.
//              VLAN tagging module header will be inserted right AFTER
//              the IOQ header.
// Note: This module works with vlan_adder(v2) module and outport_aggregator.
///////////////////////////////////////////////////////////////////////////////

  module vlan_remover
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output                             in_rdy,

    // --- Interface to the next stage
    output reg [DATA_WIDTH-1:0]        out_data,
    output reg [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                         out_wr,
    input                              out_rdy,

    // --- Interface to registers
    input                              reg_req_in,
    input                              reg_ack_in,
    input                              reg_rd_wr_L_in,
    input [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
    input [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
    input [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,
    
    output                             reg_req_out,
    output                             reg_ack_out,
    output                             reg_rd_wr_L_out,
    output [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
    output [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
    output [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

    // --- Misc
    input                              reset,
    input                              clk
   );

   `CEILDIV_FUNC

   //------------------ Internal Parameters --------------------------
   localparam NUM_PRE_STATES         = 5;
   localparam FIND_HDR               = 1,
              SKIP_HDRS              = 2,
              CHECK_VLAN             = 4,
              GET_VLAN_TAG           = 8,
              WAIT_EOP               = 16;
   
   localparam NUM_STATES             = 7;
   localparam WAIT_PREPROCESS        = 1,
              ADD_MODULE_HEADER      = 2,
              WRITE_MODULE_HEADERS   = 4,
              REMOVE_VLAN            = 8,
              WRITE_MODIFIED_PKT     = 16,
              WRITE_LAST_WORD        = 32,
              HANDLE_UNMODIFIED_PKT  = 64;

   localparam NUM_POST_STATES        = 4;
   localparam POST_WAIT_FOR_INPUT    = 1,
              POST_WRITE_IO_HEADER   = 2,
              POST_WRITE_TAG         = 4,
              POST_WRITE_PACKET      = 8;

   //---------------------- Wires/Regs -------------------------------
   wire [DATA_WIDTH-1:0] fifo_data_out;
   wire [CTRL_WIDTH-1:0] fifo_ctrl_out;

   reg [NUM_PRE_STATES-1:0] preprocess_state;
   reg [15:0]               vlan_tag;
   reg                      tag_vld, tag_found;
   reg                      cpuport_found;
   reg                      snd_pkt, snd_pkt_nxt;

   reg [NUM_STATES-1:0]  process_state, process_state_nxt;
   reg                   fifo_rd_en;
   wire                  int_rdy;
   reg                   int_wr, int_wr_nxt;
   reg [DATA_WIDTH-1:0]  int_data, int_data_nxt;
   reg [CTRL_WIDTH-1:0]  int_ctrl, int_ctrl_nxt;
   reg [DATA_WIDTH-1:0]  fifo_data_out_d1;
   reg [CTRL_WIDTH-1:0]  fifo_ctrl_out_d1;

   reg [NUM_POST_STATES-1:0]  post_state, post_state_nxt;
   reg                        out_wr_nxt;
   reg [DATA_WIDTH-1:0]       out_data_nxt;
   reg [CTRL_WIDTH-1:0]       out_ctrl_nxt;
   reg [DATA_WIDTH-1:0]       out_data_d1, out_data_d1_nxt;

   reg                        int_fifo_rd_en;
   wire [DATA_WIDTH-1:0]      int_fifo_data;
   wire [CTRL_WIDTH-1:0]      int_fifo_ctrl;
   reg                        int_fifo_ctrl_prev_0;
   
   wire [`CPCI_NF2_DATA_WIDTH-1:0] inport_vlan_reg[3:0];
   wire [11:0] inport_0_vlan_tag;
   wire [11:0] inport_1_vlan_tag;
   wire [11:0] inport_2_vlan_tag;
   wire [11:0] inport_3_vlan_tag;

   wire        vid_good;
   reg [15:0]  new_srcport, new_srcport_nxt;

   //----------------------- Modules ---------------------------------
   fallthrough_small_fifo 
     #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(3))
     input_fifo
       (.din           ({in_ctrl, in_data}),  // Data in
        .wr_en         (in_wr),               // Write enable
        .rd_en         (fifo_rd_en),          // Read the next word 
        .dout          ({fifo_ctrl_out, fifo_data_out}),
        .full          (),
        .prog_full     (),
        .nearly_full   (fifo_nearly_full),
        .empty         (fifo_empty),
        .reset         (reset),
        .clk           (clk)
        );

   fallthrough_small_fifo
     #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(3))
     internal_fifo
       (.din           ({int_ctrl, int_data}),  // Data in
        .wr_en         (int_wr),                // Write enable
        .rd_en         (int_fifo_rd_en),        // Read the next word
        .dout          ({int_fifo_ctrl, int_fifo_data}),
        .prog_full     (),
        .full          (),
        .nearly_full   (int_fifo_nearly_full),
        .empty         (int_fifo_empty),
        .reset         (reset),
        .clk           (clk)
        );

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (`VLAN_REMOVER_BLOCK_ADDR),
       .REG_ADDR_WIDTH (`VLAN_REMOVER_REG_ADDR_WIDTH),
       .NUM_COUNTERS (0),
       .NUM_SOFTWARE_REGS (4),
       .NUM_HARDWARE_REGS (0)
       )
   generic_regs
     (
      .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),
                         
      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),
                         
      // --- counters interface
      .counter_updates   (),
      .counter_decrement (),

      // --- SW regs interface
      .software_regs     ({inport_vlan_reg[3],
                           inport_vlan_reg[2],
                           inport_vlan_reg[1],
                           inport_vlan_reg[0]}),
                         
      // --- HW regs interface
      .hardware_regs     (),

      .clk               (clk),
      .reset             (reset));


   //------------------------ Logic ----------------------------------

   assign inport_3_vlan_tag = inport_vlan_reg[3][11:0];
   assign inport_2_vlan_tag = inport_vlan_reg[2][11:0];
   assign inport_1_vlan_tag = inport_vlan_reg[1][11:0];
   assign inport_0_vlan_tag = inport_vlan_reg[0][11:0];

   assign in_rdy = !fifo_nearly_full;

   /* Preprocess
    * This state machine checks if there is a VLAN id and gets it */

   always @(posedge clk) begin
      if(reset) begin
         preprocess_state <= FIND_HDR;
         vlan_tag         <= 0;
         tag_vld          <= 0;
         tag_found        <= 0;
         cpuport_found    <= 0;
      end
      else begin
         case (preprocess_state)
            FIND_HDR: begin
               if (in_wr && in_ctrl==`IO_QUEUE_STAGE_NUM) begin
                  if((in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS] == 1) ||
                     (in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS] == 3) ||
                     (in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS] == 5) ||
                     (in_data[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS] == 7)) begin
                     cpuport_found <= 1;
                  end
                  else begin
                     cpuport_found <= 0;
                  end
                  preprocess_state <= SKIP_HDRS;
               end
            end

            SKIP_HDRS: begin
               if (in_wr && in_ctrl==0) begin
                  preprocess_state <= CHECK_VLAN;
               end
            end
            
            CHECK_VLAN: begin
               if(in_wr) begin
                  if(in_data[31:16] == `VLAN_REMOVER_VLAN_ETHERTYPE) begin
                     vlan_tag            <= in_data[15:0];
                     preprocess_state    <= GET_VLAN_TAG;
                  end
                  else begin
                     preprocess_state    <= WAIT_EOP;
                     tag_vld             <= 1'b1;
                     tag_found           <= 1'b0;
                  end
               end
            end
            
            GET_VLAN_TAG: begin
               if(in_wr) begin
                  tag_vld             <= 1'b1;
                  tag_found           <= 1'b1;
                  preprocess_state    <= WAIT_EOP;
               end
            end

            WAIT_EOP: begin
               if(in_wr && in_ctrl != 0) begin
                  tag_vld             <= 0;
                  preprocess_state    <= FIND_HDR;
               end
            end
         endcase // case(preprocess_state)
      end // else: !if(reset)
   end // always @ (posedge clk)


   /* VLAN remove process.
    * This state machine will remove the VLAN info from the pkt
    * and put it to module header. */

   assign vid_good = ((vlan_tag[11:0] == inport_0_vlan_tag) ||
                      (vlan_tag[11:0] == inport_1_vlan_tag) || 
                      (vlan_tag[11:0] == inport_2_vlan_tag) || 
                      (vlan_tag[11:0] == inport_3_vlan_tag)); 

   always @(*) begin
      process_state_nxt   = process_state;
      fifo_rd_en          = 0;
      int_wr_nxt          = 0;
      int_data_nxt        = fifo_data_out;
      int_ctrl_nxt        = fifo_ctrl_out;
      new_srcport_nxt     = new_srcport;
      snd_pkt_nxt         = snd_pkt;
      
      case (process_state)
         WAIT_PREPROCESS: begin
            if(tag_vld) begin
               if(cpuport_found) begin
                  snd_pkt_nxt = 1;
                  process_state_nxt = HANDLE_UNMODIFIED_PKT;
               end
               else if(tag_found && vid_good) begin
                  snd_pkt_nxt = 0;
                  process_state_nxt = ADD_MODULE_HEADER;
               end
               else begin
                  snd_pkt_nxt = 0;
                  process_state_nxt = HANDLE_UNMODIFIED_PKT;
               end
            end // if (tag_vld)
         end // case: WAIT_PREPROCESS

         ADD_MODULE_HEADER: begin
            if(int_rdy) begin
               fifo_rd_en          = 1;
               int_wr_nxt          = 1;
               int_data_nxt        = {{(DATA_WIDTH-16){1'b0}}, vlan_tag};
               int_ctrl_nxt        = `VLAN_REMOVER_VLAN_CTRL_WORD;

               if(vlan_tag[11:0] == inport_0_vlan_tag) begin
                  new_srcport_nxt = 0; // MAC_PORT 0
               end
               else if(vlan_tag[11:0] == inport_1_vlan_tag) begin
                  new_srcport_nxt = 2; // MAC_PORT 1
               end
               else if(vlan_tag[11:0] == inport_2_vlan_tag) begin
                  new_srcport_nxt = 4; // MAC_PORT 2
               end
               else if(vlan_tag[11:0] == inport_3_vlan_tag) begin
                  new_srcport_nxt = 6; // MAC_PORT 3
               end

               process_state_nxt   = WRITE_MODULE_HEADERS;
            end
         end

         WRITE_MODULE_HEADERS: begin
            if(int_rdy) begin
               fifo_rd_en     = 1;
               int_wr_nxt     = 1;
               int_data_nxt   = fifo_data_out_d1;
               int_ctrl_nxt   = fifo_ctrl_out_d1;
               if(fifo_ctrl_out_d1 == `IO_QUEUE_STAGE_NUM) begin
                  /* Decrement byte-count and word-count in IOQ since we will remove vlan tags
                   * then add 8bytes(1word) because we add one module header */
                  int_data_nxt[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS]
                     = fifo_data_out_d1[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS] - 4 + 8;
                  int_data_nxt[`IOQ_WORD_LEN_POS+15:`IOQ_WORD_LEN_POS]
                     = ceildiv((fifo_data_out_d1[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS] - 4), 8) + 1;
                  /* Overrwrite source port field depending on VLAN VID */
                  int_data_nxt[`IOQ_SRC_PORT_POS+15:`IOQ_SRC_PORT_POS] = new_srcport;
               end
               if(fifo_ctrl_out_d1 == 0) begin
                  process_state_nxt   = REMOVE_VLAN;
               end
            end
         end // case: WRITE_MODULE_HEADERS

         REMOVE_VLAN: begin
            if(int_rdy) begin
               process_state_nxt   = WRITE_MODIFIED_PKT;
               fifo_rd_en          = 1;
               int_wr_nxt          = 1;
               int_data_nxt        = {fifo_data_out_d1[63:32], fifo_data_out[63:32]};
               int_ctrl_nxt        = fifo_ctrl_out_d1;
            end
         end // case: REMOVE_VLAN

         WRITE_MODIFIED_PKT: begin
            if(int_rdy && !fifo_empty) begin
               fifo_rd_en          = 1;
               int_wr_nxt          = 1;
               int_data_nxt        = {fifo_data_out_d1[31:0], fifo_data_out[63:32]};
               int_ctrl_nxt        = fifo_ctrl_out_d1;
               if(fifo_ctrl_out != 0) begin
                  if(fifo_ctrl_out[7:4] != 0) begin
                     int_ctrl_nxt = (fifo_ctrl_out >> 4);
                  end
                  /* We will write one more word in any case */
                  process_state_nxt = WRITE_LAST_WORD;
               end
            end
         end // case: WRITE_MODIFIED_PKT

         WRITE_LAST_WORD: begin
            if(int_rdy) begin
               int_wr_nxt          = 1;
               int_data_nxt        = {fifo_data_out_d1[31:0], 32'h600d_f00d};
               if(fifo_ctrl_out_d1[3:0] != 0) begin
                  int_ctrl_nxt = (fifo_ctrl_out_d1 << 4);
               end
               else begin
                  /* The data on this stage doesn't have 'actual' contents.
                   * Put no-meaning value here. */
                  int_ctrl_nxt = 1;
               end
               if(tag_vld) begin
                  if (cpuport_found) begin
                     snd_pkt_nxt = 1;
                     process_state_nxt = HANDLE_UNMODIFIED_PKT;
                  end
                  else if (tag_found && vid_good) begin
                     snd_pkt_nxt = 0;
                     process_state_nxt = ADD_MODULE_HEADER;
                  end
                  else begin
                     snd_pkt_nxt = 0;
                     process_state_nxt = HANDLE_UNMODIFIED_PKT;
                  end
               end
               else begin
                  process_state_nxt = WAIT_PREPROCESS;
               end
            end // if (out_rdy)
         end // case: WRITE_LAST_WORD

         HANDLE_UNMODIFIED_PKT: begin
            if(int_rdy && !fifo_empty) begin
               if(fifo_ctrl_out_d1 == 0 && fifo_ctrl_out != 0) begin
                  if(tag_vld) begin
                     if (cpuport_found) begin
                        snd_pkt_nxt = 1;
                        process_state_nxt = HANDLE_UNMODIFIED_PKT;
                     end
                     else if (tag_found && vid_good) begin
                        snd_pkt_nxt = 0;
                        process_state_nxt = ADD_MODULE_HEADER;
                     end
                     else begin
                        snd_pkt_nxt = 0;
                        process_state_nxt = HANDLE_UNMODIFIED_PKT;
                     end
                  end
                  else begin
                     process_state_nxt = WAIT_PREPROCESS;
                  end
               end
               fifo_rd_en          = 1;
               int_data_nxt        = fifo_data_out;
               int_ctrl_nxt        = fifo_ctrl_out;
               if(snd_pkt == 1) begin
                  int_wr_nxt = 1;
               end
               else begin
                  int_wr_nxt = 0; // DROP untagged packet
               end
            end
         end // case: HANDLE_UNMODIFIED_PKT

      endcase // case(process_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         process_state    <= WAIT_PREPROCESS;
         int_wr           <= 0;
         int_data         <= 0;
         int_ctrl         <= 1;
         fifo_data_out_d1 <= 0;
         fifo_ctrl_out_d1 <= 1;
         new_srcport      <= 0;
         snd_pkt          <= 0;
      end
      else begin
         process_state    <= process_state_nxt;
         int_wr           <= int_wr_nxt;
         int_data         <= int_data_nxt;
         int_ctrl         <= int_ctrl_nxt;
         new_srcport      <= new_srcport_nxt;
         snd_pkt          <= snd_pkt_nxt;
         if(fifo_rd_en) begin
            fifo_data_out_d1 <= fifo_data_out;
            fifo_ctrl_out_d1 <= fifo_ctrl_out;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)
               

   /* Postprocess
    * Swap the order between IOQ header and VLAN tagging header
    * so that IOQ header comes first. */

   assign int_rdy = !int_fifo_nearly_full;

   always @(*) begin
      post_state_nxt  = post_state;
      int_fifo_rd_en  = 0;
      out_wr_nxt      = 0;
      out_data_nxt    = int_fifo_data;
      out_data_d1_nxt = out_data_d1;
      out_ctrl_nxt    = int_fifo_ctrl;

      case (post_state)

         /* Wait for VLAN tagging header and store vlan_tag.
          * Packets without VLAN tag will be passed through. */
         POST_WAIT_FOR_INPUT: begin
            if(out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en  = 1'b1;
               out_wr_nxt      = 1'b1;
               out_data_nxt    = int_fifo_data;
               out_data_d1_nxt = int_fifo_data;
               out_ctrl_nxt    = int_fifo_ctrl;
               if(int_fifo_ctrl == `VLAN_REMOVER_VLAN_CTRL_WORD) begin
                  out_wr_nxt     = 1'b0;
                  post_state_nxt = POST_WRITE_IO_HEADER;
               end
            end // if (out_rdy && !fifo_empty)
         end // case: POST_WAIT_FOR_INPUT

         /* Put IO HEADER before vlan tagging module header */
         POST_WRITE_IO_HEADER: begin
            if(out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en  = 1'b1;
               out_wr_nxt      = 1'b1;
               out_data_nxt    = int_fifo_data;
               out_ctrl_nxt    = int_fifo_ctrl;
               if(int_fifo_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  post_state_nxt    = POST_WRITE_TAG;
               end
            end // if (out_rdy && !int_fifo_empty)
         end // case: POST_WRITE_IO_HEADER

         /* Put vlan tag next to IOQ header */
         POST_WRITE_TAG: begin
            if(out_rdy) begin
               out_wr_nxt      = 1'b1;
               out_data_nxt    = out_data_d1;
               out_ctrl_nxt    = `VLAN_REMOVER_VLAN_CTRL_WORD;
               post_state_nxt  = POST_WRITE_PACKET;
            end // if (out_rdy && !fifo_empty)
         end // case: POST_WRITE_TAG

         /* Write the rest of the packet data */
         POST_WRITE_PACKET: begin
            if(out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en  = 1'b1;
               out_wr_nxt      = 1'b1;
               out_data_nxt    = int_fifo_data;
               out_ctrl_nxt    = int_fifo_ctrl;
               if(int_fifo_ctrl !=0 && int_fifo_ctrl_prev_0 == 1) begin // eop
                  post_state_nxt = POST_WAIT_FOR_INPUT;
               end
            end // if (out_rdy)
         end // case: POST_WRITE_PACKET

      endcase // case(post_state)
   end // always @ (*)

   always @(posedge clk) begin
      if (reset) begin
         out_wr               <= 0;
         out_data             <= 0;
         out_data_d1          <= 0;
         out_ctrl             <= 1;
         post_state           <= POST_WAIT_FOR_INPUT;
         int_fifo_ctrl_prev_0 <= 0;
      end
      else begin
         out_wr           <= out_wr_nxt;
         out_data         <= out_data_nxt;
         out_data_d1      <= out_data_d1_nxt;
         out_ctrl         <= out_ctrl_nxt;
         post_state       <= post_state_nxt;
         if(int_fifo_rd_en) int_fifo_ctrl_prev_0 <= int_fifo_ctrl == 0;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // vlan_remover
