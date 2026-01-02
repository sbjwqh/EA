//+------------------------------------------------------------------+
//|                                                ExportHistory.mqh |
//|                                 Copyright 2021-2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.00"

#include "Macros.mqh"

//+------------------------------------------------------------------+
//| Экспорт истории сделок в файл                                    |
//+------------------------------------------------------------------+
class CExpertHistory {
private:
   static string     s_sep;            // Символ-разделитель
   static int        s_file;           // Хендл файла для записи
   static string     s_columnNames[];  // Массив названий столбцов

   // Запись истории сделок в файл
   static void       WriteDealsHistory();

   // Запись одной строки истории сделок в файл
   static void       WriteDealsHistoryRow(const string &fields[]);

   // Получение даты первой сделки
   static datetime   GetStartDate();

   // Формирование имени файла
   static string     GetHistoryFileName();

public:
   // Экспорт истории сделок
   static void       Export(
      string exportFileName = "",   // Имя файла для экспорта. Если пустое, то имя будет сгенерировано
      int commonFlag = FILE_COMMON  // Сохранять файл в общей папке данных
   );
};

// Статические переменные класса
string CExpertHistory::s_sep = ",";
int    CExpertHistory::s_file;
string CExpertHistory::s_columnNames[] = {"DATE", "TICKET", "TYPE",
                                          "SYMBOL", "VOLUME", "ENTRY", "PRICE",
                                          "STOPLOSS", "TAKEPROFIT", "PROFIT",
                                          "COMMISSION", "FEE", "SWAP",
                                          "MAGIC", "COMMENT"
                                         };


//+------------------------------------------------------------------+
//| Экспорт истории сделок                                           |
//+------------------------------------------------------------------+
void CExpertHistory::Export(string exportFileName = "", int commonFlag = FILE_COMMON) {
   // Если имя файла не задано, то сгенерируем его
   if(exportFileName == "") {
      exportFileName = GetHistoryFileName();
   }

   // Открываем файл на запись в нужной папке данных
   s_file = FileOpen(exportFileName, commonFlag | FILE_WRITE | FILE_CSV | FILE_ANSI, s_sep);

   // Если файл открыт, то
   if(s_file > 0) {
      // Записываем историю сделок
      WriteDealsHistory();

      // Закрываем файл
      FileClose(s_file);
   } else {
      PrintFormat(__FUNCTION__" | ERROR: Can't open file [%s]. Last error: %d",  exportFileName, GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Запись истории сделок в файл                                     |
//+------------------------------------------------------------------+
void CExpertHistory::WriteDealsHistory() {
   // Записываем заголовок с названиями столбцов
   WriteDealsHistoryRow(s_columnNames);

   // Переменные для свойств каждой сделки
   uint     total;
   ulong    ticket = 0;
   long     entry;
   double   price;
   double   sl, tp;
   double   profit, commission, fee, swap;
   double   volume;
   datetime time;
   string   symbol;
   long     type, magic;
   string   comment;

   // Берём всю историю
   HistorySelect(0, TimeCurrent());
   total = HistoryDealsTotal();

   // Для всех сделок
   for(uint i = 0; i < total; i++) {
      // Если сделка успешно выбрана, то
      if((ticket = HistoryDealGetTicket(i)) > 0) {
         // Получаем значения её свойств
         time  = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         type  = HistoryDealGetInteger(ticket, DEAL_TYPE);
         symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         price = HistoryDealGetDouble(ticket, DEAL_PRICE);
         sl = HistoryDealGetDouble(ticket, DEAL_SL);
         tp = HistoryDealGetDouble(ticket, DEAL_TP);
         profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         fee = HistoryDealGetDouble(ticket, DEAL_FEE);
         swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
         magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         comment = HistoryDealGetString(ticket, DEAL_COMMENT);

         if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL || type == DEAL_TYPE_BALANCE) {
            // Заменяем в комментарии символы-разделители на пробел
            StringReplace(comment, s_sep, " ");

            // Формируем массив значений для записи одной сделки в строку файла
            string fields[] = {TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
                               IntegerToString(ticket), IntegerToString(type), symbol, DoubleToString(volume), IntegerToString(entry),
                               DoubleToString(price, 5), DoubleToString(sl, 5), DoubleToString(tp, 5), DoubleToString(profit),
                               DoubleToString(commission), DoubleToString(fee), DoubleToString(swap), IntegerToString(magic), comment
                              };

            // Записываем значения одной сделки в файл
            WriteDealsHistoryRow(fields);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Запись одной строки истории сделок в файл                        |
//+------------------------------------------------------------------+
void CExpertHistory::WriteDealsHistoryRow(const string &fields[]) {
   // Строка для записи
   string row = "";

   // Соединяем все значения массива в одну строку через разделитель
   JOIN(fields, row, ",");

   // Записываем строку в файл
   FileWrite(s_file, row);
}

//+------------------------------------------------------------------+
//| Получение даты первой сделки                                     |
//+------------------------------------------------------------------+
datetime CExpertHistory::GetStartDate() {
   // Берём всю историю
   HistorySelect(0, TimeCurrent());
   uint total = HistoryDealsTotal();
   
   ulong ticket = 0;

   // Для всех сделок
   for(uint i = 0; i < total; i++) {
      // Если сделка успешно выбрана, то
      if((ticket = HistoryDealGetTicket(i)) > 0) {
         // Возвращаем её дату
         return (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Формирование имени файла                                         |
//+------------------------------------------------------------------+
string CExpertHistory::GetHistoryFileName() {
   // Берём название советника
   string fileName = MQLInfoString(MQL_PROGRAM_NAME);

   // Если указана версия, то добавляем её
#ifdef __VERSION__
   fileName += "." + __VERSION__;
#endif

   fileName += " ";

   // Добавляем дату начала и окончания истории
   fileName += "[" + TimeToString(GetStartDate(), TIME_DATE);
   fileName += " - " + TimeToString(TimeCurrent(), TIME_DATE) + "]";

   fileName += " ";

   // Добавляем несколько статистических характеристик
   fileName += "[" + DoubleToString(TesterStatistics(STAT_INITIAL_DEPOSIT), 0);
   fileName += ", " + DoubleToString(TesterStatistics(STAT_INITIAL_DEPOSIT) + TesterStatistics(STAT_PROFIT), 0);
   fileName += ", " + DoubleToString(TesterStatistics(STAT_EQUITY_DD_RELATIVE), 0);
   fileName += ", " + DoubleToString(TesterStatistics(STAT_SHARPE_RATIO), 2);
   fileName += "]";

   // Если имя получилось слишком длинным, то сокращаем его
   if(StringLen(fileName) > 255 - 13) {
      fileName = StringSubstr(fileName, 0, 255 - 13);
   }

   // Добавляем расширение
   fileName += ".history.csv";

   return fileName;
}
//+------------------------------------------------------------------+
