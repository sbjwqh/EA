//+------------------------------------------------------------------+
//|                                                      Storage.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.01"

#include "Database.mqh"
#include "../Base/Factorable.mqh"
#include "../Virtual/VirtualOrder.mqh"

//+------------------------------------------------------------------+
//| Класс для работы с базой данных эксперта в виде                  |
//| хранилища Key-Value для свойств и виртуальных позиций            |
//+------------------------------------------------------------------+
class CStorage {
protected:
   static bool       s_res; // Результат всех операций чтения/записи базы данных
public:
   // Подключение к базе данных эксперта
   static bool       Connect(string p_fileName);

   // Закрытие подключения к базе данных
   static void       Close();

   // Очистка данных
   static void       Clear();

   // Сохранение виртуального ордера/позиции
   static void       Set(int i, CVirtualOrder* order);

   // Сохранение одного значения произвольного простого типа
   template<typename T>
   static void       Set(string key, const T &value);

   // Сохранение массива значений произвольного простого типа
   template<typename T>
   static void       Set(string key, const T &values[]);

   // Получение значения в виде строки по заданному ключу
   static string     Get(string key);

   // Получение массива виртуальных ордеров/позиций по заданному хешу стратегии
   static bool       Get(string key, CVirtualOrder* &orders[]);

   // Получение значения по заданному ключу в переменную произвольного простого типа
   template<typename T>
   static bool       Get(string key, T &value);

   // Получение массива значений простого типа по заданному ключу в переменную
   template<typename T>
   static bool       CStorage::Get(string key, T &values[]);

   static bool       CStorage::GetSymbols(string &symbols[]);

   // Результат операций
   static bool       Res() {
      return s_res;
   }
};

// Результат всех операций чтения/записи базы данных
bool CStorage::s_res = true;

