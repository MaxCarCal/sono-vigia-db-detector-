"""
chain_model.py - Modelo bit-exacto (aritmetica entera) de la cadena SonoVigia.
Cada funcion replica el Verilog correspondiente operacion por operacion.

  adc (12 bit, 1 MS/s) -> cic_dec -> dc_block -> a_weight_iir -> ms_avg -> db_lut
"""
import numpy as np
from design_aweight import pk_q, bq_q, aq_q, FRAC

# ------------------------------------------------------------ utilidades
def wrap(v, w):                       # aritmetica modular con signo (como un reg de w bits)
    m = 1 << w
    v &= m - 1
    return v - m if v >= (m >> 1) else v

def sat(v, w):                        # saturacion a w bits con signo
    lo, hi = -(1 << (w-1)), (1 << (w-1)) - 1
    return lo if v < lo else hi if v > hi else v

# ------------------------------------------------------------ cic_dec
CIC_W, CIC_R, CIC_SHIFT = 28, 40, 12
def cic_dec(adc):
    i1 = i2 = i3 = 0
    c1 = c2 = c3 = 0                  # retardos de los combs
    cnt = 0
    out = []
    for s in adc:
        x = s - 2048                  # binario desplazado -> con signo
        # igual que el RTL con asignaciones no bloqueantes: cada etapa usa el valor ANTERIOR
        i1, i2, i3 = wrap(i1 + x, CIC_W), wrap(i2 + i1, CIC_W), wrap(i3 + i2, CIC_W)
        if cnt == CIC_R - 1:
            cnt = 0
            d1 = wrap(i3 - c1, CIC_W); c1 = i3
            d2 = wrap(d1 - c2, CIC_W); c2 = d1
            d3 = wrap(d2 - c3, CIC_W); c3 = d2
            out.append(wrap(d3 >> CIC_SHIFT, 16))
        else:
            cnt += 1
    return out

# ------------------------------------------------------------ dc_block
DCB_F, DCB_W = 10, 30
def dc_block(xs):
    acc = 0; x1 = 0; out = []
    for x in xs:
        acc = wrap(acc - (acc >> 9) - (acc >> 11) + ((x - x1) << DCB_F), DCB_W)
        x1 = x
        out.append(sat((acc + (1 << (DCB_F-1))) >> DCB_F, 16))
    return out

# ------------------------------------------------------------ a_weight_iir
DW, AW = 18, 40
HALF = 1 << (FRAC-1)
def a_weight(xs):
    xp = [0]*4; yp = [0]*4
    bx1 = bx2 = by1 = by2 = 0
    out = []
    for x in xs:
        v = x << 1                    # entrada de 16 bits -> 18 bits (x2)
        for k in range(4):
            acc = ((v - xp[k]) << FRAC) + pk_q[k]*yp[k]
            acc = wrap(acc, AW)
            y = sat((acc + HALF) >> FRAC, DW)
            xp[k] = v; yp[k] = y
            v = y
        acc = bq_q[0]*v + bq_q[1]*bx1 + bq_q[2]*bx2 - aq_q[0]*by1 - aq_q[1]*by2
        acc = wrap(acc, AW)
        w = sat((acc + HALF) >> FRAC, DW)
        bx2, bx1 = bx1, v
        by2, by1 = by1, w
        out.append(w)
    return out

# ------------------------------------------------------------ ms_avg
BLK = 3125                            # 125 ms a 25 kS/s
def ms_avg(ys, BLK=BLK):
    """Devuelve lista de (fast_sum, slow_sum, is_second) por bloque de 125 ms."""
    ring = [0]*8; ptr = 0; slow_acc = 0; nblk = 0
    acc = 0; n = 0; res = []
    for y in ys:
        acc += y*y; n += 1
        if n == BLK:
            slow_acc = slow_acc + acc - ring[ptr]
            ring[ptr] = acc; ptr = (ptr + 1) % 8
            nblk = (nblk + 1) % 8
            res.append((acc, slow_acc >> 3, nblk == 0))
            acc = 0; n = 0
    return res

# ------------------------------------------------------------ db_lut
import math
SUMW = 48
NTHR = 256
def thr_table():
    t = []
    for k in range(NTHR):
        v = 10**((k + 0.5)/10)
        t.append(math.ceil(v) if v < 2**SUMW - 1 else (1 << SUMW) - 1)
    return t
THR = thr_table()
def db_raw(x):
    """Busqueda binaria identica al RTL: cuenta umbrales <= x (0..255)."""
    idx = 0
    for bit in range(7, -1, -1):
        tryv = idx | (1 << bit)
        if THR[tryv - 1] <= x:
            idx = tryv
    return idx

# ------------------------------------------------------------ fuente de prueba
FS_ADC = 1.0e6
def adc_tone(freq, amp, n, offset=2048, noise=0.0, seed=0, phase=0.3):
    rng = np.random.default_rng(seed)
    t = np.arange(n)/FS_ADC
    v = offset + amp*np.sin(2*np.pi*freq*t + phase) + rng.normal(0, noise, n) if noise else \
        offset + amp*np.sin(2*np.pi*freq*t + phase)
    return [int(min(4095, max(0, round(s)))) for s in v]
