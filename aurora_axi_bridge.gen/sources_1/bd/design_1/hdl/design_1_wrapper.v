//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.1 (lin64) Build 3247384 Thu Jun 10 19:36:07 MDT 2021
//Date        : Fri Oct  7 05:26:43 2022
//Host        : simtool5-2 running 64-bit Ubuntu 20.04.5 LTS
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (BTNU,
    CLK100MHZ,
    CPU_RESETN,
    UART_rxd,
    UART_txd);
  input BTNU;
  input CLK100MHZ;
  input CPU_RESETN;
  input UART_rxd;
  output UART_txd;

  wire BTNU;
  wire CLK100MHZ;
  wire CPU_RESETN;
  wire UART_rxd;
  wire UART_txd;

  design_1 design_1_i
       (.BTNU(BTNU),
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .UART_rxd(UART_rxd),
        .UART_txd(UART_txd));
endmodule
