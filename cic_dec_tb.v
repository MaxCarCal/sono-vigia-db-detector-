`timescale 1ns/1ps
//==============================================================================
// cic_dec_tb.v - GENERADO por model/gen_golden_tb.py. Compara bit a bit contra
// el modelo Python. Entrada: ruido pseudoaleatorio de 12 bits (LCG) a 1 MS/s.
//==============================================================================
module cic_dec_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  [11:0] in_data = 12'd0;
    wire out_valid;
    wire signed [15:0] out_data;
    reg  [31:0] lcg = 32'd1;
    integer exp_out [0:63];
    integer i, nout = 0, errors = 0, sum = 0;

    cic_dec dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                 .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
        exp_out[0] = -272;
        exp_out[1] = -1242;
        exp_out[2] = 405;
        exp_out[3] = -613;
        exp_out[4] = 3143;
        exp_out[5] = 108;
        exp_out[6] = -3444;
        exp_out[7] = 109;
        exp_out[8] = -2350;
        exp_out[9] = -3926;
        exp_out[10] = 2110;
        exp_out[11] = 2403;
        exp_out[12] = 1183;
        exp_out[13] = 1676;
        exp_out[14] = -1262;
        exp_out[15] = -460;
        exp_out[16] = 138;
        exp_out[17] = -371;
        exp_out[18] = -3097;
        exp_out[19] = -3144;
        exp_out[20] = -2171;
        exp_out[21] = -4200;
        exp_out[22] = -2218;
        exp_out[23] = 2928;
        exp_out[24] = 2975;
        exp_out[25] = 2638;
        exp_out[26] = -1621;
        exp_out[27] = -2630;
        exp_out[28] = -1189;
        exp_out[29] = -3834;
        exp_out[30] = -785;
        exp_out[31] = -1120;
        exp_out[32] = -485;
        exp_out[33] = -327;
        exp_out[34] = 2976;
        exp_out[35] = -1853;
        exp_out[36] = -3218;
        exp_out[37] = -842;
        exp_out[38] = 788;
        exp_out[39] = -1184;
        exp_out[40] = -3784;
        exp_out[41] = -3610;
        exp_out[42] = -3131;
        exp_out[43] = -3835;
        exp_out[44] = -1313;
        exp_out[45] = 717;
        exp_out[46] = -752;
        exp_out[47] = 913;
        exp_out[48] = 3432;
        exp_out[49] = 3780;
        exp_out[50] = -343;
        exp_out[51] = -982;
        exp_out[52] = -180;
        exp_out[53] = -115;
        exp_out[54] = -2057;
        exp_out[55] = 829;
        exp_out[56] = 2004;
        exp_out[57] = -1184;
        exp_out[58] = 405;
        exp_out[59] = 2321;
        exp_out[60] = 665;
        exp_out[61] = -2529;
        exp_out[62] = -1973;
        exp_out[63] = 2821;
    end

    always @(posedge clk) if (out_valid) begin
        if (nout < 64 && out_data !== exp_out[nout]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR salida %0d: %0d, esperado %0d", nout, out_data, exp_out[nout]);
        end
        sum  = sum + out_data;
        nout = nout + 1;
    end

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < 16000; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= lcg[27:16];
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (3) @(posedge clk);
        end
        repeat (10) @(posedge clk);
        if (nout != 400) begin errors = errors + 1; $display("ERROR: %0d salidas, esperadas 400", nout); end
        if (sum != -139333) begin errors = errors + 1; $display("ERROR checksum %0d, esperado -139333", sum); end
        if (errors == 0) $display("cic_dec_tb: PASS (400 salidas bit-exactas)");
        else             $display("cic_dec_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
