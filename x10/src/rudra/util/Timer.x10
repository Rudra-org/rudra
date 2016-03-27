/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

/**
 * A simple timer that represents a sequence of disjoint intervals by
 * their number and the sum of their durations.

 * TODO: Maintain a timed sequence, and generate statistics.

 * @author vj
 */

public class Timer(name:String) {
    public static val secondInMillis = 1000;
    public static val minuteInMillis = 60*secondInMillis;
    public static val hourInMillis= 60*minuteInMillis;

    var count:UInt;
    var duration:Long;
    var lastStart:Long=0;
    var lastEnd:Long=0;

    public static def time(var ms:Long):String {
        var result:String="";
        if (ms <= secondInMillis) return ms + " ms"; 
        if (ms <= minuteInMillis) return String.format("%6.2f s", [(ms /(secondInMillis*1.0f)) as Any]);
        if (ms <= hourInMillis) 
            return String.format("%6.2f m", [(ms /(minuteInMillis*1.0f)) as Any]);
        return String.format("%6.2f h", [(ms / (hourInMillis*1.0f)) as Any]);
    }
    /** Call tic() to start an interval, and toc() to finish an interval.
     */
    public def tic():void{
        lastStart = System.nanoTime();
    }

    public def toc():void{
        lastEnd = System.nanoTime();
        addDuration(lastDuration());
    }

    public def lastDuration():Long= lastEnd-lastStart;
    public def lastDurationMillis():Long= lastDuration()/(1000*1000);
    /** Add an externally taken measurement to this timer.
     */
    public def addDuration(d:Long):void {
        count++;
        duration +=d;
    }
    public def durationMillis():Long = duration / (1000*1000);
    public def toString():String {
        val average = count > 0U ? (durationMillis()/(count as Long)) : 0;
        return "<" + name + " " + count 
                          + " " + durationMillis() + " ms" 
                          + " avg=" + average + ">";
    }
}
