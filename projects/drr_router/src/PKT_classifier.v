  module PKT_classifier
#(parameter DATA_WIDTH = 64,
  parameter CTRL_WIDTH=DATA_WIDTH/8,
  parameter UDP_REG_SRC_WIDTH = 2
)
(
    output     [DATA_WIDTH-1:0]        out_data,
    output     [CTRL_WIDTH-1:0]        out_ctrl,
    input                              out_rdy,
    output reg                         out_wr,

    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    output                             in_rdy,
    input                              in_wr,

    // --- Register interface
    input                                 reg_req_in,
    input                                 reg_ack_in,
    input                                 reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]      reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]     reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]        reg_src_in,

    output reg                            reg_req_out,
    output reg                            reg_ack_out,
    output reg                            reg_rd_wr_L_out,
    output reg [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
    output reg [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
    output reg [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

    input                              clk,
    input                              reset
);

   //------------------- Internal parameters -----------------
   localparam 	IDLE	        = 0;
   localparam	READ_HDR	= 1;
   localparam	WRITE_HDR	= 2;
   localparam	WRITE_REST	= 3;
   localparam	STORE_HDR	= 4;
   localparam	STORE_MAC1	= 5;
   localparam	STORE_MAC2	= 6;
   localparam	RESTORE_HDR	= 7;
   localparam	RESTORE_MAC1	= 8;
   localparam	RESTORE_MAC2	= 9;

   //--------------- Regs/Wires ------------------------------

   reg	[3:0]			state;
   reg	[3:0]			state_next;

   wire [DATA_WIDTH-1:0] 	in_fifo_data_out;
   wire [CTRL_WIDTH-1:0] 	in_fifo_ctrl_out;
   reg  [DATA_WIDTH-1:0] 	out_fifo_data_in;
   reg  [CTRL_WIDTH-1:0] 	out_fifo_ctrl_in;
   wire				in_fifo_nearly_full;
   wire				out_fifo_nearly_full;
   wire				in_fifo_empty;
   wire				out_fifo_empty;
   wire				out_fifo_rd_en;

   reg				wr_en;
   reg				rd_en;
   wire				Forward_OK;

   reg [4:0]				counter_updates;
   reg [4:0]				update_next;
   wire[4*`CPCI_NF2_DATA_WIDTH-1 : 0]	software_regs;
   wire[3*`CPCI_NF2_DATA_WIDTH-1 : 0]	hardware_regs;

   wire      				reg_req_out_wire;
   wire      				reg_ack_out_wire;
   wire      				reg_rd_wr_L_out_wire;
   wire [`UDP_REG_ADDR_WIDTH-1:0]  	reg_addr_out_wire;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]   	reg_data_out_wire;
   wire [UDP_REG_SRC_WIDTH-1:0]   	reg_src_out_wire;

   reg	[DATA_WIDTH-1:0]		hdr_data_ff;
   reg	[DATA_WIDTH-1:0]		hdr_data_ff_next;
   reg	[CTRL_WIDTH-1:0]		hdr_ctrl_ff;
   reg	[CTRL_WIDTH-1:0]		hdr_ctrl_ff_next;

   reg	[DATA_WIDTH-1:0]		mac1_data_ff;
   reg	[DATA_WIDTH-1:0]		mac1_data_ff_next;
   reg	[CTRL_WIDTH-1:0]		mac1_ctrl_ff;
   reg	[CTRL_WIDTH-1:0]		mac1_ctrl_ff_next;

   reg	[DATA_WIDTH-1:0]		mac2_data_ff;
   reg	[DATA_WIDTH-1:0]		mac2_data_ff_next;
   reg	[CTRL_WIDTH-1:0]		mac2_ctrl_ff;
   reg	[CTRL_WIDTH-1:0]		mac2_ctrl_ff_next;

   wire	[2:0]				cur_src;

   wire					Policy;
   wire	[2:0]				tos0;
   wire	[2:0]				tos1;
   wire	[2:0]				tos2;
   wire [2:0]				istos;

   //----------------------- Module --------------------------

   small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(5),
       .PROG_FULL_THRESHOLD(31))
   input_fifo
     (.dout         ({in_fifo_ctrl_out, in_fifo_data_out}),
      .full         (),
      .nearly_full  (in_fifo_nearly_full),
      .empty        (in_fifo_empty),
      .din          ({in_ctrl, in_data}),
      .wr_en        (in_wr),
      .rd_en        (rd_en),
      .reset        (reset),
      .clk          (clk));

   small_fifo 
	#(.WIDTH(CTRL_WIDTH+DATA_WIDTH),
	.MAX_DEPTH_BITS(5),
	.PROG_FULL_THRESHOLD(31))
      output_fifo
        (.din           ({out_fifo_ctrl_in, out_fifo_data_in}),  // Data in
         .wr_en         (wr_en),             // Write enable
         .rd_en         (out_fifo_rd_en),    // Read the next word 
         .dout          ({out_ctrl, out_data}),
         .full          (),
         .nearly_full   (out_fifo_nearly_full),
         .empty         (out_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

generic_regs #( 
	.UDP_REG_SRC_WIDTH	(UDP_REG_SRC_WIDTH),                       
	.TAG			(`DRR_QCLASS_BLOCK_ADDR),                      
	.REG_ADDR_WIDTH 	(`DRR_QCLASS_REG_ADDR_WIDTH ),
	.NUM_COUNTERS 		(5),
	.NUM_SOFTWARE_REGS 	(4),
	.NUM_HARDWARE_REGS 	(3),	
	.COUNTER_INPUT_WIDTH 	(1),                      
        .MIN_UPDATE_INTERVAL 	(1)
                                   
  ) QCLASS_regs
    ( .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),
                         
      .reg_req_out       (reg_req_out_wire),
      .reg_ack_out       (reg_ack_out_wire),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out_wire),
      .reg_addr_out      (reg_addr_out_wire),
      .reg_data_out      (reg_data_out_wire),
      .reg_src_out       (reg_src_out_wire),


      .counter_updates	(counter_updates),
      .counter_decrement (5'b00000),

      .software_regs 	(software_regs),

      .hardware_regs	(hardware_regs),

      .clk               (clk),
      .reset             (reset));
   //------------------ Logic ------------------------

   assign in_rdy = !in_fifo_nearly_full;
   assign out_fifo_rd_en = out_rdy && !out_fifo_empty;
   always @(posedge clk) begin
      	out_wr <= reset ? 0 : out_fifo_rd_en;
   end

   assign Forward_OK = (! in_fifo_empty) && (! out_fifo_nearly_full);

   assign Policy = software_regs[0];
   assign tos0 =
	software_regs[1*`CPCI_NF2_DATA_WIDTH + 2 : 1*`CPCI_NF2_DATA_WIDTH];
   assign tos1 =
	software_regs[2*`CPCI_NF2_DATA_WIDTH + 2 : 2*`CPCI_NF2_DATA_WIDTH];
   assign tos2 =
	software_regs[3*`CPCI_NF2_DATA_WIDTH + 2 : 3*`CPCI_NF2_DATA_WIDTH];

   assign hardware_regs[1 *`CPCI_NF2_DATA_WIDTH - 1 : 0 *`CPCI_NF2_DATA_WIDTH] = 
	{8'h50 , 8'h4F , 8'h52 , 8'h54};
   assign hardware_regs[2 *`CPCI_NF2_DATA_WIDTH - 1 : 1 *`CPCI_NF2_DATA_WIDTH] = 
	{8'h54 , 8'h6F , 8'h66 , 8'h53};
   assign hardware_regs[3 *`CPCI_NF2_DATA_WIDTH - 1 : 2 *`CPCI_NF2_DATA_WIDTH] = 
	{28'b0 , state};

   assign istos[0] = in_fifo_data_out[7:5] == tos0;
   assign istos[1] = in_fifo_data_out[7:5] == tos1;
   assign istos[2] = in_fifo_data_out[7:5] == tos2;

   assign cur_src = {1'b0 , in_fifo_data_out[18:17]};

   always @(*) begin

	rd_en = 0;
	wr_en = 0;
	out_fifo_data_in = in_fifo_data_out;
	out_fifo_ctrl_in = in_fifo_ctrl_out;
	state_next = state;
	update_next = 0;
	hdr_ctrl_ff_next = hdr_ctrl_ff;
	hdr_data_ff_next = hdr_data_ff;
	mac1_ctrl_ff_next = mac1_ctrl_ff;
	mac1_data_ff_next = mac1_data_ff;
	mac2_ctrl_ff_next = mac2_ctrl_ff;
	mac2_data_ff_next = mac2_data_ff;

	case (state)
	IDLE: begin
		case ({Forward_OK,Policy})
		   2'b00: begin
			state_next = IDLE;
		   end
		   2'b01: begin
			state_next = IDLE;
		   end
		   2'b10: begin
			state_next = READ_HDR;
		   end
		   2'b11: begin
			state_next = STORE_HDR;
		   end
		endcase
		rd_en = Forward_OK;
	end

	STORE_HDR: begin
	    if (in_fifo_ctrl_out == 8'hFF) begin
		if (! in_fifo_data_out[16]) begin
			hdr_data_ff_next = in_fifo_data_out;
			hdr_ctrl_ff_next = in_fifo_ctrl_out;
			state_next = (in_fifo_empty) ? STORE_HDR : STORE_MAC1;
			rd_en = ! in_fifo_empty;
		end else begin
		    out_fifo_data_in = {in_fifo_data_out[47:32], in_fifo_data_out[15:0],
				 29'b0, 3'b100};
		    out_fifo_ctrl_in = 8'h55;
		    wr_en = !out_fifo_nearly_full;
		    rd_en = 0;
		    state_next = (out_fifo_nearly_full) ? STORE_HDR: WRITE_HDR;
		    update_next[4] = ! out_fifo_nearly_full;
	        end 
	   end else begin
		wr_en = 0;
		rd_en = ! in_fifo_empty;
		state_next = STORE_HDR;
           end
	
	end

	STORE_MAC1: begin
		mac1_data_ff_next = in_fifo_data_out;
		mac1_ctrl_ff_next = in_fifo_ctrl_out;
		state_next = (in_fifo_empty) ? STORE_MAC1 : STORE_MAC2;
		rd_en = ! in_fifo_empty;
	end

	STORE_MAC2: begin
		mac2_data_ff_next = in_fifo_data_out;
		mac2_ctrl_ff_next = in_fifo_ctrl_out;
		case (istos)
		   3'b001: begin
			out_fifo_data_in = {hdr_data_ff[47:32], hdr_data_ff[15:0],
				 29'b0 , 3'b000};
			update_next[0] = ! out_fifo_nearly_full;
		   end
		   3'b010: begin
			out_fifo_data_in = {hdr_data_ff[47:32], hdr_data_ff[15:0],
				 29'b0 , 3'b001};
			update_next[1] = ! out_fifo_nearly_full;
		   end
		   3'b100: begin
			out_fifo_data_in = {hdr_data_ff[47:32], hdr_data_ff[15:0],
				 29'b0 , 3'b010};
			update_next[2] = ! out_fifo_nearly_full;
		   end
		   default: begin
			out_fifo_data_in = {hdr_data_ff[47:32], hdr_data_ff[15:0],
				 29'b0 , 3'b011};
			update_next[3] = ! out_fifo_nearly_full;
		   end
		endcase
		out_fifo_ctrl_in = 8'h55;
		wr_en = ! out_fifo_nearly_full;
		state_next = (out_fifo_nearly_full) ? STORE_MAC2 : RESTORE_HDR;
	end

	RESTORE_HDR: begin
		out_fifo_ctrl_in = hdr_ctrl_ff;
		out_fifo_data_in = hdr_data_ff;
		wr_en = ! out_fifo_nearly_full;
		state_next = (out_fifo_nearly_full) ? RESTORE_HDR : RESTORE_MAC1;
	end

	RESTORE_MAC1: begin
		out_fifo_ctrl_in = mac1_ctrl_ff;
		out_fifo_data_in = mac1_data_ff;
		wr_en = ! out_fifo_nearly_full;
		state_next = (out_fifo_nearly_full) ? RESTORE_MAC1 : RESTORE_MAC2;
	end

	RESTORE_MAC2: begin
		out_fifo_ctrl_in = mac2_ctrl_ff;
		out_fifo_data_in = mac2_data_ff;
		wr_en = Forward_OK;
		rd_en = Forward_OK;
		state_next = (Forward_OK) ? WRITE_REST : RESTORE_MAC2;
	end
	
	READ_HDR: begin
	    if (in_fifo_ctrl_out == 8'hFF) begin
		out_fifo_ctrl_in = 8'h55;
		if (! in_fifo_data_out[16]) begin
		    out_fifo_data_in = {in_fifo_data_out[47:32], in_fifo_data_out[15:0],
				 17'b0, in_fifo_data_out[31:17]};
		    update_next[cur_src] = ! out_fifo_nearly_full;
		end else begin
		    out_fifo_data_in = {in_fifo_data_out[47:32], in_fifo_data_out[15:0],
				 29'b0, 3'b100};
		    update_next[4] = ! out_fifo_nearly_full;
		end
		
		wr_en = !out_fifo_nearly_full;
		rd_en = 0;
		state_next = (out_fifo_nearly_full) ? READ_HDR: WRITE_HDR;
	    end else begin
		wr_en = 0;
		rd_en = ! in_fifo_empty;
		state_next = READ_HDR;
	    end
	end

	WRITE_HDR: begin
		wr_en = Forward_OK;
		rd_en = Forward_OK;
		out_fifo_data_in = in_fifo_data_out;
		out_fifo_ctrl_in = in_fifo_ctrl_out;
		state_next = (in_fifo_ctrl_out == 0) ? WRITE_REST : WRITE_HDR;
	end

	WRITE_REST: begin
		wr_en = (in_fifo_ctrl_out == 0) ? Forward_OK : !out_fifo_nearly_full;
		rd_en = (in_fifo_ctrl_out == 0) ? Forward_OK : 0;
		out_fifo_data_in = in_fifo_data_out;
		out_fifo_ctrl_in = in_fifo_ctrl_out;
		if (in_fifo_ctrl_out == 0)
			state_next = WRITE_REST;
		else if (out_fifo_nearly_full)
			state_next = WRITE_REST;
		else
			state_next = IDLE;
	end

	endcase
   end

always @(posedge clk) begin
	if (reset)
	   state = IDLE;
	else
	   state = state_next;
	hdr_ctrl_ff  = hdr_ctrl_ff_next;
	hdr_data_ff  = hdr_data_ff_next;
	mac1_ctrl_ff = mac1_ctrl_ff_next;
	mac1_data_ff = mac1_data_ff_next;
	mac2_ctrl_ff = mac2_ctrl_ff_next;
	mac2_data_ff = mac2_data_ff_next;
	counter_updates = update_next;
end

always @(posedge clk) begin
      reg_req_out = reg_req_out_wire;
      reg_ack_out = reg_ack_out_wire;
      reg_rd_wr_L_out = reg_rd_wr_L_out_wire;
      reg_addr_out = reg_addr_out_wire;
      reg_data_out = reg_data_out_wire;
      reg_src_out  = reg_src_out_wire;
end

endmodule		
		
