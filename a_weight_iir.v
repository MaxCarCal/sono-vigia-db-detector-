`timescale 1ns/1ps
//==============================================================================
// a_weight_iir.v - Filtro de ponderacion A (orden 6) con UN multiplicador
//------------------------------------------------------------------------------
// La curva A (IEC 61672) tiene 4 ceros en DC y 6 polos. Se implementa como:
//
//   x -> [HP 20.6 Hz] -> [HP 20.6 Hz] -> [HP 107.7 Hz] -> [HP 737.9 Hz] -> [biquad HF] -> y
//
//   HP de 1er orden : y[n] = (x[n] - x[n-1]) + p * y[n-1]      (1 multiplicacion)
//   Biquad HF (DF-I): y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2]
//                            - a1*y[n-1] - a2*y[n-2]           (5 multiplicaciones)
//     El biquad modela el polo doble de 12.2 kHz Y compensa la caida del CIC.
//     Sus coeficientes salen de un ajuste por minimos cuadrados
//     (model/design_aweight.py). Error total vs curva A: < 0.02 dB de
//     20 Hz a 10 kHz.
//
// Por que 4 secciones de 1er orden + 1 biquad en vez de 3 biquads:
//   - mismo orden (6), pero 9 multiplicaciones por muestra en vez de 15;
//   - el error de cuantizar p es lineal (en un biquad con polo doble crece
//     como raiz cuadrada);
//   - cada seccion HP tiene la misma forma que dc_block (facil de explicar).
//
// MULTIPLICADOR COMPARTIDO (time-sharing):
//   Entre muestras hay 2,000 ciclos de reloj (50 MHz / 25 kHz). Una maquina
//   de estados usa un solo multiplicador 18x18 en 9 pasos (15 ciclos en
//   total). Los multiplexores mul_c / mul_d eligen el coeficiente y el dato
//   de cada paso.
//
//   IDLE -> HP_MAC -> HP_WB  (x4 secciones, k = 0..3)
//        -> BQ_MAC (x5 terminos, k = 0..4) -> BQ_WB -> IDLE
//
// Formatos (punto fijo):
//   datos        : 18 bits con signo. Entrada de 16 bits * 2 (1 bit de guarda)
//   coeficientes : Q2.16 (18 bits con signo, rango [-2, 2))
//   acumulador   : 40 bits
//   resultado    : redondeo (+2^15, >>> 16) y saturacion a 18 bits
// Ganancia de la cadena ADC->aqui = 1 (0 dB) a 1 kHz.
//==============================================================================
module a_weight_iir (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,   // 25 kS/s (desde dc_block)
    input  wire signed [15:0] in_data,
    output reg                out_valid,
    output reg  signed [17:0] out_data
);

    localparam integer FRAC = 16;

    // ---- coeficientes Q2.16 (generados por model/design_aweight.py)
    localparam signed [17:0] P0  =  18'sd65198;   // polo 20.6 Hz   p = 0.994836
    localparam signed [17:0] P1  =  18'sd65198;   // polo 20.6 Hz
    localparam signed [17:0] P2  =  18'sd63786;   // polo 107.7 Hz  p = 0.973303
    localparam signed [17:0] P3  =  18'sd54385;   // polo 737.9 Hz  p = 0.829844
    localparam signed [17:0] B0  =  18'sd85886;   // biquad HF:  b0 =  1.310535
    localparam signed [17:0] B1  = -18'sd30466;   //             b1 = -0.464874
    localparam signed [17:0] B2  = -18'sd13511;   //             b2 = -0.206161
    localparam signed [17:0] NA1 =  18'sd9575;    //            -a1 =  0.146103
    localparam signed [17:0] NA2 =  18'sd18931;   //            -a2 =  0.288864

    localparam [2:0] S_IDLE   = 3'd0,
                     S_HP_MAC = 3'd1,
                     S_HP_WB  = 3'd2,
                     S_BQ_MAC = 3'd3,
                     S_BQ_WB  = 3'd4;

    reg [2:0] state;
    reg [2:0] k;                                   // seccion (0..3) o termino (0..4)

    reg signed [17:0] v;                           // entrada de la seccion actual
    reg signed [17:0] xp0, xp1, xp2, xp3;          // x[n-1] de cada HP
    reg signed [17:0] yp0, yp1, yp2, yp3;          // y[n-1] de cada HP
    reg signed [17:0] bx1, bx2, by1, by2;          // memoria del biquad
    reg signed [39:0] acc;

    // ---- multiplexores de operandos
    reg signed [17:0] mul_c, mul_d, xpk;
    always @* begin
        case (k)
            3'd0:    xpk = xp0;
            3'd1:    xpk = xp1;
            3'd2:    xpk = xp2;
            default: xpk = xp3;
        endcase

        if (state == S_HP_MAC) begin
            case (k)
                3'd0:    begin mul_c = P0; mul_d = yp0; end
                3'd1:    begin mul_c = P1; mul_d = yp1; end
                3'd2:    begin mul_c = P2; mul_d = yp2; end
                default: begin mul_c = P3; mul_d = yp3; end
            endcase
        end else begin
            case (k)
                3'd0:    begin mul_c = B0;  mul_d = v;   end
                3'd1:    begin mul_c = B1;  mul_d = bx1; end
                3'd2:    begin mul_c = B2;  mul_d = bx2; end
                3'd3:    begin mul_c = NA1; mul_d = by1; end
                default: begin mul_c = NA2; mul_d = by2; end
            endcase
        end
    end

    // ---- EL UNICO MULTIPLICADOR (18x18 -> 36 bits)
    wire signed [35:0] prod    = mul_c * mul_d;
    wire signed [39:0] prod_x  = {{4{prod[35]}}, prod};

    // ---- (x - x[n-1]) * 2^16 para las secciones HP
    wire signed [18:0] diff    = {v[17], v} - {xpk[17], xpk};
    wire signed [39:0] diff_sh = {{5{diff[18]}}, diff, 16'd0};

    // ---- redondeo + saturacion del acumulador a 18 bits
    function signed [17:0] satround;
        input signed [39:0] a;
        reg   signed [39:0] r;
        begin
            r = (a + 40'sd32768) >>> FRAC;
            if (r > 40'sd131071)
                satround = 18'sd131071;
            else if (r < -40'sd131072)
                satround = -18'sd131072;
            else
                satround = r[17:0];
        end
    endfunction

    wire signed [17:0] acc_q = satround(acc);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; k <= 3'd0;
            v   <= 18'sd0; acc <= 40'sd0;
            xp0 <= 18'sd0; xp1 <= 18'sd0; xp2 <= 18'sd0; xp3 <= 18'sd0;
            yp0 <= 18'sd0; yp1 <= 18'sd0; yp2 <= 18'sd0; yp3 <= 18'sd0;
            bx1 <= 18'sd0; bx2 <= 18'sd0; by1 <= 18'sd0; by2 <= 18'sd0;
            out_valid <= 1'b0;
            out_data  <= 18'sd0;
        end else begin
            out_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (in_valid) begin
                        v     <= {in_data, 1'b0};          // x2 -> 18 bits
                        k     <= 3'd0;
                        state <= S_HP_MAC;
                    end
                end

                // acc = (v - x[n-1])*2^16 + p_k * y[n-1]
                S_HP_MAC: begin
                    acc   <= diff_sh + prod_x;
                    state <= S_HP_WB;
                end

                // y = redondeo(acc); actualiza memoria; la salida es la
                // entrada de la siguiente seccion
                S_HP_WB: begin
                    case (k)
                        3'd0:    begin xp0 <= v; yp0 <= acc_q; end
                        3'd1:    begin xp1 <= v; yp1 <= acc_q; end
                        3'd2:    begin xp2 <= v; yp2 <= acc_q; end
                        default: begin xp3 <= v; yp3 <= acc_q; end
                    endcase
                    v <= acc_q;
                    if (k == 3'd3) begin
                        k     <= 3'd0;
                        state <= S_BQ_MAC;
                    end else begin
                        k     <= k + 3'd1;
                        state <= S_HP_MAC;
                    end
                end

                // acc = sum de 5 productos (k = 0 reinicia el acumulador)
                S_BQ_MAC: begin
                    acc <= ((k == 3'd0) ? 40'sd0 : acc) + prod_x;
                    if (k == 3'd4)
                        state <= S_BQ_WB;
                    else
                        k <= k + 3'd1;
                end

                S_BQ_WB: begin
                    bx2       <= bx1;
                    bx1       <= v;
                    by2       <= by1;
                    by1       <= acc_q;
                    out_data  <= acc_q;
                    out_valid <= 1'b1;
                    k         <= 3'd0;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
