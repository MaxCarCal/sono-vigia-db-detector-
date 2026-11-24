`timescale 1ns/1ps
//==============================================================================
// db_lut.v - Suma de cuadrados -> decibeles, SIN logaritmos ni raices
//            (busqueda binaria en una ROM de umbrales)
//------------------------------------------------------------------------------
// Archivo GENERADO por model/gen_db_lut.py (no editar la ROM a mano).
//
// Idea: raw = round(10*log10(x)). En vez de calcular el logaritmo, se guarda
// en una ROM el valor de x donde cambia cada dB:
//       thr[k] = ceil( 10^((k + 0.5) / 10) ),  k = 0..143
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
            8'd0  : thr_rom = 48'd2;
            8'd1  : thr_rom = 48'd2;
            8'd2  : thr_rom = 48'd2;
            8'd3  : thr_rom = 48'd3;
            8'd4  : thr_rom = 48'd3;
            8'd5  : thr_rom = 48'd4;
            8'd6  : thr_rom = 48'd5;
            8'd7  : thr_rom = 48'd6;
            8'd8  : thr_rom = 48'd8;
            8'd9  : thr_rom = 48'd9;
            8'd10 : thr_rom = 48'd12;
            8'd11 : thr_rom = 48'd15;
            8'd12 : thr_rom = 48'd18;
            8'd13 : thr_rom = 48'd23;
            8'd14 : thr_rom = 48'd29;
            8'd15 : thr_rom = 48'd36;
            8'd16 : thr_rom = 48'd45;
            8'd17 : thr_rom = 48'd57;
            8'd18 : thr_rom = 48'd71;
            8'd19 : thr_rom = 48'd90;
            8'd20 : thr_rom = 48'd113;
            8'd21 : thr_rom = 48'd142;
            8'd22 : thr_rom = 48'd178;
            8'd23 : thr_rom = 48'd224;
            8'd24 : thr_rom = 48'd282;
            8'd25 : thr_rom = 48'd355;
            8'd26 : thr_rom = 48'd447;
            8'd27 : thr_rom = 48'd563;
            8'd28 : thr_rom = 48'd708;
            8'd29 : thr_rom = 48'd892;
            8'd30 : thr_rom = 48'd1123;
            8'd31 : thr_rom = 48'd1413;
            8'd32 : thr_rom = 48'd1779;
            8'd33 : thr_rom = 48'd2239;
            8'd34 : thr_rom = 48'd2819;
            8'd35 : thr_rom = 48'd3549;
            8'd36 : thr_rom = 48'd4467;
            8'd37 : thr_rom = 48'd5624;
            8'd38 : thr_rom = 48'd7080;
            8'd39 : thr_rom = 48'd8913;
            8'd40 : thr_rom = 48'd11221;
            8'd41 : thr_rom = 48'd14126;
            8'd42 : thr_rom = 48'd17783;
            8'd43 : thr_rom = 48'd22388;
            8'd44 : thr_rom = 48'd28184;
            8'd45 : thr_rom = 48'd35482;
            8'd46 : thr_rom = 48'd44669;
            8'd47 : thr_rom = 48'd56235;
            8'd48 : thr_rom = 48'd70795;
            8'd49 : thr_rom = 48'd89126;
            8'd50 : thr_rom = 48'd112202;
            8'd51 : thr_rom = 48'd141254;
            8'd52 : thr_rom = 48'd177828;
            8'd53 : thr_rom = 48'd223873;
            8'd54 : thr_rom = 48'd281839;
            8'd55 : thr_rom = 48'd354814;
            8'd56 : thr_rom = 48'd446684;
            8'd57 : thr_rom = 48'd562342;
            8'd58 : thr_rom = 48'd707946;
            8'd59 : thr_rom = 48'd891251;
            8'd60 : thr_rom = 48'd1122019;
            8'd61 : thr_rom = 48'd1412538;
            8'd62 : thr_rom = 48'd1778280;
            8'd63 : thr_rom = 48'd2238722;
            8'd64 : thr_rom = 48'd2818383;
            8'd65 : thr_rom = 48'd3548134;
            8'd66 : thr_rom = 48'd4466836;
            8'd67 : thr_rom = 48'd5623414;
            8'd68 : thr_rom = 48'd7079458;
            8'd69 : thr_rom = 48'd8912510;
            8'd70 : thr_rom = 48'd11220185;
            8'd71 : thr_rom = 48'd14125376;
            8'd72 : thr_rom = 48'd17782795;
            8'd73 : thr_rom = 48'd22387212;
            8'd74 : thr_rom = 48'd28183830;
            8'd75 : thr_rom = 48'd35481339;
            8'd76 : thr_rom = 48'd44668360;
            8'd77 : thr_rom = 48'd56234133;
            8'd78 : thr_rom = 48'd70794579;
            8'd79 : thr_rom = 48'd89125094;
            8'd80 : thr_rom = 48'd112201846;
            8'd81 : thr_rom = 48'd141253755;
            8'd82 : thr_rom = 48'd177827942;
            8'd83 : thr_rom = 48'd223872114;
            8'd84 : thr_rom = 48'd281838294;
            8'd85 : thr_rom = 48'd354813390;
            8'd86 : thr_rom = 48'd446683593;
            8'd87 : thr_rom = 48'd562341326;
            8'd88 : thr_rom = 48'd707945785;
            8'd89 : thr_rom = 48'd891250939;
            8'd90 : thr_rom = 48'd1122018455;
            8'd91 : thr_rom = 48'd1412537545;
            8'd92 : thr_rom = 48'd1778279411;
            8'd93 : thr_rom = 48'd2238721139;
            8'd94 : thr_rom = 48'd2818382932;
            8'd95 : thr_rom = 48'd3548133893;
            8'd96 : thr_rom = 48'd4466835922;
            8'd97 : thr_rom = 48'd5623413252;
            8'd98 : thr_rom = 48'd7079457844;
            8'd99 : thr_rom = 48'd8912509382;
            8'd100: thr_rom = 48'd11220184544;
            8'd101: thr_rom = 48'd14125375447;
            8'd102: thr_rom = 48'd17782794101;
            8'd103: thr_rom = 48'd22387211386;
            8'd104: thr_rom = 48'd28183829313;
            8'd105: thr_rom = 48'd35481338924;
            8'd106: thr_rom = 48'd44668359216;
            8'd107: thr_rom = 48'd56234132520;
            8'd108: thr_rom = 48'd70794578439;
            8'd109: thr_rom = 48'd89125093814;
            8'd110: thr_rom = 48'd112201845431;
            8'd111: thr_rom = 48'd141253754463;
            8'd112: thr_rom = 48'd177827941004;
            8'd113: thr_rom = 48'd223872113857;
            8'd114: thr_rom = 48'd281838293127;
            8'd115: thr_rom = 48'd354813389234;
            8'd116: thr_rom = 48'd446683592151;
            8'd117: thr_rom = 48'd562341325191;
            8'd118: thr_rom = 48'd707945784385;
            8'd119: thr_rom = 48'd891250938134;
            8'd120: thr_rom = 48'd1122018454302;
            8'd121: thr_rom = 48'd1412537544623;
            8'd122: thr_rom = 48'd1778279410039;
            8'd123: thr_rom = 48'd2238721138569;
            8'd124: thr_rom = 48'd2818382931265;
            8'd125: thr_rom = 48'd3548133892336;
            8'd126: thr_rom = 48'd4466835921510;
            8'd127: thr_rom = 48'd5623413251904;
            8'd128: thr_rom = 48'd7079457843842;
            8'd129: thr_rom = 48'd8912509381338;
            8'd130: thr_rom = 48'd11220184543020;
            8'd131: thr_rom = 48'd14125375446228;
            8'd132: thr_rom = 48'd17782794100390;
            8'd133: thr_rom = 48'd22387211385684;
            8'd134: thr_rom = 48'd28183829312645;
            8'd135: thr_rom = 48'd35481338923358;
            8'd136: thr_rom = 48'd44668359215097;
            8'd137: thr_rom = 48'd56234132519035;
            8'd138: thr_rom = 48'd70794578438414;
            8'd139: thr_rom = 48'd89125093813375;
            8'd140: thr_rom = 48'd112201845430197;
            8'd141: thr_rom = 48'd141253754462276;
            8'd142: thr_rom = 48'd177827941003893;
            8'd143: thr_rom = 48'd223872113856834;
            default: thr_rom = 48'hFFFF_FFFF_FFFF;   // fuera de rango
            endcase
        end
    endfunction

    always @(posedge clk)
        thr_q <= thr_rom(addr);

    // ---- nivel calibrado (combinacional sobre idx final)
    wire signed [10:0] raw11  = {3'b000, idx};
    wire signed [10:0] trim11 = {{7{trim[3]}}, trim};
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
