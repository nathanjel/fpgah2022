`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2022 13:49:36
// Design Name: 
// Module Name: msim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module msim;

logic         clk_50 = 0;
logic         clk_phy = 1;
logic         o_link;

logic   [7:0]   i_eth_rdata;
logic           i_eth_rready;
logic          o_eth_rreq;

logic  [7:0]   o_eth_wdata;
logic           i_eth_wready;
logic          o_eth_wvalid;
  
  //  uart rx
  logic   [7:0]   i_uart_rdata;
  logic           i_uart_rready;
  logic          o_uart_rreq;
  //  uart tx
  logic  [7:0]   o_uart_wdata;
  logic           i_uart_wready;
  logic          o_uart_wvalid;


control dcontrol(
  //  sys
  .i_clk(clk_50),
  .o_link(o_link),
  //  eth
  
  .i_eth_rdata(i_eth_rdata),
  .i_eth_rready(i_eth_rready),
  .o_eth_rreq(o_eth_rreq),
  
  .o_eth_wdata(o_eth_wdata),
  .i_eth_wready(i_eth_wready),
  .o_eth_wvalid(o_eth_wvalid),
  
  //  uart rx
  .i_uart_rdata(i_uart_rdata),
  .i_uart_rready(i_uart_rready),
  .o_uart_rreq(o_uart_rreq),
  //  uart tx
  .o_uart_wdata(o_uart_wdata),
  .i_uart_wready(i_uart_wready),
  .o_uart_wvalid(o_uart_wvalid)
);

initial

  forever
    #10 clk_50 = ~clk_50;

initial begin
  #5
  forever
    #10 clk_phy = ~clk_phy;
end

initial begin
    i_eth_rdata <= 8'b0;
    i_eth_rready <= 0;
    i_eth_wready <= 1;
    #100
    i_eth_rdata <= 8'b00001111;
    i_eth_rready <= 1;
    #100
    i_eth_rready <= 0;
    #100
    i_eth_rdata <= 8'b00001111;
    i_eth_rready <= 1;
    #100
    i_eth_rready <= 0;
    #100
    i_eth_rdata <= 8'b00001111;
    i_eth_rready <= 1;
    #100
    i_eth_rready <= 0;
end



//always @(posedge clk_50) begin
//  force dut_top.mac_wrapper.mac_rx_data = 0;
//  force dut_top.mac_wrapper.mac_rx_valid = dut_top.main.debug_port.state == 3 ? 1 : 0;
//end


endmodule
