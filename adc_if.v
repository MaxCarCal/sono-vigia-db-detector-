`timescale 1ns/1ps
//==============================================================================
// adc_if.v - Interfaz con el Modular ADC IP del MAX 10 (modo "control core only")
//------------------------------------------------------------------------------
// El IP del ADC se genera en Platform Designer (ver README). Su interfaz de
// salida es Avalon-ST "response" (valid, channel, data[11:0]) y trabaja en el
// reloj del sistema Qsys (adc_clk), que puede ser distinto de nuestros 50 MHz.
//
// Funciones:
//  1) Comando continuo: command_valid = 1 siempre con el canal ADC_CH, asi el
//     ADC convierte sin parar (1 MS/s con reloj de ADC de 10 MHz).
//  2) Cruce de dominio de reloj (CDC) con "toggle synchronizer":
//       dominio ADC : al llegar una muestra se guarda en hold_data y se
//                     invierte tog.
//       dominio 50M : tog pasa por 2 FF (tog_s1, tog_s2); un cambio entre
//                     tog_s2 y tog_s3 indica muestra nueva -> se copia
//                     hold_data (ya estable: la siguiente muestra llega 1 us
//                     despues, el cruce tarda ~60 ns).
//  3) Deteccion de recorte (clip): muestra cerca de 0 o de 4095 -> el
//     microfono/preamp saturan y la medicion no es valida.
//
// IMPORTANTE: el conector Arduino A0 (ADC_IN0) corresponde al canal 1 del
// ADC1 en el demo ADC_RTL de Terasic (canal 0 es la entrada dedicada).
// Verificalo con el demo antes de cambiar ADC_CH.
//==============================================================================
module adc_if #(
    parameter [4:0]  ADC_CH  = 5'd1,
    parameter [11:0] CLIP_HI = 12'd4080,
    parameter [11:0] CLIP_LO = 12'd15
)(
    // ---- dominio del ADC (reloj del sistema Platform Designer)
    input  wire        adc_clk,
    input  wire        resp_valid,
    input  wire [4:0]  resp_channel,
    input  wire [11:0] resp_data,
    output wire        cmd_valid,
    output wire [4:0]  cmd_channel,
    output wire        cmd_sop,
    output wire        cmd_eop,
    input  wire        cmd_ready,      // no se usa: el comando siempre es valido

    // ---- dominio del sistema (50 MHz)
    input  wire        clk,
    input  wire        rst_n,
    output reg         s_valid,        // pulso de 1 ciclo por muestra (1 MHz)
    output reg  [11:0] s_data,         // muestra de 12 bits, binario natural
    output reg         clip            // pulso: la muestra esta saturada
);

    assign cmd_valid   = 1'b1;
    assign cmd_channel = ADC_CH;
    assign cmd_sop     = 1'b1;
    assign cmd_eop     = 1'b1;

    // ---------------- dominio del ADC
    // Valores iniciales: MAX 10 los soporta en el encendido y evitan 'x' en
    // simulacion (este dominio no tiene reset).
    reg [11:0] hold_data = 12'd2048;
    reg        tog       = 1'b0;

    always @(posedge adc_clk) begin
        if (resp_valid && (resp_channel == ADC_CH)) begin
            hold_data <= resp_data;
            tog       <= ~tog;
        end
    end

    // ---------------- dominio de 50 MHz
    reg tog_s1, tog_s2, tog_s3;
    wire new_sample = tog_s2 ^ tog_s3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tog_s1  <= 1'b0;
            tog_s2  <= 1'b0;
            tog_s3  <= 1'b0;
            s_valid <= 1'b0;
            s_data  <= 12'd2048;
            clip    <= 1'b0;
        end else begin
            tog_s1  <= tog;          // primer FF: puede quedar metaestable
            tog_s2  <= tog_s1;       // segundo FF: valor ya estable
            tog_s3  <= tog_s2;       // valor anterior, para detectar cambio
            s_valid <= new_sample;
            clip    <= 1'b0;
            if (new_sample) begin
                s_data <= hold_data;
                clip   <= (hold_data >= CLIP_HI) || (hold_data <= CLIP_LO);
            end
        end
    end

endmodule
