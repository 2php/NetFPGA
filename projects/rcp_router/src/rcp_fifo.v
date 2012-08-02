


module rcp_fifo
 #(parameter WIDTH=8, 
   parameter DEPTH=4)
 (      
	output  [WIDTH-1:0]      out_data,
	output                   empty,
	output                   full,
	input   [WIDTH-1:0]      in_data,
	input                    enq,
	input                    deq,
	input                    clk,
	input                    reset
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
   
   
   //--------------------- Internal Parameter-------------------------
   localparam ADD_WIDTH = log2(DEPTH);

   //--------------------- Internal registers-------------------------
   reg [WIDTH-1:0]            entry [DEPTH-1:0] /* synthesis syn_ramstyle=block_ram */ ;
   reg [ADD_WIDTH-1:0] 	      head, tail;
   reg 			      full_reg;
   reg 			      empty_reg;


  assign out_data = entry[head];

   always @(posedge clk)
     begin
	if (reset)
	  begin
             head <= 0;
             tail <= 0;
	     
             full_reg <= 0;
             empty_reg <= 1;
	  end
	else
	  begin
             if (enq)
               begin
		  empty_reg <= 0;
		  
		  // If queue is full, but dequeue signal is active,  it still can store new data
		  if (!full_reg | deq) 
		    begin
		       entry[tail] <= in_data;
		       
		       if (tail == DEPTH-1)
			 tail <= 0;
		       else
			 tail <= tail + 1;
                       if (!deq & ((head == (tail+1)) || (head == 0 && tail == DEPTH-1))) 
			 full_reg <= 1;
		    end
               end // if (enq)
             if (deq)
               begin
		  if (!enq)
		    full_reg <= 0;
                  if (!empty_reg)
		    begin
		       if (head == DEPTH-1)
			 head <= 0;
		       else
			 head <=  head + 1;
                       if (!enq & ((tail == (head+1)) || ((tail == 0) && (head == DEPTH-1))))
			 empty_reg <= 1;
		    end
               end // if (deq)
          end // else: !if(Reset)
     end // always @ (posedge Clk)
   
   
   assign full = full_reg;
   assign empty = empty_reg;  



endmodule // rcp_fifo
