/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

import x10.util.concurrent.Lock;

public class PhasedT[T]{T <: Arithmetic[T]} {
    static val logger = new Logger(Logger.NOTIFY);
    val lock = new Lock(); // reentrant lock
    var count:T;
    var phase:UInt=0un;
    val badT:T;
    public def this(init:T,bad:T) {
        this.count=init;
        this.badT=bad;
    }
    public def getPhase():UInt=phase;
    public def availableData(source:Long, myCount:T, myPhase:UInt):T {
        var result:T=badT;
        try {
            assert myPhase==phase||myPhase==phase+1un 
                : "Phased[T].availableData myPhase=" + myPhase
                + " should be " + phase + " or " + (phase+1un);
            logger.notify(()=>"PhasedT:  available Data source=" + source 
                          + " myCount=" + myCount + " myPhase=" + myPhase);
            lock.lock();
            logger.notify(()=>"PhasedT: got lock");
            if (myPhase==phase) {
                count +=myCount;
                result=count;
            }
            if (myPhase==phase+1un) {
                count = myCount;
	       phase++;
                result=count;
            }
        } finally {
            logger.notify(()=>"PhasedT: releasing lock " + lock);
            lock.unlock();
        }
        val r = result;
        logger.notify(()=>"PhasedT: ad =" + source 
                      + "," + myCount + "," + myPhase + " returns " + r);
        return result;
    }
}
