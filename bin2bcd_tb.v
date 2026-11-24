`timescale 1ns/1ps
//==============================================================================
// bin2bcd_tb.v - Testbench autoverificable de bin2bcd
// Prueba exhaustiva: los 256 valores de entrada, comparados contra los
// operadores / y % (que solo se usan en simulacion, no en el hardware).
//==============================================================================
module bin2bcd_tb;

    reg  [7:0] bin;
    wire [3:0] hundreds, tens, ones;

    integer i;
    integer errors = 0;

    bin2bcd dut (.bin(bin), .hundreds(hundreds), .tens(tens), .ones(ones));

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            bin = i[7:0];
            #10;
            if (hundreds !== (i / 100) ||
                tens     !== ((i / 10) % 10) ||
                ones     !== (i % 10)) begin
                errors = errors + 1;
                $display("ERROR bin=%0d: obtenido %0d%0d%0d", i, hundreds, tens, ones);
            end
        end

        if (errors == 0) $display("bin2bcd_tb: PASS (256 valores)");
        else             $display("bin2bcd_tb: FAIL (%0d errores)", errors);
        $finish;
    end

endmodule
