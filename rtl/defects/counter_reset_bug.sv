module counter #(
    parameter WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count
);

    always_ff @(posedge clk) begin
        if (!rst_n)
            count <= {{(WIDTH-1){1'b0}}, 1'b1};       // BUG: resets to 1
        else if (enable)
            count <= count + 1'b1;
    end

endmodule