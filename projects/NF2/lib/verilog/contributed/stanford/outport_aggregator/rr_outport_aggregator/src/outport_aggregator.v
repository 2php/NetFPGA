///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: input_arbiter.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: outport_aggregator.v
// Project: NF2.1
// Description: Goes round-robin around the queues and services one pkt
//              out of each (if available). Note that this is unfair for queues
//              that always receive small packets since they pile up!
//              This module is modified version of rr_input_arbiter module.
//               - The number of input ports is decreased from 8 to 4.
//               - Implement a 'selector' and its register so that we can specify
//                 which output-port to be used for forwarding.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module outport_aggregator
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter STAGE_NUMBER = 2,
      parameter NUM_QUEUES = 4
      )

   (// --- interface to TX queues
    output [DATA_WIDTH-1:0]            out_data_0,
    output [CTRL_WIDTH-1:0]            out_ctrl_0,
    output reg                         out_wr_0,
    input                              out_rdy_0,

    output [DATA_WIDTH-1:0]            out_data_1,
    output [CTRL_WIDTH-1:0]            out_ctrl_1,
    output reg                         out_wr_1,
    input                              out_rdy_1,

    output [DATA_WIDTH-1:0]            out_data_2,
    output [CTRL_WIDTH-1:0]            out_ctrl_2,
    output reg                         out_wr_2,
    input                              out_rdy_2,

    output [DATA_WIDTH-1:0]            out_data_3,
    output [CTRL_WIDTH-1:0]            out_ctrl_3,
    output reg                         out_wr_3,
    input                              out_rdy_3,

    // interface to preceding queues
    input  [DATA_WIDTH-1:0]            in_data_0,
    input  [CTRL_WIDTH-1:0]            in_ctrl_0,
    input                              in_wr_0,
    output                             in_rdy_0,

    input  [DATA_WIDTH-1:0]            in_data_1,
    input  [CTRL_WIDTH-1:0]            in_ctrl_1,
    input                              in_wr_1,
    output                             in_rdy_1,

    input  [DATA_WIDTH-1:0]            in_data_2,
    input  [CTRL_WIDTH-1:0]            in_ctrl_2,
    input                              in_wr_2,
    output                             in_rdy_2,

    input  [DATA_WIDTH-1:0]            in_data_3,
    input  [CTRL_WIDTH-1:0]            in_ctrl_3,
    input                              in_wr_3,
    output                             in_rdy_3,

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
    input                              reset,
    input                              clk
   );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   // ------------ Internal Params --------
   parameter NUM_QUEUES_WIDTH = log2(NUM_QUEUES);

   parameter NUM_STATES = 1;
   parameter IDLE       = 0;
   parameter WR_PKT     = 1;

   // ------------- Regs/ wires -----------

   reg [DATA_WIDTH-1:0]                out_data;
   reg [CTRL_WIDTH-1:0]                out_ctrl;
   reg                                 out_wr;
   reg                                 out_rdy;

   wire [NUM_QUEUES-1:0]               nearly_full;
   wire [NUM_QUEUES-1:0]               empty;
   wire [DATA_WIDTH-1:0]               in_data      [NUM_QUEUES-1:0];
   wire [CTRL_WIDTH-1:0]               in_ctrl      [NUM_QUEUES-1:0];
   wire [NUM_QUEUES-1:0]               in_wr;
   wire [CTRL_WIDTH-1:0]               fifo_out_ctrl[NUM_QUEUES-1:0];
   wire [DATA_WIDTH-1:0]               fifo_out_data[NUM_QUEUES-1:0];
   reg [NUM_QUEUES-1:0]                rd_en;

   wire [NUM_QUEUES_WIDTH-1:0]         cur_queue_plus1;
   reg [NUM_QUEUES_WIDTH-1:0]          cur_queue;
   reg [NUM_QUEUES_WIDTH-1:0]          cur_queue_next;

   reg [NUM_STATES-1:0]                state;
   reg [NUM_STATES-1:0]                state_next;

   reg [CTRL_WIDTH-1:0]                fifo_out_ctrl_prev;
   reg [CTRL_WIDTH-1:0]                fifo_out_ctrl_prev_next;

   wire [CTRL_WIDTH-1:0]               fifo_out_ctrl_sel;
   wire [DATA_WIDTH-1:0]               fifo_out_data_sel;

   reg [DATA_WIDTH-1:0]                out_data_next;
   reg [CTRL_WIDTH-1:0]                out_ctrl_next;
   reg                                 out_wr_next;

   reg                                 eop;

   wire [NUM_QUEUES_WIDTH-1:0]         outport_sel;

   // ------------ Modules -------------

   generate 
   genvar i;
   for(i=0; i<NUM_QUEUES; i=i+1) begin: in_arb_queues
      small_fifo
        #( .WIDTH(DATA_WIDTH+CTRL_WIDTH),
           .MAX_DEPTH_BITS(2))
      in_arb_fifo
        (// Outputs
         .dout                           ({fifo_out_ctrl[i], fifo_out_data[i]}),
         .full                           (),
         .nearly_full                    (nearly_full[i]),
	 .prog_full                      (),
         .empty                          (empty[i]),
         // Inputs
         .din                            ({in_ctrl[i], in_data[i]}),
         .wr_en                          (in_wr[i]),
         .rd_en                          (rd_en[i]),
         .reset                          (reset),
         .clk                            (clk));
   end // block: in_arb_queues
   endgenerate

   out_aggr_regs
   #(
      .DATA_WIDTH(DATA_WIDTH),
      .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH)
   ) out_aggr_regs ( 
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      .state            (state),
      .out_wr           (out_wr),
      .out_ctrl         (out_ctrl),
      .out_data         (out_data),
      .out_rdy          (out_rdy),
      .eop              (eop),

      .outport_sel      (outport_sel),

      .clk              (clk),
      .reset            (reset)
   );


   // ------------- Logic ------------

   assign in_data[0]         = in_data_0;
   assign in_ctrl[0]         = in_ctrl_0;
   assign in_wr[0]           = in_wr_0;
   assign in_rdy_0           = !nearly_full[0];

   assign in_data[1]         = in_data_1;
   assign in_ctrl[1]         = in_ctrl_1;
   assign in_wr[1]           = in_wr_1;
   assign in_rdy_1           = !nearly_full[1];

   assign in_data[2]         = in_data_2;
   assign in_ctrl[2]         = in_ctrl_2;
   assign in_wr[2]           = in_wr_2;
   assign in_rdy_2           = !nearly_full[2];

   assign in_data[3]         = in_data_3;
   assign in_ctrl[3]         = in_ctrl_3;
   assign in_wr[3]           = in_wr_3;
   assign in_rdy_3           = !nearly_full[3];

   /* disable regs for this module */
   assign cur_queue_plus1    = (cur_queue == NUM_QUEUES-1) ? 0 : cur_queue + 1;

   assign fifo_out_ctrl_sel  = fifo_out_ctrl[cur_queue];
   assign fifo_out_data_sel  = fifo_out_data[cur_queue];

   always @(*) begin
      state_next     = state;
      cur_queue_next = cur_queue;
      fifo_out_ctrl_prev_next = fifo_out_ctrl_prev;
      out_wr_next    = 0;
      out_ctrl_next  = fifo_out_ctrl_sel;
      out_data_next  = fifo_out_data_sel;
      rd_en          = 0;
      eop            = 0;
      
      case(state)

        /* cycle between input queues until one is not empty */
        IDLE: begin
           if(!empty[cur_queue] && out_rdy) begin
              state_next = WR_PKT;
              rd_en[cur_queue] = 1;
              fifo_out_ctrl_prev_next = STAGE_NUMBER;
           end
           if(empty[cur_queue] && out_rdy) begin
              cur_queue_next = cur_queue_plus1;
           end
        end

        /* wait until eop */
        WR_PKT: begin
           /* if this is the last word then write it and get out */
           if(out_rdy & |fifo_out_ctrl_sel & (fifo_out_ctrl_prev==0) ) begin
              out_wr_next = 1;
              state_next = IDLE;
              cur_queue_next = cur_queue_plus1;
              eop = 1;
           end
           /* otherwise read and write as usual */
           else if (out_rdy & !empty[cur_queue]) begin
              fifo_out_ctrl_prev_next = fifo_out_ctrl_sel;
              out_wr_next = 1;
              rd_en[cur_queue] = 1;
           end
        end // case: WR_PKT

      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         state <= IDLE;
         cur_queue <= 0;
         fifo_out_ctrl_prev <= 1;
         out_wr <= 0;
         out_ctrl <= 1;
         out_data <= 0;
      end
      else begin
         state <= state_next;
         cur_queue <= cur_queue_next;
         fifo_out_ctrl_prev <= fifo_out_ctrl_prev_next;
         out_wr <= out_wr_next;
         out_ctrl <= out_ctrl_next;
         out_data <= out_data_next;
      end
   end

   /* Send out packets to specified output port.
      Data/Ctrl are copied and sent out to all the ports,
      but 'wr' and 'rdy' signals are switched accordingly.
   */
   assign out_data_0 = out_data;
   assign out_data_1 = out_data;
   assign out_data_2 = out_data;
   assign out_data_3 = out_data;
   assign out_ctrl_0 = out_ctrl;
   assign out_ctrl_1 = out_ctrl;
   assign out_ctrl_2 = out_ctrl;
   assign out_ctrl_3 = out_ctrl;

   always @(*) begin
      out_wr_0 = out_wr;
      out_wr_1 = 0;
      out_wr_2 = 0;
      out_wr_3 = 0;
      out_rdy = out_rdy_0;

      case(outport_sel)
         0: begin
            out_wr_0 = out_wr;
            out_wr_1 = 0;
            out_wr_2 = 0;
            out_wr_3 = 0;
            out_rdy = out_rdy_0;
         end
         1: begin
            out_wr_0 = 0;
            out_wr_1 = out_wr;
            out_wr_2 = 0;
            out_wr_3 = 0;
            out_rdy = out_rdy_1;
         end
         2: begin
            out_wr_0 = 0;
            out_wr_1 = 0;
            out_wr_2 = out_wr;
            out_wr_3 = 0;
            out_rdy = out_rdy_2;
         end
         3: begin
            out_wr_0 = 0;
            out_wr_1 = 0;
            out_wr_2 = 0;
            out_wr_3 = out_wr;
            out_rdy = out_rdy_3;
         end
      endcase
   end

endmodule // rr_outport_aggregator

// Local Variables:
// verilog-library-directories:(".")
// End:
