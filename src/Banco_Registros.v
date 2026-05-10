// ===============================================================================
// MODULO: Banco_Registros (Saturación a 4095 y sin reg_min)
// ===============================================================================
module Banco_Registros (
    input  wire        clk,
    input  wire        rst,
    input  wire        gate,          
    
    // Interfaz UART
    input  wire        we_uart,       
    input  wire [2:0]  addr_uart,     
    input  wire [15:0] data_in_uart,  
    input  wire        clear_metrics, 

    // Interfaz Interna
    input  wire        trigger_math,
    input  wire [14:0] actual_jitter, 
    input  wire        is_error,
    input  wire        timeout_error,

    output reg  [14:0] reg_ideal,
    output reg  [14:0] reg_tol,
    output reg  [14:0] reg_max,
    output reg  [11:0] reg_tot, // 12 bits
    output reg  [11:0] reg_err  // 12 bits
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
            reg_tot   <= 12'h000;
            reg_err   <= 12'h000;
        end else begin
            // Escritura de la UART
            if (we_uart) begin
                case (addr_uart)
                    3'h1: reg_ideal <= data_in_uart[14:0];
                    3'h2: reg_tol   <= data_in_uart[14:0];
                endcase
            end

            // Limpieza de métricas (Comando 'R')
            if (clear_metrics) begin
                reg_max <= 15'h0000;
                reg_tot <= 12'h000;
                reg_err <= 12'h000;
            end 
            // Conteo y Saturación
            else if (gate_s2) begin
                // Manejo del conteo total y Jitter máximo
                if (trigger_math) begin
                    // Saturación para Total: Se queda pegado en 4095 (FFF)
                    if (reg_tot != 12'hFFF) begin
                        reg_tot <= reg_tot + 12'd1;
                    end
                    
                    if (actual_jitter > reg_max) begin
                        reg_max <= actual_jitter;
                    end
                end
                
                // Manejo de errores unificado con Saturación
                if ((trigger_math && is_error) || timeout_error) begin
                    // Saturación para Errores: Se queda pegado en 4095 (FFF)
                    if (reg_err != 12'hFFF) begin
                        reg_err <= reg_err + 12'd1;
                    end
                end
            end
        end
    end
endmodule