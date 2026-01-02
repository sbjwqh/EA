//+------------------------------------------------------------------+
//|                                            VirtualChartOrder.mqh |
//|                                 Copyright 2022-2025, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2025, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.02"

#include <Charts\Chart.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

#include "VirtualOrder.mqh"

//+------------------------------------------------------------------+
//| Класс графической виртуальной позиции                            |
//+------------------------------------------------------------------+
class CVirtualChartOrder : public CInterface {
   CVirtualOrder*    m_order;          // Связанная виртуальная позиция (ордер)
   CChart            m_chart;          // Объект графика для отображения

   // Объекты на графике для отображения виртуальной позиции
   CChartObjectHLine m_openLine;       // Линия цены открытия

   long              FindChart();      // Поиск/открытие нужного графика
public:
   CVirtualChartOrder(CVirtualOrder* p_order);     // Конструктор
   ~CVirtualChartOrder();                          // Деструктор

   bool              operator==(const ulong id) {  // Оператор сравнения по Id
      return m_order.Id() == id;
   }

   void              Show();    // Показ виртуальной позиции (ордера)
   void              Hide();    // Скрытие виртуальной позиции (ордера)

   virtual void      Redraw() override;   // Перерисовка виртуальной позиции (ордера)
};


//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CVirtualChartOrder::CVirtualChartOrder(CVirtualOrder* p_order) :
   m_order(p_order) {}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CVirtualChartOrder::~CVirtualChartOrder() {
   Hide();
}

//+------------------------------------------------------------------+
//| Поиск графика для отображения                                    |
//+------------------------------------------------------------------+
long CVirtualChartOrder::FindChart() {
   if(m_chart.ChartId() == -1 || m_chart.Symbol() != m_order.Symbol()) {
      long currChart, prevChart = ChartFirst();
      int i = 0, limit = 1000;

      currChart = prevChart;

      while(i < limit) { // у нас наверняка не больше 1000 открытых графиков
         if(ChartSymbol(currChart) == m_order.Symbol()) {
            return currChart;
         }
         currChart = ChartNext(prevChart); // на основании предыдущего получим новый график
         if(currChart < 0)
            break;        // достигли конца списка графиков
         prevChart = currChart; // запомним идентификатор текущего графика для ChartNext()
         i++;
      }

      // Если подходящий график не найден, то откроем новый
      if(currChart == -1) {
         m_chart.Open(m_order.Symbol(), PERIOD_CURRENT);
      }
   }
   return m_chart.ChartId();
}

//+------------------------------------------------------------------+
//| Показ виртуальной позиции (ордера)                               |
//+------------------------------------------------------------------+
void CVirtualChartOrder::Show() {
   return;

   string name = StringFormat("%d #%d: %s %s %.2f",
                              s_magic,
                              m_order.Id(),
                              m_order.TypeName(),
                              m_order.Symbol(), m_order.Volume());

   long chartId = FindChart();
   if(!m_openLine.Create(chartId, name, 0, m_order.OpenPrice())) {
      PrintFormat(__FUNCTION__" | ERROR Creating line", 0);
      return;
   }

   if(m_order.IsPendingOrder()) {
      if(m_order.IsStopOrder()) {
         m_openLine.Style(STYLE_DASH);
      }
      if(m_order.IsLimitOrder()) {
         m_openLine.Style(STYLE_DOT);
      }
      if(m_order.IsBuyOrder()) {
         m_openLine.Color(clrLightSkyBlue);
      }
      if(m_order.IsSellOrder()) {
         m_openLine.Color(clrLightSalmon);
      }
   } else {
      m_openLine.Style(STYLE_SOLID);

      if(m_order.IsBuyOrder()) {
         m_openLine.Color(clrBlue);
      }
      if(m_order.IsSellOrder()) {
         m_openLine.Color(clrRed);
      }
   }
}

//+------------------------------------------------------------------+
//| Скрытие виртуальной позиции (ордера)                             |
//+------------------------------------------------------------------+
void CVirtualChartOrder::Hide() {
   m_openLine.Delete();
}

//+------------------------------------------------------------------+
//| Перерисовка виртуальной позиции (ордера)                         |
//+------------------------------------------------------------------+
void CVirtualChartOrder::Redraw() {
   if(m_isChanged) {
      Hide();
      if(m_order.IsOpen()) {
         Show();
      }
      m_isChanged = false;
   }
}
//+------------------------------------------------------------------+
