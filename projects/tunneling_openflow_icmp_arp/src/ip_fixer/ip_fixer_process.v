/******************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 * filename:  ip_fixer_process.v
 * author:    Jad Naous
 * Summary:   Rewrites length and checksum
 ******************************************************/

`timescale 1ns/1ps
module ip_fixer_process
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH=DATA_WIDTH/8)
   (
    // --- Interface to the input fifo
    output reg                      in_fifo_rd_en,
    input [CTRL_WIDTH-1:0]          in_fifo_ctrl,
    input [DATA_WIDTH-1:0]          in_fifo_data,
    input                           in_fifo_empty,

    // --- Interface to preprocess block
    input [15:0]                    new_ip_length,
    input [15:0]                    new_ip_checksum,
    input                           new_data_avail,
    input                           pkt_is_ip,
    output reg                      new_data_rd_en,

    // --- data path interface
    output reg [DATA_WIDTH-1:0]        out_data,
    output reg [CTRL_WIDTH-1:0]        out_ctrl,
    output reg                         out_wr,
    input                              out_rdy,

    // --- Misc
    input                              clk,
    input                              reset);

   //------------------ local params ------------------
   localparam  WAIT_FOR_NEW_DATA   = 1,
               WRITE_IP_0          = 2,
               WRITE_IP_1          = 4,
               WRITE_IP_2          = 8,
               WRITE_REST          = 16;

   //------------------- wires/regs -------------------
   reg [4:0] state, state_nxt;

   //--------------------- Logic ----------------------
   always @(*) begin
      in_fifo_rd_en    = 0;
      out_wr           = 0;
      new_data_rd_en   = 0;
      state_nxt        = state;
      out_data         = in_fifo_data;
      out_ctrl         = in_fifo_ctrl;

      case (state)
         WAIT_FOR_NEW_DATA: begin
            if(new_data_avail && out_rdy) begin
               in_fifo_rd_en    = 1'b1;
               out_wr           = 1'b1;
               if(in_fifo_ctrl == 0) begin
                  new_data_rd_en   = 1'b1;
                  state_nxt        = WRITE_IP_0;
               end
            end
         end

         WRITE_IP_0: begin
            if(out_rdy) begin
               out_wr          = 1'b1;
               in_fifo_rd_en   = 1'b1;
               if(pkt_is_ip) begin
                  state_nxt       = WRITE_IP_1;
               end
               else begin
                  state_nxt       = WRITE_REST;
               end
            end
         end

         WRITE_IP_1: begin
            if(out_rdy) begin
               out_wr          = 1'b1;
               out_data[63:48] = new_ip_length;
               in_fifo_rd_en   = 1'b1;
               state_nxt       = WRITE_IP_2;
            end
         end

         WRITE_IP_2: begin
            if(out_rdy) begin
               out_wr          = 1'b1;
               out_data[63:48] = new_ip_checksum;
               in_fifo_rd_en   = 1'b1;
               state_nxt       = WRITE_REST;
            end
         end

         WRITE_REST: begin
            if(out_rdy && !in_fifo_empty) begin
               out_wr          = 1'b1;
               in_fifo_rd_en   = 1'b1;
               if(in_fifo_ctrl != 0) begin
                  state_nxt = WAIT_FOR_NEW_DATA;
               end
            end
         end
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk)
      if(reset)
         state <= WAIT_FOR_NEW_DATA;
      else
         state <= state_nxt;

endmodule // ip_fixer_process
