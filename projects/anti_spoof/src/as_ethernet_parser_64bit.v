///////////////////////////////////////////////////////////////////////////////
// $Id: ethernet_parser_64bit.v 2201 2007-08-21 06:52:51Z jnaous $
//
// Module: ethernet_parser_64bit.v
// Project: NF2.1
// Description: parses the Ethernet header for a 64 bit datapath
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module as_ethernet_parser_64bit
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter NUM_IQ_BITS = 3,
      parameter INPUT_ARBITER_STAGE_NUM = 2
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,

    // --- Interface to output_port_lookup
    output reg [31:0]                  dst_ip,
    output reg [31:0]                  src_ip,
    output reg [47:0]                  dst_mac,
    output reg [47:0]                  src_mac,
    output reg [15:0]                  ethertype,
    output reg                         ip_done,
    output reg [NUM_IQ_BITS-1:0]       src_port,

    // --- Misc

    input                              reset,
    input                              clk
   );


   // ------------ Internal Params --------

   parameter NUM_STATES  = 6;
   parameter READ_WORD_1 = 1;
   parameter READ_WORD_2 = 2;
   parameter READ_WORD_3 = 3;
   parameter READ_WORD_4 = 4;
   parameter READ_WORD_5 = 5;
   parameter WAIT_EOP    = 6;

   // ------------- Regs/ wires -----------

   reg [NUM_STATES-1:0]                state;
   reg [NUM_STATES-1:0]                state_next;

   reg [31:0]                          dst_ip_next;
   reg [31:0]                          src_ip_next;

   reg [47:0]                          dst_mac_next;
   reg [47:0]                          src_mac_next;
   reg [15:0]                          ethertype_next;
   reg                                 ip_done_next;
   reg [NUM_IQ_BITS-1:0]               src_port_next;

   // ------------ Logic ----------------

   always @(*) begin
      dst_ip_next     = dst_ip;
      src_ip_next     = src_ip;
      dst_mac_next     = dst_mac;
      src_mac_next     = src_mac;
      ethertype_next   = ethertype;
      ip_done_next    = ip_done;
      src_port_next    = src_port;
      state_next       = state;
      case(state)
        /* read the input source header and get the first word */
        READ_WORD_1: begin
           if(in_wr && in_ctrl==`IO_QUEUE_STAGE_NUM) begin
              src_port_next = in_data[`IOQ_SRC_PORT_POS + NUM_IQ_BITS - 1 : `IOQ_SRC_PORT_POS];
           end
           else if(in_wr && in_ctrl==0) begin
              dst_mac_next          = in_data[63:16] ;
              src_mac_next[47:32]   = in_data[15:0];
              state_next            = READ_WORD_2;
           end
        end // case: READ_WORD_1

        READ_WORD_2: begin
           if(in_wr) begin
              src_mac_next [31:0]   = in_data[63:32];
              ethertype_next        = in_data[31:16];
              state_next            = READ_WORD_3;
           end
        end

        READ_WORD_3: begin
           if(in_wr) begin
              state_next            = READ_WORD_4;
           end
        end

        READ_WORD_4: begin
           if(in_wr) begin
              src_ip_next [31:0]   = in_data[47:16];
              dst_ip_next [31:16]   = in_data[15:0];
              state_next            = READ_WORD_5;
           end
        end

        READ_WORD_5: begin
           if(in_wr) begin
              dst_ip_next [15:0]   = in_data[63:48];
              state_next            = WAIT_EOP;
              ip_done_next         = 1;
           end
        end

        WAIT_EOP: begin
           if(in_wr && in_ctrl!=0) begin
              ip_done_next   = 0;
              state_next      = READ_WORD_1;
           end
        end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         src_ip      <= 0;
         dst_ip      <= 0;
         src_mac      <= 0;
         dst_mac      <= 0;
         ethertype    <= 0;
         ip_done     <= 0;
         state        <= READ_WORD_1;
         src_port     <= 0;
      end
      else begin
         src_ip      <= src_ip_next;
         dst_ip      <= dst_ip_next;
         src_mac      <= src_mac_next;
         dst_mac      <= dst_mac_next;
         ethertype    <= ethertype_next;
         ip_done     <= ip_done_next;
         state        <= state_next;
         src_port     <= src_port_next;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // ethernet_parser_64bit
