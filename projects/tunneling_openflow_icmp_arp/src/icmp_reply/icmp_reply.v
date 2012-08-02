///////////////////////////////////////////////////////////////////////////////
// $Id$
//
// Module: icmp_reply.v
// Project: NF2.1 Tunneling OpenFlow Switch
// Author: Jad Naous <jnaous@stanford.edu>
// Description: Replies to an ICMP request if the Destination IP address in
//              IP Header matches
//
///////////////////////////////////////////////////////////////////////////////

module icmp_reply
  #(parameter DATA_WIDTH         = 64,
    parameter CTRL_WIDTH         = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH  = 2,

    parameter REG_ADDR_WIDTH = 6,   // needs to be overridden
    parameter REG_BLOCK_TAG = 0     // needs to be overridden
    )

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
   localparam ETH_TYPE_POS                             = 16;
   localparam ETH_TYPE_IP                              = 16'h0800;

   localparam IP_PROTO_TYPE_POS                        = 0;
   localparam IP_PROTO_TYPE_ICMP                       = 8'h1;

   localparam IP_ICMP_TYPE_POS                         = 40;
   localparam IP_ICMP_CODE_POS                         = 32;
   localparam IP_ICMP_ECHO_REQUEST                     = 8'h8;
   localparam IP_ICMP_ECHO_REPLY                       = 8'h0;

   localparam IP_ICMP_DEF_TTL                          = 8'h10;
   localparam IP_ICMP_CHKSUM                           = 16'h0800;
   localparam IP_ICMP_CHKSUM_1                         = 16'hffff;

   localparam NUM_PREPROCESS_STATES                    = 7;
   localparam PREPROCESS_SKIP_MODULE_HDRS              = 1,
              PREPROCESS_CHECK_ETHERTYPE               = 2,
              PREPROCESS_CHECK_IP_PROTO_TYPE           = 4,
              PREPROCESS_GET_IP_SA_IP_DA_HI            = 8,
              PREPROCESS_GET_IP_DA_LO                  = 16,
              PREPROCESS_CHECK_IP_DA                   = 32,
              PREPROCESS_WAIT_EOP                      = 64;

   localparam NUM_PROCESS_STATES                       = 5;
   localparam PROCESS_WAIT_PREPROCESS                  = 1,
              PROCESS_SKIP_MODULE_HDRS                 = 2,
              PROCESS_MOD_PKT_WORDS                    = 4,
              PROCESS_DROP_PKT                         = 8,
              PROCESS_WAIT_EOP                         = 16;


   //---------------------- Wires/Regs -------------------------------
   reg [NUM_PREPROCESS_STATES-1:0] preprocess_state;

   wire [CTRL_WIDTH-1:0]           input_fifo_ctrl;
   wire [DATA_WIDTH-1:0]           input_fifo_data;
   reg                             input_fifo_rd_en;

   reg                             pkt_is_icmp_req;
   reg                             icmp_ip_for_us;
   reg                             preprocess_fifo_wr_en;
   reg                             preprocess_fifo_rd_en;
   reg [47:0]                      eth_src_addr, eth_dst_addr;
   reg [31:0]                      ip_src_addr, ip_dst_addr;
   reg [15:0]                      ip_icmp_chksum;
   reg [63:0]                      in_data_reg;
   wire [47:0]                     eth_src_addr_dout, eth_dst_addr_dout;
   wire [31:0]                     ip_src_addr_dout, ip_dst_addr_dout;

   reg                             icmp_reply_sent;
   reg                             icmp_dropped;
   reg                             pkt_count;
   wire [31:0]                     icmp_reply_enable_reg;

   reg [NUM_PROCESS_STATES-1:0]    process_state_nxt, process_state;
   reg                             out_wr_nxt;
   reg [DATA_WIDTH-1:0]            out_data_nxt;

   wire [31:0]                     ip_addr_port_3;
   wire [31:0]                     ip_addr_port_2;
   wire [31:0]                     ip_addr_port_1;
   wire [31:0]                     ip_addr_port_0;

   wire [31:0]                     eth_addr_port_3_lo;
   wire [31:0]                     eth_addr_port_3_hi;
   wire [31:0]                     eth_addr_port_2_lo;
   wire [31:0]                     eth_addr_port_2_hi;
   wire [31:0]                     eth_addr_port_1_lo;
   wire [31:0]                     eth_addr_port_1_hi;
   wire [31:0]                     eth_addr_port_0_lo;
   wire [31:0]                     eth_addr_port_0_hi;

   reg [2:0]                       count_nxt, count;

   reg [15:0]                      src_port_decoded;
   reg [3:0]                       src_port;

   reg                             input_fifo_ctrl_prev_is_0;

   //----------------------- Modules ---------------------------------

   fallthrough_small_fifo
     #(.WIDTH            (DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS   (4)) input_fifo
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
     #(.WIDTH            (2+48+32+48+32),
       .MAX_DEPTH_BITS   (2)) preprocess_fifo
       (
        .din             ({pkt_is_icmp_req, icmp_ip_for_us, eth_src_addr, ip_src_addr, eth_dst_addr, ip_dst_addr}),
        .wr_en           (preprocess_fifo_wr_en),

        .rd_en           (preprocess_fifo_rd_en),

        .dout            ({pkt_is_icmp_req_dout, icmp_ip_for_us_dout, eth_src_addr_dout, ip_src_addr_dout, eth_dst_addr_dout, ip_dst_addr_dout}),
        .full            (),
        .nearly_full     (preprocess_fifo_nearly_full),
        .empty           (preprocess_fifo_empty),

        .reset           (reset),
        .clk             (clk)
        );

   generic_regs
     #( .UDP_REG_SRC_WIDTH     (UDP_REG_SRC_WIDTH),
        .TAG                   (REG_BLOCK_TAG),
        .REG_ADDR_WIDTH        (REG_ADDR_WIDTH),
        .NUM_COUNTERS          (3),
        .NUM_SOFTWARE_REGS     (1+8+4),
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
        .counter_updates       ({icmp_reply_sent, icmp_dropped, pkt_count}),
        .counter_decrement     (3'b0),

        // --- SW regs interface
        .software_regs         ({ip_addr_port_3,
                                 ip_addr_port_2,
                                 ip_addr_port_1,
                                 ip_addr_port_0,
                                 eth_addr_port_3_lo, 
                                 eth_addr_port_3_hi, 
                                 eth_addr_port_2_lo, 
                                 eth_addr_port_2_hi, 
                                 eth_addr_port_1_lo, 
                                 eth_addr_port_1_hi, 
                                 eth_addr_port_0_lo, 
                                 eth_addr_port_0_hi, 
                                 icmp_reply_enable_reg}),

        // --- HW regs interface
        .hardware_regs         (),

        .clk                   (clk),
        .reset                 (reset));

   //------------------------ Logic ----------------------------------

   assign in_rdy = !input_fifo_almost_full && !preprocess_fifo_nearly_full;
   assign enable_module = icmp_reply_enable_reg[0];

   /****************************** Preprocessor **************************/

   always @(*) begin
      if(reset) begin
         in_data_reg              = 0;
      end
      else begin
         in_data_reg              = in_data;
      end
   end

   /* This state machine (preprocessor) checks the ethertype
    * to see if the packet is an ICMP/IP */
   always @(posedge clk) begin

      if(reset) begin
         preprocess_fifo_wr_en    <= 0;
         pkt_is_icmp_req          <= 0;
         icmp_ip_for_us           <= 1'b1;
         preprocess_state          = PREPROCESS_SKIP_MODULE_HDRS;
      end
      else begin
         preprocess_fifo_wr_en    <= 0;
         pkt_is_icmp_req          <= 0;
         icmp_ip_for_us           <= 1'b1;

         case (preprocess_state)

            PREPROCESS_SKIP_MODULE_HDRS: begin
               if (in_wr && in_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  src_port <= in_data_reg[`IOQ_SRC_PORT_POS+3:`IOQ_SRC_PORT_POS];
               end

               if (in_wr && in_ctrl == 0) begin
                  if(enable_module) begin
                     eth_dst_addr        <= in_data_reg[63:16];
                     eth_src_addr[47:32] <= in_data_reg[15:0];
                     preprocess_state     = PREPROCESS_CHECK_ETHERTYPE;
                  end
                  else begin
                     preprocess_state       = PREPROCESS_WAIT_EOP;
                     preprocess_fifo_wr_en  <= 1'b1;
                  end
               end
            end //case: PREPROCESS_SKIP_MODULE_HDRS

            PREPROCESS_CHECK_ETHERTYPE: begin
               if (in_wr) begin
                  eth_src_addr[31:0] <= in_data_reg[63:32];
                  if(in_data_reg[ETH_TYPE_POS + 15:ETH_TYPE_POS] == ETH_TYPE_IP) begin
                     preprocess_state       = PREPROCESS_CHECK_IP_PROTO_TYPE;
                  end
                  else begin
                     preprocess_state       = PREPROCESS_WAIT_EOP;
                     preprocess_fifo_wr_en  <= 1'b1;
                  end
               end // if (in_wr)
            end // case: PREPROCESS_CHECK_ETHERTYPE

            PREPROCESS_CHECK_IP_PROTO_TYPE: begin
               if (in_wr) begin
                  if(in_data_reg[IP_PROTO_TYPE_POS + 8:IP_PROTO_TYPE_POS] == IP_PROTO_TYPE_ICMP) begin
                     preprocess_state  = PREPROCESS_GET_IP_SA_IP_DA_HI;
                  end
                  else begin
                     preprocess_state        = PREPROCESS_WAIT_EOP;
                     preprocess_fifo_wr_en  <= 1'b1;
                  end
               end // if (in_wr)
            end // case: PREPROCESS_CHECK_IP_PROTO_TYPE

            PREPROCESS_GET_IP_SA_IP_DA_HI: begin
               if (in_wr) begin
                  ip_src_addr           <= in_data_reg[47:16];
                  ip_dst_addr[31:16]    <= in_data_reg[15:0];
                  preprocess_state      = PREPROCESS_GET_IP_DA_LO;
               end // if (in_wr)
            end //case: PREPROCESS_GET_IP_SA_IP_DA_HI

            PREPROCESS_GET_IP_DA_LO: begin
               if (in_wr) begin
                  ip_icmp_chksum       <= in_data_reg[31:16];
                  ip_dst_addr[15:0]    <= in_data_reg[63:48];
                  if(in_data_reg[IP_ICMP_TYPE_POS + 7:IP_ICMP_TYPE_POS] == IP_ICMP_ECHO_REQUEST) begin
                     preprocess_state       = PREPROCESS_CHECK_IP_DA;
                  end
                  else begin
                     preprocess_state       = PREPROCESS_WAIT_EOP;
                     preprocess_fifo_wr_en  <= 1'b1;
                  end
               end // if (in_wr)
            end  //case: PREPROCESS_GET_IP_DA_LO

            PREPROCESS_CHECK_IP_DA: begin
               case ({src_port, ip_dst_addr})
                  {4'h0, ip_addr_port_0}:;
                  {4'h2, ip_addr_port_1}:;
                  {4'h4, ip_addr_port_2}:;
                  {4'h6, ip_addr_port_3}:;
                  default: icmp_ip_for_us <= 1'b0;
               endcase // case(ip_dst_addr)
               pkt_is_icmp_req           <= 1'b1;
               preprocess_fifo_wr_en     <= 1'b1;
               preprocess_state           = PREPROCESS_WAIT_EOP;
            end // case: PREPROCESS_CHECK_IP_DA

            PREPROCESS_WAIT_EOP: begin
               if(in_wr && in_ctrl != 0) begin
                  preprocess_state   = PREPROCESS_SKIP_MODULE_HDRS;
               end
            end
         endcase // case(preprocess_state)
      end // (!reset)
   end // always @ (posedge clk)


   /*********************************** Processor ************************/

   /* decode source port */
   always @(*) begin
      src_port_decoded = 0;
      src_port_decoded[input_fifo_data[`IOQ_SRC_PORT_POS+3:`IOQ_SRC_PORT_POS]] = 1'b1;
   end

   /* This state machine (processor) will reply to an icmp request if
    * it matched one of the IP addresses set in the registers.
    * This is done by replacing the IP packet's address fields and 
    * ICMP type field  */
   always @(*) begin
      process_state_nxt       = process_state;
      preprocess_fifo_rd_en   = 0;
      input_fifo_rd_en        = 0;
      out_wr_nxt              = 0;
      out_data_nxt            = input_fifo_data;

      icmp_reply_sent         = 0;
      icmp_dropped            = 0;
      pkt_count               = 0;

      count_nxt               = count;

      case (process_state)

         PROCESS_WAIT_PREPROCESS: begin
            if(!preprocess_fifo_empty && !input_fifo_empty) begin
               /* if we need to reply to the ICMP request */
               if(pkt_is_icmp_req_dout && icmp_ip_for_us_dout) begin
                  if(out_rdy) begin
                     process_state_nxt       = PROCESS_SKIP_MODULE_HDRS;
                     icmp_reply_sent         = 1'b1;
                  end
               end
               /* else if we need to let the packet pass */
               else begin
                  if(out_rdy) begin
                     process_state_nxt       = PROCESS_WAIT_EOP;
                     input_fifo_rd_en        = 1'b1;
                     out_wr_nxt              = 1'b1;
                     preprocess_fifo_rd_en   = 1'b1;
                  end
               end
            end // if (!preprocess_fifo_empty && !input_fifo_empty)
         end // case: PROCESS_WAIT_PREPROCESS

         /* let all the module headers pass */
         PROCESS_SKIP_MODULE_HDRS: begin
            if(!input_fifo_empty && out_rdy) begin
               input_fifo_rd_en   = 1'b1;
               out_wr_nxt         = 1'b1;
               /* modify the input src port to 17 so that the output port lookup
                * doesn't touch it, set the output port  */
               if(input_fifo_ctrl == `IO_QUEUE_STAGE_NUM) begin
                  out_data_nxt[`IOQ_SRC_PORT_POS + 15:`IOQ_SRC_PORT_POS]   = `ICMP_REPLY_DONT_TOUCH_SRC_PORT;
                  out_data_nxt[`IOQ_DST_PORT_POS + 15:`IOQ_DST_PORT_POS]   = src_port_decoded;
               end
               /* if we are done with the module hdrs, set the Ethernet MAC src/dst address */
               else if(input_fifo_ctrl == 0) begin
                  process_state_nxt   = PROCESS_MOD_PKT_WORDS;
                  count_nxt           = 1;
                  out_data_nxt        = {eth_src_addr_dout, eth_dst_addr_dout[47:32]};
               end
            end // if (!input_fifo_empty && out_rdy)
         end // case: PROCESS_SKIP_MODULE_HDRS

         /* modify icmp request words */
         PROCESS_MOD_PKT_WORDS: begin
            if(!input_fifo_empty && out_rdy) begin
               count_nxt          = count + 1'b1;
               input_fifo_rd_en   = 1'b1;
               out_wr_nxt         = 1'b1;
               case (count)
                  1: out_data_nxt[63:32]   = eth_dst_addr_dout[31:0];
                  2: out_data_nxt[15:8]    = {IP_ICMP_DEF_TTL};
                  3: out_data_nxt[47:0]    = {ip_dst_addr_dout, ip_src_addr_dout[31:16]};
                  4: begin
                     out_data_nxt[63:40]   = {ip_src_addr_dout[15:0], IP_ICMP_ECHO_REPLY};
                     if(out_data_nxt[31:16] >= (IP_ICMP_CHKSUM_1 - IP_ICMP_CHKSUM))
                        out_data_nxt[31:16] = ip_icmp_chksum + IP_ICMP_CHKSUM + 8'b00000001;
                     else
                        out_data_nxt[31:16] = ip_icmp_chksum + IP_ICMP_CHKSUM;

                     process_state_nxt     = PROCESS_WAIT_EOP;
                     preprocess_fifo_rd_en = 1'b1;
                     end
               endcase
            end // if(!input_fifo_empty && out_rdy)
         end // case: PROCESS_MOD_PKT_WORDS

         /* drop the packet */
         PROCESS_DROP_PKT: begin
            if(!input_fifo_empty) begin
               input_fifo_rd_en = 1'b1;
               /* if end-of-pkt reached */
               if(input_fifo_ctrl != 0 && out_ctrl == 0) begin
                  icmp_dropped            = 1'b1;
                  process_state_nxt       = PROCESS_WAIT_PREPROCESS;
                  preprocess_fifo_rd_en   = 1'b1;
               end
            end
         end // case: PROCESS_DROP_PKT

         /* send the rest of the packet */
         PROCESS_WAIT_EOP: begin
            if(!input_fifo_empty && out_rdy) begin
               input_fifo_rd_en   = 1'b1;
               out_wr_nxt         = 1'b1;
               /* if end-of-pkt reached */
               if(input_fifo_ctrl != 0 && input_fifo_ctrl_prev_is_0) begin
                  pkt_count               = 1'b1;
                  process_state_nxt       = PROCESS_WAIT_PREPROCESS;
               end
            end
         end // case: PROCESS_WAIT_EOP
      endcase // case(process_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         process_state    <= PROCESS_WAIT_PREPROCESS;
         out_wr           <= 0;
         out_data         <= 0;
         out_ctrl         <= 1;
         count            <= 1;
         input_fifo_ctrl_prev_is_0 <= 0;
      end
      else begin
         process_state    <= process_state_nxt;
         out_wr           <= out_wr_nxt;
         out_data         <= out_data_nxt;
         out_ctrl         <= input_fifo_ctrl;
         count            <= count_nxt;
         if(input_fifo_rd_en) begin
            input_fifo_ctrl_prev_is_0 <= input_fifo_ctrl == 0;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // icmp_reply


