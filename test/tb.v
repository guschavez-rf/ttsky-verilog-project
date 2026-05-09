`default_nettype none
`timescale 1ns/1ps

/* Este archivo es el envoltorio para la simulación */
module tb (
    /* Los pines coinciden con el estándar de Tiny Tapeout */
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // power enable
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n
);

    /* Instancia de tu medidor de Jitter */
    tt_um_Medidor_Jitter user_project (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

endmodule