//+------------------------------------------------------------------+
//|                                                       Expert.mq5 |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17608"
#property version "1.25"

#include "../Virtual/VirtualAdvisor.mqh"
#include "../Utils/ExpertHistory.mqh"
#include "../Utils/ConsoleDialog.mqh"

// Если не задана константа с именем итогового советника, то
#ifndef __NAME__
// Задаём её равной названию файла советника
#define  __NAME__ MQLInfoString(MQL_PROGRAM_NAME)

//+------------------------------------------------------------------+
//| Функция формирования строки инициализации стратегии              |
//| из входных параметров по умолчанию (если не было задано имя).    |
//| Импортирует строку инициализации из базы данных советника        |
//| по идентификатору группы стратегий                               |
//+------------------------------------------------------------------+
string GetStrategyParams() {
// Берём строку инициализации из новой библиотеки для выбранной группы
// (из базы данных эксперта)
   string strategiesParams = CVirtualAdvisor::Import(
                                CVirtualAdvisor::FileName(__NAME__, magic_),
                                groupId_
                             );

// Если группа стратегий из библиотеки не задана, то прерываем работу
   if(strategiesParams == NULL && useAutoUpdate_) {
      strategiesParams = "";
   }

   return strategiesParams;
}
#endif

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
input group "::: Использовать группу стратегий"
sinput int        groupId_       = 0;     // - ID группы из новой библиотеки (0 - последняя)
sinput bool       useAutoUpdate_ = true;  // - Использовать автообновление?

input group "::: Управление капиталом"
sinput double expectedDrawdown_  = 10;    // - Максимальный риск (%)
sinput double fixedBalance_      = 10000; // - Используемый депозит (0 - использовать весь) в валюте счета
input  double scale_             = 1.00;  // - Масштабирующий множитель для группы

input group ":::  Менеджер закрытия"
input bool        cmIsActive_                = true;  // - Активен?
input double      cmStartBaseBalance_        = 0;     // - Базовый баланс
input ENUM_CM_CALC_LOSS
cmCalcLossLimit_           = CM_CALC_LOSS_MONEY_BB;   // - Способ расчёта убытка
input double      cmLossLimit_       = 100;           // - Значение убытка для фиксации
input ENUM_CM_CALC_PROFIT
cmCalcProfitLimit_                    = CM_CALC_PROFIT_MONEY_BB;  // - Способ расчёта общей прибыли
input double      cmProfitLimit_   = 1000000;                     // - Значение общей прибыли для фиксации

input group ":::  Риск-менеджер"
input bool        rmIsActive_                = true;     // - Активен?
input double      rmStartBaseBalance_        = 10000;    // - Базовый баланс
input ENUM_RM_CALC_DAILY_LOSS
rmCalcDailyLossLimit_                        = RM_CALC_DAILY_LOSS_MONEY_BB;      // - Способ расчёта дневного убытка
input double      rmMaxDailyLossLimit_       = 500;                              // - Значение дневного убытка
input double      rmCloseDailyPart_          = 1.0;                              // - Значение пороговой части дневного убытка
input ENUM_RM_CALC_OVERALL_LOSS
rmCalcOverallLossLimit_                      = RM_CALC_OVERALL_LOSS_MONEY_BB;    // - Способ расчёта общего убытка
input double      rmMaxOverallLossLimit_     = 1000;                             // - Значение общего убытка
input double      rmCloseOverallPart_        = 1.0;                              // - Значение пороговой части общего убытка
input ENUM_RM_CALC_OVERALL_PROFIT
rmCalcOverallProfitLimit_                    = RM_CALC_OVERALL_PROFIT_MONEY_BB;  // - Способ расчёта общей прибыли
input double      rmMaxOverallProfitLimit_   = 1000000;                          // - Значение общей прибыли
input int         rmMaxOverallProfitDate_    = 0;                                // - Предельное время ожидания общей прибыли (дней)

input double      rmMaxRestoreTime_           = 0;                                // - Время ожидания лучшего входа на просадке
input double      rmLastVirtualProfitFactor_  = 1;                                // - Множитель начальной лучшей просадки

input group "::: Прочие параметры"
input ulong    magic_            = 27183;    // - Magic
input bool     useOnlyNewBars_   = true;     // - Работать только на открытии бара
input bool     usePrevState_     = true;     // - Загружать предыдущее состояние

input string   symbolsReplace_   = "";       // - Правила замены символов

CVirtualAdvisor     *expert;             // Объект эксперта

