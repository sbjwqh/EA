//+------------------------------------------------------------------+
//|                                                 VirtualOrder.mqh |
//|                                 Copyright 2019-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.09"

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Предварительные определения классов                              |
//+------------------------------------------------------------------+
class CVirtualOrder;
class CVirtualReceiver;
class CVirtualStrategy;

#include "../Utils/SymbolsMonitor.mqh"
#include "VirtualReceiver.mqh"
#include "VirtualStrategy.mqh"

// Структура для чтения/записи из БД 
// основных свойств виртуального ордера/позиции
struct VirtualOrderStruct {
   string            strategyHash;
   int               strategyIndex;
   ulong             ticket;
   string            symbol;
   double            lot;
   ENUM_ORDER_TYPE   type;
   datetime          openTime;
   double            openPrice;
   double            stopLoss;
   double            takeProfit;
   datetime          closeTime;
   double            closePrice;
   datetime          expiration;
   string            comment;
   double            point;
};

//+------------------------------------------------------------------+
//| Класс виртуальных ордеров и позиций                              |
//+------------------------------------------------------------------+
class CVirtualOrder {
private:
//--- Статические поля
   static ulong      s_count;          // Счётчик всех созданных объектов CVirtualOrder
   static ulong      s_ticket;
   CSymbolInfo       *m_symbolInfo;    // Объект для получения свойств символов

//--- Связанные объекты получателя и стратегии
   CSymbolsMonitor   *m_symbols;
   CVirtualReceiver  *m_receiver;
   CVirtualStrategy  *m_strategy;

//--- Свойства ордера (позиции)
   ulong             m_id;             // ID
   ulong             m_ticket;         // Тикет
   string            m_symbol;         // Символ
   double            m_lot;            // Объем
   ENUM_ORDER_TYPE   m_type;           // Тип
   double            m_openPrice;      // Цена открытия
   double            m_stopLoss;       // Уровень StopLoss
   double            m_takeProfit;     // Уровень TakeProfit
   string            m_comment;        // Комментарий
   datetime          m_expiration;     // Время истечения

   datetime          m_openTime;       // Время открытия

//--- Свойства закрытого ордера (позиции)
   double            m_closePrice;     // Цена закрытия
   datetime          m_closeTime;      // Время закрытия
   string            m_closeReason;    // Причина закрытия

   double            m_point;          // Величина пункта

   bool              m_isStopLoss;     // Признак срабатывания StopLoss
   bool              m_isTakeProfit;   // Признак срабатывания TakeProfit
   bool              m_isExpired;      // Признак истечения времени

//--- Частные методы
   bool              CheckClose();     // Проверка условий закрытия
   bool              CheckTrigger();   // Проверка срабатывания отложенного ордера

public:
                     CVirtualOrder(
      CVirtualStrategy *p_strategy
   );                                  // Конструктор

                    ~CVirtualOrder() {
      if(!!m_symbolInfo) delete m_symbolInfo;
   }

//--- Методы проверки состояния позиции (ордера)
   bool              IsOpen() {        // Ордер открыт?
      return(this.m_openTime > 0 && this.m_closeTime == 0);
   };
   bool              IsClosed() {      // Ордер закрыт?
      return(this.m_openTime > 0 && this.m_closeTime > 0);
   };
   bool              IsMarketOrder() { // Это рыночная позиция?
      return IsOpen() && (m_type == ORDER_TYPE_BUY || m_type == ORDER_TYPE_SELL);
   }
   bool              IsPendingOrder() {// Это отложенный ордер?
      return IsOpen() && (m_type == ORDER_TYPE_BUY_LIMIT
                          || m_type == ORDER_TYPE_BUY_STOP
                          || m_type == ORDER_TYPE_SELL_LIMIT
                          || m_type == ORDER_TYPE_SELL_STOP);
   }
   bool              IsBuyOrder() {    // Это открытая позиция BUY?
      return IsOpen() && (m_type == ORDER_TYPE_BUY
                          || m_type == ORDER_TYPE_BUY_LIMIT
                          || m_type == ORDER_TYPE_BUY_STOP);
   }
   bool              IsSellOrder() {   // Это открытая позиция SELL?
      return IsOpen() && (m_type == ORDER_TYPE_SELL
                          || m_type == ORDER_TYPE_SELL_LIMIT
                          || m_type == ORDER_TYPE_SELL_STOP);
   }
   bool              IsStopOrder() {   // Это отложенный STOP-ордер?
      return IsOpen() && (m_type == ORDER_TYPE_BUY_STOP || m_type == ORDER_TYPE_SELL_STOP);
   }
   bool              IsLimitOrder() {  // Это отложенный LIMIT-ордер?
      return IsOpen() && (m_type == ORDER_TYPE_BUY_LIMIT || m_type == ORDER_TYPE_SELL_LIMIT);
   }

//--- Методы получения свойств позиции (ордера)
   ulong             Id() {            // ID
      return m_id;
   }
   ulong             Ticket() {        // Тикет
      return m_ticket;
   }
   CStrategy         *Strategy() {
      return m_strategy;
   }
   ENUM_ORDER_TYPE   Type() {
      return m_type;
   }
   string            TypeName() {
      string s = StringSubstr(EnumToString(m_type), 11);
      StringReplace(s, "_", " ");
      return s;
   }
   double            Lot() {
      return m_lot;
   }
   double            Volume() {        // Объем с направлением
      return IsBuyOrder() ? m_lot : (IsSellOrder() ? -m_lot : 0);
   }
   double            Profit();         // Текущая прибыль
   double            ClosedProfit();

   string            Symbol() {        // Символ
      return m_symbol;
   }
   double            OpenPrice() {
      return m_openPrice;
   }
   datetime          OpenTime() {
      return m_openTime;
   }
   double            ClosePrice() {
      return m_closePrice;
   }
   datetime          CloseTime() {
      return m_closeTime;
   }
   double            FittedBalance() {
      return m_strategy.FittedBalance();
   }
   double            StopLoss() {
      return m_stopLoss;
   }
   void              StopLoss(double value) {
      m_stopLoss = value;
   }
   double            TakeProfit() {
      return m_takeProfit;
   }
   void              TakeProfit(double value) {
      m_takeProfit = value;
   }

//--- Методы обработки позиций (ордеров)
   bool              CVirtualOrder::Open(string symbol,
                                         ENUM_ORDER_TYPE type,
                                         double lot,
                                         double price,
                                         double sl = 0,
                                         double tp = 0,
                                         string comment = "",
                                         datetime expiration = 0,
                                         bool inPoints = false); // Открытие позиции (ордера)

   void              Expiration(datetime p_expiration) {
      if(IsOpen()) {
         m_expiration = p_expiration;
      }
   }

   void              Tick();     // Обработка тика для позиции (ордера)
   void              Close();    // Закрытие позиции (ордера)
   void              Clear() {
      m_lot = 0;
   }

   virtual void      Load(const VirtualOrderStruct &o);   // Загрузка состояния
   virtual void      Save(VirtualOrderStruct &o);   // Сохранение состояния

   static void       Reset() {
      s_count = 0;
   }

   // Есть ли открытые рыночные виртуальные позиции?
   static bool       HasMarket(CVirtualOrder* &p_orders[]);

   string            operator~();         // Преобразование объекта в строку
};

// Инициализация статических полей класса
ulong                CVirtualOrder::s_count = 0;
ulong                CVirtualOrder::s_ticket = 0;

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualOrder::CVirtualOrder(CVirtualStrategy *p_strategy) :
// Список инициализации
   m_id(++s_count),  // Новый идентификатор = счётчик объектов + 1
   m_ticket(0),
   m_receiver(CVirtualReceiver::Instance()),
   m_strategy(p_strategy),
   m_symbol(""),
   m_lot(0),
   m_type(-1),
   m_openPrice(0),
   m_stopLoss(0),
   m_takeProfit(0),
   m_openTime(0),
   m_comment(""),
   m_expiration(0),
   m_closePrice(0),
   m_closeTime(0),
   m_closeReason(""),
   m_point(0) {
   PrintFormat(__FUNCTION__ + "#%d | CREATED VirtualOrder", m_id);
   m_symbolInfo = NULL;
   m_symbols = CSymbolsMonitor::Instance();
}

