
module whole_cpu (input clk, reset);

   wire [7:0] pc,ir,areg,breg,xreg,qreg,dbus;
   wire `Control controlBits;
   wire aIsZero,flagCarry;

   wire loadIR,storeMem;
   wire assertBarM,assertBarE,assertBarA,assertBarX;
   wire immediate,doSubtract,doJump;

   wire _;
   assign {loadIR,_,_,_,_,_,storeMem,
           assertBarM,assertBarE,_,_,
           immediate,doSubtract,doJump
           } = controlBits;

   rom prog (    (~assertBarM &&  immediate),         pc,dbus);
   ram data (clk,(~assertBarM && !immediate),storeMem,xreg,dbus);

   programCounterNET p (reset,clk,doJump,immediate,dbus,pc);

   fetch_unit_NET f (clk,reset,loadIR,dbus,ir);

   control c (ir,aIsZero,flagCarry,controlBits);

   registersNET registers (reset,clk,controlBits,dbus,areg,breg,xreg,qreg);

   aluNET a (clk,reset,doSubtract,assertBarE,areg,breg,
             dbus,aIsZero,flagCarry);

endmodule