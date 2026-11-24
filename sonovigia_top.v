`timescale 1ns/1ps
//==============================================================================
// sonovigia_top.v - Nivel superior de SonoVigia FPGA (DE10-Lite, 10M50DAF484C7G)
//------------------------------------------------------------------------------
// Cadena de medicion (todo a 50 MHz salvo la interfaz del ADC):
//
//  A0 -> ADC 12b 1MS/s -> adc_if -> cic_dec (/40) -> dc_block -> a_weight_iir
//     -> ms_avg (125 ms / 1 s) -> db_lut -> nivel dB(A)
//        |-> alarm_fsm (limite de tod_clock) -> HEX4, buzzer
//        |-> led_bar (LEDR), disp_ctrl (HEX), peak_hold (Lmax)
//        |-> lvl_log (24 h) + log_uart -> UART (Arduino IO0/IO1)
//
// Controles:
//   KEY0      reset
//   KEY1      SW[5:4]=10 (reloj): suma 1 hora (SW6=0) o 1 minuto (SW6=1)
//             otro modo         : borra Lmax y silencia la alerta actual
//   SW[1:0]   limite: 00 auto dia/noche, 01 dia 55, 10 noche 50, 11 evento 100/4h
//   SW2       respuesta: 0 Fast (125 ms), 1 Slow (1 s)
//   SW3       habilita buzzer
//   SW[5:4]   display: 00 nivel, 01 Lmax, 10 reloj, 11 raw (calibracion)
//   SW6       ajuste de reloj: 0 horas, 1 minutos
//   SW[9:7]   ajuste fino de calibracion, -4..+3 dB (complemento a 2)
//
// Conexiones externas (header Arduino):
//   ARDUINO_IO[0]  RX  <- TX del adaptador USB-serie (3.3 V)
//   ARDUINO_IO[1]  TX  -> RX del adaptador USB-serie
//   ARDUINO_IO[2]  buzzer (via transistor)
//   A0 (ADC_IN0)   microfono + preamplificador (0-5 V, polarizado a 2.5 V)
//
// Simulacion: compilar con la macro SIMULATION para usar adc_model en lugar
// del IP del ADC (Active-HDL: alog +define+SIMULATION ...).
//==============================================================================
module sonovigia_top #(
    parameter integer CAL_DB  = -18,   // calibracion (ver db_lut / README)
    parameter integer HOLD_S  = 3,     // sosten de la alarma, 1..60 s
    parameter [4:0]   ADC_CH  = 5'd1   // A0 = canal 1 del ADC1 (verificar)
)(
    input  wire        ADC_CLK_10,
    input  wire        MAX10_CLK1_50,
    input  wire        MAX10_CLK2_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [9:0]  LEDR,
    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1,
    output wire [7:0]  HEX2,
    output wire [7:0]  HEX3,
    output wire [7:0]  HEX4,
    output wire [7:0]  HEX5,
    inout  wire [15:0] ARDUINO_IO,
    inout  wire        ARDUINO_RESET_N
);

    wire clk = MAX10_CLK1_50;
    localparam [5:0] HOLD6 = HOLD_S;

    //--------------------------------------------------------------------------
    // Reset e interfaz de usuario
    //--------------------------------------------------------------------------
    wire rst_n, rst;
    rst_sync u_rst (.clk(clk), .arst_n(KEY[0]), .rst_n(rst_n), .rst(rst));

    wire [9:0] sw;
    io_sync #(.WIDTH(10), .INIT(10'd0)) u_sw_sync (
        .clk(clk), .rst_n(rst_n), .async_in(SW),
        .sync_out(sw), .rise(), .fall()
    );

    wire key1_press;                         // KEY activo en bajo: presionar = flanco de bajada
    io_sync #(.WIDTH(1), .INIT(1'b1)) u_key_sync (
        .clk(clk), .rst_n(rst_n), .async_in(KEY[1]),
        .sync_out(), .rise(), .fall(key1_press)
    );

    wire [1:0]       mode_sw   = sw[1:0];
    wire             resp_slow = sw[2];
    wire             buzz_en   = sw[3];
    wire [1:0]       disp_sel  = sw[5:4];
    wire             set_min   = sw[6];
    wire signed [3:0] trim     = {sw[9], sw[9:7]};

    wire in_clock_mode = (disp_sel == 2'b10);
    wire inc_hour      = key1_press &&  in_clock_mode && !set_min;
    wire inc_min       = key1_press &&  in_clock_mode &&  set_min;
    wire key_action    = key1_press && !in_clock_mode;   // borra Lmax + silencia

    //--------------------------------------------------------------------------
    // Bases de tiempo
    //--------------------------------------------------------------------------
    wire tick_1hz, tick_4hz;
    tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(1)) u_tick1 (.clk(clk), .rst_n(rst_n), .tick(tick_1hz));
    tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(4)) u_tick4 (.clk(clk), .rst_n(rst_n), .tick(tick_4hz));

    reg blink;                               // 2 Hz para parpadeo
    always @(posedge clk or negedge rst_n)
        if (!rst_n)        blink <= 1'b1;
        else if (tick_4hz) blink <= ~blink;

    //--------------------------------------------------------------------------
    // ADC: IP real (Quartus) o modelo (simulacion)
    //--------------------------------------------------------------------------
    wire        adc_clk;
    wire        r_valid;
    wire [4:0]  r_ch;
    wire [11:0] r_data;
    wire        c_valid, c_sop, c_eop, c_ready;
    wire [4:0]  c_ch;

`ifdef SIMULATION
    adc_model #(.ADC_CH(ADC_CH)) u_adc_model (
        .clk(clk), .resp_valid(r_valid), .resp_channel(r_ch), .resp_data(r_data)
    );
    assign adc_clk = clk;
    assign c_ready = 1'b1;
