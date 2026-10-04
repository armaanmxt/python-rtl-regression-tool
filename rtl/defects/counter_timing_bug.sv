module counter #(
    parameter WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count
);

    logic delayed_enable;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count          <= '0;
            delayed_enable <= 1'b0;
        end
        else begin
            delayed_enable <= enable;

                                            // BUG: uses the previous cycle's enable value
            if (delayed_enable)
                count <= count + 1'b1;
        end
    end

endmodule