"""
gen_golden_tb.py - genera testbenches autoverificables con valores esperados
bit-exactos calculados por chain_model.py.
Las entradas usan el mismo generador pseudoaleatorio (LCG) en Python y Verilog:
    lcg = lcg * 1103515245 + 12345   (mod 2^32)
"""
from chain_model import *
from design_aweight import a_analog, cic_mag, bq_resp, hp_chain, bq_q, aq_q, FRAC
import numpy as np

def lcg_seq(n, seed=1):
    s = seed; out = []
    for _ in range(n):
        s = (s*1103515245 + 12345) & 0xFFFFFFFF
        out.append(s)
    return out

def to_s(v, w):
    return v - (1 << w) if v >= (1 << (w-1)) else v

def arr(name, vals):
    return "\n".join(f"        {name}[{i}] = {v};" for i, v in enumerate(vals))

def checksum(vals):          # suma con signo modulo 2^32 (como un integer de Verilog)
    s = 0
    for v in vals: s = (s + v) & 0xFFFFFFFF
    return to_s(s, 32)

HEADER = "`timescale 1ns/1ps\n"

# ------------------------------------------------------------------ cic_dec
N_IN = 40*400
L = lcg_seq(N_IN)
adc = [(s >> 16) & 0xFFF for s in L]
cic = cic_dec(adc)
NCHK = 64
open("../tb/cic_dec_tb.v", "w").write(HEADER + f"""//==============================================================================
// cic_dec_tb.v - GENERADO por model/gen_golden_tb.py. Compara bit a bit contra
// el modelo Python. Entrada: ruido pseudoaleatorio de 12 bits (LCG) a 1 MS/s.
//==============================================================================
module cic_dec_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  [11:0] in_data = 12'd0;
    wire out_valid;
    wire signed [15:0] out_data;
    reg  [31:0] lcg = 32'd1;
    integer exp_out [0:{NCHK-1}];
    integer i, nout = 0, errors = 0, sum = 0;

    cic_dec dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                 .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
{arr("exp_out", cic[:NCHK])}
    end

    always @(posedge clk) if (out_valid) begin
        if (nout < {NCHK} && out_data !== exp_out[nout]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR salida %0d: %0d, esperado %0d", nout, out_data, exp_out[nout]);
        end
        sum  = sum + out_data;
        nout = nout + 1;
    end

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < {N_IN}; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= lcg[27:16];
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (3) @(posedge clk);
        end
        repeat (10) @(posedge clk);
        if (nout != {len(cic)}) begin errors = errors + 1; $display("ERROR: %0d salidas, esperadas {len(cic)}", nout); end
        if (sum != {checksum(cic)}) begin errors = errors + 1; $display("ERROR checksum %0d, esperado {checksum(cic)}", sum); end
        if (errors == 0) $display("cic_dec_tb: PASS ({len(cic)} salidas bit-exactas)");
        else             $display("cic_dec_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
""")

# ------------------------------------------------------------------ dc_block
N = 3000
L = lcg_seq(N, seed=7)
xin = [5000 + ((s >> 16) & 0xFFF) - 2048 for s in L]        # DC de 5000 + ruido
dcb = dc_block(xin)
open("../tb/dc_block_tb.v", "w").write(HEADER + f"""//==============================================================================
// dc_block_tb.v - GENERADO por model/gen_golden_tb.py. Entrada: DC de 5000 +
// ruido (+-2048). Verifica bit a bit las primeras {NCHK} salidas, el checksum de
// {N}, y que la DC desaparezca (promedio de las ultimas 1000 salidas ~ 0).
//==============================================================================
module dc_block_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [15:0] in_data = 16'sd0;
    wire out_valid;
    wire signed [15:0] out_data;
    reg  [31:0] lcg = 32'd7;
    integer exp_out [0:{NCHK-1}];
    integer i, nout = 0, errors = 0, sum = 0, tail = 0;

    dc_block dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                  .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
{arr("exp_out", dcb[:NCHK])}
    end

    always @(posedge clk) if (out_valid) begin
        if (nout < {NCHK} && out_data !== exp_out[nout]) begin
            errors = errors + 1;
            if (errors < 10) $display("ERROR salida %0d: %0d, esperado %0d", nout, out_data, exp_out[nout]);
        end
        sum = sum + out_data;
        if (nout >= {N-1000}) tail = tail + out_data;
        nout = nout + 1;
    end

    initial begin
        #55 rst_n = 1'b1;
        for (i = 0; i < {N}; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= 16'sd5000 + $signed({{4'd0, lcg[27:16]}}) - 16'sd2048;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (3) @(posedge clk);
        end
        repeat (5) @(posedge clk);
        if (sum != {checksum(dcb)}) begin errors = errors + 1; $display("ERROR checksum %0d, esperado {checksum(dcb)}", sum); end
        $display("promedio de las ultimas 1000 salidas = %0d (DC eliminada si ~0)", tail / 1000);
        if (tail / 1000 > 100 || tail / 1000 < -100) begin errors = errors + 1; $display("ERROR: la DC no se elimino"); end
        if (errors == 0) $display("dc_block_tb: PASS");
        else             $display("dc_block_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
""")
print("tail mean python:", sum(dcb[-1000:])/1000)


