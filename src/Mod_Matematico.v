module Mod_Matematico (
    input  wire [15:0] t_medido,
    input  wire [15:0] reg_ideal,
    input  wire [15:0] reg_tol,
    output wire [15:0] actual_jitter,
    output wire        is_error
);

    // 1. Cálculo de Valor Absoluto: |t_medido - reg_ideal|
    // Si t_medido es mayor, se resta ideal; si es menor, se resta de ideal.
    assign actual_jitter = (t_medido >= reg_ideal) ? (t_medido - reg_ideal) : 
                                                     (reg_ideal - t_medido);

    // 2. Comparación de Ventana de Tolerancia
    // Es 1 (Verdadero) si el jitter supera el margen configurado
    assign is_error = (actual_jitter > reg_tol);

endmodule