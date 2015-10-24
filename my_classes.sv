// =======================================================================

class Agnt #( parameter CLIENTS = 8 );

    mailbox mbxA2D;
    mailbox mbxD2A;
    mailbox mbxA2SB;

    function new( mailbox a2d, mailbox d2a, mailbox a2sb );
        this.mbxA2D = a2d;
        this.mbxD2A = d2a;
        this.mbxA2SB = a2sb;
    endfunction

    task run();

    endtask

endclass

// =======================================================================

class Driver #( parameter CLIENTS = 10 );

    mailbox mbxA2D;
    mailbox mbxD2A;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;

    function new( mailbox a2d, mailbox d2a, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxA2D = a2d;
        this.mbxD2A = d2a;
        sig_h = s;
    endfunction

    task run();

    endtask

endclass

// =======================================================================

class Monitor #( parameter CLIENTS = 4 );

    mailbox mbxM2SB;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;

    function new( mailbox m2sb, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxM2SB = m2sb;
        sig_h = s;
    endfunction

    task run();

    endtask

endclass

// =======================================================================

class ScoreBoard #( parameter CLIENTS = 4 );

    mailbox mbxA2SB;
    mailbox mbxM2SB;

    function new( mailbox a2sb, mailbox m2sb );
        this.mbxA2SB = a2sb;
        this.mbxM2SB = m2sb;
    endfunction

    task run();

    endtask;

endclass

// =======================================================================

class MyEnv #( parameter CLIENTS = 4 );

    Agnt#(CLIENTS) agnt;
    Driver#(CLIENTS) drv;
    Monitor#(CLIENTS) mon;
    ScoreBoard#(CLIENTS) scb;

    mailbox mbxA2D;
    mailbox mbxD2A;
    mailbox mbxA2SB;
    mailbox mbxM2SB;

    function new( virtual ffs_arbiter_if#(CLIENTS).TB s );
        mbxA2D = new();
        mbxD2A = new();
        mbxA2SB = new();
        mbxM2SB = new();

        agnt = new( .a2d( mbxA2D ), .d2a( mbxD2A ), .a2sb( mbxA2SB ) );
        drv = new( .a2d( mbxA2D ), .d2a( mbxD2A ), .s( s ) );
        mon = new( .m2sb( mbxM2SB ), .s( s ) );
        scb = new( .a2sb( mbxA2SB ), .m2sb( mbxM2SB ) );
    endfunction

    task run();
    fork
        agnt.run();
        drv.run();
        mon.run();
        scb.run();
    join_none
    endtask

endclass
