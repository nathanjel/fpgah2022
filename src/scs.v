module scs
	#(
		parameter RAM_WIDTH 		= 8,
		parameter RAM_ADDR_BITS 	= 10
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
   output 		[RAM_ADDR_BITS-1:0]	address,
   input 		[RAM_WIDTH-1:0] 	mem_output,
	output reg 	[RAM_WIDTH-1:0] 	mem_input
	);

	reg	[RAM_ADDR_BITS-1:0] mem_addr;
	reg	[15:0] scs_out;
	reg 	[15:0] payload_len;
	wire  last_byte;
	wire  payload_byte_1, payload_byte_2;

	localparam  PAYLOAD_ADDR_1 = 4;
	localparam  PAYLOAD_ADDR_2 = 5;
	
	localparam    RESET     = 0;
	localparam	  READY     = 1;
	localparam    STEP1 		= 2;
	localparam    STEP2 		= 3;
	localparam    STEP3 		= 4;
	localparam    STEP4 		= 5;
	localparam    LOADA     = 6;
	localparam    LOADB     = 7;
	reg [2:0]     state     = RESET;
	reg 			  mstate    = 0;

   //  The forllowing code is only necessary if you wish to initialize the RAM 
   //  contents via an external file (use $readmemb for binary data)
   // initial
      // $readmemh(DATA_FILE, ram_name, INIT_START_ADDR, INIT_END_ADDR);

   always @(posedge clock)
      if (reset) begin
      	state <= RESET;
      end else begin
      	if (mstate) begin
	      	case (state)
	      		RESET: begin
	      			mem_addr <= 0;
	      			scs_out <= 0;
	      			work_complete <= 0;
	      			payload_len <= 0;
	      			state <= READY;
	      			mem_input <= 0;
	      		end
	      		READY: begin
	      			if (mem_ready)
	      				state <= STEP1;
	      		end
	      		STEP1: begin
	      			scs_out <= scs_out + mem_output;
	      			state <= last_byte ? LOADA : STEP2;
	      		end
	      		STEP2: begin
	      			scs_out <= scs_out + {mem_output, 1'b0};
	      			state <= last_byte ? LOADA : STEP3;
	      		end
	      		STEP3: begin
	      			scs_out <= scs_out + {mem_output, 2'b0};
	      			state <= last_byte ? LOADA : STEP4;
	      		end
	      		STEP4: begin
	      			scs_out <= scs_out + {mem_output, 3'b0};
	      			state <= last_byte ? LOADA : STEP1;
	      		end
	      		LOADA: begin
	      			mem_input <= scs_out[7:0];
	      			write_enable <= 1;
	      			state <= LOADB;
	      		end
	      		LOADB: begin
	      			mem_input <= scs_out[15:8];
	      			write_enable <= 1;
	      			work_complete <= 1;
	      			state <= RESET;
	      		end
	      	endcase
	      end else begin
	      	mstate <= ~mstate;
	      	write_enable <= 0;
	      	if (state != RESET && state != READY)
	      		mem_addr <= mem_addr + 1;
	      end
      end

assign address = mem_addr;
assign last_byte = payload_len == mem_addr;
assign payload_byte_1 = mem_addr == PAYLOAD_ADDR_1;
assign payload_byte_2 = mem_addr == PAYLOAD_ADDR_2;

endmodule