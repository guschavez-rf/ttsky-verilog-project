module Banco_Registros (
    input  wire        clk,
    input  wire        rst,
    input  wire        gate,          
    input  wire        we_uart,       
    input  wire [2:0]  addr_uart,     
    input  wire [15:0] data_in_uart,  
    input  wire        clear_metrics, 
    input  wire        trigger_math,
    input  wire [14:0] actual_jitter, 
    input  wire        is_error,
    input  wire        timeout_error,

    output reg  [14:0] reg_ideal,
    output reg  [14:0] reg_tol,
    output reg  [14:0] reg_max,
    output reg  [11:0] reg_tot, 
    output reg  [11:0] reg_err  
);

    // Eliminamos gate_s1 y gate_s2. Usamos gate directamente.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_ideal <= 15'd1000; reg_tol <= 15'd50;
            reg_max <= 15'h0; reg_tot <= 12'h0; reg_err <= 12'h0;
        end else begin
            if (we_uart) begin
                if (addr_uart == 3'h1) reg_ideal <= data_in_uart[14:0];
                else if (addr_uart == 3'h2) reg_tol <= data_in_uart[14:0];
            end

            if (clear_metrics) begin
                reg_max <= 15'h0; reg_tot <= 12'h0; reg_err <= 12'h0;
            end else if (gate) begin // 'gate' ya viene sincronizado del motor
                if (trigger_math) begin
                    if (reg_tot != 12'hFFF) reg_tot <= reg_tot + 12'd1;
                    if (actual_jitter > reg_max) reg_max <= actual_jitter;
                    if (is_error && reg_err != 12'hFFF) reg_err <= reg_err + 12'd1;
                end
                if (timeout_error && reg_err != 12'hFFF) reg_err <= reg_err + 12'd1;
            end
        end
    end
endmodule