//+------------------------------------------------------------------+
//|                                                       Stage2.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/15911"
#property version "1.05"

#ifndef __NAME__
#define  __NAME__ "EmptyStrategy"
#endif

#define PARAMS_FILE "db.stage2.sqlite"
#property tester_file PARAMS_FILE

#include "../Virtual/VirtualAdvisor.mqh"

//+------------------------------------------------------------------+
//| Входные параметры                                                |
//+------------------------------------------------------------------+
sinput int     idTask_     = 0;  // - Идентификатор задачи оптимизации
sinput string  fileName_   = "db.sqlite"; // - Файл с основной базой данных

input group "::: Отбор в группу"
input int      idParentJob_   = 1;     // - Идентификатор родительской работы
input bool     useClusters_   = true;  // - Использовать кластеризацию
input double   minCustomOntester_   = 0;     // - Мин. нормированная прибыль
input int      minTrades_           = 40;    // - Мин. количество сделок
input double   minSharpeRatio_      = 0.7;   // - Мин. коэффициент Шарпа
input int      count_         = 16;    // - Количество стратегий в группе (1 .. 16)

input group "::: Индексы экземпляров"
input int   i1_ = 1;          // - Индекс стратегии #1
input int   i2_ = 2;          // - Индекс стратегии #2
input int   i3_ = 3;          // - Индекс стратегии #3
input int   i4_ = 4;          // - Индекс стратегии #4
input int   i5_ = 5;          // - Индекс стратегии #5
input int   i6_ = 6;          // - Индекс стратегии #6
input int   i7_ = 7;          // - Индекс стратегии #7
input int   i8_ = 8;          // - Индекс стратегии #8
input int   i9_ = 9;          // - Индекс стратегии #9
input int   i10_ = 10;        // - Индекс стратегии #10
input int   i12_ = 11;        // - Индекс стратегии #11
input int   i11_ = 12;        // - Индекс стратегии #12
input int   i13_ = 13;        // - Индекс стратегии #13
input int   i14_ = 14;        // - Индекс стратегии #14
input int   i15_ = 15;        // - Индекс стратегии #15
input int   i16_ = 16;        // - Индекс стратегии #16

// Фиксированные параметры
double      expectedDrawdown_ = 10;       // - Максимальный риск (%)
double      fixedBalance_     = 10000;    // - Используемый депозит (0 - использовать весь) в валюте счета
double      scale_            = 1.00;     // - Масштабирующий множитель для группы

ulong       magic_            = 27183;    // - Magic
bool        useOnlyNewBars_   = true;     // - Работать только на открытии бара

CVirtualAdvisor     *expert;              // Объект эксперта

//+------------------------------------------------------------------+
//| Создание базу данных для отдельной задачи этапа                  |
//+------------------------------------------------------------------+
void CreateTaskDB(const string fileName, const int idParentJob) {
// Создаём новую базу данных для текущей задачи оптимизации
   DB::Connect(PARAMS_FILE, DB_TYPE_CUT);
   DB::Execute("DROP TABLE IF EXISTS passes;");
   DB::Execute("CREATE TABLE passes (id_pass INTEGER PRIMARY KEY AUTOINCREMENT, params TEXT);");
// DB::Close();

// Подключаемся к основной базе данных
   DB::Connect(fileName);

// Объединение
   string clusterJoin = "";

   if(useClusters_) {
      clusterJoin = "JOIN passes_clusters pc ON pc.id_pass = p.id_pass";
   }

// Запрос на получение необходимой информации из основной базы данных
   string query = StringFormat("SELECT DISTINCT p.params"
                               " FROM passes p"
                               "      JOIN "
                               "      tasks t ON p.id_task = t.id_task "
                               "      JOIN "
                               "      jobs j ON t.id_job = j.id_job "
                               "      %s "
                               "WHERE (j.id_job = %d AND  "
                               "       p.custom_ontester >= %.2f AND  "
                               "       trades >= %d AND  "
                               "       p.sharpe_ratio >= %.2f)  "
                               "ORDER BY p.custom_ontester DESC;",
                               clusterJoin,
                               idParentJob_,
                               minCustomOntester_,
                               minTrades_,
                               minSharpeRatio_);

// Выполняем запрос
   int request = DatabasePrepare(DB::Id(), query);
   if(request == INVALID_HANDLE) {
      PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
      DB::Close();
      return;
   }

// Структура для результатов запроса
   struct Row {
      string         params;
   } row;

// Массив для запросов на вставку данных в новую базу данных
   string queries[];

// Заполняем массив запросов: будем сохранять только строки инициализации
   while(DatabaseReadBind(request, row)) {
      APPEND(queries, StringFormat("INSERT INTO passes VALUES(NULL, '%s');", row.params));
   }

// Переподключаемся к новой базе данных и заполняем её
   DB::Connect(PARAMS_FILE, DB_TYPE_CUT);
   DB::ExecuteTransaction(queries);
   DB::Close();

// Переподключаемся к основной базе данных
// DB::Connect(fileName);
// DB::Close();
}

//+------------------------------------------------------------------+
//| Количество наборов параметров стратегий в базе данных задачи     |
//+------------------------------------------------------------------+
int GetParamsTotal() {
   int paramsTotal = 0;

// Если база данных задачи открыта, то
   if(DB::Connect(PARAMS_FILE, DB_TYPE_CUT)) {
      // Создаём запрос на получение количества проходов для данной задачи
      string query = "SELECT COUNT(*) FROM passes p";
      int request = DatabasePrepare(DB::Id(), query);

      if(request != INVALID_HANDLE) {
         // Структура данных для результата запроса
         struct Row {
            int      total;
         } row;

         // Получаем результат запроса из первой строки
         if (DatabaseReadBind(request, row)) {
            paramsTotal = row.total;
         }
      } else {
         PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d", query, GetLastError());
      }
      DB::Close();
   }

   return paramsTotal;
}

