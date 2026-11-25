"""
design_aweight.py - Diseno de la ponderacion A para SonoVigia (fs = 25 kS/s)

Estructura elegida (orden 6, igual que 3 biquads):
  4 secciones pasa-altas de 1er orden  H_k(z) = (1 - z^-1) / (1 - p_k z^-1)
     polos en 20.6, 20.6, 107.7 y 737.9 Hz  (los 4 ceros en DC de la curva A)
  1 biquad de alta frecuencia: polo doble de 12194 Hz + compensacion de la
     caida (droop) del CIC, ajustado por minimos cuadrados.
Coeficientes en Q2.16 (18 bits con signo).
"""
import numpy as np
from scipy.optimize import least_squares

FS   = 25000.0
FIN  = 1.0e6
R, NCIC = 40, 3
FRAC = 16                      # bits fraccionarios de los coeficientes
F1, F2, F3, F4 = 20.598997, 107.65265, 737.86223, 12194.217

def a_analog(f):
    f = np.asarray(f, float); f2 = f*f
    ra = (F4**2*f2**2)/((f2+F1**2)*np.sqrt((f2+F2**2)*(f2+F3**2))*(f2+F4**2))
    return ra/((F4**2*1e6**2)/((1e6+F1**2)*np.sqrt((1e6+F2**2)*(1e6+F3**2))*(1e6+F4**2)))

def cic_mag(f):
    f = np.asarray(f, float)
    x = np.pi*f/FIN
    with np.errstate(invalid='ignore', divide='ignore'):
        h = np.where(f == 0, 1.0, np.sin(R*x)/(R*np.sin(x)))
    return np.abs(h)**NCIC

def q(c):   # cuantiza a Q2.16
    return int(np.round(c*2**FRAC))

def hp1_resp(p, f):
    z = np.exp(1j*2*np.pi*f/FS)
    return (1 - 1/z)/(1 - p/z)

def bq_resp(b, a, f):
    z1 = np.exp(-1j*2*np.pi*f/FS)
    return (b[0]+b[1]*z1+b[2]*z1**2)/(1+a[0]*z1+a[1]*z1**2)

# ---- 4 polos de baja frecuencia: bilineal con pre-warping
pk = []
for fc in (F1, F1, F2, F3):
    K = np.tan(np.pi*fc/FS)
    pk.append((1-K)/(1+K))
pk_q = [q(p) for p in pk]

def hp_chain(f, quant=True):
    h = np.ones_like(f, dtype=complex)
    for p, pq in zip(pk, pk_q):
        h *= hp1_resp(pq/2**FRAC if quant else p, f)
    return h

# ---- biquad de alta frecuencia: ajuste en 300 Hz .. 10 kHz
fg = np.geomspace(300, 10000, 300)
target = a_analog(fg)/(np.abs(hp_chain(fg))*cic_mag(fg))

def resid(v):
    b = v[:3]; a = v[3:]
    return 20*np.log10(np.abs(bq_resp(b, a, fg))) - 20*np.log10(target)

v0 = np.array([0.9, 0.3, 0.05, 0.2, 0.05])
sol = least_squares(resid, v0)
b, a = sol.x[:3], sol.x[3:]
poles = np.roots([1, a[0], a[1]]); zeros = np.roots(b)
# normaliza la cadena completa a 0 dB en 1 kHz (con CIC)
g1k = abs(hp_chain(np.array([1000.0]))[0]*bq_resp(b, a, np.array([1000.0]))[0])*cic_mag(1000.0)
b = b/g1k
bq_q = [q(x) for x in b]; aq_q = [q(x) for x in a]

if __name__ == "__main__":
    print("polos HP (p_k) y Q2.16:")
    for fc, p, pq in zip((F1, F1, F2, F3), pk, pk_q):
        print(f"  fc={fc:9.3f} Hz  p={p:.8f}  q={pq:6d} (0x{pq & 0x3FFFF:05X})")
    print("biquad HF: b =", b, " a =", a)
    print("  |polos| =", np.abs(poles), " ceros =", zeros)
    print("  Q2.16  b =", bq_q, "  a =", aq_q)
    assert all(abs(x) < 2**17 for x in bq_q+aq_q), "coeficiente fuera de Q2.16"

    # ---- error total vs curva A ideal (con coeficientes cuantizados)
    ftab = np.array([10, 20, 31.5, 63, 100, 125, 250, 500, 1000, 2000, 4000, 6300, 8000, 10000, 12000])
    h = hp_chain(ftab)*bq_resp(np.array(bq_q)/2**FRAC, np.array(aq_q)/2**FRAC, ftab)*cic_mag(ftab)
    print("\n  f [Hz]   A ideal   cadena   error")
    for f, hh in zip(ftab, h):
        ai = 20*np.log10(a_analog(f)); ad = 20*np.log10(abs(hh))
        print(f"  {f:7.1f}  {ai:7.2f}  {ad:7.2f}  {ad-ai:+6.2f} dB")

    # ---- justificacion: biquad directo con el polo doble de 20.6 Hz en Q2.16
    p = pk[0]; a1, a2 = -2*p, p*p
    rq = np.roots([1, q(a1)/2**FRAC, q(a2)/2**FRAC])
    print("\nPolo doble 20.6 Hz como UN biquad en Q2.16:")
    print("  polos ideales:", p, p, " -> cuantizados:", rq)
    fq = -np.log(np.abs(rq))*FS/(2*np.pi)
    print("  frecuencias resultantes [Hz]:", fq)
    print("Mismo polo como seccion de 1er orden en Q2.16: p_q =", pk_q[0]/2**FRAC,
          " f =", -np.log(pk_q[0]/2**FRAC)*FS/(2*np.pi), "Hz")
