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
reg           done;
//  read regs
reg           r_req;
//  write regs
reg   [7:0]   w_data;
reg           w_valid;

wire  [7:0]   w_data_u;
wire          w_valid_u;


// frame counter 
// if its size is less than 42 bytes

wire [10-1:0] mem_address_for_scs;
wire mem_write_enable_for_scs;
wire [7:0] mem_write_for_scs;

reg [10-1:0] mem_address_for_set;
reg mem_write_enable_for_set;
reg [7:0] mem_write_for_set;

reg [10-1:0] mem_address_for_send;

wire mem_write_enable;
wire [10-1:0] mem_address;
wire [7:0] mem_write;
wire [7:0] mem_read;
wire scs_work_completed;

reg mem_enable;
reg mem_ready_for_scs;

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

reg   [15:0]  p_dst_addr;
reg   [15:0]  p_src_addr;
reg   [15:0]  p_size;
reg   [7:0]   p_d_type;
reg   [15:0]  p_scs;
reg   [5:0]   load_addr;

wire  p_direction;
wire  [6:0] p_type;

reg [7:0] eth_payload_frame_ram [(2**10)-1:0];
reg [7:0] eth_frame_load_addr;
reg [7:0] eth_frame_send_addr;

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
localparam  WAIT_FOR_TCHANGE = 9;
localparam  WRITE_PORT_1 = 10;
localparam  WRITE_PORT_21 = 15;
localparam  WRITE_PORT_3 = 12;
localparam  PREPARE = 13;
localparam  PROCESSING = 14;

reg   [3:0] command   = 0;
localparam  COMMAND_REQ_ADDR  = 3; // x03

reg   e_enable_data_set;
reg   data_set_complete;

// writer
reg [1:0] set_control_state;
localparam SETCONTROL_RESET = 0;
localparam SETCONTROL_1 = 1;
localparam SETCONTROL_2 = 2;
localparam SETCONTROL_3 = 3;

wire [7:0] set_control_wire;
assign set_control_wire = {command, mem_address_for_set[3:0]};
reg [7:0] mem_writes_counter;

always @(posedge i_clk) begin
  if (i_rst) begin
    mem_writes_counter <= 0;
    data_set_complete <= 0;
    set_control_state <= SETCONTROL_RESET;
  end else begin
    if (e_enable_data_set & ~data_set_complete) begin
      case (set_control_wire)
        8'b00110000: mem_write_for_set <= 8'hff;
        8'b00110001: mem_write_for_set <= 8'hff;
        8'b00110010: mem_write_for_set <= 8'h00;
        8'b00110011: mem_write_for_set <= 8'h00;
        8'b00110100: mem_write_for_set <= 8'h00;
        8'b00110101: mem_write_for_set <= 8'h00;
        8'b00110110: mem_write_for_set <= 8'h83;
        8'b00110111: mem_write_for_set <= 8'h09;
        8'b00111000: mem_write_for_set <= 8'h05;
        8'b00111001: begin
          data_set_complete <= 1;
          mem_writes_counter <= mem_address_for_set;
        end
      endcase
      case (set_control_state)
        SETCONTROL_RESET: begin
          if(e_enable_data_set) begin
            set_control_state <= SETCONTROL_1;  
          end
        end
        SETCONTROL_1: begin
          mem_write_enable_for_set <= 0;
          set_control_state <= SETCONTROL_2;
        end
        SETCONTROL_2: begin
          mem_write_enable_for_set <= 1;
          set_control_state <= SETCONTROL_3;
        end
        SETCONTROL_3: begin
          mem_write_enable_for_set <= 0;
          mem_address_for_set <= mem_address_for_set + 1;
          set_control_state <= SETCONTROL_1;
        end
      endcase
    end else begin
      mem_write_enable_for_set <= 0;
      mem_address_for_set <= 0;
      mem_write_for_set <= 0;
      data_set_complete <= 0;
      set_control_state <= SETCONTROL_RESET;
    end
  end
end

// machine
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
        w_valid <= 0;
        e_enable_data_set <= 0;
        mem_address_for_send <= 0;
        eth_frame_load_addr <= 0;
        eth_frame_send_addr <= 0;
        eth_rec_dead_cnt <= 0;
        mem_enable <= 1;
        mem_ready_for_scs <= 0;
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
          if (eth_rec_dead_cnt == 6'b111110)
            state <= READCOMPLETE;
        end  
      end
      READCOMPLETE: begin
        state <= IDLE;
        if (done == 0) begin
          state <= PING_REPLY_1;
          eth_frame_send_addr = 0;
        end else begin
          // normal processing
        end
      end
      PREPARE: begin
        e_enable_data_set <= 1;
        if (data_set_complete) begin
          state <= PROCESSING;
        end
      end
      PROCESSING: begin
          e_enable_data_set <= 0;
          eth_frame_load_addr <= 0;
          eth_frame_send_addr <= mem_writes_counter;
          state <= WRITE_PORT_1;
          command <= 0;
      end
      PING_REPLY_1: begin
        w_data <= 0;
        if (i_wready) begin
          w_valid <= 1;
          state <= PING_REPLY_2;
          eth_frame_send_addr <= eth_frame_send_addr + 1;
        end
      end
      PING_REPLY_2: begin
        w_valid <= 0;
        if (eth_frame_send_addr != eth_frame_load_addr) begin
          state <= PING_REPLY_1;
        end else begin
          eth_frame_send_addr <= r_time[7:0]; // [29:20];  // [17:8]
          state <= WAIT_FOR_TCHANGE;
        end
      end
      WAIT_FOR_TCHANGE: begin
        if (eth_frame_send_addr != r_time[7:0]) begin // [29:20]) begin // [17:8]
          done <= 1;
          state <= PREPARE;
          command <= COMMAND_REQ_ADDR;
        end
      end
      WRITE_PORT_1: begin
        w_valid <= 0;
        mem_address_for_send <= eth_frame_load_addr;
        state <= WRITE_PORT_21;
      end 
      WRITE_PORT_21: begin
        eth_frame_load_addr <= eth_frame_load_addr + 1;
        // eth_frame_load_addr <= eth_frame_load_addr + 1;
        state <= WRITE_PORT_3;
      end
      WRITE_PORT_3: begin
        w_data <= mem_read;
        w_valid <= 1;
        if (eth_frame_send_addr == eth_frame_load_addr) begin
          state <= IDLE;
        end else begin
          state <= WRITE_PORT_1;
        end
      end 
    endcase
  end
end

assign    w_valid_u = w_valid;
assign    w_data_u = w_data;

assign    o_done   = done;
assign    o_rreq   = r_req;
assign    o_wdata  = w_data;
assign    o_wvalid = w_valid;

assign    o_wdata_u  = w_data_u;
assign    o_wvalid_u = w_valid_u;

assign    p_direction = p_d_type[7];
assign    p_type = p_d_type[6:0];

assign    mem_write_enable = mem_write_enable_for_scs | mem_write_enable_for_set;
assign    mem_address = mem_address_for_scs | mem_address_for_send | mem_address_for_set;
assign    mem_write = mem_write_for_scs | mem_write_for_set;

endmodule
