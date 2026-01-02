//+------------------------------------------------------------------+
//|                                                    Interface.mqh |
//|                                      Copyright 2024, Yuriy Bykov |
//|                            https://www.mql5.com/ru/users/antekov |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022-2024, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/users/antekov"
#property version   "1.01"

//+------------------------------------------------------------------+
//| Базовый класс визуализации различных объектов                    |
//+------------------------------------------------------------------+
class CInterface {
protected:
   static ulong      s_magic;       // Magic эксперта
   bool              m_isActive;    // Интерфейс активен?
   bool              m_isChanged;   // Есть ли изменения у объекта?
public:
   CInterface();                    // Конструктор
   virtual void      Activate();
   virtual void      Deactivate();
   virtual void      Redraw() = 0;  // Отрисовка на графике изменённых объектов
   virtual void      Changed() {    // Установка флага наличия изменений
      m_isChanged = true;
   }

   virtual void      ChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {}
};

ulong CInterface::s_magic = 0;

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CInterface::CInterface() :
   m_isActive(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)),
   m_isChanged(true) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CInterface::Activate() {
   m_isActive = (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CInterface::Deactivate() {
   m_isActive = false;
}
//+------------------------------------------------------------------+
