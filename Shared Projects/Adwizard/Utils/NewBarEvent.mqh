//+------------------------------------------------------------------+
//|                                                  NewBarEvent.mqh |
//|                                      Copyright 2022, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.00"

#include "Macros.mqh"

//+------------------------------------------------------------------+
//| Класс определения нового бара для конкретного символа            |
//+------------------------------------------------------------------+
class CSymbolNewBarEvent {
private:
   string            m_symbol;         // Отслеживаемый символ
   long              m_timeFrames[];   // Массив отслеживаемых таймфреймов для символа
   long              m_timeLast[];     // Массив времен наступления последних баров для таймфреймов
   bool              m_res[];          // Массив признаков наступления нового бара для таймфреймов

   // Метод регистрации нового отслеживаемого таймфрейма для символа
   int               Register(ENUM_TIMEFRAMES p_timeframe) {
      APPEND(m_timeFrames, p_timeframe);  // Добавляем его в массив таймфреймов
      APPEND(m_timeLast, 0);              // Время последнего бара по нему пока неизвестно
      APPEND(m_res, false);               // Нового бара по нему пока нет
      Update();                           // Обновляем признаки нового бара
      return ArraySize(m_timeFrames) - 1;
   }

public:
   // Конструктор
                     CSymbolNewBarEvent(string p_symbol) :
                     m_symbol(p_symbol) // Устанавливаем символ
   {}

   // Метод обновления признаков нового бара
   bool              Update() {
      bool res = (ArraySize(m_res) == 0);
      FOREACH(m_timeFrames) {
         // Получаем время текущего бара
         long time = iTime(m_symbol, (ENUM_TIMEFRAMES) m_timeFrames[i], 0);
         // Если не совпадает с запомненным - то это новый бар
         m_res[i] = (time != m_timeLast[i]);
         res |= m_res[i];
         // Запоминаем новое время
         m_timeLast[i] = time;
      }
      return res;
   }

   // Метод получения признака нового бара
   bool              IsNewBar(ENUM_TIMEFRAMES p_timeframe) {
      int index;
      // Ищем индекс нужного таймфрейма
      FIND(m_timeFrames, p_timeframe, index);

      // Если не найден, то зарегистрируем новый таймфрейм
      if(index == -1) {
         PrintFormat(__FUNCTION__" | Register new event handler for %s %s", m_symbol, EnumToString(p_timeframe));
         index = Register(p_timeframe);
      }

      // Возвращаем признак нового бара для нужного таймфрейма
      return m_res[index];
   }
};


//+------------------------------------------------------------------+
//| Статический класс определения нового бара для всех               |
//| символов и таймфреймов                                           |
//+------------------------------------------------------------------+
class CNewBarEvent {
private:
   // Массив объектов для определения нового бара для одного символа
   static   CSymbolNewBarEvent     *m_symbolNewBarEvent[];

   // Массив нужных символов
   static   string                  m_symbols[];

   // Метод регистрации нового символа и таймфрейма для отслеживания нового бара
   static   int                     Register(string p_symbol)  {
      APPEND(m_symbols, p_symbol);
      APPEND(m_symbolNewBarEvent, new CSymbolNewBarEvent(p_symbol));
      return ArraySize(m_symbols) - 1;
   }

public:
   // Объекты этого класса создавать не понадобится - удаляем конструктор
                            CNewBarEvent() = delete; 

   // Метод обновления признаков нового бара
   static bool              Update() {
      bool res = (ArraySize(m_symbolNewBarEvent) == 0);
      FOREACH(m_symbols) res |= m_symbolNewBarEvent[i].Update();
      return res;
   }

   // Метод освобождения памяти для автоматически созданных объектов
   static void              Destroy() {
      FOREACH(m_symbols) delete m_symbolNewBarEvent[i];
      ArrayResize(m_symbols, 0);
      ArrayResize(m_symbolNewBarEvent, 0);
   }

   // Метод получения признака нового бара
   static bool              IsNewBar(string p_symbol, ENUM_TIMEFRAMES p_timeframe) {
      int index;
      // Ищем индекс нужного символа
      FIND(m_symbols, p_symbol, index);
      
      // Если не найден, то зарегистрируем новый символ
      if(index == -1) index = Register(p_symbol);
      
      // Возвращаем признак нового бара для нужного символа и таймфрейма
      return m_symbolNewBarEvent[index].IsNewBar(p_timeframe);
   }
};

// Инициализация статических членов класса CSymbolNewBarEvent;
CSymbolNewBarEvent* CNewBarEvent::m_symbolNewBarEvent[];
string CNewBarEvent::m_symbols[];


//+------------------------------------------------------------------+
//| Функция проверки наступления нового бара                         |
//+------------------------------------------------------------------+
bool IsNewBar(string p_symbol, ENUM_TIMEFRAMES p_timeframe) {
   return CNewBarEvent::IsNewBar(p_symbol, p_timeframe);
}

//+------------------------------------------------------------------+
//| Функция обновления информации о новых барах                      |
//+------------------------------------------------------------------+
bool UpdateNewBar() {
   return CNewBarEvent::Update();
}

//+------------------------------------------------------------------+
//| Функция удаления объектов отслеживания нового бара               |
//+------------------------------------------------------------------+
void DestroyNewBar() {
   CNewBarEvent::Destroy();
}
//+------------------------------------------------------------------+
