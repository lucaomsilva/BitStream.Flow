module top (
    input  logic clk,
    input  logic btn_in,
    output logic [5:0] led
);
    localparam int WAIT_TIME = 13500000;
    logic [5:0] ledCounter = '0;
    logic [23:0] clockCounter = '0;
    logic debounced_btn;

    debounce #(
        .STABILITY_COUNT(20000)
    ) u_debounce (
        .clk(clk),
        .btn_in(btn_in),
        .btn_out(debounced_btn)
    );

    always_ff @(posedge clk) begin
        if (debounced_btn) begin
            clockCounter <= clockCounter + 1'b1;
            if (clockCounter == WAIT_TIME) begin
                clockCounter <= '0;
                ledCounter <= ledCounter + 1'b1;
            end
        end
    end

    assign led = ~ledCounter;
endmodule
