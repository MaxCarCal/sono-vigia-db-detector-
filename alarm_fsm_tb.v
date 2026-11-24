`timescale 1ns/1ps
//==============================================================================
// alarm_fsm_tb.v - Escenarios de la maquina de alarma (limite 55, sosten 3 s
// = 24 ticks, cooldown 10 s = 80 ticks).
//==============================================================================
module alarm_fsm_tb;
    reg clk = 1'b0, rst_n = 1'b0, tick = 1'b0;
    reg [7:0] level = 8'd40, limit = 8'd55;
    wire [1:0] state;
    wire alert, pre, alert_start;
    integer errors = 0, nstart = 0;

    localparam MON = 2'd0, PRE = 2'd1, ALR = 2'd2, COOL = 2'd3;

    alarm_fsm dut (.clk(clk), .rst_n(rst_n), .tick(tick), .level(level), .limit(limit),
                   .hold_s(6'd3), .state(state), .alert(alert), .pre(pre),
                   .alert_start(alert_start));
    always #10 clk = ~clk;
    always @(posedge clk) if (alert_start) nstart = nstart + 1;

    task ticks;                                   // n niveles con valor lv
        input [7:0] lv;
        input integer n;
        integer k;
        begin
            level = lv;
            for (k = 0; k < n; k = k + 1) begin
                @(posedge clk) tick <= 1'b1;
                @(posedge clk) tick <= 1'b0;
                @(posedge clk);
            end
        end
    endtask

    task expect_state;
        input [1:0] s;
        input [255:0] label;
        begin
            #1;
            if (state !== s) begin
                errors = errors + 1;
                $display("ERROR (%0s): estado %0d, esperado %0d", label, state, s);
            end
        end
    endtask

    initial begin
        #35 rst_n = 1'b1;
        ticks(40, 5);  expect_state(MON,  "silencio");
        ticks(53, 1);  expect_state(PRE,  "a 2 dB del limite");
        ticks(60, 20); expect_state(PRE,  "20 ticks sobre el limite");
        ticks(54, 1);  expect_state(PRE,  "baja 1 tick: reinicia sosten");
        ticks(60, 23); expect_state(PRE,  "23 ticks: aun no alcanza 3 s");
        ticks(60, 1);  expect_state(ALR,  "24 ticks = 3 s: ALERTA");
        if (alert !== 1'b1 || nstart != 1) begin errors = errors + 1; $display("ERROR: salida alert / alert_start"); end
        ticks(50, 1);  expect_state(COOL, "baja del limite");
        ticks(70, 1);  expect_state(ALR,  "regresa el ruido: ALERTA sin sosten");
        if (nstart != 1) begin errors = errors + 1; $display("ERROR: no debe contar nueva alerta"); end
        ticks(40, 1);  expect_state(COOL, "baja otra vez: COOLDOWN");
        ticks(40, 79); expect_state(COOL, "79 ticks en cooldown");
        ticks(40, 1);  expect_state(MON,  "80 ticks = 10 s: MONITOR");
        ticks(60, 1);  expect_state(PRE,  "salto directo a 60: primero PRE");

        if (errors == 0) $display("alarm_fsm_tb: PASS");
        else             $display("alarm_fsm_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
