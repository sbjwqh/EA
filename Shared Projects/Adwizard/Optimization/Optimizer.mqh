//+------------------------------------------------------------------+
//|                                                    Optimizer.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.04"

#include "OptimizerTask.mqh"

//+------------------------------------------------------------------+
//| Класс для менеджера автоматической оптимизации проектов          |
//+------------------------------------------------------------------+
class COptimizer {
   string            m_fileName;
   // Текущая задача оптимизации
   COptimizerTask    *m_task;
   int               m_totalTasks;

   // Получение количества задач в очереди
   int               TotalTasks();

   // Получение идентификатора следующей задачи оптимизации из очереди
   ulong             GetNextTaskId();

public:
   COptimizer(string p_fileName, string p_pythonPath = NULL);   // Конструктор
   ~COptimizer();
   void              Process();  // Основной метод обработки
   string            Text();     // Информация от текущем состоянии оптимизации
};


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
COptimizer::COptimizer(string p_fileName, string p_pythonPath = NULL) :
   m_fileName(p_fileName),
   m_totalTasks(0) {
// Передаём путь к интерпретатору объекту задачи оптимизации
   m_task = new COptimizerTask(p_fileName, p_pythonPath);
}

//+------------------------------------------------------------------+
//| Деструктор                                                      |
//+------------------------------------------------------------------+
COptimizer::~COptimizer() {
// Если есть задача оптимизации, то останавливаем и удаляем её
   if (!!m_task) {
      if(m_task.Id()) m_task.Stop();
      delete m_task;
   }
}

//+------------------------------------------------------------------+
//| Получение количества задач с заданным статусом                   |
//+------------------------------------------------------------------+
int COptimizer::TotalTasks() {
// Результат
   int res = 0;

// Запрос на получение количества задач с заданным статусом
   string query = "SELECT COUNT(*)"
                  "  FROM tasks t"
                  "       JOIN"
                  "       jobs j ON t.id_job = j.id_job"
                  "       JOIN"
                  "       stages s ON j.id_stage = s.id_stage"
                  " WHERE t.status IN ('Queued', 'Process') "
                  " ORDER BY s.id_stage, j.id_job, t.status LIMIT 1;";

// Открываем базу данных
   if(DB::Connect(m_fileName)) {
      // Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      // Если нет ошибки
      if(request != INVALID_HANDLE) {
         // Структура данных для чтения одной строки результата запроса
         struct Row {
            int      count;
         } row;

         // Читаем данные из первой строки результата
         if(DatabaseReadBind(request, row)) {
            res = row.count;
         } else {
            // Сообщаем об ошибке при необходимости
            PrintFormat(__FUNCTION__" | ERROR: Reading row for request \n%s\nfailed with code %d",
                        query, GetLastError());
         }
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: Request \n%s\nfailed with code %d", query, GetLastError());
      }

      // Закрываем базу данных
      DB::Close();
   }

   return res;
}

//+------------------------------------------------------------------+
//| Получение идентификатора следующей задачи оптимизации из очереди |
//+------------------------------------------------------------------+
ulong COptimizer::GetNextTaskId() {
// Результат
   ulong res = 0;

// Запрос на получение очередной задачи оптимизации из очереди
   string query = "SELECT t.id_task"
                  "  FROM tasks t "
                  "       JOIN "
                  "       jobs j ON j.id_job = t.id_job "
                  "       JOIN "
                  "       stages s ON s.id_stage = j.id_stage "
                  "       LEFT JOIN "
                  "       stages ps ON ps.id_stage = s.id_parent_stage "
                  "       JOIN "
                  "       projects p ON p.id_project = s.id_project "
                  " WHERE t.id_task > 0 AND "
                  "       t.status IN ('Queued', 'Process') AND "
                  "       (ps.id_stage IS NULL OR "
                  "        ps.status = 'Done') "
                  " ORDER BY j.id_stage, "
                  "          j.id_job, "
                  "          t.status, "
                  "          t.id_task"
                  " LIMIT 1;";

// Открываем базу данных
   if(DB::Connect(m_fileName)) {
      // Выполняем запрос
      int request = DatabasePrepare(DB::Id(), query);

      // Если нет ошибки
      if(request != INVALID_HANDLE) {
         // Структура данных для чтения одной строки результата запроса
         struct Row {
            ulong    id_task;
         } row;

         // Читаем данные из первой строки результата
         if(DatabaseReadBind(request, row)) {
            res = row.id_task;
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

   return res;
}

//+------------------------------------------------------------------+
//| Основной метод обработки                                         |
//+------------------------------------------------------------------+
void COptimizer::Process() {
   if(m_task.Id()) {
      PrintFormat(__FUNCTION__" | Current Task ID = %d", m_task.Id());
   }

   // Если текущая задача завершена, то
   if (m_task.IsDone()) {
      // Если текущая задача не пустая, то
      if(m_task.Id()) {
         // Звершаем текущую задачу
         m_task.Finish();
      }

      // Получаем количество задач в очереди
      m_totalTasks = TotalTasks();

      // Если задачи есть, то
      if(m_totalTasks) {
         // Получаем идентификатор очередной текущей задачи
         ulong taskId = GetNextTaskId();

         // Загружаем параметры задачи оптимизации из базы данных
         m_task.Load(taskId);

         // Запускаем текущую задачу
         m_task.Start();
      }
   }
}

//+------------------------------------------------------------------+
//| Информация от текущем состоянии оптимизации                      |
//+------------------------------------------------------------------+
string COptimizer::Text(void) {
   string text = "";

   // Получим количество проектов с разными статусами
   DB::Connect(m_fileName);
   int process_projects_count = (int) DB::GetValue("SELECT count(status) FROM projects WHERE status = 'Process'");
   int queued_projects_count = (int) DB::GetValue("SELECT count(status) FROM projects WHERE status = 'Queued'");
   int done_projects_count = (int) DB::GetValue("SELECT count(status) FROM projects WHERE status = 'Done'");
   int total_projects_count = process_projects_count + queued_projects_count + done_projects_count;
   DB::Close();

   // Добавим это в текст сообщения
   text += StringFormat("DB: %s | %d Projects (Process: %d, Queued: %d, Done: %d)\n",
                        m_fileName,
                        total_projects_count,
                        process_projects_count,
                        queued_projects_count,
                        done_projects_count
                       );

   // Если есть активный проект 
   if(process_projects_count > 0) {
      // Добавим в текст сообщения информацию о текущей задачи
      text += m_task.Text();

      // И общее количество задач в очереди
      if(m_totalTasks)
         text += StringFormat(
                    "Total tasks in queue: %d\n",
                    m_totalTasks);
   }

   return text;
}
//+------------------------------------------------------------------+
