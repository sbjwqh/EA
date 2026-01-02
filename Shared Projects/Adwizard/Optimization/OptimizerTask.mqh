//+------------------------------------------------------------------+
//|                                                OptimizerTask.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.06"

// Функция запуска исполняемого файла в операционной системе
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

#include "../Database/Database.mqh"
#include "../Utils/MTTester.mqh" // https://www.mql5.com/ru/code/26132

//+------------------------------------------------------------------+
//| Класс для задачи оптимизации                                     |
//+------------------------------------------------------------------+
class COptimizerTask {
protected:
   enum {
      TASK_TYPE_UNKNOWN,
      TASK_TYPE_EX5,
      TASK_TYPE_PY
   }                 m_type;        // Тип задачи (MQL5 или Python)
   ulong             m_id;          // Идентификатор задачи
   string            m_setting;     // Строка инициализации параметров советника для текущей задачи

   string            m_fileName;    // Имя файла базы данных
   string            m_pythonPath;  // Полный путь к интерпретатору Python

   // Получение полного или относительного пути к заданному файлу в текущей папке
   string            GetProgramPath(string name, bool rel = true);

   // Получение строки инициализации из параметров задачи
   void              Parse();

   // Получение типа задачи из параметров задачи
   void              ParseType();

   static string     s_criterionNames[];

public:
   // Структура данных для чтения одной строки результата запроса
   struct params {
      string         expert;
      int            optimization;
      string         from_date;
      string         to_date;
      int            forward_mode;
      string         forward_date;
      double         deposit;
      string         symbol;
      string         period;
      string         tester_inputs;
      ulong          id_task;
      int            optimization_criterion;
      long           max_duration;
   } m_params;

   // Конструктор
   COptimizerTask(string p_fileName, string p_pythonPath = NULL) :
      m_id(0), m_fileName(p_fileName), m_pythonPath(p_pythonPath) {}

   // Идентификатор задачи
   ulong             Id() {
      return m_id;
   }

   // Основной метод
   void              Process();

   // Загрузка параметров задачи из базы данных
   void              Load(ulong p_id);

   // Запуск задачи
   void              Start();

   // Остановка задачи
   void              Stop();

   // Завершение задачи
   void              Finish();

   // Задача выполнена?
   bool              IsDone();

   // Информация о текущей задаче
   string            Text();
};


string COptimizerTask::s_criterionNames[] = {
   "Balance max",
   "Profit Factor max",
   "Expected Payoff max",
   "Drawdown min",
   "Recovery Factor max",
   "Sharpe Ratio max",
   "Custom max",
};


//+------------------------------------------------------------------+
//| Получение строки инициализации из параметров задачи              |
//+------------------------------------------------------------------+
void COptimizerTask::Parse() {
// Получаем тип задачи из параметров задачи
   ParseType();

// Если это задача на оптимизацию советника
   if(m_type == TASK_TYPE_EX5) {
      // Формируем строку параметров для тестера
      m_setting =  StringFormat(
                      "[Tester]\r\n"
                      "Expert=%s\r\n"
                      "Symbol=%s\r\n"
                      "Period=%s\r\n"
                      "Optimization=%d\r\n"
                      "Model=1\r\n"
                      "FromDate=%s\r\n"
                      "ToDate=%s\r\n"
                      "ForwardMode=%d\r\n"
                      "%s"
                      "Deposit=%.2f\r\n"
                      "Currency=USD\r\n"
                      "ProfitInPips=0\r\n"
                      "Leverage=200\r\n"
                      "ExecutionMode=0\r\n"
                      "OptimizationCriterion=%d\r\n"
                      "[TesterInputs]\r\n"
                      "idTask_=%d\r\n"
                      "fileName_=%s\r\n"
                      "%s\r\n",
                      GetProgramPath(m_params.expert),
                      m_params.symbol,
                      m_params.period,
                      m_params.optimization,
                      m_params.from_date,
                      m_params.to_date,
                      m_params.forward_mode,
                      (m_params.forward_mode == 4 ?
                       StringFormat("ForwardDate=%s\r\n", m_params.forward_date) : ""),
                      m_params.deposit,
                      m_params.optimization_criterion,
                      m_params.id_task,
                      DB::FileName(),
                      m_params.tester_inputs
                   );

      // Если это задача на запуск программы на Python
   } else if (m_type == TASK_TYPE_PY) {
      // Формируем строку запуска программы на Python с параметрами
      m_setting = StringFormat("\"%s\" \"%s\" %I64u %s",
                               GetProgramPath(m_params.expert, false),  // Файл с программой на Python
                               DB::FileName(true),    // Путь к файлу с базой данных
                               m_id,                  // Идентификатор задачи
                               m_params.tester_inputs // Парамтры запуска
                              );
   }
}

