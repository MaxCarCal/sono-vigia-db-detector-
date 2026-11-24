`timescale 1ns/1ps
//==============================================================================
// rst_sync.v - Sincronizador de reset (asercion asincrona, liberacion sincrona)
//------------------------------------------------------------------------------
// KEY0 entra como reset. Presionarlo pone el reset INMEDIATAMENTE (asincrono),
// pero al soltarlo el reset se libera alineado con clk (2 flip-flops). Asi
// ningun registro sale del reset en un instante distinto a los demas.
//
//   arst_n (KEY0) --+----------------+
//                   |                |
//          1'b1 -> [r1] -> [r2] -> rst_n   (r1, r2 con reset asincrono)
//
// rst_n : activo en bajo (lo usan nuestros modulos)
// rst   : activo en alto (lo usa el FFT de nanamake/r22sdf)
//==============================================================================
module rst_sync (
    input  wire clk,
    input  wire arst_n,     // reset asincrono, activo en bajo (KEY0)
    output wire rst_n,      // reset sincronizado, activo en bajo
    output wire rst         // mismo reset, activo en alto
);

    reg r1, r2;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            r1 <= 1'b0;
            r2 <= 1'b0;
        end else begin
            r1 <= 1'b1;
            r2 <= r1;
        end
    end

    assign rst_n = r2;
    assign rst   = ~r2;

endmodule
