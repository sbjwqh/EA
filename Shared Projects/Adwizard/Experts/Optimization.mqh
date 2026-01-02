//+------------------------------------------------------------------+
//|                                                 Optimization.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property description "Советник для автоматической оптимизации проектов"

#property version "1.06"

#include "../Optimization/Optimizer.mqh"
#include "../Utils/ConsoleDialog.mqh"

// Создаём константы для параметров по умолчанию,
// если они не определены в проектной части
#ifndef OPT_FILEMNAME
#define OPT_FILEMNAME ""
#endif

#ifndef OPT_PYTHONPATH
#define OPT_PYTHONPATH ""
#endif

sinput string fileName_    = OPT_FILEMNAME;  // - Файл с основной базой данных
sinput string pythonPath_  = OPT_PYTHONPATH; // - Путь к интерпретатору Python

COptimizer *optimizer;                       // Указатель на объект оптимизатора

CConsoleDialog *dialog;                      // Диалог для вывода текста с информацией

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
// Если файл базы данных не указан, то выходим
   if(fileName_ == "") {
      PrintFormat(__FUNCTION__" | ERROR: Set const OPT_FILEMNAME with filename of DB in project", 0);
      return INIT_FAILED;
   }

// Создаём оптимизатор
   optimizer = new COptimizer(fileName_, pythonPath_);

// Создаём и запускаем диалог для вывода информации
   dialog = new CConsoleDialog();
   dialog.Create(__FILE__);
   dialog.Run();

// Создаём таймер и запускаем его обработчик
   EventSetTimer(2);
   OnTimer();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer() {
   
// Запускаем обработку оптимизатора
   optimizer.Process();

   dialog.Text(optimizer.Text());
}

//+------------------------------------------------------------------+
//| Обработка событий                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // event ID
                  const long & lparam,  // event parameter of the long type
                  const double & dparam, // event parameter of the double type
                  const string & sparam) { // event parameter of the string type

   if(!!dialog && !IsStopped()) {
      dialog.ChartEvent(id, lparam, dparam, sparam);
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   PrintFormat(__FUNCTION__" | Reason: %d", reason);
   EventKillTimer();

// Удаляем оптимизатор
   if(!!optimizer) {
      delete optimizer;
   }   
   
// Удаляем диалог
   if(!!dialog) {
      dialog.Destroy();
      delete dialog;
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+
