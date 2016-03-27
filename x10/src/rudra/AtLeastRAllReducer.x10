/**
 * AtLeastRAllReducer.x10
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

package rudra;

import x10.util.Team;

import rudra.util.PhasedT;
import rudra.util.Logger;
import rudra.util.Timer;
import rudra.util.MergingMonitor;

/** Responsible for perfoming an all reduce if at least R 
    contributions, counted globally, are available. R could
    be zero.

    TODO: Improve so that it alwyas implements R>=1 and does without 
    busy waiting.  That is, by blocking  the thread until there is 
    more input from the learner or someone discovers that R 
    contributions are available. (Otherwise the cycling through multiple
    empty allReduces 

    @author vj
 */

public class AtLeastRAllReducer(desiredR:Int, team:Team, logger:Logger, 
                                
                                gCount:GlobalRef[PhasedT[Int]]) {
    var zero: TimedGradient; 

    // The pending contribution, not yet sent out
    // because the threshold has not yet been reached.
    var pending:TimedGradient=null;

    var readyToReduce:Boolean=false;
    var src:TimedGradient=null; // must be non-null if readyToReduce is true

    val allreduceTimer = new Timer("allreduce Time:");

    var phase: UInt=0un; // the local version of the global phase= # allreduces executed

    /**  Initialize with the size used for TimeGradient. 
         Will be used to create a zro TG, if needed.
         Must be called before acceptContrib and reduceIfReady.
         (Cannot be set when object is created because native learners are not initialized
         then, hence size is not known.)
     */

    var size:Long = -1;
    def initialize(size:Long) {
        this.size=size;
    }

    def getPhase():UInt=at (gCount) gCount().getPhase();

    def availableData(myData: Int, phase:UInt):Int  {
        val gc = gCount, src=here.id;
        val r = at (gc.home) gc().availableData(src,myData,phase);
        return r;
    }
    def zero():TimedGradient {
        if (zero == null) {
            zero = new TimedGradient(size);
        }
        return zero;
    }
    public def run(var readyToReduce:Boolean, thisPhase:UInt, s: TimedGradient,
                   mmPLH:PlaceLocalHandle[MergingMonitor],
                   dest:TimedGradient):void {
        assert size >= 0 : "AtLeastRAllReducer: must initialize before use.";
        val count = s.loadSize(), phi = phase;
        if (count > 0un) logger.info(()=>"Reconciler:<- Learner processing "  + s);
        if (desiredR <= 0) { 
            readyToReduce=true;
            src = count==0un ? zero() : s;
        } else {
            if (! readyToReduce) {
                logger.info(()=>"AtleastR: about to invoke availableData, count=" + count);
                readyToReduce = (count as Int) >= desiredR 
                    || availableData(count as Int, phase) >= desiredR;
                if (readyToReduce) // tell others, including urself, but that is ignored.
                    // no need for finish
                    for (p in Place.places()) 
                        at (p) async mmPLH().signalPhase(phase+1un);
            } 
            if (readyToReduce)
                if (pending!= null && pending.loadSize() > 0un) {
                    pending.addIn(s);
                    s.setLoadSize(0un);
                    src = pending;
                } else 
                    src = count==0un? zero() : s;
            else {   // need to pend s, no need to set src
                if (count > 0un) {
                    if (pending != null) pending  = new TimedGradient(size);
                    pending.addIn(s);
                    s.setLoadSize(0un);
                }
            }
        } // if desiredR <= 0
       if (readyToReduce) {
            assert dest.loadSize()==0un :
           "AtLeastRAllReduce: load size of destination " + dest + " must be zero.";
           logger.info(()=>"Entering allreduce with " + src + " at " + phi);
           allreduceTimer.tic();
           team.allreduce(src.grad, 0, dest.grad, 0, size, Team.ADD);
           allreduceTimer.toc();
           if (dest.loadSize() > 0un) phase++;
           dest.timeStamp = phase;
           if (here.id==0) logger.notify(()=>"Reconciler: <- Network "  + dest + "(" + allreduceTimer.lastDurationMillis()+" ms)");
           src.setLoadSize(0un);
           src=null;
       }
       logger.info(()=> "AtLeastRAllReducer: exiting run, s=" + s);
    } // run
}
