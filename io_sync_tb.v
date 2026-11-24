`timescale 1ns/1ps
//==============================================================================
// io_sync_tb.v - Testbench autoverificable de io_sync
// Reloj: flancos de subida en t = 10, 30, 50, 70, ... ns (periodo 20 ns).
// La entrada asincrona cambia FUERA de los flancos (t=35 y t=105).
//
// Prueba 1 (dut_a, INIT=0): la salida se retrasa 2 ciclos y rise/fall son
//           pulsos de 1 ciclo.
// Prueba 2 (dut_b, INIT=1): con entrada en '1' (KEY suelto) no debe haber
//           flancos falsos tras el reset.
//==============================================================================
module io_sync_tb;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    reg  in_a = 1'b0;
    reg  in_b = 1'b1;          // KEY sin presionar
    wire sync_a, rise_a, fall_a;
    wire sync_b, rise_b, fall_b;

    integer errors = 0;

    io_sync #(.WIDTH(1), .INIT(1'b0)) dut_a (
        .clk(clk), .rst_n(rst_n), .async_in(in_a),
        .sync_out(sync_a), .rise(rise_a), .fall(fall_a)
    );

    io_sync #(.WIDTH(1), .INIT(1'b1)) dut_b (
        .clk(clk), .rst_n(rst_n), .async_in(in_b),
        .sync_out(sync_b), .rise(rise_b), .fall(fall_b)
    );

    always #10 clk = ~clk;

    task check;
        input exp_sync;
        input exp_rise;
        input exp_fall;
        input [255:0] label;
        begin
            if (sync_a !== exp_sync || rise_a !== exp_rise || fall_a !== exp_fall) begin
                errors = errors + 1;
                $display("ERROR (%0s) t=%0t: sync=%b rise=%b fall=%b, esperado %b %b %b",
                         label, $time, sync_a, rise_a, fall_a,
                         exp_sync, exp_rise, exp_fall);
            end
        end
    endtask

    // dut_b nunca debe generar flancos (su entrada no cambia)
    always @(posedge clk) begin
        if (rst_n && (rise_b || fall_b || sync_b !== 1'b1)) begin
            errors = errors + 1;
            $display("ERROR: flanco falso en dut_b, t=%0t", $time);
        end
    end

    initial begin
        #15 rst_n = 1'b1;           // libera reset (entre flancos)
        #20 in_a  = 1'b1;           // t=35: sube la entrada asincrona
        #34;                        // t=69: antes del 2do flanco (70)
        check(1'b0, 1'b0, 1'b0, "t69 aun sin cambio");
        #2;                         // t=71: ff2 ya vale 1
        check(1'b1, 1'b1, 1'b0, "t71 rise");
        #20;                        // t=91: el pulso ya termino
        check(1'b1, 1'b0, 1'b0, "t91 nivel alto");

        #14 in_a = 1'b0;            // t=105: baja la entrada
        #44;                        // t=149
        check(1'b1, 1'b0, 1'b0, "t149 aun alto");
        #2;                         // t=151
        check(1'b0, 1'b0, 1'b1, "t151 fall");
        #20;                        // t=171
        check(1'b0, 1'b0, 1'b0, "t171 nivel bajo");

        #50;
        if (errors == 0) $display("io_sync_tb: PASS");
        else             $display("io_sync_tb: FAIL (%0d errores)", errors);
        $finish;
    end

endmodule
