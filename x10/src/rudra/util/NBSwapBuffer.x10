/**
 * NBSwapBuffer.x10
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

import x10.compiler.Volatile;

import x10.util.concurrent.AtomicBoolean;
import x10.compiler.Pinned;

/**
   A very specialized non-blocking one-place swapping buffer which communicates 
   values of type T between a producer and a consumer without consing any new 
   values or copying values. Used to couple producers and consumers that operate
   at different rates. 

   @see rudra.util.SwapBuffer

   @author vj
 */
@Pinned public class NBSwapBuffer[T]{T haszero} extends SwapBuffer[T] {
    @Volatile protected var datum:T;
    public def this(i:T){
        this.datum=i;
    }

    /** Set by the writer, when the data is ready to be read from index+1. 
     * Reset by the reader when it reads the data.
     */
    protected val dataReady=new AtomicBoolean(false);

    def swap(t:T, b:Boolean):T {
        val result=datum;
        assert t!=result;
        datum=t;
        dataReady.set(b);
        return result;
    }

    public def needsData():Boolean=!dataReady.get();
    /** Non-blocking call. If no value is available to read return t 
        (the caller should think that a zero value was returned).
        Otherwise return the available value (guaranteed to not 
        equal t), and signal that data is needed. 
     */
    public def get(t:T):T= dataReady.get()? swap(t,false):t;

    /** Non-blocking call. If there is no space return t with no modifications; 
        the caller may continue to use t. Else add t to the buffer signal 
        that data is ready, and return the old value s. Note s is not zeroed,
        it is the caller's responsibility to write application data in it
        before reading. The caller must check the return value to determine
        which of these two cases apply.
     */

    public def put(t:T):T = dataReady.get()? t: swap(t, true);
    public def toString()="<" + typeName() + " #"+hashCode()  + ">";
}
