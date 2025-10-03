`timescale 1ps / 1ps

module tb_qpsk_costas_loop();

// Parameters
parameter IQ_WIDTH = 16;
parameter CLOCK_PERIOD_PS = 32552;   // 30.72 MHz period
parameter HALF_CLOCK_PERIOD_PS = 16276;
parameter TOTAL_SAMPLES = 131072;    // Fixed number of samples

// Signals
reg clk;
reg signed [IQ_WIDTH-1:0] I_in;
reg signed [IQ_WIDTH-1:0] Q_in;
wire signed [IQ_WIDTH-1:0] I_out;
wire signed [IQ_WIDTH-1:0] Q_out;

// Sample memory
reg signed [IQ_WIDTH-1:0] I_mem [0:TOTAL_SAMPLES-1];
reg signed [IQ_WIDTH-1:0] Q_mem [0:TOTAL_SAMPLES-1];


// DUT instantiation
qpsk_costas_loop #(
    .IQ_WIDTH(IQ_WIDTH),
    .ACC_WIDTH(32),
    .LUT_DEPTH(1024),
    .PHASE_BITS(10),
    .Kp(16'h6480),
    .Ki(16'h0048))
dut (
    .clk(clk),
    .I_in(I_in),
    .Q_in(Q_in),
    .I_out(I_out),
    .Q_out(Q_out)
);


// Generate 30.72 MHz clock
initial begin
    clk = 0;
    forever #HALF_CLOCK_PERIOD_PS clk = ~clk;
end

// Initialize waveform dumping
initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_qpsk_costas_loop);
end

// Load input files and run simulation
initial begin
    // Read input data files
    $readmemh("I_data_R_64_1_0.mem", I_mem);
    $readmemh("Q_data_R_64_1_0.mem", Q_mem);
    
    // Initialize inputs
    I_in = 0;
    Q_in = 0;
    #100;  // Short initial delay
    
    // Feed all 131072 samples
    for (integer i = 0; i < TOTAL_SAMPLES; i = i+1) begin
        @(posedge clk);
       
        I_in <= I_mem[i];
        Q_in <= Q_mem[i];
    end
    
    // Capture 100 additional cycles
    repeat(100) @(posedge clk);
    $finish;
end

endmodule