//+------------------------------------------------------------------+
//|                                                SimpleCandles.mq5 |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17607"
#property description "Итоговый советник, объединяющий много экземпляров торговых стратегий:"
#property description " "
#property description "Стратегии открывают позиции после нескольких однонаправленных свечей."
#property description "Открытие происходит в сторону, противоположную направлению предыдущей свечи."
#property description "Позиции закрываются только по SL или TP."
#property version "1.04"


// 1. Определяем константу с именем советника
//#define  __NAME__ MQLInfoString(MQL_PROGRAM_NAME)

// 2. Подключаем нужную стратегию
#include "Strategies/SimpleCandlesStrategy.mqh";

#include "../Adwizard/Experts/Expert.mqh"

//+------------------------------------------------------------------+
//| Функция формирования строки инициализации стратегии              |
//| из входных параметров по умолчанию (если не было задано имя).    |
//| Импортирует строку инициализации из базы данных советника        |
//| по идентификатору группы стратегий                               |
//+------------------------------------------------------------------+
//string GetStrategyParams() {
//// Берём строку инициализации из новой библиотеки для выбранной группы
//// (из базы данных эксперта)
//   string strategiesParams = CVirtualAdvisor::Import(
//                                CVirtualAdvisor::FileName(__NAME__, magic_),
//                                groupId_
//                             );
//
//// Если группа стратегий из библиотеки не задана, то прерываем работу
//   if(strategiesParams == NULL && useAutoUpdate_) {
//      strategiesParams = "";
//   }
//
//   return strategiesParams;
//}
//+------------------------------------------------------------------+
