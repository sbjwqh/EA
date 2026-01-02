//+------------------------------------------------------------------+
//|                                              OptimizationJob.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17328"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Предопределение классов                                          |
//+------------------------------------------------------------------+
class COptimizationTask;
class COptimizationStage;

#include "OptimizationStage.mqh"

//+------------------------------------------------------------------+
//| Класс для работы оптимизации                                     |
//+------------------------------------------------------------------+
class COptimizationJob {
public:
   ulong             id_job;     // ID работы
   ulong             id_stage;   // ID этапа
   string            symbol;     // Символ
   string            timeframe;  // Таймфрейм
   string            params;     // Параметры работы для оптимизатора
   string            status;     // Статус

   COptimizationStage* stage;    // Этап, к которому относится данная работа
   COptimizationTask* tasks[];   // Массив задач, относящихся к данной работе

   // Конструктор
                     COptimizationJob(ulong p_jobId, COptimizationStage* p_stage,
                    string p_symbol, string p_timeframe,
                    string p_params, string p_status = "Done");

   // Создание работы в базе данных
   void              Insert();
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
COptimizationJob::COptimizationJob(ulong p_jobId,
                                   COptimizationStage* p_stage,
                                   string p_symbol, string p_timeframe,
                                   string p_params, string p_status = "Done") :
   id_job(p_jobId),
   stage(p_stage),
   id_stage(!!p_stage ? p_stage.id_stage : 0),
   symbol(p_symbol),
   timeframe(p_timeframe),
   params(p_params),
   status(p_status) {}

//+------------------------------------------------------------------+
//| Создание работы в базе данных                                    |
//+------------------------------------------------------------------+
void COptimizationJob::Insert() {
// Запрос на создание работы второго этапа для данного символа и таймфрейма
   string query = StringFormat("INSERT INTO jobs "
                               " VALUES (NULL,%I64u,'%s','%s','%s','%s');",
                               id_stage, symbol, timeframe, params, status);
   id_job = DB::Insert(query);
   PrintFormat(__FUNCTION__" | %s -> %I64u", query, id_job);
}

//+------------------------------------------------------------------+
