# SonoVigía FPGA — RTL completo (DE10-Lite, 10M50DAF484C7G)

## Estructura

```
rtl/      23 módulos Verilog (sintetizables, salvo adc_model.v)
tb/       19 testbenches autoverificables (imprimen PASS / FAIL)
model/    modelo Python bit-exacto + generadores (coeficientes, ROM, TBs, pines)
quartus/  sonovigia.sdc (tiempos) y sonovigia_pins.tcl (pines del manual)
```

## Cadena y módulos

```
A0 → ADC 12b 1 MS/s → adc_if → cic_dec ÷40 → dc_block → a_weight_iir → ms_avg → db_lut ─┬→ alarm_fsm → HEX4 / buzzer_ctrl
                                                                                         ├→ led_bar (LEDR), disp_ctrl (HEX), peak_hold
                                                                                         └→ lvl_log (24 h) → log_uart → uart_tx (IO1)
tick_gen → tod_clock (hora + límite 55/50/100)        uart_rx (IO0) → comando 'D' (descarga)
```

| Módulo | Función |
|---|---|
| `rst_sync` | Reset de KEY0: entra asíncrono, sale sincronizado |
| `adc_if` | Comando continuo al IP del ADC + cruce de dominio (toggle sync) + detector de recorte |
| `adc_model` | **Solo simulación**: senoidal configurable en lugar del IP |
| `cic_dec` | CIC 3 etapas ÷40 (28 bits internos, salida 16 bits, ganancia 15.625) |
| `dc_block` | Pasa-altas de 1 polo, fc = 9.7 Hz, sin multiplicador |
| `a_weight_iir` | Ponderación A, orden 6, **un multiplicador compartido** (FSM de 15 ciclos) |
| `ms_avg` | Σy² por bloque de 125 ms (Fast) y suma móvil de 1 s (Slow) |
| `db_lut` | Σy² → dB por búsqueda binaria en ROM + calibración |
| `tod_clock` | Reloj HH:MM:SS, límite día/noche/evento (4 h) |
| `alarm_fsm` | Moore: MONITOR → PRE → ALERTA → COOLDOWN, sostén configurable |
| `peak_hold` | Lmax |
| `disp_ctrl` | 6 displays (usa `hex7seg` y `bin2bcd`) |
| `lvl_log` | Anillo de 86,400 × 8 bits en M9K (24 h de niveles de 1 s) |
| `uart_tx`, `uart_rx`, `log_uart` | Línea CSV por segundo y descarga del registro |
| `buzzer_ctrl` | Pitido 0.5 s / 0.5 s en ALERTA, silenciable |
| `sonovigia_top` | Nivel superior con nombres de puertos del System Builder |

## Controles

| Control | Función |
|---|---|
| KEY0 | Reset |
| KEY1 | En modo reloj: +1 hora (SW6 = 0) o +1 minuto (SW6 = 1). En otro modo: borra Lmax y silencia la alerta |
| SW[1:0] | 00 auto día/noche · 01 día (55) · 10 noche (50) · 11 evento (100 dB, 4 h) |
| SW2 | 0 Fast (125 ms) · 1 Slow (1 s) |
| SW3 | Habilita buzzer |
| SW[5:4] | Display: 00 nivel · 01 Lmax · 10 reloj · 11 raw (calibración) |
| SW[9:7] | Ajuste fino de calibración −4…+3 dB |

Displays: **HEX5** límite (`d`/`n`/`E`), **HEX4** alarma (`-`/`P`/`A` parpadeando/`C`), **HEX3** `o` = ADC saturado, **HEX2–0** valor.

## Simulación en Active-HDL

1. Crea un diseño nuevo y agrega todos los archivos de `rtl/` y `tb/`.
2. Define la macro `SIMULATION` (Design Settings → Verilog → Macros, o `alog +define+SIMULATION`). Sin ella, `sonovigia_top` busca el IP real `adc_qsys`.
3. Compila todo y simula cada testbench:
   ```
   alog -dbg +define+SIMULATION rtl/*.v tb/*.v
   asim +access +r cic_dec_tb
   run -all
   ```
4. Orden sugerido: `tick_gen` … `led_bar` → `cic_dec` → `dc_block` → `a_weight_iir` → `ms_avg` → `db_lut` → `adc_if` → `tod_clock` → `alarm_fsm` → `disp_ctrl` → `lvl_log` → `uart_loop` → `log_uart` → `buzzer_ctrl` → `sonovigia_top`.
5. `sonovigia_top_tb` simula 1.3 s (≈65 M ciclos) y puede tardar minutos. Define también `QUICK` para detenerlo en 0.4 s.

