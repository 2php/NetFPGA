/******************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 * filename:  vlan_adder.v V2
 * Project :  VLAN tag handler
 * Author:    Tatsuya Yabe <tyabe@stanford.edu>
 * Summary:   Add/modify/remove VLAN tag.
 *            This module assumes VLAN tag resides in
 *            a module header (if exists) right after
 *            IOQ header.
 *            In this module, it will be put back into
 *            a packet after add/mod/remove is done.
 *            This module handles vlan tags following
 *            the resister value below.
 *            When the regsister value is:
 *            0x0000: VLAN_THROUGH:
 *               -doesn't touch anything.
 *                If the packet has vlan tag, it will
 *                be passed through. If not, ... it
 *                will also be passed through.
 *            0xffff: VLAN_REMOVE:
 *               -remove vlan tag.
 *            others: VLAN_ADD_REMOVE:
 *               -if a packet already has vlan tag on
 *                its module header, changes it into
 *                the value of the register.
 *               -if a packet doesn't have vlan tag,
 *                add the value of the register.
 * Note:      This module works with vlan_remover(v2)
 *            module.
 ******************************************************/

`timescale 1ns/1ps

module vlan_adder
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2,
    parameter VLAN_ADDER_BLOCK_TAG = `VLAN_ADDER_0_BLOCK_ADDR)
   (// --- data path interface
    output reg [DATA_WIDTH-1:0]        out_data,
    output reg [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                         out_wr,
    input                              out_rdy,

    input [DATA_WIDTH-1:0]             in_data,
    input [CTRL_WIDTH-1:0]             in_ctrl,
    input                              in_wr,
    output                             in_rdy,

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
    input                              clk,
    input                              reset);

   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_STATES              = 4;
   localparam WAIT_FOR_INPUT          = 1,
              FIND_VLAN_HDR           = 2,
              WRITE_STORED_DATA       = 4,
              WRITE_PACKET            = 8;
   localparam VLAN_THROUGH            = 0;
   localparam VLAN_REMOVE             = 16'hFFFF; 

   localparam NUM_POST_STATES         = 5;
   localparam POST_FIND_VLAN_HDR      = 1,
              POST_WAIT_SOP           = 2,
              POST_ADD_VLAN           = 4,
              POST_WRITE_MODIFIED_PKT = 8,
              POST_WRITE_LAST_PKT     = 16;

   //------------------------ Wires/Regs -----------------------------

   reg [NUM_STATES-1:0]            state, state_nxt;
   reg                             int_wr, int_wr_nxt;
   reg [DATA_WIDTH-1:0]            int_data, int_data_nxt;
   reg [CTRL_WIDTH-1:0]            int_ctrl, int_ctrl_nxt;
   reg                             vlan_proc_done, vlan_proc_done_nxt;
   reg [DATA_WIDTH-1:0]            int_data_d1, int_data_d1_nxt;
   reg [CTRL_WIDTH-1:0]            int_ctrl_d1, int_ctrl_d1_nxt;
   wire [`CPCI_NF2_DATA_WIDTH-1:0] vlan_reg;
   wire [15:0]                     vlan_value;

   reg                             fifo_rd_en;
   wire [DATA_WIDTH-1:0]           fifo_data;
   wire [CTRL_WIDTH-1:0]           fifo_ctrl;
   reg                             fifo_ctrl_prev_0;

   wire                       int_rdy;

   wire [DATA_WIDTH-1:0]      int_fifo_data_out;
   wire [CTRL_WIDTH-1:0]      int_fifo_ctrl_out;

   reg [15:0]                 vlan_tag, vlan_tag_nxt;
   reg [31:0]                 out_data_d1, out_data_d1_nxt;
   reg [7:0]                  out_ctrl_d1, out_ctrl_d1_nxt; 

   reg [NUM_POST_STATES-1:0]  post_state, post_state_nxt;
   reg                        int_fifo_rd_en;
   reg                        out_wr_nxt;
   reg [DATA_WIDTH-1:0]       out_data_nxt;
   reg [CTRL_WIDTH-1:0]       out_ctrl_nxt;

   //------------------------- Modules -------------------------------

   /* each pkt can have up to:
    * - 18 bytes of Eth header including VLAN
    * - 15*4 = 60 bytes IP header including max number of options
    * - at least 4 bytes of tcp/udp header
    * total = 82 bytes approx 4 bits (8 bytes x 2^4 = 128 bytes)
    */
   fallthrough_small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(4))
      input_fifo
        (.din           ({in_ctrl, in_data}),  // Data in
         .wr_en         (in_wr),               // Write enable
         .rd_en         (fifo_rd_en),          // Read the next word 
         .dout          ({fifo_ctrl, fifo_data}),
         .prog_full     (),
         .full          (),
         .nearly_full   (fifo_nearly_full),
         .empty         (fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(3))
     internal_fifo
       (.din           ({int_ctrl, int_data}), // Data in
        .wr_en         (int_wr),               // Write enable
        .rd_en         (int_fifo_rd_en),       // Read the next word 
        .dout          ({int_fifo_ctrl_out, int_fifo_data_out}),
        .full          (),
        .nearly_full   (int_fifo_nearly_full),
        .empty         (int_fifo_empty),
        .reset         (reset),
        .clk           (clk)
        );

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (VLAN_ADDER_BLOCK_TAG),
       .REG_ADDR_WIDTH (`VLAN_ADDER_REG_ADDR_WIDTH),
       .NUM_COUNTERS (0),
       .NUM_SOFTWARE_REGS (1),
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
      .software_regs     (vlan_reg),
                         
      // --- HW regs interface
      .hardware_regs     (),

      .clk               (clk),
      .reset             (reset));

   //-------------------------- Logic --------------------------------

   assign in_rdy     = !fifo_nearly_full;
   assign vlan_value = vlan_reg[15:0];

   /* This state machine checks vlan-tagging operation mode by looking
    * into the register value, then add/modify/remove vlan tag on the
    * module header.
    * The tag inside the module header for each packet will be put back
    * into the packet in the postprocess of this vlan_adder module. */
   always @(*) begin
      state_nxt            = state;
      fifo_rd_en           = 0;
      int_wr_nxt           = 0;
      int_data_nxt         = fifo_data;
      int_data_d1_nxt      = int_data_d1;
      int_ctrl_d1_nxt      = int_ctrl_d1;
      int_ctrl_nxt         = int_ctrl;
      vlan_proc_done_nxt   = vlan_proc_done;

      case (state)
         /* Wait for module header */
         WAIT_FOR_INPUT: begin
            if(int_rdy && !fifo_empty) begin
               fifo_rd_en   = 1'b1;
               int_wr_nxt   = 1'b1;
               int_data_nxt = fifo_data;
               int_ctrl_nxt = fifo_ctrl;

               if(fifo_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  int_wr_nxt      = 1'b0;
                  int_data_d1_nxt = fifo_data;
                  int_ctrl_d1_nxt = fifo_ctrl;
                  state_nxt       = FIND_VLAN_HDR;
               end
               // synthesis translate_off
               else if (fifo_ctrl==0 || fifo_empty) begin
                  $display ("%t %m ERROR: Could not find IOQ module header", $time);
                  $stop;
               end
               // synthesis translate_on
            end // if (int_rdy && !fifo_empty)
         end // case: WAIT_FOR_INPUT

         /* Wait for vlan tagging module header and handle it.
          * Assumes vlan header comes right after IOQ header. */
         FIND_VLAN_HDR: begin
            if(int_rdy && !fifo_empty) begin
               fifo_rd_en   = 1'b1;
               int_wr_nxt   = 1'b1;
               int_data_nxt = fifo_data;
               int_ctrl_nxt = fifo_ctrl;

               if(fifo_ctrl == `VLAN_ADDER_VLAN_CTRL_WORD) begin
                  /* Invalidate VLAN tag */
                  if(vlan_value == VLAN_REMOVE) begin
                     int_ctrl_nxt = 8'h01;
                  end
                  else begin
                     /* Replace VLAN tag resided in a module header.
                      * VLAN tag module header comes right after IOQ header */
                     if(vlan_value != VLAN_THROUGH) begin
                        int_data_nxt[15:0] = vlan_value;
                     end
                  end
                  vlan_proc_done_nxt = 1;
               end
               else if(fifo_ctrl == 0) begin
                  /* Add vlan tag if requested.
                   * Stop reading from fifo while writing the tag to
                   * avoid missing the data. */
                  if((vlan_proc_done != 1) &&
                     !((vlan_value == VLAN_REMOVE) || (vlan_value == VLAN_THROUGH))) begin
                     fifo_rd_en         = 1'b0;
                     int_data_nxt       = 0;
                     int_data_nxt[15:0] = vlan_value;
                     int_ctrl_nxt       = `VLAN_ADDER_VLAN_CTRL_WORD;
                  end
                  else begin
                  /* Write IOQ header.
                   * Keep reading from fifo and store it into buffer */
                     int_data_nxt    = int_data_d1;
                     int_ctrl_nxt    = int_ctrl_d1;
                     int_data_d1_nxt = fifo_data;
                     int_ctrl_d1_nxt = fifo_ctrl;
                  end
                  state_nxt = WRITE_STORED_DATA;
               end
            end // if (int_rdy && !fifo_empty)
         end // case: FIND_VLAN_HDR

         /* Put IO HEADER here when vlan tag has been added.
          * Write the first contents when vlan tag has not been added. */
         WRITE_STORED_DATA: begin
            if(int_rdy) begin
               int_wr_nxt   = 1'b1;
               int_data_nxt = int_data_d1;
               int_ctrl_nxt = int_ctrl_d1;
               state_nxt    = WRITE_PACKET;
            end
         end // case: WRITE_STORED_DATA

         /* Write the rest of the module headers and the packet data */
         WRITE_PACKET: begin
            vlan_proc_done_nxt = 0;
            if(int_rdy && !fifo_empty) begin
               fifo_rd_en   = 1'b1;
               int_wr_nxt   = 1'b1;
               int_data_nxt = fifo_data;
               int_ctrl_nxt = fifo_ctrl;
               if(fifo_ctrl != 0 && fifo_ctrl_prev_0 == 1) begin // eop
                  state_nxt = WAIT_FOR_INPUT;
               end
            end // if (int_rdy)
         end // case: WRITE_PACKET

      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if (reset) begin
         int_wr           <= 0;
         int_data         <= 0;
         int_data_d1      <= 0;
         int_ctrl         <= 1;
         int_ctrl_d1      <= 1;
         vlan_proc_done   <= 0;
         state            <= WAIT_FOR_INPUT;
         fifo_ctrl_prev_0 <= 0;
      end
      else begin
         int_wr           <= int_wr_nxt;
         int_data         <= int_data_nxt;
         int_data_d1      <= int_data_d1_nxt;
         int_ctrl         <= int_ctrl_nxt;
         int_ctrl_d1      <= int_ctrl_d1_nxt;
         vlan_proc_done   <= vlan_proc_done_nxt;
         state            <= state_nxt;
         if(fifo_rd_en) fifo_ctrl_prev_0 <= fifo_ctrl == 0;
      end // else: !if(reset)
   end // always @ (posedge clk)


   /* Post process
    * Put vlan tag residing in module header
    * to a packet itself. */

   assign int_rdy = !int_fifo_nearly_full;

   always @(*) begin
      post_state_nxt  = post_state;
      int_fifo_rd_en  = 0;
      out_wr_nxt      = 0;
      out_data_nxt    = int_fifo_data_out;
      out_ctrl_nxt    = int_fifo_ctrl_out;
      out_data_d1_nxt = out_data_d1;
      out_ctrl_d1_nxt = out_ctrl_d1;
      vlan_tag_nxt   = vlan_tag;

      case (post_state)
         POST_FIND_VLAN_HDR: begin
            if (out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en = 1;
               if (int_fifo_ctrl_out == `VLAN_ADDER_VLAN_CTRL_WORD) begin
                  out_wr_nxt     = 0;
                  vlan_tag_nxt   = int_fifo_data_out[15:0];
                  post_state_nxt = POST_WAIT_SOP;
               end
               else begin
                  out_wr_nxt = 1;
               end
            end
         end // case: POST_FIND_VLAN_HDR

         POST_WAIT_SOP: begin
            if (out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en = 1;
               out_wr_nxt     = 1;
               if (int_fifo_ctrl_out == `IO_QUEUE_STAGE_NUM) begin
                  /* Increment byte-count and word-count since we will add vlan tags
                   * then decrement 8bytes(1word) because we remove one module header */
                  out_data_nxt[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS]
                     = int_fifo_data_out[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS] + 4 - 8;
                  out_data_nxt[`IOQ_WORD_LEN_POS+15:`IOQ_WORD_LEN_POS]
                     = ceildiv((int_fifo_data_out[`IOQ_BYTE_LEN_POS+15:`IOQ_BYTE_LEN_POS] + 4), 8) - 1;
               end
               else if (int_fifo_ctrl_out == 0) begin
                  post_state_nxt = POST_ADD_VLAN;
               end
            end
         end // case: POST_WAIT_SOP

         POST_ADD_VLAN: begin   
            if (out_rdy && !int_fifo_empty) begin
               //insert vlan_tag into second word
               int_fifo_rd_en = 1;
               out_wr_nxt     = 1;
               if (int_fifo_ctrl_out == 0) begin
                  out_data_nxt    = {int_fifo_data_out[63:32], `VLAN_ADDER_VLAN_ETHERTYPE, vlan_tag};
                  out_data_d1_nxt = int_fifo_data_out[31:0];
                  out_ctrl_d1_nxt = int_fifo_ctrl_out;
                  post_state_nxt  = POST_WRITE_MODIFIED_PKT;
               end
               /* Abnormal condition.
                * int_fifo_ctrl_out should be zero on this state but if it isn't
                * then give up continueing and go back to initial state. */
               else begin
                  post_state_nxt = POST_FIND_VLAN_HDR;
               end
            end
         end // case: POST_ADD_VLAN

         POST_WRITE_MODIFIED_PKT: begin
            if (out_rdy && !int_fifo_empty) begin
               int_fifo_rd_en  = 1;
               out_wr_nxt      = 1;
               out_data_nxt    = {out_data_d1, int_fifo_data_out[63:32]};
               out_data_d1_nxt = int_fifo_data_out[31:0];
               out_ctrl_d1_nxt = int_fifo_ctrl_out;
               if (int_fifo_ctrl_out[7:4] != 0) begin
                  out_ctrl_nxt   = (int_fifo_ctrl_out >> 4);
                  post_state_nxt = POST_FIND_VLAN_HDR;
               end
               else if (int_fifo_ctrl_out[3:0] != 0) begin
                  out_ctrl_nxt   = 0;
                  post_state_nxt = POST_WRITE_LAST_PKT;
               end
            end
         end // case: POST_WRITE_MODIFIED_PKT

         POST_WRITE_LAST_PKT: begin
            if (out_rdy) begin
               out_wr_nxt     = 1;
               out_data_nxt   = {out_data_d1, 32'h0};
               out_ctrl_nxt   = out_ctrl_d1 << 4; 
               post_state_nxt = POST_FIND_VLAN_HDR;
            end
         end // case: POST_WRITE_LAST_PKT

      endcase // case(process_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         post_state  <= POST_FIND_VLAN_HDR;
         out_wr      <= 0;
         out_data    <= 0;
         out_ctrl    <= 1;
         out_data_d1 <= 0;
         out_ctrl_d1 <= 0;
         vlan_tag    <= 0;
      end
      else begin
         post_state  <= post_state_nxt;
         out_wr      <= out_wr_nxt;
         out_data    <= out_data_nxt;
         out_ctrl    <= out_ctrl_nxt;
         out_data_d1 <= out_data_d1_nxt;
         out_ctrl_d1 <= out_ctrl_d1_nxt;
         vlan_tag    <= vlan_tag_nxt;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // vlan_adder
