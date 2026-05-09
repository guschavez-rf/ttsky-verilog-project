module Banco_Registros (
    input  wire        clk,
    input  wire        rst,
    input  wire        gate,          
    
    // Interfaz UART
    input  wire        we_uart,       
    input  wire [2:0]  addr_uart,     
    input  wire [15:0] data_in_uart,  // Mantenemos 16 en bus por compatibilidad UART
    input  wire        clear_metrics, 

    // Interfaz Interna
    input  wire        trigger_math,
    input  wire [14:0] actual_jitter, // Reducido a 15
    input  wire        is_error,
    input  wire        timeout_error,

    output reg  [14:0] reg_ideal,
    output reg  [14:0] reg_tol,
    output reg  [14:0] reg_max,
    output reg  [14:0] reg_min,
    output reg  [14:0] reg_tot,
    output reg  [14:0] reg_err
);

    reg gate_s1, gate_s2;
    always @(posedge clk) begin
        gate_s1 <= gate;
        gate_s2 <= gate_s1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_ideal <= 15'd1000; 
            reg_tol   <= 15'd50;   
            reg_max   <= 15'h0000;
            reg_min   <= 15'h7FFF; // Máximo valor para 15 bits
            reg_tot   <= 15'h0000;
            reg_err   <= 15'h0000;
        end else begin
            if (we_uart) begin
                case (addr_uart)
                    3'h1: reg_ideal <= data_in_uart[14:0];
                    3'h2: reg_tol   <= data_in_uart[14:0];
                endcase
            end

            if (clear_metrics) begin
                reg_max <= 15'h0000;
                reg_min <= 15'h7FFF;
                reg_tot <= 15'h0000;
                reg_err <= 15'h0000;
            end 
            else if (gate_s2) begin
                if (trigger_math) begin
                    reg_tot <= reg_tot + 15'd1; 
                    if (actual_jitter > reg_max) reg_max <= actual_jitter;
                    if (actual_jitter < reg_min) reg_min <= actual_jitter;
                    if (is_error) reg_err <= reg_err + 15'd1;
                end
                if (timeout_error) reg_err <= reg_err + 15'd1;
            end
        end
    end
endmodule