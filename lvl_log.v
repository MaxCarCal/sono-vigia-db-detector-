`timescale 1ns/1ps
//==============================================================================
// lvl_log.v - Registro de evidencia: buffer circular de niveles de 1 s en M9K
//------------------------------------------------------------------------------
// Guarda 1 byte (nivel en dB) por segundo. DEPTH = 86,400 = 24 h.
//   86,400 x 8 bits = 691 kbit (~42 % de los 1,638 kbit de M9K del 10M50).
// Cuando se llena, el dato nuevo sobrescribe al mas viejo (anillo).
// PRIVACIDAD: aqui solo entra el nivel de 1 s; el audio nunca se almacena.
//
// Lectura por indice relativo: rd_idx = 0 es el dato MAS VIEJO.
//   base    = (lleno) ? wr_ptr : 0
//   rd_addr = (base + rd_idx) mod DEPTH
// rd_data sale 1 ciclo despues de que rd_idx es estable (RAM registrada).
// Quartus infiere una RAM de doble puerto simple (1 escritura + 1 lectura).
//==============================================================================
module lvl_log #(
    parameter integer DEPTH = 86400,
    parameter integer AW    = 17          // bits de direccion: 2^17 > 86,400
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          wr_en,           // 1 pulso por segundo
    input  wire [7:0]    wr_data,
    input  wire [AW-1:0] rd_idx,          // 0 = mas viejo
    output reg  [7:0]    rd_data,
    output reg  [AW-1:0] count            // datos validos (0..DEPTH)
);

    reg [7:0]    mem [0:DEPTH-1];
    reg [AW-1:0] wr_ptr;

    wire          full    = (count == DEPTH);
    wire [AW-1:0] base    = full ? wr_ptr : {AW{1'b0}};
    wire [AW:0]   sum     = {1'b0, base} + {1'b0, rd_idx};
    wire [AW-1:0] rd_addr = (sum >= DEPTH) ? (sum - DEPTH) : sum[AW-1:0];

    // ---- RAM (sin reset: asi Quartus la mapea a bloques M9K)
    always @(posedge clk) begin
        if (wr_en)
            mem[wr_ptr] <= wr_data;
        rd_data <= mem[rd_addr];
    end

    // ---- punteros
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {AW{1'b0}};
            count  <= {AW{1'b0}};
        end else if (wr_en) begin
            wr_ptr <= (wr_ptr == DEPTH - 1) ? {AW{1'b0}} : wr_ptr + 1'b1;
            if (!full)
                count <= count + 1'b1;
        end
    end

endmodule
