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
wire        r_send_enabled;

localparam CLOCK_DIVIDER = 50000000;
localparam ADDRESS_LINE_SIZE = 11;
// ADDRESS_LINE_SIZE-1
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

assign r_send_enabled = (r_counter_clock[9:0] == 10'b1111111111);

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

wire [ADDRESS_LINE_SIZE-1:0] mem_address_for_scs;
wire mem_write_enable_for_scs;
wire [7:0] mem_write_for_scs;

reg [ADDRESS_LINE_SIZE-1:0] mem_address_for_set;
reg mem_write_enable_for_set;
reg [7:0] mem_write_for_set;

reg [ADDRESS_LINE_SIZE-1:0] mem_address_for_cmd;
reg mem_write_enable_for_cmd;
reg [7:0] mem_write_for_cmd;

// reg [10-1:0] mem_address_for_read;
// equal to and replaced with eth_frame_load_addr
reg mem_write_enable_for_read;
reg [7:0] mem_write_for_read;

wire mem_write_enable;
wire [ADDRESS_LINE_SIZE-1:0] mem_address;
wire [7:0] mem_write;
wire [7:0] mem_read;
wire scs_work_completed;

reg mem_enable;
reg mem_ready_for_scs;

bram record_ram(
  .clock(i_clk),
  .reset       (i_rst),
  .ram_enable(mem_enable),
  .write_enable(mem_write_enable),
  .address     (mem_address),
  .input_data  (mem_write),
  .output_data (mem_read)
);

reg [ADDRESS_LINE_SIZE-1:0] eth_frame_len;
reg [ADDRESS_LINE_SIZE-1:0] eth_frame_load_addr;
reg [ADDRESS_LINE_SIZE-1:0] eth_frame_send_addr;

reg [5:0] eth_rec_dead_cnt;

reg         got_address;
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
reg [ADDRESS_LINE_SIZE-1:0] mem_writes_counter;
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
        8'b01000101: mem_write_for_set <= 8'h06;
        8'b01000110: mem_write_for_set <= 8'h92;
        8'b01000111: mem_write_for_set <= 8'h05;
        8'b01001000: mem_write_for_set <= 8'h20;
        8'b01001001: mem_write_for_set <= 8'h30;
        8'b01001010: mem_write_for_set <= 8'h60;
        8'b01001011: mem_write_for_set <= 8'h61;
        8'b01001100: mem_write_for_set <= 8'h62;
        8'b01001101: mem_write_for_set <= 8'h00;
        8'b01001110: mem_write_for_set <= 8'h00;
        8'b01001111: begin
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
        // echo response
        8'b01010000: mem_write_for_set <= 8'hff;
        8'b01010001: mem_write_for_set <= 8'hff;
        8'b01010010: mem_write_for_set <= 8'hff;
        8'b01010011: mem_write_for_set <= 8'hff;
        8'b01010100: mem_write_for_set <= p_size[15:8];
        8'b01010101: mem_write_for_set <= p_size[7:0];
        8'b01010110: mem_write_for_set <= 8'h85;
        8'b01010111: begin
          data_set_complete <= 1;
          mem_writes_counter <= p_size[ADDRESS_LINE_SIZE-1:0] + 9;
        end
        // calc response
        8'b11010000: mem_write_for_set <= 8'hff;
        8'b11010001: mem_write_for_set <= 8'hff;
        8'b11010010: mem_write_for_set <= 8'hff;
        8'b11010011: mem_write_for_set <= 8'hff;
        8'b11010100: mem_write_for_set <= 8'h00;
        8'b11010101: mem_write_for_set <= 8'h02;
        8'b11010110: mem_write_for_set <= 8'h8e;
        8'b11010111: mem_write_for_set <= p_calc_output[15:8];
        8'b11011000: mem_write_for_set <= p_calc_output[7:0];
        8'b11011001: begin
          data_set_complete <= 1;
          mem_writes_counter <= p_size[ADDRESS_LINE_SIZE-1:0] + 9;
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
reg   [ADDRESS_LINE_SIZE-1:0]   header_address_driver;
reg   [15:0]  p_dst_addr;
reg   [15:0]  p_src_addr;
reg   [15:0]  p_size;
reg   [7:0]   p_d_type;
reg   [15:0]  p_scs;
reg   [7:0]   p_operand;
reg signed   [15:0]   p_para1;
reg signed   [15:0]   p_para2;
reg signed   [15:0]   p_calc_output;

reg   [3:0] header_reader_state;
localparam HRW_INIT = 0;
localparam HRW_ADDR = 1;
localparam HRW_LOAD = 2;
localparam HRW_INC = 3;
localparam HRW_DONE = 4;
wire  p_direction;
wire  [6:0] p_type;

always @(posedge i_clk ) begin
  if(i_rst) begin
     p_dst_addr <= 0;
     p_src_addr <= 0;
     p_size <= 0;
     p_d_type <= 0;
     p_scs <= 0;
     p_operand <= 0;
     p_para1 <= 0;
     p_para2 <= 0;
     // p_calc_output <= 0;
     header_reader_state <= HRW_INIT;
     header_address_driver <= 0;
  end else begin
     // if (header_reader_active) begin
       case (header_reader_state)
          HRW_INIT: begin
            header_address_driver <= header_reader_state ? 0 : 0; // dirty hack for 0e
            if (header_reader_active)
              header_reader_state <= HRW_ADDR;
          end
          HRW_ADDR: begin
            header_reader_state <= HRW_LOAD;
          end
          HRW_LOAD: begin
            case (header_address_driver[3:0])
              4'b0000: p_src_addr[15:8] <= mem_read;
              4'b0001: p_src_addr[7:0] <= mem_read;
              4'b0010: p_dst_addr[15:8] <= mem_read;
              4'b0011: p_dst_addr[7:0] <= mem_read;
              4'b0100: p_size[15:8] <= mem_read;
              4'b0101: p_size[7:0] <= mem_read;
              4'b0110: p_d_type[7:0] <= mem_read;
              4'b0111: p_operand[7:0] <= mem_read;
              4'b1000: p_para1[15:8] <= mem_read;
              4'b1001: p_para1[7:0] <= mem_read;
              4'b1010: p_para2[15:8] <= mem_read;
              4'b1011: p_para2[7:0] <= mem_read;
            endcase
            if (header_address_driver == 4'b1011)
              header_reader_state <= HRW_DONE;
            else
              header_reader_state <= HRW_INC;
          end
          HRW_INC: begin
            header_address_driver <= header_address_driver + 1;
            header_reader_state <= HRW_ADDR;
          end
          HRW_DONE: begin
            header_reader_state <= HRW_INIT;
          end
       endcase
     // end
  end
end

// reg   [7:0] mover_ref_addr;
// reg   [7:0] mover_temp;
// reg   [7:0] mover_end_addr;
// reg         mover_complete
// reg   [7:0] mover_address;
// reg   [7:0] mover_write;
// reg         mover_write_en;
// reg   [4:0] mover_state;

// assign @(posedge i_clk) begin
//   if(i_rst) begin
//     mover_state <= 0;
//     mover_address <= 0;
//     mover_write <= 0;
//     mover_write_en <= 0;
//     mover_complete <= 0;
//   end else begin
//     case (mover_state)
//       0: begin
//         mover_state <= 0;
//         mover_address <= 0;
//         mover_write <= 0;
//         mover_write_en <= 0;
//         if (mover_ref_addr != 0)
//           mover_state <= 1;

//       end
//       1: begin
//         mover_address <= mover_ref_addr + 1;
//         mover_state <= 2;
//       end
//       2: begin
//         mover_temp <= mem_read;
//         mover_state <= 3;
//       end
//       3: begin
//         mover_address <= mover_ref_addr;
//         mover_write <= mover_temp;
//         mover_state <= 4;
//       end
//       4: begin
//         mover_write_en <= 1;
//         mover_state <= 5;
//       end
//       5: begin
//         mover_write_en <= 0;
//         mover_write <= 0;
//         mover_ref_addr <= mover_ref_addr + 1;
//       end
//       6: 
//     endcase
//   end
// end

reg [3:0] calculator_state;
reg [7:0] fib_n;
reg [15:0] fib_pp; 
reg [15:0] fib_p;
reg [15:0] fib_c;
wire fib_complete;

assign fib_complete = (fib_n == 8'hff && calculator_state == 4);

always @(posedge i_clk) begin
  if(i_rst) begin
    calculator_state <= 0;
    fib_n <= 0;
    fib_c <= 0;
    fib_pp <= 0;
    fib_p <= 0;
  end else begin
    case(calculator_state)
      0: begin
        if (p_operand == 8'h10) begin
          p_calc_output <= p_para1 + p_para2;
        end
        if (p_operand == 8'h20) begin
          p_calc_output <= p_para1 - p_para2;
        end
        if (p_operand == 8'h30) begin
          p_calc_output <= p_para1 * p_para2;
        end
        if (p_operand == 8'h60) begin
          calculator_state <= 1;
        end
      end
      1: begin
        fib_pp <= 16'h0000;
        fib_p <= 16'h0001;
        fib_c <= 16'h0001;
        fib_n <= p_para1[15:8];
        calculator_state <= 2;
      end
      2: begin
        if (fib_n == 8'h00) begin
          p_calc_output <= fib_pp;
        end else begin 
          if (fib_n == 8'h01) begin
            p_calc_output <= fib_p;
          end else begin 
            if (fib_n == 8'h02) begin 
              p_calc_output <= fib_c;
            end
          end
        end
        calculator_state <= 3;
      end
      3: begin
        fib_n <= fib_n - 1;
        calculator_state <= 4;
      end
      4: begin
        if (fib_n == 8'hfe) begin
          calculator_state <= 0;
        end else begin
          calculator_state <= 5;
        end;
      end
      5: begin
        fib_pp <= fib_p;
        calculator_state <= 6;
      end
      6: begin
        fib_p <= fib_c;
        calculator_state <= 7;
      end
      7: begin
        fib_c <= fib_p + fib_pp;
        calculator_state <= 2;
      end
    endcase 
  end
end
// command processor
reg         cp_force_address_request;
reg         command_processor_active;
reg   [4:0] command_processor_state;
localparam CP_INIT = 0;
localparam CP_HEAD = 1;
localparam CP_ACTI = 2;
localparam CP_LOAD = 3;
localparam CP_FILL1 = 4;
localparam CP_FILL2 = 5;
localparam CP_FILL3 = 6;
localparam CP_FILL4 = 7;
localparam CP_FILL1A = 10;
localparam CP_FILL2A = 11;
localparam CP_FILL3A = 12;
localparam CP_FILL4A = 13;
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
        if (p_type[4]) begin
          command_processor_state <= CP_DONE;
        end else begin
          if (p_type == 7'h0d) begin
            command_processor_state <= CP_LOAD;            
          end else begin
            if (p_type[3:0] == 4'h0d & p_operand == 8'h60) begin
              command_processor_state <= (fib_complete & mem_writes_counter) ? CP_ACTI : CP_LOAD; 
            end else begin
              command_processor_state <= CP_LOAD;
            end
          end
        end
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
        command_processor_state <= CP_FILL1A;
        mem_address_for_cmd <= 8'h00;
        mem_write_for_cmd <= p_dst_addr[15:8];
      end
      CP_FILL1A: begin
        command_processor_state <= CP_FILL2;
        mem_write_enable_for_cmd <= 1;
      end
      CP_FILL2: begin
        mem_write_enable_for_cmd <= 0;
        mem_address_for_cmd <= 8'h01;
        mem_write_for_cmd <= p_dst_addr[7:0];
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILL2A;
      end
      CP_FILL2A: begin
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILL3;
      end
      CP_FILL3: begin
        mem_write_enable_for_cmd <= 0;
        mem_address_for_cmd <= 8'h02;
        mem_write_for_cmd <= p_src_addr[15:8];
        command_processor_state <= CP_FILL3A;
      end
      CP_FILL3A: begin
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILL4;
      end
      CP_FILL4: begin
        mem_write_enable_for_cmd <= 0;
        mem_address_for_cmd <= 8'h03;
        mem_write_for_cmd <= p_src_addr[7:0];
        command_processor_state <= CP_FILL4A;        
      end
      CP_FILL4A: begin
        mem_write_enable_for_cmd <= 1;
        command_processor_state <= CP_FILLS;
      end
      CP_FILLS: begin
        mem_write_enable_for_cmd <= 0;
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



reg   [3:0] main_fsm_state       = 0;
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
    main_fsm_state   <= IDLE;
    mem_enable <= 1;
    rr_uart_d <= 0;
    rr_uart_e <= 0;
    got_address <= 0;
  end
  else begin
    case (main_fsm_state)
      IDLE: begin
        w_valid <= 0;
        w_data <= 0;
        mem_write_for_read <= 0;
        mem_write_enable_for_read <= 0;
        command_processor_active <= 0;
        eth_frame_len <= 0;
        eth_frame_load_addr <= 11'hffe;
        eth_frame_send_addr <= 0;
        eth_rec_dead_cnt <= 0;
        if (i_rready) begin // received frame's payload ready
          r_req   <= 1;     // r_req set before read main_fsm_state, so we can expect valid data in READ main_fsm_state
          main_fsm_state   <= READ;
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
      //     main_fsm_state   <= WRITE;  
      //   end
      // end
      // WRITE: begin    //  write data
      //   if (i_wready) begin
      //     w_valid_u <= 1;
      //     w_valid <= 1;
      //     main_fsm_state   <= IDLE;
      //   end
      // end
      READ: begin
        mem_write_enable_for_read <= 0;
        mem_write_for_read <= i_rdata;
        eth_frame_load_addr <= eth_frame_load_addr + 1;
        rr_uart_d <= i_rdata;
        rr_uart_e <= 0;
        r_req <= 0; // complete fifo
        main_fsm_state <= READA; // continue reading
        eth_rec_dead_cnt <= 0;
      end
      READA: begin
        mem_write_enable_for_read <= 1;
        rr_uart_e <= 1 & ~(eth_rec_dead_cnt[5] | eth_rec_dead_cnt[4] | eth_rec_dead_cnt[3] | eth_rec_dead_cnt[2] | eth_rec_dead_cnt[1] | eth_rec_dead_cnt[0]) ;
        if (i_rready) begin
          main_fsm_state <= READ;
          r_req <= 1;
        end else begin
          eth_rec_dead_cnt <= eth_rec_dead_cnt + 1;
          if (eth_rec_dead_cnt == 6'b111110)
            main_fsm_state <= READCOMPLETE;
        end  
      end
      READCOMPLETE: begin
        rr_uart_e <= 0;
        rr_uart_d <= 0;
        eth_frame_load_addr <= 0;
        eth_frame_len <= eth_frame_load_addr;
        mem_write_for_read <= 0;
        mem_write_enable_for_read <= 0;
        if (done == 0) begin
          if (i_wready & r_send_enabled) begin
            eth_frame_send_addr <= 0;
            main_fsm_state <= PING_REPLY_1;
          end
        end else begin
          main_fsm_state <= PREPARE;
        end
      end
      PREPARE: begin
        if (command_processor_state == CP_DONE) begin
          main_fsm_state <= PROCESSING;
          command_processor_active <= 0;
        end else begin 
          command_processor_active <= 1;
        end
      end
      PROCESSING: begin
          eth_frame_load_addr <= 8'h00;
          eth_frame_send_addr <= mem_writes_counter;
          cp_force_address_request <= 0;
          if (command == 5'h04)
            got_address <= 1;
          if (p_type[4]) begin
            main_fsm_state <= IDLE;
            // ready ack command
          end else begin
            if (i_wready & r_send_enabled)
              main_fsm_state <= WRITE_PORT_1;
          end
      end
      PING_REPLY_1: begin
        w_data <= 0;
        w_valid <= 0;
        main_fsm_state <= PING_REPLY_2;
        // eth_frame_send_addr <= eth_frame_send_addr + 1;
      end
      PING_REPLY_2: begin
        w_valid <= 1;
        // if (eth_frame_send_addr != eth_frame_len) begin
        //   main_fsm_state <= PING_REPLY_1;
        // end else begin
        //   eth_frame_send_addr <= r_time[7:0]; // [29:20];  // [17:8]
        main_fsm_state <= WAIT_FOR_TCHANGE;
        // end
      end
      WAIT_FOR_TCHANGE: begin
        w_valid <= 0;
        if (i_wready & r_send_enabled) begin // [29:20]) begin // [17:8]
          done <= 1;
          main_fsm_state <= PREPARE;
          cp_force_address_request <= 1;
        end
      end
      WRITE_PORT_1: begin
        if (eth_frame_load_addr == 8'h00)
          w_valid <= 0;
        else
          w_valid <= 1;
        // mem_address_for_send <= eth_frame_load_addr;
        main_fsm_state <= WRITE_PORT_2;
      end 
      WRITE_PORT_2: begin
        w_valid <= 0;
        eth_frame_load_addr <= eth_frame_load_addr + 1;
        // eth_frame_load_addr <= eth_frame_load_addr + 1;
        main_fsm_state <= WRITE_PORT_21;
      end
      WRITE_PORT_21: begin
        if (eth_frame_load_addr <= eth_frame_send_addr)
          w_data <= mem_read;
        else
          w_data <= 0;
        // eth_frame_load_addr <= eth_frame_load_addr + 1;
        // main_fsm_state <= WRITE_PORT_3;
        if (eth_frame_load_addr == (eth_frame_send_addr+8)) begin
          main_fsm_state <= IDLE;
        end else begin
          main_fsm_state <= WRITE_PORT_1;
        end
      end
      WRITE_PORT_3: begin
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

assign    o_wdata_u  = w_data_u | rr_uart_d;
assign    o_wvalid_u = w_valid_u | rr_uart_e;

assign    p_direction = p_d_type[7];
assign    p_type = p_d_type[6:0];

assign    mem_write_enable = mem_write_enable_for_scs | mem_write_enable_for_set | mem_write_enable_for_read | mem_write_enable_for_cmd;
assign    mem_address = mem_address_for_scs | mem_address_for_set | eth_frame_load_addr | header_address_driver | mem_address_for_cmd;
assign    mem_write = mem_write_for_scs | mem_write_for_set | mem_write_for_read | mem_write_for_cmd;

endmodule
