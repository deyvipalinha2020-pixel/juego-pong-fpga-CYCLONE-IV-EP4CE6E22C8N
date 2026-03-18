`timescale 1ns / 1ps

module top_pong(
    input clk_50MHz,
    input s1, s2, s3, s4,   // Botones S1 (88), S2 (89), S3 (90), S4 (91)
    input sw0,              // Switch con el número 1 (Modo de juego)
    output hsync,
    output vsync,
    output [2:0] rgb,
    output buzzer,
    output [7:0] seg,    
    output [3:0] sel     
    );
    
    wire w_vid_on, w_p_tick;
    wire [9:0] w_x, w_y;
    wire [2:0] rgb_next;
    reg [2:0] rgb_reg;
    wire [3:0] score_l, score_r; 
    
    reloj_vga clk_gen (
        .clk_50MHz(clk_50MHz), 
        .clk_25MHz(w_p_tick)
    );

    vga_controller vga (
        .clk_25(w_p_tick), 
        .hsync(hsync),      
        .vsync(vsync),      
        .video_on(w_vid_on), 
        .x_pos(w_x), 
        .y_pos(w_y)
    );

    pixel_gen pg (
        .clk(w_p_tick), 
        .video_on(w_vid_on), 
        .x(w_x), 
        .y(w_y), 
        .up_l(~s1), .down_l(~s2), 
        .up_r(~s3), .down_r(~s4), 
        .sw_modo(sw0),       // Conectado al Switch 1
        .rgb(rgb_next),
        .buzzer(buzzer),
        .score_l(score_l), .score_r(score_r)
    );
    
    seg7 disp (
        .clk(w_p_tick),
        .score_l(score_l),
        .score_r(score_r),
        .sseg(seg),
        .sel(sel)
    );

    always @(posedge w_p_tick) begin
        rgb_reg <= rgb_next;
    end
            
    assign rgb = (w_vid_on) ? rgb_reg : 3'b000;
    
endmodule