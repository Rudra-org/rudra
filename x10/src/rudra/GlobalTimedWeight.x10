/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

public class GlobalTimedWeight(networkSize:Long) implements TimedWeightI { // mutated in place, hence fields are vars.
    var timeStamp:UInt=0un;
    var size:UInt=0un;
    var weight:GlobalRail[Float] = GlobalRail(new Rail[Float](networkSize));
    public def weightRail():Rail[Float]=weight();
    public def loadSize():UInt=size;
    public def setLoadSize(l:UInt):void{
        size=l;
    }
    public def timeStamp():UInt = timeStamp;
    public def setTimeStamp(u:UInt):void {
        timeStamp=u;
    }
    def calcHash():Float{
        var result:Float=0.0f;
        val wweight = weight();
        for (x in wweight) result+=x;
        return result/wweight.size;
    }
    public def toString():String = 
         (here==weight.rail.home)
       ? ("<GTG #" + hashCode()+" load="+ calcHash()+", size="+loadSize()+", time="+timeStamp+">" )
       : ("<Remote GTG #" + hashCode()+ " home=" + weight.rail.home + ", time="+timeStamp+">");

}