`else
    // Sistema generado en Platform Designer (ver README). Revisa que los
    // nombres de puertos coincidan con adc_qsys/adc_qsys_inst.v
    adc_qsys u_adc_qsys (
        .clk_clk                              (ADC_CLK_10),
        .reset_reset_n                        (1'b1),
        .modular_adc_0_command_valid          (c_valid),
        .modular_adc_0_command_channel        (c_ch),
        .modular_adc_0_command_startofpacket  (c_sop),
        .modular_adc_0_command_endofpacket    (c_eop),
        .modular_adc_0_command_ready          (c_ready),
        .modular_adc_0_response_valid         (r_valid),
        .modular_adc_0_response_channel       (r_ch),
        .modular_adc_0_response_data          (r_data),
        .modular_adc_0_response_startofpacket (),
        .modular_adc_0_response_endofpacket   (),
        .clock_bridge_sys_out_clk_clk         (adc_clk)
    );
`endif

    wire        s_valid, clip;
    wire [11:0] s_data;
    adc_if #(.ADC_CH(ADC_CH)) u_adc_if (
        .adc_clk(adc_clk), .resp_valid(r_valid), .resp_channel(r_ch), .resp_data(r_data),
        .cmd_valid(c_valid), .cmd_channel(c_ch), .cmd_sop(c_sop), .cmd_eop(c_eop),
        .cmd_ready(c_ready),
        .clk(clk), .rst_n(rst_n), .s_valid(s_valid), .s_data(s_data), .clip(clip)
    );

    //--------------------------------------------------------------------------
    // Procesamiento de senal
    //--------------------------------------------------------------------------
    wire               cic_v, dcb_v, aw_v;
    wire signed [15:0] cic_d, dcb_d;
    wire signed [17:0] aw_d;

    cic_dec      u_cic (.clk(clk), .rst_n(rst_n), .in_valid(s_valid), .in_data(s_data),
                        .out_valid(cic_v), .out_data(cic_d));
    dc_block     u_dcb (.clk(clk), .rst_n(rst_n), .in_valid(cic_v), .in_data(cic_d),
                        .out_valid(dcb_v), .out_data(dcb_d));
    a_weight_iir u_aw  (.clk(clk), .rst_n(rst_n), .in_valid(dcb_v), .in_data(dcb_d),
                        .out_valid(aw_v), .out_data(aw_d));

    wire        blk_valid, sec_flag;
    wire [47:0] fast_sum, slow_sum;
    ms_avg u_ms (.clk(clk), .rst_n(rst_n), .in_valid(aw_v), .in_data(aw_d),
                 .blk_valid(blk_valid), .sec_flag(sec_flag),
                 .fast_sum(fast_sum), .slow_sum(slow_sum));

    // nivel seleccionado (Fast/Slow), cada 125 ms
    wire       sel_done;
    wire [7:0] raw_sel, level_sel;
    db_lut #(.CAL_DB(CAL_DB)) u_db_sel (
        .clk(clk), .rst_n(rst_n), .start(blk_valid),
        .x(resp_slow ? slow_sum : fast_sum), .trim(trim),
        .done(sel_done), .raw(raw_sel), .level(level_sel)
    );

    // LAeq de 1 s (para registro, UART y refresco del display)
    wire       s1_done;
    wire [7:0] raw_1s, level_1s;
    db_lut #(.CAL_DB(CAL_DB)) u_db_1s (
        .clk(clk), .rst_n(rst_n), .start(blk_valid & sec_flag),
        .x(slow_sum), .trim(trim),
        .done(s1_done), .raw(raw_1s), .level(level_1s)
    );

    //--------------------------------------------------------------------------
    // Reloj, limite y alarma
    //--------------------------------------------------------------------------
    wire [4:0] hour;
    wire [5:0] minute, second;
    wire [7:0] limit_db;
    wire [1:0] lim_mode;
    wire       is_night, event_expired;

    tod_clock u_tod (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .inc_hour(inc_hour), .inc_min(inc_min), .mode_sw(mode_sw),
        .hour(hour), .minute(minute), .second(second), .is_night(is_night),
        .limit_db(limit_db), .lim_mode(lim_mode), .event_expired(event_expired)
    );

    wire [1:0] alarm_state;
    wire       alert, pre, alert_start;
    alarm_fsm u_alarm (
        .clk(clk), .rst_n(rst_n), .tick(sel_done),
        .level(level_sel), .limit(limit_db), .hold_s(HOLD6),
        .state(alarm_state), .alert(alert), .pre(pre), .alert_start(alert_start)
    );

    //--------------------------------------------------------------------------
    // Indicadores
    //--------------------------------------------------------------------------
    // display: se refresca 1 vez por segundo con el nivel seleccionado
    reg [7:0] disp_level;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)       disp_level <= 8'd0;
        else if (s1_done) disp_level <= level_sel;

    // sobrecarga: hubo recorte del ADC durante el ultimo segundo
    reg clip_seen, overload;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clip_seen <= 1'b0;
            overload  <= 1'b0;
        end else if (s1_done) begin
            overload  <= clip_seen | clip;
            clip_seen <= 1'b0;
        end else if (clip) begin
            clip_seen <= 1'b1;
        end
    end

    wire [7:0] lmax;
    peak_hold u_peak (.clk(clk), .rst_n(rst_n), .in_valid(sel_done),
                      .level(level_sel), .clear(key_action), .max_level(lmax));

    led_bar #(.MIN_DB(45), .STEP_DB(6)) u_bar (.level(level_sel), .leds(LEDR));

    disp_ctrl u_disp (
        .clk(clk), .rst_n(rst_n), .sel(disp_sel),
        .level(disp_level), .lmax(lmax), .raw(raw_sel),
        .hour(hour), .minute(minute),
        .lim_mode(lim_mode), .alarm_state(alarm_state),
        .overload(overload), .blink(blink),
        .hex0(HEX0), .hex1(HEX1), .hex2(HEX2), .hex3(HEX3), .hex4(HEX4), .hex5(HEX5)
    );

    wire buzz;
    buzzer_ctrl u_buzz (.clk(clk), .rst_n(rst_n), .alert(alert), .enable(buzz_en),
                        .silence(key_action), .buzz(buzz));

    //--------------------------------------------------------------------------
    // Registro de 24 h + UART
    //--------------------------------------------------------------------------
    wire [16:0] log_count, rd_idx;
    wire [7:0]  rd_data;
    lvl_log u_log (.clk(clk), .rst_n(rst_n), .wr_en(s1_done), .wr_data(level_1s),
                   .rd_idx(rd_idx), .rd_data(rd_data), .count(log_count));

    reg [7:0] state_char;
    always @* begin
        case (alarm_state)
            2'd1:    state_char = "P";
            2'd2:    state_char = "A";
            2'd3:    state_char = "C";
            default: state_char = "M";
        endcase
    end

    wire       rx_valid, tx_start, tx_busy, uart_txd;
    wire [7:0] rx_data, tx_data;

    uart_rx u_rx (.clk(clk), .rst_n(rst_n), .rx_in(ARDUINO_IO[0]),
                  .valid(rx_valid), .data(rx_data));

    log_uart u_fmt (
        .clk(clk), .rst_n(rst_n),
        .live_valid(s1_done), .live_level(level_1s), .state_char(state_char),
        .hh(hour), .mm(minute), .ss(second),
        .rx_valid(rx_valid), .rx_data(rx_data),
        .log_count(log_count), .rd_idx(rd_idx), .rd_data(rd_data),
        .tx_start(tx_start), .tx_data(tx_data), .tx_busy(tx_busy)
    );

    uart_tx u_tx (.clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
                  .tx(uart_txd), .busy(tx_busy));

    //--------------------------------------------------------------------------
    // Pines del header Arduino
    //--------------------------------------------------------------------------
    assign ARDUINO_IO[0]     = 1'bz;          // entrada RX
    assign ARDUINO_IO[1]     = uart_txd;
    assign ARDUINO_IO[2]     = buzz;
    assign ARDUINO_IO[15:3]  = 13'bz;
    assign ARDUINO_RESET_N   = 1'bz;

endmodule
