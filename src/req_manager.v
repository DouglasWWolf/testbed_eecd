
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// This module reads data requests, and transmits the correspond row of data
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

//===================================================================================================
//                            ------->  Revision History  <------
//===================================================================================================
//
//   Date     Who   Ver  Changes
//===================================================================================================
// 06-Oct-22  DWW  1000  Initial creation
//===================================================================================================

module req_manager
(
    input clk, resetn,

    //==========================  AXI Stream interface for request input  ===========================
    input[31:0]         AXIS_RQ_TDATA,
    input               AXIS_RQ_TVALID,
    output reg          AXIS_RQ_TREADY,
    //===============================================================================================


    //==========================  AXI Stream interface for data input  ==============================
    input[511:0]        AXIS_RX_TDATA,
    input               AXIS_RX_TVALID,
    output reg          AXIS_RX_TREADY,
    //===============================================================================================


    //========================  AXI Stream interface for data_output  ===============================
    output reg[255:0]  AXIS_TX_TDATA,
    output reg         AXIS_TX_TVALID,
    input              AXIS_TX_TREADY
    //===============================================================================================

);

// This is how many beats of the RX data stream are in a single outgoing packet
localparam RX_BEATS_PER_PACKET = 32;

// Define the AXIS handshake for each stream
wire RQ_HANDSHAKE = AXIS_RQ_TVALID & AXIS_RQ_TREADY;
wire TX_HANDSHAKE = AXIS_TX_TVALID & AXIS_TX_TREADY;
wire RX_HANDSHAKE = AXIS_RX_TVALID & AXIS_RX_TREADY;


reg        rx_data_req;
reg        rx_data_valid;
wire       is_rx_data_valid = (rx_data_req == 0 && rx_data_valid == 1);

reg[255:0] data_word[0:1];


always @(posedge clk) begin
    if (resetn == 0) begin
        rx_data_valid  <= 0;
        AXIS_RX_TREADY <= 0;
    end else case (rx_data_valid)

    0:  begin
            AXIS_RX_TREADY <= 1;
            if (RX_HANDSHAKE) begin
                AXIS_RX_TREADY <= 0;
                data_word[0]   <= AXIS_RX_TDATA[511:256];
                data_word[1]   <= AXIS_RX_TDATA[255:000];
                rx_data_valid  <= 1;
            end
        end 

    1:  if (rx_data_req) begin
            AXIS_RX_TREADY <= 1;
            rx_data_valid  <= 0;
        end

    endcase

end



reg[2:0]   fsm_state;
reg[31:0]  req_id;
reg[255:0] buffered_word;
reg[7:0]   beat_countdown;

always @(posedge clk) begin
    
    // This signal only strobes high for a single cycle
    rx_data_req <= 0;
    
    if (resetn == 0) begin
        AXIS_RQ_TREADY <= 0;
        AXIS_TX_TVALID <= 0;
        fsm_state      <= 0;
    end else case(fsm_state)

    // Allow a new request to flow in from the RQ stream
    0:  begin
            AXIS_RQ_TREADY <= 1;
            fsm_state      <= fsm_state + 1;
        end

    // If a new request has arrived...
    1:  if (RQ_HANDSHAKE) begin
                
            // We are no longer ready for a new data request
            AXIS_RQ_TREADY <= 0;

            // Save the request
            req_id <= AXIS_RQ_TDATA;

            // Place the packet header on the bus
            AXIS_TX_TDATA  <= AXIS_RQ_TDATA;
            AXIS_TX_TVALID <= 1;

            // This is how many beats of RX data we have left to send
            beat_countdown <= RX_BEATS_PER_PACKET;

            // And go to the next state
            fsm_state <= fsm_state + 1;
        end
        

    // If the packet-header we just transmitted has been accepted
    2:  if (AXIS_TX_TREADY == 1 || AXIS_TX_TVALID == 0) begin
            
            // We no longer have valid data on the TX bus
            AXIS_TX_TVALID <= 0;
          
            // If we have valid data from the RX data bus...
            if (is_rx_data_valid) begin
                
                // Place half of the received data onto the TX data bus
                AXIS_TX_TDATA <= data_word[0];
                
                // Save the other half of the received data for future use
                buffered_word <= data_word[1];
                
                // Allow more data to flow in
                rx_data_req <= 1;

                // The data on the TX data bus is valid
                AXIS_TX_TVALID <= 1;

                // And go to the next state
                fsm_state <= fsm_state + 1;

            end

        end

    // If the data-cycle we just transmitted was accepted...
    3:  if (AXIS_TX_TREADY) begin
              
            // Place the second half of the received data onto the TX data bus
            AXIS_TX_TDATA <= buffered_word;

            // If this was the last data-beat we need to transmit, go to the next
            // state, otherwise, go tto the previous state to wait for the transmit
            // to be accepted
            if (beat_countdown == 1)
                fsm_state <= fsm_state + 1;
            else
                fsm_state <= fsm_state - 1;
            
            // We have one fewer data beats left to transmit
            beat_countdown <= beat_countdown - 1;
        end

    // If our last data-beat has finished transmitting...
    4:  if (AXIS_TX_TREADY) begin

            // Place the packet-footer onto the TX data-bus
            AXIS_TX_TDATA <= req_id;

            // And go wait for the handshake
            fsm_state <= fsm_state + 1;

        end

    // If the packet-footer has been accepted...
    5:  if (AXIS_TX_TREADY) begin

            // We no longer have valid data on the TX data-bus
            AXIS_TX_TVALID <= 0;

            // We're ready for another incoming request
            AXIS_RQ_TREADY <= 1;

            // And go wait for that new request to arrive
            fsm_state <= 1;

        end

    endcase

end

endmodule


