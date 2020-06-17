interface ffs_arbiter_if#(parameter CLIENTS=16)(input bit clk);
    timeunit 1ns;
    timeprecision 100ps;

    logic rst_n;
    logic [CLIENTS-1:0] req = {CLIENTS{1'b0}};
    logic [CLIENTS-1:0] gnt;

    clocking cb @(posedge clk);
        output #0.1 rst_n, req;
        input gnt;
    endclocking : cb

    modport TB(clocking cb);
endinterface : ffs_arbiter_if

// ========================================================================

module tb;
    timeunit 1ns;
    timeprecision 100ps;

    parameter NUM_REQ=128;

    logic clk;

// instantiate the interface
    ffs_arbiter_if#(.CLIENTS(NUM_REQ)) u_ffs_arbiter_if(.clk(clk));

// instantiate the main program
    main_prg#(.CLIENTS(NUM_REQ)) u_main_prg(.sig_h(u_ffs_arbiter_if));

    initial
        begin
            $dumpfile("dump.vcd");
            $dumpvars(0);
        end

    initial
        begin
            $timeformat(-9, 1, "ns", 8);

            clk = 1'b0;
            forever #5 clk = ~clk;
        end

// instantiate the DUT
    ffs_arbiter#(.CLIENTS(NUM_REQ)) u_ffs_arbiter
                                    (
                                        .clk(clk),
                                        .rst_n(u_ffs_arbiter_if.rst_n),
                                        .req(u_ffs_arbiter_if.req),
                                        .gnt(u_ffs_arbiter_if.gnt)
                                    );

endmodule : tb

// ========================================================================

program automatic main_prg
    import ffs_a_pkg::*;
    #(parameter CLIENTS=64)(ffs_arbiter_if sig_h);

    MyEnv#(.CLIENTS(CLIENTS)) env;

    initial
        begin
            env = new (sig_h);

            sig_h.cb.rst_n <= 1'b0;
            #50 sig_h.cb.rst_n <= 1'b1;

            repeat (20) @(sig_h.cb);

            env.run();

            repeat (300) @(sig_h.cb);
            $finish;
        end

endprogram
