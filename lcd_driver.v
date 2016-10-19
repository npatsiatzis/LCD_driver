module lcd_driver(
    input  clk,
    input  reset,
	input  [7:0] memory,
    //---------------------------------
    output [5:0] LCD_D, // 4-bit LCD data bus
    output LCD_E,       // Enable
	output [10:0] address 	//BRAM address
    );

    localparam [4:0]    INIT_1=1, INIT_2=2, INIT_3=3, INIT_4=4, INIT_5=5, INIT_6=6, INIT_7=7, INIT_8=8,
                        CMD_WAIT=9, U_SETUP=10, U_ENAB=11, U_HOLD=12, UL_WAIT=13, L_SETUP=14,
                        L_ENAB=15, L_HOLD=16, DISPLAY = 17, DISPLAY_TO_REFRESH = 18;
    localparam [3:0]	DISPLAY_CMD_WAIT = 1, DISPLAY_U_SETUP = 2, DISPLAY_U_ENAB = 3, DISPLAY_U_HOLD = 4,
						DISPLAY_UL_WAIT = 5, DISPLAY_L_SETUP = 6, DISPLAY_L_ENAB = 7, DISPLAY_L_HOLD = 8,
						DISPLAY_IDLE = 9;
	
	reg  [12:0] display_count;
    reg  [25:0] count;
    reg  [25:0] compare;
	reg  [12:0] display_compare;
    reg  [4:0] state;
	reg  [3:0] display_state;
    wire bell;
	wire display_bell;
	reg [7:0]command[4:0];
	reg [2:0]i;
	reg [5:0] main_LCD_D;
	reg main_LCD_E;
	reg [5:0] secondary_LCD_D;
	reg secondary_LCD_E;
	reg [8:0]bell_counter;
	reg select_output;
    reg check_cursor;
	
	assign bell = (count == compare);
	assign display_bell = (display_count == display_compare);
	assign address = {2'b0,bell_counter};
	assign LCD_D = (select_output) ? secondary_LCD_D : main_LCD_D;
	assign LCD_E = (select_output) ? secondary_LCD_E : main_LCD_E;	
    /* The count register increments until it equals 'compare' */
    always @(posedge clk) begin
        count <= (reset | bell) ? 19'b0 : count + 1;
		display_count <= (reset | display_bell) ? 19'b0 : display_count + 1;
		
    end
    
    /* Time delays for various states */
    always @(*) begin
        case (state)
            INIT_1   			: compare <= 26'd205000;  // 15ms (4.1ms OK due to power-up delay)
            INIT_2   			: compare <= 26'd12;      // 240 ns
            INIT_3   			: compare <= 26'd205000;  // 4.1 ms
            INIT_4   			: compare <= 26'd12;      // 240 ns
            INIT_5   			: compare <= 26'd5000;   // 100 us or longer
            INIT_6   			: compare <= 26'd12;      // 240 ns
            INIT_7   			: compare <= 26'd2000;    // 40  us or longer
            INIT_8   			: compare <= 26'd12;      // 240 ns
            CMD_WAIT 			: compare <= (i != 3'b101)? 26'd2000 : 26'd82000;    // 40 us or 1.64 ms
            U_SETUP  			: compare <= 26'd2;       // 40  ns
            U_ENAB   			: compare <= 26'd12;      // 230 ns
            U_HOLD   			: compare <= 26'd1;       // 10  ns
            UL_WAIT  			: compare <= 26'd50;     // 1   us
            L_SETUP  			: compare <= 26'd2;       // 40  ns
            L_ENAB   			: compare <= 26'd12;      // 230 ns
            L_HOLD   			: compare <= 26'd1;       // 10  ns
			DISPLAY				: compare <= 26'd2088;    // 41560ns setup+enable+hold+wait for display
			DISPLAY_TO_REFRESH 	: compare <= 26'd50_000_000; //1 sec
			default  			: compare <= 26'hxxxxx;
        endcase
    end
	

    /* The main state machine */
    always @(posedge clk) begin
        if (reset) begin
            state <= INIT_1;
        end
        else begin
            case (state)
                INIT_1   : state <= (bell)  ? INIT_2   : INIT_1;
                INIT_2   : state <= (bell)  ? INIT_3   : INIT_2;
                INIT_3   : state <= (bell)  ? INIT_4   : INIT_3;
                INIT_4   : state <= (bell)  ? INIT_5   : INIT_4;
                INIT_5   : state <= (bell)  ? INIT_6   : INIT_5;
                INIT_6   : state <= (bell)  ? INIT_7   : INIT_6;
                INIT_7   : state <= (bell)  ? INIT_8   : INIT_7;
                INIT_8   : state <= (bell)  ? CMD_WAIT : INIT_8;
                CMD_WAIT : state <= (bell)  ? ((i != 3'b101)? U_SETUP : DISPLAY): CMD_WAIT;
                U_SETUP  : state <= (bell)  ? U_ENAB   : U_SETUP;
                U_ENAB   : state <= (bell)  ? U_HOLD   : U_ENAB;
                U_HOLD   : state <= (bell)  ? UL_WAIT  : U_HOLD;
                UL_WAIT  : state <= (bell)  ? L_SETUP  : UL_WAIT;
                L_SETUP  : state <= (bell)  ? L_ENAB   : L_SETUP;
                L_ENAB   : state <= (bell)  ? L_HOLD   : L_ENAB;
				DISPLAY  : state <= (bell_counter == 9'd80)  ? DISPLAY_TO_REFRESH	: DISPLAY;
                L_HOLD   : state <= (bell)  ? CMD_WAIT : L_HOLD;
				DISPLAY_TO_REFRESH : state <= (bell) ? DISPLAY : DISPLAY_TO_REFRESH;
                default  : state <= 5'bxxxxx;
            endcase
        end
    end
    
    /* Combinatorial enable and data assignments */
    always @(posedge clk) begin
		 if (reset) begin
            i <= 3'b000;
			command[1] <= 8'h28;
			command[2] <= 8'h06;
			command[3] <= 8'h0C;
			command[4] <= 8'h01;
			bell_counter <= 6'b0;
			select_output <= 1'b0;
			check_cursor <= 1'b0;
        end
        else 
		begin
			case (state)
				INIT_1   : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000;					 end
				INIT_2   : begin main_LCD_E <= 0; main_LCD_D <= 6'b000011;					 end
				INIT_3   : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000;					 end
				INIT_4   : begin main_LCD_E <= 1; main_LCD_D <= 6'b000011; 					 end
				INIT_5   : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000; 					 end
				INIT_6   : begin main_LCD_E <= 1; main_LCD_D <= 6'b000011; 			 		 end
				INIT_7   : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000; 			 		 end
				INIT_8   : begin main_LCD_E <= 1; main_LCD_D <= 6'b000010;			 		 end
				CMD_WAIT : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000; i <= i+1'b1;		 end
				U_SETUP  : begin main_LCD_E <= 0; main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][7];		 	 
												  main_LCD_D[2] <= command[i][6];		 	 	
												  main_LCD_D[1] <= command[i][5];		 	 	
												  main_LCD_D[0] <= command[i][4];		 	 end								  									  
				U_ENAB   : begin main_LCD_E <= 1; main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][7];		 	 
												  main_LCD_D[2] <= command[i][6];		 	 	
												  main_LCD_D[1] <= command[i][5];		 	 	
												  main_LCD_D[0] <= command[i][4];		 	 end
				U_HOLD   : begin main_LCD_E <= 0; main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][7];		 	 
												  main_LCD_D[2] <= command[i][6];		 	 	
												  main_LCD_D[1] <= command[i][5];		 	 	
												  main_LCD_D[0] <= command[i][4];		 	 end
				UL_WAIT  : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000;					 end
				L_SETUP  : begin main_LCD_E <= 0; main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][3];		 	 
												  main_LCD_D[2] <= command[i][2];		 	 	
												  main_LCD_D[1] <= command[i][1];		 	 	
												  main_LCD_D[0] <= command[i][0];		 	 end
				L_ENAB  : begin main_LCD_E <= 1;  main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][3];		 	 
												  main_LCD_D[2] <= command[i][2];		 	 	
												  main_LCD_D[1] <= command[i][1];		 	 	
												  main_LCD_D[0] <= command[i][0];		 	 end
				L_HOLD  : begin main_LCD_E <= 0;  main_LCD_D[5] <= 0;
												  main_LCD_D[4] <= 0;
												  main_LCD_D[3] <= command[i][3];		 	 
												  main_LCD_D[2] <= command[i][2];		 	 	
												  main_LCD_D[1] <= command[i][1];		 	 	
												  main_LCD_D[0] <= command[i][0];		 	 end
				DISPLAY  : 	begin
								bell_counter <= bell_counter + bell;	
								select_output <= (bell_counter < (9'd80))? 1'b1 : 1'b0;
								if(bell_counter == 9'd80)begin
									check_cursor <= check_cursor + 1'b1;
								end
							end
				DISPLAY_TO_REFRESH: begin bell_counter <= 9'd0;  end
				default  : begin main_LCD_E <= 0; main_LCD_D <= 6'b000000;			 		 end
        endcase
		end
	end
	
	always@(posedge clk) begin
		case (display_state)
			DISPLAY_CMD_WAIT 	: display_compare <= 13'd2000;    // 40  us 
            DISPLAY_U_SETUP  	: display_compare <= 13'd3;       // 60  ns
            DISPLAY_U_ENAB   	: display_compare <= 13'd12;      // 230 ns
            DISPLAY_U_HOLD  	: display_compare <= 13'd1;       // 10  ns
            DISPLAY_UL_WAIT  	: display_compare <= 13'd50;     // 1   us
            DISPLAY_L_SETUP  	: display_compare <= 13'd2;       // 40  ns
            DISPLAY_L_ENAB   	: display_compare <= 13'd12;      // 230 ns
            DISPLAY_L_HOLD   	: display_compare <= 13'd1;      // 20ns 
			DISPLAY_IDLE     	: display_compare <= 13'd0;      // 
			default  	 		: display_compare <= 13'hxxx;
		endcase
	end
	/* The secondary state machine */
	always@(posedge clk or posedge reset)
	begin
		if(reset) begin
			display_state <= DISPLAY_IDLE;
		end
		else
		begin
			case (display_state)
				DISPLAY_IDLE 	 : display_state <= (select_output) ? DISPLAY_U_SETUP  : DISPLAY_IDLE;
				DISPLAY_CMD_WAIT : display_state <= (display_bell)  ? DISPLAY_U_SETUP  : DISPLAY_CMD_WAIT;
                DISPLAY_U_SETUP  : display_state <= (display_bell)  ? DISPLAY_U_ENAB   : DISPLAY_U_SETUP;
                DISPLAY_U_ENAB   : display_state <= (display_bell)  ? DISPLAY_U_HOLD   : DISPLAY_U_ENAB;
                DISPLAY_U_HOLD   : display_state <= (display_bell)  ? DISPLAY_UL_WAIT  : DISPLAY_U_HOLD;
                DISPLAY_UL_WAIT  : display_state <= (display_bell)  ? DISPLAY_L_SETUP  : DISPLAY_UL_WAIT;
                DISPLAY_L_SETUP  : display_state <= (display_bell)  ? DISPLAY_L_ENAB   : DISPLAY_L_SETUP;
                DISPLAY_L_ENAB   : display_state <= (display_bell)  ? DISPLAY_L_HOLD   : DISPLAY_L_ENAB;
                DISPLAY_L_HOLD   : display_state <= (display_bell)  ? ((select_output) ? DISPLAY_CMD_WAIT : DISPLAY_IDLE)  : DISPLAY_L_HOLD;
				
			endcase
		end
	end
	
	/* Combinatorial enable and data assignments */
    always @(posedge clk)
		begin
			case (display_state)
				DISPLAY_CMD_WAIT : begin secondary_LCD_E <= 0; 	secondary_LCD_D <= 6'b000000; 		 end
				DISPLAY_U_SETUP  : begin secondary_LCD_E <= 0; 	secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[7]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[6]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[5];		 	 	
																secondary_LCD_D[0] <= memory[4]-((bell_counter == 9'd55)&&check_cursor);	 end
				DISPLAY_U_ENAB   : begin secondary_LCD_E <= 1;  secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[7]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[6]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[5];		 	 	
																secondary_LCD_D[0] <= memory[4]-((bell_counter == 9'd55)&&check_cursor);	 end
				DISPLAY_U_HOLD   : begin secondary_LCD_E <= 0;  secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[7]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[6]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[5];		 	 	
																secondary_LCD_D[0] <= memory[4]-((bell_counter == 9'd55)&&check_cursor);	 end
				DISPLAY_UL_WAIT  : begin secondary_LCD_E <= 0;  secondary_LCD_D <= 6'b000000;		 end
				DISPLAY_L_SETUP  : begin secondary_LCD_E <= 0;  secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[3]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[2]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[1]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[0] <= memory[0]-((bell_counter == 9'd55)&&check_cursor);	 end
				DISPLAY_L_ENAB   : begin secondary_LCD_E <= 1;  secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[3]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[2]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[1]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[0] <= memory[0]-((bell_counter == 9'd55)&&check_cursor);	 end
				DISPLAY_L_HOLD   : begin secondary_LCD_E <= 0;  secondary_LCD_D[5] <= 1;
																secondary_LCD_D[4] <= 0;
																secondary_LCD_D[3] <= memory[3]-((bell_counter == 9'd55)&&check_cursor);		 	 
																secondary_LCD_D[2] <= memory[2]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[1] <= memory[1]-((bell_counter == 9'd55)&&check_cursor);		 	 	
																secondary_LCD_D[0] <= memory[0]-((bell_counter == 9'd55)&&check_cursor);	 end
				default  : begin secondary_LCD_E <= 0; secondary_LCD_D <= 6'b000000;			 	 end
        endcase
    end
endmodule