Los TB de `cic_dec`, `dc_block`, `a_weight_iir`, `ms_avg` y `db_lut` los genera `model/gen_golden_tb.py` y comparan **bit a bit** contra el modelo Python. Si alguno falla, anota la primera línea de `ERROR`.

## Implementación en Quartus

1. **IP del ADC (lo más seguro):** copia `adc_qsys.qsys` del demo `Demonstrations/ADC_RTL` del System CD de la DE10-Lite, que ya está probado en esta tarjeta. Ábrelo en Platform Designer, confirma el modo *ADC control core only* con el canal 1 habilitado y genera el HDL. Agrega `adc_qsys/synthesis/adc_qsys.qip` al proyecto.
2. **Revisa los nombres de puertos** del IP en `adc_qsys_inst.v` y, si difieren, ajusta la instancia en `sonovigia_top.v`. También confirma con el demo que Arduino A0 es el canal 1 (`ADC_CH`).
3. Agrega `rtl/*.v` **excepto `adc_model.v`**, más `quartus/sonovigia.sdc`. Ejecuta `quartus/sonovigia_pins.tcl` (Tools → Tcl Scripts). Ese script define el dispositivo, el top, el SDC y los 90 pines con su estándar de E/S.
4. Compila y revisa:
   - TimeQuest sin violaciones a 50 MHz;
   - unos 87 de 182 bloques M9K para el registro;
   - 2 multiplicadores 18×18.
5. Con Signal Tap, verifica que `u_adc_if/s_valid` llegue a ~1 MHz. Si la tasa real difiere, la curva A se desplaza en frecuencia.

## Calibración (un punto)

1. Pon SW[5:4] = 11 (raw) y SW2 = 1 (Slow).
2. Aplica una referencia: un calibrador de 94 dB a 1 kHz, o ruido estable medido al lado con un sonómetro Clase 2.
3. Calcula `CAL_DB = L_referencia − raw` y ponlo como parámetro de `sonovigia_top`. SW[9:7] da ±4 dB de ajuste fino sin recompilar.
4. Ajusta la ganancia del preamplificador de modo que el ruido más fuerte esperado no encienda la `o` de sobrecarga.

Con `CAL_DB = −18` (valor por defecto), un tono de 1 kHz a escala completa del ADC se lee como 110 dB.

## UART

Usa un adaptador USB-serie de **3.3 V**:
- TX del adaptador → Arduino IO0;
- RX del adaptador → IO1;
- GND común.

Configura 115200 8N1.
- Cada segundo llega una línea `HH:MM:SS,LLL,S`.
- Al enviar `D` se descarga el registro (`LLL` por línea, del más viejo al más nuevo) y termina con `END`. Las 24 h tardan ≈37 s.

## Resultados del modelo (`model/eval_chain.py`)

| Prueba | Resultado |
|---|---|
| Linealidad a 1 kHz, 0 a −60 dBFS | error ≤ +0.18 dB (redondeo a 1 dB) |
| Curva A, 31.5 Hz–10 kHz (incluye CIC y DC-block) | ≤ 0.4 dB (31.5 Hz); ≤ 0.04 dB desde 125 Hz |
| Piso de ruido (ruido de ADC σ = 1 LSB) | raw ≈ 49, frente a 128 a escala completa (≈79 dB de rango) |
| Máximo interno (tono a escala completa) | 79,824 de 131,071 (sin saturar) |

## Diferencias respecto al reporte (para actualizarlo)

| Reporte | Implementación | Motivo |
|---|---|---|
| 3 biquads Q1.17 | 4 secciones de 1er orden + 1 biquad, Q2.16 | Mismo orden 6, 9 multiplicaciones por muestra en lugar de 15; error de polo lineal; b0 = 1.31 > 1 requiere Q2.x |
| Acumulador de 40 bits | 48 bits | 3125 × y² necesita 46 bits |
| 1 multiplicador | 2 (filtro + cuadrado) | Simplicidad; son 2 de 144 |
| Slow = 1 s | Suma móvil de 8 bloques de 125 ms | Se actualiza cada 125 ms; en cada segundo exacto es el LAeq,1s |
| — | Compensación de la caída del CIC en el biquad | Error < 0.02 dB hasta 10 kHz |
