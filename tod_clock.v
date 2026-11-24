`timescale 1ns/1ps
//==============================================================================
// tod_clock.v - Reloj de hora del dia + seleccion del limite NOM-081
//------------------------------------------------------------------------------
// Reloj HH:MM:SS que avanza con tick_1hz. Se ajusta con KEY1:
//   inc_hour : suma 1 hora   (23 -> 0)
//   inc_min  : suma 1 minuto (59 -> 0, sin acarreo) y pone segundos en 0
// Al reset arranca en INIT_HOUR:00:00 (no hay bateria: hay que ajustarlo).
//
// Limite segun NOM-081 (zona residencial) y SW[1:0]:
//   00  automatico : 55 dB(A) de 06:00 a 22:00, 50 dB(A) de 22:00 a 06:00
//   01  forzar dia   (55)
//   10  forzar noche (50)
//   11  modo evento  (100 dB(A) durante 4 h = 14,400 s; al vencer regresa
//                     al modo automatico y levanta event_expired)
//   Salir del modo evento reinicia su temporizador.
//
// lim_mode (para el display): 0 = dia, 1 = noche, 2 = evento
//==============================================================================
module tod_clock #(
    parameter integer INIT_HOUR   = 12,
    parameter integer LIM_DAY     = 55,
    parameter integer LIM_NIGHT   = 50,
    parameter integer LIM_EVENT   = 100,
    parameter integer NIGHT_START = 22,
    parameter integer NIGHT_END   = 6,
    parameter integer EVENT_S     = 14400
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       inc_hour,
    input  wire       inc_min,
    input  wire [1:0] mode_sw,
    output reg  [4:0] hour,
    output reg  [5:0] minute,
    output reg  [5:0] second,
    output wire       is_night,
    output reg  [7:0] limit_db,
    output reg  [1:0] lim_mode,
    output reg        event_expired
);

    reg [13:0] ev_cnt;              // 0..16383 (alcanza para 14,400 s)

    assign is_night = (hour >= NIGHT_START) || (hour < NIGHT_END);

    // ---- reloj HH:MM:SS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hour   <= INIT_HOUR;
            minute <= 6'd0;
            second <= 6'd0;
        end else if (inc_hour) begin
            hour <= (hour == 5'd23) ? 5'd0 : hour + 5'd1;
        end else if (inc_min) begin
            minute <= (minute == 6'd59) ? 6'd0 : minute + 6'd1;
            second <= 6'd0;
        end else if (tick_1hz) begin
            if (second == 6'd59) begin
                second <= 6'd0;
                if (minute == 6'd59) begin
                    minute <= 6'd0;
                    hour   <= (hour == 5'd23) ? 5'd0 : hour + 5'd1;
                end else begin
                    minute <= minute + 6'd1;
                end
            end else begin
                second <= second + 6'd1;
            end
        end
    end

    // ---- temporizador del modo evento (4 h)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ev_cnt        <= 14'd0;
            event_expired <= 1'b0;
        end else if (mode_sw != 2'b11) begin
            ev_cnt        <= 14'd0;
            event_expired <= 1'b0;
        end else if (tick_1hz && !event_expired) begin
            if (ev_cnt == EVENT_S - 1)
                event_expired <= 1'b1;
            ev_cnt <= ev_cnt + 14'd1;
        end
    end

    // ---- seleccion de limite (registrada)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            limit_db <= LIM_DAY;
            lim_mode <= 2'd0;
        end else begin
            case (mode_sw)
                2'b01: begin limit_db <= LIM_DAY;   lim_mode <= 2'd0; end
                2'b10: begin limit_db <= LIM_NIGHT; lim_mode <= 2'd1; end
                2'b11: begin
                    if (!event_expired) begin
                        limit_db <= LIM_EVENT; lim_mode <= 2'd2;
                    end else if (is_night) begin
                        limit_db <= LIM_NIGHT; lim_mode <= 2'd1;
                    end else begin
                        limit_db <= LIM_DAY;   lim_mode <= 2'd0;
                    end
                end
                default: begin                      // 00: automatico
                    if (is_night) begin
                        limit_db <= LIM_NIGHT; lim_mode <= 2'd1;
                    end else begin
                        limit_db <= LIM_DAY;   lim_mode <= 2'd0;
                    end
                end
            endcase
        end
    end

endmodule
