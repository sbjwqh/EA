//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                 Copyright 2019-2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.04"

#include "Factorable.mqh"

//+------------------------------------------------------------------+
//| Базовый класс торговой стратегии                                 |
//+------------------------------------------------------------------+
class CStrategy : public CFactorable {
public:                     
   virtual void      Tick() = 0; // Обработка событий OnTick
};
//+------------------------------------------------------------------+
