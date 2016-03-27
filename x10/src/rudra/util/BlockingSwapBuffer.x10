/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

import x10.util.concurrent.Monitor;
import x10.compiler.Pinned;

import rudra.util.Logger;

/**
   A blocking implementation of SwapBuffer.

   @see rudra.util.SwapBuffer

   @author vj
 */
@Pinned public class BlockingSwapBuffer[T]{T haszero} extends  SwapBuffer[T] {
    protected var datum:T;
    public def this(i:T){
        this.datum=i;
    }

    protected val monitor=new Monitor();
    protected var dataReady:boolean=false; // access must be protected by monitor
    static val logger = new Logger(Logger.ERROR);
    def swap(t:T, b:Boolean):T {
        val result=datum;
        assert t!=result;
        datum=t;
        dataReady=b;
        return result;
    }

    public def needsData():Boolean {
        try {
            monitor.lock();
            return ! dataReady;
        } finally {
            monitor.release();
        }
    }
    public def get(t:T):T{
        try {
            monitor.lock();
            logger.info(()=> this + " get: checking dataReady");
            while (!dataReady) {
                logger.info(()=> this + " get: blocking");
                monitor.await();
                logger.info(()=>this + " get: unblocking");
            }
            return swap(t, false);
        } finally {
            logger.info(()=> this + " get: releasing");
            monitor.release();
        }       
    }

    public def put(t:T):T{
        try {
            monitor.lock();
            logger.info(()=> this + " put: checking dataReady");
            while (dataReady) {
                logger.info(()=> this + " put: blocking");
                monitor.await();
            logger.info(()=> this + " put: unblocking");
            }
            return swap(t, true);
        } finally {
            logger.info(()=> this + " put: releasing");
            monitor.release();
        }       
    }
    public def toString()="<" + typeName() + " #"+hashCode()  + ">";
}
