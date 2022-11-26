`timescale 1ns/1ns

module mhp(
  //  sys
  input           i_clk,      i_rst,
  //  ctrl
  input           i_send,
  output          o_done,
  //  eth
  input   [7:0]   i_rdata,
  input           i_rready,
  output          o_rreq,
  output  [7:0]   o_wdata,
  input           i_wready,
  output          o_wvalid 
);


//  local regs
reg           done      = 0;
//  read regs
reg           r_req     = 0;
//  write regs
reg   [7:0]   w_data    = 0;
reg           w_valid   = 0;

//  fsm
reg   [3:0] state       = 0;
localparam  IDLE        = 0;
localparam  READ        = 1;
localparam  WRITE       = 2;

// frame counter 
// if its size is less than 42 bytes

wire [10-1:0] mem_address_for_scs;
wire mem_write_enable_for_scs;
wire [7:0] mem_write_for_scs;

wire mem_write_enable = 0;
wire [10-1:0] mem_address;
wire [7:0] mem_write;
wire [7:0] mem_read;
wire scs_work_completed;

reg mem_enable = 1;
reg mem_ready_for_scs = 0;

bram recram(
  .clock(i_clk),
  .ram_enable(mem_enable),
  .write_enable(mem_write_enable),
  .address     (mem_address),
  .input_data  (mem_write),
  .output_data (mem_read)
);

scs cscalc(
  .reset(i_rst),
  .mem_ready(mem_ready_for_scs),
  .work_complete(scs_work_completed),
  .clock(i_clk),
  .write_enable(mem_write_enable_for_scs),
  .address(mem_address_for_scs),
  .mem_output(mem_read),
  .mem_input(mem_write_for_scs)
);

reg   [15:0]  p_dst_addr = 16'hffff;
reg   [15:0]  p_src_addr = 16'h0000;
reg   [15:0]  p_size = 0;
reg   [7:0]   p_d_type = 0;
reg   [15:0]  p_scs = 0;
reg   [5:0]   load_addr = 0;

wire  p_direction;
wire  [6:0] p_type;

always @(posedge i_clk) begin
  if (i_rst) begin
    done    <= 0;
    w_data  <= 0;
    w_valid <= 0;
    state   <= IDLE;
  end
  else begin
    case (state)
      IDLE: begin
        load_addr = 0;
        w_data  <= 0;
        w_valid <= 0;
        done    <= 0;
        if (i_rready) begin // received frame's payload ready
          r_req   <= 1;     // r_req set before read state, so we can expect valid data in READ state
          state   <= READ;
        end else
          r_req   <= 0;
      end
      READ: begin
        if (i_rready) // clear fifo
          r_req   <= 1;
        else begin
          r_req   <= 0;
          done    <= 1;
          state   <= WRITE;
        end
      end
      WRITE: begin    //  write data
        if (i_wready) begin
          w_valid <= 1;
          state   <=  IDLE;
        end
      end
    endcase
  end
end

assign    o_done   = done;
assign    o_rreq   = r_req;
assign    o_wdata  = w_data;
assign    o_wvalid = w_valid;

assign    p_direction = p_d_type[7];
assign    p_type = p_d_type[6:0];

assign    mem_write_enable = 0 | mem_write_enable_for_scs;
assign    mem_address = 0 | mem_address_for_scs;
assign    mem_write = 0 | mem_write_for_scs;

endmodule
