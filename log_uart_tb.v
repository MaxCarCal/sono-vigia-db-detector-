`timescale 1ns/1ps
//==============================================================================
// log_uart_tb.v - Formateo de la UART: una linea en vivo y una descarga.
//   log_uart + lvl_log (DEPTH 8) + uart_tx; un uart_rx hace de "PC".
//   CLKS_PER_BIT = 8 para simular rapido.
// Esperado:
//   "09:05:07,067,P\r\n"
//   "065\r\n070\r\n102\r\nEND\r\n"   (tras recibir 'D')
//==============================================================================
module log_uart_tb;
    reg clk = 1'b0, rst_n = 1'b0;
    reg live_valid = 1'b0, rx_valid = 1'b0, wr_en = 1'b0;
    reg [7:0] rx_data = 8'h00, wr_data = 8'd0;
    wire [16:0] log_count, rd_idx;
    wire [7:0]  rd_data, tx_data, pc_byte;
    wire tx_start, tx_busy, txd, pc_valid;
    reg  [7:0] exp [0:63];
    integer ne = 0, nr = 0, errors = 0;

    lvl_log #(.DEPTH(8), .AW(17)) u_log (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
                                         .rd_idx(rd_idx), .rd_data(rd_data), .count(log_count));
    log_uart dut (.clk(clk), .rst_n(rst_n),
                  .live_valid(live_valid), .live_level(8'd67), .state_char("P"),
                  .hh(5'd9), .mm(6'd5), .ss(6'd7),
                  .rx_valid(rx_valid), .rx_data(rx_data),
                  .log_count(log_count), .rd_idx(rd_idx), .rd_data(rd_data),
                  .tx_start(tx_start), .tx_data(tx_data), .tx_busy(tx_busy));
    uart_tx #(.CLKS_PER_BIT(8)) u_tx (.clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
                                     .tx(txd), .busy(tx_busy));
    uart_rx #(.CLKS_PER_BIT(8)) u_pc (.clk(clk), .rst_n(rst_n), .rx_in(txd),
                                     .valid(pc_valid), .data(pc_byte));
    always #10 clk = ~clk;

    task push; input [7:0] b; begin exp[ne] = b; ne = ne + 1; end endtask

    always @(posedge clk) if (pc_valid) begin
        if (nr >= ne || pc_byte !== exp[nr]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR caracter %0d: %h ('%c'), esperado %h", nr, pc_byte, pc_byte, exp[nr]);
        end
        nr = nr + 1;
    end

    task write_log; input [7:0] d;
        begin @(posedge clk) begin wr_en <= 1'b1; wr_data <= d; end @(posedge clk) wr_en <= 1'b0; end
    endtask

    initial begin
        push("0"); push("9"); push(":"); push("0"); push("5"); push(":"); push("0"); push("7");
        push(","); push("0"); push("6"); push("7"); push(","); push("P"); push(8'h0D); push(8'h0A);
        push("0"); push("6"); push("5"); push(8'h0D); push(8'h0A); push("0"); push("7"); push("0");
        push(8'h0D); push(8'h0A); push("1"); push("0"); push("2"); push(8'h0D); push(8'h0A); push("E");
        push("N"); push("D"); push(8'h0D); push(8'h0A);
        #35 rst_n = 1'b1;
        write_log(8'd65); write_log(8'd70); write_log(8'd102);
        @(posedge clk) live_valid <= 1'b1;
        @(posedge clk) live_valid <= 1'b0;
        repeat (16 * 100) @(posedge clk);
        @(posedge clk) begin rx_valid <= 1'b1; rx_data <= "D"; end
        @(posedge clk) rx_valid <= 1'b0;
        repeat (40 * 100) @(posedge clk);
        if (nr != ne) begin errors = errors + 1; $display("ERROR: %0d caracteres recibidos, esperados %0d", nr, ne); end
        if (errors == 0) $display("log_uart_tb: PASS (%0d caracteres)", nr);
        else             $display("log_uart_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
