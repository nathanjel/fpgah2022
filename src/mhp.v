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
  output          o_wvalid,
  // uart data
  output          o_wvalid_u,
  output  [7:0]   o_wdata_u
);

//////////////////////////
////// CLOCK
//////////////////////////
reg [31:0]  r_time;
reg [31:0]  r_counter_clock;
localparam CLOCK_DIVIDER = 50000000;

always @(posedge i_clk) begin
  if (i_rst) begin
    r_time           <= 0;
    r_counter_clock  <= 0;
  end
  else begin
    if (r_counter_clock == CLOCK_DIVIDER) begin
      r_counter_clock <= 0;
      r_time <= r_time + 1;
    end else 
      r_counter_clock <= r_counter_clock + 1;
  end
end
//////////////////////////
////// CLOCK
//////////////////////////

//  local regs
reg           done      = 0;
//  read regs
reg           r_req     = 0;
//  write regs
reg   [7:0]   w_data    = 0;
reg           w_valid   = 0;

reg   [7:0]   w_data_u    = 0;
reg           w_valid_u   = 0;


// frame counter 
// if its size is less than 42 bytes

wire [10-1:0] mem_address_for_scs;
wire mem_write_enable_for_scs;
wire [7:0] mem_write_for_scs;

wire mem_write_enable;
wire [10-1:0] mem_address;
wire [7:0] mem_write;
wire [7:0] mem_read;
wire scs_work_completed;

reg mem_enable = 1;
reg mem_ready_for_scs = 0;

bram record_ram(
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

reg [7:0] eth_payload_frame_ram [(2**10)-1:0];
reg [9:0] eth_frame_load_addr;
reg [9:0] eth_frame_send_addr;

reg [5:0] eth_rec_dead_cnt;

//  fsm
reg   [3:0] state       = 0;

localparam  IDLE        = 0;
localparam  READ        = 1;
localparam  READA        = 2;
localparam  READCOMPLETE  = 3;
localparam  WRITE       = 4;
localparam  WRITEA       = 5;
localparam  WRITECOMPLETE = 6;
localparam  PING_REPLY_1 = 7;
localparam  PING_REPLY_2 = 8;

localparam ETH_FRAME_PAYLOAD_MINIMAL_SIZE = 46;

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
        w_valid_u <= 0;
        eth_frame_load_addr <= 0;
        eth_frame_send_addr <= 0;
        eth_rec_dead_cnt <= 0;
        if (i_rready) begin // received frame's payload ready
          r_req   <= 1;     // r_req set before read state, so we can expect valid data in READ state
          state   <= READ;
        end else
          r_req   <= 0;
      end
      // READ: begin
      //   if (i_rready) begin // clear fifo
      //     r_req   <= 1;
      //   end else begin
      //     w_data_u <= i_rdata;
      //     r_req   <= 0;
      //     done    <= 1;
      //     state   <= WRITE;  
      //   end
      // end
      // WRITE: begin    //  write data
      //   if (i_wready) begin
      //     w_valid_u <= 1;
      //     w_valid <= 1;
      //     state   <= IDLE;
      //   end
      // end
      READ: begin
        eth_payload_frame_ram[eth_frame_load_addr] <= i_rdata;
        eth_frame_load_addr <= eth_frame_load_addr + 1;
        r_req <= 0; // complete fifo
        state <= READA; // continue reading
        eth_rec_dead_cnt <= 0;
      end
      READA: begin
        if (i_rready) begin
          state <= READ;
          r_req <= 1;
        end else begin
          eth_rec_dead_cnt <= eth_rec_dead_cnt + 1;
          if (eth_rec_dead_cnt == 6'b000011)
            state <= READCOMPLETE;
        end  
      end
      READCOMPLETE: begin
        state <= IDLE;
        if (done == 0) begin
          // done <= 1;
          state <= PING_REPLY_1;
          eth_frame_send_addr = 0;
        end
      end
      PING_REPLY_1: begin
        w_data_u <= 8'h40;
        w_data <= 0;
        if (i_wready) begin
          w_valid <= 1;
          w_valid_u <= 1;  
          state <= PING_REPLY_2;
          eth_frame_send_addr <= eth_frame_send_addr + 1;
        end
      end
      PING_REPLY_2: begin
        w_valid <= 0;
        w_valid_u <= 1;
        if (eth_frame_send_addr != eth_frame_load_addr) begin
          state <= PING_REPLY_1;
        end else begin
          state <= IDLE;
        end
      end
    endcase
  end
end

assign    o_done   = done;
assign    o_rreq   = r_req;
assign    o_wdata  = w_data;
assign    o_wvalid = w_valid;

assign    o_wdata_u  = w_data_u;
assign    o_wvalid_u = w_valid_u;

assign    p_direction = p_d_type[7];
assign    p_type = p_d_type[6:0];

assign    mem_write_enable = 0 | mem_write_enable_for_scs;
assign    mem_address = 0 | mem_address_for_scs;
assign    mem_write = 0 | mem_write_for_scs;

endmodule
