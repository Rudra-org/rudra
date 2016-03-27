/**
 * BlockingRXchgBuffer.x10
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

import x10.compiler.Pinned;

/**
   A very specialized non-blocking one-place swapping buffer which communicates 
   values of type T between a producer and a consumer without consing any new 
   values or copying values. Used to couple producers and consumers that operate
   at different rates. A put always puts its value in the buffer, updating the 
   previous value. Never blocks. A get blocks until there is a value.

   @author vj
 */
@Pinned public class BlockingRXchgBuffer[T]{T isref}  extends SwapBuffer[T] {
    protected var hasData:Boolean=false;
    protected var datum:T;
    protected val monitor = new Monitor();
    public def this(v:T){
        datum = v;
    }

    def swap(v:T):()=>T = ()=>{
        val r = datum;
        datum = v;
        r
    };
    public def needsData():Boolean = monitor.atomicBlock[Boolean](()=> ! hasData);
    /* Blocking get, returns only when a value has been placed 
       in the buffer that has not yet been returned.
     */
    public def get(v:T):T = monitor.on (()=>hasData, () => {
            val r = datum;
            datum = v;
            hasData =false;
            r
        });

    /** Non-blocking put, updates the value in the buffer in place.
     */
    public def put(v:T):T = monitor.atomicBlock(()=> {
            val r = datum;
            datum = v;
            hasData = true;
            r
        });

    public def toString()="<" + typeName() + " #"+hashCode()  + ">";
}