# ------------------------------------------------------------------ a_weight_iir
N = 2000
L = lcg_seq(N, seed=3)
xin = [((s >> 16) & 0x3FFF) - 8192 for s in L]
aw = a_weight(xin)
NA = 128
def filt_db(f):     # respuesta del filtro solo (sin CIC) con coeficientes cuantizados
    fa = np.array([f])
    h = hp_chain(fa)*bq_resp(np.array(bq_q)/2**FRAC, np.array(aq_q)/2**FRAC, fa)
    return 20*np.log10(abs(h[0]))
g1k, g100 = filt_db(1000.0), filt_db(100.0)
open("../tb/a_weight_iir_tb.v", "w").write(HEADER + f"""//==============================================================================
// a_weight_iir_tb.v - GENERADO por model/gen_golden_tb.py.
// Parte 1: ruido pseudoaleatorio (+-8192): compara bit a bit {NA} salidas y el
//          checksum de {N}.
// Parte 2: tonos de 1 kHz y 100 Hz (amplitud 8000): ganancia medida contra la
//          respuesta de diseno del filtro ({g1k:.2f} dB y {g100:.2f} dB; el filtro
//          incluye la compensacion del CIC). Tolerancia +-0.3 dB.
// Las muestras llegan cada 40 ciclos (el filtro usa 15).
//==============================================================================
module a_weight_iir_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [15:0] in_data = 16'sd0;
    wire out_valid;
    wire signed [17:0] out_data;
    reg  [31:0] lcg = 32'd3;
    integer exp_out [0:{NA-1}];
    integer i, nout = 0, errors = 0, sum = 0;
    integer phase = 1;                 // 1 = ruido, 2 = tono
    real    peak, gdb;

    a_weight_iir dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                      .out_valid(out_valid), .out_data(out_data));
    always #10 clk = ~clk;

    initial begin
{arr("exp_out", aw[:NA])}
    end

    always @(posedge clk) if (out_valid) begin
        if (phase == 1) begin
            if (nout < {NA} && out_data !== exp_out[nout]) begin
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
        for (i = 0; i < {N}; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= $signed({{2'd0, lcg[29:16]}}) - 16'sd8192;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (38) @(posedge clk);
        end
        repeat (40) @(posedge clk);
        if (nout != {N}) begin errors = errors + 1; $display("ERROR: %0d salidas", nout); end
        if (sum != {checksum(aw)}) begin errors = errors + 1; $display("ERROR checksum %0d, esperado {checksum(aw)}", sum); end

        tone_test(1000.0, {g1k:.3f});
        tone_test(100.0,  {g100:.3f});

        if (errors == 0) $display("a_weight_iir_tb: PASS");
        else             $display("a_weight_iir_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
""")
# chequeo en Python de la parte de tonos (mismo estimulo, mismo pico)
for f, g in ((1000.0, g1k), (100.0, g100)):
    xs = [int(8000.0*np.sin(2*np.pi*f*n/25000.0)) for n in range(8000)]
    ys = a_weight(xs)
    pk = max(ys[5001:])
    print(f"tono {f}: pico modelo -> {20*np.log10(pk/16000):.3f} dB (diseno {g:.3f})")

# ------------------------------------------------------------------ ms_avg
BLKT = 5; NB = 40
L = lcg_seq(BLKT*NB, seed=11)
ys = [((s >> 14) & 0x3FFFF) - 131072 for s in L]
res = ms_avg(ys, BLK=BLKT)
def arr48(name, vals):
    return "\n".join(f"        {name}[{i}] = 48'd{v};" for i, v in enumerate(vals))
