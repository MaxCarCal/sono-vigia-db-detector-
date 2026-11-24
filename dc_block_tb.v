`timescale 1ns/1ps
//==============================================================================
// dc_block_tb.v - GENERADO por model/gen_golden_tb.py. Entrada: DC de 5000 +
// ruido (+-2048). Verifica bit a bit las primeras 64 salidas, el checksum de
// 3000, y que la DC desaparezca (promedio de las ultimas 1000 salidas ~ 0).
//==============================================================================
module dc_block_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [15:0] in_data = 16'sd0;
    wire out_valid;
    wire signed [15:0] out_data;
    reg  [31:0] lcg = 32'd7;
    integer exp_out [0:63];
    integer i, nout = 0, errors = 0, sum = 0, tail = 0;

    dc_block dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                  .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
        exp_out[0] = 6132;
        exp_out[1] = 4551;
        exp_out[2] = 5602;
        exp_out[3] = 5106;
        exp_out[4] = 6759;
        exp_out[5] = 6248;
        exp_out[6] = 6230;
        exp_out[7] = 5971;
        exp_out[8] = 6727;
        exp_out[9] = 5543;
        exp_out[10] = 5829;
        exp_out[11] = 3581;
        exp_out[12] = 3743;
        exp_out[13] = 4074;
        exp_out[14] = 3515;
        exp_out[15] = 3080;
        exp_out[16] = 4647;
        exp_out[17] = 5913;
        exp_out[18] = 5490;
        exp_out[19] = 6075;
        exp_out[20] = 2948;
        exp_out[21] = 4772;
        exp_out[22] = 3660;
        exp_out[23] = 3654;
        exp_out[24] = 4336;
        exp_out[25] = 4985;
        exp_out[26] = 5604;
        exp_out[27] = 4512;
        exp_out[28] = 4510;
        exp_out[29] = 5423;
        exp_out[30] = 4273;
        exp_out[31] = 3199;
        exp_out[32] = 4811;
        exp_out[33] = 2952;
        exp_out[34] = 5323;
        exp_out[35] = 6125;
        exp_out[36] = 2798;
        exp_out[37] = 5948;
        exp_out[38] = 4333;
        exp_out[39] = 3727;
        exp_out[40] = 6153;
        exp_out[41] = 3777;
        exp_out[42] = 3285;
        exp_out[43] = 2542;
        exp_out[44] = 3193;
        exp_out[45] = 5873;
        exp_out[46] = 3539;
        exp_out[47] = 5420;
        exp_out[48] = 3753;
        exp_out[49] = 5863;
        exp_out[50] = 3161;
        exp_out[51] = 4511;
        exp_out[52] = 6034;
        exp_out[53] = 5217;
        exp_out[54] = 5738;
        exp_out[55] = 2377;
        exp_out[56] = 3016;
        exp_out[57] = 4945;
        exp_out[58] = 2710;
        exp_out[59] = 2818;
        exp_out[60] = 2962;
        exp_out[61] = 5451;
        exp_out[62] = 6069;
        exp_out[63] = 3065;
    end

    always @(posedge clk) if (out_valid) begin
        if (nout < 64 && out_data !== exp_out[nout]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR salida %0d: %0d, esperado %0d", nout, out_data, exp_out[nout]);
        end
        sum = sum + out_data;
        if (nout >= 2000) tail = tail + out_data;
        nout = nout + 1;
    end

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < 3000; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= 16'sd5000 + $signed({4'd0, lcg[27:16]}) - 16'sd2048;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (3) @(posedge clk);
        end
        repeat (5) @(posedge clk);
        if (sum != 2065015) begin errors = errors + 1; $display("ERROR checksum %0d, esperado 2065015", sum); end
        $display("promedio de las ultimas 1000 salidas = %0d (DC eliminada si ~0)", tail / 1000);
        if (tail / 1000 > 100 || tail / 1000 < -100) begin errors = errors + 1; $display("ERROR: la DC no se elimino"); end
        if (errors == 0) $display("dc_block_tb: PASS");
        else             $display("dc_block_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
