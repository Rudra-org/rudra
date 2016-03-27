/**
 * Monitor.x10
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
import x10.xrx.Worker;
import x10.xrx.Runtime;

/**
 * A monitor may be used to ensure atomic execution of conditional code
 * blocks by multiple activities executing simultaneously.
 * Exposes a declarative (condition, action) model to the application programmer so 
 * that s/he does not have to directly confront await / notify / and 
 * the while loop for conditions.
 * @author vj
 */
public class Monitor(increase:Boolean) {
    protected val lock = new Lock();
    protected val threads = new Rail[Worker](x10.xrx.Runtime.MAX_THREADS);
    protected var size:Int = 0n;
    protected val logger = new Logger(Logger.ERROR);
    
    public def this() { this(true);}
    public def this(b:Boolean) { property(b);}

    protected def lock() {
	    lock.lock();
    }

    protected def unlock() { lock.unlock();}
    
    static val TRUE = ()=>true;
    static val NOTHING = ()=>Unit();
    
    /**
     * Awaken all activities, if any, waiting on this monitor. Typically
     * used when some condition has been set (such as a stream being
     * closed) which will be checked by the awakened activities.
     */
    public def awaken() { on(TRUE, NOTHING); }
    /**
     * Await this condition on the monitor.
     */
    public def await(cond:()=>Boolean) { on(cond, NOTHING);}
    /**
     * Perform this action atomically with respect to all other 
     * actions executing on this monitor.
     */
    public def atomicBlock[T](action:()=>T):T =on(TRUE, action);

    /**
     * The primary work horse of the monitor. An activity executing this
     * method will block until such time as cond evaluates to true. It
     * will then execute action.  
     * 
     * <p> cond should be side-effect free; it may be evaluated an unknown number
     * of times. However, action() will be evaluated only once.
     * <p> The last execution of cond and the execution of action are guaranteed 
     * to be done in a single step wtih respect to any other 
     * <tt>on</tt> operations on this monitor. 
     * 
     */
    public def on[T](cond:()=>Boolean, action:()=>T):T {
	try {
        // When an activity blocks, its underlying thread will block, with FJ
        // scheduling. Therefore tell the runtime to ensure that there is another
        // thread available to execute asyncs.
        if (increase) Runtime.increaseParallelism();
        lock();
        logger.info(() => "Monitor: "+ this +  " 0 trying cond " + cond);
        
        while (!cond()) {
            val thisWorker = Runtime.worker();
            val s = size;
            threads(size++)=thisWorker; 
            while(threads(s)==thisWorker) {
                logger.info(suspending);
                unlock();
                Worker.park();
                logger.info(retrying);
                lock();
            }
        }
        if (increase) Runtime.decreaseParallelism(1n);
	    logger.info(()=>"Monitor: " + this  + " 1 action " + action);
	    val result=action();
	    // now awaken everyone to try.
	    val m=size;
	    logger.info(() => "Monitor : " + this + " 2 awakening size=" + m);
	    for (var i:Int = 0n; i<m; ++i) {
		size--;
		logger.info((i:Int)=> "Monitor: " + this + " 3 (" + i + ") waking " 
			     +  threads(size).toString(), i);
		threads(size).unpark();
		threads(size)=null;
	    }
	    logger.info(() => "Monitor: " + this + " 4 done.");
	    return result;
	} finally {
	    unlock();
	}
    }
    static val waking = (t:String)=> "Monitor: waking " + t;
    static val trying = ()=>"Monitor: Trying cond ";
    static val retrying = ()=>"Monitor: Retrying cond ";
    static val suspending = ()=>"Monitor: Suspending. ";
    static val acting = ()=>"Monitor: Trying action.";
    static val finished = ()=>"Monitor: done";
}
