module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,

    input  logic             write_enable,
    input  logic [WIDTH-1:0] write_data,

    input  logic             read_enable,
    output logic [WIDTH-1:0] read_data,

    output logic             full,
    output logic             empty
);

    localparam POINTER_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam COUNT_WIDTH   = $clog2(DEPTH + 1);

    logic [WIDTH-1:0] memory [0:DEPTH-1];
    logic [POINTER_WIDTH-1:0] write_pointer;
    logic [POINTER_WIDTH-1:0] read_pointer;
    logic [COUNT_WIDTH-1:0]   count;

    logic successful_write;
    logic successful_read;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    assign successful_write = write_enable && !full;
    assign successful_read = read_enable;                    // BUG: allows reads while empty

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            write_pointer <= '0;
            read_pointer  <= '0;
            count         <= '0;
            read_data     <= '0;
        end
        else begin
            if (successful_write) begin
                memory[write_pointer] <= write_data;

                if (write_pointer == DEPTH - 1)
                    write_pointer <= '0;
                else
                    write_pointer <= write_pointer + 1'b1;
            end

            if (successful_read) begin
                read_data <= memory[read_pointer];

                if (read_pointer == DEPTH - 1)
                    read_pointer <= '0;
                else
                    read_pointer <= read_pointer + 1'b1;
            end

            case ({successful_write, successful_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule