`timescale 1ns/1ps
//==============================================================================
// buzzer_ctrl.v - Senal para buzzer durante ALERTA
//------------------------------------------------------------------------------
// Patron: medio segundo sonando / medio segundo en silencio.
//   PASSIVE = 1 : buzzer pasivo (piezo) -> tono cuadrado de TONE_HZ
//   PASSIVE = 0 : buzzer activo         -> nivel alto constante
//
// silence (KEY1) calla la alerta ACTUAL; la siguiente alerta vuelve a sonar.
// enable (SW3) habilita/deshabilita el buzzer.
//
// Hardware: el pin GPIO da 3.3 V y pocos mA. Usa un transistor (p. ej.
// 2N2222 + resistencia de 1 k en la base) para manejar el buzzer.
// OJO: coloca el buzzer LEJOS del microfono; si no, el propio pitido sube
// el nivel medido y mantiene la alerta.
//==============================================================================
module buzzer_ctrl #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer TONE_HZ = 2000,
    parameter integer PASSIVE = 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire alert,
    input  wire enable,
    input  wire silence,
    output reg  buzz
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

    localparam integer TONE_DIV = CLK_HZ / (2 * TONE_HZ);   // medio periodo
    localparam integer BEEP_DIV = CLK_HZ / 2;               // 0.5 s
    localparam integer TW = clog2(TONE_DIV);
    localparam integer BW = clog2(BEEP_DIV);

    reg [TW-1:0] tcnt;
    reg [BW-1:0] bcnt;
    reg          tone, beep_on, muted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tcnt <= 0; bcnt <= 0;
            tone <= 1'b0; beep_on <= 1'b1; muted <= 1'b0;
            buzz <= 1'b0;
        end else begin
            // tono
            if (tcnt == TONE_DIV - 1) begin
                tcnt <= 0;
                tone <= ~tone;
            end else
                tcnt <= tcnt + 1'b1;

            // patron 0.5 s on / 0.5 s off (arranca en "on" al iniciar la alerta)
            if (!alert) begin
                bcnt    <= 0;
                beep_on <= 1'b1;
            end else if (bcnt == BEEP_DIV - 1) begin
                bcnt    <= 0;
                beep_on <= ~beep_on;
            end else
                bcnt <= bcnt + 1'b1;

            // silencio de la alerta actual
            if (!alert)
                muted <= 1'b0;
            else if (silence)
                muted <= 1'b1;

            buzz <= enable && alert && !muted && beep_on &&
                    ((PASSIVE != 0) ? tone : 1'b1);
        end
    end

endmodule
