module alu #(
    parameter WIDTH = 8                   //8 bit value
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [1:0]       operation,
    output logic [WIDTH-1:0] result,
    output logic             overflow
);

    logic [WIDTH:0] extended_result;

    always_comb begin
        result          = '0;
        overflow        = 1'b0;
        extended_result = '0;

        case (operation)
            2'b00: begin
                extended_result = {1'b0, a} + {1'b0, b};
                result          = extended_result[WIDTH-1:0];
                overflow        = extended_result[WIDTH];
            end

            2'b01: begin
                result = a + b;                         // BUG: adds instead of subtracting
            end

            2'b10: begin
                result = a & b;
            end

            2'b11: begin
                result = a | b;
            end
        endcase
    end

endmodule