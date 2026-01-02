//+------------------------------------------------------------------+
//|                                                       Stage3.mq5 |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17607"
#property description "Советник, сохраняющий сформированную нормированную группу стратегий "
#property description "в библиотеку групп с заданным именем."

#property version "1.04"

// 1. Определяем константу с именем советника
#define  __NAME__ "SimpleCandles" + MQLInfoString(MQL_PROGRAM_NAME)

// 2. Подключаем нужную стратегию
#include "../Strategies/SimpleCandlesStrategy.mqh";

// 3. Подключаем общую часть советника третьего этапа из библиотеки Adwizard
#include "../../Adwizard/Experts/Stage3.mqh"