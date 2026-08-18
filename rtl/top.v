module top
(
    input clk,
    input btn_in,
    output [5:0] led
);

parameter integer WAIT_TIME = 13500000;
reg [5:0] ledCounter = 0;
reg [23:0] clockCounter = 0;

 wire debounced_btn;
    debounce u_debounce (
       .clk(clk),
       .btn_in(btn_in),
       .btn_out(debounced_btn)
    );

always @(posedge clk) begin
    if (debounced_btn) begin
        clockCounter <= clockCounter + 1;
        if (clockCounter == WAIT_TIME) begin
            clockCounter <= 0;
            ledCounter <= ledCounter + 1;
        end
    end
end

assign led = ~ledCounter;
endmodule
