/**
 * PhasedT.x10
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
