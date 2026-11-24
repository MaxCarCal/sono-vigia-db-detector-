`timescale 1ns/1ps
//==============================================================================
// disp_ctrl_tb.v - Verifica los codigos de los 6 displays en cada modo.
// Codigos esperados (activo en bajo, {DP,g..a}) calculados con Python a partir
// de las tablas de hex7seg y disp_ctrl.
//==============================================================================
module disp_ctrl_tb;
    reg clk = 1'b0, rst_n = 1'b0;
    reg [1:0] sel = 2'b00;
    reg [7:0] level = 8'd67, lmax = 8'd105, raw = 8'd128;
    reg [4:0] hour = 5'd9;
    reg [5:0] minute = 6'd5;
    reg [1:0] lim_mode = 2'd1, alarm_state = 2'd0;
    reg overload = 1'b0, blink = 1'b1;
    wire [7:0] h0, h1, h2, h3, h4, h5;
    integer errors = 0;

    disp_ctrl dut (.clk(clk), .rst_n(rst_n), .sel(sel), .level(level), .lmax(lmax), .raw(raw),
                   .hour(hour), .minute(minute), .lim_mode(lim_mode), .alarm_state(alarm_state),
                   .overload(overload), .blink(blink),
                   .hex0(h0), .hex1(h1), .hex2(h2), .hex3(h3), .hex4(h4), .hex5(h5));
    always #10 clk = ~clk;

    task expect6;
        input [7:0] e5, e4, e3, e2, e1, e0;
        input [255:0] label;
        begin
            repeat (2) @(posedge clk);
            #1;
            if ({h5,h4,h3,h2,h1,h0} !== {e5,e4,e3,e2,e1,e0}) begin
                errors = errors + 1;
                $display("ERROR (%0s): %h %h %h %h %h %h  esperado %h %h %h %h %h %h",
                         label, h5,h4,h3,h2,h1,h0, e5,e4,e3,e2,e1,e0);
            end
        end
    endtask

    initial begin
        #35 rst_n = 1'b1;
        // nivel 67, noche, monitor:  n - _ _ 6 7
        expect6(8'hAB, 8'hBF, 8'hFF, 8'hFF, 8'h82, 8'hF8, "nivel 67");
        // sobrecarga -> 'o' en HEX3
        overload = 1'b1;
        expect6(8'hAB, 8'hBF, 8'hA3, 8'hFF, 8'h82, 8'hF8, "sobrecarga");
        overload = 1'b0;
        // nivel 5 -> solo unidades
        level = 8'd5;
        expect6(8'hAB, 8'hBF, 8'hFF, 8'hFF, 8'hFF, 8'h92, "nivel 5");
        // Lmax 105, dia, pre-alerta:  d P H 1 0 5
        sel = 2'b01; lim_mode = 2'd0; alarm_state = 2'd1;
        expect6(8'hA1, 8'h8C, 8'h89, 8'hF9, 8'hC0, 8'h92, "Lmax 105");
        // raw 128, evento, alerta (blink = 1 -> 'A'):  E A r 1 2 8
        sel = 2'b11; lim_mode = 2'd2; alarm_state = 2'd2;
        expect6(8'h86, 8'h88, 8'hAF, 8'hF9, 8'hA4, 8'h80, "raw 128");
        // alerta con blink = 0 -> HEX4 apagado
        blink = 1'b0;
        expect6(8'h86, 8'hFF, 8'hAF, 8'hF9, 8'hA4, 8'h80, "blink");
        // reloj 09:05, cooldown:  E C _ 9. 0 5
        sel = 2'b10; alarm_state = 2'd3; blink = 1'b1;
        expect6(8'h86, 8'hC6, 8'hFF, 8'h10, 8'hC0, 8'h92, "reloj 9.05");

        if (errors == 0) $display("disp_ctrl_tb: PASS");
        else             $display("disp_ctrl_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
