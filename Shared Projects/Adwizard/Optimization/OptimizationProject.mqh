//+------------------------------------------------------------------+
//|                                          OptimizationProject.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17328"
#property version   "1.02"

#include "../Database/Database.mqh"

// Предварительное объявление класса проекта оптимизации
class COptimizationProject;

// Порядок этапов оптимизации
enum ENUM_OPT_STAGE_ORDER {
   OPT_STAGE_ORDER_SEQUENTAL,    // Последовательно
   OPT_STAGE_ORDER_INCTREMENTAL  // Инкрементально
};

#include "OptimizationTask.mqh"
#include "OptimizationJob.mqh"
#include "OptimizationStage.mqh"

// Создание нового типа - указателя на функцию генерации строки
// параметров работы оптимизации (job), принимающей в качестве
// аргумента указатель на объект проекта оптимизации
typedef string (*TJobsTemplateFunc)(COptimizationProject*);

//+------------------------------------------------------------------+
//| Класс для проекта оптимизации                                    |
//+------------------------------------------------------------------+
class COptimizationProject {
public:
   string            m_fileName;    // Имя базы данных

   // Свойства, напрямую сохраняемые в базе данных
   ulong             id_project;    // Идентификатор проекта
   string            name;          // Название
   string            version;       // Версия
   string            description;   // Описание
   string            status;        // Статус

   // Массивы всех этапов, работ и задач проекта
   COptimizationStage* m_stages[];  // Этапы проекта
   COptimizationJob*   m_jobs[];    // Работы всех этапов проекта
   COptimizationTask*  m_tasks[];   // Задачи всех работ этапов проекта

   // Свойства для текущего состояния процесса создания проекта
   string            m_symbol;      // Текущий символ
   string            m_timeframe;   // Текущий таймфрейм

   COptimizationStage* m_stage;     // Последний созданный этап (текущий этап)
   COptimizationJob*   m_job;       // Последняя созданная работа (текущая работа)
   COptimizationTask*  m_task;      // Последняя созданная задача (текущая задача)


   // Методы
   COptimizationProject(string p_fileName);  // Конструктор
   ~COptimizationProject();                   // Дестрктор

   // Создание нового проекта в базе данных
   COptimizationProject* COptimizationProject::Create(string p_name,
         string p_version = "", string p_description = "", string p_status = "Done");

   void              Insert();   // Вставка записи в базу данных
   void              Update();   // Обновление записи в базе данных

   // Добавление нового этапа в базу данных
   COptimizationProject* AddStage(COptimizationStage* parentStage, string stageName, string stageExpertName,
                                  string stageSymbol, string stageTimeframe, int stageOptimization, int stageModel,
                                  datetime stageFromDate, datetime stageToDate,
                                  int stageForwardMode, datetime stageForwardDate,
                                  int stageDeposit = 10000, string stageCurrency = "USD",
                                  int stageProfitInPips = 0, int stageLeverage = 200,
                                  int stageExecutionMode = 0, int stageOptimizationCriterion = 7,
                                  string stageStatus = "Done");

   // Добавление новых работ в базу данных для заданных символов и таймфреймов
   COptimizationProject* AddJobs(string p_symbols, string p_timeframes, TJobsTemplateFunc p_templateFunc);
   COptimizationProject* AddJobs(string &p_symbols[], string &p_timeframes[], TJobsTemplateFunc p_templateFunc);

   // Добавление новых задач в базу данных для заданных критериев оптимизации
   COptimizationProject* AddTasks(string p_criterions, long p_maxDuration = 0);
   COptimizationProject* AddTasks(string &p_criterions[], long p_maxDuration = 0);

   void              Queue();    // Постановка проекта в очередь на выполненеие

   // Преобразование строкового названия в таймфрейм
   static ENUM_TIMEFRAMES   StringToTimeframe(string s);
};



