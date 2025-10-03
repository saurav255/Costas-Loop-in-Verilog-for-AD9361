module qpsk_costas_loop #(
    parameter integer IQ_WIDTH   = 16,             // Input/output bit width
    parameter integer ACC_WIDTH  = 32,             // Phase accumulator width
    parameter integer LUT_DEPTH  = 1024,           // Sine/Cos LUT size
    parameter integer PHASE_BITS = 10,             // log2(LUT_DEPTH)
    parameter signed [IQ_WIDTH-1:0] Kp  = 16'h1000,  // Loop filter P gain (Q1.15)
    parameter signed [IQ_WIDTH-1:0] Ki  = 16'h0400   // Loop filter I gain (Q1.15)
)(
    input  wire                        clk,
    input  wire signed [IQ_WIDTH-1:0]  I_in,
    input  wire signed [IQ_WIDTH-1:0]  Q_in,
    output wire signed [IQ_WIDTH-1:0]  I_out,
    output wire signed [IQ_WIDTH-1:0]  Q_out
);
 
    reg [ACC_WIDTH-1:0] phase_acc = 32'h10000000;  // Initial phase 
    wire [PHASE_BITS-1:0] addr = phase_acc[ACC_WIDTH-1 : ACC_WIDTH - PHASE_BITS];

    // Sin/Cos LUT
    reg signed [IQ_WIDTH-1:0] cos_lut [0:LUT_DEPTH-1];
    reg signed [IQ_WIDTH-1:0] sin_lut [0:LUT_DEPTH-1];

    initial begin
        $readmemh("cosine_lut.mem", cos_lut);
        $readmemh("sine_lut.mem", sin_lut);
    end

    // NCO output
    wire signed [IQ_WIDTH-1:0] cos_val = cos_lut[addr];
    wire signed [IQ_WIDTH-1:0] sin_val = sin_lut[addr];

    // Derotation
    wire signed [2*IQ_WIDTH-1:0] I_mix = (I_in * cos_val) + (Q_in * sin_val);
    wire signed [2*IQ_WIDTH-1:0] Q_mix = (Q_in * cos_val) - (I_in * sin_val);

    // Scaling down to 16 bits
    assign I_out = I_mix >>> (IQ_WIDTH - 1); 
    assign Q_out = Q_mix >>> (IQ_WIDTH - 1);

    // Phase error computation using: I*Q * (I² - Q²)
    wire signed [2*IQ_WIDTH-1:0] I_scaled = I_out;
    wire signed [2*IQ_WIDTH-1:0] Q_scaled = Q_out;

    wire signed [2*IQ_WIDTH:0] IQ_mul = I_scaled * Q_scaled;
    wire signed [2*IQ_WIDTH:0] I_sq   = I_scaled * I_scaled;
    wire signed [2*IQ_WIDTH:0] Q_sq   = Q_scaled * Q_scaled;
    wire signed [2*IQ_WIDTH+1:0] diff = I_sq - Q_sq;

    wire signed [4*IQ_WIDTH:0] phase_error = IQ_mul * diff;

    // Register for integrator
    reg signed [4*IQ_WIDTH-1:0] phase_integ = 0;

    // Loop filter and phase update
    wire signed [4*IQ_WIDTH-1:0] p_term = (Kp * (phase_error >>> (IQ_WIDTH - 2)));
    wire signed [4*IQ_WIDTH-1:0] i_term = (Ki * (phase_integ >>> (IQ_WIDTH - 2)));

    always @(posedge clk) begin
        // Update integrator
        phase_integ <= phase_integ + (phase_error >>> (IQ_WIDTH - 2));

        // Update NCO
        phase_acc <= phase_acc + ((p_term + i_term) >>> (IQ_WIDTH - 1));
    end

endmodule
