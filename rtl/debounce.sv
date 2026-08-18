module debounce #(
    parameter int STABILITY_COUNT = 20000
)(
    input  logic clk,
    input  logic btn_in,
    output logic btn_out
);
    logic [15:0] counter = '0;
    logic internal_state = 1'b1;

    always_ff @(posedge clk) begin
        if (btn_in != internal_state) begin
            counter <= '0;
            internal_state <= btn_in;
        end else if (counter < STABILITY_COUNT) begin
            counter <= counter + 1'b1;
        end else begin
            btn_out <= internal_state;
        end
    end
endmodule
