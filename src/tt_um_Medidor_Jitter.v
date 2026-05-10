// ===============================================================================
// MODULO TOP: tt_um_Medidor_Jitter
// ===============================================================================
module tt_um_Medidor_Jitter (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    localparam CLK_FREQ = 50000000; 
    localparam BAUDRATE = 115200;   

    wire rst = ~rst_n;

    wire rx_pin   = ui_in[0];
    wire sig_in   = ui_in[1];
    wire gate_pin = ui_in[3];
    wire ref_clk  = ui_in[4];

    wire tx_pin;
    assign uo_out[0] = tx_pin;

    assign uo_out[7:1] = 7'b0;
    assign uio_out     = 8'b0;
    assign uio_oe      = 8'b0;

    wire [7:0] uart_rx_data;
    wire       uart_rx_done;
    wire       uart_rx_next;
    wire [7:0] uart_tx_data;
    wire       uart_tx_start;
    wire       uart_tx_ready;
    wire       uart_tx_done;

    wire        fsm_we;
    wire [2:0]  fsm_addr;
    wire [15:0] fsm_data;
    wire        fsm_clear;

    // Cables ajustados: reg_min eliminado, contadores a 12 bits
    wire [14:0] reg_ideal, reg_tol, reg_max;
    wire [11:0] reg_tot, reg_err; 
    wire [14:0] t_medido;
    wire        trigger_math;
    wire        timeout_error;
    wire [14:0] actual_jitter;
    wire        is_error;

    UART_V1 #(
        .clk_frec_fpga(CLK_FREQ), 
        .tasa_baudios(BAUDRATE)
    ) U_UART (
        .clk(clk),
        .rst(rst),
        .RX(rx_pin),
        .datos_recibido(uart_rx_data),
        .hecho_rx(uart_rx_done),
        .next_ready(uart_rx_next),
        .TX(tx_pin),
        .datos_enviar(uart_tx_data),
        .datos_validos(uart_tx_start),
        .tx_ready(uart_tx_ready),
        .hecho_tx(uart_tx_done)
    );

    FSM_Jitter U_FSM (
        .clk(clk),
        .rst(rst),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done),
        .rx_next(uart_rx_next),
        .tx_ready(uart_tx_ready),
        .tx_start(uart_tx_start),
        .tx_data(uart_tx_data),
        .we_uart(fsm_we),
        .addr_uart(fsm_addr),
        .data_out_uart(fsm_data),
        .clear_metrics(fsm_clear),
        .reg_ideal(reg_ideal),
        .reg_tol(reg_tol),
        .reg_max(reg_max),
        .reg_tot(reg_tot),
        .reg_err(reg_err)
    );

    Banco_Registros U_BANCO (
        .clk(clk),
        .rst(rst),
        .gate(gate_pin),
        .we_uart(fsm_we),
        .addr_uart(fsm_addr),
        .data_in_uart(fsm_data),
        .clear_metrics(fsm_clear),
        .trigger_math(trigger_math),
        .actual_jitter(actual_jitter),
        .is_error(is_error),
        .timeout_error(timeout_error),
        .reg_ideal(reg_ideal),
        .reg_tol(reg_tol),
        .reg_max(reg_max),
        .reg_tot(reg_tot),
        .reg_err(reg_err)
    );

    Motor_Captura U_MOTOR (
        .clk(clk),
        .rst(rst),
        .gate(gate_pin),
        .ref_clk(ref_clk),
        .sig_in(sig_in),
        .reg_ideal(reg_ideal),
        .t_medido(t_medido),
        .trigger_math(trigger_math),
        .timeout_error(timeout_error)
    );

    Mod_Matematico U_MATH (
        .t_medido(t_medido),
        .reg_ideal(reg_ideal),
        .reg_tol(reg_tol),
        .actual_jitter(actual_jitter),
        .is_error(is_error)
    );

    // =======================================================================
    // SUMIDERO DE SEÑALES NO USADAS (Mantiene limpio el diseño para OpenLane)
    // =======================================================================
    wire _unused = &{ena, ui_in[7:5], ui_in[2], uio_in, uart_tx_done, 1'b0};

endmodule