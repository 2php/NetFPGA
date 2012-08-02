  module generic_DRR
#(parameter DATA_WIDTH = 64,
  parameter CTRL_WIDTH=DATA_WIDTH/8,
  parameter NUM_OF_PRIORITY_LEVEL = 5,
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


   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2
   //------------------- Internal parameters -----------------
   localparam 	IDLE	        = 0;
   localparam	READ_PRI_HDR	= 1;
   localparam	DROP_DECISION	= 2;
   localparam	STORE_IN_FIFO	= 3;
   localparam	STORE_REST	= 4;
   localparam	DROP		= 5;
   localparam	DROP_REST	= 6;

   localparam	ROUND_ROBIN	= 0;
   localparam	PUT_FROM_DRRQ	= 1;
   localparam	PUT_FROM_FSM3	= 2;
   localparam	REMOVE_REQ	= 3;
   localparam	UPDATE_FSM3_REQ = 4;
   localparam	RST		= 7;

   localparam	WAIT_FOR_RES	= 1;
   localparam	READ_REQUEST	= 2;
   localparam	SERVE		= 3;
   localparam	SERVE_REST	= 4;
   localparam	POST_PROCESS	= 5;
   localparam	CHECK_CREDIT	= 6;

   localparam	LOG_QUEUE_NUM	= log2(NUM_OF_PRIORITY_LEVEL);

   //----------------------- Regs/Wires ----------------------

   reg	[2:0]			 state1;
   reg	[2:0]			 state1_next;

   reg	[2:0]			 state2;
   reg	[2:0]			 state2_next;

   reg	[2:0]			 state3;
   reg	[2:0]			 state3_next;

   reg [LOG_QUEUE_NUM-1:0]	 DRR_src;
   reg [LOG_QUEUE_NUM-1:0]	 DRR_src_next;

   wire [DATA_WIDTH-1:0] 	in_fifo_data_out;
   wire [CTRL_WIDTH-1:0] 	in_fifo_ctrl_out;
   wire				in_fifo_nearly_full;
   wire				in_fifo_empty;
   reg				in_fifo_rd_en;

   reg  [NUM_OF_PRIORITY_LEVEL-1:0]        DRR_wr_en;
   reg  [NUM_OF_PRIORITY_LEVEL-1:0]        DRR_rd_en;
   reg  [NUM_OF_PRIORITY_LEVEL-1:0]        DRR_rd_en2;
   wire  [NUM_OF_PRIORITY_LEVEL-1:0]       DRR_rd_en_combined;
   wire [NUM_OF_PRIORITY_LEVEL-1:0]        DRR_fifo_empty;
   wire [NUM_OF_PRIORITY_LEVEL-1:0]        DRR_fifo_nearly_full	;
   wire [DATA_WIDTH-1:0]         DRR_fifo_data_out	[0:NUM_OF_PRIORITY_LEVEL-1];
   wire [CTRL_WIDTH-1:0]         DRR_fifo_ctrl_out	[0:NUM_OF_PRIORITY_LEVEL-1]; 
   wire [DATA_WIDTH-1:0]         DRR_fifo_data_in;
   wire [CTRL_WIDTH-1:0]         DRR_fifo_ctrl_in;
   wire [9:0]                    DRR_data_count_signal	[0:NUM_OF_PRIORITY_LEVEL-1];
   reg  [9:0]                    DRR_data_count		[0:NUM_OF_PRIORITY_LEVEL-1];
   wire [9:0]                    DRR_empty_space	[0:NUM_OF_PRIORITY_LEVEL-1];
   wire [9:0]                    cur_DRR_empty_space;
   wire				 cur_DRR_has_space;
   wire [DATA_WIDTH-1:0]         cur_DRR_fifo_data_out;
   wire [DATA_WIDTH-1:0]         req_DRR_fifo_data_out;
   wire [DATA_WIDTH-1:0]         cur_DRR_dout;
   wire [CTRL_WIDTH-1:0]         cur_DRR_cout;

   reg                           request_rd_en;
   reg				 request_wr_en;
   wire                          request_fifo_empty;
   wire                          request_fifo_nearly_full;
   reg [LOG_QUEUE_NUM-1:0]       request_fifo_queue_num_in;
   reg [15:0]         		 request_fifo_byte_num_in;
   reg [15:0]		         request_fifo_bucket_num_in;
   wire [LOG_QUEUE_NUM-1:0]      request_fifo_queue_num_out;
   wire [15:0]         		 request_fifo_byte_num_out;
   wire [15:0]		         request_fifo_bucket_num_out;

   reg [LOG_QUEUE_NUM-1:0]       request_fifo_queue_num_next;
   reg [15:0]         		 request_fifo_byte_num_next;
   reg [15:0]		         request_fifo_bucket_num_next;
   reg				 request_fifo_addel_next;
   reg [LOG_QUEUE_NUM-1:0]       request_fifo_queue_num_temp;
   reg [15:0]         		 request_fifo_byte_num_temp;
   reg [15:0]		         request_fifo_bucket_num_temp;
   reg				 request_fifo_addel;

   reg  [LOG_QUEUE_NUM-1:0]      request_fifo_queue_num_fixed;
   reg  [15:0]         		 request_fifo_byte_num_fixed;
   reg  [15:0]		         request_fifo_bucket_num_fixed;
   reg  [LOG_QUEUE_NUM-1:0]      request_fifo_queue_num_fixed_next;
   reg  [15:0]         		 request_fifo_byte_num_fixed_next;
   reg  [15:0]		         request_fifo_bucket_num_fixed_next;

   wire [DATA_WIDTH-1:0] 	 out_fifo_data_in;
   wire [CTRL_WIDTH-1:0] 	 out_fifo_ctrl_in;
   wire				 out_fifo_nearly_full;
   wire				 out_fifo_empty;
   wire				 out_fifo_rd_en;
   reg				 out_fifo_wr_en;  

   reg [LOG_QUEUE_NUM-1:0]	 counter;
   reg [LOG_QUEUE_NUM-1:0]	 counter_next;

   reg  [NUM_OF_PRIORITY_LEVEL-1:0]	request_in_queue_map;
   reg  [NUM_OF_PRIORITY_LEVEL-1:0]	request_in_queue_map_next;
   wire					add_next_fifo;

   reg				request;
   reg				request_next;
   reg				clear;
   reg				clear_next;
   reg				request_fifo_refresh;
   wire				sr_din;

   reg	[31:0]			slow_factor;
   reg	[31:0]			slow_factor_next;
   wire	[31:0]			slow_factor_sw;
   wire [15:0]		        cur_wsum;
   reg [15:0]		        added_bucket_num;
   reg [15:0]		        subtracted_bucket_num;
   reg [15:0]		        added_bucket_num_next;
   reg [15:0]		        subtracted_bucket_num_next;
   wire [15:0]		        double_sub;
   wire [15:0]		        double_byte;
   wire				Forward_OK;
   wire				count_zero;
   wire				terminate;
   reg  [31:0]	 		count;
   reg  [31:0]	 		count_next;
   reg  [15:0]	 		word_count;
   reg  [15:0]	 		word_count_next;

 
   wire[(NUM_OF_PRIORITY_LEVEL+2)*`CPCI_NF2_DATA_WIDTH-1 : 0]	software_regs;
   wire[(NUM_OF_PRIORITY_LEVEL+5)*`CPCI_NF2_DATA_WIDTH-1 : 0]	hardware_regs;
   reg [NUM_OF_PRIORITY_LEVEL-1:0]				update_next;
   reg [NUM_OF_PRIORITY_LEVEL-1:0]				counter_updates;

   wire [`CPCI_NF2_DATA_WIDTH-1 : 0]	wgt [0:NUM_OF_PRIORITY_LEVEL-1];

   wire      				reg_req_out_wire;
   wire      				reg_ack_out_wire;
   wire      				reg_rd_wr_L_out_wire;
   wire [`UDP_REG_ADDR_WIDTH-1:0]  	reg_addr_out_wire;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]   	reg_data_out_wire;
   wire [UDP_REG_SRC_WIDTH-1:0]   	reg_src_out_wire;

   reg					set_return;
   reg					set_return_next;

   integer				j;

   //----------------------- Module --------------------------
