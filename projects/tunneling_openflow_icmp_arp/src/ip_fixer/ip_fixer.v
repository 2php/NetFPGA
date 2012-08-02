/******************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 * filename:  ip_fixer.v
 * author:    Jad Naous
 * Summary:   fixes the ip packet length, and updates
 *            the checksum to the correct value.
 *
 * Warning: This module assumes we will not run
 * at more than 5Gbps!!
 ******************************************************/

`timescale 1ns/1ps
module ip_fixer
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH=DATA_WIDTH/8)
   (// --- data path interface
    output     [DATA_WIDTH-1:0]        out_data,
    output     [CTRL_WIDTH-1:0]        out_ctrl,
    output                             out_wr,
    input                              out_rdy,

    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output                             in_rdy,

    // --- Misc
    input                              clk,
    input                              reset);

   //------------------- wires/regs -------------------
   wire [15:0]                         new_ip_length;
   wire [15:0]                         new_ip_checksum;
   wire [DATA_WIDTH-1:0]               in_fifo_data;
   wire [CTRL_WIDTH-1:0]               in_fifo_ctrl;

   reg [DATA_WIDTH-1:0]                in_data_reg;
   reg [CTRL_WIDTH-1:0]                in_ctrl_reg;
   reg                                 in_wr_reg;

   //-------------------- Modules ---------------------
   ip_fixer_preprocess
     #(.DATA_WIDTH                  (DATA_WIDTH),
       .CTRL_WIDTH                  (CTRL_WIDTH))
       ip_fixer_preprocess
       ( // --- Interface to the previous stage
         .in_data                   (in_data_reg),
         .in_ctrl                   (in_ctrl_reg),
         .in_wr                     (in_wr_reg),

         // --- Interface to process block
         .new_ip_length             (new_ip_length),
         .new_ip_checksum           (new_ip_checksum),
         .new_data_avail            (new_data_avail),
         .pkt_is_ip                 (pkt_is_ip),
         .new_data_rd_en            (new_data_rd_en),

         // --- Misc
         .reset                     (reset),
         .clk                       (clk)
         );

   ip_fixer_process
     #(.DATA_WIDTH                  (DATA_WIDTH),
       .CTRL_WIDTH                  (CTRL_WIDTH))
       ip_fixer_process
       ( // --- Interface to the input fifo
         .in_fifo_rd_en             (in_fifo_rd_en),
         .in_fifo_ctrl              (in_fifo_ctrl),
         .in_fifo_data              (in_fifo_data),
         .in_fifo_empty             (in_fifo_empty),

         // --- Interface to preprocess block
         .new_ip_length             (new_ip_length),
         .new_ip_checksum           (new_ip_checksum),
         .new_data_avail            (new_data_avail),
         .pkt_is_ip                 (pkt_is_ip),
         .new_data_rd_en            (new_data_rd_en),

         // --- Interface to the next stage
         .out_data                  (out_data),
         .out_ctrl                  (out_ctrl),
         .out_wr                    (out_wr),
         .out_rdy                   (out_rdy),

         // --- Misc
         .reset                     (reset),
         .clk                       (clk)
         );

   fallthrough_small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(5), .PROG_FULL_THRESHOLD(29))
      input_fifo
        (.din           ({in_ctrl_reg, in_data_reg}),  // Data in
         .wr_en         (in_wr_reg),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({in_fifo_ctrl, in_fifo_data}),
         .full          (),
         .prog_full     (in_fifo_nearly_full),
         .nearly_full   (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //------------------------- Logic ----------------------
   assign in_rdy = !in_fifo_nearly_full;
   always @(posedge clk) begin
      in_ctrl_reg    <= in_ctrl;
      in_data_reg    <= in_data;
      in_wr_reg      <= in_wr;
   end

endmodule // ip_fixer
