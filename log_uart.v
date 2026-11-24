`timescale 1ns/1ps
//==============================================================================
// log_uart.v - Formatea y envia por UART el nivel en vivo y el registro de 24 h
//------------------------------------------------------------------------------
// Texto ASCII (CSV), facil de capturar con cualquier terminal serie
// (PuTTY, Arduino Serial Monitor, Python) a 115200 8N1:
//
//  EN VIVO (cada segundo):  "HH:MM:SS,LLL,S\r\n"     (16 caracteres)
//       LLL = LAeq de 1 s en dB, S = estado (M monitor, P pre, A alerta,
//       C cooldown)
//
//  DESCARGA (al recibir 'D' o 'd' desde la PC):
//       "LLL\r\n" por cada segundo guardado, del mas viejo al mas nuevo,
//       y al final "END\r\n". 86,400 lineas x 5 bytes = ~37 s a 115200.
//       Durante la descarga se pausan las lineas en vivo (el registro sigue
//       grabando).
//
// Maquina de estados de envio de caracteres:
//   CHAR : espera tx_busy = 0, pone el caracter y da un pulso tx_start
//   GAP  : 1 ciclo para que uart_tx levante busy
//   NEXT : siguiente posicion / siguiente linea
//   FETCH1..3 : pide al registro el dato rd_idx y espera la RAM (2 ciclos)
//==============================================================================
module log_uart (
    input  wire        clk,
    input  wire        rst_n,
    // linea en vivo
    input  wire        live_valid,
    input  wire [7:0]  live_level,
    input  wire [7:0]  state_char,     // ASCII: "M", "P", "A" o "C"
    input  wire [4:0]  hh,
    input  wire [5:0]  mm,
    input  wire [5:0]  ss,
    // comandos desde la PC
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    // registro de niveles
    input  wire [16:0] log_count,
    output reg  [16:0] rd_idx,
    input  wire [7:0]  rd_data,
    // transmisor
    output reg         tx_start,
    output reg  [7:0]  tx_data,
    input  wire        tx_busy
);

    localparam [2:0] S_IDLE = 3'd0, S_CHAR = 3'd1, S_GAP = 3'd2, S_NEXT = 3'd3,
                     S_F1   = 3'd4, S_F2   = 3'd5, S_F3  = 3'd6;
    localparam [1:0] M_LIVE = 2'd0, M_ENTRY = 2'd1, M_END = 2'd2;

    reg [2:0]  state;
    reg [1:0]  mode;
    reg [3:0]  pos;
    reg        live_pend, dump_req;
    reg [16:0] n_dump;

    // instantaneas (no cambian a mitad de una linea)
    reg [7:0] s_lvl, s_st;
    reg [4:0] s_hh;
    reg [5:0] s_mm, s_ss;

    // ---- digitos decimales
    wire [3:0] l_h, l_t, l_o, h_t, h_o, m_t, m_o, x_t, x_o, nu1, nu2, nu3;
    bin2bcd u_b_lvl (.bin(s_lvl),            .hundreds(l_h), .tens(l_t), .ones(l_o));
    bin2bcd u_b_hh  (.bin({3'b000, s_hh}),   .hundreds(nu1), .tens(h_t), .ones(h_o));
    bin2bcd u_b_mm  (.bin({2'b00, s_mm}),    .hundreds(nu2), .tens(m_t), .ones(m_o));
    bin2bcd u_b_ss  (.bin({2'b00, s_ss}),    .hundreds(nu3), .tens(x_t), .ones(x_o));

    function [7:0] asc;                 // digito -> ASCII
        input [3:0] d;
        asc = 8'h30 + {4'h0, d};
    endfunction

    // ---- caracter a enviar segun modo y posicion
    reg [7:0] ch;
    reg [3:0] last_pos;
    always @* begin
        ch = 8'h3F;                     // '?'
        last_pos = 4'd4;
        case (mode)
            M_LIVE: begin
                last_pos = 4'd15;
                case (pos)
                    4'd0:  ch = asc(h_t);
                    4'd1:  ch = asc(h_o);
                    4'd2:  ch = ":";
                    4'd3:  ch = asc(m_t);
                    4'd4:  ch = asc(m_o);
                    4'd5:  ch = ":";
                    4'd6:  ch = asc(x_t);
                    4'd7:  ch = asc(x_o);
                    4'd8:  ch = ",";
                    4'd9:  ch = asc(l_h);
                    4'd10: ch = asc(l_t);
                    4'd11: ch = asc(l_o);
                    4'd12: ch = ",";
                    4'd13: ch = s_st;
                    4'd14: ch = 8'h0D;
                    default: ch = 8'h0A;
                endcase
            end
            M_ENTRY: begin
                case (pos)
                    4'd0:  ch = asc(l_h);
                    4'd1:  ch = asc(l_t);
                    4'd2:  ch = asc(l_o);
                    4'd3:  ch = 8'h0D;
                    default: ch = 8'h0A;
                endcase
            end
            default: begin              // M_END: "END\r\n"
                case (pos)
                    4'd0:  ch = "E";
                    4'd1:  ch = "N";
                    4'd2:  ch = "D";
                    4'd3:  ch = 8'h0D;
                    default: ch = 8'h0A;
                endcase
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; mode <= M_LIVE; pos <= 4'd0;
            live_pend <= 1'b0; dump_req <= 1'b0; n_dump <= 17'd0;
            rd_idx <= 17'd0; tx_start <= 1'b0; tx_data <= 8'h00;
            s_lvl <= 8'd0; s_st <= "M"; s_hh <= 5'd0; s_mm <= 6'd0; s_ss <= 6'd0;
        end else begin
            tx_start <= 1'b0;

            if (live_valid)
                live_pend <= 1'b1;
            if (rx_valid && (rx_data == "D" || rx_data == "d"))
                dump_req <= 1'b1;

            case (state)
                S_IDLE: begin
                    if (dump_req) begin
                        dump_req  <= 1'b0;
                        live_pend <= 1'b0;
                        n_dump    <= log_count;
                        rd_idx    <= 17'd0;
                        pos       <= 4'd0;
                        if (log_count == 17'd0) begin
                            mode  <= M_END;
                            state <= S_CHAR;
                        end else begin
                            state <= S_F1;
                        end
                    end else if (live_pend) begin
                        live_pend <= 1'b0;
                        s_lvl <= live_level; s_st <= state_char;
                        s_hh  <= hh; s_mm <= mm; s_ss <= ss;
                        mode  <= M_LIVE;
                        pos   <= 4'd0;
                        state <= S_CHAR;
                    end
                end

                // ---- lectura del registro (rd_idx ya puesto)
                S_F1: state <= S_F2;            // rd_addr se calcula
                S_F2: state <= S_F3;            // la RAM entrega rd_data
                S_F3: begin
                    s_lvl <= rd_data;
                    mode  <= M_ENTRY;
                    pos   <= 4'd0;
                    state <= S_CHAR;
                end

                // ---- envio de un caracter
                S_CHAR: begin
                    if (!tx_busy) begin
                        tx_data  <= ch;
                        tx_start <= 1'b1;
                        state    <= S_GAP;
                    end
                end
                S_GAP: state <= S_NEXT;

                S_NEXT: begin
                    if (pos != last_pos) begin
                        pos   <= pos + 4'd1;
                        state <= S_CHAR;
                    end else begin
                        pos <= 4'd0;
                        case (mode)
                            M_ENTRY: begin
                                if (rd_idx == n_dump - 17'd1) begin
                                    mode  <= M_END;
                                    state <= S_CHAR;
                                end else begin
                                    rd_idx <= rd_idx + 17'd1;
                                    state  <= S_F1;
                                end
                            end
                            M_END: begin
                                live_pend <= 1'b0;   // descarta linea vieja
                                state     <= S_IDLE;
                            end
                            default: state <= S_IDLE;
                        endcase
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