//+------------------------------------------------------------------+
//| Подключение к базе данных эксперта                               |
//+------------------------------------------------------------------+
bool CStorage::Connect(string p_fileName) {
// Подключаемся к базе данных эксперта
   if(DB::Connect(p_fileName, DB_TYPE_ADV)) {
      // Устанавливаем, что пока ошибок нет
      s_res = true;

      // Начинаем транзакцию
      DatabaseTransactionBegin(DB::Id());

      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Закрытие подключения к базе данных                               |
//+------------------------------------------------------------------+
void CStorage::Close() {
// Если ошибок нет, то
   if(s_res) {
      // Подтверждаем транзакцию
      DatabaseTransactionCommit(DB::Id());
   } else {
      // Иначе транзакцию отменяем
      DatabaseTransactionRollback(DB::Id());
   }

// Закрываем соединение с базой данных
   DB::Close();
}

//+------------------------------------------------------------------+
//| Очистка данных                                                   |
//+------------------------------------------------------------------+
void CStorage::Clear() {
   string query = "DELETE FROM storage;\n"
                  "DELETE FROM storage_orders;";

   DB::Execute(query);
}

//+------------------------------------------------------------------+
//| Сохранение виртуального ордера/позиции                           |
//+------------------------------------------------------------------+
void CStorage::Set(int i, CVirtualOrder* order) {
   VirtualOrderStruct o;   // Структура для информации о виртуальной позиции
   order.Save(o);          // Наполняем её

// Экранируем кавычки в комментарии
   StringReplace(o.comment, "'", "\\'");

// Запрос на сохранение
   string query = StringFormat("REPLACE INTO storage_orders VALUES("
                               "'%s',%d,%I64u,"
                               "'%s',%.2f,%d,%I64d,%f,%f,%f,%I64d,%f,%I64d,'%s',%f);",
                               order.Strategy().Hash(), i, o.ticket,
                               o.symbol, o.lot, o.type,
                               o.openTime, o.openPrice,
                               o.stopLoss, o.takeProfit,
                               o.closeTime, o.closePrice,
                               o.expiration, o.comment,
                               o.point);

// Выполняем запрос
   s_res &= DatabaseExecute(DB::Id(), query);

   if(!s_res) {
      // Сообщаем об ошибке при необходимости
      PrintFormat(__FUNCTION__" | ERROR: Execution failed in DB [adv], query:\n"
                  "%s\n"
                  "error code = %d",
                  query, GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Сохранение одного значения произвольного простого типа           |
//+------------------------------------------------------------------+
template<typename T>
void CStorage::Set(string key, const T &value) {
// Экранируем символы одинарных кавычек (пока не можно не использовать)
// StringReplace(key, "'", "\\'");
// StringReplace(value, "'", "\\'");

// Запрос на сохранение значения
   string query = StringFormat("REPLACE INTO storage(key, value) VALUES('%s', '%s');",
                               key, (string) value);

// Выполняем запрос
   s_res &= DatabaseExecute(DB::Id(), query);

   if(!s_res) {
      // Сообщаем об ошибке при необходимости
      PrintFormat(__FUNCTION__" | ERROR: Execution failed in DB [adv], query:\n"
                  "%s\n"
                  "error code = %d",
                  query, GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Сохранение массива значений произвольного простого типа          |
//+------------------------------------------------------------------+
template<typename T>
void CStorage::Set(string key, const T &values[]) {
   string value = "";

// Соединяем все значения из массива в одну строку через запятую
   JOIN(values, value, ",");

// Сохраняем строку с заданным ключом
   Set(key, value);
}

//+------------------------------------------------------------------+
//| Получение значения в виде строки по заданному ключу              |
//+------------------------------------------------------------------+
string CStorage::Get(string key) {
   string value = NULL; // Возвращаемое значение

// Запрос на получение значения
   string query = StringFormat("SELECT value FROM storage WHERE key='%s'", key);

// Выполняем запрос
   int request = DatabasePrepare(DB::Id(), query);

// Если нет ошибки
   if(request != INVALID_HANDLE) {
      // Читаем данные из первой строки результата
      DatabaseRead(request);

      if(!DatabaseColumnText(request, 0, value)) {
         s_res = false;
         // Сообщаем об ошибке при необходимости
         PrintFormat(__FUNCTION__" | ERROR: Reading row in DB [adv] for request \n%s\n"
                     "failed with code %d",
                     query, GetLastError());
      }
   } else {
      s_res = false;
      // Сообщаем об ошибке при необходимости
      PrintFormat(__FUNCTION__" | ERROR: Request in DB [adv] \n%s\nfailed with code %d",
                  query, GetLastError());
   }

   return value;
}

//+------------------------------------------------------------------+
//| Получение значения по заданному ключу в переменную               |
//| произвольного простого типа                                      |
//+------------------------------------------------------------------+
template<typename T>
bool CStorage::Get(string key, T &value) {
// Получаем значение в виде строки
   string res = Get(key);

// Если значение получено
   if(res != NULL) {
      // Приводим его к типу Т и присваиваем целевой переменной
      value = (T) res;
      return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//| Получение массива значений произвольного простого типа           |
//+------------------------------------------------------------------+
template<typename T>
bool CStorage::Get(string key, T &values[]) {
   string params = Get(key);
   int n = ArraySize(values);

   if(params != NULL) {
      string parts[];
      StringSplit(params, ',', parts);

      FOREACH(parts) {
         if(i < n) {
            values[i] = (T) parts[i];
         } else {
            APPEND(values, (T) parts[i]);
         }
      }
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Получение массива виртуальных ордеров/позиций                    |
//| по заданному хешу стратегии                                      |
//+------------------------------------------------------------------+
bool CStorage::Get(string key, CVirtualOrder* &orders[]) {
// Запрос на получение данных о виртуальных позициях
   string query = StringFormat("SELECT * FROM storage_orders "
                               " WHERE strategy_hash = '%s' "
                               " ORDER BY strategy_index ASC;",
                               key);

// Выполняем запрос
   int request = DatabasePrepare(DB::Id(), query);

// Если нет ошибки
   if(request != INVALID_HANDLE) {
      // Структура для информации о виртуальной позиции
      VirtualOrderStruct row;

      // Читаем построчно данные из результата запроса
      while(DatabaseReadBind(request, row)) {
         orders[row.strategyIndex].Load(row);
      }
   } else {
      // Запоминаем ошибку и сообщаем об ней при необходимости
      s_res = false;
      PrintFormat(__FUNCTION__" | ERROR: Execution failed in DB [adv], query:\n"
                  "%s\n"
                  "error code = %d",
                  query, GetLastError());
   }

   return s_res;
}


//+------------------------------------------------------------------+
//| Получение массива символоав виртуальных ордеров/позиций          |
//+------------------------------------------------------------------+
bool CStorage::GetSymbols(string &symbols[]) {
// Запрос на получение данных о виртуальных позициях
   string query = StringFormat("SELECT symbol FROM storage_orders "
                               " WHERE symbol <> ''"
                               " GROUP BY symbol", "");

// Выполняем запрос
   int request = DatabasePrepare(DB::Id(), query);

// Если нет ошибки
   if(request != INVALID_HANDLE) {
      // Структура для информации о виртуальной позиции
      string symbol;

      // Читаем построчно данные из результата запроса
      while(DatabaseRead(request)) {
         s_res &= DatabaseColumnText(request, 0, symbol);
         APPEND(symbols, symbol);
      }
   } else {
      // Запоминаем ошибку и сообщаем об ней при необходимости
      s_res = false;
      PrintFormat(__FUNCTION__" | ERROR: Execution failed in DB [adv], query:\n"
                  "%s\n"
                  "error code = %d",
                  query, GetLastError());
   }

   return s_res;
}

//+------------------------------------------------------------------+
