module Mod_Matematico (
    input  wire [14:0] t_medido,
    input  wire [14:0] reg_ideal,
    input  wire [14:0] reg_tol,
    output wire [14:0] actual_jitter,
    output wire        is_error
);
    // Esta forma genera un restador y un mux, mucho más liviano que el complemento a 2 manual
    assign actual_jitter = (t_medido >= reg_ideal) ? (t_medido - reg_ideal) : (reg_ideal - t_medido);
    assign is_error = (actual_jitter > reg_tol);
endmodule