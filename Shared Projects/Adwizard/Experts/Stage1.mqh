//+------------------------------------------------------------------+
//|                                                       Stage1.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/15683"
#property description "Советник открывает рыночный или отложенный ордер в тот момент,"
#property description "когда тиковый объем свечи превышает средний объем в направлении текущей свечи."
#property description "Если ордера еще не превратились в позиции, то они удаляются по времени истечения."
#property description "Открытые позиции закрываются только по SL или TP."
#property version "1.20"

#ifndef __NAME__
#define  __NAME__ "EmptyStrategy"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetStrategyParams() {
   return "";
}
#endif

#include "../Virtual/VirtualAdvisor.mqh"

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
sinput int        idTask_              = 0;     // - Идентификатор задачи оптимизации
sinput string     fileName_            = "database.sqlite"; // - Файл с базой данных оптимизации

//input group "===  Параметры советника"
ulong             magic_               = 27181; // Magic
double            fixedBalance_        = 10000;
double            scale_               = 1;

CAdvisor     *expert;         // Указатель на объект эксперта

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   CMoney::FixedBalance(fixedBalance_);
   CMoney::DepoPart(1.0);

// Подключаемся к основной базе данных
   CVirtualAdvisor::TesterInit(idTask_, fileName_);

// Подготавливаем строку инициализации для одного экземпляра стратегии
   string strategyParams = GetStrategyParams();

// Подготавливаем строку инициализации для группы с одним экземпляром стратегии
   string groupParams = StringFormat(
                           "class CVirtualStrategyGroup(\n"
                           "       [\n"
                           "        %s\n"
                           "       ],%f\n"
                           "    )",
                           strategyParams, scale_
                        );

// Подготавливаем строку инициализации для риск-менеджера
   string riskManagerParams = StringFormat(
                                 "class CVirtualRiskManager(\n"
                                 "       0,0,0,0,0,0,0,0,0,0,0,0,0"
                                 "    )",
                                 0
                              );

// Подготавливаем строку инициализации для эксперта с группой из одной стратегии и риск-менеджером
   string expertParams = StringFormat(
                            "class CVirtualAdvisor(\n"
                            "    %s,\n"
                            "    %s,\n"
                            "    %d,%s,%d\n"
                            ")",
                            groupParams,
                            riskManagerParams,
                            magic_, __NAME__, true
                         );

   PrintFormat(__FUNCTION__" | Expert Params:\n%s", expertParams);

// Создаем эксперта, работающего с виртуальными позициями
   expert = NEW(expertParams);

   if(!expert) return INIT_FAILED;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   expert.Tick();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(!!expert) delete expert;
}

//+------------------------------------------------------------------+
//| Результат тестирования                                           |
//+------------------------------------------------------------------+
double OnTester(void) {
   return expert.Tester();
}

//+------------------------------------------------------------------+
//| Инициализация перед оптимизацией                                 |
//+------------------------------------------------------------------+
int OnTesterInit(void) {
   return CVirtualAdvisor::TesterInit(idTask_, fileName_);
}

//+------------------------------------------------------------------+
//| Действия после прохода оптимизации                               |
//+------------------------------------------------------------------+
void OnTesterPass() {
   CVirtualAdvisor::TesterPass();
}

//+------------------------------------------------------------------+
//| Действия после оптимизации                                       |
//+------------------------------------------------------------------+
void OnTesterDeinit(void) {
   CVirtualAdvisor::TesterDeinit();
}
//+------------------------------------------------------------------+
