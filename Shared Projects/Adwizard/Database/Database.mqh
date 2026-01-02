//+------------------------------------------------------------------+
//|                                                     Database.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.13"

// Импорт sql-файлов создания структуры БД разных типов
#resource "db.opt.schema.sql" as string dbOptSchema
#resource "db.cut.schema.sql" as string dbCutSchema
#resource "db.adv.schema.sql" as string dbAdvSchema

// Тип базы данных
enum ENUM_DB_TYPE {
   DB_TYPE_OPT,   // БД оптимизации
   DB_TYPE_CUT,   // БД для подбора групп (урезанная БД оптимизации)
   DB_TYPE_ADV,   // БД эксперта (итогового советника)
};

#include "../Utils/Macros.mqh"

#define DB CDatabase

//+------------------------------------------------------------------+
//| Класс для работы с базой данных                                  |
//+------------------------------------------------------------------+
class CDatabase {
   static int        s_db;          // Хендл соединения с БД
   static string     s_fileName;    // Имя файла БД
   static int        s_common;      // Флаг использования общей папки данных
   static bool       s_res;         // Результат выполнения запросов

public:
   static int        Id();          // Хендл соединения с БД
   static bool       Res();         // Результат выполнения запросов

   // Полное или короткое имя файла БД
   static string     FileName(bool full = false);

   static bool       IsOpen();      // Открыта ли БД?

   // Создание пустой БД по заданной схеме
   static void       Create(string p_schema);

   // Подключение к БД с заданным именем и типом
   static bool       Connect(string p_fileName,
                             ENUM_DB_TYPE p_dbType = DB_TYPE_OPT
                            );

   static void       Close();       // Закрытие БД

   // Выполнение одного запроса к БД
   static bool       Execute(string query, int attempt = 0);

   // Выполнение нескольких запросов к БД в одной транзакции
   static bool       ExecuteTransaction(string &queries[], int attempt = 0);

   // Выполнение запроса к БД на вставку с возвратом идентификатора новой записи
   static ulong      Insert(string query);

   static string     GetValue(string query, int attempt = 0);
};

int    CDatabase::s_db       =  INVALID_HANDLE;
string CDatabase::s_fileName = "database.sqlite";
int    CDatabase::s_common   =  DATABASE_OPEN_COMMON;
bool   CDatabase::s_res      =  true;


//+------------------------------------------------------------------+
//| Хендл соединения с БД                                            |
//+------------------------------------------------------------------+
int CDatabase::Id() {
   return s_db;
}

//+------------------------------------------------------------------+
//| Результат выполнения запросов                                    |
//+------------------------------------------------------------------+
bool CDatabase::Res() {
   return s_res;
}

