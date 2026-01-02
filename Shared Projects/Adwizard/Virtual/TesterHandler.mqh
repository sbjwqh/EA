//+------------------------------------------------------------------+
//|                                                TesterHandler.mqh |
//|                                 Copyright 2024-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.07"

#include "../Database/Database.mqh"
#include "VirtualStrategy.mqh"
//#include "VirtualFactory.mqh"
#include "../Optimization/OptimizerTask.mqh"

//+------------------------------------------------------------------+
//| Класс для обработки событий оптимизации                          |
//+------------------------------------------------------------------+
class CTesterHandler {
   static string     s_fileName;                   // Имя базы данных оптимизации
   static string     s_frameFileName;              // Имя файла для записи данных фрейма
   static void       ProcessFrame(string values);  // Обработка данных одиночного прохода
   static void       ProcessFrames();              // Обработка пришедших фреймов
   static string     GetFrameInputs(ulong pass);   // Получение input-параметров прохода

   // Формирование SQL-запроса на вставку результатов прохода
   static string     GetInsertQuery(string values, string inputs, ulong pass = 0);
public:
   static int        TesterInit(ulong p_idTask = 0, string p_fileName = NULL);   // Обработка начала оптимизации в главном терминале
   static void       TesterDeinit();   // Обработка завершения оптимизации в главном терминале
   static void       TesterPass();     // Обработка завершения прохода на агенте в главном терминале

   static void       Tester(const double OnTesterValue,
                            const string params);  // Обработка завершения прохода тестера для агента

   // Экспорт массива стратегий в заданную базу данных эксперта как новой группы стратегий
   static void       Export(CStrategy* &p_strategies[], string p_groupName, string p_advFileName);

   static ulong      s_idTask;   // Идентификатор задачи оптимизации
   static ulong      s_idPass;   // Идентификатор текущего прохода оптимизации
};

string CTesterHandler::s_fileName = "";   // Имя базы данных оптимизации
string CTesterHandler::s_frameFileName = "data.bin";    // Имя файла для записи данных фрейма
ulong CTesterHandler::s_idTask = 0;
ulong CTesterHandler::s_idPass = 0;


