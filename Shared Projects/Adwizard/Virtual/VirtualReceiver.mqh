//+------------------------------------------------------------------+
//|                                              VirtualReceiver.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.04"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CVirtualSymbolReceiver;
class CVirtualInterface;

#include "../Utils/Macros.mqh"
#include "../Base/Receiver.mqh"
#include "VirtualOrder.mqh"
#include "VirtualSymbolReceiver.mqh"
#include "VirtualInterface.mqh"

//+------------------------------------------------------------------+
//| Класс перевода открытых объемов в рыночные позиции (получатель)  |
//+------------------------------------------------------------------+
class CVirtualReceiver : public CReceiver {
protected:
// Статический указатель на единственный экземпляр данного класса
   static   CVirtualReceiver *s_instance;

   CVirtualOrder     *m_orders[];         // Массив виртуальных позиций

   CVirtualSymbolReceiver
   *m_symbolReceivers[];                  // Массив получателей для отдельных символов

   CVirtualInterface
   *m_interface;                          // Объект интерфейса для показа состояния пользователю

//--- Частные методы
                     CVirtualReceiver();                    // Закрытый конструктор
   bool              IsTradeAllowed();    // Торговля доступна?

public:
   static   datetime          s_lastChangeTime;       // Время последней успешной коррекции

                    ~CVirtualReceiver();  // Деструктор

//--- Статические методы
   static
   CVirtualReceiver  *Instance(ulong p_magic = 0);    // Синглтон - создание и получение единственного экземпляра

   static void       Get(CVirtualStrategy *strategy,
                         CVirtualOrder *&orders[],
                         int n); // Выделение стратегии необходимого количества виртуальных позиций

//--- Публичные методы
   virtual void      Changed()   override;
   void              OnOpen(CVirtualOrder *p_order);  // Обработка открытия виртуальной позиции
   void              OnClose(CVirtualOrder *p_order); // Обработка закрытия виртуальной позиции
   void              Tick();     // Обработка тика для массива виртуальных ордеров (позиций)

   virtual bool      Correct() override;              // Корректировка открытых объёмов

   // Оператор получения объекта символьного получателя
   CVirtualSymbolReceiver*      operator[](const string symbol);

   CVirtualOrder*    Order(int i);
   int               OrdersTotal();
};

// Инициализация статического указателя на единственный экземпляр данного класса
CVirtualReceiver *CVirtualReceiver::s_instance = NULL;
datetime CVirtualReceiver::s_lastChangeTime = 0;

//+------------------------------------------------------------------+
//| Закрытый конструктор                                             |
//+------------------------------------------------------------------+
CVirtualReceiver::CVirtualReceiver() :
   m_interface(CVirtualInterface::Instance()) {
   CVirtualOrder::Reset();
}

//+------------------------------------------------------------------+
//| Торговля доступна?                                               |
//+------------------------------------------------------------------+
bool CVirtualReceiver::IsTradeAllowed() {
   return (true
           && MQLInfoInteger(MQL_TRADE_ALLOWED)
           && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
           && AccountInfoInteger(ACCOUNT_TRADE_EXPERT)
           && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)
           && TerminalInfoInteger(TERMINAL_CONNECTED)
          );
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CVirtualReceiver::~CVirtualReceiver() {
   FOREACH(m_orders) delete m_orders[i]; // Удаляем виртуальные позиции
   FOREACH(m_symbolReceivers) delete m_symbolReceivers[i]; // Удаляем символьные получатели
}

//+------------------------------------------------------------------+
//| Синглтон - создание и получение единственного экземпляра         |
//+------------------------------------------------------------------+
CVirtualReceiver* CVirtualReceiver::Instance(ulong p_magic = 0) {
   if(!s_instance) {
      s_instance = new CVirtualReceiver();
   }
   if(s_magic == 0 && p_magic != 0) {
      s_magic = p_magic;
   }
   return s_instance;
}

