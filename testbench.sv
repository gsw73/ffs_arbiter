`define MIN(A, B) ((A) < (B) ? (A) : (B))

typedef bit [ 31:0 ] uint32_t;
typedef enum { FAIL, PASS } pf_e;

`include "my_classes.sv"

// ========================================================================

interface ffs_arbiter_if
#(
    parameter CLIENTS = 16
)
(
    input bit clk
);
    logic rst_n;
    logic [ CLIENTS - 1:0 ] req = {CLIENTS{1'b0}};
    logic [ CLIENTS - 1:0 ] gnt;

    clocking cb @( posedge clk );
        default output #0.1;

        output rst_n;
        output req;
        input gnt;
    endclocking : cb

    modport TB( clocking cb );
endinterface : ffs_arbiter_if

// ========================================================================

module tb;

parameter NUM_REQ = 128;

logic clk;

// instantiate the interface
ffs_arbiter_if
#(
    .CLIENTS( NUM_REQ )
)
u_ffs_arbiter_if
(
    .clk( clk )
);

// instantiate the main program
main_prg #( .CLIENTS( NUM_REQ ) ) u_main_prg( .i_f( u_ffs_arbiter_if ) );

initial
begin
    $dumpfile( "dump.vcd" );
    $dumpvars( 0 );
end

initial
begin
    $timeformat( -9, 1, "ns", 8 );

    clk = 1'b0;
    forever #5 clk = ~clk;
end

// instantiate the DUT
ffs_arbiter
#(
    .CLIENTS( NUM_REQ )
)
u_ffs_arbiter
(
    .clk( clk ),
    .rst_n( u_ffs_arbiter_if.rst_n ),
    .req( u_ffs_arbiter_if.req ),
    .gnt( u_ffs_arbiter_if.gnt )
);

endmodule

// ========================================================================

program automatic main_prg #( parameter CLIENTS = 64 )( ffs_arbiter_if i_f );

MyEnv#(.CLIENTS(CLIENTS)) env;
virtual ffs_arbiter_if#(CLIENTS).TB sig_h = i_f.TB;

initial
begin
    env = new( sig_h );
  
    sig_h.cb.rst_n <= 1'b0;
    #50 sig_h.cb.rst_n <= 1'b1;

    repeat( 20 ) @( sig_h.cb );

    env.run();

    repeat( 300 ) @( sig_h.cb );
    $finish;
end

endprogram
