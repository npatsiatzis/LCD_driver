module test_clock;

reg clk, rst;
wire LCD_RS,LCD_RW,LCD_E,SF_D11,SF_D10,SF_D9,SF_D8;

initial 
begin
	rst = 1'b1;
	clk = 1'b0;
	#20 rst = 1'b0;
end

always 
begin
	#10 clk = !clk;  
end

lcd_controller lcd_instance(clk,rst,LCD_RS,LCD_RW,LCD_E,SF_D11,SF_D10,SF_D9,SF_D8);
;

endmodule