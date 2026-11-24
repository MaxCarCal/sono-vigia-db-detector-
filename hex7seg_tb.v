`timescale 1ns/1ps
//==============================================================================
// hex7seg_tb.v - Testbench autoverificable de hex7seg
// Compara las 16 combinaciones contra una tabla ACTIVO-ALTO escrita de forma
// independiente (se invierte con ~ para comparar) y prueba la entrada blank.
//==============================================================================
module hex7seg_tb;

    reg  [3:0] digit;
    reg        blank;
    wire [6:0] seg;

    reg  [6:0] expected_hi [0:15];   // {g,f,e,d,c,b,a}, 1 = segmento encendido
    integer i;
    integer errors = 0;

    hex7seg dut (.digit(digit), .blank(blank), .seg(seg));

    initial begin
        //                   gfedcba
        expected_hi[0]  = 7'b0111111;
        expected_hi[1]  = 7'b0000110;
        expected_hi[2]  = 7'b1011011;
        expected_hi[3]  = 7'b1001111;
        expected_hi[4]  = 7'b1100110;
        expected_hi[5]  = 7'b1101101;
        expected_hi[6]  = 7'b1111101;
        expected_hi[7]  = 7'b0000111;
        expected_hi[8]  = 7'b1111111;
        expected_hi[9]  = 7'b1101111;
        expected_hi[10] = 7'b1110111;   // A
        expected_hi[11] = 7'b1111100;   // b
        expected_hi[12] = 7'b0111001;   // C
        expected_hi[13] = 7'b1011110;   // d
        expected_hi[14] = 7'b1111001;   // E
        expected_hi[15] = 7'b1110001;   // F

        blank = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            digit = i[3:0];
            #10;
            if (seg !== ~expected_hi[i]) begin
                errors = errors + 1;
                $display("ERROR digito %h: seg=%b esperado=%b", i[3:0], seg, ~expected_hi[i]);
            end
        end

        // blank apaga el digito sin importar el valor
        blank = 1'b1;
        for (i = 0; i < 16; i = i + 1) begin
            digit = i[3:0];
            #10;
            if (seg !== 7'b111_1111) begin
                errors = errors + 1;
                $display("ERROR blank con digito %h: seg=%b", i[3:0], seg);
            end
        end

        if (errors == 0) $display("hex7seg_tb: PASS");
        else             $display("hex7seg_tb: FAIL (%0d errores)", errors);
        $finish;
    end

endmodule
