`timescale 1ns/1ps

module uart_top_tb;

// This is a top-level testbench combining the uart_tx and uart_rx modules 

// Top-level parameters
parameter SYS_CLK_FREQ = 1000000; // Hz
parameter BAUD_RATE = 9600; // bit/s
parameter DATA_WIDTH = 8;
parameter SYS_CLK_PERIOD = 10**9 / SYS_CLK_FREQ; // ns
parameter UART_CLK_PERIOD = 10**9 / BAUD_RATE; // ns

// Shared inputs to receiver and transmitter
logic sys_clk;
logic sreset_n;
logic areset_n;

// Inputs and outputs associated with transmitter
logic [DATA_WIDTH-1:0] tx_data_in;
logic tx_data_valid;
logic tx_busy;

// Inputs and outputs associated with receiver
logic [DATA_WIDTH-1:0] rx_data_out;
logic rx_busy;

// Data line connecting transmitter and receiver
logic tx_rx_data;

// Instantiate DUTs

uart_tx #(
   .SYS_CLK_FREQ(SYS_CLK_FREQ),
   .BAUD_RATE(BAUD_RATE),
   .DATA_WIDTH(DATA_WIDTH)
)
dut_uart_tx (
    .sys_clk(sys_clk),
    .areset_n(areset_n),
    .sreset_n(sreset_n),
    .data_valid(tx_data_valid),
    .data_in(tx_data_in),
    .data_out(tx_rx_data),
    .busy(tx_busy)
);

uart_rx #(
   .SYS_CLK_FREQ(SYS_CLK_FREQ),
   .BAUD_RATE(BAUD_RATE),
   .DATA_WIDTH(DATA_WIDTH)   
)
dut_uart_rx (
    .sys_clk(sys_clk),
    .areset_n(areset_n),
    .sreset_n(sreset_n),
    .data_in(tx_rx_data),
    .data_out(rx_data_out),
    .busy(rx_busy)
);


parameter MIN_DELAY = 0; // ns
parameter MAX_DELAY = UART_CLK_PERIOD*5; // ns

// Class to introduce random delays between sending data
class send_data_delay;
    rand int delay_time;
    constraint delay { delay_time inside {[MIN_DELAY:MAX_DELAY]}; }
endclass

// Task to send data of width DATA_WIDTH to transmitter and check reception by receiver
task send_data();
    begin
        // Generate randomised input data
        @(posedge dut_uart_tx.uart_clk);
        tx_data_in = $urandom();
        tx_data_valid = 1;

        // Wait for tx_data to be registered by the transmitters
        @(negedge dut_uart_tx.uart_clk);
        tx_data_valid = 0;

        // Wait until reciever captures and outputs the data
        // wait(tx_rx_data); // Wait until start condition finishes
        @(negedge dut_uart_rx.uart_clk);
        wait(~rx_busy); // Wait until IDLE

        // Compare received data aginst transmitted data
        if (rx_data_out === tx_data_in) begin
            $display("INFO | TEST PASSED - tx_data_in  = %b, rx_data_out = %b", tx_data_in, rx_data_out);
        end else begin
            $display("ERROR | TEST FAILED - tx_data_in  = %b, rx_data_out = %b", tx_data_in, rx_data_out);
        end
    end
endtask


// Simulation
parameter NUM_TRANSFERS = 10; // Number of data transfer events

// System clock generation
always #(SYS_CLK_PERIOD/2) sys_clk = ~sys_clk;

// Instantiate send_data_delay class
send_data_delay delay_inst;

initial begin
    // Initialise input signals
    sys_clk = 0;
    sreset_n = 0;
    areset_n = 1;
    tx_data_valid = 0;
    tx_data_in = {DATA_WIDTH{1'b0}};
    
    // Create new delay object
    delay_inst = new();

    // Release reset
    #(2*UART_CLK_PERIOD) sreset_n = 1;

    // Call task to send data and check reception
    for (int i=0; i < NUM_TRANSFERS; i++) begin
        delay_inst.randomize();
        #delay_inst.delay_time;
        wait(~tx_busy);
        send_data();
    end

    // Wait for completion
    #(2*UART_CLK_PERIOD);
    $finish;
end


endmodule