generate
begin: DRR_Q
genvar i;
  for (i=0; i<NUM_OF_PRIORITY_LEVEL; i=i+1) begin: DF_gen
     fifo_1024x72 DRR_FIFO (
	.clk		(clk),
	.din		({DRR_fifo_ctrl_in, DRR_fifo_data_in}), // Bus [71 : 0] 
	.rd_en		(DRR_rd_en_combined[i]),
	.rst		(reset),
	.wr_en		(DRR_wr_en[i]),
	.almost_full	(DRR_fifo_nearly_full[i]),
	.data_count	(DRR_data_count_signal[i]), // Bus [9 : 0] 
	.dout		({DRR_fifo_ctrl_out[i], DRR_fifo_data_out[i]}), // Bus [71 : 0] 
	.empty		(DRR_fifo_empty[i]),
	.full		()
      );

  end
end
endgenerate

   small_fifo
     #(.WIDTH(16+16+LOG_QUEUE_NUM),
       .MAX_DEPTH_BITS(5),
       .PROG_FULL_THRESHOLD(31))
   request_fifo
     (.dout         ({request_fifo_byte_num_out,
		      request_fifo_bucket_num_out,
		      request_fifo_queue_num_out}),
      .full         (),
      .nearly_full  (request_fifo_nearly_full),
      .empty        (request_fifo_empty),
      .din          ({request_fifo_byte_num_in,
		      request_fifo_bucket_num_in,
		      request_fifo_queue_num_in}),
      .wr_en        (request_wr_en),
      .rd_en        (request_rd_en),
      .reset        (reset),
      .clk          (clk)
    );

   small_fifo
     #(.WIDTH(DATA_WIDTH+CTRL_WIDTH),
       .MAX_DEPTH_BITS(4),
       .PROG_FULL_THRESHOLD(15))
   input_fifo
     (.dout         ({in_fifo_ctrl_out, in_fifo_data_out}),
      .full         (),
      .nearly_full  (in_fifo_nearly_full),
      .empty        (in_fifo_empty),
      .din          ({in_ctrl, in_data}),
      .wr_en        (in_wr),
      .rd_en        (in_fifo_rd_en),
      .reset        (reset),
      .clk          (clk));

   small_fifo 
	#(.WIDTH(CTRL_WIDTH+DATA_WIDTH),
	.MAX_DEPTH_BITS(4),
	.PROG_FULL_THRESHOLD(15))
      output_fifo
        (.din           ({out_fifo_ctrl_in, out_fifo_data_in}),  // Data in
         .wr_en         (out_fifo_wr_en),             // Write enable
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
	.TAG			(`DRR_OQ_BLOCK_ADDR),                      
	.REG_ADDR_WIDTH 	(`DRR_OQ_REG_ADDR_WIDTH ),
	.NUM_COUNTERS 		(5),
	.NUM_SOFTWARE_REGS 	(7),
	.NUM_HARDWARE_REGS 	(10)
 ) 
