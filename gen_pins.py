"""gen_pins.py - asignaciones de pines DE10-Lite (tablas 3-2..3-8 del manual)."""
LV = "3.3-V LVTTL"; ST = "3.3 V SCHMITT TRIGGER"
pins = [("ADC_CLK_10","PIN_N5",LV),("MAX10_CLK1_50","PIN_P11",LV),("MAX10_CLK2_50","PIN_N14",LV),
        ("KEY[0]","PIN_B8",ST),("KEY[1]","PIN_A7",ST)]
sw = ["C10","C11","D12","C12","A12","B12","A13","A14","B14","F15"]
pins += [(f"SW[{i}]", "PIN_"+p, LV) for i, p in enumerate(sw)]
led = ["A8","A9","A10","B10","D13","C13","E14","D14","A11","B11"]
pins += [(f"LEDR[{i}]", "PIN_"+p, LV) for i, p in enumerate(led)]
hexp = {0:["C14","E15","C15","C16","E16","D17","C17","D15"],
        1:["C18","D18","E18","B16","A17","A18","B17","A16"],
        2:["B20","A20","B19","A21","B21","C22","B22","A19"],
        3:["F21","E22","E21","C19","C20","D19","E17","D22"],
        4:["F18","E20","E19","J18","H19","F19","F20","F17"],
        5:["J20","K20","L18","N18","M20","N19","N20","L19"]}
for d, ps in hexp.items():
    pins += [(f"HEX{d}[{i}]", "PIN_"+p, LV) for i, p in enumerate(ps)]
ard = ["AB5","AB6","AB7","AB8","AB9","Y10","AA11","AA12","AB17","AA17","AB19","AA19","Y19","AB20","AB21","AA20"]
pins += [(f"ARDUINO_IO[{i}]", "PIN_"+p, LV) for i, p in enumerate(ard)]
pins += [("ARDUINO_RESET_N", "PIN_F16", ST)]
assert len(set(p for _, p, _ in pins)) == len(pins), "pin repetido"
out = ["# sonovigia_pins.tcl - generado por model/gen_pins.py desde el manual DE10-Lite",
       "# Uso en Quartus: Tools > Tcl Scripts > Run  (o: source sonovigia_pins.tcl)",
       'set_global_assignment -name FAMILY "MAX 10"',
       "set_global_assignment -name DEVICE 10M50DAF484C7G",
       "set_global_assignment -name TOP_LEVEL_ENTITY sonovigia_top",
       "set_global_assignment -name SDC_FILE sonovigia.sdc", ""]
for s, p, io in pins:
    out.append(f"set_location_assignment {p} -to {s}")
    out.append(f'set_instance_assignment -name IO_STANDARD "{io}" -to {s}')
open("../quartus/sonovigia_pins.tcl", "w").write("\n".join(out) + "\n")
print(len(pins), "pines")
