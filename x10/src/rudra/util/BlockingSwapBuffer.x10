/**
 * BlockingSwapBuffer.x10
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
