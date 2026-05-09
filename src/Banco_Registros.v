module Banco_Registros (
    input  wire        clk,
    input  wire        rst,
    input  wire        gate,          // NUEVO: ui_in[3]
    
    // Interfaz UART (Desde la FSM de Control)
    input  wire        we_uart,       
    input  wire [2:0]  addr_uart,     
    input  wire [15:0] data_in_uart,  
    input  wire        clear_metrics, 

    // Interfaz Interna (Desde Captura y Matemáticas)
    input  wire        trigger_math,
    input  wire [15:0] actual_jitter,
    input  wire        is_error,
    input  wire        timeout_error,

    output reg  [15:0] reg_ideal,
    output reg  [15:0] reg_tol,
    output reg  [15:0] reg_max,
    output reg  [15:0] reg_min,
    output reg  [15:0] reg_tot,
    output reg  [15:0] reg_err
);

    // Sincronizador simple para el gate
    reg gate_s1, gate_s2;
    always @(posedge clk) begin
        gate_s1 <= gate;
        gate_s2 <= gate_s1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_ideal <= 16'd1000; 
            reg_tol   <= 16'd50;   
            reg_max   <= 16'h0000;
            reg_min   <= 16'hFFFF; 
            reg_tot   <= 16'h0000;
            reg_err   <= 16'h0000;
        end else begin
            
            // 1. Escritura desde UART (Siempre permitida)
            if (we_uart) begin
                case (addr_uart)
                    3'h1: reg_ideal <= data_in_uart;
                    3'h2: reg_tol   <= data_in_uart;
                endcase
            end

            // 2. Limpieza de métricas
            if (clear_metrics) begin
                reg_max <= 16'h0000;
                reg_min <= 16'hFFFF;
                reg_tot <= 16'h0000;
                reg_err <= 16'h0000;
            end 
            // 3. Actualización de métricas (SOLO si GATE está activo)
            else if (gate_s2) begin
                if (trigger_math) begin
                    reg_tot <= reg_tot + 1; 
                    if (actual_jitter > reg_max) reg_max <= actual_jitter;
                    if (actual_jitter < reg_min) reg_min <= actual_jitter;
                    if (is_error) reg_err <= reg_err + 1;
                end
                
                if (timeout_error) begin
                    reg_err <= reg_err + 1; 
                end
            end
        end
    end
endmodule