`timescale 1ns/1ps
//==============================================================================
// disp_ctrl.v - Control de los 6 displays de 7 segmentos (HEX5..HEX0)
//------------------------------------------------------------------------------
//   HEX5  : limite activo   d = dia (55)   n = noche (50)   E = evento (100)
//   HEX4  : estado alarma   - = monitor    P = pre-alerta   A = alerta (parpadea)
//                           C = cooldown
//   HEX3..HEX0 segun SW[5:4] (sel):
//     00  nivel      [o][ n][ n][ n]   'o' = sobrecarga del ADC en el ultimo s
//     01  Lmax       [H][ n][ n][ n]
//     10  reloj      [h][h.][m][m]     punto decimal de HEX2 como separador
//     11  raw (cal.) [r][ n][ n][ n]   10*log10(suma) sin calibrar
//   Ceros a la izquierda suprimidos ( 67 en vez de 067).
//
// Cada display recibe un "codigo de caracter" de 5 bits:
//   0x00..0x0F -> se dibuja con hex7seg (0-9, A, b, C, d, E, F)
//   0x10..     -> letras extra (blank, -, H, L, n, o, P, r, t, U)
// Salida de 8 bits por display: {DP, g, f, e, d, c, b, a}, ACTIVO EN BAJO.
//==============================================================================
module disp_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] sel,
    input  wire [7:0] level,
    input  wire [7:0] lmax,
    input  wire [7:0] raw,
    input  wire [4:0] hour,
    input  wire [5:0] minute,
    input  wire [1:0] lim_mode,      // 0 dia, 1 noche, 2 evento
    input  wire [1:0] alarm_state,   // 0 MON, 1 PRE, 2 ALERT, 3 COOL
    input  wire       overload,
    input  wire       blink,         // onda cuadrada lenta para parpadeo
    output reg  [7:0] hex0, hex1, hex2, hex3, hex4, hex5
);

    // ---- codigos de caracter
    localparam [4:0] C_BLANK = 5'h10, C_DASH = 5'h11, C_H = 5'h12, C_L = 5'h13,
                     C_N     = 5'h14, C_O    = 5'h15, C_P = 5'h16, C_R = 5'h17,
                     C_T     = 5'h18, C_U    = 5'h19,
                     C_A     = 5'h0A, C_C    = 5'h0C, C_D = 5'h0D, C_E = 5'h0E;

    // ---- valor numerico de 3 digitos segun el modo
    reg  [7:0] val3;
    always @* begin
        case (sel)
            2'b01:   val3 = lmax;
            2'b11:   val3 = raw;
            default: val3 = level;
        endcase
    end

    wire [3:0] v_h, v_t, v_o;           // centenas, decenas, unidades
    wire [3:0] hh_t, hh_o, mm_t, mm_o;
    wire [3:0] unused_h1, unused_h2;

    bin2bcd u_bcd_val (.bin(val3),            .hundreds(v_h),       .tens(v_t),  .ones(v_o));
    bin2bcd u_bcd_hh  (.bin({3'b000, hour}),  .hundreds(unused_h1), .tens(hh_t), .ones(hh_o));
    bin2bcd u_bcd_mm  (.bin({2'b00, minute}), .hundreds(unused_h2), .tens(mm_t), .ones(mm_o));

    // ---- seleccion de caracteres
    reg [4:0] c5, c4, c3, c2, c1, c0;
    reg       dp2;                       // punto decimal de HEX2 (1 = encendido)

    always @* begin
        // HEX5: limite
        case (lim_mode)
            2'd1:    c5 = C_N;
            2'd2:    c5 = C_E;
            default: c5 = C_D;
        endcase

        // HEX4: estado de alarma
        case (alarm_state)
            2'd1:    c4 = C_P;
            2'd2:    c4 = blink ? C_A : C_BLANK;   // ALERTA parpadea
            2'd3:    c4 = C_C;
            default: c4 = C_DASH;
        endcase

        dp2 = 1'b0;
        if (sel == 2'b10) begin
            // reloj HH.MM
            c3  = (hh_t == 4'd0) ? C_BLANK : {1'b0, hh_t};
            c2  = {1'b0, hh_o};
            c1  = {1'b0, mm_t};
            c0  = {1'b0, mm_o};
            dp2 = 1'b1;
        end else begin
            case (sel)
                2'b01:   c3 = C_H;
                2'b11:   c3 = C_R;
                default: c3 = overload ? C_O : C_BLANK;
            endcase
            c2 = (v_h == 4'd0)                  ? C_BLANK : {1'b0, v_h};
            c1 = (v_h == 4'd0 && v_t == 4'd0)   ? C_BLANK : {1'b0, v_t};
            c0 = {1'b0, v_o};
        end
    end

    // ---- letras que hex7seg no tiene (activo en bajo, gfedcba)
    function [6:0] letter_seg;
        input [4:0] c;
        begin
            case (c)
                C_DASH:  letter_seg = 7'b0111111;
                C_H:     letter_seg = 7'b0001001;
                C_L:     letter_seg = 7'b1000111;
                C_N:     letter_seg = 7'b0101011;
                C_O:     letter_seg = 7'b0100011;
                C_P:     letter_seg = 7'b0001100;
                C_R:     letter_seg = 7'b0101111;
                C_T:     letter_seg = 7'b0000111;
                C_U:     letter_seg = 7'b1000001;
                default: letter_seg = 7'b1111111;   // blank
            endcase
        end
    endfunction

    // ---- 6 decodificadores hex7seg (reutilizados) + letras extra
    wire [4:0] code [0:5];
    assign code[0] = c0; assign code[1] = c1; assign code[2] = c2;
    assign code[3] = c3; assign code[4] = c4; assign code[5] = c5;

    wire [6:0] seg [0:5];
    genvar gi;
    generate
        for (gi = 0; gi < 6; gi = gi + 1) begin : g_dig
            wire [6:0] hseg;
            hex7seg u_hex (.digit(code[gi][3:0]), .blank(1'b0), .seg(hseg));
            assign seg[gi] = code[gi][4] ? letter_seg(code[gi]) : hseg;
        end
    endgenerate

    // ---- salidas registradas (sin glitches); DP activo en bajo
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hex0 <= 8'hFF; hex1 <= 8'hFF; hex2 <= 8'hFF;
            hex3 <= 8'hFF; hex4 <= 8'hFF; hex5 <= 8'hFF;
        end else begin
            hex0 <= {1'b1, seg[0]};
            hex1 <= {1'b1, seg[1]};
            hex2 <= {~dp2, seg[2]};
            hex3 <= {1'b1, seg[3]};
            hex4 <= {1'b1, seg[4]};
            hex5 <= {1'b1, seg[5]};
        end
    end

endmodule
