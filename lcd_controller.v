module lcd_controller(clk,rst,LCD_RS,LCD_RW,LCD_E,SF_D11,SF_D10,SF_D9,SF_D8);

input clk,rst;
wire [5:0]LCD_D;
output LCD_RS,LCD_RW,LCD_E,SF_D11,SF_D10,SF_D9,SF_D8;
wire [7:0]memory;
wire [10:0]addr;

assign LCD_RS 	= LCD_D[5];
assign LCD_RW	= LCD_D[4];
assign SF_D11   = LCD_D[3];
assign SF_D10 	= LCD_D[2];
assign SF_D9 	= LCD_D[1];
assign SF_D8 	= LCD_D[0];

bram BRAM_INSTANCE (
    .clk(clk), 
    .addr(addr), 
    .char(memory)
    );
	
lcd_driver DRIVER (
    .clk(clk), 
    .reset(rst), 
    .memory(memory), 
    .LCD_D(LCD_D), 
    .LCD_E(LCD_E), 
    .address(addr)
    );


endmodule