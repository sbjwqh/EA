//+------------------------------------------------------------------+
//|                                                       Stage1.mq5 |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17607"
#property description "Советник с одиночным экземпляром торговой стратегии SimpleCandles."
#property description ""
#property description "Стратегия открывает позицию после нескольких однонаправленных свечей."
#property description "Открытие происходит в сторону, противоположную направлению предыдущей свечи."
#property description "Позиции закрываются только по SL или TP."
#property version "1.04"

// 1. Определяем константу с именем советника
#define  __NAME__ "SimpleCandles" + MQLInfoString(MQL_PROGRAM_NAME)

// 2. Подключаем нужную стратегию
#include "../Strategies/SimpleCandlesStrategy.mqh";

// 3. Подключаем общую часть советника первого этапа из библиотеки Adwizard
#include "../../Adwizard/Experts/Stage1.mqh"

//+------------------------------------------------------------------+
//| 4. Входные параметры  для стратегии                              |
//+------------------------------------------------------------------+
sinput string     symbol_              = "";    // Символ
sinput ENUM_TIMEFRAMES period_         = PERIOD_CURRENT;   // Таймфрейм для свечей

input group "===  Параметры сигнала к открытию"
input int         signalSeqLen_        = 6;     // Количество однонаправленных свечей
input int         periodATR_           = 0;    // Период ATR (если 0, то TP/SL в пунктах)

input group "===  Параметры отложенных ордеров"
input double      stopLevel_           = 25000;  // Stop Loss (в доле ATR или пунктах)
input double      takeLevel_           = 3630;   // Take Profit (в доле ATR или пунктах)

input group "===  Параметры управление капиталом"
input int         maxCountOfOrders_    = 9;     // Макс. количество одновременно отрытых ордеров
input int         maxSpread_           = 10;    // Макс. допустимый спред (в пунктах)


//+------------------------------------------------------------------+
//| 5. Функция формирования строки инициализации стратегии           |
//|    из входных параметров                                         |
//+------------------------------------------------------------------+
string GetStrategyParams() {
   return StringFormat(
             "class CSimpleCandlesStrategy(\"%s\",%d,%d,%d,%.3f,%.3f,%d,%d)",
             (symbol_ == "" ? Symbol() : symbol_), period_,
             signalSeqLen_, periodATR_, stopLevel_, takeLevel_,
             maxCountOfOrders_, maxSpread_
          );
}
//+------------------------------------------------------------------+