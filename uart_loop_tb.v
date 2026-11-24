`timescale 1ns/1ps
//==============================================================================
// uart_loop_tb.v - uart_tx conectado a uart_rx (lazo). CLKS_PER_BIT = 16 para
// simular rapido. Verifica 6 bytes, la duracion de la trama (10 bits) y que la
// linea quede en 1 en reposo.
//==============================================================================
module uart_loop_tb;
    reg clk = 1'b0, rst_n = 1'b0, start = 1'b0;
    reg [7:0] data = 8'd0;
    wire tx, busy, valid;
    wire [7:0] rx_byte;
    reg [7:0] bytes [0:5];
    integer i, nrx = 0, errors = 0, t0, t1;

    uart_tx #(.CLKS_PER_BIT(16)) u_tx (.clk(clk), .rst_n(rst_n), .start(start), .data(data),
                                      .tx(tx), .busy(busy));
    uart_rx #(.CLKS_PER_BIT(16)) u_rx (.clk(clk), .rst_n(rst_n), .rx_in(tx),
                                      .valid(valid), .data(rx_byte));
    always #10 clk = ~clk;

    always @(posedge clk) if (valid) begin
        if (rx_byte !== bytes[nrx]) begin
            errors = errors + 1;
            $display("ERROR byte %0d: %h, esperado %h", nrx, rx_byte, bytes[nrx]);
        end
        nrx = nrx + 1;
    end

    initial begin
        bytes[0] = 8'h55; bytes[1] = 8'hA3; bytes[2] = 8'h00;
        bytes[3] = 8'hFF; bytes[4] = "D";   bytes[5] = 8'h0A;
        #35 rst_n = 1'b1;
        repeat (3) @(posedge clk);
        if (tx !== 1'b1) begin errors = errors + 1; $display("ERROR: linea no esta en reposo"); end
        for (i = 0; i < 6; i = i + 1) begin
            @(posedge clk) begin data <= bytes[i]; start <= 1'b1; end
            @(posedge clk) start <= 1'b0;
            t0 = $time;
            @(negedge busy);
            t1 = $time;
            if (i == 0 && (t1 - t0) / 20 != 10 * 16 - 1 && (t1 - t0) / 20 != 10 * 16)
                begin errors = errors + 1; $display("ERROR: trama de %0d ciclos", (t1 - t0) / 20); end
        end
        repeat (40) @(posedge clk);
        if (nrx != 6) begin errors = errors + 1; $display("ERROR: recibidos %0d", nrx); end
        if (errors == 0) $display("uart_loop_tb: PASS");
        else             $display("uart_loop_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