//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
COptimizationProject::COptimizationProject(string p_fileName) :
   m_fileName(p_fileName), id_project(0) {
// Подключаемся к базе данных
   if (DB::Connect(m_fileName)) {
      // Начинаем транзакцию
      DatabaseTransactionBegin(DB::Id());
   }
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
COptimizationProject::~COptimizationProject() {
// Если не возникло ошибок, то
   if(DB::Res()) {
      // Подтверждаем транзакцию
      DatabaseTransactionCommit(DB::Id());
   } else {
      // Иначе отменяем транзакцию
      DatabaseTransactionRollback(DB::Id());
   }
// Закрываем соединение с базой данных
   DB::Close();

// Удаляем созданные объекты задач, работ и этапов
   FOREACH(m_tasks)  {
      delete m_tasks[i];
   }
   FOREACH(m_jobs)   {
      delete m_jobs[i];
   }
   FOREACH(m_stages) {
      delete m_stages[i];
   }
}

//+------------------------------------------------------------------+
//| Создание нового проекта в базе данных                            |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::Create(string p_name,
      string p_version = "", string p_description = "", string p_status = "Done") {
// Устанавливаем переданные значения свойств
   name = p_name;
   version = p_version;
   description = p_description;
   status = p_status;

// Вставляем в базу данных
   Insert();

   return &this;
}

//+------------------------------------------------------------------+
//| Вставка записи в базу данных                                     |
//+------------------------------------------------------------------+
void              COptimizationProject::Insert() {
   string query = StringFormat("INSERT INTO projects "
                               " VALUES (NULL,'%s','%s','%s',NULL,'%s');",
                               name, version, description, status);
   id_project = DB::Insert(query);
   PrintFormat(__FUNCTION__" | %s -> %I64u", query, id_project);
}

//+------------------------------------------------------------------+
//| Обновление записи в базе данных                                  |
//+------------------------------------------------------------------+
void              COptimizationProject::Update() {
   string query = StringFormat("UPDATE projects "
                               " SET name='%s', version='%s',description='%s',status='%s' "
                               " WHERE id_project=%I64u;",
                               name, version, description, status, id_project);
   DB::Execute(query);
   PrintFormat(__FUNCTION__" | %s", query);
}

//+------------------------------------------------------------------+
//| Добавление нового этапа в базу данных                            |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::AddStage(COptimizationStage* p_parentStage, string p_name, string p_expertName,
      string p_symbol, string p_timeframe, int p_optimization, int p_model,
      datetime p_fromDate, datetime p_toDate,
      int p_forwardMode, datetime p_forwardDate,
      int p_deposit = 10000, string p_currency = "USD",
      int p_profitInPips = 0, int p_leverage = 200,
      int p_executionMode = 0, int p_optimizationCriterion = 7,
      string p_status = "Done") {

// Создаём новый объект этапа
   m_stage = new COptimizationStage(0, &this, p_parentStage, p_name, p_expertName,
                                    p_symbol, p_timeframe, p_optimization, p_model,
                                    p_fromDate, p_toDate,
                                    p_forwardMode, p_forwardDate,
                                    p_deposit, p_currency,
                                    p_profitInPips, p_leverage,
                                    p_executionMode, p_optimizationCriterion,
                                    p_status);

// Вставляем его в базу данных оптимизации
   m_stage.Insert();

// Добавляем его в массив всех этапов
   APPEND(m_stages, m_stage);

   return &this;
}

//+------------------------------------------------------------------+
//| Добавление новых работ в базу данных для заданных                |
//| символов и таймфреймов в строках                                 |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::AddJobs(string p_symbols, string p_timeframes,
      TJobsTemplateFunc p_templateFunc) {
// Массив символов для стратегий
   string symbols[];
   StringReplace(p_symbols, ";", ",");
   StringSplit(p_symbols, ',', symbols);

// Массив таймфреймов для стратегий
   string timeframes[];
   StringReplace(p_timeframes, ";", ",");
   StringSplit(p_timeframes, ',', timeframes);

   return AddJobs(symbols, timeframes, p_templateFunc);
}

