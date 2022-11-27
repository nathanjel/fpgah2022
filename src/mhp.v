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

wire [7:0] mem_address_for_scs;
wire mem_write_enable_for_scs;
wire [7:0] mem_write_for_scs;

reg [7:0] mem_address_for_set;
reg mem_write_enable_for_set;
reg [7:0] mem_write_for_set;

reg [7:0] mem_address_for_cmd;
reg mem_write_enable_for_cmd;
reg [7:0] mem_write_for_cmd;

// reg [10-1:0] mem_address_for_read;
// equal to and replaced with eth_frame_load_addr
reg mem_write_enable_for_read;
reg [7:0] mem_write_for_read;

wire mem_write_enable;
wire [7:0] mem_address;
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

reg [7:0] eth_frame_len;
reg [7:0] eth_frame_load_addr;
reg [7:0] eth_frame_send_addr;

reg [5:0] eth_rec_dead_cnt;

reg   [4:0] command   = 0;
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
assign set_control_wire = {command[3:0], mem_address_for_set[3:0]};
reg [7:0] mem_writes_counter;
reg [15:0] mem_writes_counter_minus_2;

scs cscalc(
  .reset(i_rst),
  .mem_ready(mem_ready_for_scs),
  .work_complete(scs_work_completed),
  .clock(i_clk),
  .write_enable(mem_write_enable_for_scs),
  .address(mem_address_for_scs),
  .mem_output(mem_read),
  .mem_input(mem_write_for_scs),
  .payload_len (mem_writes_counter_minus_2)
);

// general message writer
always @(posedge i_clk) begin
  if (i_rst) begin
    mem_writes_counter <= 0;
    data_set_complete <= 0;
    set_control_state <= SETCONTROL_RESET;
  end else begin
    if (e_enable_data_set & ~data_set_complete) begin
      case (set_control_wire)
        // address request
        8'b00110000: mem_write_for_set <= 8'hff;
        8'b00110001: mem_write_for_set <= 8'hff;
        8'b00110010: mem_write_for_set <= 8'h00;
        8'b00110011: mem_write_for_set <= 8'h00;
        8'b00110100: mem_write_for_set <= 8'h00;
        8'b00110101: mem_write_for_set <= 8'h01;
        8'b00110110: mem_write_for_set <= 8'h83;
        8'b00110111: mem_write_for_set <= 8'h00;
        8'b00111001: mem_write_for_set <= 8'h00;
        8'b00111010: mem_write_for_set <= 8'h00;
        8'b00111011: begin
          data_set_complete <= 1;
          mem_writes_counter <= mem_address_for_set;
        end
        // address grant - send ready
        8'b01000000: mem_write_for_set <= 8'hff;
        8'b01000001: mem_write_for_set <= 8'hff;
        8'b01000010: mem_write_for_set <= 8'h00;
        8'b01000011: mem_write_for_set <= 8'h00;
        8'b01000100: mem_write_for_set <= 8'h00;
        8'b01000101: mem_write_for_set <= 8'h02;
        8'b01000110: mem_write_for_set <= 8'h92;
        8'b01000111: mem_write_for_set <= 8'h01;
        8'b01001000: mem_write_for_set <= 8'h20;
        8'b01001001: mem_write_for_set <= 8'h00;
        8'b01001010: mem_write_for_set <= 8'h00;
        8'b01001011: begin
          data_set_complete <= 1;
          mem_writes_counter <= mem_address_for_set;
        end
        // ping response
        8'b00010000: mem_write_for_set <= 8'hff;
        8'b00010001: mem_write_for_set <= 8'hff;
        8'b00010010: mem_write_for_set <= 8'h00;
        8'b00010011: mem_write_for_set <= 8'h00;
        8'b00010100: mem_write_for_set <= 8'h00;
        8'b00010101: mem_write_for_set <= 8'h01;
        8'b00010110: mem_write_for_set <= 8'h81;
        8'b00010111: mem_write_for_set <= 8'h00;
        8'b00011000: mem_write_for_set <= 8'h00;
        8'b00011001: mem_write_for_set <= 8'h00;
        8'b00011010: begin
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

// address and command reader
reg   header_reader_active;
reg   header_reader_complete;
reg   [7:0]   header_address_driver;
reg   [15:0]  p_dst_addr;
reg   [15:0]  p_src_addr;
reg   [15:0]  p_size;
reg   [7:0]   p_d_type;
reg   [15:0]  p_scs;

reg   [2:0] header_reader_state;
localparam HRW_INIT = 0;
localparam HRW_ADDR = 1;
localparam HRW_LOAD = 2;
localparam HRW_DONE = 3;
wire  p_direction;
wire  [6:0] p_type;

