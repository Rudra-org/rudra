/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

public class GlobalTimedGradient(size:Long) { // mutated in place, hence fields are vars.
    var timeStamp:UInt=0un;
    var grad:GlobalRail[Float] = GlobalRail(new Rail[Float](size));
    def loadSize():UInt=grad()(size-1) as UInt;
    def setLoadSize(l:UInt):void{
        grad()(size-1)=l as Float;
    }
    def addIn(g:TimedGradient):void {
        val ggrad=grad();
        assert size==g.size  : "TimedGradients of different sizes?!?!";
        for (i in  0..(size-1)) ggrad(i) += g.grad(i);
    }
    def calcHash():Float{
        var result:Float=0.0f;
        val ggrad = grad();
        for (x in ggrad) result+=x;
        return result/ggrad.size;
    }
    public def toString():String = 
         (here==grad.rail.home)
       ? ("<GTG #" + hashCode()+" load="+ calcHash()+", size="+loadSize()+", time="+timeStamp+">" )
       : ("<Remote GTG #" + hashCode()+ " home=" + grad.rail.home + ", time="+timeStamp+">");

}
