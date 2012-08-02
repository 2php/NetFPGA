
module rcp_regs
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2)

    ( // register interface
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output reg                             reg_req_out,
      output reg                             reg_ack_out,
      output reg                             reg_rd_wr_L_out,
      output reg [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output reg [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      output [`CPCI_NF2_DATA_WIDTH-1:0] rcp_rate,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_rtt_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_byte_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_0_num_rcp,
      
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_rtt_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_byte_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_1_num_rcp,
      
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_rtt_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_byte_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_2_num_rcp,
      
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_rtt_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_L,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_byte_H,
      input  [`CPCI_NF2_DATA_WIDTH-1:0] mac_3_num_rcp,
      // misc
      input clk,
      input reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2


   //-------------------- Local parameters ------------------------
   parameter NUM_REGS_USED  = 22;
   parameter ADDR_WIDTH     = log2(NUM_REGS_USED);
   parameter IP_TTL = 8'h64;
   parameter UDP_PROTO = 8'd17;
   

   
   
   //---------------- Wire and Reg Declarations -------------------
   reg [`CPCI_NF2_DATA_WIDTH-1:0] reg_file [0:NUM_REGS_USED-1];

   wire [ADDR_WIDTH-1:0]         addr;
   wire [`RCP_REG_ADDR_WIDTH - 1:0] reg_addr;
   wire [`UDP_REG_ADDR_WIDTH-`RCP_REG_ADDR_WIDTH - 1:0] tag_addr;

   wire                          addr_good;
   wire                          tag_hit;
   integer                       i;
   

   //---------------------- Logic -------------------------------

   
   assign  addr = reg_addr_in[ADDR_WIDTH-1:0];
   assign  reg_addr = reg_addr_in[`RCP_REG_ADDR_WIDTH-1:0];
   assign  tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`RCP_REG_ADDR_WIDTH];
   
   assign  addr_good= (reg_addr<NUM_REGS_USED);
   assign  tag_hit = tag_addr == `RCP_BLOCK_ADDR;
   
  /* get the info from the registers */
   assign rcp_rate = reg_file[`RCP_RATE_0];

   always @(posedge clk) begin
      // Never modify the address/src
      reg_rd_wr_L_out <= reg_rd_wr_L_in;
      reg_addr_out <= reg_addr_in;
      reg_src_out <= reg_src_in;

      if(reset) begin
         reg_req_out                     <= 1'b0;
         reg_ack_out                     <= 1'b0;
         reg_data_out                    <= 'h0;

         for(i=0; i<NUM_REGS_USED; i=i+1) begin
            reg_file[i] <= 0;
         end

         
      end
      else begin
         // Register accesses
         if(reg_req_in && tag_hit) begin
            if(addr_good) begin
               reg_data_out <= reg_file[addr];

               if (!reg_rd_wr_L_in)
                  reg_file[addr] <= reg_data_in;
            end
            else begin
               reg_data_out <= 32'hdead_beef;
            end

            reg_ack_out <= 1'b1;
         end
         else begin
            reg_ack_out <= reg_ack_in;
            reg_data_out <= reg_data_in;
         end
         reg_req_out <= reg_req_in;

	 reg_file[`RCP_MAC_0_RTT_LO]      <= mac_0_rtt_L;
	 reg_file[`RCP_MAC_0_RTT_HI]      <= mac_0_rtt_H;
	 reg_file[`RCP_MAC_0_NUM_BYTES_LO] <= mac_0_num_byte_L;
	 reg_file[`RCP_MAC_0_NUM_BYTES_HI] <= mac_0_num_byte_H;
	 reg_file[`RCP_MAC_0_NUM_RCP]    <= mac_0_num_rcp;

	 reg_file[`RCP_MAC_1_RTT_LO]      <= mac_1_rtt_L;
	 reg_file[`RCP_MAC_1_RTT_HI]      <= mac_1_rtt_H;
	 reg_file[`RCP_MAC_1_NUM_BYTES_LO] <= mac_1_num_byte_L;
	 reg_file[`RCP_MAC_1_NUM_BYTES_HI] <= mac_1_num_byte_H;
	 reg_file[`RCP_MAC_1_NUM_RCP]    <= mac_1_num_rcp;

	 reg_file[`RCP_MAC_2_RTT_LO]      <= mac_2_rtt_L;
	 reg_file[`RCP_MAC_2_RTT_HI]      <= mac_2_rtt_H;
	 reg_file[`RCP_MAC_2_NUM_BYTES_LO] <= mac_2_num_byte_L;
	 reg_file[`RCP_MAC_2_NUM_BYTES_HI] <= mac_2_num_byte_H;
	 reg_file[`RCP_MAC_2_NUM_RCP]    <= mac_2_num_rcp;

	 reg_file[`RCP_MAC_3_RTT_LO]      <= mac_3_rtt_L;
	 reg_file[`RCP_MAC_3_RTT_HI]      <= mac_3_rtt_H;
	 reg_file[`RCP_MAC_3_NUM_BYTES_LO] <= mac_3_num_byte_L;
	 reg_file[`RCP_MAC_3_NUM_BYTES_HI] <= mac_3_num_byte_H;
	 reg_file[`RCP_MAC_3_NUM_RCP]    <= mac_3_num_rcp;
              

    
      end // else: !if(reset)
   end // always @ (posedge clk)


endmodule // rcp_regs
