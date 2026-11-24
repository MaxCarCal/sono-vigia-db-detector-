`timescale 1ns/1ps
//==============================================================================
// dc_block.v - Bloqueador de DC (pasa-altas de 1 polo, fc ~ 9.7 Hz)
//------------------------------------------------------------------------------
// Ecuacion:   y[n] = x[n] - x[n-1] + R * y[n-1]
//   El cero en z = 1 elimina la DC (polarizacion del microfono); el polo en
//   z = R, muy cerca de 1, hace que todo lo de audio pase sin cambio.
//
// R = 1 - 2^-9 - 2^-11 = 0.997559  ->  fc = (1-R)*fs/(2*pi) = 9.7 Hz
//   Multiplicar por R se hace SIN multiplicador:
//       R*y = y - (y >>> 9) - (y >>> 11)
//
// Precision: el estado se guarda con 10 bits fraccionarios extra (acc), para
// que los corrimientos no acumulen error ni generen un offset de DC.
//   acc = y * 2^10      (30 bits con signo)
//   salida = redondeo(acc / 2^10), saturada a 16 bits
//==============================================================================
module dc_block (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,
    input  wire signed [15:0] in_data,
    output reg                out_valid,
    output reg  signed [15:0] out_data
);

    localparam integer F = 10;                    // bits fraccionarios

    reg  signed [29:0] acc;                       // y[n-1] * 2^F
    reg  signed [15:0] x1;                        // x[n-1]

    wire signed [16:0] d      = {in_data[15], in_data} - {x1[15], x1};   // x - x1
    wire signed [29:0] d_sh   = {{3{d[16]}}, d, {F{1'b0}}};               // (x - x1) * 2^F
    wire signed [29:0] acc_n  = acc - (acc >>> 9) - (acc >>> 11) + d_sh;  // R*acc + (x-x1)*2^F
    wire signed [29:0] rnd    = (acc_n + 30'sd512) >>> F;                  // redondeo

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc       <= 30'sd0;
            x1        <= 16'sd0;
            out_valid <= 1'b0;
            out_data  <= 16'sd0;
        end else begin
            out_valid <= 1'b0;
            if (in_valid) begin
                acc       <= acc_n;
                x1        <= in_data;
                out_valid <= 1'b1;
                if (rnd > 30'sd32767)
                    out_data <= 16'sd32767;
                else if (rnd < -30'sd32768)
                    out_data <= -16'sd32768;
                else
                    out_data <= rnd[15:0];
            end
        end
    end

endmodule
