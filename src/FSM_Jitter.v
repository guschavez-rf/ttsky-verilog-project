// ===============================================================================
// MODULO: FSM_Jitter (Optimizado con Multiplexor Combinacional a 15 bits)
// ===============================================================================
module FSM_Jitter (
    input  wire        clk,
    input  wire        rst,
    
    // Interfaz UART_RX
    input  wire [7:0]  rx_data,
    input  wire        rx_done,       
    output reg         rx_next,       
    
    // Interfaz UART_TX
    input  wire        tx_ready,
    output reg         tx_start,      
    output reg  [7:0]  tx_data,       
    
    // Interfaz Banco_Registros (Control)
    output reg         we_uart,
    output reg  [2:0]  addr_uart,
    output reg  [15:0] data_out_uart,
    output reg         clear_metrics,
    
    // CORRECCIÓN: Entradas devueltas a 15 bits para igualar al Top y al Banco
    input  wire [14:0] reg_ideal,
    input  wire [14:0] reg_tol,
    input  wire [14:0] reg_max,
    input  wire [14:0] reg_min,
    input  wire [14:0] reg_tot,
    input  wire [14:0] reg_err 
);

    // Comandos ASCII
    localparam SYNC_CHAR = 8'h24; // '$'
    localparam CMD_I     = 8'h49; // 'I'
    localparam CMD_T     = 8'h54; // 'T'
    localparam CMD_M     = 8'h4D; // 'M'
    localparam CMD_N     = 8'h4E; // 'N'
    localparam CMD_S     = 8'h53; // 'S'
    localparam CMD_G     = 8'h47; // 'G'
    localparam CMD_R     = 8'h52; // 'R'

    // Estados de la FSM
    localparam IDLE         = 4'd0;
    localparam WAIT_CMD     = 4'd1;
    localparam WAIT_DATA_H  = 4'd2;
    localparam WAIT_DATA_L  = 4'd3;
    localparam EXEC_WRITE   = 4'd4;
    localparam LOAD_READ    = 4'd5;
    localparam SEND_HIGH    = 4'd6;
    localparam WAIT_TX_H    = 4'd7;
    localparam SEND_LOW     = 4'd8;
    localparam WAIT_TX_L    = 4'd9;
    localparam ACK_RX       = 4'd10;

    reg [3:0]  estado;
    reg [3:0]  estado_retorno; 
    reg [7:0]  comando_actual;
    reg [7:0]  temp_high;

    // CORRECCIÓN: Multiplexor limpio leyendo los 15 bits y restaurando CMD_N
    wire [14:0] mux_data = (comando_actual == CMD_M) ? reg_max :
                           (comando_actual == CMD_N) ? reg_min :
                           (comando_actual == CMD_S) ? reg_tot :
                           (comando_actual == CMD_G) ? reg_err : 15'h7FFF;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado        <= IDLE;
            rx_next       <= 0;
            tx_start      <= 0;
            we_uart       <= 0;
            clear_metrics <= 0;
            tx_data       <= 8'h0;
        end else begin
            tx_start      <= 0;
            we_uart       <= 0;
            clear_metrics <= 0;
            rx_next       <= 0;

            case (estado)
                IDLE: begin
                    if (rx_done && !rx_next) begin
                        if (rx_data == SYNC_CHAR) begin
                            estado_retorno <= WAIT_CMD;
                            estado         <= ACK_RX;
                        end else begin
                            estado_retorno <= IDLE; 
                            estado         <= ACK_RX;
                        end
                    end
                end

                WAIT_CMD: begin
                    if (rx_done && !rx_next) begin
                        comando_actual <= rx_data;
                        if (rx_data == CMD_I || rx_data == CMD_T) begin
                            estado_retorno <= WAIT_DATA_H;
                        end else if (rx_data == CMD_R) begin
                            clear_metrics  <= 1; 
                            estado_retorno <= IDLE;
                        end else begin
                            estado_retorno <= LOAD_READ; 
                        end
                        estado <= ACK_RX;
                    end
                end

                WAIT_DATA_H: begin
                    if (rx_done && !rx_next) begin
                        temp_high      <= rx_data;
                        estado_retorno <= WAIT_DATA_L;
                        estado         <= ACK_RX;
                    end
                end

                WAIT_DATA_L: begin
                    if (rx_done && !rx_next) begin
                        data_out_uart  <= {temp_high, rx_data}; 
                        addr_uart      <= (comando_actual == CMD_I) ? 3'h1 : 3'h2;
                        estado_retorno <= EXEC_WRITE;
                        estado         <= ACK_RX;
                    end
                end

                EXEC_WRITE: begin
                    we_uart <= 1; 
                    estado  <= IDLE;
                end

                LOAD_READ: begin
                    estado <= SEND_HIGH;
                end

                SEND_HIGH: begin
                    if (tx_ready) begin
                        tx_data  <= {1'b0, mux_data[14:8]}; // MSB
                        tx_start <= 1;
                        estado   <= WAIT_TX_H;
                    end
                end

                WAIT_TX_H: begin
                    if (!tx_ready) estado <= SEND_LOW; 
                end

                SEND_LOW: begin
                    if (tx_ready) begin
                        tx_data  <= mux_data[7:0]; // LSB
                        tx_start <= 1;
                        estado   <= WAIT_TX_L;
                    end
                end

                WAIT_TX_L: begin
                    if (!tx_ready) estado <= IDLE;
                end

                ACK_RX: begin
                    rx_next <= 1; 
                    if (!rx_done) begin
                        rx_next <= 0;
                        estado  <= estado_retorno; 
                    end
                end
                default: estado <= IDLE;
            endcase
        end
    end
endmodule