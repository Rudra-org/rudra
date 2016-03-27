/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra.util;

public class Utils {
    public static def max(a:int, b:int) = a>b?a:b;
    public static def min(a:int, b:int) = a>b?b:a;
    public static def max(a:double, b:double) = a>b?a:b;
    public static def min(a:double, b:double) = a>b?b:a;
    public static def max(a:uint, b:uint) = a>b?a:b;
    public static def min(a:uint, b:uint) = a>b?b:a;

    public static def fabs(v:double) =   v>=0.0?v:-v; 
    public static def FFT_Flops(n:int)= ((4.0*n-3.0)*n-1.0)*n/6.0; 
    public static def powerOf2(var p:int) {
	if (p <=0n) return false;
	if (p==1n) return true;
	while (true) {
	    if (p%2n==1n) return false;
	    p /=2n;
	    if (p==1n) return true;
	}
    }
    public static def log2(var p:int) {
	assert powerOf2(p) : "p=" + p + " is not a power of 2n";
	if (p==1n) return 0n;
	var i:int=0n;
	while (p>1) { p=p/2n; i++;}
	return i;
	}
}
