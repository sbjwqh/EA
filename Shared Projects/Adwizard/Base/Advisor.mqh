//+------------------------------------------------------------------+
//|                                                      Advisor.mqh |
//|                                 Copyright 2019-2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.04"

#include "../Utils/Macros.mqh"
#include "Factorable.mqh"
#include "Strategy.mqh"

//+------------------------------------------------------------------+
//| Базовый класс эксперта                                           |
//+------------------------------------------------------------------+
class CAdvisor : public CFactorable {
protected:
   CStrategy         *m_strategies[];  // Массив торговых стратегий
   virtual void      Add(CStrategy *strategy);  // Метод добавления стратегии
public:
                    ~CAdvisor();                // Деструктор
   virtual void      Tick();                    // Обработчик события OnTick
   virtual double    Tester() {
      return 0;
   }
};

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
void CAdvisor::~CAdvisor() {
// Удаляем все объекты стратегий
   FOREACH(m_strategies) delete m_strategies[i];
}

//+------------------------------------------------------------------+
//| Обработчик события OnTick                                        |
//+------------------------------------------------------------------+
void CAdvisor::Tick(void) {
// Для всех стратегий вызываем обработку OnTick
   FOREACH(m_strategies) m_strategies[i].Tick();
}

//+------------------------------------------------------------------+
//| Метод добавления стратегии                                       |
//+------------------------------------------------------------------+
void CAdvisor::Add(CStrategy *strategy) {
   APPEND(m_strategies, strategy);  // Добавляем стратегию в конец массива
}
//+------------------------------------------------------------------+
