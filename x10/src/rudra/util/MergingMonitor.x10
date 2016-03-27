/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
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
