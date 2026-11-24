`timescale 1ns/1ps
//==============================================================================
// peak_hold.v - Nivel maximo (Lmax) desde el ultimo borrado
//------------------------------------------------------------------------------
// En cada nivel nuevo: si es mayor que el maximo guardado, lo reemplaza.
// clear (KEY1) lo regresa a 0. Se muestra con SW[5:4] = 01.
//==============================================================================
module peak_hold (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    input  wire [7:0] level,
    input  wire       clear,
    output reg  [7:0] max_level
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            max_level <= 8'd0;
        else if (clear)
            max_level <= 8'd0;
        else if (in_valid && (level > max_level))
            max_level <= level;
    end

endmodule
