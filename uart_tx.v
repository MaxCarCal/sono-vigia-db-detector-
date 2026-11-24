`timescale 1ns/1ps
//==============================================================================
// uart_tx.v - Transmisor UART 8N1 (115200 baud por defecto)
//------------------------------------------------------------------------------
// Trama: [start = 0][d0 d1 ... d7][stop = 1], LSB primero.
// CLKS_PER_BIT = 50,000,000 / 115,200 = 434 (error 0.007 %).
//
// Uso: si busy = 0, poner data y dar un pulso en start. busy sube en el
// siguiente flanco y baja al terminar el bit de stop (10 bits = 86.8 us).
// La linea en reposo esta en 1.
//==============================================================================
module uart_tx #(
    parameter integer CLKS_PER_BIT = 434
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy
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

    reg [9:0]    sh;        // {stop, d7..d0, start}
    reg [3:0]    nbit;
    reg [CW-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx   <= 1'b1;
            busy <= 1'b0;
            sh   <= 10'h3FF;
            nbit <= 4'd0;
            cnt  <= {CW{1'b0}};
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                sh   <= {1'b1, data, 1'b0};
                tx   <= 1'b0;                      // bit de start
                busy <= 1'b1;
                nbit <= 4'd0;
                cnt  <= {CW{1'b0}};
            end
        end else begin
            if (cnt == CLKS_PER_BIT - 1) begin
                cnt <= {CW{1'b0}};
                if (nbit == 4'd9) begin            // termino el stop
                    busy <= 1'b0;
                    tx   <= 1'b1;
                end else begin
                    nbit <= nbit + 4'd1;
                    sh   <= sh >> 1;
                    tx   <= sh[1];                 // siguiente bit
                end
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule
