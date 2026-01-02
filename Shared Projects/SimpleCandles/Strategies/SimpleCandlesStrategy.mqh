//+------------------------------------------------------------------+
//|                                        SimpleCandlesStrategy.mqh |
//|                                      Copyright 2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/articles/17277"
#property version   "1.03"

#include "../../Adwizard/Virtual/VirtualStrategy.mqh"

/** Описание стратегии

Входные параметры:

 - Символ
 - Таймфрейм для подсчёта однонаправленных свечей
 - Количество однонаправленных свечей (signalSeqLen)
 - Период ATR (periodATR)
 - Stop Loss (в пунктах или % ATR) (stopLevel)
 - Take Profit (в пунктах или % ATR) (takeLevel)
 - Максимальное количество одновременно отрытых позиций (maxCountOfOrders)
 - Максимальный размер спреда (maxSpread)
 - Размер позиций

При наступлении нового бара проверяем направления последних закрытых signalSeqLen свечей.

Если направления одинаковые и количество открытых позиций меньше maxCountOfOrders
и текущий спред меньше maxSpread, то:
 - Вычисляем StopLoss и TakeProfit. Если periodATR = 0, то просто отступаем от текущей
   цены на количество пунктов, взятых из параметров stopLevel и takeLevel.
   Если periodATR > 0, то рассчитываем величину ATR, используя параметр periodATR
   для дневного таймфрейма.
   От текущей цены отступаем на величины ATR * stopLevel и ATR * takeLevel.

 - Открываем позицию SELL, если направления свечей были вверх и
   позицию BUY, если направления свечей были вниз.
   При открытии устанавливаем рассчитанные ранее уровни StopLoss и TakeProfit.
*/


//+------------------------------------------------------------------+
//| Торговая стратегия c использованием однонаправленных свечей      |
//+------------------------------------------------------------------+
class CSimpleCandlesStrategy : public CVirtualStrategy {
protected:
   string            m_symbol;            // Символ (торговый инструмент)
   ENUM_TIMEFRAMES   m_timeframe;         // Период графика (таймфрейм)

   //---  Параметры сигнала к открытию
   int               m_signalSeqLen;      // Количество однонаправленных свечей
   int               m_periodATR;         // Период ATR

   //---  Параметры позиций
   double            m_stopLevel;         // Stop Loss (в пунктах или % ATR)
   double            m_takeLevel;         // Take Profit (в пунктах или % ATR)

   //---  Параметры управление капиталом
   int               m_maxCountOfOrders;  // Макс. количество одновременно отрытых позиций
   int               m_maxSpread;         // Макс. допустимый спред (в пунктах)

   CSymbolInfo       *m_symbolInfo;       // Объект для получения информации о свойствах символа

   double            m_tp;                // Stop Loss в пунктах
   double            m_sl;                // Take Profit в пунктах

   //--- Методы
   int               SignalForOpen();     // Сигнал для открытия позиции
   void              OpenBuy();           // Открытие позиции BUY
   void              OpenSell();          // Открытие позиции SELL

   double            ChannelWidth(ENUM_TIMEFRAMES p_tf = PERIOD_D1); // Расчёт величины ATR
   void              UpdateLevels();      // Обновление уровней SL и TP

   // Закрытый конструктор
                     CSimpleCandlesStrategy(string p_params);

public:
   // Статический конструктор
                     STATIC_CONSTRUCTOR(CSimpleCandlesStrategy);

   virtual string    operator~() override;   // Преобразование объекта в строку
   virtual void      Tick() override;        // Обработчик события OnTick
};

// Регистрация класса-наследника CFactorable
REGISTER_FACTORABLE_CLASS(CSimpleCandlesStrategy);


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CSimpleCandlesStrategy::CSimpleCandlesStrategy(string p_params) {
// Читаем параметры из строки инициализации
   m_params = p_params;
   m_symbol = ReadString(p_params);
   m_timeframe = (ENUM_TIMEFRAMES) ReadLong(p_params);
   m_signalSeqLen = (int) ReadLong(p_params);
   m_periodATR = (int) ReadLong(p_params);
   m_stopLevel = ReadDouble(p_params);
   m_takeLevel = ReadDouble(p_params);
   m_maxCountOfOrders = (int) ReadLong(p_params);
   m_maxSpread = (int) ReadLong(p_params);

   if(IsValid()) {
      // Запрашиваем нужное количество объектов для виртуальных позиций
      CVirtualReceiver::Get(&this, m_orders, m_maxCountOfOrders);

      // Добавляем отслеживание нового бара на нужном таймфрейме
      IsNewBar(m_symbol, m_timeframe);

      // Создаём информационный объект для нужного символа
      m_symbolInfo = CSymbolsMonitor::Instance()[m_symbol];
   }
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CSimpleCandlesStrategy::operator~() {
   return StringFormat("%s(%s)", typename(this), m_params);
}

//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void CSimpleCandlesStrategy::Tick() override {
// Если наступил новый бар по заданному символу и таймфрейму
   if(IsNewBar(m_symbol, m_timeframe)) {
// Если количество открытых позиций меньше допустимого
      if(m_ordersTotal < m_maxCountOfOrders) {
         // Получаем сигнал на открытие
         int signal = SignalForOpen();

         if(signal == 1) {          // Если сигнал на покупку, то
            OpenBuy();              // открываем позицию BUY
         } else if(signal == -1) {  // Если сигнал на продажу, то
            OpenSell();             // открываем позицию SELL_STOP
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Сигнал для открытия отложенных ордеров                           |
//+------------------------------------------------------------------+
int CSimpleCandlesStrategy::SignalForOpen() {
// По-умолчанию сигнала на открытие нет
   int signal = 0;

   MqlRates rates[];
// Копируем значения котировок (свечей) в массив-приёмник.
// Для проверки сигнала нам нужно m_signalSeqLen закрытых свечей и текущая свеча,
// поэтому всего m_signalSeqLen + 1
   int res = CopyRates(m_symbol, m_timeframe, 0, m_signalSeqLen + 1, rates);

// Если скопировалось нужное количество свечей
   if(res == m_signalSeqLen + 1) {
      signal = 1; // сигнал на покупку

      // Перебираем все закрытые свечи
      for(int i = 1; i <= m_signalSeqLen; i++) {
         // Если встречается хоть одна свеча вверх, то отменяем сигнал
         if(rates[i].open < rates[i].close ) {
            signal = 0;
            break;
         }
      }

      if(signal == 0) {
         signal = -1; // иначе - сигнал на продажу

         // Перебираем все закрытые свечи
         for(int i = 1; i <= m_signalSeqLen; i++) {
            // Если встречается хоть одна свеча вниз, то отменяем сигнал
            if(rates[i].open > rates[i].close ) {
               signal = 0;
               break;
            }
         }
      }
   }

// Если сигнал есть, то
   if(signal != 0) {
      // Если текущий спред больше максимально разрешённого, то
      if(rates[0].spread > m_maxSpread) {
         PrintFormat(__FUNCTION__" | IGNORE %s Signal, spread is too big (%d > %d)",
                     (signal > 0 ? "BUY" : "SELL"),
                     rates[0].spread, m_maxSpread);
         signal = 0; // Отменяем сигнал
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Открытие ордера BUY                                              |
//+------------------------------------------------------------------+
void CSimpleCandlesStrategy::OpenBuy() {
// Берем необходимую нам информацию о символе и ценах
   double point = m_symbolInfo.Point();
   int digits = m_symbolInfo.Digits();

// Цена открытия
   double price = m_symbolInfo.Ask();

// Обновим уровни SL и TP, рассчитав ATR
   UpdateLevels();

// Уровни StopLoss и TakeProfit
   double sl = NormalizeDouble(price - m_sl * point, digits);
   double tp = NormalizeDouble(price + m_tp * point, digits);

   bool res = false;
   for(int i = 0; i < m_maxCountOfOrders; i++) {   // Перебираем все виртуальные позиции
      if(!m_orders[i].IsOpen()) {                  // Если нашли не открытую, то открываем
         // Открытие виртуальной позиции SELL
         res = m_orders[i].Open(m_symbol, ORDER_TYPE_BUY, m_fixedLot,
                                0,
                                NormalizeDouble(sl, digits),
                                NormalizeDouble(tp, digits));

         break; // и выходим
      }
   }

   if(!res) {
      PrintFormat(__FUNCTION__" | ERROR opening BUY virtual order", 0);
   }
}

//+------------------------------------------------------------------+
//| Открытие ордера SELL                                             |
//+------------------------------------------------------------------+
void CSimpleCandlesStrategy::OpenSell() {
// Берем необходимую нам информацию о символе и ценах
   double point = m_symbolInfo.Point();
   int digits = m_symbolInfo.Digits();

// Цена открытия
   double price = m_symbolInfo.Bid();

// Обновим уровни SL и TP, рассчитав ATR
   UpdateLevels();

// Уровни StopLoss и TakeProfit
   double sl = NormalizeDouble(price + m_sl * point, digits);
   double tp = NormalizeDouble(price - m_tp * point, digits);

   bool res = false;
   for(int i = 0; i < m_maxCountOfOrders; i++) {   // Перебираем все виртуальные позиции
      if(!m_orders[i].IsOpen()) {                  // Если нашли не открытую, то открываем
         // Открытие виртуальной позиции SELL

         res = m_orders[i].Open(m_symbol, ORDER_TYPE_SELL, m_fixedLot,
                                0,
                                NormalizeDouble(sl, digits),
                                NormalizeDouble(tp, digits));

         break;   // и выходим
      }
   }

   if(!res) {
      PrintFormat(__FUNCTION__" | ERROR opening SELL virtual order", 0);
   }
}

//+------------------------------------------------------------------+
//| Обновление уровней SL и TP по рассчитанному ATR                  |
//+------------------------------------------------------------------+
void CSimpleCandlesStrategy::UpdateLevels() {
// Рассчитываем ATR
   double channelWidth = (m_periodATR > 0 ? ChannelWidth() : 1);

// Обновляем уровни SL и TP
   m_sl = m_stopLevel * channelWidth;
   m_tp = m_takeLevel * channelWidth;
}

//+------------------------------------------------------------------+
//| Расчёт величины ATR (нестандартная реализация)                   |
//+------------------------------------------------------------------+
double CSimpleCandlesStrategy::ChannelWidth(ENUM_TIMEFRAMES p_tf = PERIOD_D1) {
   int n = m_periodATR; // Количество баров для расчёта
   MqlRates rates[];    // Массив для котировок

// Копируем котировки дневного (по умолчанию) таймфрейма
   int res = CopyRates(m_symbol, p_tf, 1, n, rates);

// Если скопировалось нужное количество
   if(res == n) {
      double tr[];         // Массив для диапазонов цены
      ArrayResize(tr, n);  // Изменяем его размер

      double s = 0;        // Сумма для подсчёта среднего
      FOREACH(rates) {
         tr[i] = rates[i].high - rates[i].low; // Запоминаем размер бара
      }

      ArraySort(tr); // Сортируем размеры

      // Суммируем внутренние две четверти размеров баров
      for(int i = n / 4; i < n * 3 / 4; i++) {
         s += tr[i];
      }

      // Возвращаем средний размер в пунктах
      return 2 * s / n / m_symbolInfo.Point();
   }

   return 0.0;
}
//+------------------------------------------------------------------+