//+------------------------------------------------------------------+
//| Получение типа задачи из параметров задачи                       |
//+------------------------------------------------------------------+
void COptimizerTask::ParseType() {
   string ext = StringSubstr(m_params.expert, StringLen(m_params.expert) - 3);
   if(ext == ".py") {
      m_type = TASK_TYPE_PY;
   } else if (ext == "ex5") {
      m_type = TASK_TYPE_EX5;
   } else {
      m_type = TASK_TYPE_UNKNOWN;
   }
}

//+------------------------------------------------------------------+
//| Получение полного или относительного пути к заданному файлу      |
//| в текущей папке                                                  |
//+------------------------------------------------------------------+
string COptimizerTask::GetProgramPath(string name, bool rel = true) {
   string path = MQLInfoString(MQL_PROGRAM_PATH);
   string programName = MQLInfoString(MQL_PROGRAM_NAME) + ".ex5";
   string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Experts\\";
   if(rel) {
      path =  StringSubstr(path,
                           StringLen(terminalPath),
                           StringLen(path) - (StringLen(terminalPath) + StringLen(programName)));
   } else {
      path = StringSubstr(path, 0, StringLen(path) - (0 + StringLen(programName)));
   }

   return path + name;
}


//+------------------------------------------------------------------+
//| Получение очередной задачи оптимизации из очереди                |
//+------------------------------------------------------------------+
void COptimizerTask::Load(ulong p_id) {
// Запоминаем идентификатор задачи
   m_id = p_id;

// Запрос на получение задачи оптимизации из очереди по идентификатору
   string query = StringFormat(
                     "SELECT s.expert,"
                     "       s.optimization,"
                     "       s.from_date,"
                     "       s.to_date,"
                     "       s.forward_mode,"
                     "       s.forward_date,"
                     "       s.deposit,"
                     "       j.symbol,"
                     "       j.period,"
                     "       j.tester_inputs,"
                     "       t.id_task,"
                     "       t.optimization_criterion,"
                     "       t.max_duration"
                     "  FROM tasks t"
                     "       JOIN"
                     "       jobs j ON t.id_job = j.id_job"
                     "       JOIN"
                     "       stages s ON j.id_stage = s.id_stage"
                     " WHERE t.id_task=%I64u;", m_id);

// Открываем базу данных
   if(DB::Connect(m_fileName)) {
      // Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      // Если нет ошибки
      if(request != INVALID_HANDLE) {
         // Читаем данные из первой строки результата
         if(DatabaseReadBind(request, m_params)) {
            Parse();
         } else {
            // Сообщаем об ошибке при необходимости
            PrintFormat(__FUNCTION__" | ERROR: Reading row for request \n%s\nfailed with code %d",
                        query, GetLastError());
         }
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
      }

      // Закрываем базу данных
      DB::Close();
   }
}

