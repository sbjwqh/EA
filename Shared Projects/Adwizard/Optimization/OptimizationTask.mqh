//+------------------------------------------------------------------+
//|                                             OptimizationTask.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17328"
#property version   "1.01"

//#include <antekov/Advisor/Database/Database.mqh>

class COptimizationJob;

#include "OptimizationJob.mqh"

//+------------------------------------------------------------------+
//| Класс для задачи оптимизации                                     |
//+------------------------------------------------------------------+
class COptimizationTask {
public:
   ulong             id_task;       // ID задачи
   ulong             id_job;        // ID работы
   int               optimization;  // Критерий оптимизации
   long              maxDuration;   // Макс. продолжительность
   string            status;        // Статус задачи

   COptimizationJob* job;           // Работа, для которй будет запускаться данная задача

   // Конструктор
                     COptimizationTask(ulong p_taskId = 0, COptimizationJob* p_job = NULL,
                     int p_optimization = 6,
                     long p_maxDuration = 0,
                     string p_status = "Done");

   // Создание задачи в базе данных
   void              Insert();
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
COptimizationTask::COptimizationTask(ulong p_taskId = 0,
                                     COptimizationJob* p_job = NULL,
                                     int p_optimization = 6,
                                     long p_maxDuration = 0,
                                     string p_status = "Done") :
   id_task(p_taskId),
   job(p_job),
   id_job(!!p_job ? p_job.id_job : 0),
   optimization(p_optimization),
   maxDuration(p_maxDuration),
   status(p_status) {}

//+------------------------------------------------------------------+
//| Создание задачи в базе данных                                    |
//+------------------------------------------------------------------+
void COptimizationTask::Insert() {
   string query = StringFormat("INSERT INTO tasks "
                               " VALUES (NULL,%I64u,%d,NULL,NULL,%I64d,'%s');",
                               id_job, optimization, maxDuration, status);

   id_task = DB::Insert(query);
   PrintFormat(__FUNCTION__" | %s -> %I64u", query, id_task);
}
//+------------------------------------------------------------------+