open("../tb/ms_avg_tb.v", "w").write(HEADER + f"""//==============================================================================
// ms_avg_tb.v - GENERADO por model/gen_golden_tb.py.
// Usa BLK = {BLKT} (en lugar de 3125) para simular rapido; la logica es la misma.
// Entrada: valores pseudoaleatorios de 18 bits (rango completo).
// Compara fast_sum, slow_sum y sec_flag de {NB} bloques contra el modelo.
//==============================================================================
module ms_avg_tb;
    reg clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  signed [17:0] in_data = 18'sd0;
    wire blk_valid, sec_flag;
    wire [47:0] fast_sum, slow_sum;
    reg  [31:0] lcg = 32'd11;
    reg  [47:0] exp_fast [0:{NB-1}];
    reg  [47:0] exp_slow [0:{NB-1}];
    reg         exp_sec  [0:{NB-1}];
    integer i, nb = 0, errors = 0;

    ms_avg #(.BLK({BLKT})) dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_data(in_data),
                         .blk_valid(blk_valid), .sec_flag(sec_flag),
                         .fast_sum(fast_sum), .slow_sum(slow_sum));
    always #10 clk = ~clk;

    initial begin
{arr48("exp_fast", [r[0] for r in res])}
{arr48("exp_slow", [r[1] for r in res])}
{chr(10).join(f"        exp_sec[{i}] = 1'b{int(r[2])};" for i, r in enumerate(res))}
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
        for (i = 0; i < {BLKT*NB}; i = i + 1) begin
            @(posedge clk);
            lcg = lcg * 32'd1103515245 + 32'd12345;
            in_data  <= $signed({{1'b0, lcg[31:14]}}) - 19'sd131072;
            in_valid <= 1'b1;
            @(posedge clk) in_valid <= 1'b0;
            repeat (6) @(posedge clk);
        end
        repeat (10) @(posedge clk);
        if (nb != {NB}) begin errors = errors + 1; $display("ERROR: %0d bloques", nb); end
        if (errors == 0) $display("ms_avg_tb: PASS ({NB} bloques)");
        else             $display("ms_avg_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
""")

# ------------------------------------------------------------------ db_lut
import random
random.seed(4)
xs = [0, 1, 2, 3, 6400000000000, (1 << 46) - 1, (1 << 47)]
for k in range(0, 144, 3):
    xs += [THR[k] - 1, THR[k]]
xs += [random.randrange(1, 1 << 46) for _ in range(20)]
cases = []
for i, x in enumerate(xs):
    trim = (i % 8) - 4
    raw = db_raw(x)
    lvl = min(199, max(0, raw - 18 + trim))
    cases.append((x, trim, raw, lvl))
body = "\n".join(f"        check(48'd{x}, {t}, {r}, {l});" for x, t, r, l in cases)
open("../tb/db_lut_tb.v", "w").write(HEADER + f"""//==============================================================================
// db_lut_tb.v - GENERADO por model/gen_golden_tb.py.
// {len(cases)} casos: alrededor de los umbrales (thr-1 y thr), extremos y
// valores aleatorios, con trim de -4 a +3. CAL_DB = -18.
//==============================================================================
module db_lut_tb;
    reg clk = 1'b0, rst_n = 1'b0, start = 1'b0;
    reg  [47:0] x = 48'd0;
    reg  signed [3:0] trim = 4'sd0;
    wire done;
    wire [7:0] raw, level;
    integer errors = 0, ncase = 0;

    db_lut #(.CAL_DB(-18)) dut (.clk(clk), .rst_n(rst_n), .start(start), .x(x), .trim(trim),
                                .done(done), .raw(raw), .level(level));
    always #10 clk = ~clk;

    task check;
        input [47:0]  xv;
        input integer tv;
        input integer exp_raw;
        input integer exp_lvl;
        begin
            @(posedge clk);
            x <= xv; trim <= tv; start <= 1'b1;
            @(posedge clk) start <= 1'b0;
            @(posedge done);
            @(negedge clk);
            if (raw !== exp_raw || level !== exp_lvl) begin
                errors = errors + 1;
                $display("ERROR x=%0d trim=%0d: raw=%0d level=%0d, esperado %0d %0d",
                         xv, tv, raw, level, exp_raw, exp_lvl);
            end
            ncase = ncase + 1;
        end
    endtask

    initial begin
        #55 rst_n = 1'b1;
{body}
        if (errors == 0) $display("db_lut_tb: PASS (%0d casos)", ncase);
        else             $display("db_lut_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
""")
print("db_lut casos:", len(cases), " ejemplo:", cases[4])
