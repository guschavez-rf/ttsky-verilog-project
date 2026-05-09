// ===============================================================================
// MODULO: Mod_Matematico
// ===============================================================================
module Mod_Matematico (
    input  wire [14:0] t_medido,       // CORRECCIÓN: 15 bits
    input  wire [14:0] reg_ideal,      // CORRECCIÓN: 15 bits
    input  wire [14:0] reg_tol,        // CORRECCIÓN: 15 bits
    output wire [14:0] actual_jitter,  // CORRECCIÓN: 15 bits
    output wire        is_error
);

    assign actual_jitter = (t_medido >= reg_ideal) ? (t_medido - reg_ideal) : 
                                                     (reg_ideal - t_medido);

    assign is_error = (actual_jitter > reg_tol);

endmodule