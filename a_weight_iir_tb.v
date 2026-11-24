`timescale 1ns/1ps
//==============================================================================
// a_weight_iir_tb.v - GENERADO por model/gen_golden_tb.py.
// Parte 1: ruido pseudoaleatorio (+-8192): compara bit a bit 128 salidas y el
//          checksum de 2000.
// Parte 2: tonos de 1 kHz y 100 Hz (amplitud 8000): ganancia medida contra la
//          respuesta de diseno del filtro (0.07 dB y -19.16 dB; el filtro
//          incluye la compensacion del CIC). Tolerancia +-0.3 dB.
// Las muestras llegan cada 40 ciclos (el filtro usa 15).
//==============================================================================
module a_weight_iir_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [15:0] in_data = 16'sd0;
    wire out_valid;
    wire signed [17:0] out_data;
    reg  [31:0] lcg = 32'd3;
    integer exp_out [0:127];
    integer i, nout = 0, errors = 0, sum = 0;
    integer phase = 1;                 // 1 = ruido, 2 = tono
    real    peak, gdb;

    a_weight_iir dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                      .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
        exp_out[0] = -17899;
        exp_out[1] = 4598;
        exp_out[2] = 7352;
        exp_out[3] = 1092;
        exp_out[4] = -8876;
        exp_out[5] = 25101;
        exp_out[6] = -17672;
        exp_out[7] = 25529;
        exp_out[8] = -10336;
        exp_out[9] = 10967;
        exp_out[10] = -28531;
        exp_out[11] = -12052;
        exp_out[12] = 25954;
        exp_out[13] = -26507;
        exp_out[14] = 3799;
        exp_out[15] = -16829;
        exp_out[16] = 18398;
        exp_out[17] = 7980;
        exp_out[18] = 13053;
        exp_out[19] = -1348;
        exp_out[20] = -1862;
        exp_out[21] = 18289;
        exp_out[22] = 11619;
        exp_out[23] = -28488;
        exp_out[24] = -9328;
        exp_out[25] = -11241;
        exp_out[26] = -429;
        exp_out[27] = 7628;
        exp_out[28] = 9763;
        exp_out[29] = -20964;
        exp_out[30] = 11231;
        exp_out[31] = -17204;
        exp_out[32] = -8469;
        exp_out[33] = 17178;
        exp_out[34] = 5826;
        exp_out[35] = -5388;
        exp_out[36] = -2382;
        exp_out[37] = 9046;
        exp_out[38] = 2113;
        exp_out[39] = -584;
        exp_out[40] = 10482;
        exp_out[41] = 3183;
        exp_out[42] = 22615;
        exp_out[43] = -11120;
        exp_out[44] = 11019;
        exp_out[45] = 11799;
        exp_out[46] = 9784;
        exp_out[47] = -31437;
        exp_out[48] = 2807;
        exp_out[49] = 5336;
        exp_out[50] = -21193;
        exp_out[51] = 7561;
        exp_out[52] = -403;
        exp_out[53] = -19480;
        exp_out[54] = 1677;
        exp_out[55] = -18377;
        exp_out[56] = 24492;
        exp_out[57] = -4021;
        exp_out[58] = 1701;
        exp_out[59] = 12276;
        exp_out[60] = -5493;
        exp_out[61] = -10883;
        exp_out[62] = -13013;
        exp_out[63] = 26346;
        exp_out[64] = 8858;
        exp_out[65] = -10213;
        exp_out[66] = -18489;
        exp_out[67] = 25268;
        exp_out[68] = -8126;
        exp_out[69] = 8666;
        exp_out[70] = -25048;
        exp_out[71] = -9753;
        exp_out[72] = 14048;
        exp_out[73] = 1489;
        exp_out[74] = -13747;
        exp_out[75] = -2683;
        exp_out[76] = 23404;
        exp_out[77] = -19349;
        exp_out[78] = 21679;
        exp_out[79] = 8224;
        exp_out[80] = -11295;
        exp_out[81] = 3407;
        exp_out[82] = -13373;
        exp_out[83] = -11743;
        exp_out[84] = -9981;
        exp_out[85] = -8339;
        exp_out[86] = -2889;
        exp_out[87] = 3293;
        exp_out[88] = 24762;
        exp_out[89] = 14126;
        exp_out[90] = -15044;
        exp_out[91] = 19186;
        exp_out[92] = -1881;
        exp_out[93] = 2651;
        exp_out[94] = 1492;
        exp_out[95] = -11057;
        exp_out[96] = -12256;
        exp_out[97] = 24701;
        exp_out[98] = 2269;
        exp_out[99] = 18881;
        exp_out[100] = -14287;
        exp_out[101] = 7003;
        exp_out[102] = 10007;
        exp_out[103] = 17075;
        exp_out[104] = -17470;
        exp_out[105] = 10051;
        exp_out[106] = 11117;
        exp_out[107] = 9746;
        exp_out[108] = 1547;
        exp_out[109] = -19042;
        exp_out[110] = -4220;
        exp_out[111] = -22334;
        exp_out[112] = -5439;
        exp_out[113] = -12493;
        exp_out[114] = -13695;
        exp_out[115] = -12455;
        exp_out[116] = 16782;
        exp_out[117] = 6058;
        exp_out[118] = -13278;
        exp_out[119] = 26067;
        exp_out[120] = 676;
        exp_out[121] = -17348;
        exp_out[122] = 7171;
        exp_out[123] = 4307;
        exp_out[124] = 1674;
        exp_out[125] = -20116;
        exp_out[126] = 9242;
        exp_out[127] = 18963;
    end

    always @(posedge clk) if (out_valid) begin
        if (phase == 1) begin
            if (nout < 128 && out_data !== exp_out[nout]) begin
                errors = errors + 1;
                if (errors < 10) $display("ERROR salida %0d: %0d, esperado %0d", nout, out_data, exp_out[nout]);
            end
            sum = sum + out_data;
        end else if (nout > 5000) begin            // tono, ya sin transitorio
            if ($itor(out_data) > peak) peak = $itor(out_data);
        end
        nout = nout + 1;
    end

    task tone_test;
        input real f;
        input real expected_db;
        integer n;
        begin
            rst_n = 1'b0; #50 rst_n = 1'b1;        // reinicia el filtro
            phase = 2; nout = 0; peak = 0.0;
            for (n = 0; n < 8000; n = n + 1) begin
                @(posedge clk);
                in_data  <= $rtoi(8000.0 * $sin(2.0 * 3.14159265358979 * f * n / 25000.0));
                in_valid <= 1'b1;
                @(posedge clk) in_valid <= 1'b0;
                repeat (38) @(posedge clk);
            end
            gdb = 20.0 * $log10(peak / 16000.0);   // entrada x2 interna -> 16000
            $display("tono %0.1f Hz: ganancia %0.2f dB (diseno %0.2f dB)", f, gdb, expected_db);
            if (gdb - expected_db > 0.3 || gdb - expected_db < -0.3) begin
                errors = errors + 1;
                $display("ERROR: ganancia fuera de tolerancia");
            end
        end
    endtask

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < 2000; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= $signed({2'd0, lcg[29:16]}) - 16'sd8192;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (38) @(posedge clk);
        end
        repeat (40) @(posedge clk);
        if (nout != 2000) begin errors = errors + 1; $display("ERROR: %0d salidas", nout); end
        if (sum != -7894) begin errors = errors + 1; $display("ERROR checksum %0d, esperado -7894", sum); end

        tone_test(1000.0, 0.069);
        tone_test(100.0,  -19.157);

        if (errors == 0) $display("a_weight_iir_tb: PASS");
        else             $display("a_weight_iir_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