DRR_regs
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


      .software_regs 	(software_regs),

      .hardware_regs	(hardware_regs),

      .counter_updates	(counter_updates),
      .counter_decrement (5'b00000),

      .clk               (clk),
      .reset             (reset));
   //------------------ Logic ------------------------

   assign in_rdy = ! in_fifo_nearly_full;
   assign out_fifo_rd_en = out_rdy && !out_fifo_empty;
   always @(posedge clk) begin
      	out_wr <= reset ? 0 : out_fifo_rd_en;
   end

   assign DRR_rd_en_combined = DRR_rd_en | DRR_rd_en2;

   assign slow_factor_sw =
	software_regs[1*`CPCI_NF2_DATA_WIDTH - 1 : 0*`CPCI_NF2_DATA_WIDTH] - 1;

generate
begin: REGS_GEN
genvar i;
  for (i=0; i<NUM_OF_PRIORITY_LEVEL; i=i+1) begin: REG_GEN_LP
   assign wgt[i] =
	software_regs[(i+2)*`CPCI_NF2_DATA_WIDTH - 1 : (i+1)*`CPCI_NF2_DATA_WIDTH];
   assign hardware_regs[(i+1)*`CPCI_NF2_DATA_WIDTH - 1 : i*`CPCI_NF2_DATA_WIDTH] =
   	{22'b0 , DRR_data_count[i]};
   end
end
endgenerate

   assign hardware_regs[(NUM_OF_PRIORITY_LEVEL + 1) *`CPCI_NF2_DATA_WIDTH - 1 : 
  	NUM_OF_PRIORITY_LEVEL *`CPCI_NF2_DATA_WIDTH] = {29'b0 , state1};
   assign hardware_regs[(NUM_OF_PRIORITY_LEVEL + 2) *`CPCI_NF2_DATA_WIDTH - 1 : 
  	(NUM_OF_PRIORITY_LEVEL+1) *`CPCI_NF2_DATA_WIDTH] = {29'b0 , state2};
   assign hardware_regs[(NUM_OF_PRIORITY_LEVEL + 3) *`CPCI_NF2_DATA_WIDTH - 1 : 
  	(NUM_OF_PRIORITY_LEVEL+2) *`CPCI_NF2_DATA_WIDTH] = {29'b0 , state3};
   assign hardware_regs[(NUM_OF_PRIORITY_LEVEL + 4) *`CPCI_NF2_DATA_WIDTH - 1 : 
  	(NUM_OF_PRIORITY_LEVEL+3) *`CPCI_NF2_DATA_WIDTH] = {31'b0 , request_fifo_empty};
   assign hardware_regs[(NUM_OF_PRIORITY_LEVEL + 5) *`CPCI_NF2_DATA_WIDTH - 1 : 
  	(NUM_OF_PRIORITY_LEVEL+4) *`CPCI_NF2_DATA_WIDTH] = count;

always @(posedge clk) begin
	for (j=0 ; j<NUM_OF_PRIORITY_LEVEL; j=j+1) begin: lp1
		DRR_data_count[j] = DRR_data_count_signal[j];
	end
end
   //------------------ FSM1 -------------------------

//////////////////////////////////////////////////////////////////////////////
//  FSM1 controls the in_fifo read side, namely the read signal
//  (in_fifo_rd_en). It receives data from in_fifo_data_out and
//  in_fifo_ctrl_out. Then it will put them into the correct DRR queue.
//  Therefore it should be able to control wr_en signal and DRR_fifo_data_in
//  and DRR_fifo_ctrl_in signals. (So it is controling write side of DRR_fifo).
//  In order to deceide if the FIFO has enough space or not, it will use 
//  the data_count signal.
/////////////////////////////////////////////////////////////////////////////

assign DRR_fifo_data_in = in_fifo_data_out;
assign DRR_fifo_ctrl_in = in_fifo_ctrl_out;

generate
begin: size_calc
genvar i;
  for (i=0; i<NUM_OF_PRIORITY_LEVEL; i=i+1) begin: sz_calc
	assign DRR_empty_space[i] = ~DRR_data_count[i];
  end
end
endgenerate

assign cur_DRR_empty_space = DRR_empty_space[DRR_src];
assign cur_DRR_has_space = {6'b0 , cur_DRR_empty_space} > in_fifo_data_out[63:48];

always @(*) begin
   in_fifo_rd_en = 0;
   DRR_wr_en = 0;
   state1_next = state1;
   DRR_src_next = DRR_src;
   update_next = 0;

   case (state1)
	IDLE: begin
		state1_next = (!in_fifo_empty) ? READ_PRI_HDR : IDLE;
		in_fifo_rd_en = !in_fifo_empty;
	end

	READ_PRI_HDR: begin
		DRR_src_next = in_fifo_data_out[LOG_QUEUE_NUM-1:0];
		state1_next = DROP_DECISION;
	end

	DROP_DECISION: begin
		state1_next = (cur_DRR_has_space) ? STORE_IN_FIFO : DROP;
		update_next[DRR_src] = (cur_DRR_has_space) ? 1'b0 : 1'b1;
	end

	STORE_IN_FIFO: begin
		DRR_wr_en[DRR_src] = !in_fifo_empty;
		in_fifo_rd_en = !in_fifo_empty;
		state1_next = (in_fifo_ctrl_out == 0) ? STORE_REST : STORE_IN_FIFO;
	end

	STORE_REST: begin
		if (in_fifo_ctrl_out != 0) begin
			DRR_wr_en[DRR_src] = 1;
			in_fifo_rd_en = 0;
			state1_next = IDLE;
		end else begin
			DRR_wr_en[DRR_src] = !in_fifo_empty;
			in_fifo_rd_en = !in_fifo_empty;
			state1_next = STORE_REST;
		end
	end

	DROP: begin
		state1_next = (in_fifo_ctrl_out == 0) ? DROP_REST : DROP;
		in_fifo_rd_en = !in_fifo_empty;
	end

	DROP_REST: begin
		in_fifo_rd_en = (in_fifo_ctrl_out == 0) ? !in_fifo_empty : 0;
		state1_next = (in_fifo_ctrl_out == 0) ? DROP_REST : IDLE;
	end
   endcase
end

always @(posedge clk) begin
   if (reset) begin
	state1 = IDLE;
	DRR_src = 0;
   end else begin
   	state1 = state1_next;
   	DRR_src = DRR_src_next;
   end
	counter_updates = update_next;
end

   //-------------- FF between FSM2 and FSM3 -----------------
  ///////////////////////////////////////////////////////////////////////
  // Set Reset flip flop with input-output connected together.
  // FSM3 informs FSM2 of finishing its job with the current queue and
  // ask it to return the current queue to request fifo, if necessary.
  ///////////////////////////////////////////////////////////////////////
//
always @(posedge clk or posedge request or posedge clear) begin

	if (request)
		request_fifo_refresh = 1;
	else if (clear)
		request_fifo_refresh = 0;
	else
		request_fifo_refresh = sr_din;
end
assign sr_din = request_fifo_refresh;


   //--------------------- FSM2 -----------------------------

///////////////////////////////////////////////////////////////////////////
//  FSM2 handels reading signals from DRR FIFOs, namely DRR_rd_en signals and
//  put the requests that are not in request queue into trequest queue. It keeps
//  track of which prioirty queue (DRR queue) is in request queue through a
//  register called request_in_queue_map and do writiing into DRR queues.
//  Also it communicate with FSM3 via a set-reset FF and whenever FSM3 is done
//  serving a queue, FSM2 has the responsibilty of returning that request back
//  to the request queue....
//////////////////////////////////////////////////////////////////////////

assign add_next_fifo = !request_in_queue_map[counter] && !DRR_fifo_empty[counter];
assign cur_DRR_fifo_data_out = DRR_fifo_data_out[counter];
assign req_DRR_fifo_data_out = DRR_fifo_data_out[request_fifo_queue_num_temp];

always @(*) begin

   clear_next = 0;
   DRR_rd_en = 0;
   request_wr_en = 0;
   state2_next = state2;
   counter_next = counter;
   request_in_queue_map_next = request_in_queue_map;
   request_fifo_queue_num_in = request_fifo_queue_num_temp;
   request_fifo_bucket_num_in = request_fifo_bucket_num_temp;
   request_fifo_byte_num_in = request_fifo_byte_num_temp;

   case (state2)

   RST: begin
	clear_next = 1;
	state2_next = ROUND_ROBIN;
   end

   ROUND_ROBIN: begin
     if (request_fifo_refresh && !request_fifo_addel)
     begin
	counter_next = counter;
	state2_next = PUT_FROM_FSM3;
	clear_next = 1;
     end
     else if (request_fifo_refresh && request_fifo_addel && 
              DRR_fifo_empty[request_fifo_queue_num_temp])
     begin
	state2_next = REMOVE_REQ;
	counter_next = counter;
	clear_next = 1;
     end
     else if (request_fifo_refresh && request_fifo_addel && 
              !DRR_fifo_empty[request_fifo_queue_num_temp])
     begin
	counter_next = counter;
	state2_next = UPDATE_FSM3_REQ;
	DRR_rd_en[request_fifo_queue_num_temp] = 1;
	clear_next = 1;
     end
     else if (add_next_fifo)
     begin
	counter_next = counter;
	state2_next = PUT_FROM_DRRQ;
	DRR_rd_en[counter] = 1;
	clear_next = 0;
     end
     else begin
	counter_next = (counter == NUM_OF_PRIORITY_LEVEL-1) ? 0 : counter + 1;
	state2_next = ROUND_ROBIN;
	clear_next = 0;
     end
   end

   PUT_FROM_DRRQ: begin
	request_wr_en = 1;
	request_fifo_queue_num_in = counter;
	request_fifo_bucket_num_in = 0;
	request_fifo_byte_num_in = cur_DRR_fifo_data_out[47:32];
	request_in_queue_map_next[counter] = 1;
	counter_next = (counter == NUM_OF_PRIORITY_LEVEL-1) ? 0 : counter + 1;
	state2_next = ROUND_ROBIN;
   end

  PUT_FROM_FSM3: begin
	request_wr_en = 1;
	request_fifo_queue_num_in = request_fifo_queue_num_temp;
	request_fifo_bucket_num_in = request_fifo_bucket_num_temp;
	request_fifo_byte_num_in = request_fifo_byte_num_temp;
	counter_next = counter;
	state2_next = ROUND_ROBIN;	
   end

   UPDATE_FSM3_REQ: begin
	request_wr_en = 1;
	request_fifo_queue_num_in = request_fifo_queue_num_temp;
	request_fifo_bucket_num_in = request_fifo_bucket_num_temp;
	request_fifo_byte_num_in = req_DRR_fifo_data_out[47:32];
	state2_next = ROUND_ROBIN;
   end	

   REMOVE_REQ: begin
	request_in_queue_map_next[request_fifo_queue_num_temp] = 0;
	state2_next = ROUND_ROBIN;
   end

   endcase
end

always @(posedge clk) begin
   if (reset) begin
	counter = 0;
	state2 = RST;
	request_in_queue_map = 0;
   end else begin
   	counter = counter_next;
   	state2 = state2_next;
   	request_in_queue_map = request_in_queue_map_next;
   end
	clear = clear_next;
end	
		
   //--------------------- FSM3 -----------------------------

///////////////////////////////////////////////////////////////////////////
//  FSM3 is the FSM responsible for serving packets from DRR queues.
//  It reads the requests from request fifo and increment their credit
//  according to the input weight of that queue. then if that request
//  has enough credit to be served, it starts serving it, otherwise 
//  requests FSM2 to return that request back to request fifo with the
//  incremented credit. at some point that request will gain enough credit
//  and will be served. After FSM3 is finished serving a request, it
//  asks FSM2 to either return the request back to request fifo or just
//  remove the request, depending on wheter that queue has more packets in
//  DRR queue at that time or not.
///////////////////////////////////////////////////////////////////////////


assign cur_wsum = wgt[request_fifo_queue_num_out];
assign cur_DRR_dout = DRR_fifo_data_out[request_fifo_queue_num_fixed];
assign cur_DRR_cout = DRR_fifo_ctrl_out[request_fifo_queue_num_fixed];
assign out_fifo_data_in = cur_DRR_dout;
assign out_fifo_ctrl_in = cur_DRR_cout;
assign terminate = word_count == 1;
assign count_zero = count == 0;
assign Forward_OK = 
(!DRR_fifo_empty[request_fifo_queue_num_fixed]) && (!out_fifo_nearly_full);
assign double_sub = subtracted_bucket_num - cur_DRR_dout[47:32];
assign double_byte = cur_DRR_dout[47:32];

always @(*) begin

   request_rd_en = 0;
   DRR_rd_en2 = 0;
   out_fifo_wr_en = 0;
   count_next = count;
   state3_next = state3;
   word_count_next = word_count;
   request_fifo_bucket_num_next = request_fifo_bucket_num_temp;
   request_fifo_queue_num_next = request_fifo_queue_num_temp;
   request_fifo_byte_num_next = request_fifo_byte_num_temp;
   request_fifo_bucket_num_fixed_next = request_fifo_bucket_num_fixed;
   request_fifo_queue_num_fixed_next = request_fifo_queue_num_fixed;
   request_fifo_byte_num_fixed_next = request_fifo_byte_num_fixed;
   request_fifo_addel_next = request_fifo_addel;
   request_next = request;
   added_bucket_num_next = added_bucket_num;
   subtracted_bucket_num_next = subtracted_bucket_num;
   slow_factor_next = slow_factor;
   set_return_next = set_return;

   case (state3)
   IDLE: begin
	state3_next = (request_fifo_empty) ? IDLE : WAIT_FOR_RES;
	request_rd_en = !request_fifo_empty;
	count_next = slow_factor;
	request_next = 0;
	set_return_next = 0;
	slow_factor_next = slow_factor_sw;
   end

   WAIT_FOR_RES: begin
	state3_next = READ_REQUEST;
	added_bucket_num_next = request_fifo_bucket_num_out + cur_wsum;
	subtracted_bucket_num_next = request_fifo_bucket_num_out + cur_wsum 
		- request_fifo_byte_num_out;
	request_fifo_bucket_num_fixed_next = request_fifo_bucket_num_out;
   	request_fifo_queue_num_fixed_next = request_fifo_queue_num_out;
   	request_fifo_byte_num_fixed_next = request_fifo_byte_num_out;
   end

   READ_REQUEST: begin
	if (added_bucket_num < request_fifo_byte_num_fixed) begin
		request_fifo_bucket_num_next = added_bucket_num;
		request_fifo_queue_num_next = request_fifo_queue_num_fixed;
		request_fifo_byte_num_next = request_fifo_byte_num_fixed;
		request_fifo_addel_next = 0;
		request_next = 1;
		state3_next = IDLE;
	end
	else begin
		state3_next = SERVE;
		DRR_rd_en2[request_fifo_queue_num_fixed] = 1;
	end
   end

   SERVE: begin
	out_fifo_wr_en = Forward_OK;
	DRR_rd_en2[request_fifo_queue_num_fixed] = Forward_OK;
	state3_next = (Forward_OK) ? SERVE_REST : SERVE;
	word_count_next = cur_DRR_dout[47:32];
   end

   SERVE_REST: begin
	count_next = (count == 0) ? slow_factor : count-1;
	casex ({terminate,count_zero})
	   2'bx0: begin
		state3_next = SERVE_REST;
	   end
	   2'b01: begin
		out_fifo_wr_en = Forward_OK;
		DRR_rd_en2[request_fifo_queue_num_fixed] = Forward_OK;
		word_count_next = (Forward_OK) ? word_count - 1 : word_count;
		state3_next = SERVE_REST;
	   end
	   2'b11: begin		
		state3_next = POST_PROCESS;
	   end
	endcase
   end

   POST_PROCESS: begin
	out_fifo_wr_en = ! out_fifo_nearly_full;
	DRR_rd_en2[request_fifo_queue_num_fixed] = Forward_OK;
	set_return_next = ! Forward_OK;
	state3_next = (out_fifo_nearly_full) ? POST_PROCESS : CHECK_CREDIT;
   end

   CHECK_CREDIT: begin
      if (set_return) begin
	  request_next = 1;
	  request_fifo_bucket_num_next = subtracted_bucket_num;
	  request_fifo_queue_num_next = request_fifo_queue_num_fixed;
	  request_fifo_byte_num_next = request_fifo_byte_num_fixed;
	  request_fifo_addel_next = 1;
	  state3_next = IDLE;
	  set_return_next = 0;
      end else begin
	  state3_next = READ_REQUEST;
	  added_bucket_num_next = subtracted_bucket_num;
	  subtracted_bucket_num_next = double_sub;
	  request_fifo_bucket_num_fixed_next = subtracted_bucket_num;
   	  request_fifo_queue_num_fixed_next = request_fifo_queue_num_out;
   	  request_fifo_byte_num_fixed_next = double_byte;
 	  set_return_next = 0;		
      end
    end

   endcase
end

always @(posedge clk) begin
   if (reset) begin
	state3 = IDLE;
   end else begin
	state3 = state3_next;
   end
   count = count_next;
   word_count = word_count_next;
   request_fifo_bucket_num_temp = request_fifo_bucket_num_next;
   request_fifo_queue_num_temp = request_fifo_queue_num_next;
   request_fifo_byte_num_temp = request_fifo_byte_num_next;
   request_fifo_bucket_num_fixed = request_fifo_bucket_num_fixed_next;
   request_fifo_queue_num_fixed = request_fifo_queue_num_fixed_next;
   request_fifo_byte_num_fixed = request_fifo_byte_num_fixed_next;
   request_fifo_addel = request_fifo_addel_next;
   request = request_next;
   added_bucket_num = added_bucket_num_next;
   subtracted_bucket_num = subtracted_bucket_num_next;
   slow_factor = slow_factor_next;
   set_return = set_return_next;
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
