
module registers
  (input reset, clk, input `Control controlBits, inout [7:0] dbus,
   output [7:0] areg, breg, xreg, qreg);

   wire _;
   wire loadA,loadB,loadX,loadQ;
   wire assertA,assertX;

   assign {_,_,loadA,loadB,loadX,loadQ,_,
           _,_,assertA,assertX,
           _,_,_} = controlBits;

   GPR A(clk,reset,loadA,dbus,areg);
   GPR B(clk,reset,loadB,dbus,breg);
   GPR X(clk,reset,loadX,dbus,xreg);
   GPR Q(clk,reset,loadQ,dbus,qreg);

   assign dbus = assertA ? areg : 'z;
   assign dbus = assertX ? xreg : 'z;

endmodule

module GPR(input clk,reset,load,
           input [7:0] data,
           output reg [7:0] contents);

   always #1 if (reset) contents = 0;
   always @(posedge clk) if (load) contents <= data;

endmodule
