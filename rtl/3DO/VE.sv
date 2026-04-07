module VE
(
	input              MCLK,
	input              VCLK,
	input              RST_N,
	input              EN,
	
	input              VCE,
	input      [23: 0] AD,
	input              DE,
	output             HSYNC_N,
	output             VSYNC_N,
	
	output     [23: 0] RGB,
	output             HS_N,
	output             VS_N,
	output             HBLK_N,
	output             VBLK_N,
	output             DCLK,
	
	input      [ 7: 0] DBG_EXT,
	input              DBG_BORD_DIS,
	output     [ 9: 0] DBG_HS_START,DBG_HS_END
);

	bit  VRST_N;
	always @(posedge VCLK) begin
		VRST_N <= RST_N;
	end 
	
	bit  [ 1: 0] DCLK_DIV;
	always @(posedge VCLK or negedge VRST_N) begin
		if (!VRST_N) begin
			DCLK_DIV <= '0;
		end
		else begin
			DCLK_DIV <= DCLK_DIV + 2'd1;
		end
	end 
	
	wire [ 9: 0] HBLANK_START = 10'd58 + 10'd16 + 10'd640;
	wire [ 9: 0] HBLANK_END = 10'd58 + 10'd16;
	
	bit  [ 9: 0] LINE_BUF_RPOS;
	bit          HSTART,VSTART;
	bit  [ 9: 0] HCNT;
	bit  [ 8: 0] VCNT;
	bit          HSYNC;
	bit          VSYNC;
	bit          HBLK;
	bit          VBLK;
	always @(posedge VCLK or negedge VRST_N) begin		
		if (!VRST_N) begin
			{HSTART,VSTART} <= '0;
			LINE_BUF_RPOS <= '0;
			HCNT <= '0;
			VCNT <= '0;
			HSYNC <= 1;
			VSYNC <= 1;
			DBG_HS_START <= 10'd733;
			DBG_HS_END <= 10'd11;
		end
		else begin
			if (DCLK_DIV == 2'd3) begin
				LINE_BUF_RPOS <= LINE_BUF_RPOS + 10'd1;
					
				HCNT <= HCNT + 10'd1;
				{HSTART,VSTART} <= '0;
				if (HCNT == 10'd780 - 1) begin
					HSTART <= 1;
					HCNT <= '0;
					
					VCNT <= VCNT + 9'd1;
					if (VCNT == 9'd262 - 1) begin
						VSTART <= 1;
					end
					if (VCNT == 9'd263 - 1) begin
						VCNT <= '0;
						VSYNC <= 1;
					end
					if (VCNT == 9'd3 - 1) begin
						VSYNC <= 0;
					end
					
					if (VCNT == 9'd22 + 9'd240 - 1) begin
						VBLK <= 1;
					end
					if (VCNT == 9'd22 - 1) begin
						VBLK <= 0;
					end
				end
				
				if (HCNT == (DBG_HS_START - 10'd1)) begin
					HSYNC <= 1;
				end
				if (HCNT == (DBG_HS_END - 10'd1)) begin
					HSYNC <= 0;
				end
				
				if (HCNT == HBLANK_START - 1) begin
					HBLK <= 1;
				end
				if (HCNT == HBLANK_END - 1) begin
					HBLK <= 0;
					LINE_BUF_RPOS <= '0;
				end
			end
		end
	end 
	assign HS_N = ~HSYNC;
	assign VS_N = ~VSYNC;
	assign HBLK_N = ~HBLK;
	assign VBLK_N = ~VBLK;
	assign DCLK = (DCLK_DIV == 2'd3);
	
	
	bit  [ 2: 0] HSTART_SYNC,VSTART_SYNC;
	always @(posedge MCLK) begin
		HSTART_SYNC <= {HSTART_SYNC[1:0],HSTART};
		VSTART_SYNC <= {VSTART_SYNC[1:0],VSTART};
	end
	
	bit  [ 9: 0] LINE_BUF_WPOS;
	bit  [ 9: 0] HCNT2;
	bit  [ 8: 0] VCNT2;
	bit          HSYNC2;
	bit          VSYNC2;
	bit          EMPTY_DE;
	always @(posedge MCLK or negedge RST_N) begin
		bit          HCNT_RES,VCNT_RES;
		bit          DOT_CE;
		bit          EMPTY_LINE;
	
		if (!RST_N) begin
			LINE_BUF_WPOS <= '0;
			HCNT2 <= '0;
			VCNT2 <= '0;
			HSYNC2 <= 1;
			VSYNC2 <= 1;
		end
		else if (EN) begin
			if (VCE) begin
				EMPTY_DE <= 0;
				if (EMPTY_LINE && HCNT2 >= 10'd128 && HCNT2 < (10'd128+10'd640)) begin
					LINE_BUF_WPOS <= HCNT2 - 10'd128;
					EMPTY_DE <= 1;
				end
				else if (DE) begin
					LINE_BUF_WPOS <= LINE_BUF_WPOS + 10'd1;
					EMPTY_LINE <= 0;
				end
			
				DOT_CE <= ~DOT_CE;
				if (DOT_CE) begin
					HCNT2 <= HCNT2 + 10'd1;
					if (HCNT_RES) begin
						HCNT_RES <= 0;
						HCNT2 <= '0;
						HSYNC2 <= 1;
						
						VCNT2 <= VCNT2 + 9'd1;
						if (VCNT_RES) begin
							VCNT_RES <= 0;
							VCNT2 <= '0;
							VSYNC2 <= 1;
						end
						if (VCNT2 == 9'd3 - 1) begin
							VSYNC2 <= 0;
						end
					end
					if (HCNT2 == 10'd58 - 1) begin
						HSYNC2 <= 0;
					end
				end
			end
			
			if (HSTART_SYNC == 3'b011) begin
				LINE_BUF_WPOS <= '0;
				EMPTY_LINE <= 1;
				DOT_CE <= 1;
				HCNT_RES <= 1;
				VCNT_RES <= |VSTART_SYNC;
			end
			
		end
	end 
	assign HSYNC_N = ~HSYNC2;
	assign VSYNC_N = ~VSYNC2;

	
	VE_LINE_BUF LINE_BUF
	(
		.CLK0(MCLK),
		.ADDR0({VCNT2[0],LINE_BUF_WPOS}),
		.DATA0(AD),
		.WREN0((DE | EMPTY_DE) & EN & VCE),
		.Q0(),
		
		.CLK1(VCLK),
		.ADDR1({VCNT[0],LINE_BUF_RPOS}),
		.DATA1('0),
		.WREN1(0),
		.Q1(RGB)
	);
	

endmodule
