module vga_controller (
    input clk_25,           // Reloj de 25MHz que viene del módulo reloj_vga
    output reg hsync,       // Sincronismo Horizontal (Sin guion bajo para el Pin Planner)
    output reg vsync,       // Sincronismo Vertical (Sin guion bajo para el Pin Planner)
    output reg video_on,    // Indica si estamos dentro del área visible (640x480)
    output [9:0] x_pos,     // Coordenada X actual
    output [9:0] y_pos      // Coordenada Y actual
);

    // Contadores de posición
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    // 1. Manejo de los contadores (Estándar 640x480 @ 60Hz)
    always @(posedge clk_25) begin
        if (h_count < 799) begin
            h_count <= h_count + 1;
        end else begin
            h_count <= 0;
            if (v_count < 524) begin
                v_count <= v_count + 1;
            end else begin
                v_count <= 0;
            end
        end
    end

    // 2. Generación de señales de sincronía (Polaridad Negativa)
    // El monitor espera un '0' durante el pulso de sincronismo
    always @(posedge clk_25) begin
        // Horizontal: Sync ocurre entre 656 y 751
        hsync <= (h_count >= 656 && h_count < 752) ? 0 : 1;
        
        // Vertical: Sync ocurre entre 490 y 491
        vsync <= (v_count >= 490 && v_count < 492) ? 0 : 1;
        
        // video_on es 1 solo dentro de los 640x480 píxeles visibles
        video_on <= (h_count < 640 && v_count < 480);
    end

    // 3. Salida de coordenadas
    // Enviamos la posición actual a los otros módulos (pelota, paletas)
    assign x_pos = h_count;
    assign y_pos = v_count;

endmodule