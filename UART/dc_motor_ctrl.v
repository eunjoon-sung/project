`timescale 1ns / 1ps

module dc_motor_ctrl(
    input [7:0] rx_data,
    input rx_done,
    input rst,
    input clk,
    output wire INA,
    output wire INB
    );

    reg [10:0] duty_cycle;
    reg pwm_out;
    reg fwd; // forward : 1, reverse : 0 (port가 하나 뿐임)
    reg rx_done_prev = 0;
    reg rx_done_aft = 0;
    wire rx_done_flag; // rx_done이 0에서 1로 바뀔 때 ON
    
    always @(posedge clk) begin
        rx_done_prev <= rx_done;
        rx_done_aft <= rx_done_prev;
    end
    
    assign rx_done_flag = ~rx_done_aft && rx_done_prev; // 바뀌기 전 한클럭만 유지

    
    assign INA = fwd ? pwm_out : 0 ;
    assign INB = fwd ? 0 : pwm_out ;
    

    parameter PWM_PERIOD = 1600;
    integer i;
    
    always @(posedge clk) begin
        if (rst) begin
            fwd <= 1;
            duty_cycle <= 0;
            i <= 0;
            pwm_out <= 0;
        end else begin
            // PWM 제어
            i <= i + 1;
            if (i == PWM_PERIOD) begin
                i <= 0;
            end
            if (duty_cycle >= 0 && duty_cycle <= PWM_PERIOD) begin
                if (i < duty_cycle) begin
                    pwm_out <= 1;
                end
                else begin
                    pwm_out <= 0;
                end
            end
            
            if (rx_done_flag) begin
                case (rx_data)
                    8'h0x80: begin 
                        // 정지
                        fwd <= 1;
                        duty_cycle <= 0;
                    end
                    8'h0x81: begin
                        // 정방향 
                        fwd <= 1;
                        duty_cycle <= 800;
                    end
                    8'h0x82: begin
                        // 역방향
                        fwd <= 0;
                        duty_cycle <= 800;
                    end
                    8'h0x83: begin 
                        // PWM 증가
                        if (duty_cycle < PWM_PERIOD) begin
                            duty_cycle <= duty_cycle + 80;
                        end
                        else begin
                            duty_cycle <= duty_cycle;
                        end
                    end
                    8'h0x84: begin 
                        // PWM 감소
                        if (duty_cycle > 0) begin
                            duty_cycle <= duty_cycle - 80;
                        end
                        else begin
                            duty_cycle <= duty_cycle;
                        end
                    end
                    default: begin
                        fwd <= fwd;
                    end
                endcase
            end    
        end    
    end

endmodule
