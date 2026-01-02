//+------------------------------------------------------------------+
//|                                             VirtualInterface.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.00"

class CVirtualChartOrder;

#include "../Base/Interface.mqh"
#include "VirtualChartOrder.mqh"

//+------------------------------------------------------------------+
//| Класс графического интерфейса советника                          |
//+------------------------------------------------------------------+
class CVirtualInterface : public CInterface {
protected:
// Статический указатель на единственный экземпляр данного класса
   static   CVirtualInterface *s_instance;

   CVirtualChartOrder *m_chartOrders[];   // Массив графических виртуальных позиций

//--- Частные методы
   CVirtualInterface();   // Закрытый конструктор

public:
   ~CVirtualInterface();  // Деструктор

//--- Статические методы
   static
   CVirtualInterface  *Instance(ulong p_magic = 0);   // Синглтон - создание и получение единственного экземпляра

//--- Публичные методы
   void              Changed(CVirtualOrder *p_order); // Обработка изменений виртуальной позиции
   void              Add(CVirtualOrder *p_order);     // Добавление виртуальной позиции

   virtual void      Redraw() override;   // Отрисовка на графике изменённых объектов
};

// Инициализация статического указателя на единственный экземпляр данного класса
CVirtualInterface *CVirtualInterface::s_instance = NULL;

//+------------------------------------------------------------------+
//| Закрытый конструктор                                             |
//+------------------------------------------------------------------+
CVirtualInterface::CVirtualInterface() {}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CVirtualInterface::~CVirtualInterface() {
   // Удаляем все созданные объекты графических виртуальных позиций
   FOREACH(m_chartOrders) delete m_chartOrders[i];
}

//+------------------------------------------------------------------+
//| Синглтон - создание и получение единственного экземпляра         |
//+------------------------------------------------------------------+
CVirtualInterface* CVirtualInterface::Instance(ulong p_magic = 0) {
   if(!s_instance) {
      s_instance = new CVirtualInterface();
   }
   if(s_magic == 0 && p_magic != 0) {
      s_magic = p_magic;
   }
   return s_instance;
}

//+------------------------------------------------------------------+
//| Добавление виртуальной позиции                                   |
//+------------------------------------------------------------------+
void CVirtualInterface::Add(CVirtualOrder *p_order) {
   // Добавляем новую графичкскую виртуальную позицию, 
   // созданную из виртуальной позиции
   APPEND(m_chartOrders, new CVirtualChartOrder(p_order));
}

//+------------------------------------------------------------------+
//| Обработка изменения виртуальной позиции                          |
//+------------------------------------------------------------------+
void CVirtualInterface::Changed(CVirtualOrder *p_order) {
   // Запомним, что изменения есть у данной позиции
   int i;
   FIND(m_chartOrders, p_order.Id(), i);
   if(i != -1) {
      m_chartOrders[i].Changed();
      m_isChanged = true;
   }
}

//+------------------------------------------------------------------+
//| Отрисовка на графике изменённых объектов                         |
//+------------------------------------------------------------------+
void CVirtualInterface::Redraw() {
   if(m_isActive && m_isChanged) {  // Если интерфейс активен и есть изменения
      // Запускаем перерисовку графических виртуальных позиций
      FOREACH(m_chartOrders) m_chartOrders[i].Redraw();
      m_isChanged = false;          // Сбрасываем флаг изменений
   }
}
//+------------------------------------------------------------------+
