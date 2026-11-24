//==============================================================================
// adc_model.v - MODELO DE SIMULACION del Modular ADC (NO sintetizable)
//------------------------------------------------------------------------------
// Sustituye al IP de Intel en Active-HDL. Entrega por la misma interfaz
// Avalon-ST "response" que el IP real una muestra de 12 bits cada
// CLKS_PER_SAMPLE ciclos (50 MHz / 50 = 1 MS/s):
//
//     muestra = OFFSET + amp * sin(2*pi*freq*t)    (redondeada y limitada 0..4095)
//
// freq y amp son variables "real": el testbench puede cambiarlas en cualquier
// momento, p. ej.   dut.u_adc_model.amp = 50.0;
// Requiere funciones matematicas de Verilog-2005 ($sin).
//==============================================================================
`timescale 1ns/1ps
module adc_model #(
    parameter [4:0] ADC_CH          = 5'd1,
    parameter       FREQ_HZ         = 1000.0,
    parameter       AMP             = 200.0,
    parameter       OFFSET          = 2048.0,
    parameter integer CLKS_PER_SAMPLE = 50,
    parameter       FS_HZ           = 1.0e6
)(
    input  wire        clk,
    output reg         resp_valid,
    output reg  [4:0]  resp_channel,
    output reg  [11:0] resp_data
);

    real    freq, amp, v;
    integer div, n;

    initial begin
        freq = FREQ_HZ;
        amp  = AMP;
        div  = 0;
        n    = 0;
        resp_valid   = 1'b0;
        resp_channel = ADC_CH;
        resp_data    = 12'd2048;
    end

    always @(posedge clk) begin
        resp_valid <= 1'b0;
        if (div == CLKS_PER_SAMPLE - 1) begin
            div = 0;
            v = OFFSET + amp * $sin(2.0 * 3.14159265358979 * freq * n / FS_HZ);
            if (v < 0.0)    v = 0.0;
            if (v > 4095.0) v = 4095.0;
            resp_data    <= $rtoi(v + 0.5);
            resp_channel <= ADC_CH;
            resp_valid   <= 1'b1;
            n = n + 1;
        end else begin
            div = div + 1;
        end
    end

endmodule
