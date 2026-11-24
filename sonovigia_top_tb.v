`timescale 1ns/1ps
//==============================================================================
// sonovigia_top_tb.v - Prueba de sistema completo (requiere la macro SIMULATION)
//
// adc_model genera 1 kHz con amplitud 200 cuentas (-20 dBFS):
//   raw esperado = round(10*log10((200*31.25)^2/2 * 3125)) = 108
//   nivel        = 108 + CAL_DB(-18) = 90 dB
// Limite de dia (12:00) = 55 -> la alarma pasa a PRE y, con HOLD_S = 1,
// a ALERTA despues de 1 s sobre el limite.
//
// Puntos de verificacion:
//   0.40 s : nivel Fast (u_dut.level_sel) = 90 +-1, LEDR = 0011111111, estado PRE
//   ~1.0 s : linea UART "hh:mm:ss,090,P"
//   1.30 s : display "  90" con 'd' en HEX5, estado ALERTA
//
// OJO: son ~65 millones de ciclos; en Active-HDL puede tardar varios minutos.
// Define QUICK para detenerse despues del primer punto (0.4 s).
//==============================================================================
module sonovigia_top_tb;
    reg  clk50 = 1'b0, clk10 = 1'b0;
    reg  [1:0] key = 2'b10;               // KEY0 presionado = reset
    reg  [9:0] sw  = 10'd0;               // auto, Fast, sin buzzer, display de nivel
    wire [9:0] ledr;
    wire [7:0] hex0, hex1, hex2, hex3, hex4, hex5;
    wire [15:0] ard;
    wire ard_rst;
    wire pc_valid;
    wire [7:0] pc_byte;
    reg  [7:0] line [0:15];
    integer nchar = 0, errors = 0, lines = 0;

    assign ard[0] = 1'b1;                 // RX de la FPGA en reposo

    sonovigia_top #(.CAL_DB(-18), .HOLD_S(1)) u_dut (
        .ADC_CLK_10(clk10), .MAX10_CLK1_50(clk50), .MAX10_CLK2_50(clk50),
        .KEY(key), .SW(sw), .LEDR(ledr),
        .HEX0(hex0), .HEX1(hex1), .HEX2(hex2), .HEX3(hex3), .HEX4(hex4), .HEX5(hex5),
        .ARDUINO_IO(ard), .ARDUINO_RESET_N(ard_rst));

    always #10 clk50 = ~clk50;
    always #50 clk10 = ~clk10;

    // "PC": decodifica lo que sale por ARDUINO_IO[1]
    uart_rx #(.CLKS_PER_BIT(434)) u_pc (.clk(clk50), .rst_n(1'b1), .rx_in(ard[1]),
                                        .valid(pc_valid), .data(pc_byte));
    always @(posedge clk50) if (pc_valid) begin
        if (nchar < 16) line[nchar] = pc_byte;
        nchar = nchar + 1;
        if (pc_byte == 8'h0A) begin
            $display("[%0t ns] UART: %c%c:%c%c:%c%c,%c%c%c,%c", $time,
                     line[0], line[1], line[3], line[4], line[6], line[7],
                     line[9], line[10], line[11], line[13]);
            if (lines == 0 && (line[9] != "0" || line[10] != "9" || line[11] != "0" || line[13] != "P")) begin
                errors = errors + 1;
                $display("ERROR: se esperaba nivel 090 y estado P");
            end
            lines = lines + 1;
            nchar = 0;
        end
    end

    initial begin
        #1000 key[0] = 1'b1;                       // suelta el reset

        #(400_000_000);                            // 0.4 s
        $display("[0.4 s] level_sel=%0d raw=%0d LEDR=%b estado=%0d",
                 u_dut.level_sel, u_dut.raw_sel, ledr, u_dut.alarm_state);
        if (u_dut.level_sel < 89 || u_dut.level_sel > 91) begin
            errors = errors + 1; $display("ERROR: nivel fuera de 90 +-1");
        end
        if (ledr !== 10'b0011111111) begin errors = errors + 1; $display("ERROR: LEDR"); end
        if (u_dut.alarm_state !== 2'd1) begin errors = errors + 1; $display("ERROR: se esperaba PRE"); end
`ifndef QUICK
        #(900_000_000);                            // 1.3 s
        $display("[1.3 s] HEX5..0 = %h %h %h %h %h %h  estado=%0d  lineas UART=%0d",
                 hex5, hex4, hex3, hex2, hex1, hex0, u_dut.alarm_state, lines);
        if (hex5 !== 8'hA1 || hex3 !== 8'hFF || hex2 !== 8'hFF || hex1 !== 8'h90 || hex0 !== 8'hC0) begin
            errors = errors + 1; $display("ERROR: display (esperado d ? _ _ 9 0)");
        end
        if (u_dut.alarm_state !== 2'd2) begin errors = errors + 1; $display("ERROR: se esperaba ALERTA"); end
        if (lines < 1) begin errors = errors + 1; $display("ERROR: no llego ninguna linea UART"); end
`endif
        if (errors == 0) $display("sonovigia_top_tb: PASS");
        else             $display("sonovigia_top_tb: FAIL (%0d errores)", errors);
        $finish;
    end
endmodule
