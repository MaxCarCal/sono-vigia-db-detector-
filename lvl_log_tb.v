`timescale 1ns/1ps
//==============================================================================
// lvl_log_tb.v - Buffer circular con DEPTH = 8 (en hardware es 86,400).
// 5 escrituras -> se leen 5 en orden. 6 mas (11 en total) -> el anillo se
// lleno: quedan las 8 mas nuevas y rd_idx = 0 apunta a la mas vieja.
//==============================================================================
module lvl_log_tb;
    reg clk = 1'b0, rst_n = 1'b0, wr_en = 1'b0;
    reg [7:0] wr_data = 8'd0;
    reg [16:0] rd_idx = 17'd0;
    wire [7:0] rd_data;
    wire [16:0] count;
    integer i, errors = 0;

    lvl_log #(.DEPTH(8), .AW(17)) dut (.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
                                       .rd_idx(rd_idx), .rd_data(rd_data), .count(count));
    always #10 clk = ~clk;

    task write;
        input [7:0] d;
        begin @(posedge clk) begin wr_en <= 1'b1; wr_data <= d; end @(posedge clk) wr_en <= 1'b0; end
    endtask

    task read_check;
        input integer idx;
        input [7:0] expv;
        begin
            @(posedge clk) rd_idx <= idx;
            repeat (2) @(posedge clk); #1;
            if (rd_data !== expv) begin
                errors = errors + 1;
                $display("ERROR rd_idx=%0d: %0d, esperado %0d", idx, rd_data, expv);
            end
        end
    endtask

    initial begin
        #35 rst_n = 1'b1;
        for (i = 0; i < 5; i = i + 1) write(10 + i);
        #1;
        if (count !== 5) begin errors = errors + 1; $display("ERROR count=%0d", count); end
        for (i = 0; i < 5; i = i + 1) read_check(i, 10 + i);
        for (i = 5; i < 11; i = i + 1) write(10 + i);
        #1;
        if (count !== 8) begin errors = errors + 1; $display("ERROR count=%0d (lleno = 8)", count); end
        for (i = 0; i < 8; i = i + 1) read_check(i, 13 + i);      // 13..20

        if (errors == 0) $display("lvl_log_tb: PASS");
        else             $display("lvl_log_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
