//+------------------------------------------------------------------+
//|                                              VirtualStrategy.mqh |
//|                                 Copyright 2019-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.09"

#include <Generic/HashMap.mqh>
#include "../Base/Strategy.mqh"
#include "VirtualOrder.mqh"
#include "../Database/Storage.mqh"

//+------------------------------------------------------------------+
//| Класс торговой стратегии с виртуальными позициями                |
//+------------------------------------------------------------------+
class CVirtualStrategy : public CStrategy {
protected:
   CVirtualOrder     *m_orders[];      // Массив виртуальных позиций (ордеров)
   int               m_ordersTotal;    // Общее количество открытых позиций и ордеров
   double            m_fittedBalance;  // Нормированный баланс стратегии
   double            m_fixedLot;       // Фиксированный размер стратегии
   
   double            m_baseFittedBalance;  // Начальный нормированный баланс стратегии

   virtual void      CountOrders();    // Подсчет количества открытых виртуальных позиций и ордеров

public:
                     CVirtualStrategy();  // Конструктор

   virtual void      OnOpen(CVirtualOrder *o);            // Обработчик события открытия виртуальной позиции (ордера)
   virtual void      OnClose(CVirtualOrder *o);           // Обработчик события закрытия виртуальной позиции (ордера)

   virtual double    Profit() const;
   virtual double    ClosedProfit() const;
   virtual void      Close();

   virtual void      Save();   // Сохранение состояния
   virtual bool      Load();   // Загрузка состояния
   
   // Установка начального нормированного баланса стратегии
   void              FittedBalance(double fittedBalance) {    
      m_fittedBalance = fittedBalance;
      m_baseFittedBalance = fittedBalance;
   }

   // Нормированный баланс стратегии
   double            FittedBalance() const {    
      return m_fittedBalance;
   }

   // Масштабирование нормированного баланса
   void              Scale(double p_scale) { 
      m_fittedBalance /= p_scale;
   }
   
   // Масштабный множитель стратегии
   double            Scale() const { 
      return m_baseFittedBalance / m_fittedBalance;
   }

   // Замена названий символов
   virtual bool      SymbolsReplace(CHashMap<string, string> &p_symbolsMap) {
      return true;
   }
};


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualStrategy::CVirtualStrategy() :
   m_fixedLot(0.01),
   m_ordersTotal(0) {
      FittedBalance(10000);
   }


//+------------------------------------------------------------------+
//| Подсчет количества открытых виртуальных позиций и ордеров        |
//+------------------------------------------------------------------+
void CVirtualStrategy::CountOrders() {
   m_ordersTotal = 0;
   FOREACH(m_orders) m_ordersTotal += m_orders[i].IsOpen();
}

//+------------------------------------------------------------------+
//| Обработчик события открытия виртуальной позиции (ордера)         |
//+------------------------------------------------------------------+
void CVirtualStrategy::OnOpen(CVirtualOrder *o) {
   CountOrders();
}

//+------------------------------------------------------------------+
//| Обработчик события закрытия виртуальной позиции (ордера)         |
//+------------------------------------------------------------------+
void CVirtualStrategy::OnClose(CVirtualOrder *o) {
   CountOrders();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CVirtualStrategy::Profit() const {
   double profit = 0;
   FOREACH(m_orders) profit += m_orders[i].Profit();
   return profit;
}

double CVirtualStrategy::ClosedProfit() const {
   double profit = 0;
   FOREACH(m_orders) profit += m_orders[i].ClosedProfit();
   return profit;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CVirtualStrategy::Close(void) {
   FOREACH(m_orders) m_orders[i].Close();
}

//+------------------------------------------------------------------+
//| Сохранение состояния                                             |
//+------------------------------------------------------------------+
void CVirtualStrategy::Save() {
// Сохраняем виртуальные позиции (ордера) стратегии
   FOREACH(m_orders) CStorage::Set(i, m_orders[i]);
}

//+------------------------------------------------------------------+
//| Загрузка состояния                                               |
//+------------------------------------------------------------------+
bool CVirtualStrategy::Load() {
   bool res = true;
   
// Загружаем виртуальные позиции (ордера) стратегии
   res = CStorage::Get(this.Hash(), m_orders);

   return res;
}
//+------------------------------------------------------------------+
