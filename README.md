# ffs_arbiter
ffs_arbiter is a parameterized arbiter and test bench using find-first-set logic.  The design receives an input
request vector and sends an output grant vector on the subsequent clock cycle with a bit asserted corresponding
to the next-in-line requestor.

Requests are prioritized starting with the most-significant bits in the request vector when starting from an
empty request vector.  Requests are then considered from the upper request bit to the lower request bit in a round-
robin fashion.

design.sv is the main arbiter design file and testbench.sv contains the top-level test bench file.  Naming
convention and file back-tick includes are used for compatibility with simulating on http://edaplayground.com.
Please check out this design on that site where you can run sims and look at waveforms.
