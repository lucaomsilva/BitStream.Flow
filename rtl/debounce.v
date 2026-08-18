// src/debounce.v
module debounce(
    input  wire clk,
    input  wire btn_in,
    output reg  btn_out
);
    parameter STABILITY_COUNT = 20000; // Contagem para ~1ms de debounce com clock de 27MHz
    reg [15:0] counter = 0;
    reg internal_state = 1'b1;
    always @(posedge clk) begin
        if (btn_in!= internal_state) begin
            // O sinal do botão mudou, reinicia o contador
            counter <= 0;

            internal_state <= btn_in;
        end else if (counter < STABILITY_COUNT) begin
            // O sinal está estável, mas o tempo de debounce não foi atingido
            counter <= counter + 1;
        end else begin
            // O sinal está estável pelo tempo necessário, atualiza a saída
            btn_out <= internal_state;
        end
    end

endmodule