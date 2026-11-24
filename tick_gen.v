`timescale 1ns/1ps
//==============================================================================
// tick_gen.v - Generador de pulsos de habilitacion (tick)
//------------------------------------------------------------------------------
// Divide el reloj de 50 MHz y genera UN pulso de 1 ciclo de clk cada
// DIV = CLK_HZ / TICK_HZ ciclos. NO crea un reloj nuevo: toda la logica sigue
// en el dominio de clk y usa "tick" como habilitacion (enable).
//
// Ejemplos de instancia:
//   tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(1))      u_1hz  (...);
//   tick_gen #(.CLK_HZ(50_000_000), .TICK_HZ(25_000)) u_25k  (...);
//
// Nota: CLK_HZ / TICK_HZ debe ser entero (50 MHz/25 kHz = 2000, exacto).
//==============================================================================
module tick_gen #(
    parameter integer CLK_HZ  = 50_000_000,
    parameter integer TICK_HZ = 1
)(
    input  wire clk,     // 50 MHz (MAX10_CLK1_50)
    input  wire rst_n,   // reset asincrono, activo en bajo
    output reg  tick     // pulso de 1 ciclo cada 1/TICK_HZ segundos
);

    // log2 redondeado hacia arriba (funcion constante, portable en
    // Active-HDL y Quartus sin depender de $clog2)
    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            for (clog2 = 0; v > 0; clog2 = clog2 + 1)
                v = v >> 1;
        end
    endfunction

    localparam integer DIV = CLK_HZ / TICK_HZ;
    localparam integer W   = (DIV > 1) ? clog2(DIV) : 1;   // bits del contador

    reg [W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= {W{1'b0}};
            tick <= 1'b0;
        end else if (cnt == DIV - 1) begin   // llego al final de la cuenta
            cnt  <= {W{1'b0}};
            tick <= 1'b1;                    // pulso de un ciclo
        end else begin
            cnt  <= cnt + 1'b1;
            tick <= 1'b0;
        end
    end

endmodule
