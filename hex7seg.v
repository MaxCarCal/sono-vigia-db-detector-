`timescale 1ns/1ps
//==============================================================================
// hex7seg.v - Decodificador 4 bits -> display de 7 segmentos (ACTIVO EN BAJO)
//------------------------------------------------------------------------------
// Los displays de la DE10-Lite son anodo comun: un '0' en el pin ENCIENDE el
// segmento y un '1' lo apaga (manual, seccion 3.4).
//
//        a            seg[0] = a   (HEX_0 en el manual)
//      ----           seg[1] = b
//   f |    | b        seg[2] = c
//      -g--           seg[3] = d
//   e |    | c        seg[4] = e
//      ----           seg[5] = f
//        d            seg[6] = g
//                     (el punto decimal DP es HEX_7: dejarlo en 1 = apagado)
//
// blank = 1 apaga todo el digito (sirve para suprimir ceros a la izquierda).
// Es logica puramente combinacional (una tabla de verdad).
//==============================================================================
module hex7seg (
    input  wire [3:0] digit,   // valor 0..F
    input  wire       blank,   // 1 = digito apagado
    output reg  [6:0] seg      // {g,f,e,d,c,b,a}, activo en bajo
);

    always @* begin
        if (blank) begin
            seg = 7'b111_1111;
        end else begin
            case (digit)
                //                  gfedcba
                4'h0: seg = 7'b100_0000;
                4'h1: seg = 7'b111_1001;
                4'h2: seg = 7'b010_0100;
                4'h3: seg = 7'b011_0000;
                4'h4: seg = 7'b001_1001;
                4'h5: seg = 7'b001_0010;
                4'h6: seg = 7'b000_0010;
                4'h7: seg = 7'b111_1000;
                4'h8: seg = 7'b000_0000;
                4'h9: seg = 7'b001_0000;
                4'hA: seg = 7'b000_1000;
                4'hB: seg = 7'b000_0011;   // "b" minuscula
                4'hC: seg = 7'b100_0110;
                4'hD: seg = 7'b010_0001;   // "d" minuscula
                4'hE: seg = 7'b000_0110;
                4'hF: seg = 7'b000_1110;
                default: seg = 7'b111_1111;
            endcase
        end
    end

endmodule