CConsoleDialog      *dialog;             // Диалог для вывода текста с результатами

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
// Устанавливаем параметры в классе управления капиталом
   CMoney::DepoPart(expectedDrawdown_ / 10.0);
   CMoney::FixedBalance(fixedBalance_);

// Строка инициализации с наборами параметров стратегий
   string strategiesParams = NULL;

// Берём строку инициализации из новой библиотеки для выбранной группы
// (из базы данных эксперта)
   strategiesParams = GetStrategyParams();

// Если группа стратегий из библиотеки не задана, то прерываем работу
   if(strategiesParams == NULL) {
      return INIT_FAILED;
   }

// Подготавливаем строку инициализации для эксперта с группой из нескольких стратегий
   string expertParams = StringFormat(
                            "class CVirtualAdvisor(\n"
                            "    class CVirtualStrategyGroup(\n"
                            "       [\n"
                            "        %s\n"
                            "       ],%f\n"
                            "    ),\n"
                            "    class CVirtualRiskManager(\n"
                            "       %d,%.2f,%d,%.2f,%.2f,%d,%.2f,%.2f,%d,%.2f,%d,%.2f,%.2f"
                            "    ),\n"
                            "    class CVirtualCloseManager(\n"
                            "       %d,%.2f,%d,%.2f,%d,%.2f"
                            "    )\n"
                            "    ,%d,%s,%d\n"
                            ")",
                            strategiesParams, scale_,

                            rmIsActive_, rmStartBaseBalance_,
                            rmCalcDailyLossLimit_, rmMaxDailyLossLimit_, rmCloseDailyPart_,
                            rmCalcOverallLossLimit_, rmMaxOverallLossLimit_, rmCloseOverallPart_,
                            rmCalcOverallProfitLimit_, rmMaxOverallProfitLimit_, rmMaxOverallProfitDate_,
                            rmMaxRestoreTime_, rmLastVirtualProfitFactor_,

                            cmIsActive_, cmStartBaseBalance_,
                            cmCalcLossLimit_, cmLossLimit_, 
                            cmCalcProfitLimit_, cmProfitLimit_,

                            magic_, __NAME__, useOnlyNewBars_
                         );

   PrintFormat(__FUNCTION__" | Expert Params:\n%s", expertParams);

// Создаем эксперта, работающего с виртуальными позициями
   expert = NEW(expertParams);

// Если эксперт не создан, то возвращаем ошибку
   if(!expert) return INIT_FAILED;

// Если при замене символов возникла ошибка, то возвращаем ошибку
   if(!expert.SymbolsReplace(symbolsReplace_)) return INIT_FAILED;


// Если требуется восстанавливать состояние, то
   if(usePrevState_) {
      // Загружаем прошлое состояние при наличии
      if(!expert.Load()) return INIT_FAILED;
      //expert.Tick();
   }

// Создаём и запускаем диалог для вывода результатов
   dialog = new CConsoleDialog();
   dialog.Create(__NAME__ + ":" + (string) magic_);
   dialog.Run();

// Успешная инициализация
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   expert.Tick();

// Если одновременно выполнено:
   if(groupId_ == 0                       // - не задан конкретный идентификатор группы
         && useAutoUpdate_                // - разрешено автообновление
         && IsNewBar(Symbol(), PERIOD_D1) // - наступил новый день
         && expert.CheckUpdate()          // - обнаружена новая группа стратегий
     ) {
      // Сохраняем текущее состояние эксперта
      expert.Save();

      // Удаляем объект эксперта
      OnDeinit(REASON_RECOMPILE);

      // Вызываем функцию инициализации советника для загрузки новой группы стратегий
      OnInit();
   }

   if (IsNewBar(Symbol(), PERIOD_M1)) {
      dialog.Text(expert.Text());
   }

}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(!!expert) delete expert;
   if(!!dialog) delete dialog;
}

//+------------------------------------------------------------------+
//| Результат тестирования                                           |
//+------------------------------------------------------------------+
double OnTester(void) {
   CExpertHistory::Export();
   return expert.Tester();
}

//+------------------------------------------------------------------+
//| Обработка событий                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // event ID
                  const long & lparam,  // event parameter of the long type
                  const double & dparam, // event parameter of the double type
                  const string & sparam) { // event parameter of the string type

   if(!!dialog) {
      dialog.ChartEvent(id, lparam, dparam, sparam);
   }
}
//+------------------------------------------------------------------+
