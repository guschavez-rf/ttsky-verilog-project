// ===============================================================================
// MODULO: Motor_Captura
// ===============================================================================
module Motor_Captura (
    input  wire        clk,
    input  wire        rst,
    input  wire        gate,          
    input  wire        ref_clk,       
    input  wire        sig_in,        
    input  wire [15:0] reg_ideal,     
    output reg  [15:0] t_medido,      
    output reg         trigger_math,  
    output reg         timeout_error  
);

    reg gate_s1, gate_s2;
    reg ref_s1, ref_s2, ref_s3;
    reg sig_s1, sig_s2, sig_s3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            gate_s1 <= 0; gate_s2 <= 0;
            ref_s1 <= 0; ref_s2 <= 0; ref_s3 <= 0;
            sig_s1 <= 0; sig_s2 <= 0; sig_s3 <= 0;
        end else begin
            gate_s1 <= gate;   gate_s2 <= gate_s1;
            ref_s1  <= ref_clk; ref_s2 <= ref_s1; ref_s3 <= ref_s2;
            sig_s1  <= sig_in;  sig_s2 <= sig_s1; sig_s3 <= sig_s2;
        end
    end

    wire ref_rising_edge = ref_s2 & ~ref_s3;        
    wire sig_any_edge    = sig_s2 ^ sig_s3;         
    wire gate_active     = gate_s2;

    reg [16:0] contador; // 17 bits para evitar truncamiento en el watchdog
    reg        buscando_dato; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            contador      <= 0;
            t_medido      <= 0;
            trigger_math  <= 0;
            timeout_error <= 0;
            buscando_dato <= 0;
        end else begin
            trigger_math  <= 0;
            timeout_error <= 0;

            if (!gate_active) begin
                contador      <= 0;
                buscando_dato <= 0;
            end else begin
                if (ref_rising_edge) begin
                    contador      <= 0;
                    buscando_dato <= 1; 
                end 
                else if (sig_any_edge && buscando_dato) begin
                    t_medido      <= contador[15:0];
                    trigger_math  <= 1;
                    buscando_dato <= 0; 
                end 
                else if (buscando_dato) begin
                    contador <= contador + 17'd1;
                    
                    if (contador >= ({1'b0, reg_ideal} << 1)) begin
                        timeout_error <= 1;
                        buscando_dato <= 0;
                        contador      <= 0;
                    end
                end
            end
        end
    end
endmodule