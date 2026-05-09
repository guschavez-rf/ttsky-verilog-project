module FSM_Jitter (
    input  wire        clk,
    input  wire        rst,
    
    // Interfaz con UART_RX
    input  wire [7:0]  rx_data,
    input  wire        rx_done,       // hecho_rx del UART
    output reg         rx_next,       // next_ready para el UART
    
    // Interfaz con UART_TX
    input  wire        tx_ready,
    output reg         tx_start,      // datos_validos para el UART
    output reg  [7:0]  tx_data,       // datos_enviar para el UART
    
    // Interfaz con Banco_Registros (Control)
    output reg         we_uart,
    output reg  [2:0]  addr_uart,
    output reg  [15:0] data_out_uart,
    output reg         clear_metrics,
    
    // Interfaz con Banco_Registros (Lectura)
    input  wire [15:0] reg_ideal,
    input  wire [15:0] reg_tol,
    input  wire [15:0] reg_max,
    input  wire [15:0] reg_min,
    input  wire [15:0] reg_tot,
    input  wire [15:0] reg_err
);

    // Códigos ASCII de las instrucciones
    localparam SYNC_CHAR = 8'h24; // '$'
    localparam CMD_I     = 8'h49; // 'I' - Set Ideal
    localparam CMD_T     = 8'h54; // 'T' - Set Tolerancia
    localparam CMD_M     = 8'h4D; // 'M' - Get Max
    localparam CMD_N     = 8'h4E; // 'N' - Get Min
    localparam CMD_S     = 8'h53; // 'S' - Get Total
    localparam CMD_G     = 8'h47; // 'G' - Get Errores (Cambiado de 'E' a 'G')
    localparam CMD_R     = 8'h52; // 'R' - Reset Métricas

    // Máquina de Estados
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
    reg [3:0]  estado_retorno; // Para saber a dónde volver tras un ACK
    reg [7:0]  comando_actual;
    reg [7:0]  temp_high;
    reg [15:0] data_to_send;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado        <= IDLE;
            rx_next       <= 0;
            tx_start      <= 0;
            we_uart       <= 0;
            clear_metrics <= 0;
        end else begin
            // Valores por defecto (se limpian automáticamente en 1 ciclo de clk)
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
                            estado_retorno <= IDLE; // Ignora basura, exige el '$'
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
                            clear_metrics  <= 1; // Pulso de limpieza
                            estado_retorno <= IDLE;
                        end else begin
                            estado_retorno <= LOAD_READ; // Asume comando de lectura
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
                        data_out_uart  <= {temp_high, rx_data}; // Ensambla 16 bits
                        addr_uart      <= (comando_actual == CMD_I) ? 3'h1 : 3'h2;
                        estado_retorno <= EXEC_WRITE;
                        estado         <= ACK_RX;
                    end
                end

                EXEC_WRITE: begin
                    we_uart <= 1; // Pulso de escritura al banco
                    estado  <= IDLE;
                end

                LOAD_READ: begin
                    case (comando_actual)
                        CMD_M: data_to_send <= reg_max;
                        CMD_N: data_to_send <= reg_min;
                        CMD_S: data_to_send <= reg_tot;
                        CMD_G: data_to_send <= reg_err; // Ahora responde al comando 'G'
                        default: data_to_send <= 16'hFFFF; // Error
                    endcase
                    estado <= SEND_HIGH;
                end

                SEND_HIGH: begin
                    if (tx_ready) begin
                        tx_data  <= data_to_send[15:8]; // Envía MSB
                        tx_start <= 1;
                        estado   <= WAIT_TX_H;
                    end
                end

                WAIT_TX_H: begin
                    if (!tx_ready) estado <= SEND_LOW; // Espera a que el TX empiece a trabajar
                end

                SEND_LOW: begin
                    if (tx_ready) begin
                        tx_data  <= data_to_send[7:0];  // Envía LSB
                        tx_start <= 1;
                        estado   <= WAIT_TX_L;
                    end
                end

                WAIT_TX_L: begin
                    if (!tx_ready) estado <= IDLE;
                end

                // --- Estado Auxiliar para el Handshake del UART_RX ---
                ACK_RX: begin
                    rx_next <= 1; // Pide al UART que baje su bandera de 'rx_done'
                    if (!rx_done) begin
                        rx_next <= 0;
                        estado  <= estado_retorno; // Vuelve a donde estaba
                    end
                end

            endcase
        end
    end
endmodule