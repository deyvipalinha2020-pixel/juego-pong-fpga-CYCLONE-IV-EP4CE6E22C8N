module seg7(
    input clk,
    input [3:0] score_l, score_r,
    output reg [7:0] sseg,
    output reg [3:0] sel
    );

    reg [17:0] q_reg; 
    always @(posedge clk) q_reg <= q_reg + 1;

    reg [3:0] num;

    always @(*) begin
        case (q_reg[17:16])
            2'b00: begin 
                sel = 4'b0111; // Display 1 (Extremo Izquierdo)
                num = score_l / 10; // Decenas Jugador Verde
            end
            2'b01: begin 
                sel = 4'b1011; // Display 2 
                num = score_l % 10; // Unidades Jugador Verde
            end
            2'b10: begin 
                sel = 4'b1101; // Display 3
                num = score_r / 10; // Decenas Jugador Rojo
            end
            2'b11: begin 
                sel = 4'b1110; // Display 4 (Extremo Derecho)
                num = score_r % 10; // Unidades Jugador Rojo
            end
        endcase
    end

    // Decodificador de 7 segmentos (Cátodo Común)
    always @(*) begin
        case (num)
            4'h0: sseg = 8'hc0; 4'h1: sseg = 8'hf9; 4'h2: sseg = 8'ha4;
            4'h3: sseg = 8'hb0; 4'h4: sseg = 8'h99; 4'h5: sseg = 8'h92;
            4'h6: sseg = 8'h82; 4'h7: sseg = 8'hf8; 4'h8: sseg = 8'h80;
            4'h9: sseg = 8'h90; default: sseg = 8'hff;
        endcase
    end
endmodule