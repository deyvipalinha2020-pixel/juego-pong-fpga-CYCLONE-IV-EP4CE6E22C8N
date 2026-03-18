module pixel_gen(
    input clk, video_on,
    input [9:0] x, y,
    input up_l, down_l,  // S1 es up_l, S2 es down_l
    input up_r, down_r,  // S3 es up_r, S4 es down_r
    input sw_modo,       
    output reg [2:0] rgb,
    output reg buzzer,
    output reg [4:0] score_l, score_r 
    );

    // --- Registros de Juego ---
    reg [9:0] bar_l_y = 200, bar_r_y = 200;
    reg [9:0] ball_x = 320, ball_y = 240;
    reg ball_x_dir = 1'b1, ball_y_dir = 1'b1;
    reg [3:0] ball_y_vel_reg = 3; 
    
    // --- Lógica de IA con Toggle ---
    reg ia_mode = 0;          
    reg btn_lock = 0;         
    reg btn_pause_lock = 0;   
    
    // --- Estela (Trail) ---
    reg [9:0] trail_x [1:4];
    reg [9:0] trail_y [1:4];

    // --- Registros para Conteo e Interfaz ---
    reg [26:0] count_timer = 0;
    reg [1:0] count_val = 3; 
    reg counting = 0;         
    reg [24:0] blink_timer;
    
    // --- Lógica de Torneo e Historial ---
    reg [1:0] state = 0;      // 0: Menú, 1: Juego, 2: Victoria, 3: PAUSA
    reg [2:0] sets_l = 0, sets_r = 0; 
    reg [4:0] p_l = 0, p_r = 0;         
    reg winner = 0; 
    
    // Historial de las últimas 5 partidas
    reg [1:0] h0 = 0, h1 = 0, h2 = 0, h3 = 0, h4 = 0;

    // --- AUDIO ---
    reg [31:0] sound_timer = 0;  
    reg [15:0] tone_gen = 0;      
    reg [24:0] music_tempo = 0;   
    reg [3:0]  note_index = 0;    
    reg [16:0] music_counter = 0; 
    reg [16:0] music_freq = 0;    

    wire [3:0] vel_x = (p_l >= 10 || p_r >= 10 || (sets_l + sets_r == 4)) ? 4'd7 : 4'd4;
    wire [4:0] limite_puntos = (sets_l + sets_r == 4) ? 5'd10 : 5'd15;

    always @(*) begin {score_l, score_r} = {p_l, p_r}; end
    always @(posedge clk) blink_timer <= blink_timer + 1;
    wire update_tick = (x == 639 && y == 479); 

    // --- MELODÍA HIMNO NACIONAL DEL PERÚ (Estilo 8-bit) ---
    always @(*) begin
        case(note_index)
            // "So-mos li-bres..."
            0:  music_freq = 47892; // Do4 (C4)
            1:  music_freq = 35816; // Fa4 (F4)
            2:  music_freq = 35816; // Fa4 (F4)
            3:  music_freq = 35816; // Fa4 (F4)
            // "se-á-mos-lo..."
            4:  music_freq = 28409; // La4 (A4)
            5:  music_freq = 23900; // Do5 (C5)
            6:  music_freq = 23900; // Do5 (C5)
            7:  music_freq = 23900; // Do5 (C5)
            // "siem-pre..." (y continuación para rellenar los 16 tiempos)
            8:  music_freq = 23900; // Do5 (C5)
            9:  music_freq = 23900; // Do5 (C5)
            10: music_freq = 21294; // Re5 (D5)
            11: music_freq = 23900; // Do5 (C5)
            12: music_freq = 26824; // Sib4 (Bb4)
            13: music_freq = 28409; // La4 (A4)
            14: music_freq = 31887; // Sol4 (G4)
            15: music_freq = 35816; // Fa4 (F4)
            default: music_freq = 47892;
        endcase
    end

    // --- BLOQUE PRINCIPAL ---
    always @(posedge clk) begin
        if (update_tick) begin
            // Toggle IA Y RESET (S1 + S4)
            if (up_l && down_r) begin
                if (!btn_lock) begin
                    if (state == 3) state <= 0; 
                    else ia_mode <= ~ia_mode;   
                    btn_lock <= 1;
                end
            end else btn_lock <= 0;

            // PAUSA (S2 + S3)
            if (down_l && up_r) begin
                if (!btn_pause_lock) begin
                    if (state == 1) state <= 3;     
                    else if (state == 3) state <= 1; 
                    btn_pause_lock <= 1;
                end
            end else btn_pause_lock <= 0;

            case (state)
                0: begin // MENU
                    if (up_l && up_r) begin 
                        state <= 1; counting <= 1; count_val <= 3; count_timer <= 0;
                        p_l <= 0; p_r <= 0; sets_l <= 0; sets_r <= 0;
                    end
                    ball_x <= 320; ball_y <= 240;
                end

                1: begin // JUEGO ACTIVO
                    if (counting) begin
                        if (count_timer < 40) count_timer <= count_timer + 1;
                        else begin
                            count_timer <= 0;
                            if (count_val > 0) count_val <= count_val - 1;
                            else counting <= 0; 
                        end
                    end else begin
                        // Movimiento Paletas
                        if (up_l && bar_l_y > 5) bar_l_y <= bar_l_y - 10'd5;
                        if (down_l && bar_l_y < 415) bar_l_y <= bar_l_y + 10'd5;

                        if (ia_mode) begin
                            if (ball_y > (bar_r_y + 30) && bar_r_y < 415) bar_r_y <= bar_r_y + 10'd4;
                            else if (ball_y < (bar_r_y + 30) && bar_r_y > 5) bar_r_y <= bar_r_y - 10'd4;
                        end else begin
                            if (up_r && bar_r_y > 5) bar_r_y <= bar_r_y - 10'd5;
                            if (down_r && bar_r_y < 415) bar_r_y <= bar_r_y + 10'd5;
                        end

                        // Física Pelota y ACTUALIZACIÓN DE ESTELA
                        trail_x[4] <= trail_x[3]; trail_y[4] <= trail_y[3];
                        trail_x[3] <= trail_x[2]; trail_y[3] <= trail_y[2];
                        trail_x[2] <= trail_x[1]; trail_y[2] <= trail_y[1];
                        trail_x[1] <= ball_x;     trail_y[1] <= ball_y;

                        ball_x <= (ball_x_dir) ? ball_x + vel_x : ball_x - vel_x;
                        ball_y <= (ball_y_dir) ? ball_y + ball_y_vel_reg : ball_y - ball_y_vel_reg;

                        // Colisiones
                        if (ball_y <= 10)  begin ball_y_dir <= 1'b1; sound_timer <= 800000; end
                        if (ball_y >= 465) begin ball_y_dir <= 1'b0; sound_timer <= 800000; end
                        if (ball_x <= 40 && ball_x >= 30 && ball_y+8 >= bar_l_y && ball_y <= bar_l_y+60) begin
                            ball_x_dir <= 1'b1; sound_timer <= 1500000;
                            ball_y_vel_reg <= (up_l || down_l) ? 6 : 3;
                        end
                        if (ball_x >= 590 && ball_x <= 600 && ball_y+8 >= bar_r_y && ball_y <= bar_r_y+60) begin
                            ball_x_dir <= 1'b0; sound_timer <= 1500000;
                            ball_y_vel_reg <= (ia_mode) ? 3 : ((up_r || down_r) ? 6 : 3);
                        end

                        // Puntos y Sets
                        if (ball_x >= 635) begin 
                            if (p_l + 1 == limite_puntos) begin 
                                if (sets_l == 2) begin 
                                    state <= 2; winner <= 0; sets_l <= 3; 
                                    h4 <= h3; h3 <= h2; h2 <= h1; h1 <= h0; h0 <= 2'b01;
                                end else begin sets_l <= sets_l + 1; p_l <= 0; p_r <= 0; counting <= 1; count_val <= 3; end
                            end else p_l <= p_l + 1;
                            ball_x <= 320; ball_x_dir <= 0;
                        end
                        if (ball_x <= 5) begin 
                            if (p_r + 1 == limite_puntos) begin 
                                if (sets_r == 2) begin 
                                    state <= 2; winner <= 1; sets_r <= 3; 
                                    h4 <= h3; h3 <= h2; h2 <= h1; h1 <= h0; h0 <= 2'b10;
                                end else begin sets_r <= sets_r + 1; p_l <= 0; p_r <= 0; counting <= 1; count_val <= 3; end
                            end else p_r <= p_r + 1;
                            ball_x <= 320; ball_x_dir <= 1;
                        end
                    end
                end

                2: if (up_l && up_r) state <= 0; // Victoria -> Menú

                3: begin // ESTADO PAUSA
                end
            endcase
        end

        // AUDIO 
        if (sound_timer > 0) begin
            sound_timer <= sound_timer - 1; tone_gen <= tone_gen + 1; buzzer <= tone_gen[13];
        end else if (state == 1 && !counting && sw_modo) begin
            if (music_tempo < 6000000) music_tempo <= music_tempo + 1;
            else begin music_tempo <= 0; note_index <= note_index + 1; end
            if (music_counter >= music_freq) music_counter <= 0;
            else music_counter <= music_counter + 1;
            buzzer <= (music_counter > (music_freq >> 1)); 
        end else buzzer <= 1'b1;
    end

    // --- ELEMENTOS VISUALES ---
    
    // --- LÍNEA 1: PROYECTO PONG P Y D : ---
    wire yt = (y>=20 && y<24), yu = (y>=24 && y<28), ym = (y>=28 && y<32), yl = (y>=32 && y<36), yb = (y>=36 && y<40);
    wire y_all = (y>=20 && y<40);
    wire t_P1 = (x>=130 && x<135)&y_all | (x>=135 && x<140)&(yt|ym) | (x>=140 && x<145)&(yt|yu|ym);
    wire t_R  = (x>=150 && x<155)&y_all | (x>=155 && x<160)&(yt|ym|yl) | (x>=160 && x<165)&(yt|yu|ym|yb);
    wire t_O1 = (x>=170 && x<175)&y_all | (x>=175 && x<180)&(yt|yb) | (x>=180 && x<185)&y_all;
    wire t_Y1 = (x>=190 && x<195)&(yt|yu) | (x>=195 && x<200)&(ym|yl|yb) | (x>=200 && x<205)&(yt|yu);
    wire t_E  = (x>=210 && x<215)&y_all | (x>=215 && x<225)&(yt|ym|yb);
    wire t_C  = (x>=230 && x<235)&y_all | (x>=235 && x<245)&(yt|yb);
    wire t_T  = (x>=250 && x<255)&yt | (x>=255 && x<260)&y_all | (x>=260 && x<265)&yt;
    wire t_O2 = (x>=270 && x<275)&y_all | (x>=275 && x<280)&(yt|yb) | (x>=280 && x<285)&y_all;
    wire t_P2 = (x>=305 && x<310)&y_all | (x>=310 && x<315)&(yt|ym) | (x>=315 && x<320)&(yt|yu|ym);
    wire t_O3 = (x>=325 && x<330)&y_all | (x>=330 && x<335)&(yt|yb) | (x>=335 && x<340)&y_all;
    wire t_N  = (x>=345 && x<350)&y_all | (x>=350 && x<353)&yu | (x>=353 && x<355)&ym | (x>=355 && x<360)&y_all;
    wire t_G  = (x>=365 && x<370)&y_all | (x>=370 && x<375)&(yt|ym|yb) | (x>=375 && x<380)&(yt|ym|yl|yb);
    wire t_P3 = (x>=400 && x<405)&y_all | (x>=405 && x<410)&(yt|ym) | (x>=410 && x<415)&(yt|yu|ym);
    wire t_Y2 = (x>=435 && x<440)&(yt|yu) | (x>=440 && x<445)&(ym|yl|yb) | (x>=445 && x<450)&(yt|yu);
    wire t_D  = (x>=470 && x<475)&y_all | (x>=475 && x<480)&(yt|yb) | (x>=480 && x<485)&(yu|ym|yl);
    wire t_COLON = (x>=495 && x<500)&(yu|yl); 
    wire title_on = (state == 0) && (t_P1 | t_R | t_O1 | t_Y1 | t_E | t_C | t_T | t_O2 | t_P2 | t_O3 | t_N | t_G | t_P3 | t_Y2 | t_D | t_COLON);

    // --- LÍNEA 2: MERINO CASTRO Y VÁSQUEZ VIGIL ---
    wire yn_t = (y>=90 && y<94), yn_u = (y>=94 && y<98), yn_m = (y>=98 && y<102), yn_l = (y>=102 && y<106), yn_b = (y>=106 && y<110);
    wire yn_all = (y>=90 && y<110);
    
    wire n_M  = (((x>=170 && x<172)|(x>=174 && x<176))&yn_all) | ((x>=172 && x<174)&(yn_t|yn_u));
    wire n_E1 = ((x>=180 && x<185)&(yn_t|yn_m|yn_b)) | ((x>=180 && x<182)&yn_all);
    wire n_R1 = ((x>=190 && x<192)&yn_all) | ((x>=192 && x<195)&(yn_t|yn_m)) | ((x>=194 && x<196)&yn_u) | ((x>=193 && x<196)&(yn_l|yn_b));
    wire n_I1 = ((x>=200 && x<205)&(yn_t|yn_b)) | ((x>=202 && x<204)&yn_all);
    wire n_N1 = (((x>=210 && x<212)|(x>=214 && x<216))&yn_all) | ((x>=212 && x<214)&(yn_u|yn_m));
    wire n_O1 = ((x>=220 && x<225)&(yn_t|yn_b)) | (((x>=220 && x<222)|(x>=224 && x<226))&yn_all);

    wire n_C  = ((x>=235 && x<240)&(yn_t|yn_b)) | ((x>=235 && x<237)&yn_all);
    wire n_A1 = ((x>=245 && x<250)&(yn_t|yn_m)) | (((x>=245 && x<247)|(x>=249 && x<251))&yn_all);
    wire n_S1 = ((x>=255 && x<260)&(yn_t|yn_m|yn_b)) | ((x>=255 && x<257)&(yn_t|yn_u|yn_m)) | ((x>=259 && x<261)&(yn_m|yn_l|yn_b));
    wire n_T  = ((x>=265 && x<270)&yn_t) | ((x>=267 && x<269)&yn_all);
    wire n_R2 = ((x>=275 && x<277)&yn_all) | ((x>=277 && x<280)&(yn_t|yn_m)) | ((x>=279 && x<281)&yn_u) | ((x>=278 && x<281)&(yn_l|yn_b));
    wire n_O2 = ((x>=285 && x<290)&(yn_t|yn_b)) | (((x>=285 && x<287)|(x>=289 && x<291))&yn_all);

    wire n_Y  = (((x>=300 && x<302)|(x>=304 && x<306))&(yn_t|yn_u)) | ((x>=300 && x<306)&yn_m) | ((x>=302 && x<304)&yn_all);

    wire n_V1 = (((x>=315 && x<317)|(x>=319 && x<321))&(yn_t|yn_u|yn_m|yn_l)) | ((x>=317 && x<319)&yn_b);
    wire n_A2 = ((x>=325 && x<330)&(yn_t|yn_m)) | (((x>=325 && x<327)|(x>=329 && x<331))&yn_all);
    wire n_A2_acc = (state == 0) && (x>=327 && x<329) && (y>=85 && y<88); 
    wire n_S2 = ((x>=335 && x<340)&(yn_t|yn_m|yn_b)) | ((x>=335 && x<337)&(yn_t|yn_u|yn_m)) | ((x>=339 && x<341)&(yn_m|yn_l|yn_b));
    wire n_Q  = ((x>=345 && x<350)&(yn_t|yn_b)) | (((x>=345 && x<347)|(x>=349 && x<351))&yn_all) | ((x>=348 && x<351)&yn_b);
    wire n_U  = ((x>=355 && x<360)&yn_b) | (((x>=355 && x<357)|(x>=359 && x<361))&yn_all);
    wire n_E2 = ((x>=365 && x<370)&(yn_t|yn_m|yn_b)) | ((x>=365 && x<367)&yn_all);
    wire n_Z  = ((x>=375 && x<380)&(yn_t|yn_b)) | ((x>=378 && x<380)&yn_u) | ((x>=377 && x<379)&yn_m) | ((x>=375 && x<377)&yn_l);

    wire n_V2 = (((x>=390 && x<392)|(x>=394 && x<396))&(yn_t|yn_u|yn_m|yn_l)) | ((x>=392 && x<394)&yn_b);
    wire n_I2 = ((x>=400 && x<405)&(yn_t|yn_b)) | ((x>=402 && x<404)&yn_all);
    wire n_G  = ((x>=410 && x<415)&(yn_t|yn_b)) | ((x>=410 && x<412)&yn_all) | ((x>=414 && x<416)&(yn_m|yn_l|yn_b)) | ((x>=413 && x<415)&yn_m);
    wire n_I3 = ((x>=420 && x<425)&(yn_t|yn_b)) | ((x>=422 && x<424)&yn_all);
    wire n_L  = ((x>=430 && x<432)&yn_all) | ((x>=430 && x<435)&yn_b);

    wire subtitle_on = (state == 0) && (n_M | n_E1 | n_R1 | n_I1 | n_N1 | n_O1 | 
                                        n_C | n_A1 | n_S1 | n_T | n_R2 | n_O2 | 
                                        n_Y | 
                                        n_V1 | n_A2 | n_S2 | n_Q | n_U | n_E2 | n_Z | 
                                        n_V2 | n_I2 | n_G | n_I3 | n_L);

    // TRIÁNGULO STAR
    wire [9:0] dx_tri = (x > 290) ? (x - 290) : 0; 
    wire [9:0] dy_tri = (y > 240) ? (y - 240) : (240 - y); 
    wire triangle_start_on = (x >= 290 && x <= 350) && ((dx_tri + (dy_tri << 1)) <= 60);

    wire yts_s = (y>=232 && y<236), yms_s = (y>=240 && y<244), ybs_s = (y>=248 && y<252); 
    wire y_all_s = (y>=232 && y<252);
    wire s_S = ((yts_s|yms_s|ybs_s)&&(x>=300 && x<306)) | ((y>=232 && y<240)&&(x>=300 && x<302)) | ((y>=240 && y<252)&&(x>=304 && x<306));
    wire s_T = (yts_s&&(x>=309 && x<315)) | (y_all_s&&(x>=311 && x<313));
    wire s_A = (y_all_s&&(x>=318 && x<320)) | (y_all_s&&(x>=322 && x<324)) | (yts_s&&(x>=318 && x<324)) | (yms_s&&(x>=318 && x<324));
    wire s_R = (y_all_s&&(x>=327 && x<329)) | (yts_s&&(x>=327 && x<333)) | (yms_s&&(x>=327 && x<333)) | ((y>=232 && y<240)&&(x>=331 && x<333)) | ((y>=240 && y<252)&&(x>=331 && x<333)); 
    wire star_text_on = (s_S | s_T | s_A | s_R);

    wire start_shape_on = (state == 0) && triangle_start_on;
    wire start_text_final_on = (state == 0) && triangle_start_on && star_text_on;

    // HISTORIAL
    wire draw_hist_H = (state == 0) && (y>=400 && y<=420) && ((x>=200 && x<=205) || (x>=215 && x<=220) || (x>=205 && x<=215 && y>=408 && y<=412));
    wire draw_h0 = (state == 0 && x >= 240 && x <= 260 && y >= 400 && y <= 420);
    wire draw_h1 = (state == 0 && x >= 275 && x <= 295 && y >= 400 && y <= 420);
    wire draw_h2 = (state == 0 && x >= 310 && x <= 330 && y >= 400 && y <= 420);
    wire draw_h3 = (state == 0 && x >= 345 && x <= 365 && y >= 400 && y <= 420);
    wire draw_h4 = (state == 0 && x >= 380 && x <= 400 && y >= 400 && y <= 420);

    // EFECTOS DE PANTALLA DE VICTORIA (ARCADE)
    wire [11:0] sum_xy = {2'b00, x} + {2'b00, y};
    wire [11:0] pattern_pos = sum_xy - {1'b0, blink_timer[24:14]}; 
    wire victory_stripe = pattern_pos[6]; 

    wire draw_crown = (state == 2) && (
        (x >= 260 && x <= 380 && y >= 280 && y <= 310) || 
        (x >= 260 && x <= 280 && y >= 220 && y <= 280) || 
        (x >= 310 && x <= 330 && y >= 200 && y <= 280) || 
        (x >= 360 && x <= 380 && y >= 220 && y <= 280) || 
        (x >= 280 && x <= 310 && y >= 250 && y <= 280) || 
        (x >= 330 && x <= 360 && y >= 250 && y <= 280)   
    );

    // OTROS ELEMENTOS
    wire ia_indicator = (ia_mode && x >= 315 && x <= 325 && y >= 10 && y <= 20);
    wire pause_icon = (state == 3) && ((x >= 300 && x <= 310 && y >= 210 && y <= 270) || (x >= 330 && x <= 340 && y >= 210 && y <= 270));

    wire set_l_1 = (state == 0 && sets_l >= 1 && x >= 100 && x <= 110 && y >= 50 && y <= 60);
    wire set_l_2 = (state == 0 && sets_l >= 2 && x >= 120 && x <= 130 && y >= 50 && y <= 60);
    wire set_l_3 = (state == 0 && sets_l >= 3 && x >= 140 && x <= 150 && y >= 50 && y <= 60);
    wire set_r_1 = (state == 0 && sets_r >= 1 && x >= 490 && x <= 500 && y >= 50 && y <= 60);
    wire set_r_2 = (state == 0 && sets_r >= 2 && x >= 510 && x <= 520 && y >= 50 && y <= 60);
    wire set_r_3 = (state == 0 && sets_r >= 3 && x >= 530 && x <= 540 && y >= 50 && y <= 60);
    wire win_box_l = (state == 0 && sets_l > sets_r && x >= 100 && x <= 150 && y >= 70 && y <= 80);
    wire win_box_r = (state == 0 && sets_r > sets_l && x >= 490 && x <= 540 && y >= 70 && y <= 80);

    wire d3 = (count_val==3) && ((x>=310 && x<=330 && (y==230 || y==240 || y==250)) || (x==330 && y>=230 && y<=250));
    wire d2 = (count_val==2) && ((x>=310 && x<=330 && (y==230 || y==240 || y==250)) || (x==330 && y>=230 && y<=240) || (x==310 && y>=240 && y<=250));
    wire d1 = (count_val==1) && (x==320 && y>=230 && y<=250);
    wire dG = (count_val==0) && (x>=300 && x<=340 && y>=230 && y<=250);

    // --- MARCADOR DE FONDO GIGANTE ---
    wire [3:0] val_l = (p_l >= 10) ? p_l - 10 : p_l;
    wire [3:0] val_r = (p_r >= 10) ? p_r - 10 : p_r;
    
    wire draw_l_tens = (p_l >= 10) && (x >= 140 && x <= 155 && y >= 160 && y <= 280);
    wire draw_r_tens = (p_r >= 10) && (x >= 380 && x <= 395 && y >= 160 && y <= 280);

    wire l_seg_a = (y >= 160 && y <= 175) && (x >= 180 && x <= 240);
    wire l_seg_b = (y >= 160 && y <= 220) && (x >= 225 && x <= 240);
    wire l_seg_c = (y >= 220 && y <= 280) && (x >= 225 && x <= 240);
    wire l_seg_d = (y >= 265 && y <= 280) && (x >= 180 && x <= 240);
    wire l_seg_e = (y >= 220 && y <= 280) && (x >= 180 && x <= 195);
    wire l_seg_f = (y >= 160 && y <= 220) && (x >= 180 && x <= 195);
    wire l_seg_g = (y >= 212 && y <= 228) && (x >= 180 && x <= 240);

    wire l_draw_u = 
        (l_seg_a && (val_l!=1 && val_l!=4)) |
        (l_seg_b && (val_l!=5 && val_l!=6)) |
        (l_seg_c && (val_l!=2)) |
        (l_seg_d && (val_l!=1 && val_l!=4 && val_l!=7)) |
        (l_seg_e && (val_l==0 || val_l==2 || val_l==6 || val_l==8)) |
        (l_seg_f && (val_l!=1 && val_l!=2 && val_l!=3 && val_l!=7)) |
        (l_seg_g && (val_l!=0 && val_l!=1 && val_l!=7));

    wire r_seg_a = (y >= 160 && y <= 175) && (x >= 420 && x <= 480);
    wire r_seg_b = (y >= 160 && y <= 220) && (x >= 465 && x <= 480);
    wire r_seg_c = (y >= 220 && y <= 280) && (x >= 465 && x <= 480);
    wire r_seg_d = (y >= 265 && y <= 280) && (x >= 420 && x <= 480);
    wire r_seg_e = (y >= 220 && y <= 280) && (x >= 420 && x <= 435);
    wire r_seg_f = (y >= 160 && y <= 220) && (x >= 420 && x <= 435);
    wire r_seg_g = (y >= 212 && y <= 228) && (x >= 420 && x <= 480);

    wire r_draw_u = 
        (r_seg_a && (val_r!=1 && val_r!=4)) |
        (r_seg_b && (val_r!=5 && val_r!=6)) |
        (r_seg_c && (val_r!=2)) |
        (r_seg_d && (val_r!=1 && val_r!=4 && val_r!=7)) |
        (r_seg_e && (val_r==0 || val_r==2 || val_r==6 || val_r==8)) |
        (r_seg_f && (val_r!=1 && val_r!=2 && val_r!=3 && val_r!=7)) |
        (r_seg_g && (val_r!=0 && val_r!=1 && val_r!=7));

    wire ball_on = (x >= ball_x && x <= ball_x + 8 && y >= ball_y && y <= ball_y + 8);
    // Renderizado del Efecto Cometa (Estela)
    wire trail_1_on = (x >= trail_x[1] && x <= trail_x[1] + 8 && y >= trail_y[1] && y <= trail_y[1] + 8);
    wire trail_2_on = (x >= trail_x[2] && x <= trail_x[2] + 8 && y >= trail_y[2] && y <= trail_y[2] + 8);
    wire trail_3_on = (x >= trail_x[3] && x <= trail_x[3] + 8 && y >= trail_y[3] && y <= trail_y[3] + 8);

    wire bar_l_on = (x >= 30 && x <= 40 && y >= bar_l_y && y <= bar_l_y + 60);
    wire bar_r_on = (x >= 600 && x <= 610 && y >= bar_r_y && y <= bar_r_y + 60);
    wire net_on = (x >= 319 && x <= 321) && (y[4] == 1'b1);

    always @(*) begin
        if (~video_on) rgb = 3'b000;
        else begin
            if (ia_indicator) rgb = 3'b111; 
            else if (pause_icon) rgb = 3'b111; 
            else begin
                case (state)
                    0: begin 
                        if (title_on || subtitle_on || n_A2_acc) rgb = 3'b011; 
                        else if (set_l_1 || set_l_2 || set_l_3 || win_box_l) rgb = 3'b010;
                        else if (set_r_1 || set_r_2 || set_r_3 || win_box_r) rgb = 3'b100;
                        else if (blink_timer[24] && start_text_final_on) rgb = 3'b001; 
                        else if (blink_timer[24] && start_shape_on) rgb = 3'b110;       
                        else if (draw_hist_H) rgb = 3'b111;
                        else if (draw_h0 && h0 != 0) rgb = (h0 == 2'b01) ? 3'b010 : 3'b100;
                        else if (draw_h1 && h1 != 0) rgb = (h1 == 2'b01) ? 3'b010 : 3'b100;
                        else if (draw_h2 && h2 != 0) rgb = (h2 == 2'b01) ? 3'b010 : 3'b100;
                        else if (draw_h3 && h3 != 0) rgb = (h3 == 2'b01) ? 3'b010 : 3'b100;
                        else if (draw_h4 && h4 != 0) rgb = (h4 == 2'b01) ? 3'b010 : 3'b100;
                        else rgb = 3'b001;
                    end
                    1, 3: begin 
                        if (counting && (d3||d2||d1||dG)) rgb = 3'b111;
                        
                        // PRIORIDAD 1: Elementos del juego activos
                        else if (ball_on) rgb = (ball_y_vel_reg == 6) ? 3'b110 : 3'b111; // Roja/Naranja si va rápido, sino Blanca
                        
                        // PRIORIDAD 2: Estela de la pelota
                        else if (trail_1_on) rgb = 3'b101; // Color medio
                        else if (trail_2_on) rgb = 3'b100; // Color más oscuro
                        else if (trail_3_on) rgb = 3'b011; // Se difumina con el fondo
                        
                        // PRIORIDAD 3: Paletas y Red
                        else if (bar_l_on) rgb = 3'b010;
                        else if (bar_r_on) rgb = 3'b100;
                        else if (net_on) rgb = 3'b111;
                        
                        // PRIORIDAD 4: Fondo gigante transparente (Marcador)
                        else if (draw_l_tens || l_draw_u || draw_r_tens || r_draw_u) rgb = 3'b011; // Cian
                        
                        // PRIORIDAD 5: Fondo real del mapa
                        else rgb = 3'b001;
                    end
                    2: begin
                        if (draw_crown) begin
                            rgb = blink_timer[23] ? 3'b110 : 3'b111; 
                        end else begin
                            if (victory_stripe)
                                rgb = (winner == 0) ? 3'b010 : 3'b100; 
                            else
                                rgb = (winner == 0) ? 3'b011 : 3'b101; 
                        end
                    end
                    default: rgb = 3'b001;
                endcase
            end
        end
    end
endmodule