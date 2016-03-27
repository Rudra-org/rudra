/**
 * MergingMonitor.x10
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

import x10.io.Unserializable;
import x10.compiler.Pinned;

/**
  Coordinates the activities of three parties: two notifiers and one recipient. 
  The two notifiers invoke signal* methods which set some data on the object
  and signal the recipient. The recipient can wait for a communication from
  either of the two notifiers. 

  In this specific case, one of the notifiers will check and set the phase,
 and the other will set a boolean to true. 

  TODO: Make this functionaity more generic. It is basically intended to 
  be the GOF Kahn merge node.

  @author vj

 */
@Pinned public class MergingMonitor extends Monitor implements Unserializable {
    var phase:UInt=0un;
    var dataReady:Boolean=false;
    val logger = new Logger(Logger.ERROR);
    public def this() {
        super(false);
    }
    public def signalPhase(d:UInt) {
        atomicBlock(() => {
                if (phase+1un==d) phase++;
                else logger.warning("MergingMonitor: in phase " + phase 
                                    + " ignored awaken for phase " + d);
                Unit()
            });
    }
    public def signalData() {
        atomicBlock(() => {
                dataReady=true;
                Unit()
            });
    }
    public def await(myPhase:UInt):UInt {
        return on[UInt](()=> dataReady || myPhase+1un==phase, 
                        ()=> {
                            dataReady = false;
                            phase
                        });
    }
}
