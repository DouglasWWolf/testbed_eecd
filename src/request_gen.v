
`timescale 1ns / 1ps
//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 08-Sep-22  DWW  1000  Initial creation
//===================================================================================================


`define AXIS_DATA_WIDTH 256

module request_gen
(
    input clk, resetn,

    input BUTTON,

    //========================  AXI Stream interface for sending requests  ==========================
    output [`AXIS_DATA_WIDTH-1:0]     AXIS_TX_TDATA,
    output reg                        AXIS_TX_TVALID,
    output reg                        AXIS_TX_TLAST,
    input                             AXIS_TX_TREADY
    //===============================================================================================
);


reg[3:0] dgsm_state;
reg[7:0] counter;
reg[7:0] row;
reg[15:0] frame;

assign AXIS_TX_TDATA[7:0] = row;
assign AXIS_TX_TDATA[31:16] = frame;

always @(posedge clk) begin
    if (resetn == 0) begin
        dgsm_state     <= 0;
        AXIS_TX_TVALID <= 0;
        frame          <= 12;
    end

    else case(dgsm_state)
        0: if (BUTTON) begin
                dgsm_state     <= 1;
                counter        <= 8;
                AXIS_TX_TVALID <= 1;
                row            <= 0;
               
            end

        1:  if (AXIS_TX_TVALID & AXIS_TX_TREADY) begin
                if (counter == 1) begin
                    AXIS_TX_TVALID <= 0;
                    dgsm_state     <= 0;
                end

                else begin
                    counter <= counter - 1;
                    row     <= row     + 1;
                end
            end
    endcase
end


endmodule