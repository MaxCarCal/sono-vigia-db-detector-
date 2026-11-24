`timescale 1ns/1ps
//==============================================================================
// adc_if_tb.v - Cruce de dominio: el "ADC" corre a 10 MHz y el sistema a 50 MHz
// (relojes no alineados). Se envian 200 muestras (1 cada 10 ciclos de ADC =
// 1 MS/s); deben llegar TODAS, en orden y sin repetir. Las respuestas de otro
// canal se ignoran. Se verifica el detector de recorte (0 y 4095).
//==============================================================================
module adc_if_tb;
    reg adc_clk = 1'b0, clk = 1'b0, rst_n = 1'b0;
    reg resp_valid = 1'b0;
    reg [4:0]  resp_channel = 5'd1;
    reg [11:0] resp_data = 12'd0;
    wire cmd_valid, cmd_sop, cmd_eop;
    wire [4:0] cmd_channel;
    wire s_valid, clip;
    wire [11:0] s_data;
    integer i, nrx = 0, errors = 0, nclip = 0;
    reg [11:0] expected;

    adc_if #(.ADC_CH(5'd1)) dut (
        .adc_clk(adc_clk), .resp_valid(resp_valid), .resp_channel(resp_channel),
        .resp_data(resp_data), .cmd_valid(cmd_valid), .cmd_channel(cmd_channel),
        .cmd_sop(cmd_sop), .cmd_eop(cmd_eop), .cmd_ready(1'b1),
        .clk(clk), .rst_n(rst_n), .s_valid(s_valid), .s_data(s_data), .clip(clip));

    always #50   adc_clk = ~adc_clk;     // 10 MHz
    always #10.3 clk     = ~clk;         // ~48.5 MHz: fases que se deslizan

    // valor esperado de la muestra i (con 0 y 4095 para probar recorte)
    function [11:0] sample;
        input integer k;
        sample = (k == 50) ? 12'd0 : (k == 120) ? 12'd4095 : (k * 17 + 100);
    endfunction

    always @(posedge clk) begin
        if (s_valid) begin
            expected = sample(nrx);
            if (s_data !== expected) begin
                errors = errors + 1;
                if (errors < 10) $display("ERROR muestra %0d: %0d, esperado %0d", nrx, s_data, expected);
            end
            nrx = nrx + 1;
        end
        if (clip) nclip = nclip + 1;
    end

    initial begin
        #200 rst_n = 1'b1;
        #300;
        if (cmd_valid !== 1'b1 || cmd_channel !== 5'd1) begin
            errors = errors + 1; $display("ERROR: comando no valido");
        end
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge adc_clk);
            resp_valid <= 1'b1; resp_channel <= 5'd1; resp_data <= sample(i);
            @(posedge adc_clk);
            resp_valid <= 1'b0;
            if (i == 77) begin                   // respuesta de OTRO canal: ignorar
                @(posedge adc_clk);
                resp_valid <= 1'b1; resp_channel <= 5'd3; resp_data <= 12'd999;
                @(posedge adc_clk);
                resp_valid <= 1'b0;
                repeat (6) @(posedge adc_clk);
            end else
                repeat (8) @(posedge adc_clk);
        end
        #2000;
        if (nrx != 200)  begin errors = errors + 1; $display("ERROR: llegaron %0d muestras", nrx); end
        if (nclip != 2)  begin errors = errors + 1; $display("ERROR: %0d pulsos de clip (esperados 2)", nclip); end
        if (errors == 0) $display("adc_if_tb: PASS (200 muestras cruzaron de dominio)");
        else             $display("adc_if_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
