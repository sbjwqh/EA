//+------------------------------------------------------------------+
//|                                                       Stage3.mqh |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17328"
#property description "Советник, сохраняющий сформированную нормированную группу стратегий "
#property description "в библиотеку групп с заданным именем."

#property version "1.05"

#ifndef __NAME__
#define  __NAME__ "EmptyStrategy"
#endif

#include "../Virtual/VirtualAdvisor.mqh"

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
sinput int      idTask_  = 38;       // - Идентификатор задачи оптимизации
sinput string fileName_  = "article.16373.db.sqlite"; // - Файл с основной базой данных

input group "::: Отбор в группу"
input string     passes_ = "";      // - Идентификаторы проходов через запятую

input group "::: Сохранение в библиотеку"
input string groupName_  = "SimpleVolumes_v.1.20_2023.01.01";      // - Название версии (если пустое - не сохранять)
input string advFileName_  = "SimpleVolumes-27183.test.db.sqlite"; // - Название базы данных эксперта

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double expectedDrawdown_  = 10;    // - Максимальный риск (%)
double fixedBalance_      = 10000; // - Используемый депозит (0 - использовать весь) в валюте счета
double scale_             = 1.00;  // - Масштабирующий множитель для группы

ulong    magic_           = 27183; // - Magic

CVirtualAdvisor     *expert;       // Объект эксперта

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
// Устанавливаем параметры в классе управления капиталом
   CMoney::DepoPart(expectedDrawdown_ / 10.0);
   CMoney::FixedBalance(fixedBalance_);
   CVirtualAdvisor::TesterInit(idTask_, fileName_);

// Строка инициализации с наборами параметров стратегий
   string strategiesParams = NULL;

// Если соединение с основной базой данных установлено, то
   if(DB::Connect(fileName_)) {
      // Формируем запрос на получение проходов с указанными идетификаторами
      string query = (passes_ == "" ?
                      StringFormat("SELECT DISTINCT FIRST_VALUE(p.params) OVER (PARTITION BY p.id_task ORDER BY custom_ontester DESC) AS params "
                                   "  FROM passes p "
                                   " WHERE p.id_task IN ("
                                   "           SELECT pt.id_task "
                                   "             FROM tasks t "
                                   "                  JOIN "
                                   "                  jobs j ON j.id_job = t.id_job "
                                   "                  JOIN "
                                   "                  stages s ON s.id_stage = j.id_stage "
                                   "                  JOIN "
                                   "                  jobs pj ON pj.id_stage = s.id_parent_stage "
                                   "                  JOIN "
                                   "                  tasks pt ON pt.id_job = pj.id_job "
                                   "            WHERE t.id_task = %d "
                                   " ) ", idTask_)
                      : StringFormat("SELECT params"
                                     "  FROM passes "
                                     " WHERE id_pass IN (%s);", passes_)
                     );

      Print(query);
      int request = DatabasePrepare(DB::Id(), query);

      if(request != INVALID_HANDLE) {
         // Структура для чтения результатов
         struct Row {
            string         params;
         } row;

         // Для всех строк результата запроса, соединяем строки инициализации
         while(DatabaseReadBind(request, row)) {
            strategiesParams += row.params + ",";
         }
      }
      DB::Close();
   }

// Если наборов параметрв не найдено, то прерываем тестирование
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
                            "       0,0,0,0,0,0,0,0,0,0,0,0,0"
                            "    )\n"
                            "    ,%d,%s,%d\n"
                            ")",
                            strategiesParams, scale_,
                            magic_, __NAME__, true
                         );

   PrintFormat(__FUNCTION__" | Expert Params:\n%s", expertParams);

// Создаем эксперта, работающего с виртуальными позициями
   expert = NEW(expertParams);
   
// Если эксперт не создан, то возвращаем ошибку
   if(!expert) return INIT_FAILED;
   
// Успешная инициализация
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
   // Обрабатываем завершение прохода в объекте эксперта
   double res = expert.Tester();

   // Если имя группы не пустое, то сохраняем проход в библиотеку
   if(groupName_ != "") {
      expert.Export(groupName_, advFileName_);
   }
   
   return res;
}
//+------------------------------------------------------------------+
