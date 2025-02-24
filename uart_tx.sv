module uart_tx #(
    parameter SYS_CLK_FREQ = 10**6, // Hz
    parameter BAUD_RATE = 9600, // bit/s
    parameter DATA_WIDTH = 8
)
(
    input logic sys_clk, // Input system clock
    input logic areset_n, // Asynchronous active-low reset
    input logic sreset_n, // Synchronous active-low reset
    input logic data_valid, // Input data is valid from upstream component
    input logic [DATA_WIDTH-1:0] data_in, // Input data from upstream component
    
    output logic data_out, // Output (serialised) data
    output logic busy // Transmitter is busy sending data
);

// This local parameter is used to derive a slower clock from a (typically) faster system clock
// for the UART system to use 
localparam CLK_COUNT_INT = SYS_CLK_FREQ / BAUD_RATE;

logic uart_clk = 0; // UART clock with frequency defined by Baud Rate
logic [$clog2(CLK_COUNT_INT/2) - 1: 0] uart_clk_count;

logic [DATA_WIDTH-1:0] data_reg; // Internal register to store input data
logic [$clog2(DATA_WIDTH):0] data_index; // To index into data_reg

// Define operational states of transmitter
typedef enum logic {IDLE, TRANSFERRING} state;

state tx_state; 

// Generate UART clock from system clock
always_ff @(posedge sys_clk) begin
   if (uart_clk_count < CLK_COUNT_INT/2) begin
        uart_clk_count <= uart_clk_count + 1;
   end
   else begin
        uart_clk_count <= 0;
        uart_clk <= ~uart_clk; // Toggle clock signal after each half-period
   end
end

// Handle resets and FSM state transitions 
always_ff @(posedge uart_clk or negedge areset_n) begin
    if (~sreset_n) begin
        tx_state <= IDLE;
    end
    else if (~areset_n) begin
        tx_state <= IDLE;
    end
    else begin
        case (tx_state)
            IDLE : begin
                data_index <= 0;
                if (data_valid) begin
                    data_reg <= data_in;
                    data_out <= 1'b0;
                    tx_state <= TRANSFERRING;
                end
                else begin
                    tx_state <= IDLE;
                    data_out <= 1;
                end 
            end
            TRANSFERRING : begin
                if (data_index <= DATA_WIDTH-1) begin
                    data_index <= data_index + 1;
                    data_out <= data_reg[data_index];
                    tx_state <= TRANSFERRING;
                end
                else begin
                    data_out <= 1;
                    data_index <= 0;
                    tx_state <= IDLE;
                end
            end
            default : tx_state <= IDLE;
        endcase
    end 
end

assign busy = (tx_state != IDLE);

endmodule