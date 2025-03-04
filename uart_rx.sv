module uart_rx #(
    parameter SYS_CLK_FREQ = 10**6, // Hz
    parameter BAUD_RATE = 9600, // bit/s
    parameter DATA_WIDTH = 8
)
(
    input logic sys_clk, // Input system clock
    input logic areset_n, // Asynchronous active-low reset
    input logic sreset_n, // Synchronous active-low reset
    input logic data_in, // Input (serialised) data from UART transmitter

    output logic [DATA_WIDTH-1:0] data_out, // Output data
    output logic busy // Receiver is busy collecting data
);

// This local parameter is used to derive a slower clock from a (typically) faster system clock
// for the UART system to use 
localparam CLK_COUNT_INT = SYS_CLK_FREQ / BAUD_RATE;

logic uart_clk = 0; // UART clock with frequency defined by Baud Rate
logic [$clog2(CLK_COUNT_INT/2) - 1: 0] uart_clk_count;

// Define operational states of receiver
typedef enum logic {IDLE, RECEIVING} state;

state rx_state;

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

logic [$clog2(DATA_WIDTH):0] data_in_count; // To count the number of data bits received

always_ff @(posedge uart_clk or negedge areset_n) begin
    if (~sreset_n) begin
        rx_state <= IDLE;
        data_out <= {DATA_WIDTH{1'b0}};
        data_in_count <= 0;
    end
    else if (~areset_n) begin
        rx_state <= IDLE;
        data_out <= {DATA_WIDTH{1'b0}};
        data_in_count <= 0;
    end
    else begin
        case (rx_state)
            IDLE: begin
                data_in_count <= 0;
                if (data_in == 0) begin
                    data_out <= {DATA_WIDTH{1'b0}};
                    rx_state <= RECEIVING;
                end
                else begin
                    data_out <= {DATA_WIDTH{1'b0}};
                    rx_state <= IDLE;
                end
            end
            RECEIVING : begin
                if (data_in_count <= DATA_WIDTH-1) begin
                    data_in_count <= data_in_count + 1;
                    data_out <= {data_in, data_out[DATA_WIDTH-1:1]};
                    rx_state <= RECEIVING;
                end
                else begin
                    data_in_count <= 0;
                    // data_out <= {DATA_WIDTH{1'b0}};
                    rx_state <= IDLE;
                end
            end
            default: rx_state <= IDLE;
        endcase
        
    end
end

assign busy = (rx_state != IDLE);

endmodule