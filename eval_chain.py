import numpy as np, math
from chain_model import *
from design_aweight import a_analog

def run(adc):
    y = a_weight(dc_block(cic_dec(adc)))
    blocks = ms_avg(y)
    return y, blocks

# ganancia de referencia: tono 1 kHz a escala completa -> raw esperado
print("== Linealidad: tono 1 kHz, amplitud decreciente (2 s, ultimo segundo)")
print("  amp[LSB12]  dBFS    raw_1s  ideal_10log10   error")
for amp in [2000, 632, 200, 63, 20, 6.3, 2.0]:
    adc = adc_tone(1000, amp, 2_000_000, noise=0.0)
    y, b = run(adc)
    sec = [s for (f, s, isec) in b if isec]
    raw = db_raw(sec[-1])
    # ideal: senoidal a la salida = amp*15.625*2 (ganancia 1 en 1 kHz) -> ms = A^2/2 ; sum = ms*3125
    A = amp*15.625*2
    ideal = 10*math.log10(A*A/2*3125)
    print(f"  {amp:9.1f}  {20*math.log10(amp/2048):6.1f}   {raw:4d}    {ideal:8.2f}    {raw-ideal:+5.2f}")

print("\n== Respuesta en frecuencia de la cadena completa (amp 1000 LSB12)")
print("  f[Hz]   A ideal  medido   error")
ref = None
for f in [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 10000]:
    adc = adc_tone(f, 1000, 1_500_000)
    y, b = run(adc)
    yy = np.array(y[len(y)//3:], float)
    meas = 10*math.log10(np.mean(yy*yy))
    if f == 1000: ref = meas
    res = (f, 20*math.log10(a_analog(f)), meas)
    print(f"  {f:7.1f}  {res[1]:7.2f}", end="")
    globals().setdefault('rows', []).append(res)
    print(f"  {meas:8.2f}", end="\n")
print("  (error relativo a 1 kHz):")
for f, ai, m in rows:
    print(f"   {f:7.1f} Hz: {m-ref-ai:+5.2f} dB")

print("\n== Piso de ruido: silencio con ruido de ADC (sigma LSB12)")
for sig in [0.5, 1.0]:
    adc = adc_tone(1000, 0.0, 2_000_000, noise=sig, seed=5)
    y, b = run(adc)
    sec = [s for (f, s, isec) in b if isec]
    print(f"  sigma={sig}: raw_1s={db_raw(sec[-1])}  (1 kHz FS = 128)")

print("\n== Desbordes: valores maximos internos con tono 2.5 kHz casi a escala completa")
adc = adc_tone(2500, 2040, 600_000)
c = cic_dec(adc); d = dc_block(c); y = a_weight(d)
print("  max|cic|=", max(map(abs, c)), " max|dcb|=", max(map(abs, d)), " max|aw|=", max(map(abs, y)), "(limite 131071)")
blk = ms_avg(y)
print("  max fast_sum =", max(f for f,_,_ in blk), " bits=", max(f for f,_,_ in blk).bit_length())