//+------------------------------------------------------------------+
//| Запуск задачи                                                    |
//+------------------------------------------------------------------+
void COptimizerTask::Start() {
   PrintFormat(__FUNCTION__" | Task ID = %d\n%s", m_id, m_setting);

// Если это задача на оптимизацию советника
   if(m_type == TASK_TYPE_EX5) {
      // Запускаем новую задачу оптимизации в тестере
      MTTESTER::CloseNotChart();
      MTTESTER::SetSettings2(m_setting);
      MTTESTER::ClickStart();

      // Обновляем статус задачи в базе данных
      DB::Connect(m_fileName);
      string query = StringFormat(
                        "UPDATE tasks SET "
                        "    status='Process' "
                        " WHERE id_task=%d",
                        m_id);
      DB::Execute(query);
      DB::Close();

      // Если это задача на запуск программы на Python
   } else if (m_type == TASK_TYPE_PY) {
      PrintFormat(__FUNCTION__" | SHELL EXEC: %s", m_pythonPath);
      // Вызываем системную функцию запуска программы с параметрами
      ShellExecuteW(NULL, NULL, m_pythonPath, m_setting, NULL, 1);
   }
}

//+------------------------------------------------------------------+
//| Остановка задачи                                                 |
//+------------------------------------------------------------------+
void COptimizerTask::Stop() {
   PrintFormat(__FUNCTION__" | Task ID = %d", m_id);

// Если это задача на оптимизацию советника
   if(m_type == TASK_TYPE_EX5) {
      // Останавливаем оптимизацию в тестере
      MTTESTER::ClickStart(false);

      // Если это задача на запуск программы на Python
   } else if (m_type == TASK_TYPE_PY) {
      PrintFormat(__FUNCTION__" | STOP SHELL EXEC: %s", m_pythonPath);
      // TODO: Добавить прерываение задачи на Python с таким запуском:
      // ShellExecuteW(NULL, NULL, m_pythonPath, m_setting, NULL, 1);
   }
}

//+------------------------------------------------------------------+
//| Завершение задачи                                                |
//+------------------------------------------------------------------+
void COptimizerTask::Finish() {
   PrintFormat(__FUNCTION__" | Task ID = %d", m_id);

// Обновляем статус задачи в базе данных
   DB::Connect(m_fileName);
   string query = StringFormat(
                     "UPDATE tasks SET "
                     "    status='Done' "
                     " WHERE id_task=%d",
                     m_id);
   DB::Execute(query);
   DB::Close();

// Сбрасываем идентификатор текущей задачи
   m_id = 0;
}

//+------------------------------------------------------------------+
//| Задача выполнена?                                                |
//+------------------------------------------------------------------+
bool COptimizerTask::IsDone() {
// Если нет текущей задачи, то всё выполнено
   if(m_id == 0) {
      return true;
   }

// Результат
   bool res = false;

// Если это задача на оптимизацию советника
   if(m_type == TASK_TYPE_EX5) {
      // Проверяем, завершил ли работу тестер стратегий
      res |= MTTESTER::IsReady();

      // Если тестер работает и указана максимальная длительность, то
      if(!res && m_params.max_duration > 0) {
         // Запрос на получение прошедшего времени выполнения текущей задачи
         string query = StringFormat("SELECT unixepoch(datetime()) - unixepoch(start_date) AS duration"
                                     "  FROM tasks"
                                     " WHERE id_task=%I64u;", m_id);

         // Получаем время выполнения в секундах
         DB::Connect(m_fileName);
         long duration = StringToInteger(DB::GetValue(query));
         DB::Close();

         // Если время выполнения больше максимально допустимого, то
         if(duration > m_params.max_duration) {
            // Останавливаем задачу
            Stop();
         }
      }

      // Если это задача на запуск программы на Python, то
   } else if(m_type == TASK_TYPE_PY) {
      // Запрос на получение статуса текущей задачи
      string query = StringFormat("SELECT status "
                                  "  FROM tasks"
                                  " WHERE id_task=%I64u;", m_id);
      // Открываем базу данных
      if(DB::Connect(m_fileName)) {
         // Выполняем запрос
         int request = DatabasePrepare(DB::Id(), query);

         // Если нет ошибки
         if(request != INVALID_HANDLE) {
            // Структура данных для чтения одной строки результата запроса
            struct Row {
               string status;
            } row;

            // Читаем данные из первой строки результата
            if(DatabaseReadBind(request, row)) {
               // Проверяем, равен ли статус Done
               res = (row.status == "Done");
            } else {
               // Сообщаем об ошибке при необходимости
               PrintFormat(__FUNCTION__" | ERROR: Reading row for request \n%s\nfailed with code %d",
                           query, GetLastError());
            }
         } else {
            // Сообщаем об ошибке при необходимости
            PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
         }

         // Закрываем базу данных
         DB::Close();
      }
   } else {
      res = true;
   }

   return res;
}

