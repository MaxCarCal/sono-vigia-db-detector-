`timescale 1ns/1ps
//==============================================================================
// cic_dec.v - Decimador CIC de 3 etapas, R = 40 (1 MS/s -> 25 kS/s)
//------------------------------------------------------------------------------
// Un CIC es un filtro pasa-bajas SIN multiplicadores: solo sumas y restas.
//
//   x -> [I1] -> [I2] -> [I3] -> (toma 1 de cada 40) -> [C1] -> [C2] -> [C3] -> y
//
//   Integrador : i[n] = i[n-1] + x[n]           (corre a 1 MS/s)
//   Comb       : c[m] = d[m] - d[m-1]           (corre a 25 kS/s)
//
// Respuesta: H(z) = [ (1 - z^-R) / (1 - z^-1) ]^3  -> promedio movil de 40,
// aplicado 3 veces. Ganancia en DC = R^3 = 64,000 (~2^16).
//
// Ancho interno: 12 + 3*log2(40) = 27.97 -> W = 28 bits. Los integradores
// DESBORDAN a proposito: con aritmetica modular (complemento a 2) el resultado
// del comb es correcto siempre que W alcance para la salida final (teorema de
// Hogenauer).
//
// Salida: bits [27:12] (16 bits). Escala: y = x * 64000/4096 = x * 15.625.
// Un tono a escala completa del ADC (+-2048) da +-32000 a la salida.
//
// Caida (droop) del CIC: -1.7 dB a 5 kHz, -7.3 dB a 10 kHz. Se compensa en
// el biquad de a_weight_iir.
//==============================================================================
module cic_dec #(
    parameter integer R     = 40,
    parameter integer W     = 28,
    parameter integer SHIFT = 12      // = W - 16
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,   // 1 MS/s (desde adc_if)
    input  wire [11:0]        in_data,    // binario natural 0..4095
    output reg                out_valid,  // 25 kS/s
    output reg  signed [15:0] out_data
);

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam integer CW = clog2(R);

    // binario desplazado -> con signo: 0..4095 -> -2048..2047
    wire signed [12:0]  x13 = $signed({1'b0, in_data}) - 13'sd2048;
    wire signed [W-1:0] x   = {{(W-13){x13[12]}}, x13};

    reg  signed [W-1:0] i1, i2, i3;      // integradores
    reg  signed [W-1:0] c1, c2, c3;      // retardos de los combs
    reg  [CW-1:0]       cnt;             // contador de decimacion
    reg                 dec_go;

    wire signed [W-1:0] d1 = i3 - c1;
    wire signed [W-1:0] d2 = d1 - c2;
    wire signed [W-1:0] d3 = d2 - c3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i1 <= 0; i2 <= 0; i3 <= 0;
            c1 <= 0; c2 <= 0; c3 <= 0;
            cnt <= 0; dec_go <= 1'b0;
            out_valid <= 1'b0;
            out_data  <= 16'sd0;
        end else begin
            dec_go    <= 1'b0;
            out_valid <= 1'b0;

            // ---- integradores (cada etapa usa el valor ANTERIOR de la previa;
            //      eso solo agrega retardo, no cambia la respuesta)
            if (in_valid) begin
                i1 <= i1 + x;
                i2 <= i2 + i1;
                i3 <= i3 + i2;
                if (cnt == R - 1) begin
                    cnt    <= 0;
                    dec_go <= 1'b1;          // toca producir una salida
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end

            // ---- combs (1 de cada 40 muestras)
            if (dec_go) begin
                c1 <= i3;
                c2 <= d1;
                c3 <= d2;
                out_data  <= d3[SHIFT+15:SHIFT];
                out_valid <= 1'b1;
            end
        end
    end

endmodule
