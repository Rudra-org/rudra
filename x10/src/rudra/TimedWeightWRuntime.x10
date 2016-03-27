/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

/** TimedWeight is the same as TimedWeight except that it has an additional runtime field.
    @author vj
 */
public class TimedWeightWRuntime extends TimedWeight { // mutated in place, hence fields are vars.
    public static val POISON=new TimedWeightWRuntime(0,0un);
    var runtime:Long=0;
    public def setRuntime(r:Long):void {
        this.runtime=r;
    }
    public def this(size:Long) {
        super(size);
    }
    public def this(size:Long, ls:UInt) {
        super(size, ls);
    }
    public def toString():String = "<TW #" + hashCode() + " load="+ calcHash()
                          +",size="+ loadSize + ",time="+timeStamp+",runtime=" + runtime+">";
}
