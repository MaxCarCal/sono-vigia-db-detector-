#==============================================================================
# sonovigia.sdc - Restricciones de tiempo para Quartus (TimeQuest)
#==============================================================================
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]
create_clock -name MAX10_CLK2_50 -period 20.000 [get_ports {MAX10_CLK2_50}]
create_clock -name ADC_CLK_10    -period 100.000 [get_ports {ADC_CLK_10}]

# Relojes del PLL dentro del sistema del ADC (Platform Designer)
derive_pll_clocks
derive_clock_uncertainty

# Cruce de dominio ADC -> 50 MHz (toggle synchronizer en adc_if):
#  - el primer flip-flop del sincronizador
#  - el dato retenido (estable ~1 us antes de copiarse)
set_false_path -to   [get_registers {*u_adc_if|tog_s1}]
set_false_path -from [get_registers {*u_adc_if|hold_data*}] -to [get_registers {*u_adc_if|s_data*}]
set_false_path -from [get_registers {*u_adc_if|hold_data*}] -to [get_registers {*u_adc_if|clip}]

# Entradas/salidas lentas (switches, botones, LEDs, displays, UART, buzzer)
set_false_path -from [get_ports {KEY[*] SW[*] ARDUINO_IO[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] ARDUINO_IO[*]}]