always @(posedge i_clk ) begin
  if(i_rst) begin
     p_dst_addr <= 0;
     p_src_addr <= 0;
     p_size <= 0;
     p_d_type <= 0;
     p_scs <= 0;
     header_reader_state <= HRW_INIT;
     header_address_driver <= 0;
  end else begin
     // if (header_reader_active) begin
       case (header_reader_state)
          HRW_INIT: begin
            header_address_driver <= 0;
            if (header_reader_active)
              header_reader_state <= HRW_ADDR;
          end
          HRW_ADDR: begin
            header_reader_state <= HRW_LOAD;
          end
          HRW_LOAD: begin
            case (header_address_driver[2:0])
              3'b000: p_src_addr[15:8] <= mem_read;
              3'b001: p_src_addr[7:0] <= mem_read;
              3'b010: p_dst_addr[15:8] <= mem_read;
              3'b011: p_dst_addr[7:0] <= mem_read;
              3'b100: p_size[15:8] <= mem_read;
              3'b101: p_size[7:0] <= mem_read;
              3'b110: p_d_type[7:0] <= mem_read;
            endcase
            header_address_driver <= header_address_driver + 1;
            if (header_address_driver == 3'b110)
              header_reader_state <= HRW_DONE;
            else
              header_reader_state <= HRW_ADDR;
          end
          HRW_DONE: begin
            header_reader_state <= HRW_INIT;
          end
       endcase
     // end
  end
end

// command processor
reg         cp_force_address_request;
reg         command_processor_active;
reg   [3:0] command_processor_state;
localparam CP_INIT = 0;
localparam CP_HEAD = 1;
localparam CP_ACTI = 2;
localparam CP_LOAD = 3;
localparam CP_FILL1 = 4;
localparam CP_FILL2 = 5;
localparam CP_FILL3 = 6;
localparam CP_FILL4 = 7;
localparam CP_FILLS = 8;
localparam CP_DONE = 9;
always @(posedge i_clk) begin
  if(i_rst) begin
    mem_ready_for_scs <= 0;
    e_enable_data_set <= 0;
    command_processor_state <= CP_INIT;
    header_reader_active <= 0;
    mem_write_for_cmd <= 0;
    mem_address_for_cmd <= 0;
    mem_write_enable_for_cmd <= 0;
    mem_writes_counter_minus_2 <= 0;
  end else begin
    case (command_processor_state)
      CP_INIT: begin
        if (command_processor_active)
          command_processor_state <= CP_HEAD;
      end
      CP_HEAD: begin
        if (header_reader_state == HRW_DONE) begin
          command <= cp_force_address_request ? COMMAND_REQ_ADDR : 
                                                                      (got_address ? p_d_type[4:0] : 5'h04);
          header_reader_active <= 0;
          command_processor_state <= CP_ACTI;
        end else
          header_reader_active <= 1;
      end
      CP_ACTI: begin
        if (p_type[4])
          command_processor_state <= CP_DONE;
        else
          command_processor_state <= CP_LOAD;
      end
      CP_LOAD: begin
        if (data_set_complete) begin
          e_enable_data_set <= 0;
          command_processor_state <= cp_force_address_request ? CP_DONE : CP_FILL1;
          mem_writes_counter_minus_2 <= mem_writes_counter - 2;
        end else
          e_enable_data_set <= 1;
      end
      CP_FILL1: begin
        command_processor_state <= CP_FILL2;
        mem_address_for_cmd <= 8'h00;
        mem_write_for_cmd <= p_dst_addr[15:8];
        mem_write_enable_for_cmd <= 1;
      end
      CP_FILL2: begin
        command_processor_state <= CP_FILL3;
        mem_address_for_cmd <= 8'h01;
        mem_write_for_cmd <= p_dst_addr[7:0];
        mem_write_enable_for_cmd <= 1;
      end
      CP_FILL3: begin
        mem_address_for_cmd <= 8'h02;
        mem_write_for_cmd <= p_src_addr[15:8];
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILL4;
      end
      CP_FILL4: begin
        mem_address_for_cmd <= 8'h03;
        mem_write_for_cmd <= p_src_addr[7:0];
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILLS;
      end
      CP_FILLS: begin
        mem_write_for_cmd <= 0;
        mem_address_for_cmd <= 0;
        mem_write_enable_for_cmd <= 0;        
        if (scs_work_completed | cp_force_address_request) begin
          mem_ready_for_scs <= 0;
          command_processor_state <= CP_DONE;
        end else begin
          mem_ready_for_scs <= 1;
        end
      end
      CP_DONE: begin
        command_processor_state <= CP_INIT;
      end
    endcase
  end
end

// the machine
reg   [7:0] rr_uart_d;
reg         rr_uart_e;

reg         got_address;

reg   [4:0] state       = 0;
localparam  IDLE        = 0;
localparam  READ        = 1;
localparam  READA        = 2;
localparam  READB        = 16;
localparam  READCOMPLETE  = 3;
localparam  WRITE       = 4;
localparam  WRITEA       = 5;
localparam  WRITECOMPLETE = 6;
localparam  PING_REPLY_1 = 7;
localparam  PING_REPLY_2 = 8;
localparam  WAIT_FOR_TCHANGE = 9;
localparam  WRITE_PORT_1 = 10;
localparam  WRITE_PORT_2 = 11;
localparam  WRITE_PORT_21 = 15;
localparam  WRITE_PORT_3 = 12;
localparam  PREPARE = 13;
localparam  PROCESSING = 14;

always @(posedge i_clk) begin
  if (i_rst) begin
    done    <= 0;
    w_data  <= 0;
    w_valid <= 0;
    state   <= IDLE;
    mem_enable <= 1;
    rr_uart_d <= 0;
    rr_uart_e <= 0;
    got_address <= 0;
  end
  else begin
    case (state)
      IDLE: begin
        w_valid <= 0;
        command_processor_active <= 0;
        eth_frame_len <= 0;
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
        mem_write_enable_for_read <= 0;
        mem_write_for_read <= i_rdata;
        // rr_uart_d <= i_rdata;
        // rr_uart_e <= 0;
        r_req <= 0; // complete fifo
        state <= READB; // continue reading
        eth_rec_dead_cnt <= 0;
      end
      READB: begin
        mem_write_enable_for_read <= 1;
        state <= READA;
      end
      READA: begin
        // rr_uart_e <= 1 & ~(eth_rec_dead_cnt[5] | eth_rec_dead_cnt[4] | eth_rec_dead_cnt[3] | eth_rec_dead_cnt[2] | eth_rec_dead_cnt[1] | eth_rec_dead_cnt[0]) ;
        mem_write_enable_for_read <= 0;
        if (i_rready) begin
          eth_frame_load_addr <= eth_frame_load_addr + 1;
          state <= READ;
          r_req <= 1;
        end else begin
          eth_rec_dead_cnt <= eth_rec_dead_cnt + 1;
          if (eth_rec_dead_cnt == 6'b111110)
            state <= READCOMPLETE;
        end  
      end
      READCOMPLETE: begin
        // rr_uart_e <= 0;
        // rr_uart_d <= 0;
        eth_frame_load_addr <= 0;
        eth_frame_send_addr <= 0;
        eth_frame_len <= eth_frame_load_addr;
        mem_write_for_read <= 0;
        mem_write_enable_for_read <= 0;
        if (done == 0) begin
          state <= PING_REPLY_1;
        end else begin
          state <= PREPARE;
        end
      end
      PREPARE: begin
        if (command_processor_state == CP_DONE) begin
          state <= PROCESSING;
          command_processor_active <= 0;
        end else begin 
          command_processor_active <= 1;
        end
      end
      PROCESSING: begin
          eth_frame_load_addr <= 0;
          eth_frame_send_addr <= mem_writes_counter;
          cp_force_address_request <= 0;
          if (command == 5'h04)
            got_address <= 1;
          if (p_type[4]) begin
            state <= IDLE;
            // ready ack command
          end else begin
            state <= WRITE_PORT_1;
          end
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
        if (eth_frame_send_addr != eth_frame_len) begin
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
          cp_force_address_request <= 1;
        end
      end
      WRITE_PORT_1: begin
        w_valid <= 0;
        // mem_address_for_send <= eth_frame_load_addr;
        state <= WRITE_PORT_2;
      end 
      WRITE_PORT_2: begin
        eth_frame_load_addr <= eth_frame_load_addr + 1;
        // eth_frame_load_addr <= eth_frame_load_addr + 1;
        state <= WRITE_PORT_21;
      end
      WRITE_PORT_21: begin
        if (eth_frame_load_addr <= eth_frame_send_addr)
          w_data <= mem_read;
        else
          w_data <= 0;
        // eth_frame_load_addr <= eth_frame_load_addr + 1;
        state <= WRITE_PORT_3;
      end
      WRITE_PORT_3: begin
        w_valid <= 1;
        if (eth_frame_load_addr == 8'h32) begin
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

assign    o_wdata_u  = w_data_u; //| rr_uart_d;
assign    o_wvalid_u = w_valid_u; // | rr_uart_e;

assign    p_direction = p_d_type[7];
assign    p_type = p_d_type[6:0];

assign    mem_write_enable = mem_write_enable_for_scs | mem_write_enable_for_set | mem_write_enable_for_read | mem_write_enable_for_cmd;
assign    mem_address = mem_address_for_scs | mem_address_for_set | eth_frame_load_addr | header_address_driver | mem_address_for_cmd;
assign    mem_write = mem_write_for_scs | mem_write_for_set | mem_write_for_read | mem_write_for_cmd;

endmodule
