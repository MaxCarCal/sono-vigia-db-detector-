"""gen_db_lut.py - genera rtl/db_lut.v con la ROM de umbrales (10^((k+0.5)/10))."""
from chain_model import THR, SUMW

rom_lines = []
for k, v in enumerate(THR):
    if v >= (1 << SUMW) - 1:
        continue
    rom_lines.append(f"            8'd{k:<3d}: thr_rom = 48'd{v};")
rom = "\n".join(rom_lines)
last_used = max(k for k, v in enumerate(THR) if v < (1 << SUMW) - 1)

v = f"""`timescale 1ns/1ps
//==============================================================================
// db_lut.v - Suma de cuadrados -> decibeles, SIN logaritmos ni raices
//            (busqueda binaria en una ROM de umbrales)
//------------------------------------------------------------------------------
// Archivo GENERADO por model/gen_db_lut.py (no editar la ROM a mano).
//
// Idea: raw = round(10*log10(x)). En vez de calcular el logaritmo, se guarda
// en una ROM el valor de x donde cambia cada dB:
//       thr[k] = ceil( 10^((k + 0.5) / 10) ),  k = 0..{last_used}
// y raw = cuantos umbrales son <= x. Como la tabla esta ordenada, eso se
// encuentra con BUSQUEDA BINARIA en 8 pasos (igual que adivinar un numero
// del 0 al 255 preguntando "mayor o menor").
//
//   para bit = 7 .. 0:
//       prueba = idx | (1 << bit)
//       si thr[prueba - 1] <= x  ->  idx = prueba
//
// Cada paso usa 2 ciclos (lectura de ROM registrada + comparacion), en total
// ~18 ciclos por conversion: despreciable (llega 1 dato cada 125 ms).
//
// Nivel calibrado:  level = raw + CAL_DB + trim   (limitado a 0..199)
//   CAL_DB absorbe la sensibilidad del microfono, la ganancia del preamp,
//   la ganancia del CIC y el termino 10*log10(3125) del promedio.
//   Valor por defecto -18: un tono de 1 kHz a escala completa del ADC
//   (raw = 128) se muestra como 110 dB. Se ajusta en la calibracion.
//   trim: ajuste fino con SW[9:7] (-4..+3 dB).
//==============================================================================
module db_lut #(
    parameter integer CAL_DB = -18
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              start,      // pulso: convertir x
    input  wire [47:0]       x,          // suma de cuadrados (escala de 3125 muestras)
    input  wire signed [3:0] trim,       // ajuste fino en dB
    output reg               done,       // pulso: raw y level listos
    output reg  [7:0]        raw,        // 10*log10(x) redondeado
    output reg  [7:0]        level       // nivel calibrado en dB
);

    localparam [1:0] S_IDLE = 2'd0, S_READ = 2'd1, S_CMP = 2'd2, S_DONE = 2'd3;
    localparam signed [10:0] CAL11 = CAL_DB;

    reg  [1:0]  state;
    reg  [7:0]  idx;
    reg  [2:0]  b;
    reg  [47:0] xr;
    reg  [47:0] thr_q;

    wire [7:0]  bitmask = 8'd1 << b;
    wire [7:0]  tryv    = idx | bitmask;
    wire [7:0]  addr    = tryv - 8'd1;

    // ---- ROM de umbrales (lectura registrada: Quartus puede usar M9K)
    function [47:0] thr_rom;
        input [7:0] a;
        begin
            case (a)
{rom}
            default: thr_rom = 48'hFFFF_FFFF_FFFF;   // fuera de rango
            endcase
        end
    endfunction

    always @(posedge clk)
        thr_q <= thr_rom(addr);

    // ---- nivel calibrado (combinacional sobre idx final)
    wire signed [10:0] raw11  = {{3'b000, idx}};
    wire signed [10:0] trim11 = {{{{7{{trim[3]}}}}, trim}};
    wire signed [10:0] lv     = raw11 + CAL11 + trim11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            idx   <= 8'd0;
            b     <= 3'd7;
            xr    <= 48'd0;
            done  <= 1'b0;
            raw   <= 8'd0;
            level <= 8'd0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        xr    <= x;
                        idx   <= 8'd0;
                        b     <= 3'd7;
                        state <= S_READ;
                    end
                end
                S_READ: state <= S_CMP;          // espera la ROM (thr_q)
                S_CMP: begin
                    if (thr_q <= xr)
                        idx <= tryv;
                    if (b == 3'd0)
                        state <= S_DONE;
                    else begin
                        b     <= b - 3'd1;
                        state <= S_READ;
                    end
                end
                S_DONE: begin
                    raw <= idx;
                    if (lv < 11'sd0)
                        level <= 8'd0;
                    else if (lv > 11'sd199)
                        level <= 8'd199;
                    else
                        level <= lv[7:0];
                    done  <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
"""
open('../rtl/db_lut.v', 'w').write(v)
print("db_lut.v generado; entradas de ROM:", len(rom_lines), "ultima k =", last_used)
