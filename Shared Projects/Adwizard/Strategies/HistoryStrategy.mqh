//+------------------------------------------------------------------+
//|                                              HistoryStrategy.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/15330"
#property version   "1.01"

#include "../Utils/NewBarEvent.mqh"
#include "../Virtual/VirtualStrategy.mqh"

// Индексы нужных столбцов в истории сделок
#define DATE   0
#define TYPE   2
#define SYMBOL 3
#define VOLUME 4
#define ENTRY  5

//+------------------------------------------------------------------+
//| Торговая стратегия воспроизведения истории сделок                |
//+------------------------------------------------------------------+
class CHistoryStrategy : public CVirtualStrategy {
protected:
   string            m_symbols[];            // Символы (торговые инструменты)
   string            m_history[][15];        // Массив истории сделок (N строк * 15 столбцов)
   int               m_totalDeals;           // Количество сделок в истории
   int               m_currentDeal;          // Текущий номер сделки

   CSymbolInfo       m_symbolInfo;           // Объект для получения информации о свойствах символа

public:
                     CHistoryStrategy(string p_params);        // Конструктор
   virtual void      Tick() override;        // Обработчик события OnTick
   virtual string    operator~() override;   // Преобразование объекта в строку
};


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CHistoryStrategy::CHistoryStrategy(string p_params) {
   m_params = p_params;

// Читаем имя файла из параметров
   string fileName = ReadString(p_params);

// Если имя прочитано, то
   if(IsValid()) {
      // Пробуем открыть файл в папке данных
      int f = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');

      // Если открыть не получилось, то пробуем открыть файл из общей папки
      if(f == INVALID_HANDLE) {
         f = FileOpen(fileName, FILE_COMMON | FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
      }

      // Если не получилось, то сообщаем об ошибке и выходим
      if(f == INVALID_HANDLE) {
         SetInvalid(__FUNCTION__,
                    StringFormat("Can't open file %s from common folder %s, error code: %d",
                                 fileName, TerminalInfoString(TERMINAL_COMMONDATA_PATH), GetLastError()));
         return;
      }

      // Читаем файл до строки заголовка (обычно она идёт первой)
      while(!FileIsEnding(f)) {
         string s = FileReadString(f);
         // Если нашли строку заголовка, то читаем названия всех столбцов не сохраняя их
         if(s == "DATE") {
            FOR(14) FileReadString(f);
            break;
         }
      }

      // Читаем остальные строки до конца файла
      while(!FileIsEnding(f)) {
         // Если массив для хранения прочитанной истории заполнен, то увеличиваем его размер
         if(m_totalDeals == ArraySize(m_history)) {
            ArrayResize(m_history, ArraySize(m_history) + 10000, 100000);
         }

         // Читаем 15 значений из очередной строки файла в строку массива
         FOR(15) m_history[m_totalDeals][i] = FileReadString(f);

         // Если символ у сделки не пустой, то
         if(m_history[m_totalDeals][SYMBOL] != "") {
            // Добавляем его в массив символов, если такого символа там ещё нет
            ADD(m_symbols, m_history[m_totalDeals][SYMBOL]);
         }

         // Увеличиваем счётчик прочитанных сделок
         m_totalDeals++;
      }

      // Закрываем файл
      FileClose(f);

      PrintFormat(__FUNCTION__" | OK: Found %d rows in %s", m_totalDeals, fileName);

      // Если есть прочитанные сделки кроме самой первой (пополнения счёта), то
      if(m_totalDeals > 1) {
         // Устанавливаем точный размер для массива истории
         ArrayResize(m_history, m_totalDeals);

         // Текущее время
         datetime ct = TimeCurrent();

         PrintFormat(__FUNCTION__" |\n"
                     "Start time in tester:  %s\n"
                     "Start time in history: %s",
                     TimeToString(ct, TIME_DATE), m_history[0][DATE]);

         // Если дата начала тестирования больше даты начала истории, то сообщаем об ошибке
         if(StringToTime(m_history[0][DATE]) < ct) {
            SetInvalid(__FUNCTION__,
                       StringFormat("For this history file [%s] set start date less than %s",
                                    fileName, m_history[0][DATE]));
         }
      }

      // Создаём виртуальные позиции для каждого символа
      CVirtualReceiver::Get(GetPointer(this), m_orders, ArraySize(m_symbols));

      // Регистрируем обработчик события нового бара на минимальном таймфрейме
      FOREACH(m_symbols) IsNewBar(m_symbols[i], PERIOD_M1);
   }
}

//+------------------------------------------------------------------+
//| Обработчик события OnTick                                        |
//+------------------------------------------------------------------+
void CHistoryStrategy::Tick() override {
//---
   while(m_currentDeal < m_totalDeals && StringToTime(m_history[m_currentDeal][DATE]) <= TimeCurrent()) {
      // Символ сделки
      string symbol = m_history[m_currentDeal][SYMBOL];
      
      // Ищем индекс символа текущей сделки в массиве символов
      int index;
      FIND(m_symbols, symbol, index);

      // Если не нашли, то пропускаем текущую сделку
      if(index == -1) {
         m_currentDeal++;
         continue;
      }
      
      // Тип сделки
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE) StringToInteger(m_history[m_currentDeal][TYPE]);

      // Объем текущей сделки
      double volume = NormalizeDouble(StringToDouble(m_history[m_currentDeal][VOLUME]), 2);

      // Если это пополнение/снятие со счёта, то пропускаем эту сделку
      if(volume == 0) {
         m_currentDeal++;
         continue;
      }

      // Сообщаем информацию о прочитанной сделке
      PrintFormat(__FUNCTION__" | Process deal #%d: %s %.2f %s",
                  m_currentDeal, (type == DEAL_TYPE_BUY ? "BUY" : (type == DEAL_TYPE_SELL ? "SELL" : EnumToString(type))),
                  volume, symbol);

      // Если это сделка на продажу, то делаем объём отрицательным
      if(type == DEAL_TYPE_SELL) {
         volume *= -1;
      }

      // Если виртуальная позиция для символа текущей сделки открыта, то
      if(m_orders[index].IsOpen()) {
         // Добавляем её объем к объёму текущей сделки
         volume += m_orders[index].Volume();
         
         // Закрываем виртуальную позицию
         m_orders[index].Close();
      }

      // Если объём по текущему символу не равен 0, то
      if(MathAbs(volume) > 0.00001) {
         // Открываем виртуальную позицию нужного объёма и направления
         m_orders[index].Open(symbol, (volume > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), MathAbs(volume));
      }

      // Увеличиваем счётчик обработанных сделок
      m_currentDeal++;
   }
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CHistoryStrategy::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}

// Освобожаем имена констант
#undef DATE
#undef TYPE
#undef SYMBOL
#undef VOLUME
#undef ENTRY
//+------------------------------------------------------------------+
