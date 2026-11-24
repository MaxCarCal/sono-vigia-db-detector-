`timescale 1ns/1ps
//==============================================================================
// io_sync.v - Sincronizador de entradas asincronas + detector de flancos
//------------------------------------------------------------------------------
// Las entradas SW[9:0] y KEY[1:0] no estan sincronizadas con clk. Si una
// entrada cambia justo en el flanco del reloj, el primer flip-flop puede caer
// en metaestabilidad. Solucion estandar: cadena de 2 FF (ff1 -> ff2); ff1 puede
// quedar metaestable, pero tiene un ciclo completo para resolverse antes de
// que ff2 lo muestree. ff3 guarda el valor anterior para detectar flancos.
//
//   async_in -> [ff1] -> [ff2] -> [ff3]
//                         |         |
//                     sync_out   (previo)
//   rise = ff2 & ~ff3   fall = ~ff2 & ff3     (pulsos de 1 ciclo)
//
// WIDTH : numero de bits (1 para un KEY, 10 para todos los SW)
// INIT  : valor de reposo. Los KEY valen '1' sueltos, asi que para ellos usar
//         INIT = 1'b1 evita un flanco falso justo despues del reset.
//
// Nota: los KEY de la DE10-Lite ya traen antirrebote por hardware (Schmitt
//       trigger), por eso aqui NO se hace antirrebote.
//==============================================================================
module io_sync #(
    parameter integer         WIDTH = 1,
    parameter [WIDTH-1:0]     INIT  = {WIDTH{1'b0}}
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,   // directo del pin
    output wire [WIDTH-1:0] sync_out,   // nivel sincronizado (2 ciclos de retardo)
    output wire [WIDTH-1:0] rise,       // pulso en flanco de subida
    output wire [WIDTH-1:0] fall        // pulso en flanco de bajada
);

    reg [WIDTH-1:0] ff1, ff2, ff3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ff1 <= INIT;
            ff2 <= INIT;
            ff3 <= INIT;
        end else begin
            ff1 <= async_in;
            ff2 <= ff1;
            ff3 <= ff2;
        end
    end

    assign sync_out = ff2;
    assign rise     =  ff2 & ~ff3;
    assign fall     = ~ff2 &  ff3;

endmodule
