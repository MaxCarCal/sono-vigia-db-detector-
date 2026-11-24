`timescale 1ns/1ps
//==============================================================================
// ms_avg.v - Valor cuadratico medio por bloques (Fast 125 ms / Slow 1 s)
//------------------------------------------------------------------------------
// 1) Cuadrado:      sq = y^2              (18x18 -> 36 bits, siempre >= 0)
// 2) Bloque Fast:   suma de BLK = 3125 cuadrados = 125 ms a 25 kS/s
// 3) Slow (1 s):    suma movil de los ultimos 8 bloques, dividida entre 8
//                   (>> 3, exacto) para que quede en la MISMA escala que Fast.
//                   Se mantiene con una suma corrida:
//                     slow_acc = slow_acc + bloque_nuevo - bloque_de_hace_8
//
// No se divide entre 3125: db_lut trabaja directamente con la SUMA y la
// constante 10*log10(3125) = 34.95 dB se absorbe en la calibracion.
//
// Salidas (cada 125 ms, pulso blk_valid):
//   fast_sum : suma del ultimo bloque de 125 ms
//   slow_sum : (suma de los ultimos 8 bloques) / 8
//   sec_flag : 1 si este bloque completa un segundo (cada 8 bloques). En ese
//              instante slow_sum es exactamente el LAeq de 1 s (para el log).
//
// Ancho: |y| <= 2^17 -> y^2 <= 2^34; 3125 cuadrados < 2^46 -> SUMW = 48 bits.
//==============================================================================
module ms_avg #(
    parameter integer BLK  = 3125,
    parameter integer SUMW = 48
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,
    input  wire signed [17:0] in_data,
    output reg                blk_valid,
    output reg                sec_flag,
    output reg  [SUMW-1:0]    fast_sum,
    output reg  [SUMW-1:0]    slow_sum
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

    localparam integer NW = (BLK > 1) ? clog2(BLK) : 1;

    wire signed [35:0] sq   = in_data * in_data;             // segundo multiplicador
    wire [SUMW-1:0]    sq_u = {{(SUMW-36){1'b0}}, sq};       // sq >= 0

    reg  [SUMW-1:0] acc, blk;
    reg  [NW-1:0]   n;
    reg  [SUMW+2:0] slow_acc;
    reg  [SUMW-1:0] ring [0:7];
    reg  [2:0]      ptr;
    reg             go1, go2;
    integer         i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 0; blk <= 0; n <= 0;
            slow_acc <= 0; ptr <= 3'd0;
            go1 <= 1'b0; go2 <= 1'b0;
            blk_valid <= 1'b0; sec_flag <= 1'b0;
            fast_sum <= 0; slow_sum <= 0;
            for (i = 0; i < 8; i = i + 1)
                ring[i] <= 0;
        end else begin
            go1       <= 1'b0;
            go2       <= 1'b0;
            blk_valid <= 1'b0;

            // ---- 1) acumula cuadrados
            if (in_valid) begin
                if (n == BLK - 1) begin
                    blk <= acc + sq_u;         // bloque completo
                    acc <= 0;
                    n   <= 0;
                    go1 <= 1'b1;
                end else begin
                    acc <= acc + sq_u;
                    n   <= n + 1'b1;
                end
            end

            // ---- 2) suma movil de 8 bloques
            if (go1) begin
                slow_acc  <= slow_acc + blk - ring[ptr];
                ring[ptr] <= blk;
                ptr       <= ptr + 3'd1;
                go2       <= 1'b1;
            end

            // ---- 3) publica resultados
            if (go2) begin
                fast_sum  <= blk;
                slow_sum  <= slow_acc[SUMW+2:3];   // /8
                sec_flag  <= (ptr == 3'd0);        // se completaron 8 bloques
                blk_valid <= 1'b1;
            end
        end
    end

endmodule