//+------------------------------------------------------------------+
//| Загрузка наборов параметров стратегий                            |
//+------------------------------------------------------------------+
string LoadParams(int &indexes[]) {
   string params = NULL;
// Получаем количество наборов
   int totalParams = GetParamsTotal();

// Если они есть, то
   if(totalParams > 0) {
      if(DB::Connect(PARAMS_FILE, DB_TYPE_CUT)) {
         // Формируем строку из индексов наборов, взятых из входных параметров советника
         // через запятую для дальнейшей подстановки в SQL-запрос
         string strIndexes = "";
         FOREACH(indexes) strIndexes += IntegerToString(indexes[i]) + ",";
         strIndexes += "0"; // Дополняем несуществующим индексом, чтобы не удалять последнюю запятую

         // Формируем запрос на получение наборов параметров с нужными индексами
         string query = StringFormat("SELECT params FROM passes p WHERE id_pass IN(%s)", strIndexes);
         int request = DatabasePrepare(DB::Id(), query);

         if(request != INVALID_HANDLE) {
            // Структура данных для результатов запроса
            struct Row {
               string   params;
            } row;

            // Читаем результаты запроса и соединяем их через запятую
            while(DatabaseReadBind(request, row)) {
               params += row.params + ",";
            }
         } else {
            PrintFormat(__FUNCTION__" | ERROR: request \n%s\nfailed with code %d",
                        query, GetLastError());
         }
         DB::Close();
      }
   }

   return params;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
// Устанавливаем параметры в классе управления капиталом
   CMoney::DepoPart(expectedDrawdown_ / 10.0);
   CMoney::FixedBalance(fixedBalance_);

// Массив всех индексов из входных параметров советника
   int indexes_[] = {i1_, i2_, i3_, i4_,
                     i5_, i6_, i7_, i8_,
                     i9_, i10_, i11_, i12_,
                     i13_, i14_, i15_, i16_
                    };

// Массив для индексов, которые будут участвовать в оптимизации
   int indexes[];
   ArrayResize(indexes, count_);

// Множество для индексов наборов параметров
   CHashSet<int> setIndexes;

// Копируем в него индексы из входных параметров
// Добавляем все индексы во множество
   FOREACH(indexes) {
      indexes[i] = indexes_[i];
      setIndexes.Add(indexes[i]);
   }

// Сообщаем об ошибке, если
   if(count_ < 1 || count_ > 16           // количество экземпляров не в диапазоне 1 .. 16
         || setIndexes.Count() != count_  // не все индексы уникальные
     ) {
      return INIT_PARAMETERS_INCORRECT;
   }

// Если это не оптимизация, то надо пересоздать базу данных задачи
   if(!MQLInfoInteger(MQL_OPTIMIZATION)) {
      CreateTaskDB(fileName_, idParentJob_);
   }

// Загружаем наборы параметров стратегий
   string strategiesParams = LoadParams(indexes);

// Подключаемся к основной базе данных
//   DB::Connect(fileName_);
//   DB::Close();
   CVirtualAdvisor::TesterInit(idTask_, fileName_);

// Если ничего не загрузили, то сообщим об ошибке
   if(strategiesParams == NULL) {
      PrintFormat(__FUNCTION__" | ERROR: Can't load data from file %s.\n"
                  "Check that it exists in data folder or in common data folder.",
                  fileName_);
      return(INIT_PARAMETERS_INCORRECT);
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
                            magic_, __NAME__, useOnlyNewBars_
                         );

   PrintFormat(__FUNCTION__" | Expert Params:\n%s", expertParams);

// Создаем эксперта, работающего с виртуальными позициями
   expert = NEW(expertParams);

   if(!expert) return INIT_FAILED;

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
   return expert.Tester();
}

//+------------------------------------------------------------------+
//| Инициализация перед оптимизацией                                 |
//+------------------------------------------------------------------+
int OnTesterInit(void) {
// Создаём базу данных для отдельной задачи этапа
   CreateTaskDB(fileName_, idParentJob_);

// Получаем количество наборов параметров стратегий
   int totalParams = GetParamsTotal();

// Подключаемся к основной базе данных
   DB::Connect(fileName_);
   DB::Close();

// Если ничего не загрузили, то сообщим об ошибке
   if(totalParams == 0) {
      PrintFormat(__FUNCTION__" | ERROR: Can't load data from file %s.\n"
                  "Check that it exists in data folder or in common data folder.",
                  fileName_);
      return(INIT_FAILED);
   }

// Параметру scale_ устанавливаем значение 1
   ParameterSetRange("scale_", false, 1, 1, 1, 2);

// Параметрам перебора индексов наборов задаём диапазоны изменения
   for(int i = 1; i <= 16; i++) {
      if(i <= count_) {
         ParameterSetRange("i" + (string) i + "_", true, 0, 1, 1, totalParams);
      } else {
         // Для лишних индексов отключаем перебор
         ParameterSetRange("i" + (string) i + "_", false, 0, 1, 1, totalParams);
      }
   }

   return CVirtualAdvisor::TesterInit(idTask_, fileName_);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterPass() {
   CVirtualAdvisor::TesterPass();
}

//+------------------------------------------------------------------+
//| Действия после оптимизации                                       |
//+------------------------------------------------------------------+
void OnTesterDeinit(void) {
   CVirtualAdvisor::TesterDeinit();
}
//+------------------------------------------------------------------+
