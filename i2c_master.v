`timescale 1ns / 1ps

module i2c_master (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [6:0] slave_addr,
    input  wire [7:0] data_in,
    output reg        busy,
    output reg        done,
    output reg        ack_error,
    inout  wire       sda,
    output wire       scl
);

    parameter integer CLK_DIV = 250;

    localparam [3:0]
        IDLE      = 4'd0,
        START_A   = 4'd1,
        START_B   = 4'd2,
        BIT_HIGH  = 4'd3,
        BIT_LOW   = 4'd4,
        ACK_HIGH  = 4'd5,
        ACK_LOW   = 4'd6,
        STOP_LOW  = 4'd7,
        STOP_HIGH = 4'd8,
        STOP_END  = 4'd9;

    reg [3:0] state;
    reg [8:0] divider;
    reg [2:0] bit_index;
    reg [7:0] address_byte;
    reg [7:0] shift_reg;
    reg address_phase;
    reg scl_reg;
    reg sda_drive_low;

    wire tick = (divider == CLK_DIV - 1);

    assign scl = scl_reg;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            divider       <= 0;
            bit_index     <= 0;
            address_byte  <= 0;
            shift_reg     <= 0;
            address_phase <= 1'b1;
            scl_reg       <= 1'b1;
            sda_drive_low <= 1'b0;
            busy          <= 1'b0;
            done          <= 1'b0;
            ack_error     <= 1'b0;
        end else begin
            done <= 1'b0;

            if (state == IDLE || tick)
                divider <= 0;
            else
                divider <= divider + 1'b1;

            if (state == IDLE) begin
                scl_reg       <= 1'b1;
                sda_drive_low <= 1'b0;
                busy          <= 1'b0;

                if (start) begin
                    busy          <= 1'b1;
                    ack_error     <= 1'b0;
                    address_byte  <= {slave_addr, 1'b0};
                    shift_reg     <= data_in;
                    bit_index     <= 3'd7;
                    address_phase <= 1'b1;
                    state         <= START_A;
                end
            end else if (tick) begin
                case (state)

                    START_A: begin
                        scl_reg       <= 1'b1;
                        sda_drive_low <= 1'b1;
                        state         <= START_B;
                    end

                    START_B: begin
                        scl_reg       <= 1'b0;
                        sda_drive_low <= ~address_byte[7];
                        state         <= BIT_HIGH;
                    end

                    BIT_HIGH: begin
                        scl_reg <= 1'b1;
                        state   <= BIT_LOW;
                    end

                    BIT_LOW: begin
                        scl_reg <= 1'b0;

                        if (bit_index == 0) begin
                            sda_drive_low <= 1'b0;
                            state         <= ACK_HIGH;
                        end else begin
                            bit_index <= bit_index - 1'b1;

                            if (address_phase)
                                sda_drive_low <=
                                    ~address_byte[bit_index - 1'b1];
                            else
                                sda_drive_low <=
                                    ~shift_reg[bit_index - 1'b1];

                            state <= BIT_HIGH;
                        end
                    end

                    ACK_HIGH: begin
                        scl_reg <= 1'b1;

                        if (sda !== 1'b0)
                            ack_error <= 1'b1;

                        state <= ACK_LOW;
                    end

                    ACK_LOW: begin
                        scl_reg <= 1'b0;

                        if (sda !== 1'b0) begin
                            state <= STOP_LOW;
                        end else if (address_phase) begin
                            address_phase <= 1'b0;
                            bit_index     <= 3'd7;
                            sda_drive_low <= ~shift_reg[7];
                            state         <= BIT_HIGH;
                        end else begin
                            state <= STOP_LOW;
                        end
                    end

                    STOP_LOW: begin
                        scl_reg       <= 1'b0;
                        sda_drive_low <= 1'b1;
                        state         <= STOP_HIGH;
                    end

                    STOP_HIGH: begin
                        scl_reg <= 1'b1;
                        state   <= STOP_END;
                    end

                    STOP_END: begin
                        scl_reg       <= 1'b1;
                        sda_drive_low <= 1'b0;
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        state         <= IDLE;
                    end

                    default: begin
                        state         <= IDLE;
                        scl_reg       <= 1'b1;
                        sda_drive_low <= 1'b0;
                        busy          <= 1'b0;
                        ack_error     <= 1'b1;
                    end

                endcase
            end
        end
    end

endmodule
