`timescale 1ns/1ps
//==============================================================================
// led_bar.v - Nivel en dB -> barra de 10 LEDR (codigo termometro)
//------------------------------------------------------------------------------
// LEDR[i] se enciende cuando level >= MIN_DB + i*STEP_DB. Con los valores por
// defecto (MIN_DB = 45, STEP_DB = 6) los umbrales son:
//
//   LEDR0  1  2  3  4  5  6  7  8  9
//    45   51 57 63 69 75 81 87 93 99   dB
//
// Cubre el rango objetivo del proyecto (45..100 dB(A)).
//
// Accesibilidad: el nivel se lee por la POSICION del ultimo LED encendido, no
// por el color (importante para personas daltonicas).
// Logica puramente combinacional: 10 comparadores contra constantes.
//==============================================================================
module led_bar #(
    parameter integer MIN_DB  = 45,   // umbral del primer LED
    parameter integer STEP_DB = 6     // dB entre LEDs consecutivos
)(
    input  wire [7:0] level,          // nivel en dB (entero)
    output wire [9:0] leds            // -> LEDR[9:0]  (1 = encendido)
);

    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : g_led
            assign leds[i] = (level >= (MIN_DB + i * STEP_DB));
        end
    endgenerate

endmodule
