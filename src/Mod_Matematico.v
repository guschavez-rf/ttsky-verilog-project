module Mod_Matematico (
    input  wire [14:0] t_medido,
    input  wire [14:0] reg_ideal,
    input  wire [14:0] reg_tol,
    output wire [14:0] actual_jitter,
    output wire        is_error
);
    // Esta forma es la más eficiente para el PDK Sky130
    wire [14:0] diff1 = t_medido - reg_ideal;
    wire [14:0] diff2 = reg_ideal - t_medido;
    
    assign actual_jitter = (t_medido >= reg_ideal) ? diff1 : diff2;
    assign is_error = (actual_jitter > reg_tol);
endmodule