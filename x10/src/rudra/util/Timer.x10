/**
 * Timer.x10
 *
 * Rudra Distributed Learning Platform
 *
 * Copyright (c) IBM Corporation 2016
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * 3. Neither the name of Rudra nor the names of its contributors may be used
 *   to endorse or promote products derived from this software without specific
 *   prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
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