//+------------------------------------------------------------------+
//| Полное или короткое имя файла БД                                 |
//+------------------------------------------------------------------+
string CDatabase::FileName(bool full = false) {
   string path = "";
   if(full) {
      path = (s_common == DATABASE_OPEN_COMMON ?
              TerminalInfoString(TERMINAL_COMMONDATA_PATH) :
              TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5")
             + "\\Files\\";
   }
   return path + s_fileName;
}

//+------------------------------------------------------------------+
//| Открыта ли БД?                                                   |
//+------------------------------------------------------------------+
bool CDatabase::IsOpen() {
   return (s_db != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Создание пустой БД                                               |
//+------------------------------------------------------------------+
void CDatabase::Create(string p_schema) {
   s_res = Execute(p_schema);
   if(s_res) {
      PrintFormat(__FUNCTION__" | Database successfully created from %s", "db.*.schema.sql");
   }
}

//+------------------------------------------------------------------+
//| Закрытие БД                                                      |
//+------------------------------------------------------------------+
void CDatabase::Close() {
   if(s_db != INVALID_HANDLE) {
      DatabaseClose(s_db);
      //PrintFormat(__FUNCTION__" | Close database %s with handle %d",
      //            s_fileName, s_db);
      s_db = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Проверка подключения к базе данных с заданным именем             |
//+------------------------------------------------------------------+
bool CDatabase::Connect(string p_fileName, ENUM_DB_TYPE p_dbType = DB_TYPE_OPT) {
// Если база данных открыта, то закроем её
   Close();

   s_res = true;

// Если задано имя файла, то запомним его
   s_fileName = p_fileName;

// Установим флаг общей папки для БД оптимизации и эксперта
   s_common = (p_dbType != DB_TYPE_CUT ? DATABASE_OPEN_COMMON : 0);

// Открываем базу данных
// Пробуем открыть существующий файл БД
   s_db = DatabaseOpen(s_fileName, DATABASE_OPEN_READWRITE | s_common);

// Если файл БД не найден, то пытаемся создать его при открытии
   if(!IsOpen()) {
      s_db = DatabaseOpen(s_fileName,
                          DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | s_common);

      // Сообщаем об ошибке при неудаче
      if(!IsOpen()) {
         PrintFormat(__FUNCTION__" | ERROR: %s Connect failed with code %d",
                     s_fileName, GetLastError());
         return false;
      }
      if(p_dbType == DB_TYPE_OPT) {
         Create(dbOptSchema);
      } else if(p_dbType == DB_TYPE_CUT) {
         Create(dbCutSchema);
      } else {
         Create(dbAdvSchema);
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Выполнение одного запроса к БД                                   |
//+------------------------------------------------------------------+
bool CDatabase::Execute(string query, int attempt = 0) {
   s_res = DatabaseExecute(s_db, query);
   if(!s_res) {
      if((_LastError == ERR_DATABASE_LOCKED || _LastError == ERR_DATABASE_BUSY) && attempt < 20) {
         PrintFormat(__FUNCTION__" | WARNING: ERR_DATABASE_LOCKED. Repeat Transaction in DB [%s] for query:\n%s",
                     s_fileName, query);
         Execute(query, attempt + 1);

      } else {
         // Сообщаем о ней
         PrintFormat(__FUNCTION__" | ERROR: Execution failed in DB [%s], query:\n"
                     "%s\n"
                     "error code = %d",
                     s_fileName, query, _LastError);
      }
   } else {
      if(attempt > 0) {
         PrintFormat(__FUNCTION__" | OK: Result in DB [%s] was get at %d attempt for query:\n%s",
                     s_fileName, attempt, query);
      }
   }
   return s_res;
}

//+------------------------------------------------------------------+
//| Выполнение нескольких запросов к БД в одной транзакции           |
//+------------------------------------------------------------------+
bool CDatabase::ExecuteTransaction(string &queries[], int attempt = 0) {
// Открываем транзакцию
   DatabaseTransactionBegin(s_db);

   s_res = true;
// Отправляем все запросы на выполнение
   FOREACH(queries) {
      s_res &= DatabaseExecute(s_db, queries[i]);
      if(!s_res) break;
   }

// Если в каком-то запросе возникла ошибка, то
   if(!s_res) {
// Отменяем транзакцию
      DatabaseTransactionRollback(s_db);
      if((_LastError == ERR_DATABASE_LOCKED || _LastError == ERR_DATABASE_BUSY) && attempt < 20) {
         PrintFormat(__FUNCTION__" | WARNING: ERR_DATABASE_LOCKED. Repeat Transaction in DB [%s], first query:\n%s",
                     s_fileName, queries[0]);
         Sleep(rand() % 50);
         ExecuteTransaction(queries, attempt + 1);

      } else {
         // Сообщаем о ней
         PrintFormat(__FUNCTION__" | ERROR: Transaction failed in DB [%s], error code=%d",
                     s_fileName, _LastError);
      }

   } else {
// Иначе - подтверждаем транзакцию
      DatabaseTransactionCommit(s_db);
      
      if(attempt > 0) {
         PrintFormat(__FUNCTION__" | OK: Result in DB [%s] was get at %d attempt for query:\n%s",
                     s_fileName, attempt, queries[0]);
      }
//PrintFormat(__FUNCTION__" | Transaction done successfully");
   }

   return s_res;
}

//+------------------------------------------------------------------+
//| Выполнение запроса к БД на вставку с возвратом идентификатора    |
//| новой записи                                                     |
//+------------------------------------------------------------------+
ulong CDatabase::Insert(string query) {
   ulong res = 0;

   if(StringFind(query, "RETURNING rowid;") == -1) {
      StringReplace(query, ";", "");
      query += " RETURNING rowid;";
   }

// Выполняем запрос
   int request = DatabasePrepare(s_db, query);

// Если нет ошибки
   if(request != INVALID_HANDLE) {
      // Структура данных для чтения одной строки результата запроса
      struct Row {
         int         rowid;
      } row;

      // Читаем данные из первой строки результата
      if(DatabaseReadBind(request, row)) {
         res = row.rowid;
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: Reading row in DB [%s] for request \n%s\nfailed with code %d",
                     s_fileName, query, GetLastError());
         s_res = false;
      }
      DatabaseFinalize(request);
   } else {
      // Сообщаем об ошибке при необходимости
      PrintFormat(__FUNCTION__" | ERROR: Request in DB [%s] \n%s\nfailed with code %d",
                  s_fileName, query, GetLastError());
      s_res = false;
   }
   return res;
}


//+------------------------------------------------------------------+
//| Получение значения в виде строки по заданному ключу              |
//+------------------------------------------------------------------+
string CDatabase::GetValue(string query, int attempt = 0) {
   string value = NULL; // Возвращаемое значение

// Выполняем запрос
   int request = DatabasePrepare(DB::Id(), query);

// Если нет ошибки
   if(request != INVALID_HANDLE) {
      // Читаем данные из первой строки результата
      DatabaseRead(request);

      if(!DatabaseColumnText(request, 0, value)) {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: Reading row in DB [%s] for request \n%s\n"
                     "failed with code %d",
                     s_fileName,
                     query, GetLastError());
         s_res = false;
      }
      DatabaseFinalize(request);
   } else {
      if((_LastError == ERR_DATABASE_LOCKED || _LastError == ERR_DATABASE_BUSY) && attempt < 20) {
         PrintFormat(__FUNCTION__" | WARNING: ERR_DATABASE_LOCKED. Repeat request in DB [%s] for query:\n%s",
                     s_fileName, query);
         Sleep(rand() % 50);
         GetValue(query, attempt + 1);
      } else {
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: Request in DB [%s] \n%s\nfailed with code %d",
                     s_fileName, query, GetLastError());
         s_res = false;
      }
   }

   if(attempt > 0) {
      PrintFormat(__FUNCTION__" | OK: Result in DB [%s] was get at %d attempt for query:\n%s",
                  s_fileName, attempt, query);
   }

   return value;
}

//+------------------------------------------------------------------+