//+------------------------------------------------------------------+
//| Добавление новых работ в базу данных для заданных                |
//| символов и таймфреймов в массивах                                |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::AddJobs(string &p_symbols[], string &p_timeframes[],
      TJobsTemplateFunc p_templateFunc) {
// Для каждого символа
   FOREACH_AS(p_symbols, m_symbol) {
      // Для каждого таймфрейма
      FOREACH_AS(p_timeframes, m_timeframe) {
         // Получаем параметры для работы для данного символа и таймфрейма
         string params = p_templateFunc(&this);

         // Создаём новый объект работы
         m_job = new COptimizationJob(0, m_stage, m_symbol, m_timeframe, params);

         // Вставляем его в базу данных оптимизации
         m_job.Insert();

         // Добавляем его в массив всех работ
         APPEND(m_jobs, m_job);

         // Добавляем его в массив работ текущего этапа
         APPEND(m_stage.jobs, m_job);
      }
   }

   return &this;
}

//+------------------------------------------------------------------+
//| Добавление новых задач в базу данных для заданных                |
//| критериев оптимизации в одной строке                             |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::AddTasks(string p_criterions, long p_maxDuration) {
// Массив для критериев оптимизации
   string criterions[];
   StringReplace(p_criterions, ";", ",");
   StringSplit(p_criterions, ',', criterions);

   return AddTasks(criterions, p_maxDuration);
}

//+------------------------------------------------------------------+
//| Добавление новых задач в базу данных для заданных                |
//| критериев оптимизации в массиве                                  |
//+------------------------------------------------------------------+
COptimizationProject* COptimizationProject::AddTasks(string &p_criterions[], long p_maxDuration) {
// Для каждой работы текущего этапа
   FOREACH_AS(m_stage.jobs, m_job) {
      // Для каждого критерия оптимизации
      FOREACH(p_criterions) {
         // Создаём новый объект задачи для данной работы
         m_task = new COptimizationTask(0, m_job, (int) p_criterions[i], p_maxDuration);

         // Вставляем его в базу данных оптимизации
         m_task.Insert();

         // Добавляем его в массив всех задач
         APPEND(m_tasks, m_task);

         // Добавляем его в массив задач текущей работы
         APPEND(m_job.tasks, m_task);
      }
   }

   return &this;
}

//+------------------------------------------------------------------+
//| Постановка проекта в очередь на выполненеие                      |
//+------------------------------------------------------------------+
void              COptimizationProject::Queue() {
   status = "Queued";
   Update();
}

//+------------------------------------------------------------------+
//| Преобразование строкового названия в таймфрейм                   |
//+------------------------------------------------------------------+
static ENUM_TIMEFRAMES   COptimizationProject::StringToTimeframe(string s) {
// Если в строке есть символ "_", то оставляем только символы, идущие после него
   int pos = StringFind(s, "_");
   if(pos != -1) {
      s = StringSubstr(s, pos + 1);
   }

// Переводим в верхний регистр
   StringToUpper(s);

// Массивы соответствующих значений названий и таймфреймов
   string keys[] = {"M1", "M2", "M3", "M4", "M5", "M6", "M10", "M12", "M15", "M20", "M30",
                    "H1", "H2", "H3", "H4", "H6", "H8", "H12", "D1", "W1", "MN1"
                   };

   ENUM_TIMEFRAMES values[] = {PERIOD_M1, PERIOD_M2, PERIOD_M3, PERIOD_M4, PERIOD_M5, PERIOD_M6,
                               PERIOD_M10, PERIOD_M12, PERIOD_M15, PERIOD_M20, PERIOD_M30,
                               PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4, PERIOD_H6,
                               PERIOD_H8, PERIOD_H12, PERIOD_D1, PERIOD_W1, PERIOD_MN1
                              };

// Ищем соответствие и возвращаем, если нашли
   FOREACH(keys) {
      if(keys[i] == s) return values[i];
   }

   return PERIOD_CURRENT;
}
//+------------------------------------------------------------------+
