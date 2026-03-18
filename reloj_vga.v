module reloj_vga (
    input clk_50MHz,
    output reg clk_25MHz
);
    always @(posedge clk_50MHz) begin
        clk_25MHz <= ~clk_25MHz;
    end
endmodule