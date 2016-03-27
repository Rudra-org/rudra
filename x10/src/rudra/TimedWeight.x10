/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

/** TimedWeight is the same as TimedGradient except that the payload rail is of networkSize
    rather than networkSize+1. It represents a time stamped set of weights for the NN, together
    with  loadSize that represents the number of MB used to compute this weight.
    @author vj
 */
public class TimedWeight(size:Long) implements TimedWeightI { // mutated in place, hence fields are vars.
    public static val POISON=new TimedWeight(0,0un);
    var timeStamp:UInt=0un;
    var loadSize:UInt=0un;
    var weight:Rail[Float] = new Rail[Float](size);
    def this(size:Long){property(size);}
    def this(size:Long, ls:UInt){property(size); loadSize=ls;}

    public def loadSize():UInt=loadSize;
    public def setLoadSize(l:UInt):void{
        loadSize=l;
    }
    public def weightRail() = weight;
    public def timeStamp() = timeStamp;
    public def setTimeStamp(t:UInt):void {
        timeStamp = t;

}
    def calcHash():Float = calcHash(weight);
    public static def calcHash(f:Rail[Float]):Float {
        var result:Float=0.0f;
        for (x in f) result+=x;
        return result/f.size;
    }
    public def toString():String = "<TW #" + hashCode() + " load="+ calcHash()
                          +",size="+ loadSize + ",time="+timeStamp+">";
}
