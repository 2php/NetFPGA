///////////////////////////////////////////////////////////////////////////////
// $Id: preprocess_control.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: preprocess_control.v
// Project: NF2.1
// Description: asserts the appropriate signals for parsing the headers
//
///////////////////////////////////////////////////////////////////////////////

  module rcp_parser_control
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
      )
   (// --- Interface to the previous stage
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,

    // --- Interface to other preprocess blocks
    output reg                         word_RCP_FRATE,
    output reg                         word_RCP_RTT,
    output reg                         word_RCP_FIRST,
    output reg                         word_RCP_THIRD,
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
   
   //------------------ Internal Parameter ---------------------------
   
   localparam HDRS             = 1;
   localparam WORD_1           = 2;
   localparam WORD_2           = 4;
   localparam WORD_3           = 8;
   localparam WORD_4           = 16;
   localparam WORD_5           = 32;
   localparam WAIT_EOP         = 64;

   //---------------------- Wires/Regs -------------------------------
   reg [6:0]                            state, state_next;
       
   //------------------------ Logic ----------------------------------

   always @(*) begin
      state_next = state;
      word_RCP_FRATE = 0;
      word_RCP_RTT = 0;
      word_RCP_FIRST = 0;
      word_RCP_THIRD = 0;
      
      
      case(state)
        HDRS: begin
	   if(in_ctrl==8'hFF && in_wr) begin
	      word_RCP_FIRST = 1;
	      state_next = HDRS;
	   end
	        
           if(in_ctrl==0 && in_wr) begin
              state_next     = WORD_1;
           end
        end

        WORD_1: begin
           if(in_wr) begin
              state_next = WORD_2;
           end
	   else
	     state_next = WORD_1;
	end

        WORD_2: begin
           if(in_wr) begin
              word_RCP_THIRD = 1;
              state_next = WORD_3;
           end
	   else
	     state_next = WORD_2;
	end

        WORD_3: begin
           if(in_wr) begin
	      state_next = WORD_4;
           end
	   else
	     state_next = WORD_3;
	end

        WORD_4: begin
           if(in_wr) begin
              word_RCP_FRATE = 1;
	      state_next = WORD_5;
           end
	   else
	     state_next = WORD_4;
	end

	WORD_5: begin
	   if(in_wr) begin
	      word_RCP_RTT = 1;
	      state_next = WAIT_EOP;
	   end
	   else
	     state_next = WORD_5;
	end
	
        WAIT_EOP: begin
           if(in_ctrl!=0 & in_wr) begin
              state_next = HDRS;
           end
	   else
	     state_next = WAIT_EOP;
	end
      endcase // case(state)
   end // always @ (*)
   
   always@(posedge clk) begin
      if(reset) begin
         state <= HDRS;
      end
      else begin
         state <= state_next;
      end
   end

endmodule // rcp_parser_control

