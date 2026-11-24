`timescale 1ns/1ps
//==============================================================================
// uart_rx.v - Receptor UART 8N1 (para comandos desde la PC, p. ej. 'D')
//------------------------------------------------------------------------------
//   1) La entrada pasa por 2 FF (es asincrona).
//   2) En reposo (1) espera un 0 = posible bit de start.
//   3) Espera MEDIO bit y verifica que siga en 0 (filtra pulsos de ruido).
//   4) Muestrea 8 bits, cada uno a la mitad de su duracion (LSB primero).
//   5) Verifica el stop (1) y da un pulso valid con el byte.
//==============================================================================
module uart_rx #(
    parameter integer CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    output reg        valid,
    output reg  [7:0] data
);

    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam integer CW = clog2(CLKS_PER_BIT);
    localparam [1:0] S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg          rx_s1, rx_s2;
    reg [1:0]    state;
    reg [CW-1:0] cnt;
    reg [2:0]    nbit;
    reg [7:0]    sh;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s1 <= 1'b1; rx_s2 <= 1'b1;
            state <= S_IDLE; cnt <= {CW{1'b0}}; nbit <= 3'd0;
            sh <= 8'd0; valid <= 1'b0; data <= 8'd0;
        end else begin
            rx_s1 <= rx_in;
            rx_s2 <= rx_s1;
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    cnt <= {CW{1'b0}};
                    if (!rx_s2)
                        state <= S_START;
                end
                S_START: begin
                    if (cnt == (CLKS_PER_BIT / 2) - 1) begin
                        cnt  <= {CW{1'b0}};
                        nbit <= 3'd0;
                        state <= rx_s2 ? S_IDLE : S_DATA;   // start falso
                    end else
                        cnt <= cnt + 1'b1;
                end
                S_DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt <= {CW{1'b0}};
                        sh  <= {rx_s2, sh[7:1]};
                        if (nbit == 3'd7)
                            state <= S_STOP;
                        else
                            nbit <= nbit + 3'd1;
                    end else
                        cnt <= cnt + 1'b1;
                end
                S_STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= {CW{1'b0}};
                        state <= S_IDLE;
                        if (rx_s2) begin
                            valid <= 1'b1;
                            data  <= sh;
                        end
                    end else
                        cnt <= cnt + 1'b1;
                end
            endcase
        end
    end

endmodule
