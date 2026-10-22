
`timescale 1ns / 1ps

module i2c_master_tb;

reg clk = 0;
reg rst = 1;
reg start = 0;
reg [6:0] slave_addr = 7'h50;
reg [7:0] data_in = 8'hA5;

wire busy;
wire done;
wire ack_error;
wire scl;
tri1 sda;

reg slave_sda_low = 0;
reg transaction_active = 0;

reg [7:0] rx_byte = 0;
reg [7:0] received_address = 0;
reg [7:0] received_data = 0;

integer bit_count = 0;
integer byte_count = 0;
integer ack_count = 0;
integer failures = 0;

assign sda = slave_sda_low ? 1'b0 : 1'bz;

i2c_master #(
    .CLK_DIV(250)
) dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .slave_addr(slave_addr),
    .data_in(data_in),
    .busy(busy),
    .done(done),
    .ack_error(ack_error),
    .sda(sda),
    .scl(scl)
);

always #10 clk = ~clk;

always @(negedge sda) begin
    if (scl === 1'b1) begin
        transaction_active = 1;
        bit_count = 0;
        byte_count = 0;
        ack_count = 0;
        rx_byte = 0;
        slave_sda_low = 0;
    end
end

always @(posedge sda) begin
    if (scl === 1'b1 && transaction_active) begin
        transaction_active = 0;
        slave_sda_low = 0;
    end
end

always @(posedge scl) begin
    if (transaction_active) begin
        if (bit_count < 8) begin
            rx_byte = {rx_byte[6:0], sda};
            bit_count = bit_count + 1;

            if (bit_count == 8) begin
                if (byte_count == 0)
                    received_address = rx_byte;
                else if (byte_count == 1)
                    received_data = rx_byte;
            end
        end else begin
            if (sda === 1'b0)
                ack_count = ack_count + 1;

            bit_count = 0;
            byte_count = byte_count + 1;
            rx_byte = 0;
        end
    end
end

always @(negedge scl) begin
    if (transaction_active && bit_count == 8)
        slave_sda_low = 1'b1;
    else
        slave_sda_low = 1'b0;
end

initial begin
    $display("I2C test started");

    repeat (5) @(negedge clk);
    rst = 0;

    repeat (5) @(negedge clk);
    start = 1;

    @(negedge clk);
    start = 0;

    wait(done === 1'b1);
    #100;

    if (ack_error !== 1'b0) begin
        $display("FAIL: ACK error asserted");
        failures = failures + 1;
    end

    if (received_address !== 8'hA0) begin
        $display("FAIL: Expected address A0, got %h",
                 received_address);
        failures = failures + 1;
    end

    if (received_data !== 8'hA5) begin
        $display("FAIL: Expected data A5, got %h",
                 received_data);
        failures = failures + 1;
    end

    if (ack_count != 2) begin
        $display("FAIL: Expected 2 ACKs, counted %0d", ack_count);
        failures = failures + 1;
    end

    if (busy !== 1'b0) begin
        $display("FAIL: busy did not return low");
        failures = failures + 1;
    end

    if (failures == 0)
        $display("PASS: Address A0, data A5, both ACKs received.");
    else
        $display("TEST FAILED: %0d check(s) failed.", failures);

    $finish;
end

initial begin
    #2000000;
    $display("TIMEOUT: I2C transaction did not finish.");
    $finish;
end

endmodule
