/******************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 * filename:  ip_fixer_preprocess.v
 * author:    Jad Naous
 * Summary:   Finds the actual IP pkt length, and the
 *            correct IP checksum.
 ******************************************************/

`timescale 1ns/1ps
module ip_fixer_preprocess
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH=DATA_WIDTH/8)
   (// --- data path interface
    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,

    // --- interface to process block
    output [15:0]                      new_ip_length,
    output [15:0]                      new_ip_checksum,
    output                             new_data_avail,
    output                             pkt_is_ip,
    input                              new_data_rd_en,

    // --- Misc
    input                              clk,
    input                              reset);

   //------------------ local params ------------------
   localparam                          WAIT_FOR_PKT   = 1,
                                       IP_WORD_0      = 2,
                                       IP_WORD_1      = 4,
                                       IP_WORD_2      = 8,
                                       IP_WORD_3      = 16,
                                       IP_WORD_4      = 32,
                                       IP_WORD_5      = 64,
                                       FOLD_ONCE      = 128,
                                       FOLD_AGAIN     = 256,
                                       WAIT_EOP       = 512;

   //------------------- wires/regs -------------------
   reg [19:0]                          checksum;
   reg [15:0]                          length;
   reg [47:0]                          in_data_prev1;
   reg [47:0]                          in_data_prev2;
   reg                                 preprocess_fifo_wr_en;
   reg [9:0]                           state;
   reg                                 pkt_is_ip_local;

   //-------------------- Modules ---------------------
   small_fifo
     #(.WIDTH(33), .MAX_DEPTH_BITS(1))
      preprocess_fifo
        (.din           ({~checksum[15:0], length[15:0], pkt_is_ip_local}),
         .wr_en         (preprocess_fifo_wr_en),
         .rd_en         (new_data_rd_en),
         .dout          ({new_ip_checksum, new_ip_length, pkt_is_ip}),
         .full          (),
         .nearly_full   (),
         .empty         (preprocess_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );
   //--------------------- Logic ----------------------
   assign new_data_avail = !preprocess_fifo_empty;

   /* - Wait for packet to arrive
    * - find the IOQ module header and get the
    *   pkt length
    * - calculate the correct IP checksum
    * - repeat :)
    */
   always @(posedge clk) begin
      if(reset) begin
         length                   <= 0;
         state                    <= WAIT_FOR_PKT;
         checksum                 <= 0;
         preprocess_fifo_wr_en    <= 0;
         pkt_is_ip_local          <= 0;
      end
      else begin
         preprocess_fifo_wr_en    <= 0;

         case (state)
            WAIT_FOR_PKT: begin
               if(in_wr) begin
                  /* get the pkt length */
                  if(in_ctrl == `IO_QUEUE_STAGE_NUM) begin
                     length <= in_data[15 + `IOQ_BYTE_LEN_POS : `IOQ_BYTE_LEN_POS] - 15'd14;
                  end
                  if(in_ctrl == 0) begin
                     state <= IP_WORD_0;
                  end
               end // if (in_wr)
            end // case: WAIT_FOR_PKT

            IP_WORD_0: begin
               if(in_wr) begin
                  checksum        <= {4'h0, in_data[15:0]};
                  state           <= IP_WORD_1;
                  pkt_is_ip_local <= in_data[31:16] == 16'h0800;
               end
            end

            IP_WORD_1: begin
               if(in_wr) begin
                  checksum      <= checksum + length;
                  in_data_prev1 <= in_data[47:0];
                  state         <= IP_WORD_2;
               end
            end

            IP_WORD_2: begin
               if(in_wr) begin
                  checksum      <= checksum + in_data_prev1[47:32] +
                                   in_data_prev1[31:16];

                  in_data_prev2 <= in_data[47:0];
                  state         <= IP_WORD_3;
               end
            end

            IP_WORD_3: begin
               if(in_wr) begin
                  checksum             <= checksum + in_data_prev1[15:0] +
                                          in_data_prev2[47:32];
                  in_data_prev1[47:32] <= in_data[63:48];
                  state                <= IP_WORD_4;
               end
            end

            IP_WORD_4: begin
               if (in_wr) begin
                  checksum <= checksum + in_data_prev2[31:16] +
                              in_data_prev2[15:0];
                  state    <= IP_WORD_5;
               end
            end

            IP_WORD_5: begin
               if (in_wr) begin
                  checksum <= checksum + in_data_prev1[47:32];
                  state    <= FOLD_ONCE;
               end
            end

            FOLD_ONCE: begin
               checksum <= {16'h0, checksum[19:16]}
                           + {4'h0, checksum[15:0]};
               state    <= FOLD_AGAIN;
            end

            FOLD_AGAIN: begin
               checksum <= {16'h0, checksum[19:16]}
                           + {4'h0, checksum[15:0]};
               preprocess_fifo_wr_en <= 1;
               state    <= WAIT_EOP;
            end

            WAIT_EOP: begin
               if(in_wr && in_ctrl != 0) begin
                  state    <= WAIT_FOR_PKT;
               end
            end

            default: begin
               state    <= WAIT_FOR_PKT;
            end
         endcase // case(state)
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // ip_fixer_preprocess
