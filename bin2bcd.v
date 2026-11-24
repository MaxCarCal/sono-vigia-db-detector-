`timescale 1ns/1ps
//==============================================================================
// bin2bcd.v - Binario (0..255) -> 3 digitos BCD, algoritmo "double dabble"
//------------------------------------------------------------------------------
// Sirve para mostrar el nivel en dB (ej. 67 -> tens=6, ones=7) en los HEX.
// Evita division y modulo (que gastarian muchos recursos).
//
// Algoritmo (8 iteraciones, una por bit de entrada):
//   1) Se coloca el binario a la derecha de 3 digitos BCD (inicialmente 0).
//   2) Antes de cada desplazamiento: si un digito BCD es >= 5, se le suma 3.
//   3) Se desplaza todo 1 bit a la izquierda.
// Por que funciona: al duplicar un digito >= 5 se pasaria de 9; sumar 3 antes
// (que equivale a sumar 6 despues de duplicar) corrige el salto 9 -> 10 de BCD.
//
// Ejemplo con bin = 13 (00001101):
//   inicio  BCD=000 000 000 | 00001101
//   ...tras 8 desplazamientos con correcciones -> BCD = 0 1 3
//
// Es combinacional. Para 8 bits es pequeno (unas decenas de LEs) y el valor de
// dB cambia solo 1 vez por segundo, asi que no hay problema de tiempo.
//==============================================================================
module bin2bcd (
    input  wire [7:0] bin,
    output reg  [3:0] hundreds,
    output reg  [3:0] tens,
    output reg  [3:0] ones
);

    integer i;
    reg [19:0] shift;   // {centenas[19:16], decenas[15:12], unidades[11:8], bin[7:0]}

    always @* begin
        shift        = 20'd0;
        shift[7:0]   = bin;

        for (i = 0; i < 8; i = i + 1) begin
            if (shift[11:8]  >= 4'd5) shift[11:8]  = shift[11:8]  + 4'd3;
            if (shift[15:12] >= 4'd5) shift[15:12] = shift[15:12] + 4'd3;
            if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
            shift = shift << 1;
        end

        ones     = shift[11:8];
        tens     = shift[15:12];
        hundreds = shift[19:16];
    end

endmodule
