`timescale 1ns/1ps
//==============================================================================
// tick_gen_tb.v - Testbench autoverificable de tick_gen
// Usa CLK_HZ=1000 y TICK_HZ=100 (DIV=10) para simular rapido.
// Verifica: (1) el pulso dura 1 ciclo, (2) el periodo es exactamente DIV ciclos,
//           (3) la salida es 0 durante el reset.
//==============================================================================
module tick_gen_tb;

    localparam integer DIV = 10;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    wire tick;

    integer cycle = 0;
    integer last_tick_cycle = -1;
    integer n_ticks = 0;
    integer errors = 0;

    tick_gen #(.CLK_HZ(1000), .TICK_HZ(100)) dut (
        .clk(clk), .rst_n(rst_n), .tick(tick)
    );

    always #10 clk = ~clk;                 // 50 MHz (periodo 20 ns)

    always @(posedge clk) cycle <= cycle + 1;

    // Monitor: mide la distancia entre flancos de subida de tick
    always @(posedge tick) begin
        if (last_tick_cycle >= 0 && (cycle - last_tick_cycle) != DIV) begin
            errors = errors + 1;
            $display("ERROR: periodo = %0d ciclos (esperado %0d) en t=%0t",
                     cycle - last_tick_cycle, DIV, $time);
        end
        last_tick_cycle = cycle;
        n_ticks = n_ticks + 1;
    end

    // Monitor: el pulso debe durar un solo ciclo
    reg tick_d = 1'b0;
    always @(posedge clk) begin
        if (tick && tick_d) begin
            errors = errors + 1;
            $display("ERROR: tick dura mas de 1 ciclo en t=%0t", $time);
        end
        tick_d <= tick;
    end

    initial begin
        #25;
        if (tick !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR: tick no es 0 durante el reset");
        end
        #40 rst_n = 1'b1;                  // libera reset
        #(20 * DIV * 10);                  // ~10 periodos de tick

        if (n_ticks < 9) begin
            errors = errors + 1;
            $display("ERROR: solo %0d ticks (esperados ~10)", n_ticks);
        end

        if (errors == 0) $display("tick_gen_tb: PASS (%0d ticks)", n_ticks);
        else             $display("tick_gen_tb: FAIL (%0d errores)", errors);
        $finish;
    end

endmodule