//+------------------------------------------------------------------+
//| Открытие виртуальной позиции (ордера)                            |
//+------------------------------------------------------------------+
bool CVirtualOrder::Open(string symbol,         // Символ
                         ENUM_ORDER_TYPE type,  // Тип (BUY или SELL)
                         double lot,            // Объём
                         double price = 0,      // Цена открытия
                         double sl = 0,         // Уровень StopLoss (цена или пункты)
                         double tp = 0,         // Уровень TakeProfit (цена или пункты)
                         string comment = "",   // Комментарий
                         datetime expiration = 0,  // Время истечения
                         bool inPoints = false  // Уровни SL и TP заданы в пунктах?
                        ) {
   if(IsOpen()) { // Если позиция уже открыта, то ничего не делаем
      PrintFormat(__FUNCTION__ "#%d | ERROR: Order is opened already!", m_id);
      return false;
   }

// Получаем от монитора символов указатель на информационный объект для нужного символа
   m_symbolInfo = m_symbols[symbol];

   if(!!m_symbolInfo) {
      //m_symbolInfo.RefreshRates();  // Обновляем информацию о текущих ценах

      // Инициализируем свойства позиции
      m_ticket = ++s_ticket;
      m_openPrice = price;
      m_symbol = symbol;
      m_lot = lot;
      m_openTime = TimeCurrent();
      m_closeTime = 0;
      m_type = type;
      m_comment = comment;
      m_expiration = expiration;

      // Открываемая позиция (ордер) не является закрытой по SL, TP или истечению
      m_isStopLoss = false;
      m_isTakeProfit = false;
      m_isExpired = false;

      m_point = m_symbolInfo.Point();

      double bid = m_symbolInfo.Bid();
      double ask = m_symbolInfo.Ask();
      double spread = ((ask - bid) / m_point);

      //m_symbolInfo.Spread();

      // В зависимости от направления устанавливаем цену открытия и уровни SL и TP.
      // Если SL и TP заданы в пунктах, то предварительно вычисляем их ценовые уровни
      // относительно цены открытия
      if(IsBuyOrder()) {
         if(type == ORDER_TYPE_BUY) {
            m_openPrice = ask;
         }
         m_stopLoss = (sl > 0 ? (inPoints ? m_openPrice - sl * m_point - spread * m_point : sl) : 0);
         m_takeProfit = (tp > 0 ? (inPoints ? m_openPrice + tp * m_point : tp) : 0);
      } else if(IsSellOrder()) {
         if(type == ORDER_TYPE_SELL) {
            m_openPrice = bid;
         }
         m_stopLoss = (sl > 0 ? (inPoints ? m_openPrice + sl * m_point : sl) : 0);
         m_takeProfit = (tp > 0 ? (inPoints ? m_openPrice - tp * m_point - spread * m_point : tp) : 0);
      }

      // Оповещаем получатель и стратегию, что позиция (ордер) открыта
      m_receiver.OnOpen(&this);
      m_strategy.OnOpen(&this);

      PrintFormat(__FUNCTION__"#%d | OPEN %s: %s %s %.2f | Price=%.5f | SL=%.5f | TP=%.5f | %s | %s",
                  m_id, (IsMarketOrder() ? "Market" : "Pending"), StringSubstr(EnumToString(type), 11),
                  m_symbol, m_lot, m_openPrice, m_stopLoss, m_takeProfit, m_comment,
                  (m_expiration ? TimeToString(m_expiration) : "-"));

      return true;
   } else {
      PrintFormat(__FUNCTION__"#%d | ERROR: Can't find symbol %s for "
                  "OPEN %s: %s %s %.2f | Price=%.5f | SL=%.5f | TP=%.5f | %s | %s",
                  m_id, m_symbol, (IsMarketOrder() ? "Market" : "Pending"), StringSubstr(EnumToString(type), 11),
                  m_symbol, m_lot, m_openPrice, m_stopLoss, m_takeProfit, m_comment,
                  (m_expiration ? TimeToString(m_expiration) : "-"));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Закрытие позиции                                                 |
//+------------------------------------------------------------------+
void CVirtualOrder::Close() {
   if(IsOpen()) { // Если позиция открыта
      // Определяем причину закрытия для вывода в лог
      string closeReason = "";

      if(m_isStopLoss) {
         closeReason += "[SL]";
      } else if(m_isTakeProfit) {
         closeReason += "[TP]";
      } else if(m_isExpired) {
         closeReason += "[EX]";
      } else {
         closeReason += "[CL]";
      }

      PrintFormat(__FUNCTION__ + "#%d | CLOSE %s: %s %s %.2f | Profit=%.2f %s | %s",
                  m_id, (IsMarketOrder() ? "Market" : "Pending"), StringSubstr(EnumToString(m_type), 11),
                  m_symbol, m_lot, Profit(), closeReason, m_comment);

      m_closeTime = TimeCurrent();  // Время закрытия позиции

      // Запоминаем цену закрытия в зависимости от типа
      if(m_type == ORDER_TYPE_BUY) {
         m_closePrice = m_symbolInfo.Bid();
      } else if(m_type == ORDER_TYPE_SELL) {
         m_closePrice = m_symbolInfo.Ask();
      } else {
         m_closePrice = 0;
      }

      // Оповещаем получатель и стратегию, что позиция (ордер) закрыта
      m_receiver.OnClose(&this);
      m_strategy.OnClose(&this);
   }
}

//+------------------------------------------------------------------+
//| Расчет текущей прибыли позиции                                   |
//+------------------------------------------------------------------+
double CVirtualOrder::Profit() {
   double profit = 0;
   if(IsMarketOrder()) {   // Если это открытая рыночная виртуальная позиция
      //m_symbolInfo.Name(m_symbol);     // Выбираем нужный символ
      //m_symbolInfo.RefreshRates();     // Обновляем информацию о текущих ценах

      // Текущая цена, по которой можно закрыть позицию
      double closePrice = (m_type == ORDER_TYPE_BUY) ? m_symbolInfo.Bid() : m_symbolInfo.Ask();

      // Прибыль в виде разности цен открытия и закрытия
      if(m_type == ORDER_TYPE_BUY) {
         profit = closePrice - m_openPrice;
      } else {
         profit = m_openPrice - closePrice;
      }

      if(m_point > 1e-10) {   // Если известен размер пункта, то
         // Пересчитываем прибыль из разности цен в денежное выражение для объёма в 1 лот
         if(profit > 0) {
            profit = profit / m_point * m_symbolInfo.TickValueProfit();
         } else {
            profit = profit / m_point * m_symbolInfo.TickValueLoss();
         }
      } else {
         PrintFormat(__FUNCTION__ + "#%d | ERROR: Point for %s is undefined", m_id, m_symbol);
         m_point = m_symbolInfo.Point();
      }
      // Пересчитываем прибыль для объёма позиции
      profit *= m_lot;
   }

   return profit;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CVirtualOrder::ClosedProfit() {
   double profit = 0;
   if(IsClosed() && !!m_symbolInfo) {

      // Если это открытая рыночная виртуальная позиция
      //s_symbolInfo.Name(m_symbol);     // Выбираем нужный символ
      //s_symbolInfo.RefreshRates();     // Обновляем информацию о текущих ценах

      // Текущая цена, по которой можно закрыть позицию
      double closePrice = m_closePrice;

      // Прибыль в виде разности цен открытия и закрытия
      if(m_type == ORDER_TYPE_BUY) {
         profit = closePrice - m_openPrice;
      } else if(m_type == ORDER_TYPE_SELL) {
         profit = m_openPrice - closePrice;
      }

      if(m_point > 1e-10) {   // Если известен размер пункта, то
         // Пересчитываем прибыль из разности цен в денежное выражение для объёма в 1 лот
         if(profit > 0) {
            profit = profit / m_point * m_symbolInfo.TickValueProfit();
         } else {
            profit = profit / m_point * m_symbolInfo.TickValueLoss();
         }
      } else {
         PrintFormat(__FUNCTION__ + "#%d | ERROR: Point for %s is undefined", m_id, m_symbol);
         m_point = m_symbolInfo.Point();
      }
      // Пересчитываем прибыль для объёма позиции
      profit *= m_lot;
   }

   return profit;
}

//+------------------------------------------------------------------+
//| Проверка необходимости закрытия по SL, TP или EX                 |
//+------------------------------------------------------------------+
bool CVirtualOrder::CheckClose() {
   if(IsMarketOrder()) {               // Если это открытая рыночная виртуальная позиция, то
      //s_symbolInfo.Name(m_symbol);     // Выбираем нужный символ
      //s_symbolInfo.RefreshRates();     // Обновляем информацию о текущих ценах

      // Текущая цена, по которой можно закрыть позицию
      double closePrice = (m_type == ORDER_TYPE_BUY) ? m_symbolInfo.Bid() : m_symbolInfo.Ask();
      //double spread = m_symbolInfo.Spread();
      //double lastHigh = iHigh(m_symbol, PERIOD_M1, 1);
      //double lastLow = iLow(m_symbol, PERIOD_M1, 1) + spread;

      bool res = false;
      // Проверяем, что цена достигла SL или TP
      if(m_type == ORDER_TYPE_BUY) {
         m_isStopLoss = (m_stopLoss > 0 && closePrice <= m_stopLoss);
         m_isTakeProfit = (m_takeProfit > 0 && (closePrice >= m_takeProfit
                                                //|| lastHigh >= m_takeProfit
                                               ));
      } else if(m_type == ORDER_TYPE_SELL) {
         m_isStopLoss = (m_stopLoss > 0 && closePrice >= m_stopLoss);
         m_isTakeProfit = (m_takeProfit > 0 && (closePrice <= m_takeProfit
                                                // || lastLow <= m_takeProfit
                                               ));
      }

      // Был ли достигнут SL или TP?
      res = (m_isStopLoss || m_isTakeProfit);

      if(res) {
         PrintFormat(__FUNCTION__ + "#%d | %s REACHED at %.5f: %.5f | %.5f, Profit=%.2f | %s",
                     m_id, (m_isStopLoss ? "SL" : "TP"), closePrice, m_stopLoss, m_takeProfit,
                     Profit(), m_comment);
         return true;
      }
   } else if(IsPendingOrder()) {    // Если это виртуальный отложенный ордер
      // Проверяем, было ли достигнуто время истечения, если оно задано
      if(m_expiration > 0 && m_expiration < TimeCurrent()) {
         m_isExpired = true;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Обработка тика одного виртуального ордера (позиции)              |
//+------------------------------------------------------------------+
void CVirtualOrder::Tick() {
   if(IsOpen()) {  // Если это открытая виртуальная позиция или ордер
      if(CheckClose()) {  // Проверяем, достигнуты ли уровни SL или TP или время истечения
         Close();         // Закрываем при достижении
      } else if (IsPendingOrder()) {   // Если это отложенный ордер
         CheckTrigger();  // Проверяем его срабатывание
      }
   }
}

//+------------------------------------------------------------------+
//| Проверка срабатывания отложенного ордера                         |
//+------------------------------------------------------------------+
bool CVirtualOrder::CheckTrigger() {
   if(IsPendingOrder()) {
      //m_symbolInfo.Name(m_symbol);     // Выбираем нужный символ
      //m_symbolInfo.RefreshRates();     // Обновляем информацию о текущих ценах
      double bid = m_symbolInfo.Bid();
      double ask = m_symbolInfo.Ask();
      double spread = ((ask - bid) / m_point);

      double price = (IsBuyOrder()) ? ask : bid;


      // Если цена дошла до уровней открытия, то превращаем ордер в позицию
      if(false
            || (m_type == ORDER_TYPE_BUY_LIMIT && price <= m_openPrice)
            || (m_type == ORDER_TYPE_BUY_STOP  && price >= m_openPrice)
        ) {
         PrintFormat(__FUNCTION__"#%d | OPEN %s at %.5f -> BUY at %.5f (Spread: %.0f)",
                     m_id, StringSubstr(EnumToString(m_type), 11), m_openPrice, price, spread);
         m_type = ORDER_TYPE_BUY;
      } else if(false
                || (m_type == ORDER_TYPE_SELL_LIMIT && price >= m_openPrice)
                || (m_type == ORDER_TYPE_SELL_STOP  && price <= m_openPrice)
               ) {
         PrintFormat(__FUNCTION__"#%d | OPEN %s at %.5f -> SELL at %.5f (Spread: %.0f)",
                     m_id, StringSubstr(EnumToString(m_type), 11), m_openPrice, price, spread);
         m_type = ORDER_TYPE_SELL;
      }

      // Если ордер превратился в позицию
      if(IsMarketOrder()) {
         m_openPrice = price; // Запоминаем цену открытия

         // Оповещаем получатель и стратегию, что открыта позиция
         m_receiver.OnOpen(&this);
         m_strategy.OnOpen(&this);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Сохранение состояния                                             |
//+------------------------------------------------------------------+
void CVirtualOrder::Save(VirtualOrderStruct &o) {
   o.ticket = m_ticket;
   o.symbol = m_symbol;
   o.lot = m_lot;
   o.type = m_type;
   o.openPrice = m_openPrice;
   o.stopLoss = m_stopLoss;
   o.takeProfit = m_takeProfit;
   o.openTime = m_openTime;
   o.closePrice = m_closePrice;
   o.closeTime = m_closeTime;
   o.expiration = m_expiration;
   o.comment = m_comment;
   o.point = m_point;
}


//+------------------------------------------------------------------+
//| Загрузка состояния                                               |
//+------------------------------------------------------------------+
void CVirtualOrder::Load(const VirtualOrderStruct &o) {
   m_ticket = o.ticket;
   m_symbol = o.symbol;
   m_lot = o.lot;
   m_type = o.type;
   m_openPrice = o.openPrice;
   m_stopLoss = o.stopLoss;
   m_takeProfit = o.takeProfit;
   m_openTime = o.openTime;
   m_closePrice = o.closePrice;
   m_closeTime = o.closeTime;
   m_expiration = o.expiration;
   m_comment = o.comment;
   m_point = o.point;

   PrintFormat(__FUNCTION__" | %s", ~this);

   s_ticket = MathMax(s_ticket, m_ticket);
   
   m_symbolInfo = m_symbols[m_symbol];

// Оповещаем получатель и стратегию, что позиция (ордер) открыта
   if(IsOpen()) {
      m_receiver.OnOpen(&this);
      m_strategy.OnOpen(&this);
   } else {
      m_receiver.OnClose(&this);
      m_strategy.OnClose(&this);
   }
}

//+------------------------------------------------------------------+
//| Есть ли открытые рыночные виртуальные позиции?                               |
//+------------------------------------------------------------------+
bool CVirtualOrder::HasMarket(CVirtualOrder *&p_orders[]) {
   FOREACH(p_orders) if (p_orders[i].IsMarketOrder()) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Преобразование объекта в строку                                  |
//+------------------------------------------------------------------+
string CVirtualOrder::operator~() {
   if(IsOpen()) {
      return StringFormat("#%d %s %s %.2f in %s at %.5f (%.5f, %.5f). %s, %f",
                          m_id, TypeName(), m_symbol, m_lot,
                          TimeToString(m_openTime), m_openPrice,
                          m_stopLoss, m_takeProfit,
                          TimeToString(m_closeTime), m_closePrice);
   } else {
      return StringFormat("#%d --- ", m_id);
   }

}
//+------------------------------------------------------------------+
