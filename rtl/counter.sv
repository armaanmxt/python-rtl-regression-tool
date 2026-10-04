module counter #(
    parameter WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count           //count is the output and stored counter value.
);

    always_ff @(posedge clk) begin          //This block executes on every rising edge of the clock:
        if (!rst_n)                     //if reset button is currently being pressed
            count <= '0;                // then clear the count setting at the next clock edge
        else if (enable)                //If reset is inactive and enable is high.
            count <= count + 1'b1;      // then increment the counter by one bit
    end

endmodule