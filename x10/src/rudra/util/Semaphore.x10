/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

public class Semaphore extends Monitor {
    var datum:Int=0n;
    public def this() {
        super(false);
    }

    public def signal() {
        atomicBlock(()=> {
                this.datum=1n;
                Unit()
            });
    }
    public def wait() = on(()=> this.datum>0n, ()=>{this.datum=0n;Unit()});
            
}
