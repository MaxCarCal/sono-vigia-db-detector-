`timescale 1ns/1ps
//==============================================================================
// buzzer_ctrl_tb.v - Patron del buzzer con relojes escalados:
//   CLK_HZ = 1000, TONE_HZ = 100 -> tono de 10 ciclos; patron de 500/500 ciclos.
// Cuenta flancos de subida de buzz en ventanas de 500 ciclos.
//==============================================================================
module buzzer_ctrl_tb;
    reg clk = 1'b0, rst_n = 1'b0, alert = 1'b0, enable = 1'b1, silence = 1'b0;
    wire buzz;
    reg  buzz_d = 1'b0;
    integer edges = 0, errors = 0;

    buzzer_ctrl #(.CLK_HZ(1000), .TONE_HZ(100), .PASSIVE(1)) dut (
        .clk(clk), .rst_n(rst_n), .alert(alert), .enable(enable), .silence(silence), .buzz(buzz));
    always #10 clk = ~clk;
    always @(posedge clk) begin
        if (buzz && !buzz_d) edges = edges + 1;
        buzz_d <= buzz;
    end

    task window;                       // cuenta flancos en 500 ciclos
        input integer min_e, max_e;
        input [255:0] label;
        begin
            edges = 0;
            repeat (500) @(posedge clk);
            if (edges < min_e || edges > max_e) begin
                errors = errors + 1;
                $display("ERROR (%0s): %0d flancos, esperado %0d..%0d", label, edges, min_e, max_e);
            end
        end
    endtask

    initial begin
        #35 rst_n = 1'b1;
        window(0, 0, "sin alerta");
        alert = 1'b1;
        window(40, 51, "alerta: medio segundo sonando");
        window(0, 1,   "alerta: medio segundo en silencio");
        window(40, 51, "alerta: suena otra vez");
        @(posedge clk) silence <= 1'b1;
        @(posedge clk) silence <= 1'b0;
        window(0, 1, "silenciada (1)");
        window(0, 0, "silenciada (2)");
        alert = 1'b0;
        window(0, 0, "fin de alerta");
        alert = 1'b1;
        window(40, 51, "nueva alerta suena");
        enable = 1'b0;
        window(0, 1, "buzzer deshabilitado");

        if (errors == 0) $display("buzzer_ctrl_tb: PASS");
        else             $display("buzzer_ctrl_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
