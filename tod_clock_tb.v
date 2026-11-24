`timescale 1ns/1ps
//==============================================================================
// tod_clock_tb.v - Reloj y seleccion de limite.
// tick_1hz se genera cada 4 ciclos (acelerado). EVENT_S = 20 para probar el
// vencimiento del modo evento sin esperar 4 h.
//==============================================================================
module tod_clock_tb;
    reg clk = 1'b0, rst_n = 1'b0, tick = 1'b0, inc_hour = 1'b0, inc_min = 1'b0;
    reg [1:0] mode_sw = 2'b00;
    wire [4:0] hour;
    wire [5:0] minute, second;
    wire is_night, event_expired;
    wire [7:0] limit_db;
    wire [1:0] lim_mode;
    integer errors = 0, i;

    tod_clock #(.EVENT_S(20)) dut (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick), .inc_hour(inc_hour), .inc_min(inc_min),
        .mode_sw(mode_sw), .hour(hour), .minute(minute), .second(second), .is_night(is_night),
        .limit_db(limit_db), .lim_mode(lim_mode), .event_expired(event_expired));
    always #10 clk = ~clk;

    task ticks;                              // n segundos
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                @(posedge clk) tick <= 1'b1;
                @(posedge clk) tick <= 1'b0;
                repeat (2) @(posedge clk);
            end
        end
    endtask

    task pulse_hour;
        begin @(posedge clk) inc_hour <= 1'b1; @(posedge clk) inc_hour <= 1'b0; end
    endtask

    task check;
        input [4:0] eh; input [5:0] em, es; input [7:0] elim; input [1:0] emode;
        input [255:0] label;
        begin
            repeat (2) @(posedge clk); #1;
            if (hour !== eh || minute !== em || second !== es || limit_db !== elim || lim_mode !== emode) begin
                errors = errors + 1;
                $display("ERROR (%0s): %0d:%0d:%0d lim=%0d modo=%0d | esperado %0d:%0d:%0d lim=%0d modo=%0d",
                         label, hour, minute, second, limit_db, lim_mode, eh, em, es, elim, emode);
            end
        end
    endtask

    initial begin
        #35 rst_n = 1'b1;
        check(12, 0, 0, 55, 0, "reset 12:00:00 dia");
        ticks(3661);                                       // +1 h 1 min 1 s
        check(13, 1, 1, 55, 0, "13:01:01");
        @(posedge clk) inc_min <= 1'b1; @(posedge clk) inc_min <= 1'b0;
        check(13, 2, 0, 55, 0, "inc_min pone segundos en 0");
        for (i = 0; i < 9; i = i + 1) pulse_hour;          // 22:02
        check(22, 2, 0, 50, 1, "22:02 noche");
        mode_sw = 2'b01;
        check(22, 2, 0, 55, 0, "forzar dia");
        mode_sw = 2'b11;
        check(22, 2, 0, 100, 2, "evento");
        ticks(19);
        check(22, 2, 19, 100, 2, "evento 19 s");
        ticks(1);
        check(22, 2, 20, 50, 1, "evento vencido -> noche automatica");
        if (event_expired !== 1'b1) begin errors = errors + 1; $display("ERROR: event_expired"); end
        mode_sw = 2'b00;
        for (i = 0; i < 8; i = i + 1) pulse_hour;          // 22 -> 6
        check(6, 2, 20, 55, 0, "06:02 dia (hora paso por 0)");
        mode_sw = 2'b10;
        check(6, 2, 20, 50, 1, "forzar noche");

        if (errors == 0) $display("tod_clock_tb: PASS");
        else             $display("tod_clock_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
