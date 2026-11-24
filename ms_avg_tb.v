`timescale 1ns/1ps
//==============================================================================
// ms_avg_tb.v - GENERADO por model/gen_golden_tb.py.
// Usa BLK = 5 (en lugar de 3125) para simular rapido; la logica es la misma.
// Entrada: valores pseudoaleatorios de 18 bits (rango completo).
// Compara fast_sum, slow_sum y sec_flag de 40 bloques contra el modelo.
//==============================================================================
module ms_avg_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [17:0] in_data = 18'sd0;
    wire blk_valid, sec_flag;
    wire [47:0] fast_sum, slow_sum;
    reg  [31:0] lcg = 32'd11;
    reg  [47:0] exp_fast [0:39];
    reg  [47:0] exp_slow [0:39];
    reg         exp_sec  [0:39];
    integer i, nb = 0, errors = 0;

    ms_avg #(.BLK(5)) dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                         .blk_valid(blk_valid), .sec_flag(sec_flag),
                         .fast_sum(fast_sum), .slow_sum(slow_sum));
    always #10 clk = ~clk;

    initial begin
        exp_fast[0] = 48'd41325448089;
        exp_fast[1] = 48'd26281311560;
        exp_fast[2] = 48'd39891993103;
        exp_fast[3] = 48'd30752892591;
        exp_fast[4] = 48'd59810693331;
        exp_fast[5] = 48'd25203594593;
        exp_fast[6] = 48'd18216439746;
        exp_fast[7] = 48'd17070713855;
        exp_fast[8] = 48'd27031773169;
        exp_fast[9] = 48'd36045878316;
        exp_fast[10] = 48'd11449453432;
        exp_fast[11] = 48'd45632818623;
        exp_fast[12] = 48'd14770547639;
        exp_fast[13] = 48'd31965846934;
        exp_fast[14] = 48'd17942465271;
        exp_fast[15] = 48'd21814122170;
        exp_fast[16] = 48'd32417488986;
        exp_fast[17] = 48'd29896145738;
        exp_fast[18] = 48'd37130050819;
        exp_fast[19] = 48'd7871259440;
        exp_fast[20] = 48'd29861449243;
        exp_fast[21] = 48'd14390751361;
        exp_fast[22] = 48'd32392060534;
        exp_fast[23] = 48'd54398406241;
        exp_fast[24] = 48'd30824564554;
        exp_fast[25] = 48'd25189043993;
        exp_fast[26] = 48'd33672457028;
        exp_fast[27] = 48'd12692571000;
        exp_fast[28] = 48'd26829311155;
        exp_fast[29] = 48'd27531395941;
        exp_fast[30] = 48'd24442884791;
        exp_fast[31] = 48'd49410749761;
        exp_fast[32] = 48'd30876631976;
        exp_fast[33] = 48'd23809182285;
        exp_fast[34] = 48'd39924333860;
        exp_fast[35] = 48'd19178197627;
        exp_fast[36] = 48'd18710090890;
        exp_fast[37] = 48'd20984146303;
        exp_fast[38] = 48'd41573102908;
        exp_fast[39] = 48'd37336392226;
        exp_slow[0] = 48'd5165681011;
        exp_slow[1] = 48'd8450844956;
        exp_slow[2] = 48'd13437344094;
        exp_slow[3] = 48'd17281455667;
        exp_slow[4] = 48'd24757792334;
        exp_slow[5] = 48'd27908241658;
        exp_slow[6] = 48'd30185296626;
        exp_slow[7] = 48'd32319135858;
        exp_slow[8] = 48'd30532426493;
        exp_slow[9] = 48'd31752997338;
        exp_slow[10] = 48'd28197679879;
        exp_slow[11] = 48'd30057670633;
        exp_slow[12] = 48'd24427652421;
        exp_slow[13] = 48'd25272933964;
        exp_slow[14] = 48'd25238687154;
        exp_slow[15] = 48'd25831613194;
        exp_slow[16] = 48'd26504827671;
        exp_slow[17] = 48'd25736111099;
        exp_slow[18] = 48'd28946185772;
        exp_slow[19] = 48'd24225990874;
        exp_slow[20] = 48'd26112353575;
        exp_slow[21] = 48'd23915466628;
        exp_slow[22] = 48'd25721666036;
        exp_slow[23] = 48'd29794701545;
        exp_slow[24] = 48'd29595585991;
        exp_slow[25] = 48'd29007198273;
        exp_slow[26] = 48'd28574999049;
        exp_slow[27] = 48'd29177662994;
        exp_slow[28] = 48'd28798645733;
        exp_slow[29] = 48'd30441226305;
        exp_slow[30] = 48'd29447579337;
        exp_slow[31] = 48'd28824122277;
        exp_slow[32] = 48'd28830630705;
        exp_slow[33] = 48'd28658147992;
        exp_slow[34] = 48'd29439632596;
        exp_slow[35] = 48'd30250335924;
        exp_slow[36] = 48'd29235433391;
        exp_slow[37] = 48'd28417027186;
        exp_slow[38] = 48'd30558304451;
        exp_slow[39] = 48'd29049009759;
        exp_sec[0] = 1'b0;
        exp_sec[1] = 1'b0;
        exp_sec[2] = 1'b0;
        exp_sec[3] = 1'b0;
        exp_sec[4] = 1'b0;
        exp_sec[5] = 1'b0;
        exp_sec[6] = 1'b0;
        exp_sec[7] = 1'b1;
        exp_sec[8] = 1'b0;
        exp_sec[9] = 1'b0;
        exp_sec[10] = 1'b0;
        exp_sec[11] = 1'b0;
        exp_sec[12] = 1'b0;
        exp_sec[13] = 1'b0;
        exp_sec[14] = 1'b0;
        exp_sec[15] = 1'b1;
        exp_sec[16] = 1'b0;
        exp_sec[17] = 1'b0;
        exp_sec[18] = 1'b0;
        exp_sec[19] = 1'b0;
        exp_sec[20] = 1'b0;
        exp_sec[21] = 1'b0;
        exp_sec[22] = 1'b0;
        exp_sec[23] = 1'b1;
        exp_sec[24] = 1'b0;
        exp_sec[25] = 1'b0;
        exp_sec[26] = 1'b0;
        exp_sec[27] = 1'b0;
        exp_sec[28] = 1'b0;
        exp_sec[29] = 1'b0;
        exp_sec[30] = 1'b0;
        exp_sec[31] = 1'b1;
        exp_sec[32] = 1'b0;
        exp_sec[33] = 1'b0;
        exp_sec[34] = 1'b0;
        exp_sec[35] = 1'b0;
        exp_sec[36] = 1'b0;
        exp_sec[37] = 1'b0;
        exp_sec[38] = 1'b0;
        exp_sec[39] = 1'b1;
    end

    always @(posedge clk) if (blk_valid) begin
        if (fast_sum !== exp_fast[nb] || slow_sum !== exp_slow[nb] || sec_flag !== exp_sec[nb]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR bloque %0d: fast=%0d slow=%0d sec=%b | esperado %0d %0d %b",
                                      nb, fast_sum, slow_sum, sec_flag, exp_fast[nb], exp_slow[nb], exp_sec[nb]);
        end
        nb = nb + 1;
    end

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= $signed({1'b0, lcg[31:14]}) - 19'sd131072;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (6) @(posedge clk);
        end
        repeat (10) @(posedge clk);
        if (nb != 40) begin errors = errors + 1; $display("ERROR: %0d bloques", nb); end
        if (errors == 0) $display("ms_avg_tb: PASS (40 bloques)");
        else             $display("ms_avg_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