//+------------------------------------------------------------------+
//| Информация о текущей задаче                                      |
//+------------------------------------------------------------------+
string COptimizerTask::Text() {
   string text = "";

   // Если есть активная задача
   if(m_params.id_task) {
      DB::Connect(m_fileName);

      // Добавляем информацию о проекте
      text += StringFormat("═════════════════════════════════════════════════════════════════════════\n"
                           "PROJECT: %s v. %s\n%s\n\n",
                           DB::GetValue("SELECT name FROM projects WHERE status = 'Process' LIMIT 1"),
                           DB::GetValue("SELECT version FROM projects WHERE status = 'Process'  LIMIT 1"),
                           DB::GetValue("SELECT description FROM projects WHERE status = 'Process'  LIMIT 1")
                          );

      // Запрос на получение всей информации о задаче
      string query = "SELECT s.name, s.expert, s.from_date, s.to_date, "
                     "  j.symbol, j.period, t.optimization_criterion, t.start_date, "
                     "  time(max_duration, 'unixepoch') AS max_duration,"
                     "  time(unixepoch('now') - unixepoch(t.start_date), 'unixepoch') AS elapsed_time,"
                     "  time(MAX(0, max_duration - (unixepoch('now') - unixepoch(t.start_date))), 'unixepoch') AS remaining_time"
                     "  FROM stages s"
                     "       JOIN"
                     "       projects p ON s.id_project = p.id_project AND"
                     "                     p.status = 'Process' AND"
                     "                     s.expert IS NOT NULL"
                     "     JOIN jobs j ON j.id_stage = s.id_stage"
                     "     JOIN tasks t ON t.id_job = j.id_job AND t.status = 'Process';";

      // Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      struct Row {
         string stage_name;
         string expert_name;
         string from_date;
         string to_date;
         string symbol;
         string timeframe;
         int optimization_criterion;
         string start_date;
         string max_duration;
         string elapsed_time;
         string remainig_time;
      } row;

      // Если нет ошибки
      if(request != INVALID_HANDLE) {

         // Читаем данные из первой строки результата и добавляем в текст
         if(DatabaseReadBind(request, row)) {
            text += StringFormat("TASK #%I64u:\n"
                                 " %10.10s │ %14.14s │ %-23s │ %6.6s │ %-3.3s │ %15.15s │ %-10.10s │ %-10.10s\n"
                                 "────────────┼────────────────┼─────────────────────────┼────────┼─────┼─────────────────┼────────────┼─────────────\n"
                                 " %10.10s │ %14.14s │ %s - %s │ %6.6s │ %-3.3s │ %15.15s │ %-10.10s │ %-10.10s \n\n"
                                 "═════════════════════════════════════════════════════════════════════════\n",
                                 m_id,
                                 "Stage",
                                 "Expert",
                                 "Testing period",
                                 "Symbol",
                                 "TF",
                                 "Criterion",
                                 "Max Durat.",
                                 "Remaining",
                                 row.stage_name,
                                 row.expert_name,
                                 row.from_date,
                                 row.to_date,
                                 row.symbol,
                                 row.timeframe,
                                 s_criterionNames[row.optimization_criterion],
                                 m_params.max_duration ? row.max_duration : "Unlimited",
                                 row.remainig_time
                                );
         }
      }
      DatabaseFinalize(request);

      DB::Close();
   }

   return text;
}
//+------------------------------------------------------------------+
