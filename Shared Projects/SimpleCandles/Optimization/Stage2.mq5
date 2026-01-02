//+------------------------------------------------------------------+
//|                                                       Stage2.mq5 |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17607"
#property description "Советник, подбирающий наилучшую группу одиночных экземпляров торговых стратегий "
#property description "на заданном интервале для определённого символа и таймфрейма."

#property version "1.04"

// 1. Определяем константу с именем советника
#define  __NAME__ "SimpleCandles" + MQLInfoString(MQL_PROGRAM_NAME)

// 2. Подключаем нужную стратегию
#include "../Strategies/SimpleCandlesStrategy.mqh";

// 3. Подключаем общую часть советника второго этапа из библиотеки Adwizard
#include "../../Adwizard/Experts/Stage2.mqh"