//+------------------------------------------------------------------+
//| Выделение стратегии необходимого количества виртуальных позиций  |
//+------------------------------------------------------------------+
static void CVirtualReceiver::Get(CVirtualStrategy *strategy,   // Стратегия
                                  CVirtualOrder *&orders[],     // Массив позиций стратегии
                                  int n                         // Требуемое количество
                                 ) {
   CVirtualReceiver *self = Instance();   // Синглтон получателя
   CVirtualInterface *draw = CVirtualInterface::Instance();
   ArrayResize(orders, n);                // Расширяем массив виртуальных позиций
   FOREACH(orders) {
      orders[i] = new CVirtualOrder(strategy); // Наполняем массив новыми объектами
      APPEND(self.m_orders, orders[i]);
      draw.Add(orders[i]); // Регистрируем созданную виртуальную позицию
   }
   PrintFormat(__FUNCTION__ + " | OK, Strategy orders: %d from %d total",
               ArraySize(orders),
               ArraySize(self.m_orders));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CVirtualReceiver::Changed() {
   m_isChanged = true;
   FOREACH(m_symbolReceivers) m_symbolReceivers[i].Changed();
}

//+------------------------------------------------------------------+
//| Обработка открытия виртуальной позиции                           |
//+------------------------------------------------------------------+
void CVirtualReceiver::OnOpen(CVirtualOrder *p_order) {
   m_interface.Changed(p_order);

   if(p_order.IsPendingOrder()) {         // Если это виртуальный отложенный ордер,
      return;                             // то ничего не делаем
   }

   CVirtualSymbolReceiver* symbolReceiver = this[p_order.Symbol()];

   PrintFormat(__FUNCTION__"#%s | OPEN VirtualOrder #%d", p_order.Symbol(),  p_order.Id());
   symbolReceiver.Open(p_order); // Оповещаем символьный получатель о новой позиции
   m_isChanged = true;           // Запомним, что изменения есть
}

//+------------------------------------------------------------------+
//| Обработка закрытия виртуальной позиции                           |
//+------------------------------------------------------------------+
void CVirtualReceiver::OnClose(CVirtualOrder *p_order) {
   m_interface.Changed(p_order);
   CVirtualSymbolReceiver* symbolReceiver = this[p_order.Symbol()];

   if(!!symbolReceiver) {
      PrintFormat(__FUNCTION__"#%s | CLOSE VirtualOrder #%d", p_order.Symbol(),  p_order.Id());
      symbolReceiver.Close(p_order);   // Оповещаем символьный получатель о закрытии позиции
      m_isChanged = true;                    // Запомним, что изменения есть
   }
}

//+------------------------------------------------------------------+
//| Обработка тика для массива виртуальных ордеров (позиций)         |
//+------------------------------------------------------------------+
void CVirtualReceiver::Tick() {
   FOREACH(m_orders) m_orders[i].Tick();
}

//+------------------------------------------------------------------+
//| Корректировка открытых объемов                                   |
//+------------------------------------------------------------------+
bool CVirtualReceiver::Correct() {
   bool res = true;
   if(m_isChanged && IsTradeAllowed()) {
      // Если есть изменения, то вызываем корректировку получателей отдельных символов
      FOREACH(m_symbolReceivers) res &= m_symbolReceivers[i].Correct();
      if(res) {
         m_isChanged = false;                // Сбрасываем флаг изменений
         s_lastChangeTime = TimeCurrent();   // Запоминаем время последней успешной коррекции
      }
   }
   return res;
}

//+------------------------------------------------------------------+
//| Оператор получения объекта символьного получателя                |
//+------------------------------------------------------------------+
CVirtualSymbolReceiver* CVirtualReceiver::operator[](const string symbol) {
   CVirtualSymbolReceiver* symbolReceiver = NULL;
// Ищем информационный объект для данного символа в массиве
   int i;
   FIND(m_symbolReceivers, symbol, i);

// Если нашли, то возвращаем его
   if(i != -1) {
      symbolReceiver = m_symbolReceivers[i];
   } else {
      // Иначе создаём новый информационный объект
      // Если не нашли, то создаем нового получателя для данного символа
      symbolReceiver = new CVirtualSymbolReceiver(symbol);
      // и добавляем его в массив символьных получателей
      APPEND(m_symbolReceivers, symbolReceiver);
   }
   return symbolReceiver;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CVirtualOrder* CVirtualReceiver::Order(int i) {
   return m_orders[i];
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CVirtualReceiver::OrdersTotal() {
   return ArraySize(m_orders);
}
//+------------------------------------------------------------------+
