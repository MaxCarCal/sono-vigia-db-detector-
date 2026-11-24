`timescale 1ns/1ps
//==============================================================================
// alarm_fsm.v - Maquina de estados de alarma (Moore) con tiempo de sosten
//------------------------------------------------------------------------------
// Se evalua en cada "tick" = cada nivel nuevo (cada 125 ms, 8 por segundo).
//
//                 nivel >= limite-3
//   MONITOR ---------------------------> PRE-ALERTA
//      ^  <---------------------------    |   nivel >= limite durante
//      |       nivel < limite-3           |   hold_s segundos seguidos
//      |                                  v
//   COOLDOWN <------------------------- ALERTA
//      |        nivel < limite            ^
//      |                                  |
//      +----- nivel >= limite ------------+
//      +----- COOL_S s por debajo -> MONITOR
//
//  - PRE-ALERTA: el nivel esta a 3 dB o menos del limite (aviso temprano).
//    Si baja del limite el contador de sosten se reinicia: solo cuenta un
//    rebase CONTINUO (evita alarmas por un portazo o un claxon).
//  - ALERTA: limite rebasado por hold_s segundos (por defecto 3 s).
//    Latencia = hold_s + 125 ms (un bloque).
//  - COOLDOWN: espera COOL_S segundos por debajo del limite antes de volver
//    a MONITOR; si el ruido regresa, vuelve a ALERTA sin esperar el sosten.
//
// Moore: las salidas dependen SOLO del estado (alert, pre), lo que las hace
// estables para LEDs y buzzer. alert_start es un pulso registrado al entrar
// a ALERTA (para contar episodios).
//==============================================================================
module alarm_fsm #(
    parameter integer TICKS_PER_S = 8,
    parameter integer PRE_MARGIN  = 3,
    parameter integer COOL_S      = 10
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,          // nivel nuevo disponible
    input  wire [7:0] level,         // dB(A)
    input  wire [7:0] limit,         // dB(A)
    input  wire [5:0] hold_s,        // 1..60 s
    output reg  [1:0] state,
    output wire       alert,
    output wire       pre,
    output reg        alert_start
);

    localparam [1:0] S_MON  = 2'd0,
                     S_PRE  = 2'd1,
                     S_ALR  = 2'd2,
                     S_COOL = 2'd3;

    localparam [9:0] COOL_TICKS = COOL_S * TICKS_PER_S;

    reg  [9:0] cnt;
    wire [9:0] hold_ticks = hold_s * TICKS_PER_S;
    wire       above      = (level >= limit);
    wire       near       = ({1'b0, level} + PRE_MARGIN >= {1'b0, limit});

    assign alert = (state == S_ALR);
    assign pre   = (state == S_PRE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_MON;
            cnt         <= 10'd0;
            alert_start <= 1'b0;
        end else begin
            alert_start <= 1'b0;
            if (tick) begin
                case (state)
                    S_MON: begin
                        if (near) begin
                            state <= S_PRE;
                            cnt   <= 10'd0;
                        end
                    end
                    S_PRE: begin
                        if (above) begin
                            if (cnt + 10'd1 >= hold_ticks) begin
                                state       <= S_ALR;
                                cnt         <= 10'd0;
                                alert_start <= 1'b1;
                            end else begin
                                cnt <= cnt + 10'd1;
                            end
                        end else begin
                            cnt <= 10'd0;              // rebase no continuo
                            if (!near)
                                state <= S_MON;
                        end
                    end
                    S_ALR: begin
                        if (!above) begin
                            state <= S_COOL;
                            cnt   <= 10'd0;
                        end
                    end
                    S_COOL: begin
                        if (above) begin
                            state <= S_ALR;
                        end else if (cnt + 10'd1 >= COOL_TICKS) begin
                            state <= S_MON;
                            cnt   <= 10'd0;
                        end else begin
                            cnt <= cnt + 10'd1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
