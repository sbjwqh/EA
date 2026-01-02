//+------------------------------------------------------------------+
//|                                                       Macros.mqh |
//|                                 Copyright 2019-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.07"

// Полезные макросы для операций с массивами
#ifndef __MACROS_INCLUDE__
#define APPEND(A, V)     A[ArrayResize(A, ArraySize(A) + 1) - 1] = V;
#define FIND(A, V, I)    { for(I=ArraySize(A)-1;I>=0;I--) { if(A[I]==V) break; } }
#define SEARCH(A, C, I)  { for(I=ArraySize(A)-1;I>=0;I--) { if(C) break; } }
#define ADD(A, V)        { int i; FIND(A, V, i) if(i==-1) { APPEND(A, V) } }
#define FOREACH(A)       for(int i=0, im=ArraySize(A);i<im;i++)
#define FOREACH_AS(A, E) if(ArraySize(A)) E=A[0]; for(int i##E=0, im=ArraySize(A);i##E<im;E=A[++i##E%im])
#define FOR(N)           for(int i=0; i<N;i++)
#define REMOVE_AT(A, I)  { int s=ArraySize(A);for(int i=I;i<s-1;i++) { A[i]=A[i+1]; } ArrayResize(A, s-1); }
#define REMOVE(A, V)     { int i; FIND(A, V, i) if(i>=0) REMOVE_AT(A, i) }
#define JOIN(A, V, S)    { FOREACH(A) { V+=(string)A[i]+S; } V=StringSubstr(V, 0, StringLen(V)-StringLen(S)); }
#define SPLIT(V, A)      { string s=V; StringReplace(s, ";", ","); StringSplit(s, ',', A); }

#define __MACROS_INCLUDE__
#endif
//+------------------------------------------------------------------+
