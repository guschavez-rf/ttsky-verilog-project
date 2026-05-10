// ===============================================================================
// MODULO: Mod_Matematico (Optimizado a un solo restador)
// ===============================================================================
module Mod_Matematico (
    input  wire [14:0] t_medido,
    input  wire [14:0] reg_ideal,
    input  wire [14:0] reg_tol,
    output wire [14:0] actual_jitter,
    output wire        is_error
);

    // Hacemos una resta normal usando 16 bits para capturar el signo
    wire [15:0] resta = {1'b0, t_medido} - {1'b0, reg_ideal};
    
    // Si el bit 15 es 1 (resultado negativo), invertimos y sumamos 1 (Complemento a 2)
    assign actual_jitter = resta[15] ? (~resta[14:0] + 15'd1) : resta[14:0];

    // Comparación final
    assign is_error = (actual_jitter > reg_tol);

endmodule