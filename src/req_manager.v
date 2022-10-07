
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
    output              AXIS_RQ_TREADY,
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


reg        get_new_rx;
reg        rx_data_valid;
reg        axis_rx_tready;

wire       is_rx_data_valid = (get_new_rx == 0 && rx_data_valid == 1);

reg[255:0] data_word[0:1];


//===================================================================================================
// State machine that allows incoming data to flow in
//===================================================================================================
assign AXIS_RX_TREADY = (resetn == 1) && (get_new_rx || axis_rx_tready);
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
        if (get_new_rx) begin
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
// State machine that allows incoming data-requests to flow in
//===================================================================================================

// This will be driven high for one cycle when we're ready for a new data-request to arrive
reg get_new_rq;

// The most recently arrived data-request
reg[31:0] rq_data;

// This is '1' if rq_data holds a valid data-request
reg rq_data_valid;

// AXIS_RQ_TREADY stays high as long as this is high
reg axis_rq_tready;      

// AXIS_RQ_TREADY goes high as soon as get_new_rq goes high
assign AXIS_RQ_TREADY = (resetn == 1) && (get_new_rq || axis_rq_tready);

//===================================================================================================
always @(posedge clk) begin
   
    // If we're in reset, by definition rq_data isn't valid.
    // When we come out of reset, we want to instantly drive AXIS_RQ_TREADY 
    // high so that a data-request flows in as soon as one is available
    if (resetn == 0) begin
        rq_data_valid  <= 0;
        axis_rq_tready <= 1;
    end else begin

        // If the other state machine asked for a new data-request, AXIS_RQ_TREADY is 
        // already high.   Here we keep track of the fact that we want it to stay high
        // and we declare that the rq_data register no longer holds a valid data-request.
        if (get_new_rq) begin
            axis_rq_tready <= 1;
            rq_data_valid  <= 0;
        end

        // If a new data-request has arrived...
        if (RQ_HANDSHAKE) begin
            
            // Lower the AXIS_RQ_TREADY signal
            axis_rq_tready <= 0;
            
            // Store the data-request that just arrived
            rq_data <= AXIS_RQ_TDATA;

            // And indicate that rq_data holds a valid data-request
            rq_data_valid  <= 1;
        end
    end

end
//===================================================================================================




//===================================================================================================
// flow state machine: main state machine that waits for a data-request to arrive, then transmits
// a 1 cycle packet header, 64 cycles of packet data, and 1 cycle of packet footer
//===================================================================================================
reg[2:0]   fsm_state;
reg[31:0]  req_id;
reg[255:0] buffered_word;
reg[7:0]   beat_countdown;
//===================================================================================================

localparam FSM_WAIT_FOR_REQ    = 0;
localparam FSM_SEND_UPPER_HALF = 1;
localparam FSM_SEND_LOWER_HALF = 2;
localparam FSM_EMIT_FOOTER     = 3;
localparam FSM_WAIT_FOR_FINISH = 4;

always @(posedge clk) begin
    
    // These signals strobe high for only a single cycle
    get_new_rx <= 0;
    get_new_rq <= 0;
    
    if (resetn == 0) begin
        AXIS_TX_TVALID <= 0;
        fsm_state      <= 1;
    end else case(fsm_state)


    FSM_WAIT_FOR_REQ:

        // If a new request has arrived...
        if (rq_data_valid) begin
            
            // Keep track of the data-request ID for future use
            req_id <= rq_data;

            // Emit a packet-header which consists of the data-request ID
            AXIS_TX_TDATA <= rq_data;

            // We have valid data on the TX data bus
            AXIS_TX_TVALID <= 1;

            // Allow another data-request to get buffered up
            get_new_rq <= 1;

            // This is how many beats of RX data we have left to send
            beat_countdown <= RX_BEATS_PER_PACKET;

            // And go to the next state
            fsm_state <= FSM_SEND_UPPER_HALF;
        end
        

    
    FSM_SEND_UPPER_HALF:
        
        // If the cycle we just transmitted has been accepted
        if (AXIS_TX_TREADY == 1 || AXIS_TX_TVALID == 0) begin
            
            // We no longer have valid data on the TX bus
            AXIS_TX_TVALID <= 0;
          
            // If we have valid data from the RX data bus...
            if (is_rx_data_valid) begin
                
                // Place half of the received data onto the TX data bus
                AXIS_TX_TDATA <= data_word[0];
                
                // Save the other half of the received data for future use
                buffered_word <= data_word[1];
                
                // Allow more data to flow in
                get_new_rx <= 1;

                // The data on the TX data bus is valid
                AXIS_TX_TVALID <= 1;

                // And go to the next state
                fsm_state <= FSM_SEND_LOWER_HALF;

            end

        end


    FSM_SEND_LOWER_HALF:

        // If the data-cycle we just transmitted was accepted...
        if (AXIS_TX_TREADY) begin
              
            // Place the second half of the received data onto the TX data bus
            AXIS_TX_TDATA <= buffered_word;

            // If this was the last data-beat we need to transmit, go to the next
            // state, otherwise, go to the previous state to wait for the transmit
            // to be accepted.
            fsm_state = (beat_countdown == 1) ? FSM_EMIT_FOOTER : FSM_SEND_UPPER_HALF;
            
            // We have one fewer data beats left to transmit
            beat_countdown <= beat_countdown - 1;
        end

    FSM_EMIT_FOOTER:

        // If our last data-beat has finished transmitting, place a packet
        // footer on the TX data-bus and go wait for it to be accepted
        if (AXIS_TX_TREADY) begin
            AXIS_TX_TDATA <= req_id;
            fsm_state     <= FSM_WAIT_FOR_FINISH;
        end

    FSM_WAIT_FOR_FINISH:

        // If the packet footer was accepted...
        if (AXIS_TX_TREADY) begin

            // If we have another data-request pending...
            if (rq_data_valid) begin
                  
                // Keep track of the data-request ID for future use
                req_id <= rq_data;

                // Emit a packet-header which consists of the data-request ID
                AXIS_TX_TDATA <= rq_data;

                // Allow another data-request to get buffered up
                get_new_rq <= 1;

                // This is how many beats of RX data we have left to send
                beat_countdown <= RX_BEATS_PER_PACKET;

                // Go start emitting packet data
                fsm_state <= FSM_SEND_UPPER_HALF;

            end

            // Otherwise, we no longer have valid data on the TX data-bus
            // and we need to go wait for a request to arrive
            else begin
                AXIS_TX_TVALID <= 0;
                fsm_state      <= FSM_WAIT_FOR_REQ;
            end
        end

    endcase

end
//===================================================================================================


endmodule


