
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
    output              AXIS_RX_TREADY,
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
reg        axis_rx_tready;

wire       is_rx_data_valid = (rx_data_req == 0 && rx_data_valid == 1);

reg[255:0] data_word[0:1];


//===================================================================================================
// State machine that allows incoming data to flow in
//===================================================================================================
assign AXIS_RX_TREADY = (resetn == 1) && (rx_data_req || axis_rx_tready);
//===================================================================================================
always @(posedge clk) begin
   
    // If we're in reset, by definition the data_word[] values aren't valid.
    // When we come out of reset, we want to instantly drive AXIS_RX_TREADY 
    // high so that a data-word flows in as soon as one is ready
    if (resetn == 0) begin
        rx_data_valid  <= 0;
        axis_rx_tready <= 1;
    end else begin

        // If the other state machine asks for new data, AXIS_RX_TREADY is already
        // high.   Here we keep track of the fact that we want it to stay high
        // and we declare the data_word[] registers to no longer hold valid data.
        if (rx_data_req) begin
            axis_rx_tready <= 1;
            rx_data_valid  <= 0;
        end

        // If incoming data has arrived...
        if (RX_HANDSHAKE) begin
            
            // Lower the AXIS_RX_TREADY signal
            axis_rx_tready <= 0;
            
            // Store the data that just arrived
            data_word[0] <= AXIS_RX_TDATA[511:256];
            data_word[1] <= AXIS_RX_TDATA[255:000];

            // And indicate that data_word[] holds valid values
            rx_data_valid  <= 1;
        end
    end

end
//===================================================================================================



//===================================================================================================
// flow state machine: main state machine that waits for a data-request to arrive, then transmits
// a 1 cycle packet header, 64 cycles of packet data, and 1 cycle of packet footer
//===================================================================================================
reg[2:0]   fsm_state;
reg[31:0]  req_id, buffered_request;
reg[255:0] buffered_word;
reg[7:0]   beat_countdown;
//===================================================================================================
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
    1:  if (AXIS_RQ_TVALID) begin
            
            // Keep track of the data-request ID for future use
            req_id <= AXIS_RQ_TDATA;

            // Emit a packet-header which consists of the data-request ID
            AXIS_TX_TDATA <= AXIS_RQ_TDATA;

            // We have valid data on the TX data bus
            AXIS_TX_TVALID <= 1;

            // We are no longer ready for a new data request
            AXIS_RQ_TREADY <= 0;

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
            // state, otherwise, go to the previous state to wait for the transmit
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

            // Allow another data-request to arrive
            AXIS_RQ_TREADY <= 1;

            // And go wait for the handshake
            fsm_state <= fsm_state + 1;

        end

    5:  begin

            // If a new data-request has arrived, save it, and lower AXIS_RQ_TREADY 
            // to signal that we are no longer accepting data-requests
            if (RQ_HANDSHAKE) begin
                req_id         <= AXIS_RQ_TDATA;
                AXIS_RQ_TREADY <= 0;
            end

            // If the packet footer we transmitted has been accepted...
            if (AXIS_TX_TREADY) begin
                
                // If we have a buffered data-request that we need to emit a packet header for...
                if (AXIS_RQ_TREADY == 0) begin
                    AXIS_TX_TDATA  <= req_id;
                    beat_countdown <= RX_BEATS_PER_PACKET;
                    fsm_state      <= 2;
                end 

                // If a data-request has just arrived and we need to emit a packet header...
                else if (AXIS_RQ_TVALID) begin
                    AXIS_TX_TDATA  <= AXIS_RQ_TDATA;
                    beat_countdown <= RX_BEATS_PER_PACKET;
                    fsm_state      <= 2;
                end

                // Otherwise, we no longer have valid data on the TX data-bus
                // and we need to go wait for a request to arrive
                else begin
                    AXIS_TX_TVALID <= 0;
                    fsm_state      <= 1;
                end
           
            end

        end

    endcase

end
//===================================================================================================


endmodule


