 // Part 2 skeleton

module sokoban
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		SW,
		KEY,							// On Board Keys
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input [9:0] SW;
	input	[3:0]	KEY;					
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = SW[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [5:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
		defparam VGA.BACKGROUND_IMAGE = "back.mif";
		
		
	wire loadEN, cleanEN, plotEN, cleanDONE, plotDONE;
	
	controlPath(
		.resetn(resetn), 
		.CLOCK_50(CLOCK_50), 
		.cleanDONE(cleanDONE), 
		.plotDONE(plotDONE),
		.KEY(KEY), 
		.loadEN(loadEN), 
		.cleanEN(cleanEN), 
		.plotEN(plotEN));	
			
	dataPath(
		.resetn(resetn), 
		.x(x), 
		.y(y), 
		.colour(colour), 
		.writeEn(writeEn), 
		.CLOCK_50(CLOCK_50),  
		.cleanDONE(cleanDONE), 
		.plotDONE(plotDONE), 
		.loadEN(loadEN), 
		.cleanEN(cleanEN), 
		.plotEN(plotEN), 
		.KEY(KEY));
	
endmodule


module controlPath(resetn, CLOCK_50, cleanDONE, plotDONE, KEY, loadEN, cleanEN, plotEN);
	
	input resetn, CLOCK_50, cleanDONE, plotDONE;
	input [3:0] KEY; 
	output reg loadEN, cleanEN, plotEN;
	reg [5:0] current_state, next_state;

	localparam  S_LOAD      = 5'd0,
					S_CLEAN		= 5'd1,
					S_PLOT      = 5'd2;
					
	always@(*)
	begin: state_table
		case (current_state)
			S_LOAD: begin
				if (KEY == 4'b1111)	next_state = S_LOAD;
				else 						next_state = S_CLEAN;
			end
			S_CLEAN: next_state = cleanDONE ? S_PLOT: S_CLEAN;
			S_PLOT: next_state = (plotDONE & KEY==4'b1111) ? S_LOAD : S_PLOT;
			default: next_state = S_LOAD;
		endcase
	end // state_table
	
	always @(*)
   begin: enable_signals
		loadEN = 0;
		cleanEN = 0;
		plotEN = 0;
      case (current_state)
			S_LOAD: 	loadEN = 1;
			S_CLEAN: cleanEN = 1;
			S_PLOT: 	plotEN = 1;
      endcase
	end // enable_signals
	
	always@(posedge CLOCK_50)
   begin: state_FFs
		if(!resetn)		current_state <= S_LOAD;
		else				current_state <= next_state;
   end // state_FFS

endmodule 


module dataPath(resetn, x, y, colour, writeEn, CLOCK_50, cleanDONE, plotDONE, 
	loadEN, cleanEN, plotEN, KEY);
	
	input resetn, CLOCK_50;
	input [3:0] KEY;
	output reg writeEn, cleanDONE, plotDONE;
	input loadEN, cleanEN, plotEN;
	reg finish = 1'b0;
	output reg [7:0] x = 8'b0;
	output reg [6:0] y = 7'b0;
	output reg [5:0] colour = 3'b0; 
	
	reg[2:0] charax = 3'd3;
	reg[2:0] charay = 3'd2;
	reg[4:0] direc = 4'b0;
	reg[8:0] plottingCount = 9'b0;
	
	localparam 	chara_initPos_x = 3'd3,
					chara_initPos_y = 3'd2,
					image_size = 8'b11111111,
					white = 6'b111111,
					black = 6'b000000;

	always@(posedge CLOCK_50) begin
		if (!resetn) begin
			charax <= chara_initPos_x;
			charay <= chara_initPos_y;
			x <= 8'd0;
			y <= 7'd0;
			plottingCount <= 9'b0;
			finish <=0;
         writeEn <= 0;
			direc <= 0;
		end
		
		else begin
			finish <= 0;
			cleanDONE <= 0;
			plotDONE <= 0;
			
			if (loadEN) begin
				plotDONE <= 0;
				x <= charax * 16;
				y <= charay * 16;
				direc <= KEY;
				plottingCount <= 0;
			end
			
			if (cleanEN) begin
				x <= charax * 16 + plottingCount[7:4];
				y <= charay * 16 + plottingCount[3:0];
				plottingCount <= plottingCount + 1'b1;
				colour <= black;
				writeEn <= 1'b1;
				if (plottingCount == image_size+1) begin
					writeEn <= 0;
					plottingCount <= 9'b0;
					cleanDONE <= 1;
					case(direc)
						4'b1110:	charax <= charax + 1;
						4'b1101:	charay <= charay + 1;
						4'b1011:	charay <= charay - 1;
						4'b0111:	charax <= charax - 1;
						default: charax <= charax;
					endcase
				end
			end
		
			if (plotEN) begin
				x <= charax * 16 + plottingCount[7:4];
				y <= charay * 16 + plottingCount[3:0];
				plottingCount <= plottingCount + 1'b1;
				colour <= white;
				writeEn <= 1'b1;
				if (plottingCount == image_size+1) begin
					writeEn <= 0;
					plottingCount <= 9'b0;
					plotDONE <= 1;
				end
			end
		end
	end
	
endmodule 

/*
module drawing(init_x, init_y, x, y, colour_in, colour_out, size, finish, writeEn);

	input [7:0] init_x;
	input [6:0] init_y;
	output reg [7:0] x;
	output reg [6:0] y;
	input [5:0] colour_in;
	output reg [5:0] colour_out;
	input [7:0] size;
	reg [7:0] plotCount = 8'b0;
	output reg finish, writeEn;

	x <= init_x + plotCount[7:4];
	y <= init_y + plotCount[3:0];
	plotCount <= plotCount + 1'b1;
	colour_out <= colour_in;
	finish <= 1'b0;
	writeEn <= 1'b1;
	if (plotCount == size) begin begin
		finish <= 1;
		writeEn <= 0;
		plotCount <= 8'b0;
	end
 
endmodule 
*/
