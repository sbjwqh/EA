//+------------------------------------------------------------------+
//|                                                CreateProject.mq5 |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17607"
#property description "Советник создаёт проект с этапами, работами и задачами оптимизации."

#property version "1.05"
#include "../../Adwizard/Optimization/OptimizationProject.mqh"

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
sinput group "::: База данных"
sinput string fileName_  = "article.17607.db.sqlite"; // - Файл базы данных оптимизации

sinput group "::: Параметры проекта - Основные"
sinput string  projectName_ = "SimpleCandles";        // - Название
sinput string  projectVersion_ = "1.00";              // - Версия
sinput string  symbols_ = "GBPUSD,EURUSD,EURGBP";     // - Символы
sinput string  timeframes_ = "H1,M30";                // - Таймфреймы
//sinput ENUM_OPT_STAGE_ORDER
//   stageOrder_ = OPT_STAGE_ORDER_SEQUENTAL;           // - Последовательность этапов

sinput group "::: Параметры проекта - Интервал оптимизации"
sinput datetime fromDate_ = D'2023-09-01';            // - Дата начала
sinput datetime toDate_ = D'2024-01-01';              // - Дата окончания

sinput group "::: Параметры проекта - Счёт"
sinput string   mainSymbol_ = "GBPUSD";               // - Основной символ
sinput int      deposit_ = 10000;                     // - Начальный депозит

sinput group "::: Этап 1. Поиск"
sinput string   stage1ExpertName_ = "Stage1.ex5";     // - Советник этапа
sinput string   stage1Criterions_ = "6,6,6";          // - Критерии оптимизации для задач
sinput long     stage1MaxDuration_ = 20;              // - Макс. продолж. задач (с)

sinput group "::: Этап 2. Группировка"
sinput string   stage2ExpertName_ = "Stage2.ex5";     // - Советник этапа
sinput string   stage2Criterion_  = "6";              // - Критерий оптимизации для задач
sinput long     stage2MaxDuration_ = 20;              // - Макс. продолж. задач (с)
//sinput bool     stage2UseClusters_= false;          // - Использовать кластеризацию?
sinput double   stage2MinCustomOntester_ = 500;       // - Мин. значение норм. прибыли
sinput uint     stage2MinTrades_  = 20;               // - Мин. кол-во сделок
sinput double   stage2MinSharpeRatio_ = 0.7;          // - Мин. коэфф. Шарпа
sinput uint     stage2Count_      = 8;                // - Кол-во стратегий в группе (1 - 16)


sinput group "::: Этап 3. Итог"
sinput string   stage3ExpertName_ = "Stage3.ex5";      // - Советник этапа
sinput ulong    stage3Magic_      = 27183;             // - Magic
sinput bool     stage3Tester_     = true;              // - Для тестера?


class COptimizationProject;

// Шаблон параметров оптимизации на первом этапе
string paramsTemplate1(COptimizationProject *p) {
   string params = StringFormat(
                      "symbol_=%s\n"
                      "period_=%d\n"
                      "; ===  Параметры сигнала к открытию\n"
                      "signalSeqLen_=4||2||1||8||Y\n"
                      "periodATR_=21||7||2||48||Y\n"
                      "; ===  Параметры отложенных ордеров\n"
                      "stopLevel_=2.34||0.01||0.01||5.0||Y\n"
                      "takeLevel_=4.55||0.01||0.01||5.0||Y\n"
                      "; ===  Параметры управление капиталом\n"
                      "maxCountOfOrders_=15||1||1||30||Y\n",
                      p.m_symbol, p.StringToTimeframe(p.m_timeframe));
   return params;
}

// Шаблон параметров оптимизации на втором этапе
string paramsTemplate2(COptimizationProject *p) {

   // Находим идентификатор родительской работы для текущей работы
   // по совпадению символа и таймфрейма на текущем и родительском этапе
   int i;
   SEARCH(p.m_stage.parent_stage.jobs,
          (p.m_stage.parent_stage.jobs[i].symbol == p.m_symbol
           && p.m_stage.parent_stage.jobs[i].timeframe == p.m_timeframe),
          i);

   ulong parentJobId = p.m_stage.parent_stage.jobs[i].id_job;
   string params = StringFormat(
                      "idParentJob_=%I64u\n"
                      "useClusters_=%s\n"
                      "minCustomOntester_=%f\n"
                      "minTrades_=%u\n"
                      "minSharpeRatio_=%.2f\n"
                      "count_=%u\n",
                      parentJobId,
                      (string) false, //(string) stage2UseClusters_,
                      stage2MinCustomOntester_,
                      stage2MinTrades_,
                      stage2MinSharpeRatio_,
                      stage2Count_
                   );
   return params;
}

// Шаблон параметров оптимизации на третьем этапе
string paramsTemplate3(COptimizationProject *p) {
   string params = StringFormat(
                      "groupName_=%s\n"
                      "advFileName_=%s\n"
                      "passes_=\n",
                      StringFormat("%s_v.%s_%s",
                                   p.name, p.version, TimeToString(toDate_, TIME_DATE)),
                      StringFormat("%s-%I64u%s.db.sqlite",
                                   p.name, stage3Magic_, (stage3Tester_ ? ".test" : "")));
   return params;
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
// Создаём объект проекта оптимизации для заданной базы данных
   COptimizationProject p(fileName_);

// Создаём новый проект в базе данных
   p.Create(projectName_, projectVersion_,
            StringFormat("%s - %s",
                         TimeToString(fromDate_, TIME_DATE),
                         TimeToString(toDate_, TIME_DATE)));


// Добавляем первый этап
   p.AddStage(NULL, "First", stage1ExpertName_, mainSymbol_, "H1", 2, 2,
              fromDate_, toDate_, 0, 0, deposit_);

// Добавляем работы первого этапа
   p.AddJobs(symbols_, timeframes_, paramsTemplate1);

// Добавляем задачи для работ первого этапа
   p.AddTasks(stage1Criterions_, stage1MaxDuration_);


// Добавляем второй этап
   p.AddStage(p.m_stages[0], "Second", stage2ExpertName_, mainSymbol_, "H1", 2, 2,
              fromDate_, toDate_, 0, 0, deposit_);

// Добавляем работы второго этапа
   p.AddJobs(symbols_, timeframes_, paramsTemplate2);

// Добавляем задачи для работ второго этапа
   p.AddTasks(stage2Criterion_, stage2MaxDuration_);


// Добавляем третий этап
   p.AddStage(p.m_stages[1], "Save to library", stage3ExpertName_, mainSymbol_,
              "H1", 0, 2, fromDate_, toDate_, 0, 0, deposit_);

// Добавляем работу третьего этапа
   p.AddJobs(mainSymbol_, "H1", paramsTemplate3);

// Добавляем задачу для работы третьего этапа
   p.AddTasks("0");


// Ставим проект в очередь на выполнение
   p.Queue();

// Удаляем советник
   ExpertRemove();

// Успешная инициализация
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
