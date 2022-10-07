
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//     This module is used to narrow the width of an AXI stream in order to trim-off unused bits
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 06-Oct-22  DWW  1000  Initial creation
//===================================================================================================


module axis_slice #
(
    parameter DIN_WIDTH  = 256,
    parameter LOW_BIT    =   0,
    parameter DOUT_WIDTH =  32
) 
(
    input clk,

    //========================  AXI Stream interface for the input side  ============================
    input[DIN_WIDTH-1:0]        AXIS_RX_TDATA,
    input                       AXIS_RX_TVALID,
    output reg                  AXIS_RX_TREADY,
    //===============================================================================================


    //========================  AXI Stream interface for the output side  ===========================
    output reg[DOUT_WIDTH-1:0]  AXIS_TX_TDATA,
    output reg                  AXIS_TX_TVALID,
    input                       AXIS_TX_TREADY
    //===============================================================================================

);


always @(posedge clk) begin
    AXIS_TX_TDATA  <= AXIS_RX_TDATA[LOW_BIT + DOUT_WIDTH - 1 : LOW_BIT];
    AXIS_TX_TVALID <= AXIS_RX_TVALID;
    AXIS_RX_TREADY <= AXIS_TX_TREADY;
end


endmodule