//+------------------------------------------------------------------+
//| Обработка начала оптимизации в главном терминале                 |
//+------------------------------------------------------------------+
int CTesterHandler::TesterInit(ulong p_idTask, string p_fileName) {
// Устанавливаем идентификатор задачи
   s_idTask = p_idTask;

   s_fileName = p_fileName;

// Открываем существующую базу данных
   DB::Connect(s_fileName);

// Если открыть не удалось, то не запускаем оптимизацию
   if(!DB::IsOpen()) {
      return INIT_FAILED;
   }

// Закрываем успешно открытую базу данных
   DB::Close();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Обработка завершения оптимизации в главном терминале             |
//+------------------------------------------------------------------+
void CTesterHandler::TesterDeinit(void) {
// Обрабатываем последние пришедшие от агентов фреймы данных
   ProcessFrames();

// Закрываем график с советником, запущенным в режиме сбора фреймов
   ChartClose();
}

//+------------------------------------------------------------------+
//| Обработка завершения прохода на агенте в главном терминале       |
//+------------------------------------------------------------------+
void CTesterHandler::TesterPass(void) {
// Обрабатываем поступившие от агента фреймы данных
   ProcessFrames();
}

//+------------------------------------------------------------------+
//| Обработка завершения прохода тестера для агента                  |
//+------------------------------------------------------------------+
void CTesterHandler::Tester(double custom,   // Пользовательский критерий
                            string params    // Описание параметров советника в текущем проходе
                           ) {
// Массив имён сохраняемых статистических характеристик прохода
   ENUM_STATISTICS statNames[] = {
      STAT_INITIAL_DEPOSIT,
      STAT_WITHDRAWAL,
      STAT_PROFIT,
      STAT_GROSS_PROFIT,
      STAT_GROSS_LOSS,
      STAT_MAX_PROFITTRADE,
      STAT_MAX_LOSSTRADE,
      STAT_CONPROFITMAX,
      STAT_CONPROFITMAX_TRADES,
      STAT_MAX_CONWINS,
      STAT_MAX_CONPROFIT_TRADES,
      STAT_CONLOSSMAX,
      STAT_CONLOSSMAX_TRADES,
      STAT_MAX_CONLOSSES,
      STAT_MAX_CONLOSS_TRADES,
      STAT_BALANCEMIN,
      STAT_BALANCE_DD,
      STAT_BALANCEDD_PERCENT,
      STAT_BALANCE_DDREL_PERCENT,
      STAT_BALANCE_DD_RELATIVE,
      STAT_EQUITYMIN,
      STAT_EQUITY_DD,
      STAT_EQUITYDD_PERCENT,
      STAT_EQUITY_DDREL_PERCENT,
      STAT_EQUITY_DD_RELATIVE,
      STAT_EXPECTED_PAYOFF,
      STAT_PROFIT_FACTOR,
      STAT_RECOVERY_FACTOR,
      STAT_SHARPE_RATIO,
      STAT_MIN_MARGINLEVEL,
      STAT_DEALS,
      STAT_TRADES,
      STAT_PROFIT_TRADES,
      STAT_LOSS_TRADES,
      STAT_SHORT_TRADES,
      STAT_LONG_TRADES,
      STAT_PROFIT_SHORTTRADES,
      STAT_PROFIT_LONGTRADES,
      STAT_PROFITTRADES_AVGCON,
      STAT_LOSSTRADES_AVGCON,
      STAT_COMPLEX_CRITERION
   };

// Массив для значений статистических характеристик прохода в виде строк
   string stats[];
   ArrayResize(stats, ArraySize(statNames));

// Заполняем массив значений статистических характеристик прохода
   FOREACH(statNames) stats[i] = DoubleToString(TesterStatistics(statNames[i]), 2);

// Добавляем в него значение пользовательского критерия
   APPEND(stats, DoubleToString(custom, 2));

// Объединяем статистические характеристики в строку
   string data = "";
   JOIN(stats, data, ",");

// В описании параметров экранируем кавычки (на всякий случай на будущее)
   StringReplace(params, "'", "\\'");

// Формируем строку с данными о проходе
   data = StringFormat("%d, %d, %s,'%s'",
                       MQLInfoInteger(MQL_OPTIMIZATION),
                       MQLInfoInteger(MQL_FORWARD),
                       data, params);

// Если это проход в рамках процесса оптимизации, то
   if(MQLInfoInteger(MQL_OPTIMIZATION)) {
      // Открываем файл для записи данных для фрейма
      int f = FileOpen(s_frameFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);

      // Записываем описание параметров советника
      FileWriteString(f, data);

      // Закрываем файл
      FileClose(f);

      // Создаём фрейм с данными из записанного файла и отправляем его в главный терминал
      if(!FrameAdd("", 0, 0, s_frameFileName)) {
         PrintFormat(__FUNCTION__" | ERROR: Frame add error: %d", GetLastError());
      }
   } else {
      // Иначе это одиночный проход, вызываем метод добавления его результатов
      // в базу данных оптимизации (если она была задана)
      if (s_fileName != "") {
         CTesterHandler::ProcessFrame(data);
      }
   }
}

//+------------------------------------------------------------------+
//| Экспорт массива стратегий в заданную базу данных эксперта        |
//| как новой группы стратегий                                       |
//+------------------------------------------------------------------+
void CTesterHandler::Export(CStrategy* &p_strategies[], string p_groupName, string p_advFileName) {
// Создаём объект задачи оптимизации
   COptimizerTask task(s_fileName);
// Загружаем в него данные текущей задачи оптимизации
   task.Load(CTesterHandler::s_idTask);

// Подключаемся к нужной базе данных эксперта
   if(DB::Connect(p_advFileName, DB_TYPE_ADV)) {
      string fromDate = task.m_params.from_date; // Дата начала интервала оптимизации
      string toDate = task.m_params.to_date;     // Дата конца  интервала оптимизации

      // Создаём запись для новой группы стратегий
      string query = StringFormat("INSERT INTO strategy_groups VALUES(NULL, '%s', '%s', '%s', NULL)"
                                  " RETURNING rowid;",
                                  p_groupName, fromDate, toDate);
      ulong groupId = DB::Insert(query);

      PrintFormat(__FUNCTION__" | Export %d strategies into new group [%s] with ID=%I64u",
                  ArraySize(p_strategies), p_groupName, groupId);

      // Для каждой стратегии
      FOREACH(p_strategies) {
         CVirtualStrategy *strategy = p_strategies[i];
         // Формируем строку инициализации в виде группы из одной стратегии с нормирующим множителем
         string params = StringFormat("class CVirtualStrategyGroup([%s],%0.5f)",
                                      ~strategy,
                                      strategy.Scale());

         // Сохраняем её в базе данных эксперта с указанием нового идентификатора группы
         string query = StringFormat("INSERT INTO strategies "
                                     "VALUES (NULL, %I64u, '%s', '%s')",
                                     groupId, strategy.Hash(~strategy), params);
         DB::Execute(query);
      }

      // Закрываем базу данных
      DB::Close();
   }
   
   // TODO: Добавить сохранение группы в базу данных оптимизации
}

//+------------------------------------------------------------------+
//| Формирование SQL-запроса на вставку результатов прохода          |
//+------------------------------------------------------------------+
string CTesterHandler::GetInsertQuery(string values, string inputs, ulong pass) {
   return StringFormat("INSERT INTO passes "
                       "VALUES (NULL, %d, %I64u, %s,\n'%s',\nNULL) RETURNING rowid;",
                       s_idTask, pass, values, inputs);
}

//+------------------------------------------------------------------+
//| Обработка данных одиночного прохода                              |
//+------------------------------------------------------------------+
void CTesterHandler::ProcessFrame(string values) {
// Открываем базу данных
   DB::Connect(s_fileName);

// Формируем SQL-запрос из полученных данных
   string query = GetInsertQuery(values, "", 0);

// Выполняем запрос
   s_idPass = DB::Insert(query);

// Закрываем базу данных
   DB::Close();
}


//+------------------------------------------------------------------+
//| Обработка пришедших фреймов                                      |
//+------------------------------------------------------------------+
void CTesterHandler::ProcessFrames(void) {
// Открываем базу данных
   DB::Connect(s_fileName);

// Переменные для чтения данных из фреймов
   string   name;      // Название фрейма (не используется)
   ulong    pass;      // Индекс прохода фрейма
   long     id;        // Идентификатор типа фрейма (не используется)
   double   value;     // Одиночное значение фрейма (не используется)
   uchar    data[];    // Массив данных фрейма в виде массива символа

   string   values;    // Данные фрейма в виде строки
   string   inputs;    // Строка с именами и значениями параметров прохода
   string   query;     // Строка одного SQL-запроса
   string   queries[]; // SQL-запросы на добавление записей в БД


// Проходим по фреймам и читаем данные из них
   while(FrameNext(pass, name, id, value, data)) {
      // Переводим в строку массив символов, прочитанный из фрейма
      values = CharArrayToString(data);

      // Формируем строку с именами и значениями параметров прохода
      inputs = GetFrameInputs(pass);

      // Формируем SQL-запрос из полученных данных
      query = GetInsertQuery(values, inputs, pass);

      // Добавляем его в массив SQL-запросов
      APPEND(queries, query);
   }

// Выполняем все запросы
   DB::ExecuteTransaction(queries);

// Закрываем базу данных
   DB::Close();
}

//+------------------------------------------------------------------+
//| Формирует строку с именами и значениями input-переменных прохода |
//+------------------------------------------------------------------+
string CTesterHandler::GetFrameInputs(ulong pass) {
   string  params[];    // Массив описаний input-переменных
   uint    count;       // Количество input-переменных
   string  inputs = ""; // Строка для результата

   if(FrameInputs(pass, params, count)) {
      // собираем оптимизируемые параметры и их значения
      for(uint i = 0; i < count; i++) {
         string name2value[];
         string delimeter = (i == count - 1 ? "" : ",");
         // Делим описание очередной input-переменной по символу '='
         int n = StringSplit(params[i], '=', name2value);
         if(n == 2) {
            // Получаем значение по имени в pvalue
            double pvalue, pstart, pstep, pstop;
            bool enabled = false;
            if(ParameterGetRange(name2value[0],
                                 enabled, pvalue, pstart, pstep, pstop)) {
               // Добавляем в выходную строку имя и значение input-переменной
               if(MathAbs(pvalue - (long) pvalue) < 1e-6) {
                  // как целое число
                  inputs += StringFormat("%s=%d%s", name2value[0], (long) pvalue, delimeter);
               } else {
                  // как вещественное число
                  inputs += StringFormat("%s=%.2f%s", name2value[0], pvalue, delimeter);
               }
            }
         }
      }
   }
//PrintFormat(__FUNCTION__" | pass %d: %s", pass, inputs);

   return inputs;
}

//+------------------------------------------------------------------+
