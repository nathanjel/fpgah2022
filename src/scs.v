module scs
	#(
		parameter RAM_WIDTH 		= 8,
		parameter RAM_ADDR_BITS 	= 8
		// // parameter DATA_FILE 		= "data_file.txt",
		// parameter INIT_START_ADDR 	= 0,
		// parameter INIT_END_ADDR		= 10
	)
	
	(
	input                   reset,
	input							mem_ready,
	output reg                work_complete,
	input							clock,
	output reg						write_enable,
   output reg		[RAM_ADDR_BITS-1:0]	address,
   input 		[RAM_WIDTH-1:0] 	mem_output,
	output reg 	[RAM_WIDTH-1:0] 	mem_input,
	input     	[15:0] payload_len
	);

	reg	[15:0] scs_out;
	
	wire  last_byte;
	wire  pre_last_byte;

	localparam    RESET     = 0;
	localparam	  READY     = 1;
	localparam    STEP1 		= 2;
	localparam    STEP2 		= 3;
	localparam    STEP3 		= 4;
	localparam    STEP4 		= 5;
	localparam    STEP1A 		= 10;
	localparam    STEP2A 		= 11;
	localparam    STEP3A 		= 12;
	localparam    STEP4A 		= 13;
	localparam    LOADA     = 6;
	localparam    LOADAA     = 7;
	localparam    LOADB     = 8;
	localparam    LOADBB     = 9;
	reg [3:0]     state;
	reg 			  mstate;

   //  The forllowing code is only necessary if you wish to initialize the RAM 
   //  contents via an external file (use $readmemb for binary data)
   // initial
      // $readmemh(DATA_FILE, ram_name, INIT_START_ADDR, INIT_END_ADDR);

   always @(posedge clock)
      if (reset) begin
      	state <= RESET;
      	mstate <= 0;
      	write_enable <= 0;
      	mem_input <= 0;
      	work_complete <= 0;
      	address <= 0;
      	scs_out <= 0;
      end else begin
	      	case (state)
	      		RESET: begin
	      			address <= 0;
	      			scs_out <= 0;
	      			work_complete <= 0;
	      			state <= READY;
	      			mem_input <= 0;
	      			write_enable <= 0;	      			
	      		end
	      		READY: begin
	      			if (mem_ready) begin
	      				state <= STEP1;
	      			end
	      		end
	      		STEP1: begin
	      			state <= last_byte ? LOADA : STEP1A;
	      		end
	      		STEP1A: begin
	      			if (pre_last_byte)
	      				scs_out <= scs_out + mem_output;
	      			address <= address + 1;
	      			state <= STEP2;
	      		end
	      		STEP2: begin
	      			state <= last_byte ? LOADA : STEP2A;
	      		end
	      		STEP2A: begin
	      			if (pre_last_byte)
	      				scs_out <= scs_out + {mem_output, 1'b0};
	      			address <= address + 1;
	      			state <= STEP3;
	      		end
	      		STEP3: begin
	      			state <= last_byte ? LOADA : STEP3A;
	      		end
	      		STEP3A: begin
	      			if (pre_last_byte)
	      				scs_out <= scs_out + {mem_output, 2'b0};
	      			address <= address + 1;
	      			state <= STEP4;
	      		end
	      		STEP4: begin
	      			state <= last_byte ? LOADA : STEP4A;
	      		end
	      		STEP4A: begin
	      			if (pre_last_byte)
	      				scs_out <= scs_out + {mem_output, 3'b0};
	      			address <= address + 1;
	      			state <= STEP1;
	      		end
	      		LOADA: begin
	      			mem_input <= scs_out[15:8];
	      			// address <= address + 1;
	      			state <= LOADAA;
	      		end
	      		LOADAA: begin
	      			write_enable <= 1;
	      			state <= LOADB;
	      		end
	      		LOADB: begin
	      			address <= address + 1;
	      			mem_input <= scs_out[7:0];
	      			write_enable <= 0;
	      			state <= LOADBB;
	      		end
	      		LOADBB: begin
	      			// address <= address + 1;
	      			write_enable <= 1;
	      			work_complete <= 1;
	      			state <= RESET;
	      		end
	      	endcase
      end

assign last_byte = payload_len == address;
assign pre_last_byte = (payload_len-1) == address;

endmodule