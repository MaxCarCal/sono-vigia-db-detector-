`timescale 1ns/1ps
//==============================================================================
// led_bar_tb.v - Testbench autoverificable de led_bar
// Barre level = 0..255 con los parametros por defecto (MIN=45, STEP=6) y
// comprueba: (1) el valor exacto esperado, (2) que sea codigo termometro
// (si LEDR[i] esta encendido, todos los de abajo tambien).
//==============================================================================
module led_bar_tb;

    reg  [7:0] level;
    wire [9:0] leds;

    integer i, k;
    integer errors = 0;
    reg [9:0] expected;

    led_bar #(.MIN_DB(45), .STEP_DB(6)) dut (.level(level), .leds(leds));

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            level = i[7:0];
            #10;

            // modelo de referencia: un LED por cada umbral alcanzado
            expected = 10'd0;
            for (k = 0; k < 10; k = k + 1)
                if (i >= 45 + 6 * k) expected[k] = 1'b1;

            if (leds !== expected) begin
                errors = errors + 1;
                $display("ERROR level=%0d: leds=%b esperado=%b", i, leds, expected);
            end

            // propiedad termometro: leds+1 debe ser potencia de 2 (000..0111..1)
            if (((leds + 10'd1) & leds) !== 10'd0) begin
                errors = errors + 1;
                $display("ERROR level=%0d: no es codigo termometro (%b)", i, leds);
            end
        end

        // casos puntuales de referencia
        level = 8'd44;  #10; if (leds !== 10'b00_0000_0000) begin errors = errors + 1; $display("ERROR 44 dB"); end
        level = 8'd45;  #10; if (leds !== 10'b00_0000_0001) begin errors = errors + 1; $display("ERROR 45 dB"); end
        level = 8'd75;  #10; if (leds !== 10'b00_0011_1111) begin errors = errors + 1; $display("ERROR 75 dB"); end
        level = 8'd99;  #10; if (leds !== 10'b11_1111_1111) begin errors = errors + 1; $display("ERROR 99 dB"); end

        if (errors == 0) $display("led_bar_tb: PASS");
        else             $display("led_bar_tb: FAIL (%0d errores)", errors);
        $finish;
    end

endmodule
