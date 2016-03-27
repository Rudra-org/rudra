/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
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
